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

// (label, icon, key) for each selectable theme option.
const List<(String, IconData, String)> _themeOptions =
    <(String, IconData, String)>[
      ('Light', Icons.light_mode, 'light'),
      ('Dark', Icons.dark_mode, 'dark'),
      ('System Default', Icons.brightness_auto, 'system'),
    ];

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

  void _onSelectTheme(String key) {
    setState(() => _selectedTheme = key);
    unawaited(ref.read(settingsProvider.notifier).setTheme(key));
  }

  Future<void> _onContinue() async {
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

              for (final (String label, IconData icon, String key)
                  in _themeOptions) ...<Widget>[
                _ThemeCard(
                  label: label,
                  icon: icon,
                  selected: _selectedTheme == key,
                  onTap: () => _onSelectTheme(key),
                ),
                if (key != 'system') const SizedBox(height: _cardGap),
              ],

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
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,

      children: List<Widget>.generate(total, (int i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: _dotMargin),
          width: _dotSize,
          height: _dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i == current ? colors.primary : colors.outlineVariant,
          ),
        );
      }),
    );
  }
}
