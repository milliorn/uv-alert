import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uvalert/app.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/screens/onboarding_screen.dart';
import 'package:uvalert/screens/theme_onboarding_screen.dart';
import 'package:uvalert/storage/preferences.dart';

import 'helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('UvAlertApp always starts on OnboardingScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: UvAlertApp()));

    expect(find.byType(OnboardingScreen), findsOneWidget);
    await pumpSplash(tester);
  });

  testWidgets('UvAlertApp routes to ThemeOnboardingScreen on first launch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: UvAlertApp()));
    await pumpSplash(tester);

    expect(find.byType(ThemeOnboardingScreen), findsOneWidget);
  });

  testWidgets('UvAlertApp routes to DashboardScreen when not first launch', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      Preferences.keyFirstLaunchForTesting: false,
    });

    await tester.pumpWidget(const ProviderScope(child: UvAlertApp()));
    await pumpSplash(tester);

    expect(find.byType(DashboardScreen), findsOneWidget);
  });
}
