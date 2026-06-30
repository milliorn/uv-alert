import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uvalert/api/geocoding_api.dart';
import 'package:uvalert/constants.dart';

import 'helpers.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

GeocodingApi _makeApi(http.Client client) => GeocodingApi(
  proxyBaseUrl: 'https://proxy.test',
  deviceId: 'test-device-id',
  httpClient: client,
);

// Proxy response shape: array of { lat, lon, name, country, state? }
const String _validBodyWithState =
    '[{"lat":36.75,"lon":-119.65,'
    '"name":"Fresno","country":"US","state":"California"}]';

const String _validBodyNoState =
    '[{"lat":48.85,"lon":2.35,"name":"Paris","country":"FR"}]';

const String _validBodyMultiple =
    '[{"lat":51.5,"lon":-0.1,"name":"London",'
    '"country":"GB","state":"England"},'
    '{"lat":42.9,"lon":-81.2,"name":"London",'
    '"country":"CA","state":"Ontario"}]';

const String _validArrayMultiple =
    '[{"lat":34.06,"lon":-117.64,"name":"Ontario",'
    '"country":"US","state":"California"},'
    '{"lat":44.02,"lon":-116.96,"name":"Ontario",'
    '"country":"US","state":"Oregon"}]';

// reverseGeocode uses a single-object response (separate OWM endpoint).
const String _reverseBodyWithState =
    '{"lat":36.75,"lon":-119.65,'
    '"name":"Fresno","country":"US","state":"California"}';

// ---------------------------------------------------------------------------
// geocodeMultiple
// ---------------------------------------------------------------------------

