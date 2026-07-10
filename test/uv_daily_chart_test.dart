import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/utils/who_risk.dart';
import 'package:uvalert/widgets/uv_daily_chart.dart';

import 'fakes/fake_uv_data.dart';

/// First day used by [makeUvData]'s defaults, so daily fixtures line up.
///
/// Anchored to today (UTC midnight) rather than a fixed historical date,
/// because [UvDailyChart] now drops any daily entry whose location-local
/// date is in the past -- a hardcoded past date would be silently filtered
/// out of every fixture below.
final DateTime _day0 = () {
  final DateTime now = DateTime.now().toUtc();
  return DateTime.utc(now.year, now.month, now.day);
}();

/// Mirrors the widget's own weekday-abbreviation lookup, so tests can
/// derive expected labels from [_day0] instead of hardcoding a day-of-week
/// that would silently go stale once the date this file was written on has
/// passed.
const List<String> _weekdayAbbreviations = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

String _weekdayAbbreviation(DateTime date) =>
    _weekdayAbbreviations[date.weekday - 1];

/// Abbreviated weekday names for [_day0] and the six days after it.
final List<String> _weekdaysFromDay0 = <String>[
  for (int i = 0; i < 7; i++)
    _weekdayAbbreviation(_day0.add(Duration(days: i))),
];

List<UvForecastEntry> _dailyFrom(
  DateTime start,
  int count, {
  double Function(int day)? uviAt,
}) => <UvForecastEntry>[
  for (int i = 0; i < count; i++)
    UvForecastEntry(
      time: start.add(Duration(days: i)),
      uvi: uviAt != null ? uviAt(i) : 5,
    ),
];

Widget _wrap(UvData uvData, {double width = 400}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: width,
      height: 220,
      child: UvDailyChart(uvData: uvData),
    ),
  ),
);

BarChartData _chartData(WidgetTester tester) =>
    tester.widget<BarChart>(find.byType(BarChart)).data;

/// A [TitleMeta] fixture for directly invoking a [GetTitleWidgetFunction]
/// in tests; field values are arbitrary except where the widget under test
/// reads them.
TitleMeta _fakeTitleMeta() => TitleMeta(
  min: 0,
  max: 6,
  parentAxisSize: 100,
  axisPosition: 0,
  appliedInterval: 1,
  sideTitles: const SideTitles(),
  formattedValue: '',
  axisSide: AxisSide.bottom,
  rotationQuarterTurns: 0,
);

