import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/storage/preferences.dart';

/// Screen 1 of onboarding: lets the user pick a theme.
// ConsumerStatefulWidget is the Riverpod version of StatefulWidget.
// It gives the State class a `ref` to read and write providers.
class OnboardingScreen extends ConsumerStatefulWidget {
  /// Creates an [OnboardingScreen].
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  // Tracks which theme card is currently selected.
  String _selectedTheme = 'system';

  Future<void> _onContinue() async {
    // Persist the chosen theme via the settings provider.
    await ref.read(settingsProvider.notifier).setTheme(_selectedTheme);

    // Mark first launch done so this screen never shows again.
    final Preferences prefs = await ref.read(preferencesProvider.future);
    await prefs.setFirstLaunchDone();
    ref.invalidate(preferencesProvider);

    if (!mounted) return;

    // TODO(onboarding): replace with location screen when it exists.
    unawaited(
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const DashboardScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: <Widget>[
              const Spacer(),

              Text(
                'Choose your theme',
                style: Theme.of(context).textTheme.headlineMedium,
              ),

              const SizedBox(height: 32),

              _ThemeCard(
                label: 'Light',
                icon: Icons.light_mode,
                value: 'light',
                selected: _selectedTheme == 'light',
                onTap: () => setState(() => _selectedTheme = 'light'),
              ),

              const SizedBox(height: 16),

              _ThemeCard(
                label: 'Dark',
                icon: Icons.dark_mode,
                value: 'dark',
                selected: _selectedTheme == 'dark',
                onTap: () => setState(() => _selectedTheme = 'dark'),
              ),

              const SizedBox(height: 16),

              _ThemeCard(
                label: 'System Default',
                icon: Icons.brightness_auto,
                value: 'system',
                selected: _selectedTheme == 'system',
                onTap: () => setState(() => _selectedTheme = 'system'),
              ),

              const Spacer(),
              const _ProgressDots(current: 0, total: 3),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _onContinue,
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single selectable theme card.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),

          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),

          color: selected
              ? colors.primary.withValues(alpha: 0.08)
              : colors.surface,
        ),

        child: Row(
          children: <Widget>[
            Icon(icon, color: selected ? colors.primary : colors.onSurface),

            const SizedBox(width: 16),

            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: selected ? colors.primary : colors.onSurface,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Spacer(),

            if (selected) Icon(Icons.check_circle, color: colors.primary),
          ],
        ),
      ),
    );
  }
}

/// Three dots indicating progress through onboarding screens.
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.current, required this.total});

  // Zero-based index of the current screen.
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final Color active = Theme.of(context).colorScheme.primary;
    final Color inactive = Theme.of(context).colorScheme.outlineVariant;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,

      children: List<Widget>.generate(total, (int i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i == current ? active : inactive,
          ),
        );
      }),
    );
  }
}
