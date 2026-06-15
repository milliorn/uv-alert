import 'package:flutter/material.dart';

/// Milliseconds in one second.
const int msPerSecond = 1000;

/// Total number of onboarding steps shown in the progress indicator.
const int totalOnboardingSteps = 2;

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
