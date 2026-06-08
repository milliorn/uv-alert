import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uvalert/api/geocoding_api.dart';
import 'package:uvalert/providers/location_provider.dart';
import 'package:uvalert/providers/uv_provider.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/screens/location_onboarding_screen.dart';

import 'fakes/fake_geolocator.dart';

// ---------------------------------------------------------------------------
// Fake GeocodingApi
// ---------------------------------------------------------------------------

const String _proxyUrl = 'https://proxy.test';
const String _displayName = 'Fresno, CA, US';
const String _validGeoBody =
    '{"lat":36.75,"lon":-119.65,"display_name":"$_displayName"}';

GeocodingApi _fakeGeocodingApi({
  int status = 200,
  String body = _validGeoBody,
}) {
  return GeocodingApi(
    proxyBaseUrl: _proxyUrl,
    httpClient: MockClient((_) async => http.Response(body, status)),
  );
}

// ---------------------------------------------------------------------------
// Widget helpers
// ---------------------------------------------------------------------------

Widget _wrap(
  LocationOnboardingScreen screen, {
  FakeGeolocatorPlatform? platform,
}) {
  final FakeGeolocatorPlatform fakePlatform =
      platform ?? FakeGeolocatorPlatform();
  return ProviderScope(
    // ignore: always_specify_types — Override not in flutter_riverpod public API
    overrides: [
      locationProvider.overrideWith(
        () => LocationNotifier(platform: fakePlatform),
      ),
      proxyBaseUrlProvider.overrideWithValue(_proxyUrl),
    ],
    child: MaterialApp(home: screen),
  );
}

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
      _wrap(
        LocationOnboardingScreen(key: key, geocodingApi: _fakeGeocodingApi()),
      ),
    );
    expect(find.byKey(key), findsOneWidget);
  });

  testWidgets('shows Use My Location and Enter manually buttons initially', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(LocationOnboardingScreen(geocodingApi: _fakeGeocodingApi())),
    );
    expect(find.text('Use My Location'), findsOneWidget);
    expect(find.text('Enter location manually'), findsOneWidget);
  });

  testWidgets('Continue button is disabled initially', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(LocationOnboardingScreen(geocodingApi: _fakeGeocodingApi())),
    );
    final FilledButton btn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('renders progress dots row', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(LocationOnboardingScreen(geocodingApi: _fakeGeocodingApi())),
    );
    expect(find.byType(LocationOnboardingScreen), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Manual entry flow
  // -------------------------------------------------------------------------

  testWidgets('tapping Enter manually reveals text field', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(LocationOnboardingScreen(geocodingApi: _fakeGeocodingApi())),
    );
    await tester.tap(find.text('Enter location manually'));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets(
    'submitting a manual query shows confirm card with display name',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(LocationOnboardingScreen(geocodingApi: _fakeGeocodingApi())),
      );

      await tester.tap(find.text('Enter location manually'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Fresno, CA');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text(_displayName), findsOneWidget);
    },
  );

  testWidgets('Continue is enabled after manual geocode succeeds', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(LocationOnboardingScreen(geocodingApi: _fakeGeocodingApi())),
    );

    await tester.tap(find.text('Enter location manually'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Fresno, CA');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final FilledButton btn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('geocoding 404 shows not-found error and stays on manual entry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        LocationOnboardingScreen(
          geocodingApi: _fakeGeocodingApi(status: 404, body: 'not found'),
        ),
      ),
    );

    await tester.tap(find.text('Enter location manually'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'nowhere');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(
      find.text('Location not found. Try a different search.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('geocoding 500 shows generic error and stays on manual entry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        LocationOnboardingScreen(
          geocodingApi: _fakeGeocodingApi(status: 500, body: 'error'),
        ),
      ),
    );

    await tester.tap(find.text('Enter location manually'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Fresno, CA');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('tapping Change from confirm card returns to manual entry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(LocationOnboardingScreen(geocodingApi: _fakeGeocodingApi())),
    );

    await tester.tap(find.text('Enter location manually'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Fresno, CA');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Change'));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(_displayName), findsNothing);
  });

  // -------------------------------------------------------------------------
  // GPS flow
  // -------------------------------------------------------------------------

  testWidgets('GPS grant shows confirm card after reverse geocode', (
    WidgetTester tester,
  ) async {
    final FakeGeolocatorPlatform platform = FakeGeolocatorPlatform()
      ..checkResult = LocationPermission.always
      ..positionResult = fakePosition(lat: 36.75, lon: -119.65);

    await tester.pumpWidget(
      _wrap(
        LocationOnboardingScreen(geocodingApi: _fakeGeocodingApi()),
        platform: platform,
      ),
    );

    await tester.tap(find.text('Use My Location'));
    await tester.pumpAndSettle();

    expect(find.text(_displayName), findsOneWidget);
  });

  testWidgets('GPS permission denied falls through to manual entry', (
    WidgetTester tester,
  ) async {
    final FakeGeolocatorPlatform platform = FakeGeolocatorPlatform()
      ..checkResult = LocationPermission.denied
      ..requestResult = LocationPermission.denied;

    await tester.pumpWidget(
      _wrap(
        LocationOnboardingScreen(geocodingApi: _fakeGeocodingApi()),
        platform: platform,
      ),
    );

    await tester.tap(find.text('Use My Location'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('GPS permission denied forever falls through to manual entry', (
    WidgetTester tester,
  ) async {
    final FakeGeolocatorPlatform platform = FakeGeolocatorPlatform()
      ..checkResult = LocationPermission.deniedForever;

    await tester.pumpWidget(
      _wrap(
        LocationOnboardingScreen(geocodingApi: _fakeGeocodingApi()),
        platform: platform,
      ),
    );

    await tester.tap(find.text('Use My Location'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('GPS reverse geocode 404 shows error message', (
    WidgetTester tester,
  ) async {
    final FakeGeolocatorPlatform platform = FakeGeolocatorPlatform()
      ..checkResult = LocationPermission.always
      ..positionResult = fakePosition();

    await tester.pumpWidget(
      _wrap(
        LocationOnboardingScreen(
          geocodingApi: _fakeGeocodingApi(status: 404, body: 'not found'),
        ),
        platform: platform,
      ),
    );

    await tester.tap(find.text('Use My Location'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not determine your city. Try entering it manually.'),
      findsOneWidget,
    );
  });

  // -------------------------------------------------------------------------
  // Continue navigates to Dashboard
  // -------------------------------------------------------------------------

  testWidgets('tapping Continue after confirm navigates to DashboardScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(LocationOnboardingScreen(geocodingApi: _fakeGeocodingApi())),
    );

    await tester.tap(find.text('Enter location manually'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Fresno, CA');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(DashboardScreen), findsOneWidget);
  });
}
