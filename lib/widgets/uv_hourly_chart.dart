import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/utils/time_format.dart';
import 'package:uvalert/utils/who_risk.dart';

/// Width of the scrub interaction's vertical hairline.
const double _hairlineWidth = 1;

/// Radius of the filled dot drawn where the scrub hairline intersects the
/// line chart.
const double _scrubDotRadius = 4;

/// Vertical gap between the scrub label and the top of the chart.
const double _scrubLabelTopOffset = 4;

/// Horizontal padding inside the scrub label's background pill.
const double _scrubLabelPaddingHorizontal = 6;

/// Vertical padding inside the scrub label's background pill.
const double _scrubLabelPaddingVertical = 2;

/// Corner radius of the scrub label's background pill.
const double _scrubLabelBorderRadius = 4;

/// Opacity of the scrub label's background pill, kept low so it reads as a
/// plain text label rather than a decorative tooltip bubble.
const double _scrubLabelBackgroundOpacity = 0.85;

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

/// A hourly UV index line chart, spanning sunrise to sunset.
///
/// Draws WHO risk-band background fills, an hourly (or every-2-hours,
/// if labels would overlap) time axis, and a UV index axis at the WHO
/// threshold boundaries. Supports a press-and-hold scrub interaction: a
/// thin vertical hairline follows the finger, with a small filled dot where
/// it intersects the line and a plain text label (no decorative tooltip
/// bubble) showing the UV value and time at that point.
///
/// A [StatefulWidget] (rather than [StatelessWidget]) because the scrub
/// interaction must track the touch position across a drag gesture's
/// down/update/end events, which requires local state -- this is a
/// structural change from the chart's prior static-only implementation.
class UvHourlyChart extends StatefulWidget {
  /// Creates a [UvHourlyChart] from the hourly forecast entries in [uvData]
  /// that fall between its sunrise and sunset.
  const UvHourlyChart({required this.uvData, super.key});

  /// The UV data to chart; only [UvData.hourly] entries between
  /// [UvData.sunrise] and [UvData.sunset] are shown.
  final UvData uvData;

  @override
  State<UvHourlyChart> createState() => _UvHourlyChartState();
}

/// The scrub interaction's current touch state: the touched [_ChartPoint]
/// and the pixel `localPosition` (within the chart's own coordinate space)
/// the hairline/label are drawn at. `null` (via
/// `_UvHourlyChartState._scrubState`) when no scrub is in progress.
typedef _ScrubState = ({_ChartPoint point, Offset localPosition});

class _UvHourlyChartState extends State<UvHourlyChart> {
  /// The current scrub touch state, or `null` when not actively touched.
  _ScrubState? _scrubState;

  /// The chronologically sorted, sunrise-to-sunset [_ChartPoint]s for
  /// `widget.uvData`. Computed in [initState]/[didUpdateWidget] rather than
  /// per-build so repeated touch-move callbacks during a scrub drag don't
  /// each re-sort and re-derive the full list.
  late List<_ChartPoint> _points;

  @override
  void initState() {
    super.initState();
    _points = _computePoints();
  }

