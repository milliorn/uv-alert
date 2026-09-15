import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/api/uv_api.dart';
import 'package:uvalert/constants.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/providers/app_version_provider.dart';
import 'package:uvalert/providers/device_id_provider.dart';
import 'package:uvalert/providers/location_provider.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/storage/cache.dart';
import 'package:uvalert/storage/preferences.dart';

/// Provides the proxy base URL. Overridable in tests.
final Provider<String> proxyBaseUrlProvider = Provider<String>(
  (_) => proxyBaseUrl,
);

/// Provides a [Cache] backed by [Preferences].
final FutureProvider<Cache> cacheProvider = FutureProvider<Cache>((
  Ref ref,
) async {
  final Preferences prefs = await ref.read(preferencesProvider.future);
  return Cache(prefs);
});

/// Provides the production [UvApi] instance.
final FutureProvider<UvApi> uvApiProvider = FutureProvider<UvApi>((
  Ref ref,
) async {
  final String url = ref.read(proxyBaseUrlProvider);

  if (url.isEmpty) {
    throw StateError(
      'PROXY_BASE_URL is not set. '
      'Pass --dart-define=PROXY_BASE_URL=https://your-proxy.com at build time.',
    );
  }

  final Cache cache = await ref.read(cacheProvider.future);
  final UvApi api = UvApi(cache: cache, proxyBaseUrl: url);

  ref.onDispose(api.dispose);
  return api;
});

/// Riverpod provider for [UvNotifier].
final NotifierProvider<UvNotifier, AsyncValue<UvData>> uvProvider =
    NotifierProvider<UvNotifier, AsyncValue<UvData>>(UvNotifier.new);

/// Extra queries on [UvNotifier]'s state, co-located here so callers don't
/// re-derive [UvNotifier]'s state-transition guarantees themselves.
extension UvStateQueries on AsyncValue<UvData> {
  /// Whether there is genuinely no UV data to show: the last fetch failed
  /// and no prior successful data exists to fall back to.
  bool get isNoData => hasError && !hasValue;
}

/// In-memory record of proxy failures, tracked so the dashboard can escalate
/// its error UX (toast -> persistent banner) after repeated failures, or
/// show an immediate persistent banner for a failure that cannot self-heal
/// via retry. See `docs/adr/0010-proxy-error-code-contract.md`.
///
/// Tracks two independent things because ADR 0010 gives 400/429/502 and
/// 500/503/504 different escalation semantics: an immediate code's banner
/// must stay up until [ProxyErrorNotifier.recordSuccess], regardless of what
/// other codes occur in between, while the 500/503/504 streak counts only a
/// consecutive run of that family. A single shared counter/last-code pair
/// cannot represent both without one clobbering the other (e.g. a 502
/// followed by a 500 would otherwise flip [lastStatusCode] to 500 and hide
/// the still-active 502 banner with no success having occurred).
@immutable
class ProxyErrorState {
  /// Creates a [ProxyErrorState].
  const ProxyErrorState({
    this.consecutiveFailures = 0,
    this.lastStatusCode,
    this.immediateStatusCode,
  });

  /// Number of 500/503/504 responses received back-to-back, with no
  /// successful network response and no intervening non-500/503/504 failure
  /// in between. Reset to 0 whenever `UvApi.fetch` actually receives an HTTP
  /// 200 from the proxy (`UvApiFetchMeta.receivedNetwork200` in
  /// `uv_api.dart`) -- this holds even if something fails afterward (an
  /// unparseable body, or a cache-write error), since the proxy itself still
  /// answered successfully. Excludes a cache hit, which is also a
  /// "successful fetch" but is not evidence the proxy has recovered.
  final int consecutiveFailures;

  /// The status code of the most recent 500/503/504 failure counted by
  /// [consecutiveFailures], or `null` if no such failure has been recorded
  /// since the last network-verified success (or none has completed yet).
  ///
  /// A cache-hit fetch leaves this value unchanged rather than clearing it
  /// -- see [consecutiveFailures].
  final int? lastStatusCode;

