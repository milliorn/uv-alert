import 'package:catcher_2/catcher_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/constants.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/screens/onboarding_screen.dart';

// Built once at startup; ColorScheme.fromSeed is expensive per-build.
final ThemeData _lightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
  useMaterial3: true,
);

final ThemeData _darkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: logoPurple,
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
    // Fall back to system theme while settings are loading or on error.
    final ThemeMode themeMode = ref.watch(
      settingsProvider.select(
        (AsyncValue<SettingsState> s) => s.value?.themeMode ?? ThemeMode.system,
      ),
    );

    return MaterialApp(
      title: 'UV Alert',
      navigatorKey: Catcher2.navigatorKey,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: themeMode,
      home: const OnboardingScreen(),
    );
  }
}
