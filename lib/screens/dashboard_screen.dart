import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/api/uv_api.dart';
import 'package:uvalert/constants.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/providers/location_provider.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/providers/uv_provider.dart';
import 'package:uvalert/screens/settings_screen.dart';
import 'package:uvalert/widgets/dashboard_footer.dart';
import 'package:uvalert/widgets/dashboard_hero.dart';
import 'package:uvalert/widgets/dashboard_no_data_view.dart';
import 'package:uvalert/widgets/proxy_error_banner.dart';
import 'package:uvalert/widgets/uv_daily_chart.dart';
import 'package:uvalert/widgets/uv_hourly_chart.dart';
import 'package:uvalert/widgets/weather_alert_banner.dart';

/// Height reserved for [UvHourlyChart] below the hero, per
/// `.private/architecture/SCREENS.md`'s Dashboard Screen layout order
/// (Hero, then Hourly Chart, then Weekly Chart, then Footer).
const double _hourlyChartHeight = 220;

/// Height reserved for [UvDailyChart], matching [_hourlyChartHeight]'s
/// role as a fixed size fl_chart needs a bounded constraint to lay out in.
const double _dailyChartHeight = 180;

/// Vertical gap between the hero, hourly chart, and daily chart sections.
const double _dashboardSectionGap = 16;

/// Padding around the two chart sections, matching the hero's own implicit
/// centering so charts don't run edge-to-edge.
///
/// Wide enough that the hourly chart's rightmost x-axis label (e.g. "7 PM"),
/// which fl_chart centers on the axis's own edge rather than insetting it,
/// isn't clipped by the screen edge, confirmed by screenshotting a
/// populated dashboard.
const double _chartHorizontalPadding = 20;

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
    final UvData? uvData = uvState.value;
    // A 400 means the current request itself is invalid (e.g. bad lat/lon);
    // retrying would just repeat it. See ADR 0010's "do not retry" rule for
    // 400, and DashboardNoDataView's onRetry doc. Checked against uvState's
    // own error (not proxyErrorProvider.immediateStatusCode, which stays
    // sticky through a later 500/503/504 and would keep suppressing Retry
    // for a since-changed, retryable failure).
    final Object? uvError = uvState.error;
    final bool isInvalidRequest =
        uvError is UvApiException && uvError.statusCode == httpBadRequest;

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
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ProxyErrorToastListener(
          child: Column(
            children: <Widget>[
              const ProxyErrorBanner(),
              const WeatherAlertBanner(),
              Expanded(
                child: showNoData
                    ? DashboardNoDataView(
                        onRetry: isInvalidRequest
                            ? null
                            : () {
                                final LocationState location = ref.read(
                                  locationProvider,
                                );

                                if (location == null) return;

                                unawaited(
                                  ref
                                      .read(uvProvider.notifier)
                                      .fetch(
                                        lat: location.lat,
                                        lon: location.lon,
                                      ),
                                );
                              },
                      )
                    : SingleChildScrollView(
                        child: Column(
                          spacing: _dashboardSectionGap,
                          children: <Widget>[
                            const DashboardHero(),
                            if (uvData != null) ...<Widget>[
                              _chartSection(
                                height: _hourlyChartHeight,
                                child: UvHourlyChart(uvData: uvData),
                              ),
                              _chartSection(
                                height: _dailyChartHeight,
                                child: UvDailyChart(uvData: uvData),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
              const DashboardFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps [child] in the fixed [height] and shared horizontal padding common
/// to both dashboard chart sections.
Widget _chartSection({required double height, required Widget child}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: _chartHorizontalPadding),
    child: SizedBox(height: height, child: child),
  );
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
