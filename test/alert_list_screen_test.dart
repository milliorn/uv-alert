import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/models/weather_alert.dart';
import 'package:uvalert/screens/alert_list_screen.dart';

final WeatherAlert _heatAdvisory = WeatherAlert(
  event: 'Heat Advisory',
  description: 'Dangerously high UV and heat index expected today.',
  start: DateTime.utc(2026, 8, 2, 14),
  end: DateTime.utc(2026, 8, 3, 8, 30),
  senderName: 'NWS Billings MT',
);

final WeatherAlert _floodWarning = WeatherAlert(
  event: 'Flood Warning',
  description: 'Heavy rainfall may cause flash flooding.',
  start: DateTime.utc(2026, 8, 2),
  end: DateTime.utc(2026, 8, 2, 12),
  senderName: 'NWS Great Falls MT',
);

Widget _wrap(List<WeatherAlert> alerts) =>
    MaterialApp(home: AlertListScreen(alerts: alerts));

void main() {
  testWidgets('renders the app bar title', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const <WeatherAlert>[]));

    expect(find.text('Active Alerts'), findsOneWidget);
  });

  testWidgets(
    "renders a single alert's event, full description, sender, and time "
    'window',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(<WeatherAlert>[_heatAdvisory]));

      expect(find.text(_heatAdvisory.event), findsOneWidget);
      expect(find.text(_heatAdvisory.description), findsOneWidget);
      expect(
        find.text('Issued by ${_heatAdvisory.senderName}'),
        findsOneWidget,
      );
      expect(find.text('Aug 2, 2:00 PM – Aug 3, 8:30 AM'), findsOneWidget);
    },
  );

  testWidgets('renders multiple alerts in list order', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(<WeatherAlert>[_heatAdvisory, _floodWarning]),
    );

    expect(find.text(_heatAdvisory.event), findsOneWidget);
    expect(find.text(_floodWarning.event), findsOneWidget);

    final double heatY = tester.getTopLeft(find.text(_heatAdvisory.event)).dy;
    final double floodY = tester.getTopLeft(find.text(_floodWarning.event)).dy;
    expect(heatY, lessThan(floodY));

    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('each item has a stable key across rebuilds with the same '
      'list', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(<WeatherAlert>[_heatAdvisory, _floodWarning]),
    );

    final Key firstKey = tester
        .widgetList<Padding>(find.byType(Padding))
        .firstWhere((Padding p) => p.key != null)
        .key!;

    await tester.pumpWidget(
      _wrap(<WeatherAlert>[_heatAdvisory, _floodWarning]),
    );

    final Key secondKey = tester
        .widgetList<Padding>(find.byType(Padding))
        .firstWhere((Padding p) => p.key != null)
        .key!;

    expect(firstKey, secondKey);
    expect(
      find.byKey(
        const ValueKey<String>(
          'Heat Advisory|2026-08-02T14:00:00.000Z|2026-08-03T08:30:00.000Z',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('item keys track their alert through a reorder', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(<WeatherAlert>[_heatAdvisory, _floodWarning]),
    );

    expect(
      find.byKey(
        ValueKey<String>(
          '${_floodWarning.event}|'
          '${_floodWarning.start.toIso8601String()}|'
          '${_floodWarning.end.toIso8601String()}',
        ),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _wrap(<WeatherAlert>[_floodWarning, _heatAdvisory]),
    );

    // The reordered list still resolves the same stable key for
    // _floodWarning, now as the first item.
    expect(
      find.byKey(
        ValueKey<String>(
          '${_floodWarning.event}|'
          '${_floodWarning.start.toIso8601String()}|'
          '${_floodWarning.end.toIso8601String()}',
        ),
      ),
      findsOneWidget,
    );
  });
}
