import 'package:flutter/material.dart';

/// Root widget of the UV Alert application.
class UvAlertApp extends StatelessWidget {
  /// Creates the [UvAlertApp].
  const UvAlertApp({super.key});

  // Override build to define the widget tree. This is not optional -
  // StatelessWidget declares build as abstract with no default body,
  // so Dart will not compile without it. Flutter calls this whenever
  // the widget needs to be rendered.
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
