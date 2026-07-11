import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uvalert/models/weather_alert.dart';
import 'package:uvalert/screens/settings_screen.dart';
import 'package:uvalert/widgets/weather_alert_banner.dart';

/// The main screen shown after onboarding completes.
class DashboardScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
          const Expanded(child: Center(child: Text('Dashboard'))),
        ],
      ),
    );
  }
}
