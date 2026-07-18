import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uvalert/api/uv_api.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/storage/cache.dart';

import 'fakes/fake_uv_data.dart';
import 'helpers.dart';

class MockCache extends Mock implements Cache {}

// Used only in the dispose group to verify close() is never called on
// externally-owned clients; MockClient suffices everywhere else.
class MockHttpClient extends Mock implements http.Client {}

UvData _makeData() => makeUvData(
  sunrise: DateTime.utc(2023, 11, 14, 6),
  sunset: DateTime.utc(2023, 11, 14, 18),
  fetchedAt: DateTime.utc(2023, 11, 14, 12),
);

Map<String, Object?> _apiJson() => <String, Object?>{
  'current': <String, num>{
    'uvi': 5.0,
    'sunrise': 1699945200,
    'sunset': 1699988400,
    'clouds': 0,
  },
  'hourly': <Map<String, Object?>>[],
  'daily': <Map<String, Object?>>[],
  'timezone': 'UTC',
  'timezone_offset': 0,
  'fetched_at': 1699963200,
};

void main() {
  late MockCache mockCache;

  setUpAll(() {
    registerFallbackValue(FakeUvData());
  });

  setUp(() {
    mockCache = MockCache();
  });

  tearDown(resetMocktailState);

  group('UvApi.fetch — cache hit', () {
    test('returns cached data without making a network request', () async {
      final UvData cached = _makeData();
      when(() => mockCache.isValid).thenReturn(true);
      when(() => mockCache.read()).thenAnswer((_) async => cached);

      final UvApi api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
      );

      final UvData result = await api.fetch(
        lat: 40.7,
        lon: -74,
        uuid: 'uuid-1',
        appVersion: 'test-version',
      );

      expect(result.currentUvi, cached.currentUvi);
      verifyNever(() => mockCache.store(any()));
    });

    test('recovers from corrupt cache: falls through to network '
        'when isValid but read() returns null', () async {
      when(() => mockCache.isValid).thenReturn(true);
      when(() => mockCache.read()).thenAnswer((_) async => null);
      when(() => mockCache.store(any())).thenAnswer((_) async {});

      final UvApi api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
        httpClient: mockClientReturning(200, jsonEncode(_apiJson())),
      );

      final UvData result = await api.fetch(
        lat: 40.7,
        lon: -74,
        uuid: 'uuid-1',
        appVersion: 'test-version',
      );

      expect(result.currentUvi, 5.0);
      verify(() => mockCache.store(any())).called(1);
    });
  });

  group('UvApi.fetch — cache miss', () {
    setUp(() {
      when(() => mockCache.isValid).thenReturn(false);
      when(() => mockCache.store(any())).thenAnswer((_) async {});
    });

    test('fetches from network and stores result in cache', () async {
      final UvApi api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
        httpClient: mockClientReturning(200, jsonEncode(_apiJson())),
      );

      final UvData result = await api.fetch(
        lat: 40.7,
        lon: -74,
        uuid: 'uuid-1',
        appVersion: 'test-version',
      );

      expect(result.currentUvi, 5.0);
      verify(() => mockCache.store(any())).called(1);
    });

    test('throws UvApiException on non-200 response', () async {
      final UvApi api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
        httpClient: mockClientReturning(
          500,
          jsonEncode(<String, Object?>{'error': 'server error'}),
        ),
      );

      await expectLater(
        () => api.fetch(
          lat: 40.7,
          lon: -74,
          uuid: 'uuid-1',
          appVersion: 'test-version',
        ),
        throwsA(
          isA<UvApiException>().having(
            (UvApiException e) => e.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
    });

    test('throws UvApiForceUpdateException on 426 response', () async {
      final UvApi api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
        httpClient: mockClientReturning(
          426,
          jsonEncode(<String, Object?>{'error': 'upgrade_required'}),
        ),
      );

      await expectLater(
        () =>
            api.fetch(lat: 40.7, lon: -74, uuid: 'uuid-1', appVersion: '0.1.0'),
        throwsA(isA<UvApiForceUpdateException>()),
      );
    });

    test('throws UvApiException on malformed JSON body', () async {
      final UvApi api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
        httpClient: MockClient((_) async => http.Response('not json', 200)),
      );

      await expectLater(
        () => api.fetch(
          lat: 40.7,
          lon: -74,
          uuid: 'uuid-1',
          appVersion: 'test-version',
        ),
        throwsA(isA<UvApiException>()),
      );
    });

    test('throws UvApiException when JSON is not an object', () async {
      for (final String body in <String>['[1,2,3]', '"a string"', '42']) {
        final UvApi api = UvApi(
          cache: mockCache,
          proxyBaseUrl: 'http://example.com',
          httpClient: MockClient((_) async => http.Response(body, 200)),
        );

        await expectLater(
          () => api.fetch(
            lat: 40.7,
            lon: -74,
            uuid: 'uuid-1',
            appVersion: 'test-version',
          ),
          throwsA(isA<UvApiException>()),
          reason: 'expected UvApiException for body: $body',
        );
      }
    });

    test('sends correct lat/lon query parameters', () async {
      Uri? capturedUri;

      final UvApi api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
        httpClient: MockClient((http.Request request) async {
          capturedUri = request.url;
          return http.Response(jsonEncode(_apiJson()), 200);
        }),
      );

      await api.fetch(
        lat: 51.5,
        lon: -0.1,
        uuid: 'uuid-1',
        appVersion: 'test-version',
      );

      expect(capturedUri?.queryParameters['lat'], '51.5');
      expect(capturedUri?.queryParameters['lon'], '-0.1');
    });

    test('strips trailing slash from proxyBaseUrl', () async {
      Uri? capturedUri;

      final UvApi api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com/',
        httpClient: MockClient((http.Request request) async {
          capturedUri = request.url;
          return http.Response(jsonEncode(_apiJson()), 200);
        }),
      );

      await api.fetch(
        lat: 40.7,
        lon: -74,
        uuid: 'uuid-1',
        appVersion: 'test-version',
      );

      expect(capturedUri?.path, '/api/uv');
    });

    test('sends X-Device-ID header with uuid', () async {
      String? deviceId;

      final UvApi api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
        httpClient: MockClient((http.Request request) async {
          deviceId = request.headers['X-Device-ID'];
          return http.Response(jsonEncode(_apiJson()), 200);
        }),
      );

      await api.fetch(
        lat: 40.7,
        lon: -74,
        uuid: 'my-device-uuid',
        appVersion: 'test-version',
      );

      expect(deviceId, 'my-device-uuid');
    });

    test('sends app_version query parameter with appVersion', () async {
      Uri? capturedUri;

      final UvApi api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
        httpClient: MockClient((http.Request request) async {
          capturedUri = request.url;
          return http.Response(jsonEncode(_apiJson()), 200);
        }),
      );

      await api.fetch(lat: 40.7, lon: -74, uuid: 'uuid-1', appVersion: '1.2.3');

      expect(capturedUri?.queryParameters['app_version'], '1.2.3');
    });

    test('propagates TimeoutException when request exceeds timeout', () async {
      final UvApi api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
        timeout: const Duration(milliseconds: 1),
        httpClient: MockClient((_) => Completer<http.Response>().future),
      );

      await expectLater(
        () => api.fetch(
          lat: 40.7,
          lon: -74,
          uuid: 'uuid-1',
          appVersion: 'test-version',
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });

  group('UvApi.dispose', () {
    test('completes without error when UvApi owns the client', () {
      // httpClient omitted → _ownsClient = true; dispose() calls close() on
      // the internally created client. We can't intercept that client, so we
      // just confirm dispose() does not throw.
      final UvApi api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
      );

      expect(api.dispose, returnsNormally);
    });

    test('does not close the client when UvApi does not own it', () {
      final MockHttpClient client = MockHttpClient();

      UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
        httpClient: client,
      ).dispose();

      // ignore: unnecessary_lambdas — tear-off would invoke close() for real
      verifyNever(() => client.close());
    });
  });

  group('UvApiException', () {
    test('toString includes status code and body', () {
      final UvApiException e = UvApiException(404, 'not found');
      expect(e.toString(), contains('404'));
      expect(e.toString(), contains('not found'));
    });
  });
}
