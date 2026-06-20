import 'dart:convert';

import 'package:catcher_2/model/platform_type.dart';
import 'package:catcher_2/model/report.dart';
import 'package:catcher_2/model/report_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uvalert/constants.dart';

// Allocated once; getSupportedPlatforms() is called on every crash dispatch.
const List<PlatformType> _allPlatforms = PlatformType.values;

/// Sends crash reports to the proxy's `/api/crash` endpoint so no email
/// address needs to be embedded in the app binary.
class CrashReportHandler extends ReportHandler {
  /// Creates a [CrashReportHandler].
  ///
  /// [proxyBaseUrl] is the base URL of the proxy; defaults to the compile-time
  /// [proxyBaseUrl] constant. Pass a custom value in tests to avoid hitting
  /// the real endpoint.
  ///
  /// [httpClient] is injected for testing; defaults to a real instance.
  CrashReportHandler({
    String proxyBaseUrl = proxyBaseUrl,
    Duration timeout = apiDefaultTimeout,
    http.Client? httpClient,
  }) : _timeout = timeout,
       _ownsClient = httpClient == null,
       _httpClient = httpClient ?? http.Client(),
       _crashUri = Uri.parse('${stripTrailingSlash(proxyBaseUrl)}/api/crash');

  final Duration _timeout;
  final http.Client _httpClient;
  final bool _ownsClient;
  final Uri _crashUri;

  /// Releases the underlying HTTP client if this instance owns it.
  void dispose() {
    if (_ownsClient) _httpClient.close();
  }

  @override
  List<PlatformType> getSupportedPlatforms() => _allPlatforms;

  @override
  Future<bool> handle(Report report, BuildContext? context) async {
    final Map<String, Object> body = <String, Object>{
      'error': report.error.toString(),
      if (report.stackTrace != null) 'stack': report.stackTrace.toString(),
      if (report.deviceParameters.isNotEmpty)
        'deviceInfo': report.deviceParameters,
      if (report.applicationParameters.isNotEmpty)
        'appInfo': report.applicationParameters,
    };

    try {
      final http.Response response = await _httpClient
          .post(
            _crashUri,
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      return response.statusCode == httpOk;
    } on Object catch (e) {
      if (kDebugMode) debugPrint('CrashReportHandler.handle: $e');
      return false;
    }
  }
}
