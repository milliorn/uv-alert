import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/models/weather_alert.dart';

void main() {
  const Map<String, Object?> sampleJson = <String, Object?>{
    'event': 'Heat Advisory',
    'description': 'Dangerously high UV and heat index expected today.',
  };

  test('fromJson parses event and description', () {
    final WeatherAlert alert = WeatherAlert.fromJson(sampleJson);

    expect(alert.event, 'Heat Advisory');
    expect(
      alert.description,
      'Dangerously high UV and heat index expected today.',
    );
  });

  test('fromJson throws FormatException when event is missing', () {
    expect(
      () => WeatherAlert.fromJson(const <String, Object?>{
        'description': 'Missing the event field.',
      }),
      throwsA(
        isA<FormatException>().having(
          (FormatException e) => e.message,
          'message',
          'missing required field: event',
        ),
      ),
    );
  });

  test('fromJson throws FormatException when description is missing', () {
    expect(
      () => WeatherAlert.fromJson(const <String, Object?>{
        'event': 'Heat Advisory',
      }),
      throwsA(
        isA<FormatException>().having(
          (FormatException e) => e.message,
          'message',
          'missing required field: description',
        ),
      ),
    );
  });

  test('toJson round-trips through fromJson', () {
    final WeatherAlert original = WeatherAlert.fromJson(sampleJson);
    final WeatherAlert roundTripped = WeatherAlert.fromJson(original.toJson());

    expect(roundTripped, equals(original));
  });

  test('equal when event and description match', () {
    const WeatherAlert a = WeatherAlert(
      event: 'Flood Warning',
      description: 'Heavy rainfall may cause flash flooding.',
    );
    const WeatherAlert b = WeatherAlert(
      event: 'Flood Warning',
      description: 'Heavy rainfall may cause flash flooding.',
    );

    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
  });

  test('not equal when event differs', () {
    const WeatherAlert a = WeatherAlert(
      event: 'Flood Warning',
      description: 'Same text.',
    );
    const WeatherAlert b = WeatherAlert(
      event: 'Heat Advisory',
      description: 'Same text.',
    );

    expect(a, isNot(equals(b)));
  });
}
