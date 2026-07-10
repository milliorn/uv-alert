import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/utils/who_risk.dart';

/// Number of days shown on the chart, left (current day) to right (last
/// forecast day).
const int _daysShown = 7;

/// Fixed y-axis upper bound, matching the hourly chart's cap: the WHO
/// "Extreme" band is open-ended (11+), and real-world UV indices essentially
/// never exceed this in practice.
const double _chartYAxisMax = 12;

/// Chart y-axis lower bound: the minimum possible UV index.
const double _chartYAxisMin = 0;

/// Width of each bar, kept narrow for tight, clinical spacing per the
/// Weekly Chart spec.
const double _barWidth = 20;

/// Radius of the rounded top corners on each bar.
const double _barTopRadius = 4;

/// Height reserved for the bottom (day-of-week) axis titles.
const double _bottomTitleReservedSize = 24;

/// Vertical offset from a bar's tip to its UV-value label, so the label
/// sits just above the bar rather than overlapping it.
const double _valueLabelOffsetY = -16;

/// Day-of-week abbreviations, indexed by `DateTime.weekday - 1`
/// (Monday = index 0).
const List<String> _weekdayAbbreviations = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// A single daily UV reading positioned along the chart's x-axis.
///
/// `index` is the bar's position (0 = current/earliest day); `localTime` is
/// the reading's date in the queried location's local time (not the
/// device's); `whoColor` is this bar's WHO risk-band color, computed once
/// and reused by both the bar fill and the accessibility label.
typedef _ChartPoint = ({
  int index,
  DateTime localTime,
  UvForecastEntry entry,
  Color whoColor,
});

/// A static 7-day UV index bar chart, current day (left) to last forecast
/// day (right).
///
/// Draws one WHO-colored bar per day with its UV max value labeled on top,
/// and a day-of-week abbreviation on the bottom axis. Does not highlight
/// the current day -- its leftmost position conveys that. Does not support
/// tap/scrub interaction -- see the "Out of scope" note on the originating
/// issue for that follow-up.
class UvDailyChart extends StatelessWidget {
  /// Creates a [UvDailyChart] from up to [_daysShown] entries in
  /// [UvData.daily], chronologically sorted with stale (pre-today,
  /// location-local) entries dropped first.
  const UvDailyChart({required this.uvData, super.key});

  /// The UV data to chart. [UvData.daily] is sorted chronologically and any
  /// entry whose location-local date is before today is dropped; up to
  /// [_daysShown] of what remains is shown.
  final UvData uvData;

  /// Converts a UTC [time] to the data's location-local time, using
  /// [UvData.timezoneOffset] rather than the device's own timezone, so the
  /// chart reflects the queried location's day rather than the viewer's.
  DateTime _toLocationLocal(DateTime time) =>
      time.add(Duration(seconds: uvData.timezoneOffset));

