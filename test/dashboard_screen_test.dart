import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uvalert/api/uv_api.dart';
import 'package:uvalert/constants.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/models/weather_alert.dart';
import 'package:uvalert/providers/app_version_provider.dart';
import 'package:uvalert/providers/location_provider.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/providers/uv_provider.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/screens/settings_screen.dart';
import 'package:uvalert/widgets/dashboard_footer.dart';
import 'package:uvalert/widgets/dashboard_hero.dart';
import 'package:uvalert/widgets/dashboard_no_data_view.dart';
import 'package:uvalert/widgets/uv_daily_chart.dart';
import 'package:uvalert/widgets/uv_hourly_chart.dart';

import 'fakes/fake_fixed_location_notifier.dart';
import 'fakes/fake_proxy_error_notifier.dart';
import 'fakes/fake_settings_notifier.dart';
import 'fakes/fake_uv_data.dart';
import 'fakes/fake_uv_notifier.dart';
import 'fakes/mock_uv_api.dart';

/// Day-of-week abbreviations, indexed by `DateTime.weekday - 1` (Monday =
/// index 0), matching [UvDailyChart]'s own bottom-axis and semantics labels.
const List<String> _weekdayAbbreviations = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

final WeatherAlert _heatAdvisory = WeatherAlert(
  id: 'NWS|Heat Advisory|2024-06-01T00:00:00.000Z',
  event: 'Heat Advisory',
  description: 'Dangerously high UV and heat index expected today.',
  start: DateTime.utc(2024, 6),
  end: DateTime.utc(2024, 6, 2),
  senderName: 'NWS',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(resetMocktailState);

  testWidgets('DashboardScreen renders the UV hero', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [
          uvProvider.overrideWith(() => FakeDataUvNotifier(makeUvData())),
        ],
        // Not const: every other call site in this file constructs
        // DashboardScreen() inside a const tree, which the compiler
        // canonicalizes into one shared instance -- coverage tooling then
        // credits the constructor only once, and inconsistently. This one
        // non-const call guarantees the constructor line is always counted.
        // ignore: prefer_const_constructors
        child: MaterialApp(home: DashboardScreen()),
      ),
    );

    expect(find.byType(DashboardHero), findsOneWidget);
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

    expect(find.byType(DashboardHero), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
  });

  testWidgets('does not render the alert banner when there is no active '
      'alert', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DashboardScreen())),
    );

    expect(find.text(_heatAdvisory.event), findsNothing);
  });

  testWidgets('renders the alert banner below the app bar when uvProvider '
      'has an active alert', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [
          uvProvider.overrideWith(
            () => FakeDataUvNotifier(
              makeUvData(alerts: <WeatherAlert>[_heatAdvisory]),
            ),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
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
    expect(find.byType(DashboardHero), findsNothing);
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
    expect(find.byType(DashboardHero), findsOneWidget);
  });

  testWidgets(
    'renders the hourly and daily charts with the populated forecast data '
    'from uvProvider',
    (WidgetTester tester) async {
      // UvDailyChart drops any daily entry whose location-local date is
      // before its own internal DateTime.now() read (see its own doc
      // comment). Anchoring the fixture's first entry one day past the
      // moment captured here, rather than at that moment itself, keeps it
      // ahead of UvDailyChart's own DateTime.now() read inside pumpWidget
      // even if a UTC midnight falls between the two reads, so the fixture
      // never straddles the chart's own staleness cutoff.
      final DateTime today = DateTime.now().toUtc();
      final DateTime firstEntryDate = DateTime.utc(
        today.year,
        today.month,
        today.day,
      ).add(const Duration(days: 1));
      final String firstEntryAbbreviation =
          _weekdayAbbreviations[firstEntryDate.weekday - 1];

      final UvData data = makeUvData(
        hourly: <UvForecastEntry>[
          UvForecastEntry(time: DateTime.utc(2024, 6, 1, 8), uvi: 2),
          UvForecastEntry(time: DateTime.utc(2024, 6, 1, 12), uvi: 7),
          UvForecastEntry(time: DateTime.utc(2024, 6, 1, 16), uvi: 4),
        ],
        daily: <UvForecastEntry>[
          UvForecastEntry(time: firstEntryDate, uvi: 7.5),
          UvForecastEntry(
            time: firstEntryDate.add(const Duration(days: 1)),
            uvi: 6,
          ),
        ],
      );

      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          ProviderScope(
            // ignore: always_specify_types - Override not in flutter_riverpod public API
            overrides: [
              uvProvider.overrideWith(() => FakeDataUvNotifier(data)),
            ],
            child: const MaterialApp(home: DashboardScreen()),
          ),
        );

        final UvHourlyChart hourlyChart = tester.widget(
          find.byType(UvHourlyChart),
        );
        final UvDailyChart dailyChart = tester.widget(
          find.byType(UvDailyChart),
        );

        expect(hourlyChart.uvData, data);
        expect(dailyChart.uvData, data);

        // Confirms the fed-in data actually reaches each chart's rendered
        // semantics tree, not just its constructor argument.
        expect(
          find.bySemanticsLabel('12:00 PM, UV index 7.0, High risk'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            '$firstEntryAbbreviation, UV max 7.5, Very High risk',
          ),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets('does not render the hourly or daily chart in the no-data '
      'state', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [uvProvider.overrideWith(FakeErrorUvNotifier.new)],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    expect(find.byType(UvHourlyChart), findsNothing);
    expect(find.byType(UvDailyChart), findsNothing);
  });

  testWidgets(
    'suppresses the hourly and daily charts when uvProvider still holds the '
    "previous location's data",
    (WidgetTester tester) async {
      final UvData data = makeUvData();
      final FakeDataUvNotifier notifier = FakeDataUvNotifier(data);

      final ProviderContainer container = ProviderContainer(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [
          uvProvider.overrideWith(() => notifier),
          locationProvider.overrideWith(LocationNotifier.new),
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

      expect(find.byType(UvHourlyChart), findsOneWidget);
      expect(find.byType(UvDailyChart), findsOneWidget);

      // uvProvider has no source-location field on UvData (see
      // dashboard_screen.dart's own comment on this), and a real UvNotifier
      // deliberately keeps serving the previous location's cached data
      // while a new fetch is in flight, so this simulates exactly that
      // window: locationProvider has already moved to the new location, but
      // uvProvider's value is still the same object fetched for the
      // original location.
      container.read(locationProvider.notifier).setManual(lat: 45, lon: 88);
      await tester.pump();

      expect(find.byType(UvHourlyChart), findsNothing);
      expect(find.byType(UvDailyChart), findsNothing);

      // Once uvProvider's value actually changes (by UvData's own value
      // equality) to data that arrived after the location change, the
      // mismatch clears and the charts return.
      notifier.updateData(makeUvData(currentUvi: 9));
      await tester.pump();

      expect(find.byType(UvHourlyChart), findsOneWidget);
      expect(find.byType(UvDailyChart), findsOneWidget);
    },
  );

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
        meta: any(named: 'meta'),
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
        meta: any(named: 'meta'),
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

  testWidgets(
    'hides the Retry button in the no-data state when the current proxy '
    'error is a 400 (an identical retry cannot succeed)',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          // ignore: always_specify_types - Override not in flutter_riverpod public API
          overrides: [
            uvProvider.overrideWith(
              () => FakeErrorUvNotifier(
                error: UvApiException(httpBadRequest, 'bad request'),
              ),
            ),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );

      expect(find.byType(DashboardNoDataView), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsNothing);
    },
  );

  testWidgets(
    'shows the Retry button when the current proxy error is a 500, even if '
    'immediateStatusCode is still sticky from an earlier interrupted 400',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          // ignore: always_specify_types - Override not in flutter_riverpod public API
          overrides: [
            uvProvider.overrideWith(
              () => FakeErrorUvNotifier(
                error: UvApiException(httpInternalServerError, 'server error'),
              ),
            ),
            proxyErrorProvider.overrideWith(
              () => FakeProxyErrorNotifier(
                const ProxyErrorState(immediateStatusCode: httpBadRequest),
              ),
            ),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );

      expect(find.byType(DashboardNoDataView), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    },
  );

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
          meta: any(named: 'meta'),
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
          meta: any(named: 'meta'),
        ),
      ).called(greaterThanOrEqualTo(1));
      verifyNever(
        () => mockApi.fetch(
          lat: 1,
          lon: 2,
          uuid: any(named: 'uuid'),
          appVersion: any(named: 'appVersion'),
          meta: any(named: 'meta'),
        ),
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Location restoration on cold launch
  // ---------------------------------------------------------------------------

  testWidgets('restores locationProvider from a saved manual location and '
      'auto-fetches UV data', (WidgetTester tester) async {
    final MockUvApi mockApi = MockUvApi();
    when(
      () => mockApi.fetch(
        lat: any(named: 'lat'),
        lon: any(named: 'lon'),
        uuid: any(named: 'uuid'),
        appVersion: any(named: 'appVersion'),
        meta: any(named: 'meta'),
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
        meta: any(named: 'meta'),
      ),
    ).called(1);
  });

  testWidgets('does not restore locationProvider when useGps is true', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      // ignore: always_specify_types - Override not in flutter_riverpod public API
      overrides: [
        uvProvider.overrideWith(FakeErrorUvNotifier.new),
        locationProvider.overrideWith(LocationNotifier.new),
        settingsProvider.overrideWith(
          () => FakeManualLocationSettingsNotifier.gps(
            name: 'New York, NY, US',
            lat: 40.7128,
            lon: -74.006,
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
  });

  testWidgets('does not overwrite an already-set locationProvider on rebuild', (
    WidgetTester tester,
  ) async {
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
  });
}