void main() {
  group('GeocodingApi.geocodeMultiple', () {
    test('returns single result on 200 with state field', () async {
      final GeocodingApi api = _makeApi(
        mockClientReturning(200, _validBodyWithState),
      );
      addTearDown(api.dispose);
      final List<GeocodingResult> results = await api.geocodeMultiple(
        'Fresno, CA',
      );

      expect(results, hasLength(1));
      expect(results.first.lat, 36.75);
      expect(results.first.lon, -119.65);
      expect(results.first.displayName, 'Fresno, California, US');
    });

    test('returns single result on 200 without state field', () async {
      final GeocodingApi api = _makeApi(
        mockClientReturning(200, _validBodyNoState),
      );
      addTearDown(api.dispose);
      final List<GeocodingResult> results = await api.geocodeMultiple('Paris');

      expect(results, hasLength(1));
      expect(results.first.lat, 48.85);
      expect(results.first.lon, 2.35);
      expect(results.first.displayName, 'Paris, FR');
    });

    test(
      'returns multiple results when proxy returns several matches',
      () async {
        final GeocodingApi api = _makeApi(
          mockClientReturning(200, _validBodyMultiple),
        );
        addTearDown(api.dispose);
        final List<GeocodingResult> results = await api.geocodeMultiple(
          'London',
        );

        expect(results, hasLength(2));
        expect(results[0].displayName, 'London, England, GB');
        expect(results[1].displayName, 'London, Ontario, CA');
      },
    );

    test('returns multiple results (Ontario)', () async {
      final GeocodingApi api = _makeApi(
        mockClientReturning(200, _validArrayMultiple),
      );
      addTearDown(api.dispose);
      final List<GeocodingResult> results = await api.geocodeMultiple(
        'Ontario',
      );

      expect(results, hasLength(2));
      expect(results[0].displayName, 'Ontario, California, US');
      expect(results[1].displayName, 'Ontario, Oregon, US');
    });

    test('throws GeocodingNotFoundException on 404', () async {
      final GeocodingApi api = _makeApi(mockClientReturning(404, 'not found'));
      addTearDown(api.dispose);

      await expectLater(
        api.geocodeMultiple('nowhere'),
        throwsA(isA<GeocodingNotFoundException>()),
      );
    });

    test('throws GeocodingNotFoundException when array is empty', () async {
      final GeocodingApi api = _makeApi(mockClientReturning(200, '[]'));
      addTearDown(api.dispose);

      await expectLater(
        api.geocodeMultiple('Fresno, CA'),
        throwsA(isA<GeocodingNotFoundException>()),
      );
    });

    test('throws GeocodingException on 500', () async {
      final GeocodingApi api = _makeApi(mockClientReturning(500, 'error'));
      addTearDown(api.dispose);

      await expectLater(
        api.geocodeMultiple('Fresno, CA'),
        throwsA(isA<GeocodingException>()),
      );
    });

    test('throws GeocodingException when body is not a JSON array', () async {
      final GeocodingApi api = _makeApi(mockClientReturning(200, '"string"'));
      addTearDown(api.dispose);

      await expectLater(
        api.geocodeMultiple('Fresno, CA'),
        throwsA(isA<GeocodingException>()),
      );
    });

    test('throws GeocodingException on malformed JSON body', () async {
      final GeocodingApi api = _makeApi(mockClientReturning(200, '{not json}'));
      addTearDown(api.dispose);

      await expectLater(
        api.geocodeMultiple('Fresno, CA'),
        throwsA(isA<GeocodingException>()),
      );
    });

    test('sends query as q parameter', () async {
      Uri? captured;
      final MockClient client = MockClient((http.Request req) async {
        captured = req.url;
        return http.Response(_validBodyWithState, 200);
      });

      final GeocodingApi api = _makeApi(client);
      addTearDown(api.dispose);
      await api.geocodeMultiple('Fresno, CA');

      expect(captured?.queryParameters['q'], 'Fresno, CA');
    });

    test('sends X-Device-ID header', () async {
      Map<String, String>? capturedHeaders;
      final MockClient client = MockClient((http.Request req) async {
        capturedHeaders = req.headers;
        return http.Response(_validBodyWithState, 200);
      });

      final GeocodingApi api = _makeApi(client);
      addTearDown(api.dispose);
      await api.geocodeMultiple('Fresno, CA');

      expect(capturedHeaders?[deviceIdHeader], 'test-device-id');
    });

    test('strips trailing slash from proxyBaseUrl', () async {
      Uri? captured;
      final MockClient client = MockClient((http.Request req) async {
        captured = req.url;
        return http.Response(_validBodyWithState, 200);
      });

      final GeocodingApi api = GeocodingApi(
        proxyBaseUrl: 'https://proxy.test/',
        deviceId: 'test-device-id',
        httpClient: client,
      );
      addTearDown(api.dispose);
      await api.geocodeMultiple('Fresno, CA');

      expect(captured?.host, 'proxy.test');
      expect(captured?.path, '/api/geocode');
    });
  });

  // -------------------------------------------------------------------------
  // reverseGeocode
  // -------------------------------------------------------------------------

  group('GeocodingApi.reverseGeocode', () {
    test('returns result on 200 with state field', () async {
      final GeocodingApi api = _makeApi(
        mockClientReturning(200, _reverseBodyWithState),
      );
      addTearDown(api.dispose);
      final GeocodingResult result = await api.reverseGeocode(
        lat: 36.75,
        lon: -119.65,
      );

      expect(result.lat, 36.75);
      expect(result.lon, -119.65);
      expect(result.displayName, 'Fresno, California, US');
    });

    test('throws GeocodingNotFoundException on 404', () async {
      final GeocodingApi api = _makeApi(mockClientReturning(404, 'not found'));
      addTearDown(api.dispose);

      await expectLater(
        api.reverseGeocode(lat: 36.75, lon: -119.65),
        throwsA(isA<GeocodingNotFoundException>()),
      );
    });

    test('sends lat and lon as separate query parameters', () async {
      Uri? captured;
      final MockClient client = MockClient((http.Request req) async {
        captured = req.url;
        return http.Response(_reverseBodyWithState, 200);
      });

      final GeocodingApi api = _makeApi(client);
      addTearDown(api.dispose);
      await api.reverseGeocode(lat: 36.75, lon: -119.65);

      expect(captured?.queryParameters['lat'], '36.75');
      expect(captured?.queryParameters['lon'], '-119.65');
      expect(captured?.queryParameters['q'], isNull);
    });

    test('sends X-Device-ID header', () async {
      Map<String, String>? capturedHeaders;
      final MockClient client = MockClient((http.Request req) async {
        capturedHeaders = req.headers;
        return http.Response(_reverseBodyWithState, 200);
      });

      final GeocodingApi api = _makeApi(client);
      addTearDown(api.dispose);
      await api.reverseGeocode(lat: 36.75, lon: -119.65);

      expect(capturedHeaders?[deviceIdHeader], 'test-device-id');
    });

    test('throws GeocodingException on non-200/404 status', () async {
      final GeocodingApi api = _makeApi(
        mockClientReturning(500, 'server error'),
      );
      addTearDown(api.dispose);

      await expectLater(
        api.reverseGeocode(lat: 36.75, lon: -119.65),
        throwsA(isA<GeocodingException>()),
      );
    });

    test('throws GeocodingException when body is not a JSON object', () async {
      final GeocodingApi api = _makeApi(mockClientReturning(200, '"string"'));
      addTearDown(api.dispose);

      await expectLater(
        api.reverseGeocode(lat: 36.75, lon: -119.65),
        throwsA(isA<GeocodingException>()),
      );
    });

    test(
      'throws GeocodingException when required fields are missing',
      () async {
        final GeocodingApi api = _makeApi(
          mockClientReturning(200, '{"lat":36.75,"lon":-119.65}'),
        );
        addTearDown(api.dispose);

        await expectLater(
          api.reverseGeocode(lat: 36.75, lon: -119.65),
          throwsA(isA<GeocodingException>()),
        );
      },
    );

    test('throws GeocodingException on malformed JSON body', () async {
      final GeocodingApi api = _makeApi(mockClientReturning(200, '{not json}'));
      addTearDown(api.dispose);

      await expectLater(
        api.reverseGeocode(lat: 36.75, lon: -119.65),
        throwsA(isA<GeocodingException>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // GeocodingException.toString
  // -------------------------------------------------------------------------

  test('GeocodingException.toString includes status and body', () {
    final GeocodingException ex = GeocodingException(500, 'boom');
    expect(ex.toString(), contains('500'));
    expect(ex.toString(), contains('boom'));
  });

  // -------------------------------------------------------------------------
  // dispose - owned client path
  // -------------------------------------------------------------------------

  test('dispose does not throw when api owns its client', () {
    final GeocodingApi api = GeocodingApi(
      proxyBaseUrl: 'https://proxy.test',
      deviceId: 'test-device-id',
    );
    expect(api.dispose, returnsNormally);
  });
}
