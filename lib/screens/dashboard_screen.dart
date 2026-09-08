import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/providers/location_provider.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/providers/uv_provider.dart';
import 'package:uvalert/screens/settings_screen.dart';
import 'package:uvalert/widgets/dashboard_footer.dart';
import 'package:uvalert/widgets/dashboard_no_data_view.dart';
import 'package:uvalert/widgets/proxy_error_banner.dart';
import 'package:uvalert/widgets/weather_alert_banner.dart';

/// The main screen shown after onboarding completes.
class DashboardScreen extends ConsumerStatefulWidget {
  /// Creates a [DashboardScreen].
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Deferred to a post-frame callback (not called directly here) because
    // _restoreLocationIfNeeded may mutate locationProvider, and Riverpod
    // disallows mutating a provider while the widget tree is still building
    // -- a constraint on mutation during build, not on reading providers
    // from initState, which is otherwise fine (e.g. OnboardingScreen reads
    // preferencesProvider directly from initState).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restoreLocationIfNeeded(ref, ref.read(settingsProvider));
    });
  }

  @override
  Widget build(BuildContext context) {
    // Covers settings resolving (loading -> data) after the one-shot
    // initState callback above has already run and found nothing to
    // restore yet.
    ref.listen(settingsProvider, (_, AsyncValue<SettingsState> next) {
      _restoreLocationIfNeeded(ref, next);
    });

    final AsyncValue<UvData> uvState = ref.watch(uvProvider);
    final bool showNoData = uvState.isNoData;
    final LocationState location = ref.watch(locationProvider);

    return ProxyErrorToastListener(
      child: Scaffold(
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
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              const ProxyErrorBanner(),
              // uvProvider's UvData.alerts is the real fetch/parse path for
              // government weather alerts (see WeatherAlert.fromJson,
              // UvData.fromJson) -- only the single first alert is surfaced
              // here since WeatherAlertBanner still only accepts one; showing
              // more than one, plus a full alert list, is issue #99.
              WeatherAlertBanner(alert: uvState.value?.alerts.firstOrNull),
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

  final ManualLocation? manualLocation = settings.manualLocation;
  if (manualLocation == null) return;

  ref
      .read(locationProvider.notifier)
      .setManual(lat: manualLocation.lat, lon: manualLocation.lon);
}