  @override
  void didUpdateWidget(UvHourlyChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uvData != widget.uvData) {
      _points = _computePoints();
      // The previous _scrubState references a _ChartPoint from the old
      // _points list; clear it rather than risk showing a stale value from
      // discarded data until the next touch callback.
      _scrubState = null;
    }
  }

  /// Builds a [_ChartPoint] for [entry], computing its location-local time
  /// and WHO risk color once and reusing them for the plotted x-position
  /// and dot color.
  _ChartPoint _chartPoint(UvForecastEntry entry, DateTime sunrise) {
    final DateTime localTime = toLocationLocal(
      entry.time,
      widget.uvData.timezoneOffset,
    );
    return (
      hours: localTime.difference(sunrise).inSeconds / Duration.secondsPerHour,
      localTime: localTime,
      entry: entry,
      whoColor: whoRiskColor(entry.uvi),
    );
  }

  /// Updates [_scrubState] from a touch/pointer event reported by fl_chart's
  /// [LineTouchData.touchCallback]. Clears the scrub state (hiding the
  /// hairline/dot/label) on any event that ends or cancels the gesture, or
  /// that has no touched spot (e.g. a touch outside the plotted line), or
  /// whose reported spot index doesn't resolve to a current point.
  void _handleTouch(FlTouchEvent event, LineTouchResponse? response) {
    final TouchLineBarSpot? spot =
        (!event.isInterestedForInteractions ||
            response == null ||
            response.lineBarSpots == null ||
            response.lineBarSpots!.isEmpty)
        ? null
        : response.lineBarSpots!.first;
    final int index = spot?.spotIndex ?? -1;

    if (spot == null || index < 0 || index >= _points.length) {
      if (_scrubState != null) setState(() => _scrubState = null);
      return;
    }

    setState(() {
      _scrubState = (
        point: _points[index],
        localPosition: response!.touchLocation,
      );
    });
  }

  /// Computes the chronologically sorted, sunrise-to-sunset [_ChartPoint]s
  /// for `widget.uvData`.
  List<_ChartPoint> _computePoints() {
    final DateTime sunrise = toLocationLocal(
      widget.uvData.sunrise,
      widget.uvData.timezoneOffset,
    );

    // UvData.hourly has no documented ordering guarantee, so sort
    // explicitly -- an out-of-order list would otherwise draw a zigzagging
    // line and expose semantics nodes to TalkBack in the wrong swipe order.
    return <_ChartPoint>[
      for (final UvForecastEntry entry in widget.uvData.hourly)
        if (!entry.time.isBefore(widget.uvData.sunrise) &&
            !entry.time.isAfter(widget.uvData.sunset))
          _chartPoint(entry, sunrise),
    ]..sort((_ChartPoint a, _ChartPoint b) => a.hours.compareTo(b.hours));
  }

  @override
  Widget build(BuildContext context) {
    final DateTime sunrise = toLocationLocal(
      widget.uvData.sunrise,
      widget.uvData.timezoneOffset,
    );
    final DateTime sunset = toLocationLocal(
      widget.uvData.sunset,
      widget.uvData.timezoneOffset,
    );
    final double sunsetHours =
        sunset.difference(sunrise).inSeconds / Duration.secondsPerHour;
    final List<_ChartPoint> points = _points;

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
                              label: formatTime(
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
                  lineTouchData: LineTouchData(
                    touchCallback: _handleTouch,
                    // Suppresses fl_chart's own default indicator dot and
                    // tooltip bubble entirely -- this widget draws its own
                    // hairline/dot/label overlay below instead, per the
                    // "no decorative bubble" requirement.
                    handleBuiltInTouches: false,
                    touchTooltipData: const LineTouchTooltipData(
                      getTooltipColor: _transparentTooltip,
                    ),
                  ),
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
            if (_scrubState != null) _ScrubOverlay(scrub: _scrubState!),
          ],
        );
      },
    );
  }
}

/// Always returns a fully transparent color, so
/// [LineTouchData.touchTooltipData] never paints a visible tooltip bubble --
/// [LineTouchData.handleBuiltInTouches] is `false` so this is normally
/// unreachable, but pinning it explicitly (rather than leaving the default)
/// guards against a decorative bubble reappearing if that ever changes.
Color _transparentTooltip(LineBarSpot spot) => Colors.transparent;

/// The scrub interaction's visual overlay: a thin vertical hairline at the
/// touched x-position, a small filled dot where it intersects the line, and
/// a plain text label (UV value + time) above the chart -- deliberately no
/// decorative tooltip bubble, per the scrub interaction spec.
class _ScrubOverlay extends StatelessWidget {
  const _ScrubOverlay({required this.scrub});

  final _ScrubState scrub;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double x = scrub.localPosition.dx;

    return Positioned.fill(
      child: Stack(
        children: <Widget>[
          Positioned(
            left: x - _hairlineWidth / 2,
            top: 0,
            bottom: _bottomTitleReservedSize,
            width: _hairlineWidth,
            child: ColoredBox(color: colors.onSurface),
          ),
          Positioned(
            left: x - _scrubDotRadius,
            top: scrub.localPosition.dy - _scrubDotRadius,
            width: _scrubDotRadius * 2,
            height: _scrubDotRadius * 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scrub.point.whoColor,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: _scrubLabelTopOffset,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: _scrubLabelPaddingHorizontal,
                  vertical: _scrubLabelPaddingVertical,
                ),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(
                    alpha: _scrubLabelBackgroundOpacity,
                  ),
                  borderRadius: BorderRadius.circular(_scrubLabelBorderRadius),
                ),
                child: Text(
                  '${_scrubUvi(scrub.point)} · '
                  '${formatTime(scrub.point.localTime)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.onSurface),
                ),
              ),
            ),
          ),
        ],
      ),
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

/// Formats [point]'s UV index to one decimal place, for the scrub
/// interaction's label.
String _scrubUvi(_ChartPoint point) =>
    truncateToTenth(point.entry.uvi).toStringAsFixed(1);

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
    final String time = formatTime(point.localTime);
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
