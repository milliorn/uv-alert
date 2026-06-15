import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/screens/location_onboarding_screen.dart';
import 'package:uvalert/screens/theme_onboarding_screen.dart';
import 'package:uvalert/storage/preferences.dart';

const double _logoWidth = 200;
const Duration _settingsTimeout = Duration(seconds: 10);
const Duration _minSplashDuration = Duration(seconds: 2);
const double _splashPaddingHorizontal = 32;
const double _statusTopGap = 16;
const double _bottomGap = 32;
const double _settingsStepProgress = 0.5;

enum _SplashStep {
  loading('Loading preferences…', 0),
  settings('Loading settings…', _settingsStepProgress);

  const _SplashStep(this.label, this.progress);

  final String label;
  final double progress;
}

/// Returns the first screen the user should see based on [prefs].
Widget _onboardingDestination(Preferences prefs) {
  if (!prefs.isFirstLaunch) return const DashboardScreen();
  if (prefs.isThemeStepDone) return const LocationOnboardingScreen();
  return const ThemeOnboardingScreen();
}

/// Whether the minimum splash duration floor should apply.
///
/// Only enforced on a truly fresh first launch (no steps completed yet).
/// Mid-onboarding cold relaunches and returning users skip the floor so
/// they reach their destination as quickly as possible.
bool _shouldEnforceMinSplash(Preferences prefs) =>
    prefs.isFirstLaunch && !prefs.isThemeStepDone;

/// Splash screen shown at startup. Loads providers then routes to the
/// appropriate screen based on onboarding state.
class OnboardingScreen extends ConsumerStatefulWidget {
  /// Creates an [OnboardingScreen].
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _SplashStep _step = _SplashStep.loading;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    try {
      final Preferences preferences = await ref.read(
        preferencesProvider.future,
      );

      if (!mounted) return;

      setState(() => _step = _SplashStep.settings);

      final Duration splashFloor = _shouldEnforceMinSplash(preferences)
          ? _minSplashDuration
          : Duration.zero;
      await _awaitSettingsFor(splashFloor);

      if (!mounted) return;

      unawaited(
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => _onboardingDestination(preferences),
          ),
        ),
      );
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load settings. Please restart the app.';
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Error: $e');
    }
  }

  void _onRetry() {
    setState(() {
      _step = _SplashStep.loading;
      _errorMessage = '';
    });
    unawaited(_run());
  }

  /// Waits until [settingsProvider] leaves its loading state, then waits for
  /// any remaining time in [minDuration] (pass [Duration.zero] to skip).
  Future<void> _awaitSettingsFor(Duration minDuration) async {
    // Start the stopwatch before subscribing so that synchronous completion
    // via fireImmediately: true is counted in elapsed time.
    final Stopwatch stopwatch = Stopwatch()..start();

    final Completer<void> completer = Completer<void>();

    final ProviderSubscription<AsyncValue<SettingsState>> sub = ref
        .listenManual<AsyncValue<SettingsState>>(settingsProvider, (
          _,
          AsyncValue<SettingsState> next,
        ) {
          if (completer.isCompleted) return;
          if (next.hasValue) {
            completer.complete();
          } else if (next.hasError) {
            completer.completeError(next.error!, next.stackTrace);
          }
        }, fireImmediately: true);

    await completer.future.timeout(_settingsTimeout).whenComplete(sub.close);
    stopwatch.stop();

    final Duration remaining = minDuration - stopwatch.elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _splashPaddingHorizontal,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Spacer(),

              Image.asset(
                'assets/images/high-resolution-color-logo.png',
                width: _logoWidth,
              ),

              const Spacer(),

              LinearProgressIndicator(value: _step.progress),

              const SizedBox(height: _statusTopGap),

              Text(
                _errorMessage.isEmpty ? _step.label : _errorMessage,
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              if (_errorMessage.isNotEmpty) ...<Widget>[
                const SizedBox(height: _statusTopGap),
                FilledButton.tonal(
                  onPressed: _onRetry,
                  child: const Text('Retry'),
                ),
              ],

              const SizedBox(height: _bottomGap),
            ],
          ),
        ),
      ),
    );
  }
}
