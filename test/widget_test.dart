import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uvalert/app.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/screens/onboarding_screen.dart';

void main() {
  testWidgets('UvAlertApp shows OnboardingScreen on first launch', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const ProviderScope(child: UvAlertApp()));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('UvAlertApp shows DashboardScreen when not first launch', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'uvalert_first_launch': false,
    });

    await tester.pumpWidget(const ProviderScope(child: UvAlertApp()));
    await tester.pumpAndSettle();

    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('UvAlertApp shows loading indicator while preferences load', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const ProviderScope(child: UvAlertApp()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('UvAlertApp shows error message when preferences fail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        // overrideWith type inference is not exposed publicly
        // in flutter_riverpod
        // ignore: always_specify_types
        overrides: [
          preferencesProvider.overrideWith(
            (_) async => throw StateError('prefs unavailable'),
          ),
        ],
        child: const UvAlertApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load preferences.'), findsOneWidget);
  });
}
