import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Returns a [MockClient] that responds with [status] and an optional [body].
http.Client mockClientReturning(int status, [String body = '']) =>
    MockClient((_) async => http.Response(body, status));

// 100 ms past the 2-second minimum splash floor in OnboardingScreen.
const Duration _splashClearDelay = Duration(milliseconds: 2100);

/// Pumps the splash screen and settles all resulting navigation animations.
///
/// Pass [hasSplashFloor]: true (default) when the test triggers the 2-second
/// minimum splash duration (fresh first launch, no steps done). Pass false
/// when the floor does not apply (returning user, mid-onboarding relaunch)
/// to avoid an unnecessary 2-second delay.
Future<void> pumpSplash(
  WidgetTester tester, {
  bool hasSplashFloor = true,
}) async {
  await tester.pump();
  if (hasSplashFloor) await tester.pump(_splashClearDelay);
  await tester.pumpAndSettle();
}
