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

// WeatherAlertBanner reads uvProvider directly (rather than taking alerts as
// a constructor param) so it can never disagree with AlertListScreen, which
// it pushes on "See more" and which also reads uvProvider directly -- see
// alert_list_screen.dart.
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
  child: const MaterialApp(home: Scaffold(body: WeatherAlertBanner())),
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

  testWidgets('a three-alert set is fully cleared by a single dismiss tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(<WeatherAlert>[_heatAdvisory, _floodWarning, _redFlagWarning]),
    );
    expect(find.textContaining('3 Active Alerts'), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss all alerts'));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialBanner), findsNothing);
  });

  testWidgets(
    'dismissing one alert does not suppress a different still-active alert',
    (WidgetTester tester) async {
      final FakeDataUvNotifier notifier = FakeDataUvNotifier(
        makeUvData(alerts: <WeatherAlert>[_heatAdvisory]),
      );

      await tester.pumpWidget(
        _wrap(<WeatherAlert>[_heatAdvisory], notifier: notifier),
      );
      await tester.tap(find.byTooltip('Dismiss alert'));
      await tester.pumpAndSettle();
      expect(find.text(_heatAdvisory.event), findsNothing);

      notifier.updateData(makeUvData(alerts: <WeatherAlert>[_floodWarning]));
      await tester.pumpAndSettle();

      expect(find.text(_floodWarning.event), findsOneWidget);
    },
  );

  testWidgets(
    'a provider rebuild that reuses the identical alerts list instance '
    'still keeps a prior dismissal (the identical() fast path in '
    '_pruneDismissedIds does not skip pruning incorrectly, only '
    'redundantly)',
    (WidgetTester tester) async {
      final List<WeatherAlert> alerts = <WeatherAlert>[_heatAdvisory];
      final FakeDataUvNotifier notifier = FakeDataUvNotifier(
        makeUvData(alerts: alerts),
      );

      await tester.pumpWidget(_wrap(alerts, notifier: notifier));
      await tester.tap(find.byTooltip('Dismiss alert'));
      await tester.pumpAndSettle();
      expect(find.text(_heatAdvisory.event), findsNothing);

      // Same List instance as above (not a new literal), the case
      // _pruneDismissedIds's identical() check exists to short-circuit --
      // simulates a provider rebuild that leaves alerts unchanged (e.g. a
      // different UvData field updating).
      notifier.updateData(makeUvData(alerts: alerts));
      await tester.pumpAndSettle();

      expect(find.text(_heatAdvisory.event), findsNothing);
    },
  );

  testWidgets(
    'dismissing then refreshing to the same unchanged alert stays hidden',
    (WidgetTester tester) async {
      final FakeDataUvNotifier notifier = FakeDataUvNotifier(
        makeUvData(alerts: <WeatherAlert>[_heatAdvisory]),
      );

      await tester.pumpWidget(
        _wrap(<WeatherAlert>[_heatAdvisory], notifier: notifier),
      );
      await tester.tap(find.byTooltip('Dismiss alert'));
      await tester.pumpAndSettle();

      // Simulates a data refresh that returns the same still-active alert.
      // Built via fromJson (not a const literal) so it's a genuinely distinct
      // object at runtime -- a const WeatherAlert with the same field values
      // would canonicalize to the exact same instance as _heatAdvisory,
      // masking a regression that swapped value-equality for identical().
      notifier.updateData(
        makeUvData(
          alerts: <WeatherAlert>[
            // A const map here would let the compiler canonicalize the
            // resulting WeatherAlert back to the same instance as
            // _heatAdvisory, defeating the point of this test.
            // ignore: prefer_const_literals_to_create_immutables
            WeatherAlert.fromJson(<String, Object?>{
              'sender_name': 'NWS',
              'event': 'Heat Advisory',
              'description':
                  'Dangerously high UV and heat index expected today.',
              'start': 1717200000,
              'end': 1717286400,
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_heatAdvisory.event), findsNothing);
    },
  );

  testWidgets(
    'clearing all alerts hides the banner even without a dismiss tap',
    (WidgetTester tester) async {
      final FakeDataUvNotifier notifier = FakeDataUvNotifier(
        makeUvData(alerts: <WeatherAlert>[_heatAdvisory]),
      );

      await tester.pumpWidget(
        _wrap(<WeatherAlert>[_heatAdvisory], notifier: notifier),
      );
      expect(find.text(_heatAdvisory.event), findsOneWidget);

      notifier.updateData(makeUvData());
      await tester.pump();

      expect(find.text(_heatAdvisory.event), findsNothing);
    },
  );

  testWidgets('dismissing, then a transient empty list, then the same alert '
      'returning stays hidden', (WidgetTester tester) async {
    // Regression test: a refresh that briefly reports "no active alerts"
    // before the same alert reappears must not incorrectly resurface a
    // banner the user already dismissed.
    final FakeDataUvNotifier notifier = FakeDataUvNotifier(
      makeUvData(alerts: <WeatherAlert>[_heatAdvisory]),
    );

    await tester.pumpWidget(
      _wrap(<WeatherAlert>[_heatAdvisory], notifier: notifier),
    );
    await tester.tap(find.byTooltip('Dismiss alert'));
    await tester.pumpAndSettle();
    expect(find.text(_heatAdvisory.event), findsNothing);

    notifier.updateData(makeUvData());
    await tester.pumpAndSettle();

    notifier.updateData(makeUvData(alerts: <WeatherAlert>[_heatAdvisory]));
    await tester.pumpAndSettle();

    expect(find.text(_heatAdvisory.event), findsNothing);
  });

  testWidgets(
    'an alert removed from the active list (not dismissed) does not block '
    'a later different alert reusing no state',
    (WidgetTester tester) async {
      final FakeDataUvNotifier notifier = FakeDataUvNotifier(
        makeUvData(alerts: <WeatherAlert>[_heatAdvisory]),
      );

      await tester.pumpWidget(
        _wrap(<WeatherAlert>[_heatAdvisory], notifier: notifier),
      );
      notifier.updateData(makeUvData());
      await tester.pump();
      notifier.updateData(makeUvData(alerts: <WeatherAlert>[_floodWarning]));
      await tester.pumpAndSettle();

      expect(find.text(_floodWarning.event), findsOneWidget);
    },
  );
}
