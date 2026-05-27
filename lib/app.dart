import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/screens/onboarding_screen.dart';
import 'package:uvalert/storage/preferences.dart';

/// Root widget of the UV Alert application.
class UvAlertApp extends ConsumerWidget {
  /// Creates a [UvAlertApp].
  const UvAlertApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Preferences> prefs = ref.watch(preferencesProvider);

    return MaterialApp(
      title: 'UV Alert',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: switch (prefs) {
        AsyncData<Preferences>(:final Preferences value) =>
          value.isFirstLaunch
              ? const OnboardingScreen()
              : const DashboardScreen(),
        AsyncError<Preferences>() => const Scaffold(
          body: Center(child: Text('Failed to load preferences.')),
        ),
        _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
      },
    );
  }
}
