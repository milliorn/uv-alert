import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uvalert/constants.dart';
import 'package:uvalert/providers/location_provider.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/screens/location_onboarding_screen.dart';
import 'package:uvalert/screens/notification_onboarding_screen.dart';
import 'package:uvalert/screens/onboarding_progress_dots.dart';
import 'package:uvalert/storage/preferences.dart';

import 'fakes/fake_fixed_location_notifier.dart';

// ---------------------------------------------------------------------------
// Widget helper
// ---------------------------------------------------------------------------

Widget _wrap() => const ProviderScope(
  child: MaterialApp(home: NotificationOnboardingScreen()),
);

Widget _wrapWithPermission({
  Future<PermissionStatus> Function()? requestNotificationPermission,
  Future<bool> Function()? openAppSettingsOverride,
}) => ProviderScope(
  child: MaterialApp(
    home: NotificationOnboardingScreen(
      requestNotificationPermission: requestNotificationPermission,
      openAppSettingsOverride: openAppSettingsOverride,
    ),
  ),
);

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
      find.textContaining(
        'Notifications can be enabled, disabled, and customized',
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
    await tester.pumpWidget(
      _wrapWithPermission(
        requestNotificationPermission: () async => PermissionStatus.granted,
      ),
    );
    await tester.tap(find.text('Default Notifications'));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets(
    'tapping Default Notifications sets notificationsEnabled to true',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithPermission(
          requestNotificationPermission: () async => PermissionStatus.granted,
        ),
      );
      await tester.tap(find.text('Default Notifications'));
      await tester.pumpAndSettle();
      final Preferences prefs = await Preferences.load();
      expect(prefs.notificationsEnabled, isTrue);
    },
  );

  testWidgets('tapping Default Notifications sets isFirstLaunch to false', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrapWithPermission(
        requestNotificationPermission: () async => PermissionStatus.granted,
      ),
    );
    await tester.tap(find.text('Default Notifications'));
    await tester.pumpAndSettle();
    final Preferences prefs = await Preferences.load();
    expect(prefs.isFirstLaunch, isFalse);
  });

  // -------------------------------------------------------------------------
  // OS notification permission prompt
  // -------------------------------------------------------------------------

  testWidgets('tapping Default Notifications with denied permission navigates '
      'without showing a dialog and leaves notifications disabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrapWithPermission(
        requestNotificationPermission: () async => PermissionStatus.denied,
      ),
    );
    await tester.tap(find.text('Default Notifications'));
    await tester.pump();

    expect(find.byType(AlertDialog), findsNothing);

    await tester.pumpAndSettle();

    expect(find.byType(DashboardScreen), findsOneWidget);
    final Preferences prefs = await Preferences.load();
    expect(prefs.notificationsEnabled, isFalse);
  });

  testWidgets(
    'tapping Default Notifications with permanently denied permission '
    'shows an in-app dialog',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithPermission(
          requestNotificationPermission: () async =>
              PermissionStatus.permanentlyDenied,
        ),
      );
      await tester.tap(find.text('Default Notifications'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Notifications are blocked'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Open Settings on the permanently-denied dialog calls the '
    'override, closes the dialog, and navigates with notifications '
    'disabled',
    (WidgetTester tester) async {
      int openSettingsCalls = 0;

      await tester.pumpWidget(
        _wrapWithPermission(
          requestNotificationPermission: () async =>
              PermissionStatus.permanentlyDenied,
          openAppSettingsOverride: () async {
            openSettingsCalls++;
            return true;
          },
        ),
      );
      await tester.tap(find.text('Default Notifications'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Open Settings'));
      await tester.pumpAndSettle();

      expect(openSettingsCalls, equals(1));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(DashboardScreen), findsOneWidget);

      final Preferences prefs = await Preferences.load();
      expect(prefs.notificationsEnabled, isFalse);
    },
  );

  testWidgets(
    'tapping Not now on the permanently-denied dialog dismisses it without '
    'opening settings, and still navigates with notifications disabled',
    (WidgetTester tester) async {
      int openSettingsCalls = 0;

      await tester.pumpWidget(
        _wrapWithPermission(
          requestNotificationPermission: () async =>
              PermissionStatus.permanentlyDenied,
          openAppSettingsOverride: () async {
            openSettingsCalls++;
            return true;
          },
        ),
      );
      await tester.tap(find.text('Default Notifications'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Not now'));
      await tester.pumpAndSettle();

      expect(openSettingsCalls, equals(0));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(DashboardScreen), findsOneWidget);

      final Preferences prefs = await Preferences.load();
      expect(prefs.notificationsEnabled, isFalse);
    },
  );

  testWidgets(
    'shows snackbar and re-enables buttons when the permission request '
    'throws',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithPermission(
          requestNotificationPermission: () async =>
              throw Exception('permission request failed'),
        ),
      );
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

  testWidgets(
    'tapping No Notifications never invokes the OS permission request',
    (WidgetTester tester) async {
      int requestCalls = 0;

      await tester.pumpWidget(
        _wrapWithPermission(
          requestNotificationPermission: () async {
            requestCalls++;
            return PermissionStatus.granted;
          },
        ),
      );
      await tester.tap(find.text('No Notifications'));
      await tester.pumpAndSettle();

      expect(requestCalls, equals(0));
      expect(find.byType(DashboardScreen), findsOneWidget);

      final Preferences prefs = await Preferences.load();
      expect(prefs.notificationsEnabled, isFalse);
    },
  );

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
  // Error path
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
}
