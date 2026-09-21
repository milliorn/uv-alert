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

/// Stubs [mockCache]'s `isValid` to always return [value], for any
/// coordinates -- most tests here don't care which lat/lon was passed.
void _stubIsValid(MockCache mockCache, {required bool value}) {
  when(
    () => mockCache.isValid(
      lat: any(named: 'lat'),
      lon: any(named: 'lon'),
    ),
  ).thenReturn(value);
}

/// Stubs [mockCache]'s `store` to succeed as a no-op, for any data or
/// coordinates.
void _stubStoreSucceeds(MockCache mockCache) {
  when(
    () => mockCache.store(
      any(),
      lat: any(named: 'lat'),
      lon: any(named: 'lon'),
    ),
  ).thenAnswer((_) async {});
}

/// The invocation matcher for [mockCache]'s `store`, for `verify`/
/// `verifyNever` calls that don't care which data or coordinates were
/// passed.
Future<void> _storeInvocation(MockCache mockCache) => mockCache.store(
  any(),
  lat: any(named: 'lat'),
  lon: any(named: 'lon'),
);

/// The invocation matcher for [mockCache]'s `read`, for `when` setup that
/// doesn't care which coordinates were passed.
Future<UvData?> _readInvocation(MockCache mockCache) => mockCache.read(
  lat: any(named: 'lat'),
  lon: any(named: 'lon'),
);

