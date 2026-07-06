import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/utils/who_risk.dart';

/// Height reserved for the bottom (time) axis titles.
const double _bottomTitleReservedSize = 28;

/// Height reserved for the left (UV index) axis titles.
const double _leftTitleReservedSize = 32;

/// Chart line stroke width.
const double _lineStrokeWidth = 3;

/// Radius of the dot drawn at each data point.
const double _dotRadius = 2.5;

/// Fixed y-axis upper bound.
///
/// The WHO "Extreme" band is open-ended (11+), so the chart caps its
/// vertical scale here; real-world UV indices essentially never exceed
/// this in practice.
const double _yAxisMax = 12;

/// Below this pixel width per hourly label, hour labels would visually
/// overlap, so the chart falls back to showing every 2 hours instead.
const double _minPixelsPerHourLabel = 36;

/// Approximate width, in logical pixels, of a single hour-label such as
/// "2 PM", used to decide whether hourly labels fit without overlapping.
const double _estimatedHourLabelWidth = 32;

/// The upper bound of the WHO "Extreme" band drawn on the chart background.
///
/// The real WHO "Extreme" band is open-ended (11+); the chart draws its
/// fill up to [_yAxisMax] since that is the top of the visible chart.
const double _whoExtremeMax = _yAxisMax;

/// A single hourly UV reading positioned along the chart's x-axis.
///
/// `hours` is the fractional number of hours since sunrise (the chart's
/// x-coordinate); `localTime` is the reading's timestamp in the queried
/// location's local time (not the device's).
typedef _ChartPoint = ({
  double hours,
  DateTime localTime,
  UvForecastEntry entry,
});

/// A static hourly UV index line chart, spanning sunrise to sunset.
///
/// Draws WHO risk-band background fills, an hourly (or every-2-hours,
/// if labels would overlap) time axis, and a UV index axis at the WHO
/// threshold boundaries. Does not support scrub/press interaction -- see
/// the "Out of scope" note on the originating issue for that follow-up.
class UvHourlyChart extends StatelessWidget {
  /// Creates a [UvHourlyChart] from the hourly forecast entries in [uvData]
  /// that fall between its sunrise and sunset.
  const UvHourlyChart({required this.uvData, super.key});

  /// The UV data to chart; only [UvData.hourly] entries between
  /// [UvData.sunrise] and [UvData.sunset] are shown.
  final UvData uvData;

  /// Converts a UTC [time] to the data's location-local time, using
  /// [UvData.timezoneOffset] rather than the device's own timezone, so the
  /// chart reflects the queried location's day rather than the viewer's.
  DateTime _toLocationLocal(DateTime time) =>
      time.add(Duration(seconds: uvData.timezoneOffset));

