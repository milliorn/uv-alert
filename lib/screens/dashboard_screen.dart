import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/models/weather_alert.dart';
import 'package:uvalert/providers/location_provider.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/providers/uv_provider.dart';
import 'package:uvalert/screens/settings_screen.dart';
import 'package:uvalert/widgets/dashboard_footer.dart';
import 'package:uvalert/widgets/dashboard_no_data_view.dart';
import 'package:uvalert/widgets/weather_alert_banner.dart';

/// The main screen shown after onboarding completes.
class DashboardScreen extends ConsumerWidget {
  /// Creates a [DashboardScreen].
  ///
  /// [activeAlert] is the government weather alert to surface in the
  /// banner below the app bar, or `null` when there is none. Fetching and
  /// parsing the real OWM `alerts` payload is out of scope for now -- see
  /// [WeatherAlert].
  const DashboardScreen({this.activeAlert, super.key});

  /// The active alert to show in the dashboard's banner, if any.
  final WeatherAlert? activeAlert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching (not just reading) settingsProvider ensures this build()
    // re-runs when settings resolve from loading to data, so the
    // post-frame callback below gets a chance to restore locationProvider
    // as soon as a manual location becomes available -- not just on the
    // widget's very first build.
    final AsyncValue<SettingsState> settingsState = ref.watch(settingsProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      _restoreLocationIfNeeded(ref, settingsState);
    });

    final bool showNoData = ref.watch(uvProvider).isNoData;
    final LocationState location = ref.watch(locationProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.location_pin),
          tooltip: 'Change location',
          onPressed: () {},
        ),
        title: const Text('UV Alert'),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Open settings',
            onPressed: () {
              unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            WeatherAlertBanner(alert: activeAlert),
            Expanded(
              child: showNoData
                  ? DashboardNoDataView(
                      onRetry: () {
                        if (location == null) return;

                        unawaited(
                          ref
                              .read(uvProvider.notifier)
                              .fetch(lat: location.lat, lon: location.lon),
                        );
                      },
                    )
                  : const Center(child: Text('Dashboard')),
            ),
            const DashboardFooter(),
          ],
        ),
      ),
    );
  }
}

/// Populates [locationProvider] from a manually saved location the first
/// time [settingsState] resolves with one, so a fresh app launch doesn't
/// leave [locationProvider] `null` (and [uvProvider] un-fetched) until the
/// user re-visits onboarding. Only restores the manual-location case --
/// GPS mode re-acquires a fresh position instead, since a stale cached fix
/// could be far from the device's current location.
///
/// No-op once [locationProvider] already has a value, so it never
/// overwrites a location the user (or GPS) has already set this session.
void _restoreLocationIfNeeded(
  WidgetRef ref,
  AsyncValue<SettingsState> settingsState,
) {
  if (ref.read(locationProvider) != null) return;

  final SettingsState? settings = settingsState.value;

  if (settings == null || settings.useGps) return;

  final double? lat = settings.manualLat;
  final double? lon = settings.manualLon;
  
  if (lat == null || lon == null) return;

  ref.read(locationProvider.notifier).setManual(lat: lat, lon: lon);
}
