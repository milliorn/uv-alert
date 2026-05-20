import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/api/uv_api.dart';
import 'package:uvalert/constants.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/providers/device_id_provider.dart';
import 'package:uvalert/providers/location_provider.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/storage/cache.dart';
import 'package:uvalert/storage/preferences.dart';

/// Provides the proxy base URL. Overridable in tests.
final Provider<String> proxyBaseUrlProvider =
    Provider<String>((_) => proxyBaseUrl);

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

/// Manages UV data state.
///
/// Watches [locationProvider] for coordinate changes and triggers a re-fetch
/// automatically. Call [fetch] to force a refresh.
class UvNotifier extends Notifier<AsyncValue<UvData>> {
  /// Creates a [UvNotifier]; [api] defaults to `null`, in which case the
  /// production instance is resolved from [uvApiProvider] at runtime.
  UvNotifier({UvApi? api}) : _api = api;

  /// The [UvApi] instance used to fetch UV data.
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
            final (String uuid, UvApi api) = await (
              ref.read(deviceIdProvider.future),
              _resolveApi(),
            ).wait;

            if (generation != _fetchGeneration) return;

            await _fetchWith(
              api: api,
              lat: location.lat,
              lon: location.lon,
              uuid: uuid,
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

  /// Fetches UV data for the current location.
  ///
  /// Updates state to [AsyncValue.loading] while in-flight, then to
  /// [AsyncValue.data] on success or [AsyncValue.error] on failure.
  Future<void> fetch({required double lat, required double lon}) async {
    if (!ref.mounted) return;

    final String uuid;
    final UvApi api;

    try {
      (uuid, api) = await (
        ref.read(deviceIdProvider.future),
        _resolveApi(),
      ).wait;
    } on Object catch (e, st) {
      if (!ref.mounted) return;
      state = AsyncValue<UvData>.error(e, st);
      return;
    }

    await _fetchWith(api: api, lat: lat, lon: lon, uuid: uuid);
  }

  Future<void> _fetchWith({
    required UvApi api,
    required double lat,
    required double lon,
    required String uuid,
    int? generation,
  }) async {
    // generation == null means the call came from fetch() (manual refresh),
    // which always runs to completion. A non-null value means the call came
    // from build()'s microtask; re-check before every state write so a newer
    // build() that incremented _fetchGeneration while api.fetch was in-flight
    // can't be overwritten by this stale result.
    bool isStale() => generation != null && generation != _fetchGeneration;

    if (isStale()) return;
    if (!ref.mounted) return;
    // build() returns stateOrNull, preserving prior data without setting state;
    // only set loading here for manual fetch() calls, where build() hasn't run.
    if (generation == null) state = const AsyncValue<UvData>.loading();

    final UvData data;

    try {
      data = await api.fetch(lat: lat, lon: lon, uuid: uuid);
    } on Object catch (e, st) {
      if (!ref.mounted || isStale()) return;
      state = AsyncValue<UvData>.error(e, st);
      return;
    }

    if (!ref.mounted || isStale()) return;
    state = AsyncValue<UvData>.data(data);
  }
}
