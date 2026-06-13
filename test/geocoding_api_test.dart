import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uvalert/api/geocoding_api.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

GeocodingApi _makeApi(MockClient client) => GeocodingApi(
  proxyBaseUrl: 'https://proxy.test',
  deviceId: 'test-device-id',
  httpClient: client,
);

MockClient _respondWith(int status, String body) =>
    MockClient((_) async => http.Response(body, status));

// Proxy response shape: { lat, lon, name, country, state? }
const String _validBodyWithState =
    '{"lat":36.75,"lon":-119.65,'
    '"name":"Fresno","country":"US","state":"California"}';

const String _validBodyNoState =
    '{"lat":48.85,"lon":2.35,"name":"Paris","country":"FR"}';

// ---------------------------------------------------------------------------
// geocode
// ---------------------------------------------------------------------------

void main() {
  group('GeocodingApi.geocode', () {
    test('returns result on 200 with state field', () async {
      final GeocodingApi api = _makeApi(_respondWith(200, _validBodyWithState));
      final GeocodingResult result = await api.geocode('Fresno, CA');

      expect(result.lat, 36.75);
      expect(result.lon, -119.65);
      expect(result.displayName, 'Fresno, California, US');

      api.dispose();
    });

    test('returns result on 200 without state field', () async {
      final GeocodingApi api = _makeApi(_respondWith(200, _validBodyNoState));
      final GeocodingResult result = await api.geocode('Paris');

      expect(result.lat, 48.85);
      expect(result.lon, 2.35);
      expect(result.displayName, 'Paris, FR');

      api.dispose();
    });

    test('throws GeocodingNotFoundException on 404', () async {
      final GeocodingApi api = _makeApi(_respondWith(404, 'not found'));

      await expectLater(
        api.geocode('nowhere'),
        throwsA(isA<GeocodingNotFoundException>()),
      );

      api.dispose();
    });

    test('throws GeocodingException on 500', () async {
      final GeocodingApi api = _makeApi(_respondWith(500, 'error'));

      await expectLater(
        api.geocode('Fresno, CA'),
        throwsA(isA<GeocodingException>()),
      );

      api.dispose();
    });

    test('throws GeocodingException when body is not a JSON object', () async {
      final GeocodingApi api = _makeApi(_respondWith(200, '"string"'));

      await expectLater(
        api.geocode('Fresno, CA'),
        throwsA(isA<GeocodingException>()),
      );

      api.dispose();
    });

    test(
      'throws GeocodingException when required fields are missing',
      () async {
        final GeocodingApi api = _makeApi(_respondWith(200, '{"lat":36.75}'));

        await expectLater(
          api.geocode('Fresno, CA'),
          throwsA(isA<GeocodingException>()),
        );

        api.dispose();
      },
    );

    test('sends query as q parameter', () async {
      Uri? captured;
      final MockClient client = MockClient((http.Request req) async {
        captured = req.url;
        return http.Response(_validBodyWithState, 200);
      });

      final GeocodingApi api = _makeApi(client);
      await api.geocode('Fresno, CA');

      expect(captured?.queryParameters['q'], 'Fresno, CA');

      api.dispose();
    });

    test('sends X-Device-ID header', () async {
      Map<String, String>? capturedHeaders;
      final MockClient client = MockClient((http.Request req) async {
        capturedHeaders = req.headers;
        return http.Response(_validBodyWithState, 200);
      });

      final GeocodingApi api = GeocodingApi(
        proxyBaseUrl: 'https://proxy.test',
        deviceId: 'my-device-uuid',
        httpClient: client,
      );
      await api.geocode('Fresno, CA');

      expect(capturedHeaders?['X-Device-ID'], 'my-device-uuid');

      api.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // reverseGeocode
  // -------------------------------------------------------------------------

  group('GeocodingApi.reverseGeocode', () {
    test('returns result on 200 with state field', () async {
      final GeocodingApi api = _makeApi(_respondWith(200, _validBodyWithState));
      final GeocodingResult result = await api.reverseGeocode(
        lat: 36.75,
        lon: -119.65,
      );

      expect(result.lat, 36.75);
      expect(result.lon, -119.65);
      expect(result.displayName, 'Fresno, California, US');

      api.dispose();
    });

    test('throws GeocodingNotFoundException on 404', () async {
      final GeocodingApi api = _makeApi(_respondWith(404, 'not found'));

      await expectLater(
        api.reverseGeocode(lat: 36.75, lon: -119.65),
        throwsA(isA<GeocodingNotFoundException>()),
      );

      api.dispose();
    });

    test('sends lat and lon as separate query parameters', () async {
      Uri? captured;
      final MockClient client = MockClient((http.Request req) async {
        captured = req.url;
        return http.Response(_validBodyWithState, 200);
      });

      final GeocodingApi api = _makeApi(client);
      await api.reverseGeocode(lat: 36.75, lon: -119.65);

      expect(captured?.queryParameters['lat'], '36.75');
      expect(captured?.queryParameters['lon'], '-119.65');
      expect(captured?.queryParameters['q'], isNull);

      api.dispose();
    });

    test('sends X-Device-ID header', () async {
      Map<String, String>? capturedHeaders;
      final MockClient client = MockClient((http.Request req) async {
        capturedHeaders = req.headers;
        return http.Response(_validBodyWithState, 200);
      });

      final GeocodingApi api = GeocodingApi(
        proxyBaseUrl: 'https://proxy.test',
        deviceId: 'my-device-uuid',
        httpClient: client,
      );
      await api.reverseGeocode(lat: 36.75, lon: -119.65);

      expect(capturedHeaders?['X-Device-ID'], 'my-device-uuid');

      api.dispose();
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