  /// The status code of an active 400/429/502 failure, or `null` if none is
  /// active.
  ///
  /// Unlike [lastStatusCode], this is not a streak: ADR 0010 calls for these
  /// codes to show their banner on the very 1st occurrence and keep it shown
  /// until [ProxyErrorNotifier.recordSuccess], since they cannot self-heal
  /// via retry (a bad request stays bad; an invalid OWM key needs operator
  /// action). A later 500/503/504 does not clear this field, so the
  /// immediate banner stays visible while the 500/503/504 streak accumulates
  /// underneath it.
  final int? immediateStatusCode;

  // Override == for value equality, consistent with the rest of the
  // codebase's model classes (see WeatherAlert, UvData) -- lets tests and
  // ref.listen compare states directly rather than field-by-field.
  @override
  bool operator ==(Object other) =>
      other is ProxyErrorState &&
      other.consecutiveFailures == consecutiveFailures &&
      other.lastStatusCode == lastStatusCode &&
      other.immediateStatusCode == immediateStatusCode;

  @override
  int get hashCode =>
      Object.hash(consecutiveFailures, lastStatusCode, immediateStatusCode);
}

/// Riverpod provider for [ProxyErrorNotifier].
final NotifierProvider<ProxyErrorNotifier, ProxyErrorState> proxyErrorProvider =
    NotifierProvider<ProxyErrorNotifier, ProxyErrorState>(
      ProxyErrorNotifier.new,
    );

/// Tracks consecutive proxy failures reported by [UvNotifier].
///
/// A companion notifier rather than a field on [UvNotifier] itself, so
/// [uvProvider]'s existing `AsyncValue<UvData>` contract is untouched --
/// widgets that already `ref.watch(uvProvider)` expecting only UV data are
/// unaffected. [UvNotifier] reports outcomes via [recordFailure] and
/// [recordSuccess] as they happen.
class ProxyErrorNotifier extends Notifier<ProxyErrorState> {
  @override
  ProxyErrorState build() => const ProxyErrorState();

  /// Records a non-200 proxy response, updating [ProxyErrorState] per ADR
  /// 0010's rules for [statusCode].
  ///
  /// - If [statusCode] is in [proxyImmediateStatusCodes] (400/429/502), sets
  ///   [ProxyErrorState.immediateStatusCode] to it. This does not touch
  ///   [ProxyErrorState.consecutiveFailures]: an immediate-banner code is a
  ///   distinct, sticky condition that stays active until [recordSuccess],
  ///   not a streak, and it must not consume a slot in the 500/503/504
  ///   counter (nor be cleared by that counter's own resets).
  /// - If [statusCode] is in [proxyThresholdGatedStatusCodes]
  ///   (500/503/504), increments [ProxyErrorState.consecutiveFailures] if
  ///   the previous failure was also threshold-gated, or starts a fresh
  ///   streak at 1 otherwise (an interrupting immediate-banner code does not
  ///   belong to this streak, so it cannot be silently counted as one of its
  ///   3 consecutive failures).
  /// - Any other [statusCode] (e.g. 404, which has its own "geocoding no
  ///   results" UX per ADR 0010) is a no-op: it must not affect either field,
  ///   since no widget shows feedback for it.
  ///
  /// [statusCode] 426 (app-version-too-old) must never be passed here --
  /// it is handled separately via [UvApiForceUpdateException] and force-update
  /// UI (see `docs/adr/0009-force-update-via-426.md`), and is explicitly
  /// excluded from this escalation counter per issue #70's scope.
  void recordFailure(int statusCode) {
    assert(
      statusCode != httpUpgradeRequired,
      'recordFailure must not be called with $httpUpgradeRequired '
      '(force-update); it is tracked separately, not via this counter.',
    );

    if (proxyImmediateStatusCodes.contains(statusCode)) {
      state = ProxyErrorState(
        consecutiveFailures: state.consecutiveFailures,
        lastStatusCode: state.lastStatusCode,
        immediateStatusCode: statusCode,
      );
      return;
    }

    if (proxyThresholdGatedStatusCodes.contains(statusCode)) {
      final bool continuesStreak = proxyThresholdGatedStatusCodes.contains(
        state.lastStatusCode,
      );

      state = ProxyErrorState(
        consecutiveFailures: continuesStreak
            ? state.consecutiveFailures + 1
            : 1,
        lastStatusCode: statusCode,
        immediateStatusCode: state.immediateStatusCode,
      );
    }
  }