  @override
  Widget build(BuildContext context) {
    final DateTime sunrise = _toLocationLocal(uvData.sunrise);
    final DateTime sunset = _toLocationLocal(uvData.sunset);
    final double sunsetHours =
        sunset.difference(sunrise).inMinutes / Duration.minutesPerHour;

    final List<_ChartPoint> points = <_ChartPoint>[
      for (final UvForecastEntry entry in uvData.hourly)
        if (!entry.time.isBefore(uvData.sunrise) &&
            !entry.time.isAfter(uvData.sunset))
          (
            hours:
                _toLocationLocal(entry.time).difference(sunrise).inMinutes /
                Duration.minutesPerHour,
            localTime: _toLocationLocal(entry.time),
            entry: entry,
          ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double hourInterval = _hourLabelInterval(
          constraints.maxWidth,
          sunsetHours,
        );

        return Stack(
          children: <Widget>[
            ExcludeSemantics(
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: sunsetHours,
                  minY: 0,
                  maxY: _yAxisMax,
                  backgroundColor: Colors.transparent,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  rangeAnnotations: _whoRangeAnnotations(),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: _bottomTitleReservedSize,
                        interval: hourInterval,
                        getTitlesWidget: (double value, TitleMeta meta) =>
                            _BottomTitle(
                              label: _formatHour(
                                sunrise.add(_hoursDuration(value)),
                              ),
                              meta: meta,
                            ),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: _leftTitleReservedSize,
                        interval: whoModerateMax - whoLowMax,
                        getTitlesWidget: (double value, TitleMeta meta) =>
                            _LeftTitle(value: value, meta: meta),
                      ),
                    ),
                  ),
                  lineTouchData: const LineTouchData(enabled: false),
                  lineBarsData: <LineChartBarData>[
                    LineChartBarData(
                      spots: <FlSpot>[
                        for (final _ChartPoint point in points)
                          FlSpot(point.hours, point.entry.uvi),
                      ],
                      barWidth: _lineStrokeWidth,
                      color: Theme.of(context).colorScheme.onSurface,
                      dotData: FlDotData(
                        getDotPainter:
                            (
                              FlSpot spot,
                              double percent,
                              LineChartBarData bar,
                              int index,
                            ) => FlDotCirclePainter(
                              radius: _dotRadius,
                              color: whoRiskColor(spot.y),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(child: _HourlyChartSemantics(points: points)),
          ],
        );
      },
    );
  }

  RangeAnnotations _whoRangeAnnotations() => RangeAnnotations(
    horizontalRangeAnnotations: <HorizontalRangeAnnotation>[
      HorizontalRangeAnnotation(
        y1: 0,
        y2: whoLowMax,
        color: _bandFill(whoColorLow),
      ),
      HorizontalRangeAnnotation(
        y1: whoLowMax,
        y2: whoModerateMax,
        color: _bandFill(whoColorModerate),
      ),
      HorizontalRangeAnnotation(
        y1: whoModerateMax,
        y2: whoHighMax,
        color: _bandFill(whoColorHigh),
      ),
      HorizontalRangeAnnotation(
        y1: whoHighMax,
        y2: whoVeryHighMax,
        color: _bandFill(whoColorVeryHigh),
      ),
      HorizontalRangeAnnotation(
        y1: whoVeryHighMax,
        y2: _whoExtremeMax,
        color: _bandFill(whoColorExtreme),
      ),
    ],
  );
}

/// Background-fill opacity for WHO risk bands, kept low so the line and
/// dots remain the visual focus.
const double _whoBandFillOpacity = 0.12;

Color _bandFill(Color color) => color.withValues(alpha: _whoBandFillOpacity);

Duration _hoursDuration(double hours) =>
    Duration(seconds: (hours * Duration.secondsPerHour).round());

/// Chooses the hour-label axis interval: every hour, or every 2 hours if
/// hourly labels would not fit within the available chart width.
double _hourLabelInterval(double chartWidth, double sunsetHours) {
  final int hourlyLabelCount = sunsetHours.ceil() + 1;
  final double pixelsPerHour = chartWidth / hourlyLabelCount;

  final bool hourlyLabelsFit =
      pixelsPerHour >= _minPixelsPerHourLabel &&
      pixelsPerHour >= _estimatedHourLabelWidth;

  return hourlyLabelsFit ? 1 : 2;
}

String _formatHour(DateTime time) => _formatTime(time, includeMinutes: false);

/// Formats [time] as e.g. "2:00 PM" (or "2 PM" when [includeMinutes] is
/// false), for use in axis labels and accessibility semantic labels.
String _formatTime(DateTime time, {required bool includeMinutes}) {
  final int hour24 = time.hour;
  final int hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final String period = hour24 < 12 ? 'AM' : 'PM';

  if (!includeMinutes) return '$hour12 $period';

  final String minutes = time.minute.toString().padLeft(2, '0');
  return '$hour12:$minutes $period';
}

/// An invisible, TalkBack-navigable overlay exposing one semantics node per
/// hourly data point, so screen reader users can swipe through readings
/// without needing the press-and-hold scrub interaction (out of scope for
/// this widget; sighted/touch users get only the visual chart).
class _HourlyChartSemantics extends StatelessWidget {
  const _HourlyChartSemantics({required this.points});

  final List<_ChartPoint> points;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Row(
        children: <Widget>[
          for (final _ChartPoint point in points)
            Expanded(
              child: Semantics(
                label: _pointLabel(point),
                child: const SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }

  String _pointLabel(_ChartPoint point) {
    final String time = _formatTime(point.localTime, includeMinutes: true);
    final String uviLabel = truncateToTenth(point.entry.uvi).toStringAsFixed(1);
    final String risk = whoRiskLabel(point.entry.uvi);
    return '$time, UV index $uviLabel, $risk risk';
  }
}

class _BottomTitle extends StatelessWidget {
  const _BottomTitle({required this.label, required this.meta});

  final String label;
  final TitleMeta meta;

  @override
  Widget build(BuildContext context) {
    return SideTitleWidget(
      meta: meta,
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _LeftTitle extends StatelessWidget {
  const _LeftTitle({required this.value, required this.meta});

  final double value;
  final TitleMeta meta;

  @override
  Widget build(BuildContext context) {
    return SideTitleWidget(
      meta: meta,
      child: Text(
        value.round().toString(),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
