import 'dart:convert';

import 'package:catcher_2/model/platform_type.dart';
import 'package:catcher_2/model/report.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uvalert/api/crash_report_handler.dart';

import 'helpers.dart';

class _MockHttpClient extends Mock implements http.Client {}

// Builds a minimal Report with all required fields.
Report _makeReport({
  Object error = 'test error',
  StackTrace? stackTrace,
  Map<String, dynamic>? deviceParameters,
  Map<String, dynamic>? applicationParameters,
}) {
  return Report(
    error,
    stackTrace,
    DateTime.utc(2026),
    deviceParameters ?? <String, dynamic>{},
    applicationParameters ?? <String, dynamic>{},
    <String, dynamic>{},
    null,
    PlatformType.android,
    null,
  );
}

void main() {
  group('CrashReportHandler.handle', () {
    test('returns true on HTTP 200', () async {
      final CrashReportHandler handler = CrashReportHandler(
        proxyBaseUrl: 'http://example.com',
        httpClient: mockClientReturning(200),
      );

      final bool result = await handler.handle(_makeReport(), null);

      expect(result, isTrue);
    });

    test('returns false on non-200 response', () async {
      for (final int status in <int>[400, 404, 500, 503]) {
        final CrashReportHandler handler = CrashReportHandler(
          proxyBaseUrl: 'http://example.com',
          httpClient: mockClientReturning(status),
        );

        final bool result = await handler.handle(_makeReport(), null);

        expect(result, isFalse, reason: 'expected false for status $status');
      }
    });

    test('returns false on network exception', () async {
      final CrashReportHandler handler = CrashReportHandler(
        proxyBaseUrl: 'http://example.com',
        httpClient: MockClient((_) async => throw Exception('network error')),
      );

      final bool result = await handler.handle(_makeReport(), null);

      expect(result, isFalse);
    });

    test('posts error string in JSON body', () async {
      String? capturedBody;

      final CrashReportHandler handler = CrashReportHandler(
        proxyBaseUrl: 'http://example.com',
        httpClient: MockClient((http.Request request) async {
          capturedBody = request.body;
          return http.Response('', 200);
        }),
      );

      await handler.handle(_makeReport(error: 'boom'), null);

      final Map<String, dynamic> body =
          jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body['error'], 'boom');
    });

    test('includes stack trace when present', () async {
      String? capturedBody;
      final StackTrace stack = StackTrace.current;

      final CrashReportHandler handler = CrashReportHandler(
        proxyBaseUrl: 'http://example.com',
        httpClient: MockClient((http.Request request) async {
          capturedBody = request.body;
          return http.Response('', 200);
        }),
      );

      await handler.handle(_makeReport(stackTrace: stack), null);

      final Map<String, dynamic> body =
          jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body.containsKey('stack'), isTrue);
    });

    test('omits stack key when stackTrace is null', () async {
      String? capturedBody;

      final CrashReportHandler handler = CrashReportHandler(
        proxyBaseUrl: 'http://example.com',
        httpClient: MockClient((http.Request request) async {
          capturedBody = request.body;
          return http.Response('', 200);
        }),
      );

      await handler.handle(_makeReport(), null);

      final Map<String, dynamic> body =
          jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body.containsKey('stack'), isFalse);
    });

    test('includes deviceInfo when deviceParameters is non-empty', () async {
      String? capturedBody;

      final CrashReportHandler handler = CrashReportHandler(
        proxyBaseUrl: 'http://example.com',
        httpClient: MockClient((http.Request request) async {
          capturedBody = request.body;
          return http.Response('', 200);
        }),
      );

      await handler.handle(
        _makeReport(deviceParameters: <String, dynamic>{'os': 'Android'}),
        null,
      );

      final Map<String, dynamic> body =
          jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body['deviceInfo'], <String, dynamic>{'os': 'Android'});
    });

    test('omits deviceInfo when deviceParameters is empty', () async {
      String? capturedBody;

      final CrashReportHandler handler = CrashReportHandler(
        proxyBaseUrl: 'http://example.com',
        httpClient: MockClient((http.Request request) async {
          capturedBody = request.body;
          return http.Response('', 200);
        }),
      );

      await handler.handle(_makeReport(), null);

      final Map<String, dynamic> body =
          jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body.containsKey('deviceInfo'), isFalse);
    });

    test('includes appInfo when applicationParameters is non-empty', () async {
      String? capturedBody;

      final CrashReportHandler handler = CrashReportHandler(
        proxyBaseUrl: 'http://example.com',
        httpClient: MockClient((http.Request request) async {
          capturedBody = request.body;
          return http.Response('', 200);
        }),
      );

      await handler.handle(
        _makeReport(
          applicationParameters: <String, dynamic>{'version': '1.0.0'},
        ),
        null,
      );

      final Map<String, dynamic> body =
          jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body['appInfo'], <String, dynamic>{'version': '1.0.0'});
    });

    test('omits appInfo when applicationParameters is empty', () async {
      String? capturedBody;

      final CrashReportHandler handler = CrashReportHandler(
        proxyBaseUrl: 'http://example.com',
        httpClient: MockClient((http.Request request) async {
          capturedBody = request.body;
          return http.Response('', 200);
        }),
      );

      await handler.handle(_makeReport(), null);

      final Map<String, dynamic> body =
          jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body.containsKey('appInfo'), isFalse);
    });

    test('posts to /api/crash path', () async {
      Uri? capturedUri;

      final CrashReportHandler handler = CrashReportHandler(
        proxyBaseUrl: 'http://example.com',
        httpClient: MockClient((http.Request request) async {
          capturedUri = request.url;
          return http.Response('', 200);
        }),
      );

      await handler.handle(_makeReport(), null);

      expect(capturedUri?.path, '/api/crash');
    });

    test('strips trailing slash from proxyBaseUrl', () async {
      Uri? capturedUri;

      final CrashReportHandler handler = CrashReportHandler(
        proxyBaseUrl: 'http://example.com/',
        httpClient: MockClient((http.Request request) async {
          capturedUri = request.url;
          return http.Response('', 200);
        }),
      );

      await handler.handle(_makeReport(), null);

      expect(capturedUri?.path, '/api/crash');
    });

    test('sets Content-Type to application/json', () async {
      String? contentType;

      final CrashReportHandler handler = CrashReportHandler(
        proxyBaseUrl: 'http://example.com',
        httpClient: MockClient((http.Request request) async {
          contentType = request.headers['Content-Type'];
          return http.Response('', 200);
        }),
      );

      await handler.handle(_makeReport(), null);

      expect(contentType, 'application/json');
    });
  });

  group('CrashReportHandler.getSupportedPlatforms', () {
    test('returns all platform types', () {
      final CrashReportHandler handler = CrashReportHandler(
        proxyBaseUrl: 'http://example.com',
        httpClient: mockClientReturning(200),
      );

      expect(handler.getSupportedPlatforms(), containsAll(PlatformType.values));
    });
  });

  group('CrashReportHandler.dispose', () {
    test('completes without error when handler owns the client', () {
      final CrashReportHandler handler = CrashReportHandler(
        proxyBaseUrl: 'http://example.com',
      );

      expect(handler.dispose, returnsNormally);
    });

    test('does not close the client when handler does not own it', () {
      final _MockHttpClient client = _MockHttpClient();

      CrashReportHandler(
        proxyBaseUrl: 'http://example.com',
        httpClient: client,
      ).dispose();

      verifyNever(client.close);
    });
  });
}
