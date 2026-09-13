import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/providers/location_provider.dart';
import 'package:uvalert/providers/uv_provider.dart';
import 'package:uvalert/services/solar_position.dart';
import 'package:uvalert/services/uv_interpolation.dart';
import 'package:uvalert/utils/time_format.dart';
import 'package:uvalert/widgets/dashboard_hero.dart';
import 'package:uvalert/widgets/uv_current_display.dart';
import 'package:uvalert/widgets/uv_hero_conditional_line.dart';

import 'fakes/fake_fixed_location_notifier.dart';
import 'fakes/fake_uv_data.dart';
import 'fakes/fake_uv_notifier.dart';

/// The hourly peak used by the interpolation fixture below, kept as a named
/// constant so the test's elevation-threshold math stays in sync with the
/// fixture value it is derived from.
const double _fixtureHourlyPeakUvi = 20;

Widget _wrap({
  required UvNotifier Function() uvNotifier,
  LocationNotifier Function()? locationNotifier,
}) => ProviderScope(
  // ignore: always_specify_types - Override not in flutter_riverpod public API
  overrides: [
    uvProvider.overrideWith(uvNotifier),
    if (locationNotifier != null)
      locationProvider.overrideWith(locationNotifier),
  ],
  // Not `const`: each call must construct a genuinely new DashboardHero
  // instance rather than reusing one frozen canonicalized const object
  // across every test, so the constructor line is credited by coverage the
  // same way a real (non-const) call site would be.
  // ignore: prefer_const_constructors
  child: MaterialApp(home: Scaffold(body: DashboardHero())),
);

