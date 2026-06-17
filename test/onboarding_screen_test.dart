import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/screens/location_onboarding_screen.dart';
import 'package:uvalert/screens/onboarding_screen.dart';
import 'package:uvalert/screens/theme_onboarding_screen.dart';
import 'package:uvalert/storage/preferences.dart';

import 'helpers.dart';

// SettingsNotifier that immediately emits an error state.
class _ErrorSettingsNotifier extends SettingsNotifier {
  @override
  AsyncValue<SettingsState> build() => AsyncValue<SettingsState>.error(
    Exception('settings failed'),
    StackTrace.empty,
  );
}

// SettingsNotifier that stays in loading state forever (triggers timeout).
class _LoadingForeverSettingsNotifier extends SettingsNotifier {
  @override
  AsyncValue<SettingsState> build() =>
      const AsyncValue<SettingsState>.loading();
}

Widget _wrap({Map<String, Object> prefs = const <String, Object>{}}) {
  SharedPreferences.setMockInitialValues(prefs);
  return const ProviderScope(child: MaterialApp(home: OnboardingScreen()));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('OnboardingScreen constructs with an explicit key', (
    WidgetTester tester,
  ) async {
    final Key key = UniqueKey();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: OnboardingScreen(key: key)),
      ),
    );
    expect(find.byKey(key), findsOneWidget);
    await pumpSplash(tester);
  });

  testWidgets('renders logo image', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap());
    expect(
      find.byWidgetPredicate(
        (Widget w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName ==
                'assets/images/high-resolution-color-logo.png',
      ),
      findsOneWidget,
    );
    await pumpSplash(tester);
  });

  testWidgets('shows initial status text', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.text('Loading preferences…'), findsOneWidget);
    await pumpSplash(tester);
  });

  testWidgets('LinearProgressIndicator is present', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap());
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await pumpSplash(tester);
  });

  testWidgets(
    'routes to ThemeOnboardingScreen when first launch, theme not done',
    (WidgetTester tester) async {
      // isFirstLaunch defaults to true, isThemeStepDone defaults to false.
      await tester.pumpWidget(_wrap());
      await pumpSplash(tester);
      expect(find.byType(ThemeOnboardingScreen), findsOneWidget);
    },
  );

  testWidgets(
    'routes to LocationOnboardingScreen when first launch, theme done',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          prefs: <String, Object>{Preferences.keyThemeStepDoneForTesting: true},
        ),
      );
      await pumpSplash(tester);
      expect(find.byType(LocationOnboardingScreen), findsOneWidget);
    },
  );

  testWidgets('routes to DashboardScreen when isFirstLaunch=false', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        prefs: <String, Object>{Preferences.keyFirstLaunchForTesting: false},
      ),
    );
    await pumpSplash(tester, hasSplashFloor: false);
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets(
    'shows error status and does not navigate when settingsProvider errors',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          // ignore: always_specify_types — Override not in flutter_riverpod public API
          overrides: [
            settingsProvider.overrideWith(_ErrorSettingsNotifier.new),
          ],
          child: const MaterialApp(home: OnboardingScreen()),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('Something went wrong'), findsOneWidget);
      expect(find.byType(ThemeOnboardingScreen), findsNothing);
      expect(find.byType(DashboardScreen), findsNothing);
    },
  );

  testWidgets(
    'shows error status and does not navigate when preferencesProvider throws',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          // ignore: always_specify_types — Override not in flutter_riverpod public API
          overrides: [
            preferencesProvider.overrideWithValue(
              AsyncValue<Preferences>.error(
                Exception('prefs failed'),
                StackTrace.empty,
              ),
            ),
          ],
          child: const MaterialApp(home: OnboardingScreen()),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('Something went wrong'), findsOneWidget);
      expect(find.byType(ThemeOnboardingScreen), findsNothing);
      expect(find.byType(LocationOnboardingScreen), findsNothing);
      expect(find.byType(DashboardScreen), findsNothing);
    },
  );

  testWidgets('Retry button is shown when an error occurs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types — Override not in flutter_riverpod public API
        overrides: [settingsProvider.overrideWith(_ErrorSettingsNotifier.new)],
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Retry button is tappable and does not throw', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types — Override not in flutter_riverpod public API
        overrides: [settingsProvider.overrideWith(_ErrorSettingsNotifier.new)],
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);

    // Tapping Retry should not throw and should keep the widget on screen.
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    // Widget is still alive (no navigation, no crash).
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('shows timeout error when settingsProvider never resolves', (
    WidgetTester tester,
  ) async {
    const Duration shortTimeout = Duration(milliseconds: 10);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          // ignore: always_specify_types — Override not in flutter_riverpod public API
          overrides: [
            settingsProvider.overrideWith(_LoadingForeverSettingsNotifier.new),
          ],
          child: const MaterialApp(
            home: OnboardingScreen(loadTimeout: shortTimeout),
          ),
        ),
      );

      // Advance past the injected timeout.
      await Future<void>.delayed(
        shortTimeout + const Duration(milliseconds: 50),
      );
      await tester.pump();
      await tester.pumpAndSettle();
    });

    expect(find.textContaining('Could not load app data'), findsOneWidget);
  });
}
