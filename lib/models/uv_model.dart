import 'package:flutter/foundation.dart';
import 'package:uvalert/models/weather_alert.dart';
import 'package:uvalert/utils/epoch.dart';

/// Parses `rawAlerts` into [WeatherAlert]s, skipping and logging any entry
/// that is malformed (not a map, or missing/wrong-typed required fields)
/// rather than aborting the whole parse -- one bad alert shouldn't take down
/// the rest of the dashboard. Logging is unconditional (not gated on
/// [kDebugMode]) so a dropped alert always leaves a trace, including in
/// release builds. Only [FormatException] -- the exception type a malformed
/// field value actually produces -- is caught; a non-map entry is filtered
/// out via an `is` check rather than a cast, and any other [Error] indicates
/// a genuine bug and is left to propagate.
List<WeatherAlert> _parseAlerts(List<dynamic>? rawAlerts) {
  return List<WeatherAlert>.unmodifiable(
    (rawAlerts ?? <Object>[]).whereType<Map<String, Object?>>().map((
      Map<String, Object?> a,
    ) {
      try {
        return WeatherAlert.fromJson(a);
      } on FormatException catch (e) {
        debugPrint('UvData.fromJson: skipping malformed alert: $e');
        return null;
      }
    }).whereType<WeatherAlert>(),
  );
}

/// A single UV index reading at a point in time.
@immutable
class UvForecastEntry {
  /// Creates a [UvForecastEntry].
  const UvForecastEntry({required this.time, required this.uvi});

  /// Deserializes a [UvForecastEntry] from a JSON map.
  factory UvForecastEntry.fromJson(Map<String, Object?> json) {
    return UvForecastEntry(
      time: fromEpochSeconds(json['dt']! as int),
      uvi: (json['uvi']! as num).toDouble(),
    );
  }

  /// The UTC timestamp of this reading.
  final DateTime time;

  /// The UV index value.
  final double uvi;

  /// Serializes this entry to a JSON map.
  Map<String, Object?> toJson() => <String, Object?>{
    'dt': toEpochSeconds(time),
    'uvi': uvi,
  };

  // Override == for value equality: two entries with identical time and uvi
  // are equal regardless of whether they are the same object in memory.
  // Required so listEquals() in UvData.== can compare entries by value.
  // `other` is the Dart SDK's parameter name from Object.==; it is the
  // right-hand operand being compared against `this`.
  @override
  bool operator ==(Object other) =>
      other is UvForecastEntry && other.time == time && other.uvi == uvi;

  // Override hashCode whenever == is overridden. Dart requires that objects
  // which are == produce the same hashCode, otherwise Sets and Maps break.
  @override
  int get hashCode => Object.hash(time, uvi);
}

/// UV index data for a location, including current conditions and forecast.
@immutable
class UvData {
  /// Creates a [UvData] instance.
  const UvData({
    required this.currentUvi,
    required this.sunrise,
    required this.sunset,
    required this.clouds,
    required this.hourly,
    required this.daily,
    required this.timezone,
    required this.timezoneOffset,
    required this.fetchedAt,
    this.alerts = const <WeatherAlert>[],
  });

  /// Deserializes a [UvData] from a JSON map.
  ///
  /// Throws [FormatException] if the required `fetched_at` field is absent.
  ///
  /// Each entry in `alerts` is parsed independently via [_parseAlerts]: a
  /// malformed entry (e.g. missing a required field) is skipped and logged
  /// rather than aborting the whole parse, since one bad alert shouldn't
  /// take down the rest of the dashboard.
  factory UvData.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> current =
        json['current']! as Map<String, Object?>;

    return UvData(
      currentUvi: (current['uvi']! as num).toDouble(),
      sunrise: fromEpochSeconds(current['sunrise']! as int),
      sunset: fromEpochSeconds(current['sunset']! as int),
      clouds: (current['clouds']! as num).toInt(),
      hourly: List<UvForecastEntry>.unmodifiable(
        (json['hourly'] as List<dynamic>? ?? <Object>[]).map<UvForecastEntry>(
          (dynamic h) => UvForecastEntry.fromJson(h as Map<String, Object?>),
        ),
      ),
      daily: List<UvForecastEntry>.unmodifiable(
        (json['daily'] as List<dynamic>? ?? <Object>[]).map<UvForecastEntry>(
          (dynamic d) => UvForecastEntry.fromJson(d as Map<String, Object?>),
        ),
      ),
      timezone: json['timezone']! as String,
      timezoneOffset: json['timezone_offset']! as int,
      fetchedAt: json['fetched_at'] != null
          ? fromEpochSeconds(json['fetched_at']! as int)
          : throw const FormatException('missing required field: fetched_at'),
      alerts: _parseAlerts(json['alerts'] as List<dynamic>?),
    );
  }

  /// The current UV index.
  final double currentUvi;

  /// Sunrise time in UTC.
  final DateTime sunrise;

  /// Sunset time in UTC.
  final DateTime sunset;

  /// Cloud coverage percentage (0-100).
  final int clouds;

  /// Hourly UV index forecast entries.
  final List<UvForecastEntry> hourly;

  /// Daily UV index forecast entries.
  final List<UvForecastEntry> daily;

  /// IANA timezone name for the location (e.g. `America/New_York`).
  final String timezone;

  /// UTC offset in seconds for the location's timezone.
  final int timezoneOffset;

  /// When this data was fetched from the server, in UTC.
  final DateTime fetchedAt;

  /// Active government weather alerts for this location.
  ///
  /// Unlike every other field on [UvData], this is an optional constructor
  /// parameter defaulting to an empty list rather than `required`, mirroring
  /// OWM's own `alerts` field being optional in the source payload: most
  /// locations have no active alerts most of the time, so "no alerts" is
  /// the natural default rather than something every caller must state.
  final List<WeatherAlert> alerts;

  /// Serializes this instance to a JSON map.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'current': <String, num>{
        'uvi': currentUvi,
        'sunrise': toEpochSeconds(sunrise),
        'sunset': toEpochSeconds(sunset),
        'clouds': clouds,
      },
      'hourly': hourly.map((UvForecastEntry h) => h.toJson()).toList(),
      'daily': daily.map((UvForecastEntry d) => d.toJson()).toList(),
      'timezone': timezone,
      'timezone_offset': timezoneOffset,
      'fetched_at': toEpochSeconds(fetchedAt),
      'alerts': alerts.map((WeatherAlert a) => a.toJson()).toList(),
    };
  }

  // Override == for value equality: two UvData instances with identical fields
  // are equal regardless of whether they are the same object in memory.
  // Enables value-based comparisons in tests and correct behavior with
  // listEquals. `other` is the Dart SDK's parameter name from Object.==; it is
  // the right-hand operand being compared against `this`.
  @override
  bool operator ==(Object other) =>
      other is UvData &&
      other.currentUvi == currentUvi &&
      other.sunrise == sunrise &&
      other.sunset == sunset &&
      other.clouds == clouds &&
      other.timezone == timezone &&
      other.timezoneOffset == timezoneOffset &&
      other.fetchedAt == fetchedAt &&
      listEquals(other.hourly, hourly) &&
      listEquals(other.daily, daily) &&
      listEquals(other.alerts, alerts);

  // Override hashCode whenever == is overridden. Dart requires that objects
  // which are == produce the same hashCode, otherwise Sets and Maps break.
  @override
  int get hashCode => Object.hashAll(<Object?>[
    currentUvi,
    sunrise,
    sunset,
    clouds,
    timezone,
    timezoneOffset,
    fetchedAt,
    ...hourly,
    ...daily,
    ...alerts,
  ]);
}
