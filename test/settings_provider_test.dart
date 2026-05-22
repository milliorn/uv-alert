import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uvalert/providers/settings_provider.dart';

ProviderContainer _makeContainer() {
  final ProviderContainer container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // -------------------------------------------------------------------------
  // Initial state
  // -------------------------------------------------------------------------

  test('initial state is AsyncLoading', () {
    final ProviderContainer container = _makeContainer();

    expect(
      container.read(settingsProvider),
      isA<AsyncLoading<SettingsState>>(),
    );
  });
}
