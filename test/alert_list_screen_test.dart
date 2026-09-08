import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/models/weather_alert.dart';
import 'package:uvalert/screens/alert_list_screen.dart';

final WeatherAlert _heatAdvisory = WeatherAlert(
  id: 'NWS|Heat Advisory|2024-06-01T00:00:00.000Z',
  event: 'Heat Advisory',
  description: 'Dangerously high UV and heat index expected today.',
  start: DateTime.utc(2024, 6, 1, 8),
  end: DateTime.utc(2024, 6, 1, 20),
  senderName: 'NWS Fresno',
);

final WeatherAlert _floodWarning = WeatherAlert(
  id: '|Flood Warning|2024-06-01T00:00:00.000Z',
  event: 'Flood Warning',
  description: 'Heavy rainfall may cause flash flooding.',
  start: DateTime.utc(2024, 6, 1, 6),
  end: DateTime.utc(2024, 6, 2),
);

Widget _wrap(List<WeatherAlert> alerts) =>
    MaterialApp(home: AlertListScreen(alerts: alerts));

void main() {
  testWidgets('renders an app bar titled "Active Alerts"', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(<WeatherAlert>[_heatAdvisory]));

    expect(find.widgetWithText(AppBar, 'Active Alerts'), findsOneWidget);
  });

  testWidgets('renders one card per alert', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(<WeatherAlert>[_heatAdvisory, _floodWarning]),
    );

    expect(find.text(_heatAdvisory.event), findsOneWidget);
    expect(find.text(_floodWarning.event), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(2));
  });

  testWidgets('renders the full, untruncated description for each alert', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(<WeatherAlert>[_heatAdvisory]));

    final Text descriptionWidget = tester.widget(
      find.text(_heatAdvisory.description),
    );
    expect(descriptionWidget.maxLines, isNull);
  });

  testWidgets('renders the sender name when present', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(<WeatherAlert>[_heatAdvisory]));

    expect(find.textContaining('NWS Fresno'), findsOneWidget);
  });

  testWidgets('omits a sender segment when senderName is null', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(<WeatherAlert>[_floodWarning]));

    expect(find.textContaining('null'), findsNothing);
  });

  testWidgets('each alert card is keyed by the alert\'s stable id', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(<WeatherAlert>[_heatAdvisory, _floodWarning]),
    );

    final Finder heatCard = find.ancestor(
      of: find.text(_heatAdvisory.event),
      matching: find.byType(Card),
    );
    expect(tester.widget(heatCard).key, ValueKey<String>(_heatAdvisory.id));
  });
}
