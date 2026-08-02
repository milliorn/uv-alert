import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/models/weather_alert.dart';

void main() {
  const Map<String, Object?> sampleJson = <String, Object?>{
    'event': 'Heat Advisory',
    'description': 'Dangerously high UV and heat index expected today.',
    'start': 1700000000,
    'end': 1700010000,
    'sender_name': 'NWS Billings MT',
  };

  test('fromJson parses event, description, start, end, and sender_name', () {
    final WeatherAlert alert = WeatherAlert.fromJson(sampleJson);

    expect(alert.event, 'Heat Advisory');
    expect(
      alert.description,
      'Dangerously high UV and heat index expected today.',
    );
    expect(
      alert.start,
      DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
    );
    expect(
      alert.end,
      DateTime.fromMillisecondsSinceEpoch(1700010000000, isUtc: true),
    );
    expect(alert.senderName, 'NWS Billings MT');
  });

  test('fromJson throws FormatException when event is missing', () {
    expect(
      () => WeatherAlert.fromJson(const <String, Object?>{
        'description': 'Missing the event field.',
        'start': 1700000000,
        'end': 1700010000,
        'sender_name': 'NWS Billings MT',
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
        'end': 1700010000,
        'sender_name': 'NWS Billings MT',
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
        'end': 1700010000,
        'sender_name': 'NWS Billings MT',
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
        'sender_name': 'NWS Billings MT',
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

  test('fromJson throws FormatException when sender_name is missing', () {
    expect(
      () => WeatherAlert.fromJson(const <String, Object?>{
        'event': 'Heat Advisory',
        'description': 'Missing the sender_name field.',
        'start': 1700000000,
        'end': 1700010000,
      }),
      throwsA(
        isA<FormatException>().having(
          (FormatException e) => e.message,
          'message',
          'missing required field: sender_name',
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
        'end': 1700010000,
        'sender_name': 'NWS Billings MT',
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
        'end': 1700010000,
        'sender_name': 'NWS Billings MT',
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
        'start': '1700000000',
        'end': 1700010000,
        'sender_name': 'NWS Billings MT',
      }),
      throwsA(
        isA<FormatException>().having(
          (FormatException e) => e.message,
          'message',
          'field start must be an int, got String',
        ),
      ),
    );
  });

  test('fromJson throws FormatException (not TypeError) when end is not '
      'an int', () {
    expect(
      () => WeatherAlert.fromJson(const <String, Object?>{
        'event': 'Heat Advisory',
        'description': 'Wrong-type end field.',
        'start': 1700000000,
        'end': 1700010000.0,
        'sender_name': 'NWS Billings MT',
      }),
      throwsA(
        isA<FormatException>().having(
          (FormatException e) => e.message,
          'message',
          'field end must be an int, got double',
        ),
      ),
    );
  });

  test('fromJson throws FormatException (not TypeError) when sender_name '
      'is not a string', () {
    expect(
      () => WeatherAlert.fromJson(const <String, Object?>{
        'event': 'Heat Advisory',
        'description': 'Wrong-type sender_name field.',
        'start': 1700000000,
        'end': 1700010000,
        'sender_name': 42,
      }),
      throwsA(
        isA<FormatException>().having(
          (FormatException e) => e.message,
          'message',
          'field sender_name must be a string, got int',
        ),
      ),
    );
  });

  test('toJson round-trips through fromJson', () {
    final WeatherAlert original = WeatherAlert.fromJson(sampleJson);
    final WeatherAlert roundTripped = WeatherAlert.fromJson(original.toJson());

    expect(roundTripped, equals(original));
    expect(roundTripped.start, original.start);
    expect(roundTripped.end, original.end);
    expect(roundTripped.senderName, original.senderName);
  });

  test('equal when event, description, start, end, and senderName match', () {
    final WeatherAlert a = WeatherAlert(
      event: 'Flood Warning',
      description: 'Heavy rainfall may cause flash flooding.',
      start: DateTime.utc(2026),
      end: DateTime.utc(2026, 1, 2),
      senderName: 'NWS Billings MT',
    );
    final WeatherAlert b = WeatherAlert(
      event: 'Flood Warning',
      description: 'Heavy rainfall may cause flash flooding.',
      start: DateTime.utc(2026),
      end: DateTime.utc(2026, 1, 2),
      senderName: 'NWS Billings MT',
    );

    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
  });

  test('not equal when event differs', () {
    final WeatherAlert a = WeatherAlert(
      event: 'Flood Warning',
      description: 'Same text.',
      start: DateTime.utc(2026),
      end: DateTime.utc(2026, 1, 2),
      senderName: 'NWS Billings MT',
    );
    final WeatherAlert b = WeatherAlert(
      event: 'Heat Advisory',
      description: 'Same text.',
      start: DateTime.utc(2026),
      end: DateTime.utc(2026, 1, 2),
      senderName: 'NWS Billings MT',
    );

    expect(a, isNot(equals(b)));
  });

  test('not equal when start/end differ despite identical event and '
      'description -- this is the renewed-alert identity fix', () {
    // A renewed alert reuses the same event/description text but carries a
    // new start/end window. It must NOT compare equal to the prior
    // occurrence, or dismiss-state would incorrectly mask the renewal.
    final WeatherAlert original = WeatherAlert(
      event: 'Extreme Heat Warning',
      description: 'Dangerously high temperatures expected.',
      start: DateTime.utc(2026),
      end: DateTime.utc(2026, 1, 2),
      senderName: 'NWS Billings MT',
    );
    final WeatherAlert renewed = WeatherAlert(
      event: 'Extreme Heat Warning',
      description: 'Dangerously high temperatures expected.',
      start: DateTime.utc(2026, 1, 2),
      end: DateTime.utc(2026, 1, 3),
      senderName: 'NWS Billings MT',
    );

    expect(original, isNot(equals(renewed)));
    expect(original.hashCode, isNot(equals(renewed.hashCode)));
  });

  test('not equal when senderName differs', () {
    final WeatherAlert a = WeatherAlert(
      event: 'Flood Warning',
      description: 'Same text.',
      start: DateTime.utc(2026),
      end: DateTime.utc(2026, 1, 2),
      senderName: 'NWS Billings MT',
    );
    final WeatherAlert b = WeatherAlert(
      event: 'Flood Warning',
      description: 'Same text.',
      start: DateTime.utc(2026),
      end: DateTime.utc(2026, 1, 2),
      senderName: 'NWS Great Falls MT',
    );

    expect(a, isNot(equals(b)));
  });
}
