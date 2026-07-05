import 'package:flutter/material.dart';

/// Placeholder for the settings screen.
///
/// Full implementation (location, notifications, support sections) is
/// tracked in a follow-up issue.
class SettingsScreen extends StatelessWidget {
  /// Creates a [SettingsScreen].
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('Settings')),
    );
  }
}
