import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/models/weather_alert.dart';

void main() {
  final Map<String, Object?> sampleJson = <String, Object?>{
    'sender_name': 'NWS Billings MT',
    'event': 'Heat Advisory',
    'description': 'Dangerously high UV and heat index expected today.',
    'start': 1700000000,
    'end': 1700050000,
    'tags': <String>['Extreme heat warning'],
  };

  test('fromJson parses all fields', () {
    final WeatherAlert alert = WeatherAlert.fromJson(sampleJson);

    expect(alert.event, 'Heat Advisory');
    expect(
      alert.description,
      'Dangerously high UV and heat index expected today.',
    );
    expect(alert.senderName, 'NWS Billings MT');
    expect(alert.start, DateTime.utc(2023, 11, 14, 22, 13, 20));
    expect(alert.end, DateTime.utc(2023, 11, 15, 12, 6, 40));
    expect(alert.tags, <String>['Extreme heat warning']);
  });

  test('fromJson synthesizes id as senderName|event|start', () {
    final WeatherAlert alert = WeatherAlert.fromJson(sampleJson);

    expect(
      alert.id,
      'NWS Billings MT|Heat Advisory|${alert.start.toIso8601String()}',
    );
  });

  test('fromJson throws FormatException when event is missing', () {
    expect(
      () => WeatherAlert.fromJson(const <String, Object?>{
        'description': 'Missing the event field.',
        'start': 1700000000,
        'end': 1700050000,
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
        'start': 1700000000,
        'end': 1700050000,
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

  test('fromJson throws FormatException when start is missing', () {
    expect(
      () => WeatherAlert.fromJson(const <String, Object?>{
        'event': 'Heat Advisory',
        'description': 'Missing the start field.',
        'end': 1700050000,
      }),
      throwsA(
        isA<FormatException>().having(
          (FormatException e) => e.message,
          'message',
          'missing required field: start',
        ),
      ),
    );
  });

  test('fromJson throws FormatException when end is missing', () {
    expect(
      () => WeatherAlert.fromJson(const <String, Object?>{
        'event': 'Heat Advisory',
        'description': 'Missing the end field.',
        'start': 1700000000,
      }),
      throwsA(
        isA<FormatException>().having(
          (FormatException e) => e.message,
          'message',
          'missing required field: end',
        ),
      ),
    );
  });

  test('fromJson throws FormatException (not TypeError) when event is not '
      'a string', () {
    expect(
      () => WeatherAlert.fromJson(const <String, Object?>{
        'event': 404,
        'description': 'Wrong-type event field.',
        'start': 1700000000,
        'end': 1700050000,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('fromJson throws FormatException (not TypeError) when description '
      'is not a string', () {
    expect(
      () => WeatherAlert.fromJson(const <String, Object?>{
        'event': 'Heat Advisory',
        'description': false,
        'start': 1700000000,
        'end': 1700050000,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('fromJson throws FormatException (not TypeError) when start is not '
      'an int', () {
    expect(
      () => WeatherAlert.fromJson(const <String, Object?>{
        'event': 'Heat Advisory',
        'description': 'Wrong-type start field.',
        'start': 'not-an-int',
        'end': 1700050000,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('fromJson throws FormatException (not TypeError) when end is not '
      'an int', () {
    expect(
      () => WeatherAlert.fromJson(const <String, Object?>{
        'event': 'Heat Advisory',
        'description': 'Wrong-type end field.',
        'start': 1700000000,
        'end': 'not-an-int',
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('fromJson defaults senderName to null when absent', () {
    final WeatherAlert alert = WeatherAlert.fromJson(const <String, Object?>{
      'event': 'Heat Advisory',
      'description': 'No sender given.',
      'start': 1700000000,
      'end': 1700050000,
    });

    expect(alert.senderName, isNull);
  });

  test('fromJson defaults senderName to null when wrong type', () {
    final WeatherAlert alert = WeatherAlert.fromJson(const <String, Object?>{
      'event': 'Heat Advisory',
      'description': 'Wrong-type sender.',
      'start': 1700000000,
      'end': 1700050000,
      'sender_name': 12345,
    });

    expect(alert.senderName, isNull);
  });

  test('fromJson defaults tags to empty list when absent', () {
    final WeatherAlert alert = WeatherAlert.fromJson(const <String, Object?>{
      'event': 'Heat Advisory',
      'description': 'No tags given.',
      'start': 1700000000,
      'end': 1700050000,
    });

    expect(alert.tags, isEmpty);
  });

  test('fromJson silently drops non-string entries from tags', () {
    final WeatherAlert alert = WeatherAlert.fromJson(const <String, Object?>{
      'event': 'Heat Advisory',
      'description': 'Malformed tags entries.',
      'start': 1700000000,
      'end': 1700050000,
      'tags': <Object?>['valid', 42, null, 'also valid'],
    });

    expect(alert.tags, <String>['valid', 'also valid']);
  });

  test('toJson round-trips through fromJson', () {
    final WeatherAlert original = WeatherAlert.fromJson(sampleJson);
    final WeatherAlert roundTripped = WeatherAlert.fromJson(original.toJson());

    expect(roundTripped, equals(original));
  });

  test('equal when all fields match', () {
    final WeatherAlert a = WeatherAlert.fromJson(sampleJson);
    final WeatherAlert b = WeatherAlert.fromJson(sampleJson);

    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
  });

  test('not equal when event differs', () {
    final WeatherAlert a = WeatherAlert.fromJson(sampleJson);
    final WeatherAlert b = WeatherAlert.fromJson(<String, Object?>{
      ...sampleJson,
      'event': 'Flood Warning',
    });

    expect(a, isNot(equals(b)));
  });

  test('not equal when id differs', () {
    final WeatherAlert a = WeatherAlert.fromJson(sampleJson);
    final WeatherAlert b = WeatherAlert(
      id: 'different-id',
      event: 'Heat Advisory',
      description: 'Dangerously high UV and heat index expected today.',
      start: DateTime.utc(2023, 11, 14, 22, 13, 20),
      end: DateTime.utc(2023, 11, 15, 12, 6, 40),
      senderName: 'NWS Billings MT',
      tags: const <String>['Extreme heat warning'],
    );

    expect(a, isNot(equals(b)));
  });

  test('not equal when tags differ', () {
    final WeatherAlert a = WeatherAlert.fromJson(sampleJson);
    final WeatherAlert b = WeatherAlert.fromJson(<String, Object?>{
      ...sampleJson,
      'tags': const <String>['Different tag'],
    });

    expect(a, isNot(equals(b)));
  });

  test('not equal to a non-WeatherAlert object', () {
    final WeatherAlert a = WeatherAlert.fromJson(sampleJson);

    // Deliberately comparing against a non-WeatherAlert value to exercise
    // the `other is WeatherAlert` type check in operator ==. Cast through
    // Object so the analyzer doesn't statically flag the comparison.
    expect((a as Object) == 'not a WeatherAlert', isFalse);
  });
}
