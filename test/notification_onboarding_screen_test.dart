import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uvalert/constants.dart';
import 'package:uvalert/providers/location_provider.dart';
import 'package:uvalert/providers/notification_permission_provider.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/screens/location_onboarding_screen.dart';
import 'package:uvalert/screens/notification_onboarding_screen.dart';
import 'package:uvalert/screens/onboarding_progress_dots.dart';
import 'package:uvalert/storage/preferences.dart';

import 'fakes/fake_fixed_location_notifier.dart';
import 'fakes/fake_permission_handler.dart';

// ---------------------------------------------------------------------------
// Widget helper
// ---------------------------------------------------------------------------

Widget _wrap({FakePermissionHandlerPlatform? permissionPlatform}) {
  final FakePermissionHandlerPlatform platform =
      permissionPlatform ??
      (FakePermissionHandlerPlatform()
        ..requestResult = PermissionStatus.granted);

  return ProviderScope(
    // ignore: always_specify_types (overrides list type not in flutter_riverpod public API)
    overrides: [
      notificationPermissionProvider.overrideWithValue(
        NotificationPermissionService(platform: platform),
      ),
    ],
    child: const MaterialApp(home: NotificationOnboardingScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // -------------------------------------------------------------------------
  // Initial state
  // -------------------------------------------------------------------------

  testWidgets('renders with an explicit key', (WidgetTester tester) async {
    final Key key = UniqueKey();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: NotificationOnboardingScreen(key: key)),
      ),
    );
    expect(find.byKey(key), findsOneWidget);
  });

  testWidgets('shows Default Notifications and No Notifications options', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap());
    expect(find.text('Default Notifications'), findsOneWidget);
    expect(find.text('No Notifications'), findsOneWidget);
  });

  testWidgets('shows notifications header text', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.text('Notifications'), findsOneWidget);
  });

  testWidgets('shows settings note text', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap());
    expect(
      find.text(
        'Notifications can be enabled, disabled, and customized in Settings.',
      ),
      findsOneWidget,
    );
  });

  // -------------------------------------------------------------------------
  // Progress dots
  // -------------------------------------------------------------------------

  testWidgets('renders progress dots at step 3 of 3', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap());
    final OnboardingProgressDots dots = tester.widget<OnboardingProgressDots>(
      find.byType(OnboardingProgressDots),
    );
    expect(dots.current, equals(totalOnboardingSteps - 1));
    expect(dots.total, equals(totalOnboardingSteps));
  });

  // -------------------------------------------------------------------------
  // Default Notifications path
  // -------------------------------------------------------------------------

  testWidgets('tapping Default Notifications navigates to DashboardScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('Default Notifications'));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets(
    'tapping Default Notifications sets notificationsEnabled to true',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap());
      await tester.tap(find.text('Default Notifications'));
      await tester.pumpAndSettle();
      final Preferences prefs = await Preferences.load();
      expect(prefs.notificationsEnabled, isTrue);
    },
  );

  testWidgets('tapping Default Notifications sets isFirstLaunch to false', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('Default Notifications'));
    await tester.pumpAndSettle();
    final Preferences prefs = await Preferences.load();
    expect(prefs.isFirstLaunch, isFalse);
  });

  testWidgets('tapping Default Notifications requests OS permission', (
    WidgetTester tester,
  ) async {
    final FakePermissionHandlerPlatform platform =
        FakePermissionHandlerPlatform()
          ..requestResult = PermissionStatus.granted;

    await tester.pumpWidget(_wrap(permissionPlatform: platform));
    await tester.tap(find.text('Default Notifications'));
    await tester.pumpAndSettle();

    expect(platform.requestCalled, isTrue);
  });

  // -------------------------------------------------------------------------
  // Permission denial path (not permanent)
  // -------------------------------------------------------------------------

  testWidgets(
    'first denial does not show a dialog and disables notifications',
    (WidgetTester tester) async {
      final FakePermissionHandlerPlatform platform =
          FakePermissionHandlerPlatform()
            ..requestResult = PermissionStatus.denied;

      await tester.pumpWidget(_wrap(permissionPlatform: platform));
      await tester.tap(find.text('Default Notifications'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(DashboardScreen), findsOneWidget);

      final Preferences prefs = await Preferences.load();
      expect(prefs.notificationsEnabled, isFalse);
    },
  );

  // -------------------------------------------------------------------------
  // Permanently denied path
  // -------------------------------------------------------------------------

  testWidgets(
    'permanently denied permission shows a dialog and blocks navigation '
    'until dismissed',
    (WidgetTester tester) async {
      final FakePermissionHandlerPlatform platform =
          FakePermissionHandlerPlatform()
            ..requestResult = PermissionStatus.permanentlyDenied;

      await tester.pumpWidget(_wrap(permissionPlatform: platform));
      await tester.tap(find.text('Default Notifications'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Notifications are blocked. To enable them, go to your device '
          'Settings.',
        ),
        findsOneWidget,
      );
      expect(find.byType(DashboardScreen), findsNothing);
    },
  );

  testWidgets('tapping Open Settings calls openAppSettings and advances', (
    WidgetTester tester,
  ) async {
    final FakePermissionHandlerPlatform platform =
        FakePermissionHandlerPlatform()
          ..requestResult = PermissionStatus.permanentlyDenied;

    await tester.pumpWidget(_wrap(permissionPlatform: platform));
    await tester.tap(find.text('Default Notifications'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    expect(platform.openAppSettingsCalled, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(DashboardScreen), findsOneWidget);

    final Preferences prefs = await Preferences.load();
    expect(prefs.notificationsEnabled, isFalse);
  });

  testWidgets('tapping Not Now dismisses the dialog and advances', (
    WidgetTester tester,
  ) async {
    final FakePermissionHandlerPlatform platform =
        FakePermissionHandlerPlatform()
          ..requestResult = PermissionStatus.permanentlyDenied;

    await tester.pumpWidget(_wrap(permissionPlatform: platform));
    await tester.tap(find.text('Default Notifications'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();

    expect(platform.openAppSettingsCalled, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(DashboardScreen), findsOneWidget);

    final Preferences prefs = await Preferences.load();
    expect(prefs.notificationsEnabled, isFalse);
  });

  // -------------------------------------------------------------------------
  // No Notifications path
  // -------------------------------------------------------------------------

  testWidgets('tapping No Notifications navigates to DashboardScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('No Notifications'));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('tapping No Notifications leaves notificationsEnabled false', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('No Notifications'));
    await tester.pumpAndSettle();
    final Preferences prefs = await Preferences.load();
    expect(prefs.notificationsEnabled, isFalse);
  });

  testWidgets('tapping No Notifications sets isFirstLaunch to false', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('No Notifications'));
    await tester.pumpAndSettle();
    final Preferences prefs = await Preferences.load();
    expect(prefs.isFirstLaunch, isFalse);
  });

  testWidgets('tapping No Notifications never requests OS permission', (
    WidgetTester tester,
  ) async {
    final FakePermissionHandlerPlatform platform =
        FakePermissionHandlerPlatform();

    await tester.pumpWidget(_wrap(permissionPlatform: platform));
    await tester.tap(find.text('No Notifications'));
    await tester.pumpAndSettle();

    expect(platform.requestCalled, isFalse);
  });

  // -------------------------------------------------------------------------
  // Back navigation
  // -------------------------------------------------------------------------

  testWidgets('shows a back button', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('tapping back navigates to LocationOnboardingScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(LocationOnboardingScreen), findsOneWidget);
  });

  testWidgets('tapping back restores the confirm phase when a location was '
      'already confirmed', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'uvalert_manual_location':
          '{"name": "Fresno, California, US", "lat": 36.75, "lon": -119.65}',
      'uvalert_use_gps': false,
    });

    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types (overrides list type not in flutter_riverpod public API)
        overrides: [
          locationProvider.overrideWith(FakeFixedLocationNotifier.new),
        ],
        child: const MaterialApp(home: NotificationOnboardingScreen()),
      ),
    );

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Fresno, California, US'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Change'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Error paths
  // -------------------------------------------------------------------------

  testWidgets(
    'shows snackbar and re-enables buttons when preferencesProvider throws',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          // ignore: always_specify_types (overrides list type not in flutter_riverpod public API)
          overrides: [
            preferencesProvider.overrideWithValue(
              AsyncValue<Preferences>.error(
                Exception('prefs failed'),
                StackTrace.empty,
              ),
            ),
          ],
          child: const MaterialApp(home: NotificationOnboardingScreen()),
        ),
      );

      await tester.tap(find.text('No Notifications'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );

      // Buttons must be re-enabled so the user can retry.
      // Check onTap is non-null, not just that label text is present.
      final List<InkWell> inkWells = tester
          .widgetList<InkWell>(find.byType(InkWell))
          .toList();
      expect(inkWells, isNotEmpty);
      expect(inkWells.every((InkWell w) => w.onTap != null), isTrue);
    },
  );

  testWidgets(
    'shows snackbar and re-enables buttons when requesting permission throws',
    (WidgetTester tester) async {
      final FakePermissionHandlerPlatform platform =
          FakePermissionHandlerPlatform()..throwOnRequest = Exception('boom');

      await tester.pumpWidget(_wrap(permissionPlatform: platform));

      await tester.tap(find.text('Default Notifications'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );

      final List<InkWell> inkWells = tester
          .widgetList<InkWell>(find.byType(InkWell))
          .toList();
      expect(inkWells, isNotEmpty);
      expect(inkWells.every((InkWell w) => w.onTap != null), isTrue);
    },
  );
}
