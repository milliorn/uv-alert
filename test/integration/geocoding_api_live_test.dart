// Integration tests for GeocodingApi against the live proxy.
//
// These tests require outbound internet access and are excluded from the normal
// test suite. Run them with:
//
//   flutter test --tags integration test/integration/geocoding_api_live_test.dart
//
// In CI they run in a dedicated workflow job (integration.yml) that has network
// access; the standard ci.yml job does not run them.

@Tags(<String>['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/api/geocoding_api.dart';

const String _proxyBaseUrl = 'https://uv-alert-proxy.vercel.app';
const String _testDeviceId = 'integration-test-device-id';

void main() {
  late GeocodingApi api;

  setUp(() {
    api = GeocodingApi(
      proxyBaseUrl: _proxyBaseUrl,
      deviceId: _testDeviceId,
    );
  });

  tearDown(() => api.dispose());

  group('GeocodingApi live proxy', () {
    test(
      'happy path with state - Fresno returns name, state, country',
      () async {
        final GeocodingResult result = await api.geocode('Fresno, CA');

        expect(result.lat, isNonZero);
        expect(result.lon, isNonZero);
        // Proxy returns { name, state, country };
        // displayName is built as "name, state, country"
        expect(result.displayName, contains('Fresno'));
        expect(result.displayName, contains('US'));
      },
    );

    test(
      'international city - Tokyo returns valid coords and displayName',
      () async {
        final GeocodingResult result = await api.geocode('Tokyo, Japan');

        expect(result.lat, isNonZero);
        expect(result.lon, isNonZero);
        expect(result.displayName, isNotEmpty);
        expect(result.displayName, contains('JP'));
        // Tokyo lat/lon ballpark: 35-36°N, 139-140°E
        expect(result.lat, inInclusiveRange(34.0, 37.0));
        expect(result.lon, inInclusiveRange(138.0, 141.0));
      },
    );

    test(
      '404 path - nonsense query throws GeocodingNotFoundException',
      () async {
        await expectLater(
          api.geocode('xyzzy_no_such_place_8675309'),
          throwsA(isA<GeocodingNotFoundException>()),
        );
      },
    );

    test(
      'coords round-trip - Fresno lat/lon are in the right ballpark',
      () async {
        final GeocodingResult result = await api.geocode('Fresno, CA');

        // Fresno, CA is roughly 36-37°N, 119-120°W
        expect(result.lat, inInclusiveRange(35.0, 38.0));
        expect(result.lon, inInclusiveRange(-121.0, -118.0));
      },
    );
  });
}
