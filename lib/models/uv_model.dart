DateTime _fromEpochSeconds(int s) =>
    DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);

int _toEpochSeconds(DateTime dt) => dt.millisecondsSinceEpoch ~/ 1000;

class UvForecastEntry {
  final DateTime time;
  final double uvi;

  const UvForecastEntry({required this.time, required this.uvi});

  factory UvForecastEntry.fromJson(Map<String, dynamic> json) {
    return UvForecastEntry(
      time: _fromEpochSeconds(json['dt'] as int),
      uvi: (json['uvi'] as num).toDouble(),
    );
  }
}

class UvData {
  final double currentUvi;
  final DateTime sunrise;
  final DateTime sunset;
  final int clouds;
  final List<UvForecastEntry> hourly;
  final List<UvForecastEntry> daily;
  final String timezone;
  final int timezoneOffset;
  final DateTime fetchedAt;

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

  factory UvData.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>;

    return UvData(
      currentUvi: (current['uvi'] as num).toDouble(),
      sunrise: _fromEpochSeconds(current['sunrise'] as int),
      sunset: _fromEpochSeconds(current['sunset'] as int),
      clouds: (current['clouds'] as num).toInt(),
      hourly: (json['hourly'] as List? ?? [])
          .map((h) => UvForecastEntry.fromJson(h as Map<String, dynamic>))
          .toList(),
      daily: (json['daily'] as List? ?? [])
          .map((d) => UvForecastEntry.fromJson(d as Map<String, dynamic>))
          .toList(),
      timezone: json['timezone'] as String,
      timezoneOffset: json['timezone_offset'] as int,
      fetchedAt: json['fetched_at'] != null
          ? DateTime.parse(json['fetched_at'] as String)
          : DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current': {
        'uvi': currentUvi,
        'sunrise': sunrise.millisecondsSinceEpoch ~/ 1000,
        'sunset': sunset.millisecondsSinceEpoch ~/ 1000,
        'clouds': clouds,
      },
      'hourly': hourly
          .map(
            (h) => {'dt': h.time.millisecondsSinceEpoch ~/ 1000, 'uvi': h.uvi},
          )
          .toList(),
      'daily': daily
          .map(
            (d) => {'dt': d.time.millisecondsSinceEpoch ~/ 1000, 'uvi': d.uvi},
          )
          .toList(),
      'timezone': timezone,
      'timezone_offset': timezoneOffset,
      'fetched_at': fetchedAt.toIso8601String(),
    };
  }
}
