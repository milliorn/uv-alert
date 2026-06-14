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
