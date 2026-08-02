import 'package:flutter/foundation.dart';
import 'package:uvalert/constants.dart';

/// Returns `json[field]` as a [String], or throws [FormatException] if the
/// field is absent or not a string.
String _requireString(Map<String, Object?> json, String field) {
  final Object? value = json[field];
  if (value == null) {
    throw FormatException('missing required field: $field');
  }

  if (value is! String) {
    throw FormatException(
      'field $field must be a string, got ${value.runtimeType}',
    );
  }
  return value;
}

/// Returns `json[field]` as an [int], or throws [FormatException] if the
/// field is absent or not an int.
int _requireInt(Map<String, Object?> json, String field) {
  final Object? value = json[field];
  if (value == null) {
    throw FormatException('missing required field: $field');
  }

  if (value is! int) {
    throw FormatException(
      'field $field must be an int, got ${value.runtimeType}',
    );
  }
  return value;
}

DateTime _fromEpochSeconds(int s) =>
    DateTime.fromMillisecondsSinceEpoch(s * msPerSecond, isUtc: true);

int _toEpochSeconds(DateTime dt) => dt.millisecondsSinceEpoch ~/ msPerSecond;

/// A government weather alert to surface on the dashboard banner.
///
/// Mirrors the subset of OpenWeatherMap's `alerts[]` entry fields
/// (`event`, `description`, `start`, `end`, `sender_name`) the banner and
/// full alert list need to render. Fetching and parsing the actual OWM
/// `alerts` payload is out of scope for now -- see
/// `docs/adr/0002-owm-one-call-api.md` and `.private/adr/OPEN_QUESTIONS.md`.
@immutable
class WeatherAlert {
  /// Creates a [WeatherAlert].
  const WeatherAlert({
    required this.event,
    required this.description,
    required this.start,
    required this.end,
    required this.senderName,
  });

  /// Deserializes a [WeatherAlert] from a JSON map.
  ///
  /// Throws [FormatException] if `event`, `description`, `start`, `end`, or
  /// `sender_name` is absent or the wrong type.
  factory WeatherAlert.fromJson(Map<String, Object?> json) {
    return WeatherAlert(
      event: _requireString(json, 'event'),
      description: _requireString(json, 'description'),
      start: _fromEpochSeconds(_requireInt(json, 'start')),
      end: _fromEpochSeconds(_requireInt(json, 'end')),
      senderName: _requireString(json, 'sender_name'),
    );
  }

  /// Short alert name, e.g. "Heat Advisory".
  final String event;

  /// Full alert body text.
  final String description;

  /// When this alert becomes active, in UTC.
  final DateTime start;

  /// When this alert expires, in UTC.
  final DateTime end;

  /// The issuing authority, e.g. "NWS Billings MT".
  final String senderName;

  /// Serializes this instance to a JSON map.
  Map<String, Object?> toJson() => <String, Object?>{
    'event': event,
    'description': description,
    'start': _toEpochSeconds(start),
    'end': _toEpochSeconds(end),
    'sender_name': senderName,
  };

  // Override == for value equality: two alerts with identical fields are
  // equal regardless of whether they are the same object in memory.
  // Including start/end/senderName (not just event/description) fixes a
  // dismiss-logic gap: a renewed alert with identical event/description
  // text but a different start/end window must NOT compare equal to a
  // prior occurrence that was already dismissed.
  // `other` is the Dart SDK's parameter name from Object.==; it is the
  // right-hand operand being compared against `this`.
  @override
  bool operator ==(Object other) =>
      other is WeatherAlert &&
      other.event == event &&
      other.description == description &&
      other.start == start &&
      other.end == end &&
      other.senderName == senderName;

  // Override hashCode whenever == is overridden. Dart requires that objects
  // which are == produce the same hashCode, otherwise Sets and Maps break.
  @override
  int get hashCode => Object.hash(event, description, start, end, senderName);
}