  @override
  Widget build(BuildContext context) {
    // A cached UvData payload can still be "fresh" (within Cache's 24h TTL)
    // after its own local calendar day has passed -- e.g. fetched at 11pm,
    // still valid at 11am the next day. Drop any daily entry whose
    // location-local date is already in the past so a stale leading day is
    // never mistaken for "today" by virtue of being the leftmost bar.
    final DateTime today = _toLocationLocal(DateTime.now().toUtc());
    // DateTime.utc, not the local-time DateTime() constructor: `today` is
    // itself UTC-flagged (add() on a UTC DateTime preserves isUtc), and
    // comparing a UTC-flagged instant against a device-local-flagged one
    // via isBefore compares absolute instants, not wall-clock fields --
    // silently shifting this boundary by the device's own UTC offset.
    final DateTime todayDate = DateTime.utc(today.year, today.month, today.day);

    // UvData.daily has no documented ordering guarantee, so sort explicitly
    // -- an out-of-order list would otherwise draw days out of sequence and
    // expose semantics nodes to TalkBack in the wrong swipe order. Sorting
    // first (on raw entries) lets the filter below compute each entry's
    // location-local time exactly once, instead of once to filter and again
    // to build its _ChartPoint.
    final List<UvForecastEntry> sortedEntries = <UvForecastEntry>[
      ...uvData.daily,
    ]..sort((UvForecastEntry a, UvForecastEntry b) => a.time.compareTo(b.time));

    final List<_ChartPoint> points = <_ChartPoint>[];
    for (final UvForecastEntry entry in sortedEntries) {
      if (points.length >= _daysShown) {
        break;
      }
      final DateTime localTime = _toLocationLocal(entry.time);
      if (localTime.isBefore(todayDate)) {
        continue;
      }
      points.add((
        index: points.length,
        localTime: localTime,
        entry: entry,
        whoColor: whoRiskColor(entry.uvi),
      ));
    }

    final TextStyle? labelStyle = Theme.of(context).textTheme.bodySmall;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Stack(
          children: <Widget>[
            ExcludeSemantics(
              child: BarChart(
                BarChartData(
                  minY: _chartYAxisMin,
                  maxY: _chartYAxisMax,
                  // Pinned explicitly (matching the default) rather than
                  // left implicit, because _DailyChartSemantics._barCenterX
                  // reimplements this alignment's bar-center formula by
                  // hand; an upstream default change must not silently
                  // desync the semantics overlay from the visible bars.
                  alignment: BarChartAlignment.spaceEvenly,
                  backgroundColor: Colors.transparent,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: const BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: _bottomTitleReservedSize,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final int index = value.round();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              _weekdayAbbreviation(points[index].localTime),
                              style: labelStyle,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Exactly one rod per group: _DailyChartSemantics.
                  // _barCenterX assumes each BarChartGroupData.width equals
                  // _barWidth exactly, which only holds with a single rod
                  // (a second rod would add its own width + barsSpace and
                  // silently desync the semantics overlay from the bars --
                  // see the class doc on _DailyChartSemantics).
                  barGroups: <BarChartGroupData>[
                    for (final _ChartPoint point in points)
                      BarChartGroupData(
                        x: point.index,
                        barRods: <BarChartRodData>[
                          BarChartRodData(
                            toY: point.entry.uvi,
                            color: point.whoColor,
                            width: _barWidth,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(_barTopRadius),
                            ),
                            label: BarChartRodLabel(
                              offset: const Offset(0, _valueLabelOffsetY),
                              text: truncateToTenth(
                                point.entry.uvi,
                              ).toStringAsFixed(1),
                              style: labelStyle,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: _bottomTitleReservedSize,
              child: _DailyChartSemantics(
                points: points,
                plotWidth: constraints.maxWidth,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Formats [localTime] as its abbreviated day-of-week name, e.g. "Mon".
String _weekdayAbbreviation(DateTime localTime) =>
    _weekdayAbbreviations[localTime.weekday - 1];

/// An invisible, TalkBack-navigable overlay exposing one semantics node per
/// daily bar, so screen reader users can swipe through readings without
/// needing a tap/scrub interaction (out of scope for this widget;
/// sighted/touch users get only the visual chart).
///
/// Each node is centered on its bar's exact horizontal center, but sized to
/// span the full constant spacing between adjacent bar centers (not just
/// the bar's visible [_barWidth]), applied symmetrically on both sides even
/// at the outermost bars -- an equal split of [plotWidth] into same-width
/// slices would instead misalign the outermost nodes with their bars by a
/// growing margin as the bar count shrinks, since fl_chart's
/// [BarChartAlignment.spaceEvenly] lays out fixed-width bars with computed
/// gaps around them, not as equal-width slices. Symmetric cell sizing keeps
/// every node's rect exactly centered on its bar while still giving
/// TalkBack a much wider touch target than a narrow [_barWidth]-wide one.
///
/// This exactness depends on invariants enforced elsewhere in this file,
/// not by the compiler -- changing any of them without updating
/// [_barCenterX] to match will silently desync this overlay from the
/// visible bars:
///  * [UvDailyChart] pins `alignment: BarChartAlignment.spaceEvenly`
///    explicitly on its `BarChartData` (not left at fl_chart's default).
///  * Each `BarChartGroupData` has exactly one `BarChartRodData` of width
///    [_barWidth], so `BarChartGroupData.width == _barWidth`.
///  * `topTitles`/`leftTitles`/`rightTitles` and `FlBorderData` all stay
///    hidden, so fl_chart reserves zero horizontal space beyond [plotWidth].
///  * `BarChart` is never given a `transformationConfig` (pan/zoom), which
///    would otherwise shrink fl_chart's internal plot width below
///    [plotWidth].
class _DailyChartSemantics extends StatelessWidget {
  const _DailyChartSemantics({required this.points, required this.plotWidth});

  final List<_ChartPoint> points;

  /// The width available to the bar chart's plot area, matching what
  /// fl_chart's `calculateGroupsX` receives as `viewWidth`.
  final double plotWidth;

  /// Replicates fl_chart's `BarChartAlignment.spaceEvenly` bar-center
  /// formula (`calculateGroupsX` in `bar_chart_data_extension.dart`) so
  /// each semantics node lines up with its bar exactly, not approximately.
  /// See the invariants this depends on in the class doc above.
  double _barCenterX(int index) {
    assert(plotWidth.isFinite && plotWidth >= 0, 'plotWidth must be finite');
    final double spaceAvailable = plotWidth - (_barWidth * points.length);
    final double eachSpace = spaceAvailable / (points.length + 1);
    return eachSpace * (index + 1) + _barWidth * (index + 0.5);
  }

  /// Half the constant spacing between adjacent bar centers under
  /// [BarChartAlignment.spaceEvenly] -- used as each semantics node's cell
  /// half-width, applied symmetrically on both sides of [_barCenterX] (even
  /// at the outermost bars) so every node's rect stays exactly centered on
  /// its bar while still spanning far more than [_barWidth].
  double get _cellHalfWidth {
    if (points.length < 2) {
      return plotWidth / 2;
    }
    return (_barCenterX(1) - _barCenterX(0)) / 2;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Stack(
        children: <Widget>[
          for (final _ChartPoint point in points)
            Positioned(
              // Sized to the full inter-bar cell width, centered on the bar,
              // rather than just _barWidth, so TalkBack explore-by-touch and
              // focus targeting aren't confined to the narrow visible bar --
              // matches _HourlyChartSemantics' full-width Expanded regions.
              // Applying the same half-width symmetrically at the edges (not
              // extending to the plot boundary) keeps every node's rect
              // centered exactly on its bar, matching _barCenterX.
              left: _barCenterX(point.index) - _cellHalfWidth,
              width: _cellHalfWidth * 2,
              top: 0,
              bottom: 0,
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
    final String day = _weekdayAbbreviation(point.localTime);
    final String value = truncateToTenth(point.entry.uvi).toStringAsFixed(1);
    final String risk = whoRiskLabel(point.entry.uvi);
    return '$day, UV max $value, $risk risk';
  }
}