void main() {
  late MockCache mockCache;

  setUpAll(() {
    registerFallbackValue(FakeUvData());
  });

  setUp(() {
    mockCache = MockCache();
  });

  tearDown(resetMocktailState);

  group('UvApi.fetch -- cache hit', () {
    test('returns cached data without making a network request', () async {
      final UvData cached = _makeData();
      _stubIsValid(mockCache, value: true);
      when(() => _readInvocation(mockCache)).thenAnswer((_) async => cached);

      final UvApi api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
      );

      final UvApiFetchMeta meta = UvApiFetchMeta();
      final UvData result = await api.fetch(
        lat: 40.7,
        lon: -74,
        uuid: 'uuid-1',
        appVersion: 'test-version',
        meta: meta,
      );

      expect(result.currentUvi, cached.currentUvi);
      expect(meta.wasFromCache, isTrue);
      verifyNever(() => _storeInvocation(mockCache));
    });

    test('recovers from corrupt cache: falls through to network '
        'when isValid but read() returns null', () async {
      _stubIsValid(mockCache, value: true);
      when(() => _readInvocation(mockCache)).thenAnswer((_) async => null);
      _stubStoreSucceeds(mockCache);

      final UvApi api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
        httpClient: mockClientReturning(200, jsonEncode(_apiJson())),
      );

      final UvApiFetchMeta meta = UvApiFetchMeta();
      final UvData result = await api.fetch(
        lat: 40.7,
        lon: -74,
        uuid: 'uuid-1',
        appVersion: 'test-version',
        meta: meta,
      );

      expect(result.currentUvi, 5.0);
      expect(meta.wasFromCache, isFalse);
      verify(() => _storeInvocation(mockCache)).called(1);
    });

    test('overlapping calls on the same UvApi keep separate meta outcomes '
        '(a slower network call is not clobbered by a faster concurrent '
        'cache hit)', () async {
      // First call: cache miss, slow network response held open until
      // released below.
      final Completer<http.Response> networkGate = Completer<http.Response>();
      bool cacheValidForSecondCallOnward = false;

      when(
        () => mockCache.isValid(
          lat: any(named: 'lat'),
          lon: any(named: 'lon'),
        ),
      ).thenAnswer((_) => cacheValidForSecondCallOnward);
      _stubStoreSucceeds(mockCache);

      final UvApi api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
        httpClient: MockClient((_) => networkGate.future),
      );

      final UvApiFetchMeta slowNetworkMeta = UvApiFetchMeta();
      final Future<UvData> slowNetworkFetch = api.fetch(
        lat: 40.7,
        lon: -74,
        uuid: 'uuid-1',
        appVersion: 'test-version',
        meta: slowNetworkMeta,
      );

      // Second call starts while the first is still awaiting the network
      // and completes via a cache hit before the first resolves.
      cacheValidForSecondCallOnward = true;
      final UvData cached = _makeData();
      when(() => _readInvocation(mockCache)).thenAnswer((_) async => cached);

      final UvApiFetchMeta cacheHitMeta = UvApiFetchMeta();
      final UvData cacheHitResult = await api.fetch(
        lat: 40.7,
        lon: -74,
        uuid: 'uuid-1',
        appVersion: 'test-version',
        meta: cacheHitMeta,
      );

      expect(cacheHitResult.currentUvi, cached.currentUvi);
      expect(cacheHitMeta.wasFromCache, isTrue);

      // Now release the first call's network response.
      networkGate.complete(http.Response(jsonEncode(_apiJson()), 200));
      final UvData networkResult = await slowNetworkFetch;

      expect(networkResult.currentUvi, 5.0);
      // The cache-hit call's meta must not have leaked into the slower
      // network call's own meta.
      expect(slowNetworkMeta.wasFromCache, isFalse);
    });
  });

  group('UvApi.fetch -- cache miss', () {
    setUp(() {
      _stubIsValid(mockCache, value: false);
      _stubStoreSucceeds(mockCache);
    });

    test('fetches from network and stores result in cache', () async {
      final UvApi api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
        httpClient: mockClientReturning(200, jsonEncode(_apiJson())),
      );

      final UvApiFetchMeta meta = UvApiFetchMeta();
      final UvData result = await api.fetch(
        lat: 40.7,
        lon: -74,
        uuid: 'uuid-1',
        appVersion: 'test-version',
        meta: meta,
      );

      expect(result.currentUvi, 5.0);
      expect(meta.wasFromCache, isFalse);
      expect(meta.receivedNetwork200, isTrue);
      verify(() => _storeInvocation(mockCache)).called(1);
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

      final UvApiFetchMeta meta = UvApiFetchMeta();
      await expectLater(
        () => api.fetch(
          lat: 40.7,
          lon: -74,
          uuid: 'uuid-1',
          appVersion: 'test-version',
          meta: meta,
        ),
        throwsA(
          isA<UvApiException>().having(
            (UvApiException e) => e.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
      expect(
        meta.receivedNetwork200,
        isFalse,
        reason: 'a non-200 response must not set receivedNetwork200',
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

    test('throws UvApiParseException on malformed JSON body', () async {
      final UvApi api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
        httpClient: MockClient((_) async => http.Response('not json', 200)),
      );

      final UvApiFetchMeta meta = UvApiFetchMeta();
      await expectLater(
        () => api.fetch(
          lat: 40.7,
          lon: -74,
          uuid: 'uuid-1',
          appVersion: 'test-version',
          meta: meta,
        ),
        throwsA(isA<UvApiParseException>()),
      );
      expect(
        meta.receivedNetwork200,
        isTrue,
        reason:
            'the proxy answered with a real 200 -- only the body failed '
            'to parse, so this must still be recorded as proxy health',
      );
    });

    test('receivedNetwork200 is true even when Cache.store throws after a '
        'real 200 and successful parse', () async {
      when(() => _storeInvocation(mockCache)).thenThrow(Exception('disk full'));

      final UvApi api = UvApi(
        cache: mockCache,
        proxyBaseUrl: 'http://example.com',
        httpClient: mockClientReturning(200, jsonEncode(_apiJson())),
      );

      final UvApiFetchMeta meta = UvApiFetchMeta();
      await expectLater(
        () => api.fetch(
          lat: 40.7,
          lon: -74,
          uuid: 'uuid-1',
          appVersion: 'test-version',
          meta: meta,
        ),
        throwsA(isA<Exception>()),
      );
      expect(
        meta.receivedNetwork200,
        isTrue,
        reason:
            'the proxy answered with a real 200 and the body parsed fine '
            '-- a later cache-write failure must not erase that fact',
      );
    });

    test('throws UvApiParseException when JSON is not an object', () async {
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
          throwsA(isA<UvApiParseException>()),
          reason: 'expected UvApiParseException for body: $body',
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

      // ignore: unnecessary_lambdas -- tear-off would invoke close() for real
      verifyNever(() => client.close());
    });
  });

  group('UvApiException', () {
    test('toString includes status code and body', () {
      final UvApiException e = UvApiException(404, 'not found');
      expect(e.toString(), contains('404'));
      expect(e.toString(), contains('not found'));
    });

    test('escalationStatusCode is the status code', () {
      final UvApiException e = UvApiException(500, 'server error');
      expect(e.escalationStatusCode, 500);
    });

    test('escalationStatusCode is null for a status code outside '
        'proxyEscalationStatusCodes (404)', () {
      final UvApiException e = UvApiException(404, 'not found');
      expect(e.escalationStatusCode, isNull);
    });
  });

  group('UvApiParseException', () {
    test('toString includes the body', () {
      final UvApiParseException e = UvApiParseException('parse error: bad');
      expect(e.toString(), contains('parse error: bad'));
    });

    test('escalationStatusCode is null', () {
      final UvApiParseException e = UvApiParseException('parse error: bad');
      expect(e.escalationStatusCode, isNull);
    });
  });

  group('UvApiForceUpdateException', () {
    test('escalationStatusCode is null', () {
      const UvApiForceUpdateException e = UvApiForceUpdateException();
      expect(e.escalationStatusCode, isNull);
    });
  });
}
