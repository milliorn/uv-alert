import 'package:flutter/material.dart';

const double _elevation = 0;

/// Transparent, flat AppBar with a back button, shown on onboarding screens
/// that support navigating to the previous step.
// Shared between LocationOnboardingScreen and NotificationOnboardingScreen so
// a single edit keeps both screens visually consistent.
class OnboardingBackAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  /// Creates an [OnboardingBackAppBar].
  const OnboardingBackAppBar({required this.onBack, super.key});

  /// Called when the back button is tapped; `null` disables the button.
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: BackButton(onPressed: onBack),
      backgroundColor: Colors.transparent,
      elevation: _elevation,
    );
  }
}
