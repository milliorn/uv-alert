class HourlyUv {
  final DateTime time;
  final double uvi;

  const HourlyUv({required this.time, required this.uvi});

  factory HourlyUv.fromJson(Map<String, dynamic> json) {
    return HourlyUv(
      time: DateTime.fromMillisecondsSinceEpoch(json['dt'] * 1000, isUtc: true),
      uvi: (json['uvi'] as num).toDouble(),
    );
  }
}

class DailyUv {
  final DateTime time;
  final double uvi;

  const DailyUv({required this.time, required this.uvi});

  factory DailyUv.fromJson(Map<String, dynamic> json) {
    return DailyUv(
      time: DateTime.fromMillisecondsSinceEpoch(json['dt'] * 1000, isUtc: true),
      uvi: (json['uvi'] as num).toDouble(),
    );
  }
}

class UvData {
  final double currentUvi;
  final DateTime sunrise;
  final DateTime sunset;
  final int clouds;
  final List<HourlyUv> hourly;
  final List<DailyUv> daily;
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
      sunrise: DateTime.fromMillisecondsSinceEpoch(
        current['sunrise'] * 1000,
        isUtc: true,
      ),
      sunset: DateTime.fromMillisecondsSinceEpoch(
        current['sunset'] * 1000,
        isUtc: true,
      ),
      clouds: (current['clouds'] as num).toInt(),
      hourly: (json['hourly'] as List)
          .map((h) => HourlyUv.fromJson(h))
          .toList(),
      daily: (json['daily'] as List).map((d) => DailyUv.fromJson(d)).toList(),
      timezone: json['timezone'] as String,
      timezoneOffset: json['timezone_offset'] as int,
      fetchedAt: DateTime.now().toUtc(),
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
