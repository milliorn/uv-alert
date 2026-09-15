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
/// then by earliest [WeatherAlert.start], then by [WeatherAlert.id], then by
/// [WeatherAlert.description] (both plain string comparisons, chosen only
/// for a total, arbitrary-but-stable order, not for any semantic meaning of
/// their contents) as a final tiebreak, so the choice doesn't depend on the
/// payload's original ordering even when two alerts share severity and
/// start.
///
/// [WeatherAlert.id] is synthesized from `senderName`/`event`/`start` (see
/// [WeatherAlert.fromJson]), not guaranteed unique across the whole model
/// (two distinct alerts from the same sender, same event name, and the
/// same start instant, but a different description, would collide) --
/// [WeatherAlert.description] is included as one further level specifically
/// to cover that gap, rather than assuming [WeatherAlert.id] alone settles
/// every comparison.
///
/// [alerts] must not be empty -- callers already guard on
/// `alerts.isNotEmpty` before showing any banner content, so an empty list
/// here indicates a caller bug rather than a normal "no alerts" state (which
/// is handled by not calling this at all).
WeatherAlert topAlert(List<WeatherAlert> alerts) {
  assert(alerts.isNotEmpty, 'topAlert requires a non-empty alert list');

  // Each alert's severity is computed exactly once, tracked alongside the
  // running best pick, rather than recomputed on it at every subsequent
  // comparison the way a plain alerts.reduce() callback would.
  WeatherAlert best = alerts.first;
  AlertSeverity bestSeverity = alertSeverityOf(best);

  for (final WeatherAlert alert in alerts.skip(1)) {
    final AlertSeverity severity = alertSeverityOf(alert);

    // Each comparison only matters when every earlier one was a tie, so
    // this reads as a single ranked cascade: severity, then start time,
    // then id, then description.
    final int comparison = severity.index != bestSeverity.index
        ? severity.index - bestSeverity.index
        : !alert.start.isAtSameMomentAs(best.start)
        ? alert.start.compareTo(best.start)
        : alert.id != best.id
        ? alert.id.compareTo(best.id)
        : alert.description.compareTo(best.description);

    if (comparison < 0) {
      best = alert;
      bestSeverity = severity;
    }
  }

  return best;
}
