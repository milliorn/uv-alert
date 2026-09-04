import 'package:flutter/material.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/services/hero_conditional_line.dart';
import 'package:uvalert/services/solar_position.dart';

/// The dashboard hero's single conditional line of text, showing the next
/// most relevant event in the day's sequence (solar events or UV threshold
/// crossings), or rendering nothing when [heroConditionalLine] returns
/// `null`.
///
/// A thin wrapper around the pure [heroConditionalLine] function -- kept
/// separate so the priority-ordered branch logic is directly unit-testable
/// without a widget-test harness.
class UvHeroConditionalLine extends StatelessWidget {
  /// Creates a [UvHeroConditionalLine].
  ///
  /// [now] must be UTC (e.g. `DateTime.now().toUtc()`), not device-local
  /// time. [solarEvents] is the event-time map produced by
  /// [solarEventTimes]. [uvData] supplies the `hourly` entries used to
  /// evaluate the UV-threshold branches.
  const UvHeroConditionalLine({
    required this.now,
    required this.solarEvents,
    required this.uvData,
    super.key,
  });

  /// The current UTC time.
  final DateTime now;

  /// The day's solar event times, from [solarEventTimes].
  final Map<SolarEvent, DateTime?> solarEvents;

  /// The UV data supplying `hourly` entries for threshold evaluation.
  final UvData uvData;

  @override
  Widget build(BuildContext context) {
    final String? line = heroConditionalLine(
      now: now,
      solarEvents: solarEvents,
      uvData: uvData,
    );

    if (line == null) return const SizedBox.shrink();

    return Text(
      line,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}
