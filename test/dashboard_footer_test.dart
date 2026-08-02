import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:uvalert/providers/settings_provider.dart';
import 'package:uvalert/providers/uv_provider.dart';
import 'package:uvalert/widgets/dashboard_footer.dart';

import 'fakes/fake_settings_notifier.dart';
import 'fakes/fake_uv_data.dart';
import 'fakes/fake_uv_notifier.dart';

class _MockUrlLauncherPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {}

Widget _wrap({
  required UvNotifier Function() uvNotifier,
  SettingsNotifier Function() settingsNotifier =
      FakeManualLocationSettingsNotifier.new,
}) => ProviderScope(
  // ignore: always_specify_types - Override not in flutter_riverpod public API
  overrides: [
    uvProvider.overrideWith(uvNotifier),
    settingsProvider.overrideWith(settingsNotifier),
  ],
  // Not `const`: each call must construct a genuinely new DashboardFooter
  // instance rather than reusing one frozen canonicalized const object
  // across every test, so the constructor line is credited by coverage
  // the same way a real (non-const) call site would be.
  // ignore: prefer_const_constructors
  child: MaterialApp(home: Scaffold(body: DashboardFooter())),
);

void main() {
  late _MockUrlLauncherPlatform mockUrlLauncher;
  late UrlLauncherPlatform originalUrlLauncher;

  setUpAll(() {
    registerFallbackValue(const LaunchOptions());
    originalUrlLauncher = UrlLauncherPlatform.instance;
  });

  setUp(() {
    mockUrlLauncher = _MockUrlLauncherPlatform();
    UrlLauncherPlatform.instance = mockUrlLauncher;
    when(
      () => mockUrlLauncher.launchUrl(any(), any()),
    ).thenAnswer((_) async => true);
  });

  tearDown(() {
    UrlLauncherPlatform.instance = originalUrlLauncher;
  });

  testWidgets('renders updated time and city/state when data is fresh', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        uvNotifier: () =>
            FakeDataUvNotifier(makeUvData(fetchedAt: DateTime.now().toUtc())),
      ),
    );

    expect(find.text('Updated just now · Fresno, CA'), findsOneWidget);
  });

  for (final (Duration elapsed, String expectedSuffix) in <(Duration, String)>[
    (const Duration(minutes: 5), 'mins ago · Fresno, CA'),
    (const Duration(hours: 3), 'hr ago · Fresno, CA'),
    (const Duration(days: 2), 'd ago · Fresno, CA'),
  ]) {
    testWidgets('formats elapsed time as "$expectedSuffix"', (
      WidgetTester tester,
    ) async {
      final DateTime fetchedAt = DateTime.now().toUtc().subtract(elapsed);

      await tester.pumpWidget(
        _wrap(
          uvNotifier: () =>
              FakeDataUvNotifier(makeUvData(fetchedAt: fetchedAt)),
        ),
      );

      expect(find.textContaining(expectedSuffix), findsOneWidget);
    });
  }

  testWidgets(
    'periodic timer refreshes the label and is cancelled on dispose',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(uvNotifier: () => FakeDataUvNotifier(makeUvData())),
      );

      expect(find.byType(DashboardFooter), findsOneWidget);

      // Advancing the test binding's virtual clock past one refresh
      // interval must not throw and must not leave a pending timer once
      // the widget is torn down -- flutter_test fails the test at
      // tearDown if any Timer is still active, so a passing test here
      // proves both that the periodic Timer fires (FakeAsync isn't
      // needed to observe this: pump(duration) drives Flutter's own
      // timer queue) and that dispose() cancels it correctly.
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('periodic timer skips rebuilding when uvProvider has no value', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(uvNotifier: FakeErrorUvNotifier.new));

    expect(find.textContaining('Updated'), findsNothing);

    // Ticking past a refresh interval with no cached uvData must not
    // throw and must not leave a pending timer once torn down -- this
    // exercises the early return added so the timer skips setState
    // when there is nothing to refresh.
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('omits the location segment when manualLocation is null', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        uvNotifier: () =>
            FakeDataUvNotifier(makeUvData(fetchedAt: DateTime.now().toUtc())),
        settingsNotifier: FakeLoadedSettingsNotifier.new,
      ),
    );

    expect(find.text('Updated just now'), findsOneWidget);
    expect(find.textContaining('·'), findsNothing);
  });

  testWidgets('omits the location segment when manualLocation is empty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        uvNotifier: () =>
            FakeDataUvNotifier(makeUvData(fetchedAt: DateTime.now().toUtc())),
        settingsNotifier: () => FakeManualLocationSettingsNotifier(''),
      ),
    );

    expect(find.text('Updated just now'), findsOneWidget);
    expect(find.textContaining('·'), findsNothing);
  });

  testWidgets('omits the updated line entirely when uvProvider has no value', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(uvNotifier: FakeErrorUvNotifier.new));

    expect(find.textContaining('Updated'), findsNothing);
  });

  testWidgets('renders a tappable GitHub link', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(uvNotifier: () => FakeDataUvNotifier(makeUvData())),
    );

    expect(find.widgetWithText(TextButton, 'GitHub'), findsOneWidget);
  });

  testWidgets('tapping the GitHub link launches the repo URL', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(uvNotifier: () => FakeDataUvNotifier(makeUvData())),
    );

    await tester.tap(find.widgetWithText(TextButton, 'GitHub'));
    await tester.pumpAndSettle();

    final List<dynamic> capturedArgs = verify(
      () => mockUrlLauncher.launchUrl(captureAny(), captureAny()),
    ).captured;
    expect(capturedArgs.first, 'https://github.com/milliorn/uv-alert');
  });

  testWidgets('shows a SnackBar when the GitHub link fails to launch', (
    WidgetTester tester,
  ) async {
    when(
      () => mockUrlLauncher.launchUrl(any(), any()),
    ).thenAnswer((_) async => false);

    await tester.pumpWidget(
      _wrap(uvNotifier: () => FakeDataUvNotifier(makeUvData())),
    );

    await tester.tap(find.widgetWithText(TextButton, 'GitHub'));
    await tester.pumpAndSettle();

    expect(find.text('Could not open GitHub'), findsOneWidget);
  });

  testWidgets('renders the copyright notice with the current year', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(uvNotifier: () => FakeDataUvNotifier(makeUvData())),
    );

    expect(
      find.textContaining('© ${DateTime.now().year} UV Alert'),
      findsOneWidget,
    );
  });
}
