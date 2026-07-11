import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/models/weather_alert.dart';
import 'package:uvalert/widgets/weather_alert_banner.dart';

const WeatherAlert _heatAdvisory = WeatherAlert(
  event: 'Heat Advisory',
  description: 'Dangerously high UV and heat index expected today.',
);

const WeatherAlert _floodWarning = WeatherAlert(
  event: 'Flood Warning',
  description: 'Heavy rainfall may cause flash flooding.',
);

Widget _wrap(WeatherAlert? alert) =>
    MaterialApp(home: Scaffold(body: WeatherAlertBanner(alert: alert)));

void main() {
  testWidgets('renders nothing when there is no active alert', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(null));

    expect(find.byType(WeatherAlertBanner), findsOneWidget);
    expect(find.text(_heatAdvisory.event), findsNothing);
    expect(find.byIcon(Icons.warning_amber), findsNothing);
  });

  testWidgets('renders the event and description when an alert is active', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(_heatAdvisory));

    expect(find.text(_heatAdvisory.event), findsOneWidget);
    expect(find.text(_heatAdvisory.description), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
  });

  testWidgets('dismiss button hides the banner', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(_heatAdvisory));
    expect(find.text(_heatAdvisory.event), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss alert'));
    await tester.pumpAndSettle();

    expect(find.text(_heatAdvisory.event), findsNothing);
  });

  testWidgets('dismissing one alert does not suppress a later different '
      'alert', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(_heatAdvisory));
    await tester.tap(find.byTooltip('Dismiss alert'));
    await tester.pumpAndSettle();
    expect(find.text(_heatAdvisory.event), findsNothing);

    await tester.pumpWidget(_wrap(_floodWarning));
    await tester.pumpAndSettle();

    expect(find.text(_floodWarning.event), findsOneWidget);
  });

  testWidgets('dismissing then refreshing to the same unchanged alert '
      'stays hidden', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(_heatAdvisory));
    await tester.tap(find.byTooltip('Dismiss alert'));
    await tester.pumpAndSettle();

    // Simulates a data refresh that returns the same still-active alert.
    // Built via fromJson (not a const literal) so it's a genuinely distinct
    // object at runtime -- a const WeatherAlert with the same field values
    // would canonicalize to the exact same instance as _heatAdvisory,
    // masking a regression that swapped value-equality for identical().
    await tester.pumpWidget(
      _wrap(
        // A const map here would let the compiler canonicalize the
        // resulting WeatherAlert back to the same instance as
        // _heatAdvisory, defeating the point of this test.
        // ignore: prefer_const_literals_to_create_immutables
        WeatherAlert.fromJson(<String, Object?>{
          'event': 'Heat Advisory',
          'description': 'Dangerously high UV and heat index expected today.',
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(_heatAdvisory.event), findsNothing);
  });

  testWidgets('clearing the alert hides the banner even without a dismiss '
      'tap', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(_heatAdvisory));
    expect(find.text(_heatAdvisory.event), findsOneWidget);

    await tester.pumpWidget(_wrap(null));

    expect(find.text(_heatAdvisory.event), findsNothing);
  });
}
