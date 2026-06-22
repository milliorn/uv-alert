import 'package:flutter/material.dart';

/// Milliseconds in one second.
const int msPerSecond = 1000;

/// Total number of onboarding steps shown in the progress indicator.
const int totalOnboardingSteps = 3;

/// Brand periwinkle drawn from the logo's actual color (#9498ED).
const Color logoPurple = Color(0xFF9498ED);

/// Base URL of the UV proxy API.
const String proxyBaseUrl = String.fromEnvironment('PROXY_BASE_URL');

/// HTTP header name used to identify the device to the proxy API.
const String deviceIdHeader = 'X-Device-ID';

/// Default HTTP request timeout for all API clients.
const Duration apiDefaultTimeout = Duration(seconds: 10);

/// HTTP 200 OK status code.
const int httpOk = 200;

/// HTTP 404 Not Found status code.
const int httpNotFound = 404;

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
