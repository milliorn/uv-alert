import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uvalert/constants.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/screens/notification_onboarding_screen.dart';
import 'package:uvalert/screens/onboarding_progress_dots.dart';
import 'package:uvalert/storage/preferences.dart';

// ---------------------------------------------------------------------------
// Widget helper
// ---------------------------------------------------------------------------

Widget _wrap() => const ProviderScope(
  child: MaterialApp(home: NotificationOnboardingScreen()),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // -------------------------------------------------------------------------
  // Initial state
  // -------------------------------------------------------------------------

  testWidgets('renders with an explicit key', (WidgetTester tester) async {
    final Key key = UniqueKey();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: NotificationOnboardingScreen(key: key)),
      ),
    );
    expect(find.byKey(key), findsOneWidget);
  });

  testWidgets('shows Default Notifications and No Notifications options', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap());
    expect(find.text('Default Notifications'), findsOneWidget);
    expect(find.text('No Notifications'), findsOneWidget);
  });

  testWidgets('shows notifications header text', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.text('Notifications'), findsOneWidget);
  });

  testWidgets('shows settings note text', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap());
    expect(
      find.textContaining('More notification options can be found in Settings'),
      findsOneWidget,
    );
  });

  // -------------------------------------------------------------------------
  // Progress dots
  // -------------------------------------------------------------------------

  testWidgets('renders progress dots at step 3 of 3', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap());
    final OnboardingProgressDots dots = tester.widget<OnboardingProgressDots>(
      find.byType(OnboardingProgressDots),
    );
    expect(dots.current, equals(totalOnboardingSteps - 1));
    expect(dots.total, equals(totalOnboardingSteps));
  });

  // -------------------------------------------------------------------------
  // Default Notifications path
  // -------------------------------------------------------------------------

  testWidgets('tapping Default Notifications navigates to DashboardScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('Default Notifications'));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets(
    'tapping Default Notifications sets notificationsEnabled to true',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap());
      await tester.tap(find.text('Default Notifications'));
      await tester.pumpAndSettle();
      final Preferences prefs = await Preferences.load();
      expect(prefs.notificationsEnabled, isTrue);
    },
  );

  testWidgets('tapping Default Notifications sets isFirstLaunch to false', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('Default Notifications'));
    await tester.pumpAndSettle();
    final Preferences prefs = await Preferences.load();
    expect(prefs.isFirstLaunch, isFalse);
  });

  // -------------------------------------------------------------------------
  // No Notifications path
  // -------------------------------------------------------------------------

  testWidgets('tapping No Notifications navigates to DashboardScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('No Notifications'));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('tapping No Notifications leaves notificationsEnabled false', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('No Notifications'));
    await tester.pumpAndSettle();
    final Preferences prefs = await Preferences.load();
    expect(prefs.notificationsEnabled, isFalse);
  });

  testWidgets('tapping No Notifications sets isFirstLaunch to false', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('No Notifications'));
    await tester.pumpAndSettle();
    final Preferences prefs = await Preferences.load();
    expect(prefs.isFirstLaunch, isFalse);
  });

  // -------------------------------------------------------------------------
  // Error path
  // -------------------------------------------------------------------------

  testWidgets(
    'shows snackbar and re-enables buttons when preferencesProvider throws',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          // ignore: always_specify_types (overrides list type not in flutter_riverpod public API)
          overrides: [
            preferencesProvider.overrideWithValue(
              AsyncValue<Preferences>.error(
                Exception('prefs failed'),
                StackTrace.empty,
              )
            )
          ],
          child: const MaterialApp(home: NotificationOnboardingScreen()),
        ),
      );

      await tester.tap(find.text('No Notifications'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );

      // Buttons must be re-enabled so the user can retry.
      expect(find.text('Default Notifications'), findsOneWidget);
      expect(find.text('No Notifications'), findsOneWidget);
    },
  );
}