  /// Resets [ProxyErrorState] to its initial value after a successful fetch,
  /// clearing both the 500/503/504 streak and any active immediate banner.
  void recordSuccess() {
    state = const ProxyErrorState();
  }
}

/// Manages UV data state.
///
/// Watches [locationProvider] for coordinate changes and triggers a re-fetch
/// automatically. Call [fetch] to force a refresh.
class UvNotifier extends Notifier<AsyncValue<UvData>> {
  /// Creates a [UvNotifier]; [api] defaults to `null`, in which case the
  /// production instance is resolved from [uvApiProvider] at runtime.
  UvNotifier({UvApi? api}) : _api = api;

  /// Injected [UvApi] for testing. When `null`, [_resolveApi] reads the
  /// production instance from [uvApiProvider]. Injected instances are owned
  /// by the caller and are not disposed by this notifier.
  final UvApi? _api;

  // Incremented on each build() invocation; microtasks check this to detect
  // superseded fetches caused by rapid location changes.
  int _fetchGeneration = 0;

  Future<UvApi> _resolveApi() async =>
      _api ?? await ref.read(uvApiProvider.future);

  /// Merges [next] with the current state's value/error, so a transient
  /// failure or a loading transition falls back to stale cached data instead
  /// of wiping it -- the plain [AsyncValue.error]/[AsyncValue.loading]
  /// factories always produce hasValue == false, which would incorrectly
  /// trip DashboardNoDataView (see [UvStateQueries.isNoData]) even when good
  /// data already exists. copyWithPrevious is @internal upstream with no
  /// public equivalent; this is the same mechanism riverpod's own
  /// AsyncNotifier machinery applies automatically when build() throws,
  /// applied manually here since these transitions originate outside
  /// build() itself.
  AsyncValue<UvData> _withPrevious(AsyncValue<UvData> next) =>
      // copyWithPrevious is @internal with no public equivalent.
      // ignore: invalid_use_of_internal_member
      next.copyWithPrevious(state);

  @override
  AsyncValue<UvData> build() {
    final LocationState location = ref.watch(locationProvider);

    if (location != null) {
      final int generation = ++_fetchGeneration;

      // State mutations are not allowed synchronously inside build().
      unawaited(
        Future<void>.microtask(() async {
          try {
            // ref.read (not watch) so resolution doesn't re-trigger build().
            final (String uuid, String appVersion, UvApi api) = await (
              ref.read(deviceIdProvider.future),
              ref.read(appVersionProvider.future),
              _resolveApi(),
            ).wait;

            if (generation != _fetchGeneration) return;

            await _fetchWith(
              api: api,
              lat: location.lat,
              lon: location.lon,
              uuid: uuid,
              appVersion: appVersion,
              generation: generation,
            );
          } on Object catch (e, st) {
            if (!ref.mounted || generation != _fetchGeneration) return;
            state = _withPrevious(AsyncValue<UvData>.error(e, st));
          }
        }),
      );
    }

    // Preserve previous AsyncData during a refresh so the UI doesn't flash a
    // spinner. copyWithPrevious is @internal in riverpod, so this is the only
    // public way to achieve it from a sync Notifier.
    return stateOrNull ?? const AsyncValue<UvData>.loading();
  }

