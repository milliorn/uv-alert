import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/api/uv_api.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/providers/uv_provider.dart';

/// Immediately emits an error state with no prior data, mirroring the
/// dashboard's no-data edge case (network drop or corrupt cache, no
/// fallback available).
///
/// [fetch] (inherited from [UvNotifier]) uses the injected api when
/// present, so tests can drive a Retry tap through to a mock without
/// resolving the production API provider.
class FakeErrorUvNotifier extends UvNotifier {
  /// Creates a [FakeErrorUvNotifier]; forwards `api` to [UvNotifier] for use
  /// by an inherited [fetch] call. [error] defaults to a generic exception;
  /// pass a real [UvApiException] for tests that need [build]'s error to
  /// carry a specific `statusCode`.
  FakeErrorUvNotifier({super.api, Object? error})
    : _error = error ?? Exception('uv fetch failed');

  final Object _error;

  @override
  AsyncValue<UvData> build() =>
      AsyncValue<UvData>.error(_error, StackTrace.empty);
}

/// Immediately emits data, mirroring the dashboard's happy path.
///
/// [fetch] (inherited from [UvNotifier]) uses the injected api when present,
/// so a test that triggers a fetch from this state still doesn't resolve the
/// production API provider.
class FakeDataUvNotifier extends UvNotifier {
  /// Creates a [FakeDataUvNotifier] that resolves to [data]; forwards `api`
  /// to [UvNotifier] for use by an inherited [fetch] call.
  FakeDataUvNotifier(this.data, {super.api});

  /// The data returned by [build].
  final UvData data;

  @override
  AsyncValue<UvData> build() => AsyncValue<UvData>.data(data);

  /// Replaces the current state with [newData], for tests that need to
  /// prove a widget rebuilds and re-reads provider state after this notifier
  /// changes, rather than only checking its initial [build] output.
  void updateData(UvData newData) {
    state = AsyncValue<UvData>.data(newData);
  }
}