void main() {
  testWidgets(
    'renders currentUvi directly when no location has been acquired yet',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(uvNotifier: () => FakeDataUvNotifier(makeUvData(currentUvi: 4))),
      );

      final UvCurrentDisplay display = tester.widget(
        find.byType(UvCurrentDisplay),
      );
      expect(display.uvIndex, 4);
      expect(find.byType(UvHeroConditionalLine), findsNothing);
    },
  );

  testWidgets(
    'renders the solar-interpolated value and conditional line when a '
    'location is available',
    (WidgetTester tester) async {
      // Captured once and reused for both the fixture's hourly anchor and
      // the expected-value comparison below, so the two agree on what
      // "today" is regardless of when this test actually runs.
      final DateTime nowUtc = DateTime.now().toUtc();
      // currentUvi (1) is deliberately distinct from the hourly peak (20):
      // with a correct location branch, peakUviForDay picks up 20 as UVmax,
      // so during the day the interpolated estimate is a value scaled from
      // 20, clearly not 1. This is what the day-branch assertion below
      // checks, so it actually fails if the widget silently bypassed
      // interpolation and passed currentUvi straight through instead.
      //
      // At night, interpolatedUvi's conservative-max step correctly
      // resolves to max(0, 1) = 1, coincidentally equal to currentUvi. This
      // is an inherent limitation of the conservative-max design itself
      // (see uv_interpolation_test.dart's own night-time tests), not
      // something this fixture can avoid without an injectable clock. The
      // day-branch assertion below is skipped in that case rather than
      // silently passing on a false premise.
      // Anchors both the captured nowUtc's calendar day and the day after,
      // so the widget's own DateTime.now() call (microseconds after nowUtc
      // is captured above) still finds an hourly entry on its own day even
      // if the two calls happen to straddle a UTC midnight boundary
      // (makeUvData defaults timezoneOffset to 0, so the local calendar day
      // here is the UTC calendar day).
      final UvData data = makeUvData(
        currentUvi: 1,
        hourly: <UvForecastEntry>[
          UvForecastEntry(time: nowUtc, uvi: _fixtureHourlyPeakUvi),
          UvForecastEntry(
            time: nowUtc.add(const Duration(days: 1)),
            uvi: _fixtureHourlyPeakUvi,
          ),
        ],
      );

      await tester.pumpWidget(
        _wrap(
          uvNotifier: () => FakeDataUvNotifier(data),
          locationNotifier: FakeFixedLocationNotifier.new,
        ),
      );

      const ({double lat, double lon}) fixedLocation = (
        lat: 36.75,
        lon: -119.65,
      );
      final double expectedUvi = displayUvi(
        data: data,
        location: fixedLocation,
        atUtc: nowUtc,
      );

      final UvCurrentDisplay display = tester.widget(
        find.byType(UvCurrentDisplay),
      );
      // Compares to within a small tolerance since `expectedUvi` and the
      // widget's own `DateTime.now()` call are computed microseconds apart.
      expect(display.uvIndex, closeTo(expectedUvi, 0.01));
      expect(find.byType(UvHeroConditionalLine), findsOneWidget);

      // Proves the widget actually took the location/interpolation branch
      // rather than silently falling back to a currentUvi passthrough, when
      // the sun is high enough at this location right now: with
      // currentUvi=1 and a real peak of 20, interpolatedUvi's
      // conservative-max step only exceeds currentUvi once
      // 20 * sin(elevation) > 1, i.e. elevation above asin(1/20), about
      // 2.87 degrees. Below that (including a barely-positive elevation
      // near sunrise/sunset), the correct result coincidentally equals
      // currentUvi too, so asserting greaterThan there would make this test
      // flaky depending on the instant it happens to run. A passthrough bug
      // would still render exactly 1 regardless of the real peak, so this
      // assertion only runs (and only proves anything) once elevation is
      // clearly past that threshold. See the fixture comment above for why
      // it is skipped, not silently passed, otherwise.
      final double elevation = solarElevationDegrees(
        lat: fixedLocation.lat,
        lon: fixedLocation.lon,
        utcTime: nowUtc,
      );
      final double minElevationForVisibleInterpolation =
          math.asin(data.currentUvi / _fixtureHourlyPeakUvi) * 180 / math.pi;
      if (elevation > minElevationForVisibleInterpolation) {
        expect(display.uvIndex, greaterThan(data.currentUvi));
      }
    },
  );

  testWidgets(
    'anchors solarEvents to the location-local calendar date, not '
    "nowUtc's own UTC date",
    (WidgetTester tester) async {
      // A non-zero, non-multiple-of-24h-aligned offset: with makeUvData's
      // default timezoneOffset of 0, toLocationLocal(nowUtc, 0) == nowUtc,
      // so no assertion here could ever distinguish the correct call from a
      // regression back to passing nowUtc directly. A large positive offset
      // makes that distinction meaningful for most of a UTC day (excluding
      // a window near UTC midnight where both computations still happen to
      // agree, an inherent limitation without an injectable clock, same as
      // the interpolation fixture above).
      const int nonZeroOffsetSeconds = 12 * 60 * 60;
      final DateTime nowUtc = DateTime.now().toUtc();
      final UvData data = makeUvData(timezoneOffset: nonZeroOffsetSeconds);

      await tester.pumpWidget(
        _wrap(
          uvNotifier: () => FakeDataUvNotifier(data),
          locationNotifier: FakeFixedLocationNotifier.new,
        ),
      );

      const ({double lat, double lon}) fixedLocation = (
        lat: 36.75,
        lon: -119.65,
      );
      final Map<SolarEvent, DateTime?> expectedSolarEvents = solarEventTimes(
        lat: fixedLocation.lat,
        lon: fixedLocation.lon,
        date: toLocationLocal(nowUtc, nonZeroOffsetSeconds),
      );
      final Map<SolarEvent, DateTime?> regressedSolarEvents = solarEventTimes(
        lat: fixedLocation.lat,
        lon: fixedLocation.lon,
        date: nowUtc,
      );

      final UvHeroConditionalLine conditionalLine = tester.widget(
        find.byType(UvHeroConditionalLine),
      );
      expect(conditionalLine.solarEvents, expectedSolarEvents);

      // Only meaningful once the local and UTC calendar dates actually
      // differ at this run instant (see the offset comment above); skipped,
      // not silently passed, otherwise.
      if (toLocationLocal(
            nowUtc,
            nonZeroOffsetSeconds,
          ).day !=
          nowUtc.day) {
        expect(conditionalLine.solarEvents, isNot(regressedSolarEvents));
      }
    },
  );

  testWidgets('renders nothing when uvProvider has no value', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(uvNotifier: FakeErrorUvNotifier.new));

    expect(find.byType(UvCurrentDisplay), findsNothing);
    expect(find.byType(UvHeroConditionalLine), findsNothing);
  });

  testWidgets(
    'periodic timer refreshes the hero and is cancelled on dispose, without '
    'triggering a fetch',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          uvNotifier: () => FakeDataUvNotifier(makeUvData(currentUvi: 1)),
          locationNotifier: FakeFixedLocationNotifier.new,
        ),
      );

      expect(find.byType(DashboardHero), findsOneWidget);

      final UvCurrentDisplay initialDisplay = tester.widget(
        find.byType(UvCurrentDisplay),
      );

      // Advances the test binding's virtual clock past one refresh interval
      // with no provider change at all, isolating the periodic Timer's own
      // contribution: a rebuild here can only be caused by the Timer firing,
      // not by ref.watch reacting to new state (see
      // dashboard_screen_test.dart for that separate case). Flutter builds
      // a fresh UvCurrentDisplay instance on every DashboardHero.build()
      // call regardless of whether uvIndex's value actually changed, so a
      // different widget instance (not equal value) is what proves the
      // rebuild happened.
      await tester.pump(const Duration(minutes: 1));

      final UvCurrentDisplay refreshedDisplay = tester.widget(
        find.byType(UvCurrentDisplay),
      );
      expect(identical(initialDisplay, refreshedDisplay), isFalse);

      // Tearing the widget down here must not leave a pending timer
      // (flutter_test fails the test at tearDown if any Timer is still
      // active): a passing test proves dispose() cancels the periodic Timer
      // correctly rather than leaking it. The absence of any registered UV
      // API mock also means a network fetch attempt at any point above
      // would surface as an unhandled call/error.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('periodic timer skips rebuilding when uvProvider has no value', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(uvNotifier: FakeErrorUvNotifier.new));

    expect(find.byType(UvCurrentDisplay), findsNothing);

    await tester.pump(const Duration(minutes: 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
