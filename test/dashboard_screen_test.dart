import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/screens/settings_screen.dart';

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
}
