import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/models/weather_alert.dart';
import 'package:uvalert/utils/weather_alert_priority.dart';

WeatherAlert _alert({
  required String event,
  DateTime? start,
  String description = 'Some description.',
  String senderName = 'NWS Billings MT',
}) => WeatherAlert(
  event: event,
  description: description,
  start: start ?? DateTime.utc(2026),
  end: DateTime.utc(2026, 1, 2),
  senderName: senderName,
);

void main() {
  test('does not mutate the input list', () {
    final List<WeatherAlert> input = <WeatherAlert>[
      _alert(event: 'Heat Advisory'),
      _alert(event: 'Extreme Heat Warning'),
    ];
    final List<WeatherAlert> original = List<WeatherAlert>.of(input);

    prioritizedAlerts(input);

    expect(input, orderedEquals(original));
  });

  test('ranks Warning above Watch, Advisory, and other', () {
    final WeatherAlert warning = _alert(event: 'Extreme Heat Warning');
    final WeatherAlert watch = _alert(event: 'Red Flag Watch');
    final WeatherAlert advisory = _alert(event: 'Heat Advisory');
    final WeatherAlert other = _alert(event: 'Special Weather Statement');

    final List<WeatherAlert> sorted = prioritizedAlerts(<WeatherAlert>[
      other,
      advisory,
      watch,
      warning,
    ]);

    expect(sorted, <WeatherAlert>[warning, watch, advisory, other]);
  });

  test('severity matching is case-insensitive', () {
    final WeatherAlert warning = _alert(event: 'extreme heat WARNING');
    final WeatherAlert advisory = _alert(event: 'heat ADVISORY');

    final List<WeatherAlert> sorted = prioritizedAlerts(<WeatherAlert>[
      advisory,
      warning,
    ]);

    expect(sorted, <WeatherAlert>[warning, advisory]);
  });

  test('ties within the same severity rank break on earliest start '
      'ascending', () {
    final WeatherAlert later = _alert(
      event: 'Flood Warning',
      start: DateTime.utc(2026, 1, 3),
    );
    final WeatherAlert earlier = _alert(event: 'Fire Weather Warning');

    final List<WeatherAlert> sorted = prioritizedAlerts(<WeatherAlert>[
      later,
      earlier,
    ]);

    expect(sorted, <WeatherAlert>[earlier, later]);
  });

  test('final tie-break is event name alphabetically ascending', () {
    final DateTime sameStart = DateTime.utc(2026);
    final WeatherAlert zWarning = _alert(
      event: 'Zebra Warning',
      start: sameStart,
    );
    final WeatherAlert aWarning = _alert(
      event: 'Amber Warning',
      start: sameStart,
    );

    final List<WeatherAlert> sorted = prioritizedAlerts(<WeatherAlert>[
      zWarning,
      aWarning,
    ]);

    expect(sorted, <WeatherAlert>[aWarning, zWarning]);
  });

  test('empty input returns an empty list', () {
    expect(prioritizedAlerts(<WeatherAlert>[]), isEmpty);
  });
}
