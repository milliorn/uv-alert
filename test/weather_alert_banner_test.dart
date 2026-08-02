import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/models/weather_alert.dart';
import 'package:uvalert/screens/alert_list_screen.dart';
import 'package:uvalert/widgets/weather_alert_banner.dart';

final WeatherAlert _heatAdvisory = WeatherAlert(
  event: 'Heat Advisory',
  description: 'Dangerously high UV and heat index expected today.',
  start: DateTime.utc(2026),
  end: DateTime.utc(2026, 1, 2),
  senderName: 'NWS Billings MT',
);

final WeatherAlert _floodWarning = WeatherAlert(
  event: 'Flood Warning',
  description: 'Heavy rainfall may cause flash flooding.',
  start: DateTime.utc(2026),
  end: DateTime.utc(2026, 1, 2),
  senderName: 'NWS Billings MT',
);

final WeatherAlert _fireWatch = WeatherAlert(
  event: 'Red Flag Watch',
  description: 'Critical fire weather conditions possible.',
  start: DateTime.utc(2026),
  end: DateTime.utc(2026, 1, 2),
  senderName: 'NWS Billings MT',
);

Widget _wrap(List<WeatherAlert> alerts) => MaterialApp(
  home: Scaffold(body: WeatherAlertBanner(alerts: alerts)),
);

void main() {
  testWidgets('renders nothing when there are no active alerts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const <WeatherAlert>[]));

    expect(find.byType(WeatherAlertBanner), findsOneWidget);
    expect(find.text(_heatAdvisory.event), findsNothing);
    expect(find.byIcon(Icons.warning_amber), findsNothing);
  });

  testWidgets(
    'renders the headline and description for a single active alert',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(<WeatherAlert>[_heatAdvisory]));

      expect(find.text('1 Active Alert · Heat Advisory'), findsOneWidget);
      expect(find.text(_heatAdvisory.description), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    },
  );

  testWidgets(
    'renders the count and top-priority event for multiple active alerts',
    (WidgetTester tester) async {
      // _floodWarning ("Warning") outranks _heatAdvisory ("Advisory"), so
      // it must be the one named in the headline regardless of list order.
      await tester.pumpWidget(
        _wrap(<WeatherAlert>[_heatAdvisory, _floodWarning]),
      );

      expect(find.text('2 Active Alerts · Flood Warning'), findsOneWidget);
      expect(find.text(_floodWarning.description), findsOneWidget);
    },
  );

  testWidgets('dismiss button hides a single active alert', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(<WeatherAlert>[_heatAdvisory]));
    expect(find.text('1 Active Alert · Heat Advisory'), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss alert'));
    await tester.pumpAndSettle();

    expect(find.text(_heatAdvisory.event), findsNothing);
  });

  testWidgets(
    'dismissing the top alert of a 3-alert list reveals the next-highest '
    'priority one and updates the count',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(<WeatherAlert>[_heatAdvisory, _fireWatch, _floodWarning]),
      );

      // Warning > Watch > Advisory, so Flood Warning starts on top.
      expect(find.text('3 Active Alerts · Flood Warning'), findsOneWidget);

      await tester.tap(find.byTooltip('Dismiss alert'));
      await tester.pumpAndSettle();

      expect(find.text('2 Active Alerts · Red Flag Watch'), findsOneWidget);

      await tester.tap(find.byTooltip('Dismiss alert'));
      await tester.pumpAndSettle();

      expect(find.text('1 Active Alert · Heat Advisory'), findsOneWidget);

      await tester.tap(find.byTooltip('Dismiss alert'));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialBanner), findsNothing);
    },
  );

  testWidgets('dismissing one alert does not suppress a later different '
      'alert', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(<WeatherAlert>[_heatAdvisory]));
    await tester.tap(find.byTooltip('Dismiss alert'));
    await tester.pumpAndSettle();
    expect(find.text(_heatAdvisory.event), findsNothing);

    await tester.pumpWidget(_wrap(<WeatherAlert>[_floodWarning]));
    await tester.pumpAndSettle();

    expect(find.text('1 Active Alert · Flood Warning'), findsOneWidget);
  });

  testWidgets('dismissing then refreshing to the same unchanged alert '
      'stays hidden', (WidgetTester tester) async {
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
        // A const map here would not by itself change WeatherAlert
        // identity (fromJson is a plain, non-const factory), but is kept
        // non-const to match the deliberate non-canonicalization pattern
        // used throughout this file for fromJson-built fixtures.
        // ignore: prefer_const_literals_to_create_immutables
        WeatherAlert.fromJson(<String, Object?>{
          'event': 'Heat Advisory',
          'description': 'Dangerously high UV and heat index expected today.',
          'start': 1767225600,
          'end': 1767312000,
          'sender_name': 'NWS Billings MT',
        }),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text(_heatAdvisory.event), findsNothing);
  });

  testWidgets(
    'a renewed alert (same event/description, different start/end) is not '
    'suppressed by a prior dismissal of the old occurrence',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(<WeatherAlert>[_heatAdvisory]));
      await tester.tap(find.byTooltip('Dismiss alert'));
      await tester.pumpAndSettle();
      expect(find.text(_heatAdvisory.event), findsNothing);

      // A renewed occurrence of the same alert: identical event and
      // description text, but a new start/end window (e.g. NWS re-issued
      // it for another day). Built via fromJson for the same reason as
      // above -- avoids compiler canonicalization masking the check.
      // ignore: prefer_const_literals_to_create_immutables
      final WeatherAlert renewed = WeatherAlert.fromJson(<String, Object?>{
        'event': 'Heat Advisory',
        'description': 'Dangerously high UV and heat index expected today.',
        'start': 1767312000,
        'end': 1767398400,
        'sender_name': 'NWS Billings MT',
      });

      await tester.pumpWidget(_wrap(<WeatherAlert>[renewed]));
      await tester.pumpAndSettle();

      expect(find.text('1 Active Alert · Heat Advisory'), findsOneWidget);
    },
  );

  testWidgets('clearing the alerts hides the banner even without a dismiss '
      'tap', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(<WeatherAlert>[_heatAdvisory]));
    expect(find.text('1 Active Alert · Heat Advisory'), findsOneWidget);

    await tester.pumpWidget(_wrap(const <WeatherAlert>[]));

    expect(find.text(_heatAdvisory.event), findsNothing);
  });

  testWidgets('dismissing, then a transient empty list, then the same alert '
      'returning stays hidden', (WidgetTester tester) async {
    // The dismissed set persists for the widget's lifetime, so a refresh
    // that briefly reports no active alerts before the same alert
    // reappears must not resurface a banner the user already dismissed.
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

  testWidgets('tapping "See more" navigates to AlertListScreen with the '
      'same visible list', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(<WeatherAlert>[_heatAdvisory, _fireWatch, _floodWarning]),
    );

    await tester.tap(find.text('See more'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertListScreen), findsOneWidget);

    final AlertListScreen screen = tester.widget<AlertListScreen>(
      find.byType(AlertListScreen),
    );
    expect(screen.alerts, <WeatherAlert>[
      _floodWarning,
      _fireWatch,
      _heatAdvisory,
    ]);
  });
}
