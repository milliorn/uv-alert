import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/app.dart';

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        // TODO(crashes): forward to crash reporting
        // (e.g. Sentry, Firebase Crashlytics)
      };

      runApp(const ProviderScope(child: UvAlertApp()));
    },
    (Object error, StackTrace stack) {
      debugPrint('Unhandled async error: $error\n$stack');
      // TODO(crashes): forward to crash reporting
      // (e.g. Sentry, Firebase Crashlytics)
    },
  );
}
