import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/constants.dart';
import 'package:uvalert/providers/uv_provider.dart';

/// Number of consecutive 500/503/504 failures required before escalating
/// from a one-time toast to a persistent banner. See
/// `docs/adr/0010-proxy-error-code-contract.md`.
const int proxyErrorEscalationThreshold = 3;

/// The persistent-banner message shown for 502 immediately, and for
/// 500/503/504 once [proxyErrorEscalationThreshold] consecutive failures
/// have occurred. Identical text for both cases per ADR 0010: from the
/// user's perspective there is nothing to distinguish -- UV data is stale
/// and the app is still trying.
const String proxyErrorUnavailableMessage =
    'UV data is temporarily unavailable. Showing last known reading.';

/// Banner message for 429 (proxy abuse detection).
const String proxyErrorTooManyRequestsMessage =
    'Too many requests. Please try again later.';

/// Banner message for 400 (invalid request parameters).
///
/// Distinct wording from [proxyErrorUnavailableMessage]: a 400 is a client
/// bug (bad lat/lon), not a transient upstream failure, and retrying an
/// identical request will not help -- per ADR 0010, "do not retry".
const String proxyErrorInvalidRequestMessage =
    'Something went wrong loading UV data for this location.';

/// The one-time toast message shown on the first 500/503/504 failure,
/// before [proxyErrorEscalationThreshold] is reached.
///
/// Does not claim a retry is in progress: the app has no automatic retry
/// after a fetch failure (see `PeriodicRebuildMixin`, which only repaints
/// already-cached data on a timer, never re-fetches). The user must tap
/// Retry in `DashboardNoDataView`, or change location, to trigger another
/// fetch.
const String proxyErrorTransientToastMessage =
    'UV data could not be refreshed. Showing last known reading.';

/// Persistent banner text for [errorState], or `null` if no banner should
/// show given the current state.
///
/// [ProxyErrorState.immediateStatusCode] (400/429/502) takes priority when
/// set: ADR 0010 calls for these to show their banner on the 1st occurrence
/// and keep it shown until success, regardless of what
/// [ProxyErrorState.consecutiveFailures] is doing underneath. Otherwise,
/// 500/503/504 only show a banner once [ProxyErrorState.consecutiveFailures]
/// reaches [proxyErrorEscalationThreshold]; before that, [ProxyErrorBanner]
/// shows a toast instead (handled by the caller, not this function).
String? _bannerMessageFor(ProxyErrorState errorState) {
  switch (errorState.immediateStatusCode) {
    case httpTooManyRequests:
      return proxyErrorTooManyRequestsMessage;
    case httpBadGateway:
      return proxyErrorUnavailableMessage;
    case httpBadRequest:
      return proxyErrorInvalidRequestMessage;
    case null:
      break;
  }

  if (errorState.lastStatusCode != null &&
      errorState.consecutiveFailures >= proxyErrorEscalationThreshold) {
    return proxyErrorUnavailableMessage;
  }

  return null;
}

/// A persistent banner shown below the app bar when the proxy is failing in
/// a way that ADR 0010 calls for user-visible, non-dismissible feedback.
///
/// Renders nothing when there is no active proxy error, or when the active
/// error is still within its toast-only grace period (500/503/504 below
/// [proxyErrorEscalationThreshold] consecutive failures -- see
/// [ProxyErrorToastListener] for the toast side of that case). Clears
/// automatically the moment the proxy answers with a real HTTP 200 (see
/// `UvApiFetchMeta.receivedNetwork200` in `uv_api.dart`), since that is what
/// [ProxyErrorNotifier.recordSuccess] resets [ProxyErrorState] on. This holds
/// even if [uvProvider] itself is still in an error state afterward (e.g.
/// the 200 body failed to parse), since a real 200 is evidence the proxy
/// itself has recovered.
///
/// Built on [MaterialBanner] embedded directly in the widget tree (same
/// pattern as `WeatherAlertBanner`), not shown via `ScaffoldMessenger`, so
/// it renders inline and pushes the rest of the dashboard down rather than
/// floating on top of it. Unlike `WeatherAlertBanner`, this banner has no
/// dismiss action: ADR 0010 calls these "persistent," and the state they
/// describe (proxy still failing) doesn't stop being true just because the
/// user closed the banner once.
class ProxyErrorBanner extends ConsumerWidget {
  /// Creates a [ProxyErrorBanner].
  const ProxyErrorBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProxyErrorState errorState = ref.watch(proxyErrorProvider);
    final String? message = _bannerMessageFor(errorState);

    if (message == null) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return MaterialBanner(
      backgroundColor: colors.errorContainer,
      leading: ExcludeSemantics(
        child: Icon(Icons.cloud_off, color: colors.onErrorContainer),
      ),
      content: Semantics(
        liveRegion: true,
        label: message,
        child: ExcludeSemantics(
          child: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onErrorContainer,
            ),
          ),
        ),
      ),
      actions: const <Widget>[SizedBox.shrink()],
    );
  }
}

/// Shows a one-time [SnackBar] toast on the first 500/503/504 failure,
/// before [proxyErrorEscalationThreshold] consecutive failures have
/// accumulated and [ProxyErrorBanner] takes over.
///
/// A [ConsumerWidget] alone can't drive a one-shot side effect like a toast
/// from provider state -- `ref.listen` (rather than `ref.watch`) is required
/// so the toast fires exactly once per *new* 1st-failure transition, not on
/// every rebuild while that state persists. This widget renders nothing
/// itself; wrap it around (or place it alongside) the dashboard content that
/// owns the [Scaffold] so `ScaffoldMessenger.of(context)` resolves.
class ProxyErrorToastListener extends ConsumerWidget {
  /// Creates a [ProxyErrorToastListener] wrapping [child].
  const ProxyErrorToastListener({required this.child, super.key});

  /// The widget below this one in the tree. Rendered unchanged; this widget
  /// only adds a `ref.listen` side effect.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ProxyErrorState>(proxyErrorProvider, (
      ProxyErrorState? _,
      ProxyErrorState next,
    ) {
      // Only the 1st failure (consecutiveFailures == 1) of the 500/503/504
      // streak shows a toast; the 2nd/3rd+ are silent until ProxyErrorBanner
      // takes over. lastStatusCode is only ever set to a threshold-gated
      // code by ProxyErrorNotifier.recordFailure, so a non-null value here
      // is always eligible; 429/502/400 never toast (they show their
      // persistent banner immediately via immediateStatusCode, per ADR
      // 0010).
      if (next.consecutiveFailures != 1 || next.lastStatusCode == null) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(proxyErrorTransientToastMessage)),
        );
    });

    return child;
  }
}
