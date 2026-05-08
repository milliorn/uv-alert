import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/app.dart';

void main() {
  testWidgets('UvAlertApp renders without error', (tester) async {
    await tester.pumpWidget(const UvAlertApp());
    expect(find.byType(UvAlertApp), findsOneWidget);
  });
}
