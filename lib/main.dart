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
  WidgetsFlutterBinding.ensureInitialized();

  final CrashReportHandler crashHandler = CrashReportHandler();
  WidgetsBinding.instance.addObserver(_CrashHandlerDisposer(crashHandler));

  final Catcher2Options debugOptions = Catcher2Options(
    DialogReportMode(),
    <ReportHandler>[crashHandler, ConsoleHandler()],
  );

  final Catcher2Options releaseOptions = Catcher2Options(
    SilentReportMode(),
    <ReportHandler>[crashHandler],
  );

  Catcher2(
    debugConfig: debugOptions,
    releaseConfig: releaseOptions,
    runAppFunction: () {
      runApp(const ProviderScope(child: UvAlertApp()));
    },
  );
}
