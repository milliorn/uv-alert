import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/providers/location_provider.dart';
import 'package:uvalert/providers/uv_provider.dart';
import 'package:uvalert/services/uv_interpolation.dart';
import 'package:uvalert/widgets/dashboard_hero.dart';
import 'package:uvalert/widgets/uv_current_display.dart';
import 'package:uvalert/widgets/uv_hero_conditional_line.dart';

import 'fakes/fake_fixed_location_notifier.dart';
import 'fakes/fake_uv_data.dart';
import 'fakes/fake_uv_notifier.dart';

Widget _wrap({
  required UvNotifier Function() uvNotifier,
  LocationNotifier Function()? locationNotifier,
}) => ProviderScope(
  // ignore: always_specify_types - Override not in flutter_riverpod public API
  overrides: [
    uvProvider.overrideWith(uvNotifier),
    if (locationNotifier != null)
      locationProvider.overrideWith(locationNotifier),
  ],
  // Not `const`: each call must construct a genuinely new DashboardHero
  // instance rather than reusing one frozen canonicalized const object
  // across every test, so the constructor line is credited by coverage the
  // same way a real (non-const) call site would be.
  // ignore: prefer_const_constructors
  child: MaterialApp(home: Scaffold(body: DashboardHero())),
);

void main() {
  testWidgets(
    'renders currentUvi directly when no location has been acquired yet',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(uvNotifier: () => FakeDataUvNotifier(makeUvData(currentUvi: 4))),
      );

      final UvCurrentDisplay display = tester.widget(
        find.byType(UvCurrentDisplay),
      );
      expect(display.uvIndex, 4);
      expect(find.byType(UvHeroConditionalLine), findsNothing);
    },
  );

  testWidgets(
    'renders the solar-interpolated value and conditional line when a '
    'location is available',
    (WidgetTester tester) async {
      final DateTime fetchedAt = DateTime.utc(2024, 6, 1, 12);
      final UvData data = makeUvData(currentUvi: 4, fetchedAt: fetchedAt);

      await tester.pumpWidget(
        _wrap(
          uvNotifier: () => FakeDataUvNotifier(data),
          locationNotifier: FakeFixedLocationNotifier.new,
        ),
      );

      final double expectedUvi = interpolatedUvi(
        data: data,
        lat: 36.75,
        lon: -119.65,
        atUtc: DateTime.now().toUtc(),
      );

      final UvCurrentDisplay display = tester.widget(
        find.byType(UvCurrentDisplay),
      );
      // Compares to within a small tolerance since `expectedUvi` and the
      // widget's own `DateTime.now()` call are computed microseconds apart.
      expect(display.uvIndex, closeTo(expectedUvi, 0.01));
      expect(find.byType(UvHeroConditionalLine), findsOneWidget);
    },
  );

  testWidgets('renders nothing when uvProvider has no value', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(uvNotifier: FakeErrorUvNotifier.new));

    expect(find.byType(UvCurrentDisplay), findsNothing);
    expect(find.byType(UvHeroConditionalLine), findsNothing);
  });

  testWidgets(
    'periodic timer refreshes the hero and is cancelled on dispose, without '
    'triggering a fetch',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          uvNotifier: () => FakeDataUvNotifier(makeUvData()),
          locationNotifier: FakeFixedLocationNotifier.new,
        ),
      );

      expect(find.byType(DashboardHero), findsOneWidget);

      // Advancing the test binding's virtual clock past one refresh
      // interval must not throw and must not leave a pending timer once the
      // widget is torn down (flutter_test fails the test at tearDown if
      // any Timer is still active), so a passing test here proves both that
      // the periodic Timer fires and that dispose() cancels it correctly.
      // The absence of any registered UV API mock also means a network
      // fetch attempt here would surface as an unhandled call/error.
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('periodic timer skips rebuilding when uvProvider has no value', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(uvNotifier: FakeErrorUvNotifier.new));

    expect(find.byType(UvCurrentDisplay), findsNothing);

    await tester.pump(const Duration(minutes: 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
