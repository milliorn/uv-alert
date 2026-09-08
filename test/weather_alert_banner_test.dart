import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/models/weather_alert.dart';
import 'package:uvalert/screens/alert_list_screen.dart';
import 'package:uvalert/widgets/weather_alert_banner.dart';

final WeatherAlert _heatAdvisory = WeatherAlert(
  id: 'NWS|Heat Advisory|2024-06-01T00:00:00.000Z',
  event: 'Heat Advisory',
  description: 'Dangerously high UV and heat index expected today.',
  start: DateTime.utc(2024, 6),
  end: DateTime.utc(2024, 6, 2),
  senderName: 'NWS',
);

final WeatherAlert _floodWarning = WeatherAlert(
  id: '|Flood Warning|2024-06-01T00:00:00.000Z',
  event: 'Flood Warning',
  description: 'Heavy rainfall may cause flash flooding.',
  start: DateTime.utc(2024, 6),
  end: DateTime.utc(2024, 6, 2),
);

final WeatherAlert _redFlagWarning = WeatherAlert(
  id: 'NWS|Red Flag Warning|2024-06-01T06:00:00.000Z',
  event: 'Red Flag Warning',
  description: 'Critical fire weather conditions expected.',
  start: DateTime.utc(2024, 6, 1, 6),
  end: DateTime.utc(2024, 6, 2),
  senderName: 'NWS',
);

Widget _wrap(List<WeatherAlert> alerts) => MaterialApp(
  home: Scaffold(body: WeatherAlertBanner(alerts: alerts)),
);

