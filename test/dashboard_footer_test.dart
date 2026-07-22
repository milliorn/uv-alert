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

void main() {
  late _MockUrlLauncherPlatform mockUrlLauncher;

  setUpAll(() {
    registerFallbackValue(const LaunchOptions());
  });

  setUp(() {
    mockUrlLauncher = _MockUrlLauncherPlatform();
    UrlLauncherPlatform.instance = mockUrlLauncher;
    when(
      () => mockUrlLauncher.launchUrl(any(), any()),
    ).thenAnswer((_) async => true);
  });
  testWidgets('renders updated time and city/state when data is fresh', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [
          uvProvider.overrideWith(
            () => FakeDataUvNotifier(
              makeUvData(fetchedAt: DateTime.now().toUtc()),
            ),
          ),
          settingsProvider.overrideWith(FakeManualLocationSettingsNotifier.new),
        ],
        child: const MaterialApp(home: Scaffold(body: DashboardFooter())),
      ),
    );

    expect(find.text('Updated just now · Fresno, CA'), findsOneWidget);
  });

  testWidgets('formats elapsed minutes', (WidgetTester tester) async {
    final DateTime fetchedAt = DateTime.now().toUtc().subtract(
      const Duration(minutes: 5),
    );

    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [
          uvProvider.overrideWith(
            () => FakeDataUvNotifier(makeUvData(fetchedAt: fetchedAt)),
          ),
          settingsProvider.overrideWith(FakeManualLocationSettingsNotifier.new),
        ],
        child: const MaterialApp(home: Scaffold(body: DashboardFooter())),
      ),
    );

    expect(find.textContaining('min ago · Fresno, CA'), findsOneWidget);
  });

  testWidgets('formats elapsed hours', (WidgetTester tester) async {
    final DateTime fetchedAt = DateTime.now().toUtc().subtract(
      const Duration(hours: 3),
    );

    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [
          uvProvider.overrideWith(
            () => FakeDataUvNotifier(makeUvData(fetchedAt: fetchedAt)),
          ),
          settingsProvider.overrideWith(FakeManualLocationSettingsNotifier.new),
        ],
        child: const MaterialApp(home: Scaffold(body: DashboardFooter())),
      ),
    );

    expect(find.textContaining('hr ago · Fresno, CA'), findsOneWidget);
  });

  testWidgets('formats elapsed days', (WidgetTester tester) async {
    final DateTime fetchedAt = DateTime.now().toUtc().subtract(
      const Duration(days: 2),
    );

    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [
          uvProvider.overrideWith(
            () => FakeDataUvNotifier(makeUvData(fetchedAt: fetchedAt)),
          ),
          settingsProvider.overrideWith(FakeManualLocationSettingsNotifier.new),
        ],
        child: const MaterialApp(home: Scaffold(body: DashboardFooter())),
      ),
    );

    expect(find.textContaining('d ago · Fresno, CA'), findsOneWidget);
  });

  testWidgets('omits the location segment when manualLocation is null', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [
          uvProvider.overrideWith(
            () => FakeDataUvNotifier(
              makeUvData(fetchedAt: DateTime.now().toUtc()),
            ),
          ),
          settingsProvider.overrideWith(FakeLoadedSettingsNotifier.new),
        ],
        child: const MaterialApp(home: Scaffold(body: DashboardFooter())),
      ),
    );

    expect(find.text('Updated just now'), findsOneWidget);
    expect(find.textContaining('·'), findsNothing);
  });

  testWidgets('omits the updated line entirely when uvProvider has no value', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [
          uvProvider.overrideWith(FakeErrorUvNotifier.new),
          settingsProvider.overrideWith(FakeManualLocationSettingsNotifier.new),
        ],
        child: const MaterialApp(home: Scaffold(body: DashboardFooter())),
      ),
    );

    expect(find.textContaining('Updated'), findsNothing);
  });

  testWidgets('renders a tappable GitHub link', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [
          uvProvider.overrideWith(
            () => FakeDataUvNotifier(makeUvData()),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DashboardFooter())),
      ),
    );

    expect(find.widgetWithText(TextButton, 'GitHub'), findsOneWidget);
  });

  testWidgets('tapping the GitHub link launches the repo URL', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [
          uvProvider.overrideWith(
            () => FakeDataUvNotifier(makeUvData()),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DashboardFooter())),
      ),
    );

    await tester.tap(find.widgetWithText(TextButton, 'GitHub'));
    await tester.pumpAndSettle();

    final List<dynamic> capturedArgs = verify(
      () => mockUrlLauncher.launchUrl(captureAny(), captureAny()),
    ).captured;
    expect(capturedArgs.first, 'https://github.com/milliorn/uv-alert');
  });

  testWidgets('renders the copyright notice with the current year', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [
          uvProvider.overrideWith(
            () => FakeDataUvNotifier(makeUvData()),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DashboardFooter())),
      ),
    );

    expect(
      find.textContaining('© ${DateTime.now().year} UV Alert'),
      findsOneWidget,
    );
  });
}
