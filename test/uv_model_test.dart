import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/models/uv_model.dart';

void main() {
  final sampleJson = <String, dynamic>{
    'current': {
      'uvi': 7.5,
      'sunrise': 1700000000,
      'sunset': 1700050000,
      'clouds': 20,
    },
    'hourly': [
      {'dt': 1700010000, 'uvi': 5.0},
      {'dt': 1700020000, 'uvi': 8.2},
    ],
    'daily': [
      {'dt': 1700000000, 'uvi': 9.1},
    ],
    'timezone': 'America/New_York',
    'timezone_offset': -18000,
    'fetched_at': '2023-11-14T12:00:00.000Z',
  };

  group('UvForecastEntry', () {
    test('fromJson round-trips through toJson', () {
      final entry = UvForecastEntry.fromJson({'dt': 1700010000, 'uvi': 5.0});
      final json = entry.toJson();
      final restored = UvForecastEntry.fromJson(json);

      expect(restored.uvi, entry.uvi);
      expect(restored.time, entry.time);
    });

    test('parses epoch seconds into UTC DateTime', () {
      final entry = UvForecastEntry.fromJson({'dt': 0, 'uvi': 1.0});
      expect(entry.time, DateTime.utc(1970, 1, 1));
    });

    test('accepts integer uvi', () {
      final entry = UvForecastEntry.fromJson({'dt': 1700000000, 'uvi': 3});
      expect(entry.uvi, 3.0);
    });
  });

  group('UvData', () {
    test('fromJson parses all fields correctly', () {
      final data = UvData.fromJson(sampleJson);

      expect(data.currentUvi, 7.5);
      expect(data.clouds, 20);
      expect(data.timezone, 'America/New_York');
      expect(data.timezoneOffset, -18000);
      expect(data.hourly.length, 2);
      expect(data.daily.length, 1);
      expect(data.hourly[1].uvi, 8.2);
      expect(data.daily[0].uvi, 9.1);
    });

    test('fromJson falls back to now when fetched_at is absent', () {
      final before = DateTime.now().toUtc().subtract(
        const Duration(seconds: 1),
      );
      final json = Map<String, dynamic>.from(sampleJson)..remove('fetched_at');
      final data = UvData.fromJson(json);
      final after = DateTime.now().toUtc().add(const Duration(seconds: 1));

      expect(data.fetchedAt.isAfter(before), isTrue);
      expect(data.fetchedAt.isBefore(after), isTrue);
    });

    test('fromJson handles missing hourly/daily lists', () {
      final json = Map<String, dynamic>.from(sampleJson)
        ..remove('hourly')
        ..remove('daily');
      final data = UvData.fromJson(json);

      expect(data.hourly, isEmpty);
      expect(data.daily, isEmpty);
    });

    test('toJson round-trips through fromJson', () {
      final original = UvData.fromJson(sampleJson);
      final restored = UvData.fromJson(original.toJson());

      expect(restored.currentUvi, original.currentUvi);
      expect(restored.clouds, original.clouds);
      expect(restored.timezone, original.timezone);
      expect(restored.timezoneOffset, original.timezoneOffset);
      expect(restored.sunrise, original.sunrise);
      expect(restored.sunset, original.sunset);
      expect(restored.hourly.length, original.hourly.length);
      expect(restored.daily.length, original.daily.length);
      expect(restored.fetchedAt, original.fetchedAt);
    });
  });
}
