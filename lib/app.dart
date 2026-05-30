import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/screens/onboarding_screen.dart';
import 'package:uvalert/storage/preferences.dart';

ThemeData _appTheme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.orange,
    brightness: brightness,
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
    final AsyncValue<SettingsState> settings = ref.watch(settingsProvider);

    // Fall back to system theme while settings are loading or on error.
    final ThemeMode themeMode =
        settings.whenData((SettingsState s) => s.themeMode).value ??
        ThemeMode.system;

    return MaterialApp(
      title: 'UV Alert',
      theme: _appTheme(Brightness.light),
      darkTheme: _appTheme(Brightness.dark),
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
