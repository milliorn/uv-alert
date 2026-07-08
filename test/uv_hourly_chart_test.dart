import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/utils/who_risk.dart';
import 'package:uvalert/widgets/uv_hourly_chart.dart';

import 'fakes/fake_uv_data.dart';

/// Sunrise used by [makeUvData]'s defaults, so hourly fixtures line up.
final DateTime _sunrise = DateTime.utc(2024, 6, 1, 6);

List<UvForecastEntry> _hourlyFrom(
  DateTime sunrise,
  int count, {
  double Function(int hour)? uviAt,
}) => <UvForecastEntry>[
  for (int i = 0; i < count; i++)
    UvForecastEntry(
      time: sunrise.add(Duration(hours: i)),
      uvi: uviAt != null ? uviAt(i) : 5,
    ),
];

Widget _wrap(UvData uvData, {double width = 400}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: width,
      height: 220,
      child: UvHourlyChart(uvData: uvData),
    ),
  ),
);

LineChartData _chartData(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data;

/// A [TitleMeta] fixture for directly invoking a [GetTitleWidgetFunction]
/// in tests; field values are arbitrary except where the widget under test
/// reads them.
TitleMeta _fakeTitleMeta() => TitleMeta(
  min: 0,
  max: 12,
  parentAxisSize: 100,
  axisPosition: 0,
  appliedInterval: 1,
  sideTitles: const SideTitles(),
  formattedValue: '',
  axisSide: AxisSide.left,
  rotationQuarterTurns: 0,
);

void main() {
  testWidgets('renders a LineChart spanning sunrise to sunset', (
    WidgetTester tester,
  ) async {
    final UvData uvData = makeUvData(
      sunrise: _sunrise,
      sunset: _sunrise.add(const Duration(hours: 14)),
      hourly: _hourlyFrom(_sunrise, 15),
    );

    await tester.pumpWidget(_wrap(uvData));

    final LineChartData data = _chartData(tester);
    expect(data.minX, 0);
    expect(data.maxX, 14);
    expect(data.lineBarsData, hasLength(1));
    expect(data.lineBarsData.single.spots, hasLength(15));
  });

  testWidgets('only plots hourly entries within sunrise-to-sunset', (
    WidgetTester tester,
  ) async {
    final DateTime sunset = _sunrise.add(const Duration(hours: 14));
    final UvData uvData = makeUvData(
      sunrise: _sunrise,
      sunset: sunset,
      hourly: <UvForecastEntry>[
        UvForecastEntry(
          time: _sunrise.subtract(const Duration(hours: 1)),
          uvi: 1,
        ),
        ..._hourlyFrom(_sunrise, 15),
        UvForecastEntry(time: sunset.add(const Duration(hours: 1)), uvi: 1),
      ],
    );

    await tester.pumpWidget(_wrap(uvData));

    expect(_chartData(tester).lineBarsData.single.spots, hasLength(15));
  });

  testWidgets('plots points in chronological order even if hourly is not', (
    WidgetTester tester,
  ) async {
    final UvData uvData = makeUvData(
      sunrise: _sunrise,
      sunset: _sunrise.add(const Duration(hours: 2)),
      hourly: <UvForecastEntry>[
        UvForecastEntry(time: _sunrise.add(const Duration(hours: 2)), uvi: 3),
        UvForecastEntry(time: _sunrise, uvi: 1),
        UvForecastEntry(time: _sunrise.add(const Duration(hours: 1)), uvi: 2),
      ],
    );

    await tester.pumpWidget(_wrap(uvData));

    final List<FlSpot> spots = _chartData(tester).lineBarsData.single.spots;
    expect(spots.map((FlSpot s) => s.x), <double>[0, 1, 2]);
    expect(spots.map((FlSpot s) => s.y), <double>[1, 2, 3]);
  });

  testWidgets('renders without error when hourly is empty', (
    WidgetTester tester,
  ) async {
    // makeUvData()'s hourly default is already an empty list; omitted here
    // to satisfy the analyzer, but that default is exactly what this test
    // exercises.
    final UvData uvData = makeUvData(
      sunrise: _sunrise,
      sunset: _sunrise.add(const Duration(hours: 14)),
    );

    await tester.pumpWidget(_wrap(uvData));

    expect(_chartData(tester).lineBarsData.single.spots, isEmpty);
  });

  group('WHO risk band background fills', () {
    testWidgets('draws all 5 WHO bands with their reference colors', (
      WidgetTester tester,
    ) async {
      final UvData uvData = makeUvData(
        sunrise: _sunrise,
        sunset: _sunrise.add(const Duration(hours: 14)),
        hourly: _hourlyFrom(_sunrise, 15),
      );

      await tester.pumpWidget(_wrap(uvData));

      final List<HorizontalRangeAnnotation> bands = _chartData(
        tester,
      ).rangeAnnotations.horizontalRangeAnnotations;

      expect(bands, hasLength(5));

      final Set<Color> opaqueBandColors = bands
          .map((HorizontalRangeAnnotation b) => b.color!.withValues(alpha: 1))
          .toSet();

      expect(
        opaqueBandColors,
        containsAll(<Color>[
          whoColorLow,
          whoColorModerate,
          whoColorHigh,
          whoColorVeryHigh,
          whoColorExtreme,
        ]),
      );
    });

    testWidgets('bands use a low opacity fill, not a solid color', (
      WidgetTester tester,
    ) async {
      final UvData uvData = makeUvData(
        sunrise: _sunrise,
        sunset: _sunrise.add(const Duration(hours: 14)),
        hourly: _hourlyFrom(_sunrise, 15),
      );

      await tester.pumpWidget(_wrap(uvData));

      final List<HorizontalRangeAnnotation> bands = _chartData(
        tester,
      ).rangeAnnotations.horizontalRangeAnnotations;

      for (final HorizontalRangeAnnotation band in bands) {
        expect(band.color!.a, lessThan(1));
        expect(band.color!.a, greaterThan(0));
      }
    });

    testWidgets('bands span y1/y2 at the WHO threshold boundaries', (
      WidgetTester tester,
    ) async {
      final UvData uvData = makeUvData(
        sunrise: _sunrise,
        sunset: _sunrise.add(const Duration(hours: 14)),
        hourly: _hourlyFrom(_sunrise, 15),
      );

      await tester.pumpWidget(_wrap(uvData));

      final List<HorizontalRangeAnnotation> bands = _chartData(
        tester,
      ).rangeAnnotations.horizontalRangeAnnotations;

      final List<double> boundaries = <double>[
        bands.first.y1,
        for (final HorizontalRangeAnnotation b in bands) b.y2,
      ];

      expect(boundaries, <double>[
        0,
        whoLowMax,
        whoModerateMax,
        whoHighMax,
        whoVeryHighMax,
        chartYAxisMax,
      ]);
    });

    testWidgets('left axis only labels values at WHO threshold boundaries', (
      WidgetTester tester,
    ) async {
      final UvData uvData = makeUvData(
        sunrise: _sunrise,
        sunset: _sunrise.add(const Duration(hours: 14)),
        hourly: _hourlyFrom(_sunrise, 15),
      );

      await tester.pumpWidget(_wrap(uvData));

      final GetTitleWidgetFunction getTitlesWidget = _chartData(
        tester,
      ).titlesData.leftTitles.sideTitles.getTitlesWidget;
      final TitleMeta meta = _fakeTitleMeta();

      Future<bool> hasLabelAt(double value) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: getTitlesWidget(value, meta),
          ),
        );
        return find.byType(Text).evaluate().isNotEmpty;
      }

      final List<double> whoBoundaries = <double>[
        0,
        whoLowMax,
        whoModerateMax,
        whoHighMax,
        whoVeryHighMax,
        chartYAxisMax,
      ];
      for (final double value in whoBoundaries) {
        expect(
          await hasLabelAt(value),
          isTrue,
          reason: 'expected a label at WHO boundary $value',
        );
      }

      final List<double> nonBoundaries = <double>[
        for (int i = 0; i <= chartYAxisMax; i++)
          if (!whoBoundaries.contains(i.toDouble())) i.toDouble(),
      ];
      for (final double value in nonBoundaries) {
        expect(
          await hasLabelAt(value),
          isFalse,
          reason: 'expected no label at non-boundary $value',
        );
      }
    });
  });

  group('hourly vs every-2-hours axis label fallback', () {
    testWidgets('uses a 1-hour interval when the chart is wide enough', (
      WidgetTester tester,
    ) async {
      final UvData uvData = makeUvData(
        sunrise: _sunrise,
        sunset: _sunrise.add(const Duration(hours: 6)),
        hourly: _hourlyFrom(_sunrise, 7),
      );

      await tester.pumpWidget(_wrap(uvData, width: 800));

      expect(_chartData(tester).titlesData.bottomTitles.sideTitles.interval, 1);
    });

    testWidgets('falls back to a 2-hour interval on a narrow chart', (
      WidgetTester tester,
    ) async {
      final UvData uvData = makeUvData(
        sunrise: _sunrise,
        sunset: _sunrise.add(const Duration(hours: 14)),
        hourly: _hourlyFrom(_sunrise, 15),
      );

      await tester.pumpWidget(_wrap(uvData, width: 200));

      expect(_chartData(tester).titlesData.bottomTitles.sideTitles.interval, 2);
    });
  });

  group('accessibility semantics', () {
    testWidgets(
      'exposes one semantics node per hourly point with time, UV, and risk',
      (WidgetTester tester) async {
        final UvData uvData = makeUvData(
          sunrise: _sunrise,
          sunset: _sunrise.add(const Duration(hours: 2)),
          hourly: _hourlyFrom(
            _sunrise,
            3,
            uviAt: (int hour) => <double>[1, 4, 9][hour],
          ),
        );

        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_wrap(uvData));

          expect(
            tester.getSemantics(
              find.bySemanticsLabel(RegExp('6:00 AM, UV index 1.0, Low risk')),
            ),
            matchesSemantics(label: '6:00 AM, UV index 1.0, Low risk'),
          );
          expect(
            tester.getSemantics(
              find.bySemanticsLabel(
                RegExp('7:00 AM, UV index 4.0, Moderate risk'),
              ),
            ),
            matchesSemantics(label: '7:00 AM, UV index 4.0, Moderate risk'),
          );
          expect(
            tester.getSemantics(
              find.bySemanticsLabel(
                RegExp('8:00 AM, UV index 9.0, Very High risk'),
              ),
            ),
            matchesSemantics(label: '8:00 AM, UV index 9.0, Very High risk'),
          );
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets('excludes the visual chart canvas from the semantics tree', (
      WidgetTester tester,
    ) async {
      final UvData uvData = makeUvData(
        sunrise: _sunrise,
        sunset: _sunrise.add(const Duration(hours: 2)),
        hourly: _hourlyFrom(_sunrise, 3),
      );

      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_wrap(uvData));

        final SemanticsNode chartNode = tester.getSemantics(
          find.byType(LineChart),
        );
        expect(chartNode.label, isEmpty);
      } finally {
        handle.dispose();
      }
    });
  });
}
