import 'package:catcher_2/catcher_2.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/app.dart';

Future<void> main() async {
  final Catcher2Options debugOptions = Catcher2Options(
    DialogReportMode(),
    <ReportHandler>[
      EmailManualHandler(
        <String>['scottmilliorn@gmail.com'],
        emailTitle: 'UV Alert crash report',
      ),
      ConsoleHandler(),
    ],
  );

  final Catcher2Options releaseOptions = Catcher2Options(
    SilentReportMode(),
    <ReportHandler>[
      EmailManualHandler(
        <String>['scottmilliorn@gmail.com'],
        emailTitle: 'UV Alert crash report',
      ),
    ],
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
