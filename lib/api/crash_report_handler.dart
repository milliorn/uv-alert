import 'dart:convert';

import 'package:catcher_2/model/platform_type.dart';
import 'package:catcher_2/model/report.dart';
import 'package:catcher_2/model/report_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uvalert/constants.dart';

/// Sends crash reports to the proxy's `/api/crash` endpoint so no email
/// address needs to be embedded in the app binary.
class CrashReportHandler extends ReportHandler {
  /// Creates a [CrashReportHandler].
  ///
  /// [httpClient] is injected for testing; defaults to a real instance.
  CrashReportHandler({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  @override
  List<PlatformType> getSupportedPlatforms() => PlatformType.values.toList();

  @override
  Future<bool> handle(Report report, BuildContext? context) async {
    final Uri uri = Uri.parse('$proxyBaseUrl/api/crash');

    final Map<String, Object> body = <String, Object>{
      'error': report.error.toString(),
      if (report.stackTrace != null)
        'stack': report.stackTrace.toString(),
      if (report.deviceParameters.isNotEmpty)
        'deviceInfo': report.deviceParameters,
      if (report.applicationParameters.isNotEmpty)
        'appInfo': report.applicationParameters,
    };

    try {
      final http.Response response = await _httpClient.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      return response.statusCode == 200;
    } on Object catch (e) {
      if (kDebugMode) debugPrint('CrashReportHandler.handle: $e');
      return false;
    }
  }
}
