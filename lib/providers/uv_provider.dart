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
final Provider<Future<Cache>> cacheProvider = Provider<Future<Cache>>((
  Ref ref,
) async {
  final Preferences prefs = await Preferences.load();
  return Cache(prefs);
});

/// Provides the production [UvApi] instance.
final Provider<Future<UvApi>> uvApiProvider = Provider<Future<UvApi>>((
  Ref ref,
) async {
  final Cache cache = await ref.read(cacheProvider);
  return UvApi(cache: cache, proxyBaseUrl: kProxyBaseUrl);
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

  @override
  AsyncValue<UvData> build() {
    // Watch locationProvider so this notifier rebuilds when coords change,
    // which triggers fetch() automatically.
    final LocationState location = ref.watch(locationProvider);

    // Watch deviceIdProvider; skip the fetch until the UUID is ready.
    final AsyncValue<String> deviceId = ref.watch(deviceIdProvider);

    if (location != null) {
      deviceId.whenData((String uuid) {
        // Schedule the fetch after build returns; state mutations are not
        // allowed synchronously inside build().
        unawaited(
          Future<void>.microtask(() async {
            final UvApi api = _api ?? await ref.read(uvApiProvider);
            await _fetchWith(
              api: api,
              lat: location.lat,
              lon: location.lon,
              uuid: uuid,
            );
          }),
        );
      });
    }

    return const AsyncValue<UvData>.loading();
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
    final UvApi api = _api ?? await ref.read(uvApiProvider);
    await _fetchWith(api: api, lat: lat, lon: lon, uuid: uuid);
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
