import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/constants.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
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
class NotificationOnboardingScreen extends ConsumerStatefulWidget {
  /// Creates a [NotificationOnboardingScreen].
  const NotificationOnboardingScreen({super.key});

  @override
  ConsumerState<NotificationOnboardingScreen> createState() =>
      _NotificationOnboardingScreenState();
}

class _NotificationOnboardingScreenState
    extends ConsumerState<NotificationOnboardingScreen> {
  bool _continuing = false;

  void _onPressed(bool notificationsEnabled) {
    if (_continuing) return;
    unawaited(_advance(notificationsEnabled: notificationsEnabled));
  }

  Future<void> _advance({required bool notificationsEnabled}) async {
    setState(() => _continuing = true);

    try {
      await ref
          .read(settingsProvider.notifier)
          .setNotificationsEnabled(value: notificationsEnabled);

      final Preferences prefs = await ref.read(preferencesProvider.future);

      await prefs.setFirstLaunchDone();

      if (!mounted) return;

      unawaited(
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const DashboardScreen()),
        ),
      );
    } on Object {
      if (!mounted) return;

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
                onPressed: () => _onPressed(true),
              ),

              _OptionButton(
                icon: Icons.notifications_off,
                label: 'No Notifications',
                description: 'Skip notifications for now.',
                onPressed: () => _onPressed(false),
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
      'More notification options can be found in Settings on the Dashboard.',
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
