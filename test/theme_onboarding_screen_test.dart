import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/screens/location_onboarding_screen.dart';
import 'package:uvalert/screens/theme_onboarding_screen.dart';
import 'package:uvalert/storage/preferences.dart';

// SettingsNotifier that returns data immediately without reading preferences,
// so Continue is enabled even when preferencesProvider is overridden to error.
class _LoadedSettingsNotifier extends SettingsNotifier {
  @override
  AsyncValue<SettingsState> build() {
    return const AsyncValue<SettingsState>.data(
      SettingsState(
        themeMode: ThemeMode.system,
        useGps: false,
        manualLocation: null,
        notificationsEnabled: false,
      ),
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('ThemeOnboardingScreen constructs with an explicit key', (
    WidgetTester tester,
  ) async {
    final Key key = UniqueKey();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: ThemeOnboardingScreen(key: key)),
      ),
    );

    expect(find.byKey(key), findsOneWidget);
  });

  testWidgets('ThemeOnboardingScreen renders all three theme cards', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ThemeOnboardingScreen())),
    );

    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('System Default'), findsOneWidget);
  });

  testWidgets('System Default card is pre-selected', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ThemeOnboardingScreen())),
    );

    // The check_circle icon only appears on the selected card.
    // There should be exactly one -- on System Default.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('tapping a theme card selects it', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ThemeOnboardingScreen())),
    );

    await tester.tap(find.text('Dark'));
    await tester.pump();

    // After tapping Dark, check_circle must be inside the Dark card only.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<ThemeMode>(ThemeMode.dark)),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping Continue navigates to LocationOnboardingScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ThemeOnboardingScreen())),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(LocationOnboardingScreen), findsOneWidget);
  });

  testWidgets('tapping Continue sets isThemeStepDone to true', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ThemeOnboardingScreen())),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final Preferences prefs = await Preferences.load();
    expect(prefs.isThemeStepDone, isTrue);
  });

  testWidgets('tapping Continue does not clear isFirstLaunch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ThemeOnboardingScreen())),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final Preferences prefs = await Preferences.load();
    expect(prefs.isFirstLaunch, isTrue);
  });

  testWidgets('tapping a card immediately writes theme to settingsProvider', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ThemeOnboardingScreen()),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final AsyncValue<SettingsState> settings = container.read(settingsProvider);
    expect(settings.requireValue.themeMode, equals(ThemeMode.dark));
  });

  testWidgets('tapping a card writes theme to SharedPreferences', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ThemeOnboardingScreen())),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final Preferences prefs = await Preferences.load();
    expect(prefs.theme, ThemeMode.dark);
  });

  testWidgets(
    'card reflects stored non-default theme once settingsProvider loads',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'uvalert_theme': 'light',
      });

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ThemeOnboardingScreen())),
      );

      // Let settingsProvider finish loading so the card reflects stored theme.
      await tester.pumpAndSettle();

      // The Light card should now be selected (check_circle inside it only).
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<ThemeMode>(ThemeMode.light)),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('selected theme is in settingsProvider when Continue is tapped', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ThemeOnboardingScreen()),
      ),
    );

    await tester.tap(find.text('Dark'));
    await tester.pump();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final AsyncValue<SettingsState> settings = container.read(settingsProvider);
    expect(settings.requireValue.themeMode, equals(ThemeMode.dark));
  });

  testWidgets(
    'Continue shows snackbar and re-enables button when preferencesProvider '
    'throws',
    (WidgetTester tester) async {
      // _LoadedSettingsNotifier returns data immediately in build() so Continue
      // is enabled. preferencesProvider errors so _onContinue throws when it
      // calls ref.read(preferencesProvider.future) to write setThemeStepDone.
      await tester.pumpWidget(
        ProviderScope(
          // ignore: always_specify_types - Override not in flutter_riverpod public API
          overrides: [
            settingsProvider.overrideWith(_LoadedSettingsNotifier.new),
            preferencesProvider.overrideWithValue(
              AsyncValue<Preferences>.error(
                Exception('prefs failed'),
                StackTrace.empty,
              ),
            ),
          ],
          child: const MaterialApp(home: ThemeOnboardingScreen()),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );

      final FilledButton btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue'),
      );
      expect(btn.onPressed, isNotNull);
    },
  );
}
