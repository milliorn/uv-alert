import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/models/weather_alert.dart';
import 'package:uvalert/utils/alert_severity.dart';

WeatherAlert _alert({
  required String event,
  DateTime? start,
  String id = 'id',
  String description = 'description',
}) => WeatherAlert(
  id: id,
  event: event,
  description: description,
  start: start ?? DateTime.utc(2024, 6),
  end: DateTime.utc(2024, 6, 2),
);

void main() {
  group('alertSeverityOf', () {
    test('matches "Warning" case-insensitively as AlertSeverity.warning', () {
      expect(
        alertSeverityOf(_alert(event: 'Excessive Heat WARNING')),
        AlertSeverity.warning,
      );
    });

    test('matches "Watch" as AlertSeverity.watch', () {
      expect(
        alertSeverityOf(_alert(event: 'Tornado Watch')),
        AlertSeverity.watch,
      );
    });

    test('matches "Advisory" as AlertSeverity.advisory', () {
      expect(
        alertSeverityOf(_alert(event: 'Heat Advisory')),
        AlertSeverity.advisory,
      );
    });

    test('returns AlertSeverity.unknown for an unrecognized event name', () {
      expect(
        alertSeverityOf(_alert(event: 'Special Weather Statement')),
        AlertSeverity.unknown,
      );
    });
  });

  group('topAlert', () {
    test('ranks Warning above Watch above Advisory above unknown', () {
      final WeatherAlert warning = _alert(event: 'Flood Warning', id: 'w');
      final WeatherAlert watch = _alert(event: 'Flood Watch', id: 'wa');
      final WeatherAlert advisory = _alert(event: 'Heat Advisory', id: 'a');
      final WeatherAlert unknown = _alert(event: 'Weather Statement', id: 'u');

      expect(
        topAlert(<WeatherAlert>[unknown, advisory, watch, warning]),
        warning,
      );
      expect(topAlert(<WeatherAlert>[unknown, advisory, watch]), watch);
      expect(topAlert(<WeatherAlert>[unknown, advisory]), advisory);
      expect(topAlert(<WeatherAlert>[unknown]), unknown);
    });

    test(
      'breaks a tie between equally-severe alerts by earliest start time',
      () {
        final WeatherAlert earlier = _alert(
          event: 'Flood Warning',
          id: 'earlier',
        );
        final WeatherAlert later = _alert(
          event: 'Fire Warning',
          id: 'later',
          start: DateTime.utc(2024, 6, 1, 6),
        );

        expect(topAlert(<WeatherAlert>[later, earlier]), earlier);
        expect(topAlert(<WeatherAlert>[earlier, later]), earlier);
      },
    );

    test('returns the only alert in a single-element list', () {
      final WeatherAlert only = _alert(event: 'Heat Advisory');
      expect(topAlert(<WeatherAlert>[only]), only);
    });

    test(
      'breaks a tie between alerts with equal severity and equal start time '
      'by id, so the result does not depend on payload order',
      () {
        final DateTime sameStart = DateTime.utc(2024, 6, 1, 6);
        final WeatherAlert a = _alert(
          event: 'Flood Warning',
          id: 'a',
          start: sameStart,
        );
        final WeatherAlert b = _alert(
          event: 'Fire Warning',
          id: 'b',
          start: sameStart,
        );

        expect(topAlert(<WeatherAlert>[b, a]), a);
        expect(topAlert(<WeatherAlert>[a, b]), a);
      },
    );

    test(
      'breaks a tie between two distinct alerts sharing an id (same '
      'senderName/event/start, different description) by description, so '
      'the result does not depend on payload order even when the '
      'synthesized id does not disambiguate them',
      () {
        final DateTime sameStart = DateTime.utc(2024, 6, 1, 6);
        final WeatherAlert a = _alert(
          event: 'Flood Warning',
          id: 'shared',
          start: sameStart,
          description: 'aaa',
        );
        final WeatherAlert b = _alert(
          event: 'Flood Warning',
          id: 'shared',
          start: sameStart,
          description: 'bbb',
        );

        expect(topAlert(<WeatherAlert>[b, a]), a);
        expect(topAlert(<WeatherAlert>[a, b]), a);
      },
    );
  });
}
