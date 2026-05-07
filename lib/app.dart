import 'package:flutter/material.dart';

class UvAlertApp extends StatelessWidget {
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
