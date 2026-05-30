import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/storage/preferences.dart';

const int _totalOnboardingSteps = 3;

const double _screenPaddingHorizontal = 24;
const double _screenPaddingVertical = 32;

const double _headingGap = 32;
const double _cardGap = 16;
const double _buttonGap = 24;

const Duration _cardAnimationDuration = Duration(milliseconds: 200);

const double _cardPaddingHorizontal = 20;
const double _cardPaddingVertical = 16;

const double _cardBorderRadius = 12;

const double _selectedBorderWidth = 2;
const double _unselectedBorderWidth = 1;

const double _selectedCardOpacity = 0.08;

const double _cardIconGap = 16;

const double _dotMargin = 4;
const double _dotSize = 8;

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
          padding: const EdgeInsets.symmetric(
            horizontal: _screenPaddingHorizontal,
            vertical: _screenPaddingVertical,
          ),
          child: Column(
            children: <Widget>[
              const Spacer(),

              Text(
                'Choose your theme',
                style: Theme.of(context).textTheme.headlineMedium,
              ),

              const SizedBox(height: _headingGap),

              _ThemeCard(
                label: 'Light',
                icon: Icons.light_mode,
                selected: _selectedTheme == 'light',
                onTap: () => setState(() => _selectedTheme = 'light'),
              ),

              const SizedBox(height: _cardGap),

              _ThemeCard(
                label: 'Dark',
                icon: Icons.dark_mode,
                selected: _selectedTheme == 'dark',
                onTap: () => setState(() => _selectedTheme = 'dark'),
              ),

              const SizedBox(height: _cardGap),

              _ThemeCard(
                label: 'System Default',
                icon: Icons.brightness_auto,
                selected: _selectedTheme == 'system',
                onTap: () => setState(() => _selectedTheme = 'system'),
              ),

              const Spacer(),
              const _ProgressDots(current: 0, total: _totalOnboardingSteps),
              const SizedBox(height: _buttonGap),

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
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,

      child: AnimatedContainer(
        duration: _cardAnimationDuration,
        padding: const EdgeInsets.symmetric(
          horizontal: _cardPaddingHorizontal,
          vertical: _cardPaddingVertical,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_cardBorderRadius),

          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? _selectedBorderWidth : _unselectedBorderWidth,
          ),

          color: selected
              ? colors.primary.withValues(alpha: _selectedCardOpacity)
              : colors.surface,
        ),

        child: Row(
          children: <Widget>[
            Icon(icon, color: selected ? colors.primary : colors.onSurface),

            const SizedBox(width: _cardIconGap),

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
          margin: const EdgeInsets.symmetric(horizontal: _dotMargin),
          width: _dotSize,
          height: _dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i == current ? active : inactive,
          ),
        );
      }),
    );
  }
}
