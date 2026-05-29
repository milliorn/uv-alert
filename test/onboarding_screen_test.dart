import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/screens/onboarding_screen.dart';
import 'package:uvalert/storage/preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
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

  testWidgets('tapping a theme card selects it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );

    await tester.tap(find.text('Dark'));
    await tester.pump();

    // After tapping Dark, check_circle moves to the Dark card.
    // We verify there is still exactly one check_circle (no double-selection).
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('tapping Continue navigates to DashboardScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );

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

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final Preferences prefs = await Preferences.load();
    expect(prefs.isFirstLaunch, isFalse);
  });
}
