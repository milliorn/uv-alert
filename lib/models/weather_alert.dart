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
  /// [id] is synthesized (OWM has no native alert id) from `senderName`,
  /// `event`, and `start`. Each part is escaped (`|` and `\` are backslash-
  /// escaped) before joining with `|`, so a delimiter character embedded in
  /// a free-form source field can't shift the field boundary and collide
  /// two distinct alerts onto the same id; an absent `senderName` joins as
  /// an empty segment rather than the literal string `"null"`, so two
  /// senderless alerts still only collide when `event` and `start` also
  /// match exactly.
  factory WeatherAlert.fromJson(Map<String, Object?> json) {
    final String event = _requireString(json, 'event');
    final String description = _requireString(json, 'description');
    final DateTime start = _requireEpochSeconds(json, 'start');
    final DateTime end = _requireEpochSeconds(json, 'end');
    final Object? senderNameValue = json['sender_name'];
    final String? senderName = senderNameValue is String
        ? senderNameValue
        : null;
    final Object? tagsValue = json['tags'];
    final List<String> tags =
        (tagsValue is List<dynamic> ? tagsValue : const <Object>[])
            .whereType<String>()
            .toList();

    return WeatherAlert(
      id: _synthesizeId(senderName, event, start),
      event: event,
      description: description,
      start: start,
      end: end,
      senderName: senderName,
      tags: tags,
    );
  }

  static String _escapeIdPart(String part) =>
      part.replaceAll(r'\', r'\\').replaceAll('|', r'\|');

  static String _synthesizeId(
    String? senderName,
    String event,
    DateTime start,
  ) {
    final String senderPart = senderName == null
        ? ''
        : _escapeIdPart(senderName);
    return '$senderPart|${_escapeIdPart(event)}|${start.toIso8601String()}';
  }

  /// Synthesized stable identity for this alert.
  ///
  /// OWM's `alerts[]` entries have no native id, so [WeatherAlert.fromJson]
  /// derives one from `senderName`, `event`, and `start` (see
  /// [_synthesizeId]) -- a plain, directly-debuggable string rather than a
  /// hash int, so it reads predictably in logs and unit tests. Callers that
  /// construct a [WeatherAlert] directly (e.g. in tests) are responsible for
  /// keeping [id] consistent with those three fields themselves, since the
  /// constructor does not re-derive or validate it.
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
