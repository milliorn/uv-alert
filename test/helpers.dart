import 'package:flutter_test/flutter_test.dart';

// 100 ms past the 2-second minimum splash floor in OnboardingScreen.
const Duration _splashClearDelay = Duration(milliseconds: 2100);

/// Pumps the splash screen past the 2-second minimum splash floor and settles
/// all resulting navigation animations.
Future<void> pumpSplash(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(_splashClearDelay);
  await tester.pumpAndSettle();
}
