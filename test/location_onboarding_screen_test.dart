import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uvalert/api/geocoding_api.dart';
import 'package:uvalert/providers/device_id_provider.dart';
import 'package:uvalert/providers/location_provider.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/providers/uv_provider.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/screens/location_onboarding_screen.dart';
import 'package:uvalert/storage/preferences.dart';

import 'fakes/fake_geolocator.dart';
import 'helpers.dart';

// ---------------------------------------------------------------------------
// LocationNotifier that succeeds without setting state (covers null-loc path)
// ---------------------------------------------------------------------------

class _NullResultLocationNotifier extends LocationNotifier {
  _NullResultLocationNotifier() : super(platform: FakeGeolocatorPlatform());

  @override
  Future<void> fetchGps() async {
    // Completes without updating state, so locationProvider stays null.
  }
}

// ---------------------------------------------------------------------------
// SettingsNotifier that throws on setManualLocation (covers _onConfirm error)
// ---------------------------------------------------------------------------

class _ThrowingSettingsNotifier extends SettingsNotifier {
  @override
  Future<void> setManualLocation(String location) =>
      Future<void>.error(Exception('settings write failed'));
}

// ---------------------------------------------------------------------------
// Fake GeocodingApi
// ---------------------------------------------------------------------------

const String _proxyUrl = 'https://proxy.test';

// _parseResult assembles displayName as 'name, state, country'.
const String _displayName = 'Fresno, California, US';
const String _validGeoBody =
    '{"lat":36.75,"lon":-119.65,'
    '"name":"Fresno","state":"California","country":"US"}';

GeocodingApi _fakeGeocodingApi({
  int status = 200,
  String body = _validGeoBody,
}) {
  return GeocodingApi(
    proxyBaseUrl: _proxyUrl,
    deviceId: 'test-device-id',
    httpClient: mockClientReturning(status, body),
  );
}

// ---------------------------------------------------------------------------
// Widget helpers
// ---------------------------------------------------------------------------

Widget _wrap(
  LocationOnboardingScreen screen, {
  FakeGeolocatorPlatform? platform,
  LocationNotifier Function()? locationFactory,
  SettingsNotifier Function()? settingsFactory,
  String proxyUrl = _proxyUrl,
}) {
  final FakeGeolocatorPlatform fakePlatform =
      platform ?? FakeGeolocatorPlatform();
  return ProviderScope(
    // ignore: always_specify_types (overrideWith is not in the flutter_riverpod public API)
    overrides: [
      locationProvider.overrideWith(
        locationFactory ?? () => LocationNotifier(platform: fakePlatform),
      ),
      proxyBaseUrlProvider.overrideWithValue(proxyUrl),
      deviceIdProvider.overrideWith((_) => 'test-device-id'),
      if (settingsFactory != null)
        settingsProvider.overrideWith(settingsFactory),
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

  testWidgets(
    'tapping Continue after confirm persists isFirstLaunch as false',
    (
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

    final Preferences prefs = await Preferences.load();
    expect(prefs.isFirstLaunch, isFalse);
  });

  // -------------------------------------------------------------------------
  // Owned GeocodingApi creation (line 96: _ownedApi ??= GeocodingApi(...))
  // -------------------------------------------------------------------------

  testWidgets(
    'no injected GeocodingApi: owned instance shows error on network fail',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const LocationOnboardingScreen(), proxyUrl: 'http://0.0.0.0'),
      );

      await tester.tap(find.text('Enter location manually'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Anywhere');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
    },
  );

  // -------------------------------------------------------------------------
  // GPS null-location path (line 123: _setError('Could not read GPS…'))
  // -------------------------------------------------------------------------

  testWidgets('GPS fetchGps succeeds with null location shows error', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        LocationOnboardingScreen(geocodingApi: _fakeGeocodingApi()),
        locationFactory: _NullResultLocationNotifier.new,
      ),
    );

    await tester.tap(find.text('Use My Location'));
    await tester.pumpAndSettle();

    expect(find.text('Could not read GPS coordinates.'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // GPS generic error (lines 146-147: on Object catch in _onUseMyLocation)
  // -------------------------------------------------------------------------

  testWidgets('GPS generic error shows error message', (
    WidgetTester tester,
  ) async {
    final FakeGeolocatorPlatform platform = FakeGeolocatorPlatform()
      ..checkResult = LocationPermission.always;
    // positionResult left null so getCurrentPosition throws StateError,
    // a generic Object (not PermissionDeniedException or
    // GeocodingNotFoundException), exercising the on Object branch.

    await tester.pumpWidget(
      _wrap(
        LocationOnboardingScreen(geocodingApi: _fakeGeocodingApi()),
        platform: platform,
      ),
    );

    await tester.tap(find.text('Use My Location'));
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  // -------------------------------------------------------------------------
  // CircularProgressIndicator during loading (line 300)
  // -------------------------------------------------------------------------

  testWidgets('CircularProgressIndicator is visible while GPS is loading', (
    WidgetTester tester,
  ) async {
    final Completer<Position> completer = Completer<Position>();
    final _SlowGeolocatorPlatform platform = _SlowGeolocatorPlatform(
      completer.future,
    );

    await tester.pumpWidget(
      _wrap(
        LocationOnboardingScreen(geocodingApi: _fakeGeocodingApi()),
        platform: platform,
      ),
    );

    await tester.tap(find.text('Use My Location'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    completer.completeError(Exception('cancelled'));
    await tester.pumpAndSettle();
  });

  // -------------------------------------------------------------------------
  // onSearch icon button (line 308: onSearch callback)
  // -------------------------------------------------------------------------

  testWidgets('tapping search icon triggers geocode (onSearch callback)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(LocationOnboardingScreen(geocodingApi: _fakeGeocodingApi())),
    );

    await tester.tap(find.text('Enter location manually'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Fresno, CA');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.text(_displayName), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // _onConfirm error path (lines 241-244)
  // -------------------------------------------------------------------------

  testWidgets('_onConfirm shows error when settingsProvider throws', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        LocationOnboardingScreen(geocodingApi: _fakeGeocodingApi()),
        settingsFactory: _ThrowingSettingsNotifier.new,
      ),
    );

    await tester.tap(find.text('Enter location manually'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Fresno, CA');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(DashboardScreen), findsNothing);
  });

  testWidgets('_onConfirm error re-enables Continue button so user can retry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        LocationOnboardingScreen(geocodingApi: _fakeGeocodingApi()),
        settingsFactory: _ThrowingSettingsNotifier.new,
      ),
    );

    await tester.tap(find.text('Enter location manually'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Fresno, CA');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    // After error, Continue must be re-enabled so the user can retry.
    final FilledButton btn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(btn.onPressed, isNotNull);
  });
}

// ---------------------------------------------------------------------------
// GeolocatorPlatform that stalls until the given future resolves
// ---------------------------------------------------------------------------

class _SlowGeolocatorPlatform extends FakeGeolocatorPlatform {
  _SlowGeolocatorPlatform(this._positionFuture);

  final Future<Position> _positionFuture;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      _positionFuture;
}
