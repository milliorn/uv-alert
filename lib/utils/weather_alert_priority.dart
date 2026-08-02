import 'package:uvalert/models/weather_alert.dart';

/// Severity rank for an alert whose [WeatherAlert.event] contains
/// "warning" (case-insensitive), the highest-severity NWS alert tier.
const int _severityRankWarning = 3;

/// Severity rank for an alert whose [WeatherAlert.event] contains "watch"
/// (case-insensitive).
const int _severityRankWatch = 2;

/// Severity rank for an alert whose [WeatherAlert.event] contains
/// "advisory" (case-insensitive).
const int _severityRankAdvisory = 1;

/// Severity rank for an alert whose [WeatherAlert.event] matches none of
/// the recognized NWS naming conventions.
const int _severityRankOther = 0;

/// Ranks [event] by severity using NWS's own naming convention: a "Warning"
/// outranks a "Watch", which outranks an "Advisory". OWM's `alerts[]`
/// payload has no numeric severity field, so this substring match on the
/// event name is the closest available signal.
int _severityRank(String event) {
  final String lower = event.toLowerCase();

  if (lower.contains('warning')) return _severityRankWarning;
  if (lower.contains('watch')) return _severityRankWatch;
  if (lower.contains('advisory')) return _severityRankAdvisory;
  return _severityRankOther;
}

/// Returns a new list of [alerts] sorted by display priority, highest first.
///
/// Sort order:
///  1. Severity rank descending (Warning > Watch > Advisory > other), by a
///     case-insensitive substring match on [WeatherAlert.event].
///  2. Earliest [WeatherAlert.start] ascending, as a tie-break.
///  3. [WeatherAlert.event] alphabetically ascending, as a final tie-break
///     for full determinism -- [List.sort] is not guaranteed stable.
///
/// Does not mutate [alerts].
List<WeatherAlert> prioritizedAlerts(List<WeatherAlert> alerts) {
  return List<WeatherAlert>.of(alerts)..sort((WeatherAlert a, WeatherAlert b) {
    final int rankCompare = _severityRank(
      b.event,
    ).compareTo(_severityRank(a.event));
    if (rankCompare != 0) return rankCompare;

    final int startCompare = a.start.compareTo(b.start);
    if (startCompare != 0) return startCompare;

    return a.event.compareTo(b.event);
  });
}
