import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/models/weather_alert.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/screens/settings_screen.dart';

const WeatherAlert _heatAdvisory = WeatherAlert(
  event: 'Heat Advisory',
  description: 'Dangerously high UV and heat index expected today.',
);

void main() {
  testWidgets('DashboardScreen renders Dashboard text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));

    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('DashboardScreen app bar has title and both icons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));

    expect(find.text('UV Alert'), findsOneWidget);
    expect(find.byIcon(Icons.location_pin), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('DashboardScreen icons expose semantic labels', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));

    expect(find.byTooltip('Change location'), findsOneWidget);
    expect(find.byTooltip('Open settings'), findsOneWidget);
  });

  testWidgets('Tapping the gear icon opens SettingsScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));

    await tester.tap(find.byTooltip('Open settings'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('Tapping the location pin is a no-op', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));

    await tester.tap(find.byTooltip('Change location'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
  });

  testWidgets('does not render the alert banner when there is no active '
      'alert', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));

    expect(find.text(_heatAdvisory.event), findsNothing);
  });

  testWidgets('renders the alert banner below the app bar when an active '
      'alert is passed in', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: DashboardScreen(activeAlert: _heatAdvisory)),
    );

    expect(find.text(_heatAdvisory.event), findsOneWidget);
    expect(find.text(_heatAdvisory.description), findsOneWidget);

    final double appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    final double bannerTop = tester
        .getTopLeft(find.text(_heatAdvisory.event))
        .dy;
    expect(bannerTop, greaterThanOrEqualTo(appBarBottom));
  });
}
