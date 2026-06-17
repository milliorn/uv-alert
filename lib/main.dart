import 'package:catcher_2/catcher_2.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/api/crash_report_handler.dart';
import 'package:uvalert/app.dart';

// Disposes [CrashReportHandler] when the app is detached (process about to
// exit on desktop; best-effort on mobile where the OS may kill without notice).
class _CrashHandlerDisposer extends WidgetsBindingObserver {
  _CrashHandlerDisposer(this._handler);

  final CrashReportHandler _handler;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _handler.dispose();
    }
  }
}

Future<void> main() async {
  final CrashReportHandler crashHandler = CrashReportHandler();

  final Catcher2Options debugOptions = Catcher2Options(
    DialogReportMode(),
    <ReportHandler>[crashHandler, ConsoleHandler()],
  );

  final Catcher2Options releaseOptions = Catcher2Options(
    SilentReportMode(),
    <ReportHandler>[crashHandler],
  );

  // ensureInitialized: true lets Catcher2 call WidgetsFlutterBinding
  // .ensureInitialized() inside its own runZonedGuarded zone on web, avoiding
  // the zone-mismatch warning that fires when we initialize the binding in the
  // outer zone before Catcher2's zone is set up.
  Catcher2(
    debugConfig: debugOptions,
    releaseConfig: releaseOptions,
    ensureInitialized: true,
    runAppFunction: () {
      WidgetsBinding.instance.addObserver(_CrashHandlerDisposer(crashHandler));
      runApp(const ProviderScope(child: UvAlertApp()));
    },
  );
}
