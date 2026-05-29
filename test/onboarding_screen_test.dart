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

  testWidgets('OnboardingScreen renders Get Started button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );

    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('tapping Get Started navigates to DashboardScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('tapping Get Started sets isFirstLaunch to false', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    final Preferences prefs = await Preferences.load();
    expect(prefs.isFirstLaunch, isFalse);
  });
}
