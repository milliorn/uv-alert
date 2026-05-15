import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/app.dart';

void main() {
  testWidgets('UvAlertApp renders without error', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: UvAlertApp()));
    expect(find.byType(UvAlertApp), findsOneWidget);
  });
}
