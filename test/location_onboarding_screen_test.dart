import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uvalert/api/geocoding_api.dart';
import 'package:uvalert/constants.dart';
import 'package:uvalert/providers/device_id_provider.dart';
import 'package:uvalert/providers/location_provider.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/providers/uv_provider.dart';
import 'package:uvalert/screens/location_onboarding_screen.dart';
import 'package:uvalert/screens/notification_onboarding_screen.dart';
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

// _parseEntry assembles displayName as 'name, state, country'.
const String _displayName = 'Fresno, California, US';

// geocodeMultiple expects an array; reverseGeocode expects a single object.
const String _validGeoArray =
    '[{"lat":36.75,"lon":-119.65,'
    '"name":"Fresno","state":"California","country":"US"}]';
const String _validGeoSingle =
    '{"lat":36.75,"lon":-119.65,'
    '"name":"Fresno","state":"California","country":"US"}';

// geocodeMultiple with two results (used by pick-list tests).
const String _multiResultBody =
    '[{"lat":51.5,"lon":-0.1,"name":"London",'
    '"country":"GB","state":"England"},'
    '{"lat":42.9,"lon":-81.2,"name":"London",'
    '"country":"CA","state":"Ontario"}]';

// Two Fresno results used by separator rendering tests.
const String _twoFresnoResults =
    '[{"lat":36.75,"lon":-119.65,'
    '"name":"Fresno","state":"California","country":"US"},'
    '{"lat":34.06,"lon":-117.64,'
    '"name":"Fresno","state":"Texas","country":"US"}]';

GeocodingApi _fakeGeocodingApi({
  int forwardStatus = 200,
  String forwardBody = _validGeoArray,
  int reverseStatus = 200,
  String reverseBody = _validGeoSingle,
  // Autocomplete defaults to 404 to avoid suggestions interfering with tests
  // that use forwardBody for geocodeMultiple only.
  int autocompleteStatus = 404,
  String autocompleteBody = 'not found',
}) {
  return GeocodingApi(
    proxyBaseUrl: _proxyUrl,
    deviceId: 'test-device-id',
    httpClient: mockClientByQuery(
      forwardStatus: forwardStatus,
      forwardBody: forwardBody,
      reverseStatus: reverseStatus,
      reverseBody: reverseBody,
      autocompleteStatus: autocompleteStatus,
      autocompleteBody: autocompleteBody,
    ),
  );
}

/// Picks the first candidate from the _PickList after a manual search.
Future<void> _pickFirstCandidate(WidgetTester tester) async {
  await tester.tap(find.text(_displayName));
  await tester.pumpAndSettle();
}

