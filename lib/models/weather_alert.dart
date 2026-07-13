import 'package:flutter/foundation.dart';

/// Returns `json[field]` as a [String], or throws [FormatException] if the
/// field is absent or not a string.
String _requireString(Map<String, Object?> json, String field) {
  final Object? value = json[field];
  if (value == null) {
    throw FormatException('missing required field: $field');
  }
  
  if (value is! String) {
    throw FormatException('field $field must be a string, got $value');
  }
  return value;
}

/// A government weather alert to surface on the dashboard banner.
///
/// Mirrors the subset of OpenWeatherMap's `alerts[]` entry fields
/// (`event`, `description`) the banner needs to render. Fetching and
/// parsing the actual OWM `alerts` payload is out of scope for now -- see
/// `docs/adr/0002-owm-one-call-api.md` and `.private/adr/OPEN_QUESTIONS.md`.
@immutable
class WeatherAlert {
  /// Creates a [WeatherAlert].
  const WeatherAlert({required this.event, required this.description});

  /// Deserializes a [WeatherAlert] from a JSON map.
  ///
  /// Throws [FormatException] if `event` or `description` is absent or not
  /// a string.
  factory WeatherAlert.fromJson(Map<String, Object?> json) {
    return WeatherAlert(
      event: _requireString(json, 'event'),
      description: _requireString(json, 'description'),
    );
  }

  /// Short alert name, e.g. "Heat Advisory".
  final String event;

  /// Full alert body text.
  final String description;

  /// Serializes this instance to a JSON map.
  Map<String, Object?> toJson() => <String, Object?>{
    'event': event,
    'description': description,
  };

  // Override == for value equality: two alerts with identical fields are
  // equal regardless of whether they are the same object in memory.
  // `other` is the Dart SDK's parameter name from Object.==; it is the
  // right-hand operand being compared against `this`.
  @override
  bool operator ==(Object other) =>
      other is WeatherAlert &&
      other.event == event &&
      other.description == description;

  // Override hashCode whenever == is overridden. Dart requires that objects
  // which are == produce the same hashCode, otherwise Sets and Maps break.
  @override
  int get hashCode => Object.hash(event, description);
}