  /// Fetches UV data for the given coordinates.
  ///
  /// Updates state to [AsyncValue.loading] while in-flight, then to
  /// [AsyncValue.data] on success or [AsyncValue.error] on failure.
  Future<void> fetch({required double lat, required double lon}) async {
    if (!ref.mounted) return;

    final String uuid;
    final String appVersion;
    final UvApi api;

    try {
      (uuid, appVersion, api) = await (
        ref.read(deviceIdProvider.future),
        ref.read(appVersionProvider.future),
        _resolveApi(),
      ).wait;
    } on Object catch (e, st) {
      if (!ref.mounted) return;
      state = _withPrevious(AsyncValue<UvData>.error(e, st));
      return;
    }

    // Increment after the await so this manual fetch supersedes any concurrent
    // auto-fetch microtask that incremented the counter while we were awaiting
    // deviceId/appVersion/api above.
    final int generation = ++_fetchGeneration;

    if (!ref.mounted) return;
    // Preserve prior value/error through the loading transition (mirrors
    // build()'s stateOrNull ?? loading() fallback) so a manual refresh
    // doesn't itself wipe hasValue before _fetchWith's own error handling
    // ever runs.
    state = _withPrevious(const AsyncValue<UvData>.loading());

    await _fetchWith(
      api: api,
      lat: lat,
      lon: lon,
      uuid: uuid,
      appVersion: appVersion,
      generation: generation,
    );
  }

  Future<void> _fetchWith({
    required UvApi api,
    required double lat,
    required double lon,
    required String uuid,
    required String appVersion,
    required int generation,
  }) async {
    // Re-check generation before every state write so a newer build() that
    // incremented _fetchGeneration while api.fetch was in-flight can't
    // overwrite the result of the superseding fetch.
    bool isStale() => generation != _fetchGeneration;

    if (isStale()) return;
    if (!ref.mounted) return;

    final UvData data;
    // Fresh per call, not a field on the shared UvApi instance, so an
    // overlapping (superseded) fetch can't clobber this call's own
    // cache-hit outcome before it's read below.
    final UvApiFetchMeta meta = UvApiFetchMeta();

    try {
      data = await api.fetch(
        lat: lat,
        lon: lon,
        uuid: uuid,
        appVersion: appVersion,
        meta: meta,
      );
    } on Object catch (e, st) {
      if (!ref.mounted || isStale()) return;
      // Whether (and with what code) a failure counts toward the escalation
      // counter is declared on the exception itself (see
      // UvApiFailure.escalationStatusCode), not inferred here by type --
      // 426/parse failures return null there, so adding a new failure type
      // can't silently start or stop counting: the policy and the status
      // code are the same getter, so there is no "opted in but forgot the
      // code" state for this site to miss, in any build mode.
      if (e is UvApiFailure) {
        final int? code = e.escalationStatusCode;

        if (code != null) {
          ref.read(proxyErrorProvider.notifier).recordFailure(code);
        }
      }

      // A real network 200 is proxy-health evidence regardless of what
      // failed afterward (body parsing, or Cache.store raising some
      // unrelated exception that isn't even a UvApiFailure) -- so this is
      // keyed on UvApiFetchMeta.receivedNetwork200, not on the exception's
      // type, per issue #70's "reset on any successful 200 response" rule.
      if (meta.receivedNetwork200) {
        ref.read(proxyErrorProvider.notifier).recordSuccess();
      }

      state = _withPrevious(AsyncValue<UvData>.error(e, st));
      return;
    }

    if (!ref.mounted || isStale()) return;

    // A cache hit proves nothing about current proxy health -- only a real
    // network response should clear the consecutive-failure streak (see
    // UvApiFetchMeta).
    if (!meta.wasFromCache) {
      ref.read(proxyErrorProvider.notifier).recordSuccess();
    }
    
    state = AsyncValue<UvData>.data(data);
  }
}
