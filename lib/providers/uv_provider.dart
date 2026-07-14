import 'dart:async';

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
            state = AsyncValue<UvData>.error(e, st);
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
      state = AsyncValue<UvData>.error(e, st);
      return;
    }

    // Increment after the await so this manual fetch supersedes any concurrent
    // auto-fetch microtask that incremented the counter while we were awaiting
    // deviceId/appVersion/api above.
    final int generation = ++_fetchGeneration;

    if (!ref.mounted) return;
    state = const AsyncValue<UvData>.loading();

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

    try {
      data = await api.fetch(
        lat: lat,
        lon: lon,
        uuid: uuid,
        appVersion: appVersion,
      );
    } on Object catch (e, st) {
      if (!ref.mounted || isStale()) return;
      state = AsyncValue<UvData>.error(e, st);
      return;
    }

    if (!ref.mounted || isStale()) return;
    state = AsyncValue<UvData>.data(data);
  }
}
