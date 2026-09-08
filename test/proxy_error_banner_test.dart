import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/constants.dart';
import 'package:uvalert/providers/uv_provider.dart';
import 'package:uvalert/widgets/proxy_error_banner.dart';

import 'fakes/fake_proxy_error_notifier.dart';

Widget _wrap(Widget child, {required ProxyErrorState errorState}) {
  return ProviderScope(
    // ignore: always_specify_types - Override not in flutter_riverpod public API
    overrides: [
      proxyErrorProvider.overrideWith(
        () => FakeProxyErrorNotifier(errorState),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(body: ProxyErrorToastListener(child: child)),
    ),
  );
}

void main() {
  // ---------------------------------------------------------------------------
  // ProxyErrorBanner — no active error
  // ---------------------------------------------------------------------------

  testWidgets('renders nothing when there is no active proxy error', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      // Not const: every other call site in this file constructs
      // ProxyErrorBanner() inside a const tree, which the compiler
      // canonicalizes into one shared instance -- coverage tooling then
      // credits the constructor only once, and inconsistently. This one
      // non-const call guarantees the constructor line is always counted.
      // ignore: prefer_const_constructors
      _wrap(ProxyErrorBanner(), errorState: const ProxyErrorState()),
    );

    expect(find.byType(MaterialBanner), findsNothing);
  });

  // ---------------------------------------------------------------------------
  // ProxyErrorBanner — immediate persistent banner (429, 502, 400)
  // ---------------------------------------------------------------------------

  testWidgets('shows a persistent banner immediately for 429', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ProxyErrorBanner(),
        errorState: const ProxyErrorState(
          consecutiveFailures: 1,
          lastStatusCode: httpTooManyRequests,
        ),
      ),
    );

    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(find.text(proxyErrorTooManyRequestsMessage), findsOneWidget);
  });

  testWidgets('shows a persistent banner immediately for 502', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ProxyErrorBanner(),
        errorState: const ProxyErrorState(
          consecutiveFailures: 1,
          lastStatusCode: httpBadGateway,
        ),
      ),
    );

    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(find.text(proxyErrorUnavailableMessage), findsOneWidget);
  });

  testWidgets('shows a persistent banner immediately for 400', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ProxyErrorBanner(),
        errorState: const ProxyErrorState(
          consecutiveFailures: 1,
          lastStatusCode: httpBadRequest,
        ),
      ),
    );

    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(find.text(proxyErrorInvalidRequestMessage), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // ProxyErrorBanner — escalating server errors (500/503/504)
  // ---------------------------------------------------------------------------

  for (final int code in <int>[
    httpInternalServerError,
    httpServiceUnavailable,
    httpGatewayTimeout,
  ]) {
    testWidgets(
      'does not show a banner on the 1st consecutive failure for $code',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            const ProxyErrorBanner(),
            errorState: ProxyErrorState(
              consecutiveFailures: 1,
              lastStatusCode: code,
            ),
          ),
        );

        expect(find.byType(MaterialBanner), findsNothing);
      },
    );

    testWidgets(
      'does not show a banner on the 2nd consecutive failure for $code',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            const ProxyErrorBanner(),
            errorState: ProxyErrorState(
              consecutiveFailures: 2,
              lastStatusCode: code,
            ),
          ),
        );

        expect(find.byType(MaterialBanner), findsNothing);
      },
    );

    testWidgets(
      'shows the persistent banner on the 3rd consecutive failure for $code',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(
            const ProxyErrorBanner(),
            errorState: ProxyErrorState(
              consecutiveFailures: proxyErrorEscalationThreshold,
              lastStatusCode: code,
            ),
          ),
        );

        expect(find.byType(MaterialBanner), findsOneWidget);
        expect(find.text(proxyErrorUnavailableMessage), findsOneWidget);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // ProxyErrorBanner — clears on success
  // ---------------------------------------------------------------------------

  testWidgets('banner clears when the error state resets to zero failures', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      // ignore: always_specify_types - Override not in flutter_riverpod public API
      overrides: [
        proxyErrorProvider.overrideWith(
          () => FakeProxyErrorNotifier(
            const ProxyErrorState(
              consecutiveFailures: proxyErrorEscalationThreshold,
              lastStatusCode: httpBadGateway,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: ProxyErrorBanner()),
        ),
      ),
    );

    expect(find.byType(MaterialBanner), findsOneWidget);

    container.read(proxyErrorProvider.notifier).recordSuccess();
    await tester.pump();

    expect(find.byType(MaterialBanner), findsNothing);
  });

  // ---------------------------------------------------------------------------
  // ProxyErrorToastListener — toast on 1st failure, silent after
  // ---------------------------------------------------------------------------

  testWidgets('shows a toast once on the 1st 500/503/504 failure', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: ProxyErrorToastListener(child: SizedBox.shrink()),
          ),
        ),
      ),
    );

    container
        .read(proxyErrorProvider.notifier)
        .recordFailure(httpInternalServerError);
    await tester.pump();

    expect(find.text(proxyErrorTransientToastMessage), findsOneWidget);
  });

  testWidgets(
    'does not show a toast on the 2nd or 3rd consecutive 500/503/504 '
    'failure',
    (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer(
        // ignore: always_specify_types - Override not in flutter_riverpod public API
        overrides: [
          proxyErrorProvider.overrideWith(
            () => FakeProxyErrorNotifier(
              const ProxyErrorState(
                consecutiveFailures: 1,
                lastStatusCode: httpInternalServerError,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ProxyErrorToastListener(child: SizedBox.shrink()),
            ),
          ),
        ),
      );

      container.read(proxyErrorProvider.notifier).recordFailure(
        httpInternalServerError,
      );
      await tester.pump();

      expect(find.text(proxyErrorTransientToastMessage), findsNothing);
    },
  );

  testWidgets('does not show a toast for 429, 502, or 400', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: ProxyErrorToastListener(child: SizedBox.shrink()),
          ),
        ),
      ),
    );

    container.read(proxyErrorProvider.notifier).recordFailure(
      httpTooManyRequests,
    );
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
  });
}
