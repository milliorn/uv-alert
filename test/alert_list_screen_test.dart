import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/models/weather_alert.dart';
import 'package:uvalert/providers/uv_provider.dart';
import 'package:uvalert/screens/alert_list_screen.dart';

import 'fakes/fake_uv_data.dart';
import 'fakes/fake_uv_notifier.dart';

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

Widget _wrap(
  List<WeatherAlert> alerts, {
  int timezoneOffset = 0,
  FakeDataUvNotifier? notifier,
}) => ProviderScope(
  // ignore: always_specify_types - Override not in flutter_riverpod public API
  overrides: [
    uvProvider.overrideWith(
      () =>
          notifier ??
          FakeDataUvNotifier(
            makeUvData(alerts: alerts, timezoneOffset: timezoneOffset),
          ),
    ),
  ],
  child: const MaterialApp(home: AlertListScreen()),
);

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

  testWidgets("each alert card is keyed by the alert's stable id", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(<WeatherAlert>[_heatAdvisory, _floodWarning]),
    );

    expect(find.byKey(ValueKey<String>(_heatAdvisory.id)), findsOneWidget);
    expect(find.byKey(ValueKey<String>(_floodWarning.id)), findsOneWidget);
  });

  testWidgets(
    'renders the alert time window in the location-local time, not raw UTC',
    (WidgetTester tester) async {
      // _heatAdvisory.start is 08:00 UTC. A -25200s (UTC-7) offset shifts
      // that to 1:00 AM local -- if the raw UTC hour were shown instead,
      // this would read "8:00 AM".
      await tester.pumpWidget(
        _wrap(<WeatherAlert>[_heatAdvisory], timezoneOffset: -25200),
      );

      expect(find.textContaining('1:00 AM'), findsOneWidget);
      expect(find.textContaining('8:00 AM'), findsNothing);
    },
  );

  testWidgets(
    'includes the date in the time window when an alert spans multiple '
    'local days, so a cross-midnight window is not ambiguous',
    (WidgetTester tester) async {
      // _floodWarning runs 06:00 Jun 1 -> 00:00 Jun 2 at UTC+0 (timezoneOffset
      // 0), so its local start and end fall on different calendar days.
      await tester.pumpWidget(_wrap(<WeatherAlert>[_floodWarning]));

      expect(find.textContaining('Jun 1 6:00 AM'), findsOneWidget);
      expect(find.textContaining('Jun 2 12:00 AM'), findsOneWidget);
      // Without the date, both instants would show as bare times with no
      // way to tell the window spans two days.
      expect(find.text('6:00 AM - 12:00 AM'), findsNothing);
    },
  );

  testWidgets(
    'omits the date from the time window when an alert stays within a '
    'single local day',
    (WidgetTester tester) async {
      // _heatAdvisory runs 08:00 -> 20:00 on the same UTC day.
      await tester.pumpWidget(_wrap(<WeatherAlert>[_heatAdvisory]));

      expect(find.textContaining('8:00 AM - 8:00 PM'), findsOneWidget);
      expect(find.textContaining('Jun'), findsNothing);
    },
  );

  testWidgets('reflects a later data refresh live, rather than showing a stale '
      'snapshot from when the screen was opened', (WidgetTester tester) async {
    final FakeDataUvNotifier notifier = FakeDataUvNotifier(
      makeUvData(alerts: <WeatherAlert>[_heatAdvisory]),
    );

    await tester.pumpWidget(
      _wrap(<WeatherAlert>[_heatAdvisory], notifier: notifier),
    );
    expect(find.text(_heatAdvisory.event), findsOneWidget);
    expect(find.text(_floodWarning.event), findsNothing);

    // Simulates a background refresh that adds a new alert while this
    // screen is already open.
    notifier.updateData(
      makeUvData(alerts: <WeatherAlert>[_heatAdvisory, _floodWarning]),
    );
    await tester.pump();

    expect(find.text(_heatAdvisory.event), findsOneWidget);
    expect(find.text(_floodWarning.event), findsOneWidget);
  });
}
