import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uvalert/api/uv_api.dart';
import 'package:uvalert/models/weather_alert.dart';
import 'package:uvalert/providers/app_version_provider.dart';
import 'package:uvalert/providers/location_provider.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/providers/uv_provider.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/screens/settings_screen.dart';
import 'package:uvalert/widgets/dashboard_footer.dart';
import 'package:uvalert/widgets/dashboard_no_data_view.dart';

import 'fakes/fake_fixed_location_notifier.dart';
import 'fakes/fake_settings_notifier.dart';
import 'fakes/fake_uv_data.dart';
import 'fakes/fake_uv_notifier.dart';
import 'fakes/mock_uv_api.dart';

const WeatherAlert _heatAdvisory = WeatherAlert(
  event: 'Heat Advisory',
  description: 'Dangerously high UV and heat index expected today.',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(resetMocktailState);

  testWidgets('DashboardScreen renders Dashboard text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [
          uvProvider.overrideWith(() => FakeDataUvNotifier(makeUvData())),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('DashboardScreen renders the footer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [
          uvProvider.overrideWith(() => FakeDataUvNotifier(makeUvData())),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    expect(find.byType(DashboardFooter), findsOneWidget);
  });

  testWidgets('DashboardScreen app bar has title and both icons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DashboardScreen())),
    );

    expect(find.text('UV Alert'), findsOneWidget);
    expect(find.byIcon(Icons.location_pin), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('DashboardScreen icons expose semantic labels', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DashboardScreen())),
    );

    expect(find.byTooltip('Change location'), findsOneWidget);
    expect(find.byTooltip('Open settings'), findsOneWidget);
  });

  testWidgets('Tapping the gear icon opens SettingsScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DashboardScreen())),
    );

    await tester.tap(find.byTooltip('Open settings'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('Tapping the location pin is a no-op', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [
          uvProvider.overrideWith(() => FakeDataUvNotifier(makeUvData())),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    await tester.tap(find.byTooltip('Change location'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
  });

  testWidgets('does not render the alert banner when there is no active '
      'alert', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DashboardScreen())),
    );

    expect(find.text(_heatAdvisory.event), findsNothing);
  });

  testWidgets('renders the alert banner below the app bar when an active '
      'alert is passed in', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DashboardScreen(activeAlert: _heatAdvisory)),
      ),
    );

    expect(find.text(_heatAdvisory.event), findsOneWidget);
    expect(find.text(_heatAdvisory.description), findsOneWidget);

    final double appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    final double bannerTop = tester
        .getTopLeft(find.text(_heatAdvisory.event))
        .dy;
    expect(bannerTop, greaterThanOrEqualTo(appBarBottom));
  });

  // ---------------------------------------------------------------------------
  // No-data state
  // ---------------------------------------------------------------------------

  testWidgets('shows DashboardNoDataView when uvProvider errors with no data', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [uvProvider.overrideWith(FakeErrorUvNotifier.new)],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    expect(find.byType(DashboardNoDataView), findsOneWidget);
    expect(
      find.text('No UV data available. Please check your connection.'),
      findsOneWidget,
    );
    expect(find.text('Dashboard'), findsNothing);
  });

  testWidgets('does not show DashboardNoDataView when data is present', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [
          uvProvider.overrideWith(() => FakeDataUvNotifier(makeUvData())),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    expect(find.byType(DashboardNoDataView), findsNothing);
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('tapping Retry triggers a fresh UV fetch', (
    WidgetTester tester,
  ) async {
    final MockUvApi mockApi = MockUvApi();
    when(
      () => mockApi.fetch(
        lat: any(named: 'lat'),
        lon: any(named: 'lon'),
        uuid: any(named: 'uuid'),
        appVersion: any(named: 'appVersion'),
      ),
    ).thenAnswer((_) async => makeUvData());

    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [
          uvProvider.overrideWith(() => FakeErrorUvNotifier(api: mockApi)),
          locationProvider.overrideWith(FakeFixedLocationNotifier.new),
          appVersionProvider.overrideWith((_) async => 'test-version'),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    expect(find.byType(DashboardNoDataView), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    verify(
      () => mockApi.fetch(
        lat: 36.75,
        lon: -119.65,
        uuid: any(named: 'uuid'),
        appVersion: any(named: 'appVersion'),
      ),
    ).called(1);
  });

  testWidgets('Retry button is present in the no-data state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [uvProvider.overrideWith(FakeErrorUvNotifier.new)],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
  });

  testWidgets('tapping Retry with no location acquired does not throw', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [uvProvider.overrideWith(FakeErrorUvNotifier.new)],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(DashboardNoDataView), findsOneWidget);
  });

  testWidgets(
    'tapping Retry right after a location change uses the new location, '
    'not a stale one',
    (WidgetTester tester) async {
      final MockUvApi mockApi = MockUvApi();
      when(
        () => mockApi.fetch(
          lat: any(named: 'lat'),
          lon: any(named: 'lon'),
          uuid: any(named: 'uuid'),
          appVersion: any(named: 'appVersion'),
        ),
      ).thenThrow(UvApiException(500, 'server error'));

      final ProviderContainer container = ProviderContainer(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [
          uvProvider.overrideWith(() => UvNotifier(api: mockApi)),
          locationProvider.overrideWith(LocationNotifier.new),
          appVersionProvider.overrideWith((_) async => 'test-version'),
        ],
      );
      addTearDown(container.dispose);

      container.read(locationProvider.notifier).setManual(lat: 1, lon: 2);
      await container.read(uvProvider.notifier).fetch(lat: 1, lon: 2);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();
      clearInteractions(mockApi);

      // Change location, then pump only a single frame -- not
      // pumpAndSettle -- so the tap below lands before UvNotifier's
      // auto-fetch microtask (triggered by its own watch of
      // locationProvider) has finished rebuilding DashboardScreen with the
      // new location.
      container.read(locationProvider.notifier).setManual(lat: 99, lon: 88);
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();

      verify(
        () => mockApi.fetch(
          lat: 99,
          lon: 88,
          uuid: any(named: 'uuid'),
          appVersion: any(named: 'appVersion'),
        ),
      ).called(greaterThanOrEqualTo(1));
      verifyNever(
        () => mockApi.fetch(
          lat: 1,
          lon: 2,
          uuid: any(named: 'uuid'),
          appVersion: any(named: 'appVersion'),
        ),
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Location restoration on cold launch
  // ---------------------------------------------------------------------------

  testWidgets(
    'restores locationProvider from a saved manual location and '
    'auto-fetches UV data',
    (WidgetTester tester) async {
      final MockUvApi mockApi = MockUvApi();
      when(
        () => mockApi.fetch(
          lat: any(named: 'lat'),
          lon: any(named: 'lon'),
          uuid: any(named: 'uuid'),
          appVersion: any(named: 'appVersion'),
        ),
      ).thenAnswer((_) async => makeUvData());

      final ProviderContainer container = ProviderContainer(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [
          uvProvider.overrideWith(() => UvNotifier(api: mockApi)),
          locationProvider.overrideWith(LocationNotifier.new),
          settingsProvider.overrideWith(
            () => FakeManualLocationSettingsNotifier(
              'New York, NY, US',
              40.7128,
              -74.006,
            ),
          ),
          appVersionProvider.overrideWith((_) async => 'test-version'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(locationProvider), (lat: 40.7128, lon: -74.006));
      verify(
        () => mockApi.fetch(
          lat: 40.7128,
          lon: -74.006,
          uuid: any(named: 'uuid'),
          appVersion: any(named: 'appVersion'),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'does not restore locationProvider when useGps is true',
    (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [
          uvProvider.overrideWith(FakeErrorUvNotifier.new),
          locationProvider.overrideWith(LocationNotifier.new),
          settingsProvider.overrideWith(
            () => FakeManualLocationSettingsNotifier.gps(
              'New York, NY, US',
              40.7128,
              -74.006,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // useGps: true means the manual coordinates above must be ignored.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(locationProvider), isNull);
    },
  );

  testWidgets(
    'does not overwrite an already-set locationProvider on rebuild',
    (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [
          uvProvider.overrideWith(() => FakeDataUvNotifier(makeUvData())),
          locationProvider.overrideWith(LocationNotifier.new),
          settingsProvider.overrideWith(
            () => FakeManualLocationSettingsNotifier(
              'New York, NY, US',
              40.7128,
              -74.006,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(locationProvider.notifier).setManual(lat: 1, lon: 2);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(locationProvider), (lat: 1.0, lon: 2.0));
    },
  );
}
