import 'package:flutter/material.dart';

/// Root widget of the UV Alert application.
class UvAlertApp extends StatelessWidget {
  /// Creates the [UvAlertApp].
  const UvAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UV Alert',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const Placeholder(),
    );
  }
}
