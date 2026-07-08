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
///
/// Also doubles as the upper bound of the WHO "Extreme" band drawn on the
/// chart background, since that is the top of the visible chart. Exposed
/// for tests via [visibleForTesting].
@visibleForTesting
const double chartYAxisMax = 12;

/// Below this pixel width per hourly label, hour labels would visually
/// overlap, so the chart falls back to showing every 2 hours instead.
const double _minPixelsPerHourLabel = 36;

/// Chart x-axis lower bound: sunrise, 0 hours after itself.
const double _chartXAxisMin = 0;

/// Chart y-axis lower bound: the minimum possible UV index.
const double _chartYAxisMin = 0;

/// Left axis tick generation step. Ticks are generated at every whole UV
/// index unit, then [_isWhoAxisBoundary] filters the rendered labels down
/// to only the WHO threshold values.
const double _leftAxisTickInterval = 1;

/// A single hourly UV reading positioned along the chart's x-axis.
///
/// `hours` is the fractional number of hours since sunrise (the chart's
/// x-coordinate); `localTime` is the reading's timestamp in the queried
/// location's local time (not the device's); `whoColor` is this point's WHO
/// risk-band color, computed once and reused by the dot painter instead of
/// re-deriving it per dot paint.
typedef _ChartPoint = ({
  double hours,
  DateTime localTime,
  UvForecastEntry entry,
  Color whoColor,
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

  /// Builds a [_ChartPoint] for [entry], computing its location-local time
  /// and WHO risk color once and reusing them for the plotted x-position
  /// and dot color.
  _ChartPoint _chartPoint(UvForecastEntry entry, DateTime sunrise) {
    final DateTime localTime = _toLocationLocal(entry.time);
    return (
      hours: localTime.difference(sunrise).inSeconds / Duration.secondsPerHour,
      localTime: localTime,
      entry: entry,
      whoColor: whoRiskColor(entry.uvi),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime sunrise = _toLocationLocal(uvData.sunrise);
    final DateTime sunset = _toLocationLocal(uvData.sunset);
    final double sunsetHours =
        sunset.difference(sunrise).inSeconds / Duration.secondsPerHour;

    // UvData.hourly has no documented ordering guarantee, so sort explicitly
    // -- an out-of-order list would otherwise draw a zigzagging line and
    // expose semantics nodes to TalkBack in the wrong swipe order.
    final List<_ChartPoint> points = <_ChartPoint>[
      for (final UvForecastEntry entry in uvData.hourly)
        if (!entry.time.isBefore(uvData.sunrise) &&
            !entry.time.isAfter(uvData.sunset))
          _chartPoint(entry, sunrise),
    ]..sort((_ChartPoint a, _ChartPoint b) => a.hours.compareTo(b.hours));

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double hourInterval = _hourLabelInterval(
          constraints.maxWidth - _leftTitleReservedSize,
          sunsetHours,
        );

        return Stack(
          children: <Widget>[
            ExcludeSemantics(
              child: LineChart(
                LineChartData(
                  minX: _chartXAxisMin,
                  maxX: sunsetHours,
                  minY: _chartYAxisMin,
                  maxY: chartYAxisMax,
                  backgroundColor: Colors.transparent,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  rangeAnnotations: _whoRangeAnnotations,
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
                              label: _formatTime(
                                sunrise.add(_hoursDuration(value)),
                                includeMinutes: false,
                              ),
                              meta: meta,
                            ),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: _leftTitleReservedSize,
                        interval: _leftAxisTickInterval,
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
                              color: points[index].whoColor,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: _leftTitleReservedSize,
                  bottom: _bottomTitleReservedSize,
                ),
                child: _HourlyChartSemantics(points: points),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// WHO risk-band background fills, drawn once and reused across rebuilds
/// since the boundaries and colors never change.
final RangeAnnotations _whoRangeAnnotations = RangeAnnotations(
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
      y2: chartYAxisMax,
      color: _bandFill(whoColorExtreme),
    ),
  ],
);

/// Background-fill opacity for WHO risk bands, kept low so the line and
/// dots remain the visual focus.
const double _whoBandFillOpacity = 0.12;

Color _bandFill(Color color) => color.withValues(alpha: _whoBandFillOpacity);

Duration _hoursDuration(double hours) =>
    Duration(seconds: (hours * Duration.secondsPerHour).round());

/// Chooses the hour-label axis interval: every hour, or every 2 hours if
/// hourly labels would not fit within the available chart width.
///
/// [plotAreaWidth] must be the chart's plot area width, not the full widget
/// width -- fl_chart reserves [_leftTitleReservedSize] for the left axis
/// titles (subtracted from the chart's content area as layout margin), which
/// is not available for spacing the bottom axis's hour labels.
double _hourLabelInterval(double plotAreaWidth, double sunsetHours) {
  // +1 because labels cover both endpoints (0..ceil(sunsetHours) inclusive),
  // matching fl_chart's own tick count for a fractional axis max -- see
  // AxisChartHelper.iterateThroughAxis, which always emits an extra tick
  // exactly at a non-integer max in addition to the integer ticks below it.
  final int hourlyLabelCount = sunsetHours.ceil() + 1;
  final double pixelsPerHour = plotAreaWidth / hourlyLabelCount;

  return pixelsPerHour >= _minPixelsPerHourLabel ? 1 : 2;
}

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
    return '$time, ${uvIndexSemanticsPhrase(point.entry.uvi)}';
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

/// The WHO threshold boundaries drawn on the left axis, matching the
/// background risk-band edges exactly.
const List<double> _leftAxisWhoBoundaries = <double>[
  0,
  whoLowMax,
  whoModerateMax,
  whoHighMax,
  whoVeryHighMax,
  chartYAxisMax,
];

/// Tolerance for matching a generated axis tick against
/// [_leftAxisWhoBoundaries].
///
/// fl_chart generates tick values by repeatedly summing the axis interval,
/// so ticks can accumulate floating-point drift; comparing with a small
/// tolerance instead of exact equality keeps the boundary labels showing
/// even if a threshold constant or the axis interval ever becomes a value
/// that isn't exactly representable in binary floating point.
const double _axisBoundaryTolerance = 1e-6;

/// Whether [value] matches one of [_leftAxisWhoBoundaries], within
/// [_axisBoundaryTolerance].
bool _isWhoAxisBoundary(double value) => _leftAxisWhoBoundaries.any(
  (double boundary) => (value - boundary).abs() < _axisBoundaryTolerance,
);

class _LeftTitle extends StatelessWidget {
  const _LeftTitle({required this.value, required this.meta});

  final double value;
  final TitleMeta meta;

  @override
  Widget build(BuildContext context) {
    if (!_isWhoAxisBoundary(value)) return const SizedBox.shrink();

    return SideTitleWidget(
      meta: meta,
      child: Text(
        value.round().toString(),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
