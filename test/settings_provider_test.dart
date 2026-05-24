import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/providers/settings_provider.dart';

ProviderContainer _makeContainer() {
  final ProviderContainer container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

Future<ProviderContainer> _makeLoadedContainer() async {
  final ProviderContainer container = _makeContainer();
  await (container..read(settingsProvider)).read(preferencesProvider.future);
  await Future<void>.delayed(Duration.zero);
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

  // -------------------------------------------------------------------------
  // build() — loads from preferences
  // -------------------------------------------------------------------------

  test('build() loads default values from preferences', () async {
    final ProviderContainer container = await _makeLoadedContainer();

    final SettingsState settings = container
        .read(settingsProvider)
        .requireValue;
    expect(settings.theme, 'system');
    expect(settings.useGps, isTrue);
    expect(settings.manualLocation, isNull);
    expect(settings.notificationsEnabled, isFalse);
  });

  test('build() sets AsyncError when preferencesProvider throws', () async {
    final ProviderContainer container = ProviderContainer(
      // Override type inference is not exposed publicly in flutter_riverpod.
      // ignore: always_specify_types
      overrides: [
        preferencesProvider.overrideWith(
          (_) async => throw StateError('prefs unavailable'),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(settingsProvider);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(settingsProvider), isA<AsyncError<SettingsState>>());
  });

  // -------------------------------------------------------------------------
  // setTheme
  // -------------------------------------------------------------------------

  test('setTheme rejects invalid theme value', () async {
    final ProviderContainer container = await _makeLoadedContainer();

    expect(
      () => container.read(settingsProvider.notifier).setTheme('invalid'),
      throwsA(isA<AssertionError>()),
    );
  });

  test('setTheme updates theme in state', () async {
    final ProviderContainer container = await _makeLoadedContainer();

    await container.read(settingsProvider.notifier).setTheme('dark');

    expect(container.read(settingsProvider).requireValue.theme, 'dark');
  });

  // -------------------------------------------------------------------------
  // setUseGps
  // -------------------------------------------------------------------------

  test('setUseGps updates useGps in state', () async {
    final ProviderContainer container = await _makeLoadedContainer();

    await container.read(settingsProvider.notifier).setUseGps(value: false);

    expect(container.read(settingsProvider).requireValue.useGps, isFalse);
  });

  // -------------------------------------------------------------------------
  // setManualLocation
  // -------------------------------------------------------------------------

  test('setManualLocation updates manualLocation in state', () async {
    final ProviderContainer container = await _makeLoadedContainer();

    await container
        .read(settingsProvider.notifier)
        .setManualLocation('New York, NY');

    expect(
      container.read(settingsProvider).requireValue.manualLocation,
      'New York, NY',
    );
  });

  // -------------------------------------------------------------------------
  // setNotificationsEnabled
  // -------------------------------------------------------------------------

  test(
    'setNotificationsEnabled updates notificationsEnabled in state',
    () async {
      final ProviderContainer container = await _makeLoadedContainer();

      await container
          .read(settingsProvider.notifier)
          .setNotificationsEnabled(value: true);

      expect(
        container.read(settingsProvider).requireValue.notificationsEnabled,
        isTrue,
      );
    },
  );

  // -------------------------------------------------------------------------
  // concurrent updates
  // -------------------------------------------------------------------------

  test('concurrent setTheme and setUseGps both apply', () async {
    final ProviderContainer container = await _makeLoadedContainer();
    final SettingsNotifier notifier = container.read(settingsProvider.notifier);

    await Future.wait(<Future<void>>[
      notifier.setTheme('dark'),
      notifier.setUseGps(value: false),
    ]);

    final SettingsState result = container.read(settingsProvider).requireValue;
    expect(result.theme, 'dark');
    expect(result.useGps, isFalse);
  });
}
