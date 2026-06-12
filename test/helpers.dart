import 'package:flutter_test/flutter_test.dart';

/// Pumps the splash screen past the 2-second minimum splash floor and settles
/// all resulting navigation animations.
Future<void> pumpSplash(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 2100));
  await tester.pumpAndSettle();
}
