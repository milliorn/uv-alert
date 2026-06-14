import 'package:flutter/material.dart';

const double _dotMargin = 4;
const double _dotSize = 8;

/// Progress dots indicating position within the onboarding flow.
// Shared between ThemeOnboardingScreen and LocationOnboardingScreen so that
// a single edit keeps both screens visually consistent.
class OnboardingProgressDots extends StatelessWidget {
  /// Creates an [OnboardingProgressDots] widget.
  const OnboardingProgressDots({
    required this.current,
    required this.total,
    super.key,
  });

  /// Zero-based index of the current screen.
  final int current;

  /// Total number of onboarding screens.
  final int total;

  @override
  Widget build(BuildContext context) {
    assert(current >= 0 && current < total, 'current must be in [0, total)');

    final ColorScheme colors = Theme.of(context).colorScheme;

    // TODO(milliorn): animate the active dot transition (AnimatedContainer or
    // AnimatedSwitcher) once all onboarding screens exist - issue #14.
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
