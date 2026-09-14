import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/models/weather_alert.dart';
import 'package:uvalert/providers/uv_provider.dart';
import 'package:uvalert/screens/alert_list_screen.dart';
import 'package:uvalert/widgets/weather_alert_banner.dart';

import 'fakes/fake_uv_data.dart';
import 'fakes/fake_uv_notifier.dart';

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

// A ProviderScope with uvProvider available is needed even though
// WeatherAlertBanner itself takes alerts/timezoneOffset directly (unchanged,
// still fed by DashboardScreen) -- "See more" pushes AlertListScreen, which
// reads uvProvider directly rather than from navigation arguments (see
// alert_list_screen.dart), so the pushed route needs it in scope too.
Widget _wrap(List<WeatherAlert> alerts, {int timezoneOffset = 0}) =>
    ProviderScope(
      // ignore: always_specify_types - Override not in flutter_riverpod public API
      overrides: [
        uvProvider.overrideWith(
          () => FakeDataUvNotifier(
            makeUvData(alerts: alerts, timezoneOffset: timezoneOffset),
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: WeatherAlertBanner(
            alerts: alerts,
            timezoneOffset: timezoneOffset,
          ),
        ),
      ),
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
  // Multiple alerts -- collapsed count + top alert
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

      expect(find.byType(AlertListScreen), findsOneWidget);
      expect(find.text(_heatAdvisory.event), findsOneWidget);
      expect(find.text(_floodWarning.event), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------------
  // Dismissal -- all currently-visible alerts at once, keyed by id
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
    'dismissing a multi-alert set clears every visible alert at once, '
    'using the plural tooltip',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(<WeatherAlert>[_heatAdvisory, _floodWarning]),
      );
      // _floodWarning ("Warning") outranks _heatAdvisory ("Advisory").
      expect(
        find.text('2 Active Alerts · ${_floodWarning.event}'),
        findsOneWidget,
      );
      expect(find.byTooltip('Dismiss all alerts'), findsOneWidget);

      await tester.tap(find.byTooltip('Dismiss all alerts'));
      await tester.pumpAndSettle();

      // Both alerts are gone -- not just the top-ranked one.
      expect(find.text(_heatAdvisory.event), findsNothing);
      expect(find.textContaining('Active Alerts'), findsNothing);
    },
  );

  testWidgets(
    'a three-alert set is fully cleared by a single dismiss tap',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(<WeatherAlert>[_heatAdvisory, _floodWarning, _redFlagWarning]),
      );
      expect(find.textContaining('3 Active Alerts'), findsOneWidget);

      await tester.tap(find.byTooltip('Dismiss all alerts'));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialBanner), findsNothing);
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
