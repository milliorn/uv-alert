import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/storage/preferences.dart';

const int _totalOnboardingSteps = 3;

const int _onboardingThemeScreenIndex = 0;

const double _screenPaddingHorizontal = 24;
const double _screenPaddingVertical = 32;

const double _cardGap = 16;

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
class OnboardingScreen extends ConsumerStatefulWidget {
  /// Creates an [OnboardingScreen].
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
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
    if (_continuing) return;
    
    setState(() => _continuing = true);
    // Theme was already persisted by _onSelectTheme on tap; only first-launch
    // flag needs writing here.
    final Preferences prefs = await ref.read(preferencesProvider.future);

    await prefs.setFirstLaunchDone();

    if (!mounted) return;

    ref.invalidate(preferencesProvider);

    // TODO(onboarding): replace with location screen (issue #14).
    // Full flow: Theme → Location → Notifications → Dashboard.
    unawaited(
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const DashboardScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SettingsState> settings = ref.watch(settingsProvider);
    final bool settingsReady = settings.hasValue || settings.hasError;
    final ThemeMode selectedTheme =
        _pendingTheme ?? settings.value?.themeMode ?? ThemeMode.system;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _screenPaddingHorizontal,
            vertical: _screenPaddingVertical,
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
              const _ProgressDots(
                current: _onboardingThemeScreenIndex,
                total: _totalOnboardingSteps,
              ),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: settingsReady ? _onContinue : null,
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
    final BorderRadius cardRadius = BorderRadius.circular(_cardBorderRadius);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: cardRadius,

        child: AnimatedContainer(
          duration: _cardAnimationDuration,
          padding: const EdgeInsets.symmetric(
            horizontal: _cardPaddingHorizontal,
            vertical: _cardPaddingVertical,
          ),

          decoration: BoxDecoration(
            borderRadius: cardRadius,

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

/// Three dots indicating progress through onboarding screens.
class _ProgressDots extends StatelessWidget {
  /// Creates a [_ProgressDots] widget.
  const _ProgressDots({required this.current, required this.total});

  /// Zero-based index of the current screen.
  final int current;

  /// Total number of onboarding screens.
  final int total;

  @override
  Widget build(BuildContext context) {
    assert(current >= 0 && current < total, 'current must be in [0, total)');
    final ColorScheme colors = Theme.of(context).colorScheme;

    // TODO(milliorn): animate the active dot transition (AnimatedContainer or
    // AnimatedSwitcher) once a second onboarding screen exists - issue #14.
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
