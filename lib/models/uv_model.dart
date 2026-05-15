import 'package:flutter/foundation.dart';
import 'package:uvalert/constants.dart';

DateTime _fromEpochSeconds(int s) =>
    DateTime.fromMillisecondsSinceEpoch(s * msPerSecond, isUtc: true);

int _toEpochSeconds(DateTime dt) => dt.millisecondsSinceEpoch ~/ msPerSecond;

/// A single UV index reading at a point in time.
@immutable
class UvForecastEntry {
  /// Creates a [UvForecastEntry].
  const UvForecastEntry({required this.time, required this.uvi});

  /// Deserializes a [UvForecastEntry] from a JSON map.
  factory UvForecastEntry.fromJson(Map<String, Object?> json) {
    return UvForecastEntry(
      time: _fromEpochSeconds(json['dt']! as int),
      uvi: (json['uvi']! as num).toDouble(),
    );
  }

  /// The UTC timestamp of this reading.
  final DateTime time;

  /// The UV index value.
  final double uvi;

  /// Serializes this entry to a JSON map.
  Map<String, Object?> toJson() => <String, Object?>{
    'dt': _toEpochSeconds(time),
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
  });

  /// Deserializes a [UvData] from a JSON map.
  ///
  /// Throws [FormatException] if the required `fetched_at` field is absent.
  factory UvData.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> current =
        json['current']! as Map<String, Object?>;

    return UvData(
      currentUvi: (current['uvi']! as num).toDouble(),
      sunrise: _fromEpochSeconds(current['sunrise']! as int),
      sunset: _fromEpochSeconds(current['sunset']! as int),
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
          ? _fromEpochSeconds(json['fetched_at']! as int)
          : throw const FormatException('missing required field: fetched_at'),
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

  /// Serializes this instance to a JSON map.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'current': <String, num>{
        'uvi': currentUvi,
        'sunrise': _toEpochSeconds(sunrise),
        'sunset': _toEpochSeconds(sunset),
        'clouds': clouds,
      },
      'hourly': hourly.map((UvForecastEntry h) => h.toJson()).toList(),
      'daily': daily.map((UvForecastEntry d) => d.toJson()).toList(),
      'timezone': timezone,
      'timezone_offset': timezoneOffset,
      'fetched_at': _toEpochSeconds(fetchedAt),
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
      listEquals(other.daily, daily);

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
  ]);
}
