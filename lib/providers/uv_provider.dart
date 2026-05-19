import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/api/uv_api.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/providers/location_provider.dart';

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

  final UvApi? _api;

  @override
  AsyncValue<UvData> build() {
    // Watch locationProvider so this notifier rebuilds when coords change,
    // which triggers fetch() automatically.
    final LocationState location = ref.watch(locationProvider);

    if (location != null) {
      // Schedule the fetch after build returns; state mutations are not
      // allowed synchronously inside build().
      unawaited(
        Future<void>.microtask(
          () => fetch(lat: location.lat, lon: location.lon),
        ),
      );
    }

    return const AsyncValue<UvData>.loading();
  }

  /// Fetches UV data for the given coordinates.
  ///
  /// Updates state to [AsyncValue.loading] while in-flight, then to
  /// [AsyncValue.data] on success or [AsyncValue.error] on failure.
  Future<void> fetch({required double lat, required double lon}) async {
    final UvApi? api = _api;

    if (api == null) {
      state = AsyncValue<UvData>.error(
        StateError('UvNotifier: UvApi not configured'),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncValue<UvData>.loading();

    try {
      final UvData data = await api.fetch(lat: lat, lon: lon, uuid: '');
      state = AsyncValue<UvData>.data(data);
    } on Object catch (e, st) {
      state = AsyncValue<UvData>.error(e, st);
    }
  }
}
