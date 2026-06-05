import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/screens/onboarding_screen.dart';
import 'package:uvalert/storage/preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('OnboardingScreen constructs with an explicit key', (
    WidgetTester tester,
  ) async {
    // Use a non-const key so the constructor is called at runtime,
    // ensuring the super.key path is traced by the coverage tool.
    final Key key = UniqueKey();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: OnboardingScreen(key: key)),
      ),
    );

    expect(find.byKey(key), findsOneWidget);
  });

  testWidgets('OnboardingScreen renders all three theme cards', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );

    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('System Default'), findsOneWidget);
  });

  testWidgets('System Default card is pre-selected', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );

    // The check_circle icon only appears on the selected card.
    // There should be exactly one -- on System Default.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('tapping a theme card selects it', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
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

  testWidgets('tapping Continue navigates to DashboardScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('tapping Continue sets isFirstLaunch to false', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final Preferences prefs = await Preferences.load();
    expect(prefs.isFirstLaunch, isFalse);
  });

  testWidgets('tapping a card immediately writes theme to settingsProvider', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingScreen()),
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
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final Preferences prefs = await Preferences.load();
    expect(prefs.theme, ThemeMode.dark);
  });

  testWidgets(
    'listenManual syncs card when settings load with a stored non-default'
    ' theme',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'uvalert_theme': 'light',
      });

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
      );

      // Let settingsProvider finish loading so listenManual fires.
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

  testWidgets(
    'selected theme is in settingsProvider when Continue is tapped',
    (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: OnboardingScreen()),
        ),
      );

      await tester.tap(find.text('Dark'));
      await tester.pump();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final AsyncValue<SettingsState> settings = container.read(
        settingsProvider,
      );
      expect(settings.requireValue.themeMode, equals(ThemeMode.dark));
    },
  );

}
