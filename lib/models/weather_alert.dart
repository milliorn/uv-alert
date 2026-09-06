import 'package:flutter/foundation.dart';
import 'package:uvalert/utils/epoch.dart';

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

/// Returns `json[field]` as epoch seconds converted to a UTC [DateTime], or
/// throws [FormatException] if the field is absent or not an [int].
DateTime _requireEpochSeconds(Map<String, Object?> json, String field) {
  final Object? value = json[field];

  if (value == null) {
    throw FormatException('missing required field: $field');
  }

  if (value is! int) {
    throw FormatException(
      'field $field must be an int, got ${value.runtimeType}',
    );
  }
  
  return fromEpochSeconds(value);
}

/// A government weather alert to surface on the dashboard banner.
///
/// Mirrors the subset of OpenWeatherMap's `alerts[]` entry fields the
/// banner and full alert list need to render: `sender_name`, `event`,
/// `start`, `end`, `description`, and `tags`. See
/// `docs/adr/0002-owm-one-call-api.md`.
@immutable
class WeatherAlert {
  /// Creates a [WeatherAlert].
  const WeatherAlert({
    required this.id,
    required this.event,
    required this.description,
    required this.start,
    required this.end,
    this.senderName,
    this.tags = const <String>[],
  });

  /// Deserializes a [WeatherAlert] from a JSON map.
  ///
  /// Throws [FormatException] if `event`, `description`, `start`, or `end`
  /// is absent or the wrong type. `sender_name` is optional. `tags` is
  /// parsed defensively: a missing or malformed `tags` list defaults to
  /// empty, and any non-string entry within it is silently dropped, since
  /// tags are non-critical metadata not worth failing the whole alert over.
  ///
  /// [id] is synthesized (OWM has no native alert id) as
  /// `'$senderName|$event|${start.toIso8601String()}'`.
  factory WeatherAlert.fromJson(Map<String, Object?> json) {
    final String event = _requireString(json, 'event');
    final String description = _requireString(json, 'description');
    final DateTime start = _requireEpochSeconds(json, 'start');
    final DateTime end = _requireEpochSeconds(json, 'end');
    final Object? senderNameValue = json['sender_name'];
    final String? senderName = senderNameValue is String
        ? senderNameValue
        : null;
    final List<String> tags = (json['tags'] as List<dynamic>? ?? <Object>[])
        .whereType<String>()
        .toList();

    return WeatherAlert(
      id: '$senderName|$event|${start.toIso8601String()}',
      event: event,
      description: description,
      start: start,
      end: end,
      senderName: senderName,
      tags: tags,
    );
  }

  /// Synthesized stable identity for this alert.
  ///
  /// OWM's `alerts[]` entries have no native id, so this is derived as
  /// `'$senderName|$event|${start.toIso8601String()}'` -- a plain,
  /// directly-debuggable string rather than a hash int, so it reads
  /// predictably in logs and unit tests.
  final String id;

  /// Short alert name, e.g. "Heat Advisory".
  final String event;

  /// Full alert body text.
  final String description;

  /// When this alert becomes active, in UTC.
  final DateTime start;

  /// When this alert expires, in UTC.
  final DateTime end;

  /// The issuing agency, e.g. "NWS Billings MT", or `null` if unknown.
  final String? senderName;

  /// Free-form category tags supplied by the source, e.g. `["Extreme
  /// heat warning"]`. Defaults to empty.
  final List<String> tags;

  /// Serializes this instance to a JSON map.
  Map<String, Object?> toJson() => <String, Object?>{
    'event': event,
    'description': description,
    'start': toEpochSeconds(start),
    'end': toEpochSeconds(end),
    'sender_name': senderName,
    'tags': tags,
  };

  // Override == for value equality: two alerts with identical fields are
  // equal regardless of whether they are the same object in memory.
  // `other` is the Dart SDK's parameter name from Object.==; it is the
  // right-hand operand being compared against `this`.
  @override
  bool operator ==(Object other) =>
      other is WeatherAlert &&
      other.id == id &&
      other.event == event &&
      other.description == description &&
      other.start == start &&
      other.end == end &&
      other.senderName == senderName &&
      listEquals(other.tags, tags);

  // Override hashCode whenever == is overridden. Dart requires that objects
  // which are == produce the same hashCode, otherwise Sets and Maps break.
  @override
  int get hashCode => Object.hash(
    id,
    event,
    description,
    start,
    end,
    senderName,
    Object.hashAll(tags),
  );
}
