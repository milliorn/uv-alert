import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uvalert/constants.dart';

/// Returns a [MockClient] that responds with [status] and an optional [body].
http.Client mockClientReturning(int status, [String body = '']) =>
    MockClient((_) async => http.Response(body, status));

/// Returns a [MockClient] that dispatches by path and query parameter:
/// - `/api/autocomplete?q=` → [autocompleteStatus]/[autocompleteBody]
/// - `/api/geocode?q=`      → [forwardStatus]/[forwardBody]
/// - `/api/geocode?lat=`    → [reverseStatus]/[reverseBody]
http.Client mockClientByQuery({
  int forwardStatus = 200,
  String forwardBody = '',
  int reverseStatus = 200,
  String reverseBody = '',
  int autocompleteStatus = 200,
  String autocompleteBody = '',
}) => MockClient((http.Request req) async {
  if (req.url.path == '/api/autocomplete') {
    return http.Response(autocompleteBody, autocompleteStatus);
  }
  if (req.url.queryParameters.containsKey('q')) {
    return http.Response(forwardBody, forwardStatus);
  }
  return http.Response(reverseBody, reverseStatus);
});

// 100 ms past the 2-second minimum splash floor in OnboardingScreen.
const Duration _splashClearDelay = Duration(milliseconds: 2100);

/// How far past [gpsTimeout] the fake GPS delay is set so the timeout fires.
const Duration gpsOvershoot = Duration(milliseconds: 100);

/// Extra buffer added to [gpsTimeout] for the per-test [Timeout] annotation.
const Duration gpsTestBuffer = Duration(seconds: 5);

/// Duration past the autocomplete debounce window; enough for the timer to
/// fire and the async geocode to complete before the next pump.
const Duration debounceFired = Duration(milliseconds: 500);

/// Duration within the debounce window; a pump this short must not trigger
/// autocomplete.
const Duration withinDebounce = Duration(milliseconds: 200);

/// Remaining debounce time after two [withinDebounce] pumps; ensures the
/// timer fires on the third pump.
const Duration debounceRemainder = Duration(milliseconds: 300);

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
