import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/screens/dashboard_screen.dart';

void main() {
  testWidgets('DashboardScreen renders Dashboard text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));

    expect(find.text('Dashboard'), findsOneWidget);
  });
}
