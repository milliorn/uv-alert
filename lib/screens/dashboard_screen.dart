import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/models/weather_alert.dart';
import 'package:uvalert/providers/location_provider.dart';
import 'package:uvalert/providers/uv_provider.dart';
import 'package:uvalert/screens/settings_screen.dart';
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
    final AsyncValue<UvData> uvState = ref.watch(uvProvider);
    final bool showNoData = uvState.hasError && !uvState.hasValue;
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
      body: Column(
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
        ],
      ),
    );
  }
}
