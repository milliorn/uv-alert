import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uvalert/constants.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/screens/location_onboarding_screen.dart';
import 'package:uvalert/screens/onboarding_back_app_bar.dart';
import 'package:uvalert/screens/onboarding_progress_dots.dart';
import 'package:uvalert/storage/preferences.dart';

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------
const int _notificationScreenIndex = totalOnboardingSteps - 1;

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Screen 3 of onboarding: lets the user choose notification preferences.
///
/// Presents two options ("Default Notifications" and "No Notifications");
/// the chosen value is persisted via `setNotificationsEnabled()` before
/// advancing to [DashboardScreen]. This screen also owns the
/// `setFirstLaunchDone()` call, which was moved here from
/// `LocationOnboardingScreen` when this screen was inserted as the last
/// onboarding step.
///
/// Choosing "Default Notifications" triggers the OS notification permission
/// prompt (via [requestNotificationPermission]) before advancing. If the
/// permission is permanently denied, an in-app dialog points the user to
/// device Settings (via [openAppSettingsOverride]) before advancing with
/// notifications left disabled.
class NotificationOnboardingScreen extends ConsumerStatefulWidget {
  /// Creates a [NotificationOnboardingScreen].
  const NotificationOnboardingScreen({
    this.requestNotificationPermission,
    this.openAppSettingsOverride,
    super.key,
  });

  /// Requests the OS notification permission. Defaults to
  /// `Permission.notification.request()` in production; overridable in
  /// tests to avoid touching the real platform channel.
  final Future<PermissionStatus> Function()? requestNotificationPermission;

  /// Opens the device's app settings page. Defaults to `openAppSettings()`
  /// in production; overridable in tests.
  final Future<bool> Function()? openAppSettingsOverride;

  @override
  ConsumerState<NotificationOnboardingScreen> createState() =>
      _NotificationOnboardingScreenState();
}

class _NotificationOnboardingScreenState
    extends ConsumerState<NotificationOnboardingScreen> {
  bool _continuing = false;

  int _operationId = 0;

  void _onDefaultPressed() {
    if (_continuing) return;
    unawaited(_advanceWithPermissionCheck());
  }

  void _onNonePressed() {
    if (_continuing) return;
    unawaited(_advance(notificationsEnabled: false));
  }

  void _onBack() {
    unawaited(
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              const LocationOnboardingScreen(restoreConfirmedLocation: true),
        ),
      ),
    );
  }

  /// The function used to request the OS notification permission: the
  /// injected override in tests, or the real permission_handler request.
  Future<PermissionStatus> Function() get _requestPermission =>
      widget.requestNotificationPermission ?? Permission.notification.request;

  /// The function used to open the device's app settings page: the
  /// injected override in tests, or the real permission_handler call.
  Future<bool> Function() get _openSettings =>
      widget.openAppSettingsOverride ?? openAppSettings;

  /// Requests the OS notification permission, shows the permanently-denied
  /// dialog if applicable, then advances with the resulting enabled state.
  Future<void> _advanceWithPermissionCheck() async {
    final int opId = ++_operationId;
    setState(() => _continuing = true);

    final bool notificationsEnabled;
    try {
      final PermissionStatus status = await _requestPermission();

      if (!mounted || _operationId != opId) return;

      if (status.isPermanentlyDenied) {
        await _showPermanentlyDeniedDialog();
        if (!mounted || _operationId != opId) return;
      }

      notificationsEnabled = status.isGranted;
    } on Object {
      if (!mounted || _operationId != opId) return;

      setState(() => _continuing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
      return;
    }

    await _advance(notificationsEnabled: notificationsEnabled, opId: opId);
  }

  /// Shows an in-app dialog pointing the user to device Settings after an
  /// "Don't ask again" permission denial.
  Future<void> _showPermanentlyDeniedDialog() {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Notifications blocked'),
          content: const Text(
            'Notifications are blocked. To enable them, go to your device '
            'Settings.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () async {
                await _openSettings();
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _advance({required bool notificationsEnabled, int? opId}) async {
    final int id = opId ?? ++_operationId;
    if (opId == null) setState(() => _continuing = true);

    try {
      await ref
          .read(settingsProvider.notifier)
          .setNotificationsEnabled(value: notificationsEnabled);

      if (!mounted || _operationId != id) return;

      final Preferences prefs = await ref.read(preferencesProvider.future);

      await prefs.setFirstLaunchDone();

      if (!mounted || _operationId != id) return;

      unawaited(
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const DashboardScreen()),
        ),
      );
    } on Object {
      if (!mounted || _operationId != id) return;

      setState(() => _continuing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: OnboardingBackAppBar(onBack: _continuing ? null : _onBack),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: onboardingPaddingHorizontal,
            vertical: onboardingPaddingVertical,
          ),
          child: Column(
            spacing: onboardingSectionGap,
            children: <Widget>[
              const Spacer(),

              const _Header(),

              _OptionButton(
                icon: Icons.notifications_active,
                label: 'Default Notifications',
                description:
                    'Enable 4 threshold alert notifications for UV changes.',
                onPressed: _continuing ? null : _onDefaultPressed,
              ),

              _OptionButton(
                icon: Icons.notifications_off,
                label: 'No Notifications',
                description: 'Skip notifications for now.',
                onPressed: _continuing ? null : _onNonePressed,
              ),

              const _Note(),

              const Spacer(),

              const OnboardingProgressDots(
                current: _notificationScreenIndex,
                total: totalOnboardingSteps,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets (private)
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      spacing: onboardingItemGap,
      children: <Widget>[
        Text('Notifications', style: theme.textTheme.headlineMedium),
        Text(
          'Would you like UV Alert to notify you when UV levels change?',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      hint: description,
      child: InkWell(
        onTap: onPressed,
        borderRadius: onboardingCardRadius,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: onboardingCardPaddingHorizontal,
            vertical: onboardingCardPaddingVertical,
          ),
          decoration: BoxDecoration(
            borderRadius: onboardingCardRadius,
            border: Border.all(
              color: colors.outlineVariant,
              width: onboardingSelectedBorderWidth,
            ),
            color: colors.surface,
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, color: colors.primary),
              const SizedBox(width: onboardingItemGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: onboardingLabelGap,
                  children: <Widget>[
                    Text(
                      label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Text(
      'Notifications can be enabled, disabled, and customized in Settings.',
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
