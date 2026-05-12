import 'package:flutter/foundation.dart';

DateTime _fromEpochSeconds(int s) =>
    DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);

int _toEpochSeconds(DateTime dt) => dt.millisecondsSinceEpoch ~/ 1000;

/// A single UV index reading at a point in time.
@immutable
class UvForecastEntry {
  /// Creates a [UvForecastEntry].
  const UvForecastEntry({required this.time, required this.uvi});

  /// Deserializes a [UvForecastEntry] from a JSON map.
  factory UvForecastEntry.fromJson(Map<String, dynamic> json) {
    return UvForecastEntry(
      time: _fromEpochSeconds(json['dt'] as int),
      uvi: (json['uvi'] as num).toDouble(),
    );
  }

  /// The UTC timestamp of this reading.
  final DateTime time;

  /// The UV index value.
  final double uvi;

  /// Serializes this entry to a JSON map.
  Map<String, dynamic> toJson() => {'dt': _toEpochSeconds(time), 'uvi': uvi};

  @override
  bool operator ==(Object other) =>
      other is UvForecastEntry && other.time == time && other.uvi == uvi;

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
  factory UvData.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>;

    return UvData(
      currentUvi: (current['uvi'] as num).toDouble(),
      sunrise: _fromEpochSeconds(current['sunrise'] as int),
      sunset: _fromEpochSeconds(current['sunset'] as int),
      clouds: (current['clouds'] as num).toInt(),
      hourly: List.unmodifiable(
        (json['hourly'] as List? ?? []).map(
          (h) => UvForecastEntry.fromJson(h as Map<String, dynamic>),
        ),
      ),
      daily: List.unmodifiable(
        (json['daily'] as List? ?? []).map(
          (d) => UvForecastEntry.fromJson(d as Map<String, dynamic>),
        ),
      ),
      timezone: json['timezone'] as String,
      timezoneOffset: json['timezone_offset'] as int,
      fetchedAt: json['fetched_at'] != null
          ? _fromEpochSeconds(json['fetched_at'] as int)
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
  Map<String, dynamic> toJson() {
    return {
      'current': {
        'uvi': currentUvi,
        'sunrise': _toEpochSeconds(sunrise),
        'sunset': _toEpochSeconds(sunset),
        'clouds': clouds,
      },
      'hourly': hourly.map((h) => h.toJson()).toList(),
      'daily': daily.map((d) => d.toJson()).toList(),
      'timezone': timezone,
      'timezone_offset': timezoneOffset,
      'fetched_at': _toEpochSeconds(fetchedAt),
    };
  }

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

  @override
  int get hashCode => Object.hashAll([
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
