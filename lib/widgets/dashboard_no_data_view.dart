import 'package:flutter/material.dart';

/// Horizontal padding around the no-data message and retry button.
const double dashboardNoDataPaddingHorizontal = 32;

/// Gap between the message and the retry button.
const double dashboardNoDataGap = 16;

/// Icon size for the no-data state.
const double dashboardNoDataIconSize = 48;

/// Full-screen error state shown when the UV data provider has no data and
/// no cached data to fall back to (e.g. network dropped between onboarding
/// and the dashboard, or the cache was corrupted on relaunch).
///
/// Deliberately has no skeleton/loading variant -- this is a rare edge case,
/// not the common first-load path.
class DashboardNoDataView extends StatelessWidget {
  /// Creates a [DashboardNoDataView]. [onRetry] is called when the user taps
  /// the retry button, or `null` to hide the button entirely: per ADR 0010,
  /// a 400 (invalid request) must not be retried, since an identical request
  /// will fail identically.
  const DashboardNoDataView({required this.onRetry, super.key});

  /// Called when the user taps the retry button, or `null` if retrying
  /// would just repeat a request that cannot succeed (see [onRetry]'s
  /// constructor doc).
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: dashboardNoDataPaddingHorizontal,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.cloud_off,
              size: dashboardNoDataIconSize,
              color: colors.error,
            ),
            const SizedBox(height: dashboardNoDataGap),
            Text(
              'No UV data available. Please check your connection.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: dashboardNoDataGap),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
