import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/services/solar_position.dart';
import 'package:uvalert/widgets/uv_hero_conditional_line.dart';

import 'fakes/fake_uv_data.dart';

final DateTime _now = DateTime.utc(2024, 6, 1, 12);

Map<SolarEvent, DateTime?> _noEvents() => <SolarEvent, DateTime?>{
  for (final SolarEvent e in SolarEvent.values) e: null,
};

void main() {
  testWidgets('renders the conditional line text when one applies', (
    WidgetTester tester,
  ) async {
    final Map<SolarEvent, DateTime?> events = _noEvents();
    events[SolarEvent.sunset] = _now.add(const Duration(hours: 1));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UvHeroConditionalLine(
            now: _now,
            solarEvents: events,
            uvData: makeUvData(),
          ),
        ),
      ),
    );

    expect(find.text('Sunset at 1:00 PM'), findsOneWidget);
  });

  testWidgets('renders nothing when no branch applies', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UvHeroConditionalLine(
            now: _now,
            solarEvents: _noEvents(),
            uvData: makeUvData(),
          ),
        ),
      ),
    );

    expect(find.byType(Text), findsNothing);
    expect(find.byType(SizedBox), findsOneWidget);
  });

  testWidgets('constructs with an explicit key', (WidgetTester tester) async {
    final Key key = UniqueKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UvHeroConditionalLine(
            now: _now,
            solarEvents: _noEvents(),
            uvData: makeUvData(),
            key: key,
          ),
        ),
      ),
    );

    expect(find.byKey(key), findsOneWidget);
  });
}
