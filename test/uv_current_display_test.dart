import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/widgets/uv_current_display.dart';

Widget _wrap(double uvIndex) => MaterialApp(
  home: Scaffold(body: UvCurrentDisplay(uvIndex: uvIndex)),
);

void main() {
  testWidgets('UvCurrentDisplay constructs with an explicit key', (
    WidgetTester tester,
  ) async {
    final Key key = UniqueKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: UvCurrentDisplay(uvIndex: 1, key: key)),
      ),
    );

    expect(find.byKey(key), findsOneWidget);
  });

  group('WHO risk bands', () {
    final Map<double, String> bandLabels = <double, String>{
      0: 'Low',
      2: 'Low',
      3: 'Moderate',
      5: 'Moderate',
      6: 'High',
      7: 'High',
      8: 'Very High',
      10: 'Very High',
      11: 'Extreme',
      15: 'Extreme',
    };

    for (final MapEntry<double, String> entry in bandLabels.entries) {
      testWidgets('UV ${entry.key} shows "${entry.value}" label colored to '
          'whoRiskColor', (WidgetTester tester) async {
        await tester.pumpWidget(_wrap(entry.key));

        expect(find.text(entry.value), findsOneWidget);

        final Text riskText = tester.widget<Text>(find.text(entry.value));
        expect(riskText.style?.color, whoRiskColor(entry.key));
        expect(whoRiskLabel(entry.key), entry.value);
      });
    }

    testWidgets('band colors are all distinct', (WidgetTester tester) async {
      final Set<Color> colors = <Color>{
        whoRiskColor(0),
        whoRiskColor(3),
        whoRiskColor(6),
        whoRiskColor(8),
        whoRiskColor(11),
      };
      expect(colors, hasLength(5));
    });
  });

  testWidgets('applies semantic label with UV value and risk', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(4.2));

    expect(
      tester.getSemantics(find.byType(UvCurrentDisplay)),
      matchesSemantics(label: 'UV index 4.2, Moderate risk'),
    );
  });

  testWidgets('formats the UV number to one decimal place', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(7));

    expect(find.text('7.0'), findsOneWidget);
  });

  group('displayed number always agrees with its band color/label', () {
    // Regression coverage for a boundary bug: a raw uvIndex just above an
    // integer threshold (e.g. 5.04) used to round up to the next band's
    // displayed number via toStringAsFixed while banding on the raw value,
    // so the shown number and its color/label could visibly disagree.
    final Map<double, String> truncatedDisplay = <double, String>{
      5.04: '5.0',
      2.04: '2.0',
      7.04: '7.0',
      2.99: '2.9',
      3.01: '3.0',
    };

    for (final MapEntry<double, String> entry in truncatedDisplay.entries) {
      testWidgets(
        'UV ${entry.key} displays "${entry.value}" and bands to match',
        (WidgetTester tester) async {
          await tester.pumpWidget(_wrap(entry.key));

          expect(find.text(entry.value), findsOneWidget);

          final String expectedRisk = whoRiskLabel(entry.key);
          final Text riskText = tester.widget<Text>(find.text(expectedRisk));
          expect(riskText.style?.color, whoRiskColor(entry.key));
        },
      );
    }
  });

  testWidgets('ring diameter scales with textScaler', (
    WidgetTester tester,
  ) async {
    Future<double> ringWidthAt(TextScaler scaler) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: scaler),
          child: _wrap(4),
        ),
      );
      return tester
          .widget<Container>(find.byType(Container))
          .constraints!
          .maxWidth;
    }

    final double baseWidth = await ringWidthAt(TextScaler.noScaling);
    final double scaledWidth = await ringWidthAt(const TextScaler.linear(2));

    expect(scaledWidth, greaterThan(baseWidth));
  });
}
