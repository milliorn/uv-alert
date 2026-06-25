// Integration tests for GeocodingApi against the live proxy.
//
// These tests require outbound internet access and are excluded from the normal
// test suite. Run them with:
//
//   flutter test --tags integration test/integration/geocoding_api_live_test.dart
//
// ci.yml excludes them via --exclude-tags integration; run manually when
// needed.

@Tags(<String>['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/api/geocoding_api.dart';

const String _proxyBaseUrl = 'https://uv-alert-proxy.vercel.app';
const String _testDeviceId = 'integration-test-device-id';

void main() {
  late GeocodingApi api;

  setUp(() {
    api = GeocodingApi(proxyBaseUrl: _proxyBaseUrl, deviceId: _testDeviceId);
  });

  tearDown(() => api.dispose());

  group('GeocodingApi live proxy', () {
    test(
      'happy path with state - Fresno returns name, state, country',
      () async {
        final List<GeocodingResult> results =
            await api.geocodeMultiple('Fresno');

        expect(results, isNotEmpty);
        final GeocodingResult first = results.first;
        expect(first.lat, isNonZero);
        expect(first.lon, isNonZero);
        expect(first.displayName, contains('Fresno'));
        expect(first.displayName, contains('US'));
      },
    );

    test(
      'international city - Tokyo returns valid coords and displayName',
      () async {
        final List<GeocodingResult> results =
            await api.geocodeMultiple('Tokyo, Japan');

        expect(results, isNotEmpty);
        final GeocodingResult first = results.first;
        expect(first.lat, isNonZero);
        expect(first.lon, isNonZero);
        expect(first.displayName, isNotEmpty);
        expect(first.displayName, contains('JP'));
        // Tokyo lat/lon ballpark: 35-36°N, 139-140°E
        expect(first.lat, inInclusiveRange(34.0, 37.0));
        expect(first.lon, inInclusiveRange(138.0, 141.0));
      },
    );

    test(
      '404 path - nonsense query throws GeocodingNotFoundException',
      () async {
        await expectLater(
          api.geocodeMultiple('xyzzy_no_such_place_8675309'),
          throwsA(isA<GeocodingNotFoundException>()),
        );
      },
    );

    test(
      'coords round-trip - Fresno lat/lon are in the right ballpark',
      () async {
        final List<GeocodingResult> results =
            await api.geocodeMultiple('Fresno');

        expect(results, isNotEmpty);
        final GeocodingResult first = results.first;
        // Fresno, CA is roughly 36-37°N, 119-120°W
        expect(first.lat, inInclusiveRange(35.0, 38.0));
        expect(first.lon, inInclusiveRange(-121.0, -118.0));
      },
    );
  });
}
