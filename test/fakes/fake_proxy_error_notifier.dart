import 'package:uvalert/providers/uv_provider.dart';

/// Immediately emits a fixed [ProxyErrorState], for widget tests that need
/// to drive `ProxyErrorBanner`/`ProxyErrorToastListener` into a specific
/// error state without going through a real [UvNotifier] fetch failure.
class FakeProxyErrorNotifier extends ProxyErrorNotifier {
  /// Creates a [FakeProxyErrorNotifier] that resolves to [fixedState].
  FakeProxyErrorNotifier(this.fixedState);

  /// The state returned by [build].
  final ProxyErrorState fixedState;

  @override
  ProxyErrorState build() => fixedState;
}