void main() {
  // ---------------------------------------------------------------------------
  // Empty / single alert
  // ---------------------------------------------------------------------------

  testWidgets('renders nothing when there are no active alerts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const <WeatherAlert>[]));

    expect(find.byType(WeatherAlertBanner), findsOneWidget);
    expect(find.text(_heatAdvisory.event), findsNothing);
    expect(find.byIcon(Icons.warning_amber), findsNothing);
  });

  testWidgets(
    'renders the event and description directly when there is one alert',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(<WeatherAlert>[_heatAdvisory]));

      expect(find.text(_heatAdvisory.event), findsOneWidget);
      expect(find.text(_heatAdvisory.description), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------------
  // Multiple alerts — collapsed count + top alert
  // ---------------------------------------------------------------------------

  testWidgets('shows a count and the top-severity alert event when there are '
      'multiple alerts', (WidgetTester tester) async {
    // _redFlagWarning and _floodWarning both match "Warning"; _heatAdvisory
    // matches "Advisory" and ranks lower.
    await tester.pumpWidget(
      _wrap(<WeatherAlert>[_heatAdvisory, _floodWarning]),
    );

    expect(
      find.text('2 Active Alerts · ${_floodWarning.event}'),
      findsOneWidget,
    );
    // Only the top alert's description is shown in the collapsed banner.
    expect(find.text(_heatAdvisory.description), findsNothing);
    expect(find.text(_floodWarning.description), findsOneWidget);
  });

  testWidgets(
    'breaks a tie between equally-severe alerts by earliest start time',
    (WidgetTester tester) async {
      // _floodWarning starts at 2024-06-01T00:00 (earlier);
      // _redFlagWarning starts at 2024-06-01T06:00 -- both are "Warning".
      await tester.pumpWidget(
        _wrap(<WeatherAlert>[_redFlagWarning, _floodWarning]),
      );

      expect(
        find.text('2 Active Alerts · ${_floodWarning.event}'),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows a "See more" action', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(<WeatherAlert>[_heatAdvisory]));

    expect(find.text('See more'), findsOneWidget);
  });

  testWidgets(
    'tapping "See more" opens AlertListScreen with all visible alerts',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(<WeatherAlert>[_heatAdvisory, _floodWarning]),
      );

      await tester.tap(find.text('See more'));
      await tester.pumpAndSettle();

      final AlertListScreen screen = tester.widget(
        find.byType(AlertListScreen),
      );
      expect(screen.alerts, <WeatherAlert>[_heatAdvisory, _floodWarning]);
    },
  );

  // ---------------------------------------------------------------------------
  // Dismissal — per-alert, keyed by id
  // ---------------------------------------------------------------------------

  testWidgets('dismiss button hides the banner when there is one alert', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(<WeatherAlert>[_heatAdvisory]));
    expect(find.text(_heatAdvisory.event), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss alert'));
    await tester.pumpAndSettle();

    expect(find.text(_heatAdvisory.event), findsNothing);
  });

  testWidgets(
    'dismissing the top alert of a multi-alert set surfaces the next one',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(<WeatherAlert>[_heatAdvisory, _floodWarning]),
      );
      // _floodWarning ("Warning") outranks _heatAdvisory ("Advisory").
      expect(
        find.text('2 Active Alerts · ${_floodWarning.event}'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Dismiss alert'));
      await tester.pumpAndSettle();

      // Only _heatAdvisory remains -- single-alert direct rendering.
      expect(find.text(_heatAdvisory.event), findsOneWidget);
      expect(find.textContaining('Active Alerts'), findsNothing);
    },
  );

  testWidgets(
    'dismissing one alert does not suppress a different still-active alert',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(<WeatherAlert>[_heatAdvisory]));
      await tester.tap(find.byTooltip('Dismiss alert'));
      await tester.pumpAndSettle();
      expect(find.text(_heatAdvisory.event), findsNothing);

      await tester.pumpWidget(_wrap(<WeatherAlert>[_floodWarning]));
      await tester.pumpAndSettle();

      expect(find.text(_floodWarning.event), findsOneWidget);
    },
  );

  testWidgets(
    'dismissing then refreshing to the same unchanged alert stays hidden',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(<WeatherAlert>[_heatAdvisory]));
      await tester.tap(find.byTooltip('Dismiss alert'));
      await tester.pumpAndSettle();

      // Simulates a data refresh that returns the same still-active alert.
      // Built via fromJson (not a const literal) so it's a genuinely distinct
      // object at runtime -- a const WeatherAlert with the same field values
      // would canonicalize to the exact same instance as _heatAdvisory,
      // masking a regression that swapped value-equality for identical().
      await tester.pumpWidget(
        _wrap(<WeatherAlert>[
          // A const map here would let the compiler canonicalize the
          // resulting WeatherAlert back to the same instance as
          // _heatAdvisory, defeating the point of this test.
          // ignore: prefer_const_literals_to_create_immutables
          WeatherAlert.fromJson(<String, Object?>{
            'sender_name': 'NWS',
            'event': 'Heat Advisory',
            'description': 'Dangerously high UV and heat index expected today.',
            'start': 1717200000,
            'end': 1717286400,
          }),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text(_heatAdvisory.event), findsNothing);
    },
  );

  testWidgets(
    'clearing all alerts hides the banner even without a dismiss tap',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(<WeatherAlert>[_heatAdvisory]));
      expect(find.text(_heatAdvisory.event), findsOneWidget);

      await tester.pumpWidget(_wrap(const <WeatherAlert>[]));

      expect(find.text(_heatAdvisory.event), findsNothing);
    },
  );

  testWidgets('dismissing, then a transient empty list, then the same alert '
      'returning stays hidden', (WidgetTester tester) async {
    // Regression test: a refresh that briefly reports "no active alerts"
    // before the same alert reappears must not incorrectly resurface a
    // banner the user already dismissed.
    await tester.pumpWidget(_wrap(<WeatherAlert>[_heatAdvisory]));
    await tester.tap(find.byTooltip('Dismiss alert'));
    await tester.pumpAndSettle();
    expect(find.text(_heatAdvisory.event), findsNothing);

    await tester.pumpWidget(_wrap(const <WeatherAlert>[]));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_wrap(<WeatherAlert>[_heatAdvisory]));
    await tester.pumpAndSettle();

    expect(find.text(_heatAdvisory.event), findsNothing);
  });

  testWidgets(
    'an alert removed from the active list (not dismissed) does not block '
    'a later different alert reusing no state',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(<WeatherAlert>[_heatAdvisory]));
      await tester.pumpWidget(_wrap(const <WeatherAlert>[]));
      await tester.pumpWidget(_wrap(<WeatherAlert>[_floodWarning]));
      await tester.pumpAndSettle();

      expect(find.text(_floodWarning.event), findsOneWidget);
    },
  );
}
