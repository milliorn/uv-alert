import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/app.dart';

void main() {
  unawaited(
    runZonedGuarded(
      () async {
        WidgetsFlutterBinding.ensureInitialized();

        FlutterError.onError = (details) {
          FlutterError.presentError(details);
          if (kReleaseMode) {
            // TODO(crashes): forward to crash reporting
            // (e.g. Sentry, Firebase Crashlytics)
          }
        };

        runApp(const ProviderScope(child: UvAlertApp()));
      },
      (error, stack) {
        debugPrint('Unhandled async error: $error\n$stack');
        if (kReleaseMode) {
          // TODO(crashes): forward to crash reporting
          // (e.g. Sentry, Firebase Crashlytics)
        }
      },
    ),
  );
}
