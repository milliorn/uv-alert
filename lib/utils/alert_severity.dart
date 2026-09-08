import 'package:uvalert/models/weather_alert.dart';

/// Severity rank for a [WeatherAlert], used to pick the "top" alert to show
/// in the collapsed multi-alert banner. Lower values are more severe.
///
/// OWM's `alerts[]` payload has no numeric severity field, only free-form
/// `event` names. This ranks by NWS's own naming convention -- "Warning" is
/// the most severe, then "Watch", then "Advisory" -- matched
/// case-insensitively against a substring of [WeatherAlert.event], since
/// real event names are phrases like "Excessive Heat Warning" or "Red Flag
/// Warning", not exactly one of these three words.
enum AlertSeverity {
  /// Most severe: an event is imminent or already occurring (NWS "Warning").
  warning,

  /// Conditions are favorable for a severe event (NWS "Watch").
  watch,

  /// Least severe: conditions may cause inconvenience (NWS "Advisory").
  advisory,

  /// [WeatherAlert.event] doesn't match any known NWS severity keyword.
  /// Ranked below all three known severities so an unrecognized event name
  /// never outranks a genuinely severe, correctly-labeled alert.
  unknown,
}

/// The [AlertSeverity] for [alert], derived from its [WeatherAlert.event]
/// name. See [AlertSeverity] for the ranking and matching rules.
AlertSeverity alertSeverityOf(WeatherAlert alert) {
  final String event = alert.event.toLowerCase();

  if (event.contains('warning')) return AlertSeverity.warning;
  if (event.contains('watch')) return AlertSeverity.watch;
  if (event.contains('advisory')) return AlertSeverity.advisory;

  return AlertSeverity.unknown;
}

/// Returns the highest-priority alert in [alerts] for the collapsed banner's
/// "top alert" slot.
///
/// Ranked by [AlertSeverity] first (warning > watch > advisory > unknown),
/// then by earliest [WeatherAlert.start] as a stable tiebreak among
/// equally-severe alerts, so the choice doesn't depend on the payload's
/// original ordering.
///
/// [alerts] must not be empty -- callers already guard on
/// `alerts.isNotEmpty` before showing any banner content, so an empty list
/// here indicates a caller bug rather than a normal "no alerts" state (which
/// is handled by not calling this at all).
WeatherAlert topAlert(List<WeatherAlert> alerts) {
  assert(alerts.isNotEmpty, 'topAlert requires a non-empty alert list');

  return alerts.reduce((WeatherAlert a, WeatherAlert b) {
    final AlertSeverity severityA = alertSeverityOf(a);
    final AlertSeverity severityB = alertSeverityOf(b);

    if (severityA.index != severityB.index) {
      return severityA.index < severityB.index ? a : b;
    }

    return a.start.isBefore(b.start) ? a : b;
  });
}
