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
    // Expected colors are hard-coded from WHO's own RGB values (see
    // docs/adr/who-uv-index-colour-standards.pdf), computed independently
    // via Color.fromARGB rather than imported from the widget's color
    // constants, so a regression inside whoRiskColor/_whoRiskBand itself
    // (e.g. a swapped or mistyped color) is actually caught.
    final Map<double, (String label, Color color)> bands =
        <double, (String, Color)>{
          0: ('Low', const Color.fromARGB(255, 40, 149, 0)),
          2: ('Low', const Color.fromARGB(255, 40, 149, 0)),
          3: ('Moderate', const Color.fromARGB(255, 247, 228, 0)),
          5: ('Moderate', const Color.fromARGB(255, 247, 228, 0)),
          6: ('High', const Color.fromARGB(255, 248, 89, 0)),
          7: ('High', const Color.fromARGB(255, 248, 89, 0)),
          8: ('Very High', const Color.fromARGB(255, 216, 0, 29)),
          10: ('Very High', const Color.fromARGB(255, 216, 0, 29)),
          11: ('Extreme', const Color.fromARGB(255, 107, 73, 200)),
          15: ('Extreme', const Color.fromARGB(255, 107, 73, 200)),
        };

    for (final MapEntry<double, (String, Color)> entry in bands.entries) {
      final double uvIndex = entry.key;
      final (String label, Color color) = entry.value;

      testWidgets('UV $uvIndex shows "$label" label and ring colored to '
          'the WHO reference color', (WidgetTester tester) async {
        await tester.pumpWidget(_wrap(uvIndex));

        expect(find.text(label), findsOneWidget);

        final Text riskText = tester.widget<Text>(find.text(label));
        expect(riskText.style?.color, color);

        final Container ring = tester.widget<Container>(find.byType(Container));
        final BoxDecoration decoration = ring.decoration! as BoxDecoration;
        expect(decoration.border!.top.color, color);
      });
    }

    testWidgets('band colors are all distinct', (WidgetTester tester) async {
      final Set<Color> colors = bands.values
          .map(((String, Color) v) => v.$2)
          .toSet();
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
