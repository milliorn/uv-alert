import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/screens/onboarding_screen.dart';
import 'package:uvalert/storage/preferences.dart';

// Built once at startup; ColorScheme.fromSeed is expensive per-build.
final ThemeData _lightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
  useMaterial3: true,
);

final ThemeData _darkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.orange,
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
);

/// Root widget of the UV Alert application.
class UvAlertApp extends ConsumerWidget {
  /// Creates a [UvAlertApp].
  const UvAlertApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Preferences> prefs = ref.watch(preferencesProvider);

    // Fall back to system theme while settings are loading or on error.
    final ThemeMode themeMode = ref.watch(
      settingsProvider.select(
        (AsyncValue<SettingsState> s) =>
            s.whenData((SettingsState st) => st.themeMode).value ??
            ThemeMode.system,
      ),
    );

    return MaterialApp(
      title: 'UV Alert',
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: themeMode,
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
