import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/models/uv_model.dart';

const int _secondsPerHour = 3600;
const int _utcMinus5OffsetSeconds = -5 * _secondsPerHour;

void main() {
  final Map<String, dynamic> sampleJson = <String, dynamic>{
    'current': <String, num>{
      'uvi': 7.5,
      'sunrise': 1700000000,
      'sunset': 1700050000,
      'clouds': 20,
    },
    'hourly': <Map<String, num>>[
      <String, num>{'dt': 1700010000, 'uvi': 5.0},
      <String, num>{'dt': 1700020000, 'uvi': 8.2},
    ],
    'daily': <Map<String, num>>[
      <String, num>{'dt': 1700000000, 'uvi': 9.1},
    ],
    'timezone': 'America/New_York',
    'timezone_offset': _utcMinus5OffsetSeconds,
    'fetched_at': 1699963200,
  };

  group('UvForecastEntry', () {
    test('equal when time and uvi match', () {
      final UvForecastEntry a = UvForecastEntry.fromJson(const <String, dynamic>{'dt': 1700010000, 'uvi': 5.0});

      final UvForecastEntry b = UvForecastEntry.fromJson(const <String, dynamic>{'dt': 1700010000, 'uvi': 5.0});

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when fields differ', () {
      final UvForecastEntry a = UvForecastEntry.fromJson(const <String, dynamic>{'dt': 1700010000, 'uvi': 5.0});

      final UvForecastEntry b = UvForecastEntry.fromJson(const <String, dynamic>{'dt': 1700010000, 'uvi': 6.0});

      expect(a, isNot(equals(b)));
    });

    test('fromJson round-trips through toJson', () {
      final UvForecastEntry entry = UvForecastEntry.fromJson(const <String, dynamic>{
        'dt': 1700010000,
        'uvi': 5.0,
      });

      final Map<String, dynamic> json = entry.toJson();
      final UvForecastEntry restored = UvForecastEntry.fromJson(json);

      expect(restored.uvi, entry.uvi);
      expect(restored.time, entry.time);
    });

    test('parses epoch seconds into UTC DateTime', () {
      final UvForecastEntry entry = UvForecastEntry.fromJson(const <String, dynamic>{'dt': 0, 'uvi': 1.0});
      expect(entry.time, DateTime.utc(1970));
    });

    test('accepts integer uvi', () {
      final UvForecastEntry entry = UvForecastEntry.fromJson(const <String, dynamic>{
        'dt': 1700000000,
        'uvi': 3,
      });

      expect(entry.uvi, 3.0);
    });
  });

  group('UvData', () {
    test('fromJson parses all fields correctly', () {
      final UvData data = UvData.fromJson(sampleJson);

      expect(data.currentUvi, 7.5);
      expect(data.clouds, 20);
      expect(data.timezone, 'America/New_York');
      expect(data.timezoneOffset, _utcMinus5OffsetSeconds);
      expect(data.hourly.length, 2);
      expect(data.daily.length, 1);
      expect(data.hourly[1].uvi, 8.2);
      expect(data.daily[0].uvi, 9.1);
    });

    test('fromJson throws FormatException when fetched_at is absent', () {
      final Map<String, dynamic> json = Map<String, dynamic>.from(sampleJson)..remove('fetched_at');

      expect(() => UvData.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('fromJson handles missing hourly/daily lists', () {
      final Map<String, dynamic> json = Map<String, dynamic>.from(sampleJson)
        ..remove('hourly')
        ..remove('daily');

      final UvData data = UvData.fromJson(json);

      expect(data.hourly, isEmpty);
      expect(data.daily, isEmpty);
    });

    test('hourly and daily lists are unmodifiable', () {
      final UvData data = UvData.fromJson(sampleJson);
      final UvForecastEntry extra = UvForecastEntry.fromJson(const <String, dynamic>{'dt': 0, 'uvi': 0.0});

      expect(() => data.hourly.add(extra), throwsUnsupportedError);
      expect(data.daily.clear, throwsUnsupportedError);
    });

    test('equal when all fields match', () {
      final UvData a = UvData.fromJson(sampleJson);
      final UvData b = UvData.fromJson(sampleJson);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when a field differs', () {
      final UvData a = UvData.fromJson(sampleJson);
      final UvData b = UvData.fromJson(<String, dynamic>{...sampleJson, 'timezone': 'America/Chicago'});

      expect(a, isNot(equals(b)));
    });

    test('toJson round-trips through fromJson', () {
      final UvData original = UvData.fromJson(sampleJson);
      final UvData restored = UvData.fromJson(original.toJson());

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
