import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/constants.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/screens/dashboard_screen.dart';
import 'package:uvalert/screens/location_onboarding_screen.dart';
import 'package:uvalert/screens/notification_onboarding_screen.dart';
import 'package:uvalert/screens/theme_onboarding_screen.dart';
import 'package:uvalert/storage/preferences.dart';

const double _logoWidth = 200;
const Duration _loadTimeout = apiDefaultTimeout;
const Duration _minSplashDuration = Duration(seconds: 2);
const double _splashPaddingHorizontal = 32;
const double _statusTopGap = 16;
const double _bottomGap = 32;
const double _settingsStepProgress = 1 / totalOnboardingSteps;
const double _errorStepProgress = 0;

enum _SplashStep {
  // null → indeterminate animation while preferences are being read.
  loading('Loading preferences…', null),
  settings('Loading settings…', _settingsStepProgress),
  // Frozen at _errorStepProgress so pumpAndSettle can settle in tests and the
  // user sees a stopped bar rather than a spinner when something goes wrong.
  error('', _errorStepProgress);

  const _SplashStep(this.label, this.progress);

  final String label;
  final double? progress;
}

/// Returns the first screen the user should see based on [prefs].
Widget _onboardingDestination(Preferences prefs) {
  if (!prefs.isFirstLaunch) return const DashboardScreen();
  if (prefs.isLocationStepDone) return const NotificationOnboardingScreen();
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
  ///
  /// [loadTimeout] is injected for testing; defaults to [_loadTimeout].
  const OnboardingScreen({super.key, this.loadTimeout});

  /// Override for tests; production code leaves this null and the state
  /// falls back to [_loadTimeout].
  final Duration? loadTimeout;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _SplashStep _step = _SplashStep.loading;
  String _errorMessage = '';

  Duration get _timeout => widget.loadTimeout ?? _loadTimeout;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    try {
      final Preferences preferences = await ref
          .read(preferencesProvider.future)
          .timeout(_timeout);

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
        _step = _SplashStep.error;
        _errorMessage = 'Could not load app data. Please restart the app.';
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _step = _SplashStep.error;
        _errorMessage = 'Something went wrong. Please restart the app.';
      });
    }
  }

  void _onRetry() {
    setState(() {
      _step = _SplashStep.loading;
      _errorMessage = '';
    });
    ref
      ..invalidate(preferencesProvider)
      ..invalidate(settingsProvider);
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

    await completer.future.timeout(_timeout).whenComplete(sub.close);
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
                _step == _SplashStep.error ? _errorMessage : _step.label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              if (_step == _SplashStep.error) ...<Widget>[
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
