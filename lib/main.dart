import 'package:catcher_2/catcher_2.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/api/crash_report_handler.dart';
import 'package:uvalert/app.dart';

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

  Catcher2(
    debugConfig: debugOptions,
    releaseConfig: releaseOptions,
    runAppFunction: () {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(const ProviderScope(child: UvAlertApp()));
    },
  );
}
