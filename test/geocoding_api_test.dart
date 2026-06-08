import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uvalert/api/geocoding_api.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

GeocodingApi _makeApi(MockClient client) =>
    GeocodingApi(proxyBaseUrl: 'https://proxy.test', httpClient: client);

MockClient _respondWith(int status, String body) =>
    MockClient((_) async => http.Response(body, status));

const String _validBody =
    '{"lat":36.75,"lon":-119.65,"display_name":"Fresno, CA, US"}';

// ---------------------------------------------------------------------------
// geocode
// ---------------------------------------------------------------------------

void main() {
  group('GeocodingApi.geocode', () {
    test('returns result on 200 with valid body', () async {
      final GeocodingApi api = _makeApi(_respondWith(200, _validBody));
      final GeocodingResult result = await api.geocode('Fresno, CA');

      expect(result.lat, 36.75);
      expect(result.lon, -119.65);
      expect(result.displayName, 'Fresno, CA, US');

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
        return http.Response(_validBody, 200);
      });

      final GeocodingApi api = _makeApi(client);
      await api.geocode('Fresno, CA');

      expect(captured?.queryParameters['q'], 'Fresno, CA');

      api.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // reverseGeocode
  // -------------------------------------------------------------------------

  group('GeocodingApi.reverseGeocode', () {
    test('returns result on 200 with valid body', () async {
      final GeocodingApi api = _makeApi(_respondWith(200, _validBody));
      final GeocodingResult result = await api.reverseGeocode(
        lat: 36.75,
        lon: -119.65,
      );

      expect(result.lat, 36.75);
      expect(result.lon, -119.65);
      expect(result.displayName, 'Fresno, CA, US');

      api.dispose();
    });

    test('throws GeocodingNotFoundException on 404', () async {
      final GeocodingApi api = _makeApi(_respondWith(404, 'not found'));

      await expectLater(
        api.reverseGeocode(lat: 0, lon: 0),
        throwsA(isA<GeocodingNotFoundException>()),
      );

      api.dispose();
    });

    test('sends lat and lon as query parameters', () async {
      Uri? captured;
      final MockClient client = MockClient((http.Request req) async {
        captured = req.url;
        return http.Response(_validBody, 200);
      });

      final GeocodingApi api = _makeApi(client);
      await api.reverseGeocode(lat: 36.75, lon: -119.65);

      expect(captured?.queryParameters['lat'], '36.75');
      expect(captured?.queryParameters['lon'], '-119.65');

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
  // dispose — owned client path
  // -------------------------------------------------------------------------

  test('dispose does not throw when api owns its client', () {
    final GeocodingApi api = GeocodingApi(proxyBaseUrl: 'https://proxy.test');
    expect(api.dispose, returnsNormally);
  });
}
