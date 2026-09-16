import 'package:flutter/material.dart';

/// Milliseconds in one second.
const int msPerSecond = 1000;

/// Total number of onboarding steps shown in the progress indicator.
const int totalOnboardingSteps = 3;

/// Brand periwinkle drawn from the logo's actual color (#9498ED).
const Color logoPurple = Color(0xFF9498ED);

/// Base URL of the UV proxy API.
const String proxyBaseUrl = String.fromEnvironment('PROXY_BASE_URL');

/// URL of the uv-alert GitHub repository.
const String githubRepoUrl = 'https://github.com/milliorn/uv-alert';

/// HTTP header name used to identify the device to the proxy API.
const String deviceIdHeader = 'X-Device-ID';

/// Default HTTP request timeout for all API clients.
const Duration apiDefaultTimeout = Duration(seconds: 10);

/// Timeout for GPS hardware acquisition.
///
/// Separate from [apiDefaultTimeout] because GPS cold-start can legitimately
/// take longer than a network roundtrip (weak signal, first fix indoors).
const Duration gpsTimeout = Duration(seconds: 30);

/// HTTP 200 OK status code.
const int httpOk = 200;

/// HTTP 404 Not Found status code.
const int httpNotFound = 404;

/// HTTP 400 Bad Request status code.
///
/// See `docs/adr/0010-proxy-error-code-contract.md`.
const int httpBadRequest = 400;

/// HTTP 426 Upgrade Required status code.
///
/// See `docs/adr/0009-force-update-via-426.md`.
const int httpUpgradeRequired = 426;

/// HTTP 429 Too Many Requests status code (proxy abuse detection).
///
/// See `docs/adr/0010-proxy-error-code-contract.md`.
const int httpTooManyRequests = 429;

/// HTTP 500 Internal Server Error status code (unhandled proxy error).
///
/// See `docs/adr/0010-proxy-error-code-contract.md`.
const int httpInternalServerError = 500;

/// HTTP 502 Bad Gateway status code (OWM key invalid/expired).
///
/// See `docs/adr/0010-proxy-error-code-contract.md`.
const int httpBadGateway = 502;

/// HTTP 503 Service Unavailable status code (OWM unreachable/rate capped).
///
/// See `docs/adr/0010-proxy-error-code-contract.md`.
const int httpServiceUnavailable = 503;

/// HTTP 504 Gateway Timeout status code (OWM timeout).
///
/// See `docs/adr/0010-proxy-error-code-contract.md`.
const int httpGatewayTimeout = 504;

/// Status codes ADR 0010 calls for an immediate persistent banner on the 1st
/// occurrence, shown until `ProxyErrorNotifier.recordSuccess` (in
/// `uv_provider.dart`): waiting for a streak (as the 500/503/504 threshold
/// does) would add no value here, since each of these three has its own
/// reason to show up front instead. 400 and 502 cannot self-heal via retry
/// (a bad request stays bad; an invalid OWM key needs operator action); 429
/// can self-heal, but only by the user waiting, which the banner itself
/// already communicates ("try again later"), not by a silent retry streak.
const Set<int> proxyImmediateStatusCodes = <int>{
  httpBadRequest,
  httpTooManyRequests,
  httpBadGateway,
};

/// Status codes ADR 0010 gates behind
/// `proxyErrorEscalationThreshold` consecutive failures (see
/// `proxy_error_banner.dart`) before showing a persistent banner; before
/// that threshold, a one-time toast is shown instead.
const Set<int> proxyThresholdGatedStatusCodes = <int>{
  httpInternalServerError,
  httpServiceUnavailable,
  httpGatewayTimeout,
};

/// Union of [proxyImmediateStatusCodes] and [proxyThresholdGatedStatusCodes]:
/// every status code ADR 0010 defines escalation UX for.
/// `ProxyErrorNotifier.recordFailure` (in `uv_provider.dart`) uses this to
/// decide whether a failure is recorded at all, so a status code not in this
/// set (e.g. 404, which ADR 0010 assigns its own "geocoding no results" UX,
/// not this escalation path) can never silently consume state while
/// producing no user-visible feedback.
const Set<int> proxyEscalationStatusCodes = <int>{
  ...proxyImmediateStatusCodes,
  ...proxyThresholdGatedStatusCodes,
};

/// Strips a trailing slash from [url] if present.
String stripTrailingSlash(String url) =>
    url.endsWith('/') ? url.substring(0, url.length - 1) : url;

// ---------------------------------------------------------------------------
// Shared onboarding layout constants
// ---------------------------------------------------------------------------

/// Horizontal screen padding used across all onboarding screens.
const double onboardingPaddingHorizontal = 24;

/// Vertical screen padding used across all onboarding screens.
const double onboardingPaddingVertical = 32;

/// Card corner radius used across all onboarding screens.
const double onboardingCardBorderRadius = 12;

/// Card horizontal padding used across all onboarding screens.
const double onboardingCardPaddingHorizontal = 20;

/// Card vertical padding used across all onboarding screens.
const double onboardingCardPaddingVertical = 16;

/// Border width for a selected card on onboarding screens.
const double onboardingSelectedBorderWidth = 2;

/// Background fill opacity for a selected card on onboarding screens.
const double onboardingSelectedCardOpacity = 0.08;

/// Gap between major sections within an onboarding screen.
const double onboardingSectionGap = 24;

/// Gap between items within an onboarding card or section.
const double onboardingItemGap = 12;

/// Gap between a card's label and its description line.
const double onboardingLabelGap = 4;

/// Maximum fraction of screen height the pick-list candidate scroll area
/// may occupy.
const double onboardingPickListMaxHeightFraction = 0.35;

/// Card corner radius used across all onboarding screens.
///
/// Derived from [onboardingCardBorderRadius].
const BorderRadius onboardingCardRadius = BorderRadius.all(
  Radius.circular(onboardingCardBorderRadius),
);