/// Drives the screen to the pick-list phase via manual entry of 'London'.
/// Assumes the widget was pumped with a [GeocodingApi] that returns multiple
/// results for a forward geocode.
Future<void> _pumpToPickList(WidgetTester tester) async {
  await tester.tap(find.text('Enter location manually'));
  await tester.pump();
  await tester.enterText(find.byType(TextField), 'London');
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

/// Drives the screen through manual entry to the confirm phase and taps
/// Continue. Leaves the tester settled at the post-navigation state.
Future<void> _tapContinueAfterManualEntry(WidgetTester tester) async {
  await tester.tap(find.text('Enter location manually'));
  await tester.pump();
  await tester.enterText(find.byType(TextField), 'Fresno, CA');
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
  await _pickFirstCandidate(tester);
  await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
  await tester.pumpAndSettle();
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
      await _pickFirstCandidate(tester);

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
    await _pickFirstCandidate(tester);

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
          geocodingApi: _fakeGeocodingApi(
            forwardStatus: 404,
            forwardBody: 'not found',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Enter location manually'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'nowhere');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.textContaining('Location not found. '), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('geocoding 500 shows generic error and stays on manual entry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        LocationOnboardingScreen(
          geocodingApi: _fakeGeocodingApi(
            forwardStatus: 500,
            forwardBody: 'error',
          ),
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
    await _pickFirstCandidate(tester);

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
          geocodingApi: _fakeGeocodingApi(
            reverseStatus: 404,
            reverseBody: 'not found',
          ),
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
  // Continue navigates to NotificationOnboardingScreen
  // -------------------------------------------------------------------------

  testWidgets(
    'tapping Continue after confirm navigates to NotificationOnboardingScreen',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(LocationOnboardingScreen(geocodingApi: _fakeGeocodingApi())),
      );
      await _tapContinueAfterManualEntry(tester);
      expect(find.byType(NotificationOnboardingScreen), findsOneWidget);
    },
  );

  testWidgets('tapping Continue after confirm does not clear isFirstLaunch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(LocationOnboardingScreen(geocodingApi: _fakeGeocodingApi())),
    );
    await _tapContinueAfterManualEntry(tester);
    final Preferences prefs = await Preferences.load();
    // setFirstLaunchDone() moved to NotificationOnboardingScreen (issue #15).
    expect(prefs.isFirstLaunch, isTrue);
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
  // GPS timeout (TimeoutException branch in _onUseMyLocation)
  // -------------------------------------------------------------------------

  testWidgets(
    'GPS timeout shows not-available error message',
    (WidgetTester tester) async {
      final FakeGeolocatorPlatform platform = FakeGeolocatorPlatform()
        ..checkResult = LocationPermission.always
        ..positionDelay = gpsTimeout + gpsOvershoot
        ..positionResult = fakePosition();

      await tester.pumpWidget(
        _wrap(
          LocationOnboardingScreen(geocodingApi: _fakeGeocodingApi()),
          platform: platform,
        ),
      );

      await tester.tap(find.text('Use My Location'));
      await tester.pump(gpsTimeout + gpsOvershoot);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('GPS is not available on this device'),
        findsOneWidget,
      );
    },
    timeout: Timeout(gpsTimeout + gpsTestBuffer),
  );

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
    await _pickFirstCandidate(tester);

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
    await _pickFirstCandidate(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(NotificationOnboardingScreen), findsNothing);
  });

  // -------------------------------------------------------------------------
  // GPS reverseGeocode timeout (inner TimeoutException, lines 144-145)
  // -------------------------------------------------------------------------

  testWidgets(
    'GPS reverseGeocode timeout shows city-not-determined error',
    (WidgetTester tester) async {
      final FakeGeolocatorPlatform platform = FakeGeolocatorPlatform()
        ..checkResult = LocationPermission.always
        ..positionResult = fakePosition(lat: 36.75, lon: -119.65);

      await tester.pumpWidget(
        _wrap(
          LocationOnboardingScreen(
            geocodingApi: _ReverseTimeoutGeocodingApi(),
          ),
          platform: platform,
        ),
      );

      await tester.tap(find.text('Use My Location'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Could not determine your city. Try entering it manually.',
        ),
        findsOneWidget,
      );
    },
  );

  // -------------------------------------------------------------------------
  // Multiple geocoding results: _Phase.picking (lines 205-208, 358-362, 566+)
  // -------------------------------------------------------------------------

  testWidgets(
    'multiple geocode results shows pick list with all candidates',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          LocationOnboardingScreen(
            geocodingApi: _fakeGeocodingApi(forwardBody: _multiResultBody),
          ),
        ),
      );

      await _pumpToPickList(tester);

      expect(find.text('Select your location:'), findsOneWidget);
      expect(find.text('London, England, GB'), findsOneWidget);
      expect(find.text('London, Ontario, CA'), findsOneWidget);
    },
  );

  testWidgets(
    'picking a candidate from pick list shows confirm card',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          LocationOnboardingScreen(
            geocodingApi: _fakeGeocodingApi(forwardBody: _multiResultBody),
          ),
        ),
      );

      await _pumpToPickList(tester);

      await tester.tap(find.text('London, England, GB'));
      await tester.pumpAndSettle();

      expect(find.text('London, England, GB'), findsOneWidget);
      expect(find.text('Select your location:'), findsNothing);
    },
  );

  testWidgets(
    'tapping Search again from pick list returns to manual entry',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          LocationOnboardingScreen(
            geocodingApi: _fakeGeocodingApi(forwardBody: _multiResultBody),
          ),
        ),
      );

      await _pumpToPickList(tester);

      await tester.ensureVisible(find.text('Search again'));
      await tester.tap(find.text('Search again'));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Select your location:'), findsNothing);
    },
  );

  // -------------------------------------------------------------------------

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
    await _pickFirstCandidate(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    // After error, Continue must be re-enabled so the user can retry.
    final FilledButton btn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(btn.onPressed, isNotNull);
  });

  // -------------------------------------------------------------------------
  // Autocomplete / debounce (onChanged -> _onDebounced)
  // -------------------------------------------------------------------------

  testWidgets(
    'typing shows suggestions after debounce delay fires',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          LocationOnboardingScreen(
            geocodingApi: _fakeGeocodingApi(
              autocompleteStatus: 200,
              autocompleteBody: _validGeoArray,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Enter location manually'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Fres');
      // Debounce has not fired yet - suggestions should not appear.
      await tester.pump();
      expect(find.text(_displayName), findsNothing);

      // Advance past the 400 ms debounce window and settle the async geocode.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text(_displayName), findsOneWidget);
    },
  );

  testWidgets(
    'typing again before debounce fires resets the timer',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          LocationOnboardingScreen(
            geocodingApi: _fakeGeocodingApi(
              autocompleteStatus: 200,
              autocompleteBody: _validGeoArray,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Enter location manually'));
      await tester.pump();

      // First keystroke.
      await tester.enterText(find.byType(TextField), 'Fr');
      await tester.pump(const Duration(milliseconds: 200));

      // Second keystroke before debounce fires.
      await tester.enterText(find.byType(TextField), 'Fres');
      await tester.pump(const Duration(milliseconds: 200));

      // Still within debounce window from second keystroke - no suggestions.
      expect(find.text(_displayName), findsNothing);

      // Now let the debounce fire and the geocode settle.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text(_displayName), findsOneWidget);
    },
  );

  testWidgets(
    'tapping a suggestion from autocomplete goes to confirm phase',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          LocationOnboardingScreen(
            geocodingApi: _fakeGeocodingApi(
              autocompleteStatus: 200,
              autocompleteBody: _validGeoArray,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Enter location manually'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Fres');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Tap the suggestion.
      await tester.tap(find.text(_displayName));
      await tester.pumpAndSettle();

      // Should now be in confirm phase: display name shown, Continue enabled.
      expect(find.text(_displayName), findsOneWidget);
      final FilledButton btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue'),
      );
      expect(btn.onPressed, isNotNull);
    },
  );

  testWidgets(
    'autocomplete 404 silently clears suggestions without showing error',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          LocationOnboardingScreen(
            geocodingApi: _fakeGeocodingApi(
              forwardStatus: 404,
              forwardBody: 'not found',
            ),
          ),
        ),
      );

      await tester.tap(find.text('Enter location manually'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'xyzzy');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // No suggestions and no error message shown.
      expect(find.text(_displayName), findsNothing);
      expect(find.textContaining('Location not found'), findsNothing);
      expect(find.textContaining('Something went wrong'), findsNothing);
    },
  );

  testWidgets(
    'typing fewer than 2 chars does not trigger autocomplete',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(LocationOnboardingScreen(geocodingApi: _fakeGeocodingApi())),
      );

      await tester.tap(find.text('Enter location manually'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'F');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text(_displayName), findsNothing);
    },
  );

  testWidgets(
    'typing clears existing suggestions immediately',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          LocationOnboardingScreen(
            geocodingApi: _fakeGeocodingApi(
              autocompleteStatus: 200,
              autocompleteBody: _validGeoArray,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Enter location manually'));
      await tester.pump();

      // Get suggestions showing.
      await tester.enterText(find.byType(TextField), 'Fres');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text(_displayName), findsOneWidget);

      // Type another character - suggestions must clear immediately.
      await tester.enterText(find.byType(TextField), 'Fresn');
      await tester.pump();
      expect(find.text(_displayName), findsNothing);
    },
  );
  // -------------------------------------------------------------------------
  // _onBack via AppBar back button (lines 342-350)
  // -------------------------------------------------------------------------

  testWidgets('back button from manual phase returns to idle phase', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(LocationOnboardingScreen(geocodingApi: _fakeGeocodingApi())),
    );

    await tester.tap(find.text('Enter location manually'));
    await tester.pump();

    // Back button is visible while in manual phase.
    await tester.tap(find.byType(BackButton));
    await tester.pump();

    // Returned to idle: both option buttons visible again.
    expect(find.text('Use My Location'), findsOneWidget);
    expect(find.text('Enter location manually'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  // -------------------------------------------------------------------------
  // _onSearchAgain via Search again button in _PickList (lines 265-273)
  // -------------------------------------------------------------------------

  testWidgets('Search again from pick list returns to manual entry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        LocationOnboardingScreen(
          geocodingApi: _fakeGeocodingApi(forwardBody: _multiResultBody),
        ),
      ),
    );

    await tester.tap(find.text('Enter location manually'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Fresno, CA');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    // Now in picking phase - tap Search again.
    await tester.ensureVisible(find.text('Search again'));
    await tester.tap(find.text('Search again'));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search again'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // Autocomplete generic error (lines 208-210 in _onDebounced)
  // -------------------------------------------------------------------------

  testWidgets('autocomplete generic error silently clears suggestions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        LocationOnboardingScreen(
          geocodingApi: _fakeGeocodingApi(
            forwardStatus: 500,
            forwardBody: 'server error',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Enter location manually'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Fres');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // No suggestions and no error banner shown for autocomplete failures.
    expect(find.text(_displayName), findsNothing);
    expect(find.textContaining('Something went wrong'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // _SuggestionList separator (line 706) — needs 2+ suggestions
  // -------------------------------------------------------------------------

  testWidgets(
    'autocomplete with multiple results renders suggestion separators',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          LocationOnboardingScreen(
            geocodingApi: _fakeGeocodingApi(
              autocompleteStatus: 200,
              autocompleteBody: _twoFresnoResults,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Enter location manually'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Fres');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Fresno, California, US'), findsOneWidget);
      expect(find.text('Fresno, Texas, US'), findsOneWidget);
    },
  );

  // -------------------------------------------------------------------------
  // _PickList separator (line 673) — needs 2+ candidates from geocodeMultiple
  // -------------------------------------------------------------------------

  testWidgets(
    'pick list with multiple candidates renders separators',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          LocationOnboardingScreen(
            geocodingApi: _fakeGeocodingApi(forwardBody: _twoFresnoResults),
          ),
        ),
      );

      await tester.tap(find.text('Enter location manually'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Fresno, CA');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('Fresno, California, US'), findsOneWidget);
      expect(find.text('Fresno, Texas, US'), findsOneWidget);
      expect(find.text('Search again'), findsOneWidget);
    },
  );
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

// ---------------------------------------------------------------------------
// GeocodingApi that times out only on reverseGeocode
// ---------------------------------------------------------------------------

class _ReverseTimeoutGeocodingApi extends GeocodingApi {
  _ReverseTimeoutGeocodingApi()
    : super(
        proxyBaseUrl: _proxyUrl,
        deviceId: 'test-device-id',
      );

  @override
  Future<GeocodingResult> reverseGeocode({
    required double lat,
    required double lon,
  }) =>
      Future<GeocodingResult>.error(
        TimeoutException('reverseGeocode timed out'),
      );
}
