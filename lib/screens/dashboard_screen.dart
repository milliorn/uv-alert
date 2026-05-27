import 'package:flutter/material.dart';

/// The main screen shown after onboarding completes.
class DashboardScreen extends StatelessWidget {
  /// Creates a [DashboardScreen].
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Dashboard')));
  }
}
