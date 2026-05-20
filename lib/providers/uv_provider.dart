import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/api/uv_api.dart';
import 'package:uvalert/constants.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/providers/device_id_provider.dart';
import 'package:uvalert/providers/location_provider.dart';
import 'package:uvalert/storage/cache.dart';
import 'package:uvalert/storage/preferences.dart';

/// Provides a [Cache] backed by [Preferences].
final FutureProvider<Cache> cacheProvider = FutureProvider<Cache>((
  Ref ref,
) async {
  final Preferences prefs = await Preferences.load();
  return Cache(prefs);
});

/// Provides the production [UvApi] instance.
final FutureProvider<UvApi> uvApiProvider = FutureProvider<UvApi>((
  Ref ref,
) async {
  if (proxyBaseUrl.isEmpty) {
    throw StateError(
      'PROXY_BASE_URL is not set. '
      'Pass --dart-define=PROXY_BASE_URL=https://your-proxy.com at build time.',
    );
  }
  final Cache cache = await ref.read(cacheProvider.future);
  return UvApi(cache: cache, proxyBaseUrl: proxyBaseUrl);
});

/// Riverpod provider for [UvNotifier].
final NotifierProvider<UvNotifier, AsyncValue<UvData>> uvProvider =
    NotifierProvider<UvNotifier, AsyncValue<UvData>>(UvNotifier.new);

/// Manages UV data state.
///
/// Watches [locationProvider] for coordinate changes and triggers a re-fetch
/// automatically. Call [fetch] to force a refresh.
class UvNotifier extends Notifier<AsyncValue<UvData>> {
  /// Creates a [UvNotifier]; [api] defaults to `null` and must be overridden
  /// in tests.
  UvNotifier({UvApi? api}) : _api = api;

  /// The [UvApi] instance used to fetch UV data.
  final UvApi? _api;

  Future<UvApi> _resolveApi() async =>
      _api ?? await ref.read(uvApiProvider.future);

  @override
  AsyncValue<UvData> build() {
    // Watch locationProvider so this notifier rebuilds when coords change,
    // which triggers fetch() automatically.
    final LocationState location = ref.watch(locationProvider);

    if (location != null) {
      // Schedule the fetch after build returns; state mutations are not
      // allowed synchronously inside build().
      unawaited(
        Future<void>.microtask(() async {
          try {
            // Read (not watch) deviceIdProvider so its future resolution does
            // not trigger another build() and reset state to loading.
            // Resolve both concurrently — they load SharedPreferences
            // independently.
            final (String uuid, UvApi api) = await (
              ref.read(deviceIdProvider.future),
              _resolveApi(),
            ).wait;

            await _fetchWith(
              api: api,
              lat: location.lat,
              lon: location.lon,
              uuid: uuid,
            );
          } on Object catch (e, st) {
            if (!ref.mounted) return;
            state = AsyncValue<UvData>.error(e, st);
          }
        }),
      );
    }

    // On initial build there is no previous state; return loading.
    // On subsequent builds (location change), preserve the previous value so
    // the UI keeps showing data while the new fetch is in flight instead of
    // flashing a spinner.
    return stateOrNull ?? const AsyncValue<UvData>.loading();
  }

  /// Fetches UV data for the given coordinates.
  ///
  /// Updates state to [AsyncValue.loading] while in-flight, then to
  /// [AsyncValue.data] on success or [AsyncValue.error] on failure.
  Future<void> fetch({
    required double lat,
    required double lon,
    required String uuid,
  }) async {
    await _fetchWith(api: await _resolveApi(), lat: lat, lon: lon, uuid: uuid);
  }

  Future<void> _fetchWith({
    required UvApi api,
    required double lat,
    required double lon,
    required String uuid,
  }) async {
    state = const AsyncValue<UvData>.loading();

    final UvData data;

    try {
      data = await api.fetch(lat: lat, lon: lon, uuid: uuid);
    } on Object catch (e, st) {
      // Guard against writing to a disposed notifier when a location change
      // causes Riverpod to rebuild (and dispose the old instance) while a
      // fetch is still in flight.
      if (!ref.mounted) return;
      state = AsyncValue<UvData>.error(e, st);
      return;
    }

    if (!ref.mounted) return;
    state = AsyncValue<UvData>.data(data);
  }
}
