import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/storage/preferences.dart';

/// Shown on first launch only. Marks first launch done then routes to
/// the dashboard.
class OnboardingScreen extends ConsumerWidget {
  /// Creates an [OnboardingScreen].
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final Preferences preferences =
                await ref.read(preferencesProvider.future);
            await preferences.setFirstLaunchDone();
            }, child: null,
        ),
      ),
    );
  }
}
