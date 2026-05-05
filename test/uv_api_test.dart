import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uvalert/api/uv_api.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/storage/cache.dart';

class MockCache extends Mock implements Cache {}

class _FakeUvData extends Fake implements UvData {}

UvData _makeData() => UvData(
  currentUvi: 5.0,
  sunrise: DateTime.utc(2023, 11, 14, 6),
  sunset: DateTime.utc(2023, 11, 14, 18),
  clouds: 0,
  hourly: [],
  daily: [],
  timezone: 'UTC',
  timezoneOffset: 0,
  fetchedAt: DateTime.utc(2023, 11, 14, 12),
);

Map<String, dynamic> _apiJson() => {
  'current': {
    'uvi': 5.0,
    'sunrise': 1699945200,
    'sunset': 1699988400,
    'clouds': 0,
  },
  'hourly': [],
  'daily': [],
  'timezone': 'UTC',
  'timezone_offset': 0,
  'fetched_at': '2023-11-14T12:00:00.000Z',
};

http.Client _clientReturning(int status, Map<String, dynamic> body) {
  return MockClient((_) async => http.Response(jsonEncode(body), status));
}

void main() {
  late MockCache mockCache;

  setUpAll(() {
    registerFallbackValue(_FakeUvData());
  });

  setUp(() {
    mockCache = MockCache();
  });

  group('UvApi.fetch — cache hit', () {
    test('returns cached data without making a network request', () async {
      final cached = _makeData();
      when(() => mockCache.isValid).thenReturn(true);
      when(() => mockCache.read()).thenReturn(cached);

      final api = UvApi(cache: mockCache, proxyBaseUrl: 'http://example.com');

      final result = await api.fetch(lat: 40.7, lon: -74.0, uuid: 'uuid-1');

      expect(result.currentUvi, cached.currentUvi);
      verifyNever(() => mockCache.store(any()));
    });
  });

  group('UvApi.fetch — cache miss', () {
    setUp(() {
      when(() => mockCache.isValid).thenReturn(false);
      when(() => mockCache.store(any())).thenAnswer((_) async {});
    });

    test('fetches from network and stores result in cache', () async {
      final api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
        httpClient: _clientReturning(200, _apiJson()),
      );

      final result = await api.fetch(lat: 40.7, lon: -74.0, uuid: 'uuid-1');

      expect(result.currentUvi, 5.0);
      verify(() => mockCache.store(any())).called(1);
    });

    test('throws UvApiException on non-200 response', () async {
      final api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
        httpClient: _clientReturning(500, {'error': 'server error'}),
      );

      await expectLater(
        () => api.fetch(lat: 40.7, lon: -74.0, uuid: 'uuid-1'),
        throwsA(
          isA<UvApiException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('throws UvApiException on malformed JSON body', () async {
      final api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
        httpClient: MockClient((_) async => http.Response('not json', 200)),
      );

      await expectLater(
        () => api.fetch(lat: 40.7, lon: -74.0, uuid: 'uuid-1'),
        throwsA(isA<UvApiException>()),
      );
    });

    test('sends correct lat/lon query parameters', () async {
      Uri? capturedUri;

      final api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
        httpClient: MockClient((request) async {
          capturedUri = request.url;
          return http.Response(jsonEncode(_apiJson()), 200);
        }),
      );

      await api.fetch(lat: 51.5, lon: -0.1, uuid: 'uuid-1');

      expect(capturedUri?.queryParameters['lat'], '51.5');
      expect(capturedUri?.queryParameters['lon'], '-0.1');
    });

    test('sends X-Device-ID header with uuid', () async {
      String? deviceId;

      final api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
        httpClient: MockClient((request) async {
          deviceId = request.headers['X-Device-ID'];
          return http.Response(jsonEncode(_apiJson()), 200);
        }),
      );

      await api.fetch(lat: 40.7, lon: -74.0, uuid: 'my-device-uuid');

      expect(deviceId, 'my-device-uuid');
    });
  });

  group('UvApiException', () {
    test('toString includes status code and body', () {
      final e = UvApiException(404, 'not found');
      expect(e.toString(), contains('404'));
      expect(e.toString(), contains('not found'));
    });
  });
}