void main() {
  testWidgets('renders one bar group per daily entry, up to 7', (
    WidgetTester tester,
  ) async {
    final UvData uvData = makeUvData(daily: _dailyFrom(_day0, 7));

    await tester.pumpWidget(_wrap(uvData));

    final BarChartData data = _chartData(tester);
    expect(data.barGroups, hasLength(7));
    for (final BarChartGroupData group in data.barGroups) {
      expect(group.barRods, hasLength(1));
    }
  });

  testWidgets('trims to 7 bars when daily has more than 7 entries', (
    WidgetTester tester,
  ) async {
    final UvData uvData = makeUvData(daily: _dailyFrom(_day0, 8));

    await tester.pumpWidget(_wrap(uvData));

    expect(_chartData(tester).barGroups, hasLength(7));
  });

  testWidgets('renders fewer bars when daily has fewer than 7 entries', (
    WidgetTester tester,
  ) async {
    final UvData uvData = makeUvData(daily: _dailyFrom(_day0, 3));

    await tester.pumpWidget(_wrap(uvData));

    expect(_chartData(tester).barGroups, hasLength(3));
  });

  testWidgets('renders without error when daily is empty', (
    WidgetTester tester,
  ) async {
    // makeUvData()'s daily default is already an empty list; omitted here
    // to satisfy the analyzer, but that default is exactly what this test
    // exercises.
    final UvData uvData = makeUvData();

    await tester.pumpWidget(_wrap(uvData));

    expect(_chartData(tester).barGroups, isEmpty);
  });

  testWidgets(
    'renders one bar and one full-width semantics node when daily has '
    'exactly one entry',
    (WidgetTester tester) async {
      const double barWidth = 20; // must match _barWidth in the widget.
      final UvData uvData = makeUvData(daily: _dailyFrom(_day0, 1));

      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_wrap(uvData));

        expect(_chartData(tester).barGroups, hasLength(1));
        final SemanticsNode node = tester.getSemantics(
          find.bySemanticsLabel(RegExp('UV max')),
        );
        // With only one bar there is no neighbor on either side, so the
        // node's cell falls back to half the plot width -- still centered
        // on the single bar, not clipped to _barWidth.
        expect(node.rect.width, greaterThan(barWidth));
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets('orders bars chronologically even if daily is not', (
    WidgetTester tester,
  ) async {
    final UvData uvData = makeUvData(
      daily: <UvForecastEntry>[
        UvForecastEntry(time: _day0.add(const Duration(days: 2)), uvi: 3),
        UvForecastEntry(time: _day0, uvi: 1),
        UvForecastEntry(time: _day0.add(const Duration(days: 1)), uvi: 2),
      ],
    );

    await tester.pumpWidget(_wrap(uvData));

    final List<BarChartGroupData> groups = _chartData(tester).barGroups;
    expect(groups.map((BarChartGroupData g) => g.x), <int>[0, 1, 2]);
    expect(groups.map((BarChartGroupData g) => g.barRods.single.toY), <double>[
      1,
      2,
      3,
    ]);
  });

  group('stale-day filtering', () {
    testWidgets('drops daily entries dated before today, local time', (
      WidgetTester tester,
    ) async {
      final DateTime yesterday = _day0.subtract(const Duration(days: 1));
      final UvData uvData = makeUvData(
        daily: <UvForecastEntry>[
          UvForecastEntry(time: yesterday, uvi: 9),
          ..._dailyFrom(_day0, 2),
        ],
      );

      await tester.pumpWidget(_wrap(uvData));

      final List<BarChartGroupData> groups = _chartData(tester).barGroups;
      expect(groups, hasLength(2));
      expect(groups.first.barRods.single.toY, isNot(9));
    });

    testWidgets(
      'keeps an entry timestamped at the current moment, in a timezone '
      "where it's already tomorrow in UTC terms",
      (WidgetTester tester) async {
        // entry.time is "right now" (UTC), and a +23h offset shifts its
        // location-local reading almost a full day forward -- still not
        // before location-local "today", so it must not be dropped as
        // stale purely because of a large positive timezone offset.
        final DateTime rightNow = DateTime.now().toUtc();
        final UvData uvData = makeUvData(
          daily: <UvForecastEntry>[UvForecastEntry(time: rightNow, uvi: 5)],
          timezoneOffset: 23 * Duration.secondsPerHour,
        );

        await tester.pumpWidget(_wrap(uvData));

        expect(_chartData(tester).barGroups, hasLength(1));
      },
    );
  });

  group('WHO risk color mapping', () {
    testWidgets('each bar is colored per whoRiskColor for its UV value', (
      WidgetTester tester,
    ) async {
      final List<double> uvValues = <double>[1, 4, 6.5, 9, 12];
      final UvData uvData = makeUvData(
        daily: _dailyFrom(
          _day0,
          uvValues.length,
          uviAt: (int day) => uvValues[day],
        ),
      );

      await tester.pumpWidget(_wrap(uvData));

      final List<Color?> colors = _chartData(
        tester,
      ).barGroups.map((BarChartGroupData g) => g.barRods.single.color).toList();

      expect(colors, <Color>[
        whoColorLow,
        whoColorModerate,
        whoColorHigh,
        whoColorVeryHigh,
        whoColorExtreme,
      ]);
    });

    testWidgets('bar UV value label shows the truncated-to-tenth value', (
      WidgetTester tester,
    ) async {
      final UvData uvData = makeUvData(
        daily: _dailyFrom(_day0, 1, uviAt: (int day) => 5.04),
      );

      await tester.pumpWidget(_wrap(uvData));

      final BarChartRodLabel label = _chartData(
        tester,
      ).barGroups.single.barRods.single.label;
      expect(label.show, isTrue);
      expect(label.text, '5.0');
    });
  });

  group('day-of-week axis labels', () {
    testWidgets('labels bars with abbreviated day names in location-local '
        'time', (WidgetTester tester) async {
      // Base the fixture one day ahead of _day0, so a -1h offset (which
      // shifts each entry's location-local date a day earlier) still lands
      // on/after today -- otherwise the stale-day filter would drop the
      // shifted-to-yesterday entries this test relies on.
      final DateTime base = _day0.add(const Duration(days: 1));
      final UvData uvData = makeUvData(
        daily: _dailyFrom(base, 3),
        // -1 hour: a UTC timestamp of midnight becomes 11 PM the previous
        // local day, proving the axis uses location-local time, not
        // UTC/device time.
        timezoneOffset: -Duration.secondsPerHour,
      );

      await tester.pumpWidget(_wrap(uvData));

      final GetTitleWidgetFunction getTitlesWidget = _chartData(
        tester,
      ).titlesData.bottomTitles.sideTitles.getTitlesWidget;
      final TitleMeta meta = _fakeTitleMeta();

      Future<String?> labelAt(double value) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: getTitlesWidget(value, meta),
          ),
        );
        final Finder textFinder = find.byType(Text);
        if (textFinder.evaluate().isEmpty) return null;
        return tester.widget<Text>(textFinder).data;
      }

      // -1h local shifts each bar's local date to the day before its UTC
      // date, so bar 0 reads as the weekday before `base` -- i.e. _day0.
      expect(await labelAt(0), _weekdaysFromDay0[0]);
      expect(await labelAt(1), _weekdaysFromDay0[1]);
      expect(await labelAt(2), _weekdaysFromDay0[2]);
    });

    testWidgets('renders nothing for an axis value outside the bar range', (
      WidgetTester tester,
    ) async {
      final UvData uvData = makeUvData(daily: _dailyFrom(_day0, 2));

      await tester.pumpWidget(_wrap(uvData));

      final GetTitleWidgetFunction getTitlesWidget = _chartData(
        tester,
      ).titlesData.bottomTitles.sideTitles.getTitlesWidget;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: getTitlesWidget(5, _fakeTitleMeta()),
        ),
      );

      expect(find.byType(Text), findsNothing);
    });
  });

  group('accessibility semantics', () {
    testWidgets(
      'exposes one semantics node per daily bar with day, UV max, and risk',
      (WidgetTester tester) async {
        final UvData uvData = makeUvData(
          daily: _dailyFrom(
            _day0,
            3,
            uviAt: (int day) => <double>[1, 4, 9][day],
          ),
        );

        final String label0 = '${_weekdaysFromDay0[0]}, UV max 1.0, Low risk';
        final String label1 =
            '${_weekdaysFromDay0[1]}, UV max 4.0, Moderate risk';
        final String label2 =
            '${_weekdaysFromDay0[2]}, UV max 9.0, Very High risk';

        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_wrap(uvData));

          expect(
            tester.getSemantics(find.bySemanticsLabel(RegExp(label0))),
            matchesSemantics(label: label0),
          );
          expect(
            tester.getSemantics(find.bySemanticsLabel(RegExp(label1))),
            matchesSemantics(label: label1),
          );
          expect(
            tester.getSemantics(find.bySemanticsLabel(RegExp(label2))),
            matchesSemantics(label: label2),
          );
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets(
      "positions each semantics node at its bar's actual horizontal center",
      (WidgetTester tester) async {
        const double chartWidth = 400;
        const double barWidth = 20; // must match _barWidth in the widget.
        const int count = 7;
        final UvData uvData = makeUvData(daily: _dailyFrom(_day0, count));

        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_wrap(uvData));

          // Mirrors fl_chart's BarChartAlignment.spaceEvenly formula
          // (calculateGroupsX in bar_chart_data_extension.dart) so this
          // test fails if the semantics overlay ever drifts from the
          // chart's actual bar layout again.
          const double spaceAvailable = chartWidth - barWidth * count;
          const double eachSpace = spaceAvailable / (count + 1);
          double expectedCenter(int index) =>
              eachSpace * (index + 1) + barWidth * (index + 0.5);

          for (int i = 0; i < count; i++) {
            final String day = _weekdaysFromDay0[i];
            final SemanticsNode node = tester.getSemantics(
              find.bySemanticsLabel(RegExp('^${RegExp.escape(day)}, UV max')),
            );
            // node.transform is null when no translation is needed (e.g. a
            // node whose local origin already matches its parent's, such as
            // the leftmost cell) -- fall back to an identity translation of
            // 0 rather than assuming a transform always exists.
            final double translationX =
                node.transform?.getTranslation().x ?? 0;
            final double actualCenter = node.rect.center.dx + translationX;
            expect(
              actualCenter,
              closeTo(expectedCenter(i), 0.5),
              reason: 'bar $i ($day) semantics node is misaligned',
            );
          }
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets('excludes the visual chart canvas from the semantics tree', (
      WidgetTester tester,
    ) async {
      final UvData uvData = makeUvData(daily: _dailyFrom(_day0, 3));

      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_wrap(uvData));

        final SemanticsNode chartNode = tester.getSemantics(
          find.byType(BarChart),
        );
        expect(chartNode.label, isEmpty);
      } finally {
        handle.dispose();
      }
    });
  });
}
