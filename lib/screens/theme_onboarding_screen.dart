import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/constants.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/screens/location_onboarding_screen.dart';
import 'package:uvalert/screens/onboarding_progress_dots.dart';
import 'package:uvalert/storage/preferences.dart';

const int _onboardingThemeScreenIndex = 0;

const double _cardGap = 16;

const Duration _cardAnimationDuration = Duration(milliseconds: 200);

const double _unselectedBorderWidth = 1;

const BorderRadius _cardRadius = BorderRadius.all(
  Radius.circular(onboardingCardBorderRadius),
);

const double _cardIconGap = 16;

// (label, icon, themeMode) for each selectable theme option.
const List<(String, IconData, ThemeMode)> _themeOptions =
    <(String, IconData, ThemeMode)>[
      ('Light', Icons.light_mode, ThemeMode.light),
      ('Dark', Icons.dark_mode, ThemeMode.dark),
      ('System Default', Icons.brightness_auto, ThemeMode.system),
    ];

/// Screen 1 of onboarding: lets the user pick a theme.
// ConsumerStatefulWidget is the Riverpod version of StatefulWidget.
// It gives the State class a `ref` to read and write providers.
class ThemeOnboardingScreen extends ConsumerStatefulWidget {
  /// Creates a [ThemeOnboardingScreen].
  const ThemeOnboardingScreen({super.key});

  @override
  ConsumerState<ThemeOnboardingScreen> createState() =>
      _ThemeOnboardingScreenState();
}

class _ThemeOnboardingScreenState extends ConsumerState<ThemeOnboardingScreen> {
  // Optimistic override: set on tap, cleared once the provider round-trips.
  ThemeMode? _pendingTheme;
  bool _continuing = false;

  Future<void> _onSelectTheme(ThemeMode mode) async {
    setState(() => _pendingTheme = mode);

    await ref.read(settingsProvider.notifier).setTheme(mode);
    // Only clear the optimistic override if no newer tap has superseded it.
    if (mounted && _pendingTheme == mode) setState(() => _pendingTheme = null);
  }

  Future<void> _onContinue() async {
    setState(() => _continuing = true);
    // Theme was already persisted by _onSelectTheme on tap.
    // setThemeStepDone() marks this step complete so the splash screen can
    // route directly to LocationOnboardingScreen on the next cold launch.

    try {
      final Preferences prefs = await ref.read(preferencesProvider.future);

      if (!mounted) return;

      await prefs.setThemeStepDone();

      if (!mounted) return;

      unawaited(
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const LocationOnboardingScreen(),
          ),
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
    final AsyncValue<SettingsState> settings = ref.watch(settingsProvider);
    final ThemeMode selectedTheme =
        _pendingTheme ?? settings.value?.themeMode ?? ThemeMode.system;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: onboardingPaddingHorizontal,
            vertical: onboardingPaddingVertical,
          ),
          child: Column(
            spacing: _cardGap,
            children: <Widget>[
              const Spacer(),

              Text(
                'Choose your theme',
                style: Theme.of(context).textTheme.headlineMedium,
              ),

              for (final (String label, IconData icon, ThemeMode mode)
                  in _themeOptions)
                _ThemeCard(
                  key: ValueKey<ThemeMode>(mode),
                  label: label,
                  icon: icon,
                  selected: selectedTheme == mode,
                  onTap: () => _onSelectTheme(mode),
                ),

              const Spacer(),

              const OnboardingProgressDots(
                current: _onboardingThemeScreenIndex,
                total: totalOnboardingSteps,
              ),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (settings.hasValue || settings.hasError) &&
                          !_continuing
                      ? _onContinue
                      : null,
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
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color contentColor = selected ? colors.primary : colors.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: _cardRadius,

        child: AnimatedContainer(
          duration: _cardAnimationDuration,
          padding: const EdgeInsets.symmetric(
            horizontal: onboardingCardPaddingHorizontal,
            vertical: onboardingCardPaddingVertical,
          ),

          decoration: BoxDecoration(
            borderRadius: _cardRadius,

            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected
                  ? onboardingSelectedBorderWidth
                  : _unselectedBorderWidth,
            ),

            color: selected
                ? colors.primary.withValues(
                    alpha: onboardingSelectedCardOpacity,
                  )
                : colors.surface,
          ),

          child: Row(
            children: <Widget>[
              Icon(icon, color: contentColor),

              const SizedBox(width: _cardIconGap),

              Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: contentColor,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const Spacer(),

              if (selected) Icon(Icons.check_circle, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
