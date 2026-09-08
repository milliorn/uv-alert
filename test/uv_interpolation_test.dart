import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/services/solar_position.dart';
import 'package:uvalert/services/uv_interpolation.dart';

import 'fakes/fake_uv_data.dart';

/// Fresno, CA -- reused from `solar_position_test.dart` for consistency.
const double _lat = 36.75;
const double _lon = -119.65;

/// Solar noon for [_lat]/[_lon] on 2024-06-21 (summer solstice) is close to
/// 20:00 UTC (Fresno is UTC-7 in June; solar noon lands near 13:00 local).
/// Used as "midday" in tests below where the sun is confidently above the
/// horizon.
final DateTime _solarNoonUtc = DateTime.utc(2024, 6, 21, 20);

/// Midnight UTC on the same calendar day -- well past sunset for Fresno, so
/// the sun is confidently below the horizon.
final DateTime _midnightUtc = DateTime.utc(2024, 6, 21);

double _sinDegrees(double degrees) => math.sin(degrees * math.pi / 180);

void main() {
  group('interpolatedUvi', () {
    test('returns 0 when the sun is below the horizon', () {
      final double elevation = solarElevationDegrees(
        lat: _lat,
        lon: _lon,
        utcTime: _midnightUtc,
      );
      // Sanity-check the fixture actually represents nighttime before
      // asserting on interpolatedUvi's behavior.
      expect(elevation, lessThanOrEqualTo(0));

      final UvData data = makeUvData();

      expect(
        interpolatedUvi(data: data, lat: _lat, lon: _lon, atUtc: _midnightUtc),
        0,
      );
    });

    test(
      'returns 0 at night even when currentUvi is non-zero (no negative UV)',
      () {
        final UvData data = makeUvData(currentUvi: 3);

        final double result = interpolatedUvi(
          data: data,
          lat: _lat,
          lon: _lon,
          atUtc: _midnightUtc,
        );

        expect(result, 0);
        expect(result, isNot(lessThan(0)));
      },
    );

    test(
      'scales the peak hourly uvi by sin(elevation) when the sun is up',
      () {
        final double elevation = solarElevationDegrees(
          lat: _lat,
          lon: _lon,
          utcTime: _solarNoonUtc,
        );
        expect(elevation, greaterThan(0));

        final UvData data = makeUvData(
          currentUvi: 0,
          hourly: <UvForecastEntry>[
            UvForecastEntry(time: _solarNoonUtc, uvi: 10),
          ],
        );

        final double result = interpolatedUvi(
          data: data,
          lat: _lat,
          lon: _lon,
          atUtc: _solarNoonUtc,
        );

        expect(result, closeTo(10 * _sinDegrees(elevation), 0.01));
      },
    );

    test(
      'falls back to currentUvi as UVmax when hourly has no entry for the '
      'day',
      () {
        final UvData data = makeUvData(
          currentUvi: 4,
          hourly: const <UvForecastEntry>[],
        );

        final double elevation = solarElevationDegrees(
          lat: _lat,
          lon: _lon,
          utcTime: _solarNoonUtc,
        );

        final double result = interpolatedUvi(
          data: data,
          lat: _lat,
          lon: _lon,
          atUtc: _solarNoonUtc,
        );

        // UVmax falls back to currentUvi (4); result is max(estimate, 4).
        final double expectedEstimate = 4 * _sinDegrees(elevation);
        expect(result, math.max(expectedEstimate, 4));
      },
    );

    test(
      'ignores hourly entries from a different location-local day when '
      'computing UVmax',
      () {
        final UvData data = makeUvData(
          currentUvi: 1,
          // Yesterday's entry has a much higher uvi than today's, and must
          // not be picked up as today's peak.
          hourly: <UvForecastEntry>[
            UvForecastEntry(
              time: _solarNoonUtc.subtract(const Duration(days: 1)),
              uvi: 99,
            ),
            UvForecastEntry(time: _solarNoonUtc, uvi: 5),
          ],
        );

        final double elevation = solarElevationDegrees(
          lat: _lat,
          lon: _lon,
          utcTime: _solarNoonUtc,
        );

        final double result = interpolatedUvi(
          data: data,
          lat: _lat,
          lon: _lon,
          atUtc: _solarNoonUtc,
        );

        expect(result, lessThan(99));
        expect(result, closeTo(5 * _sinDegrees(elevation), 0.01));
      },
    );

    test(
      'uses the conservative (higher) value when currentUvi exceeds the '
      'interpolated estimate',
      () {
        final UvData data = makeUvData(
          currentUvi: 50,
          hourly: <UvForecastEntry>[
            UvForecastEntry(time: _solarNoonUtc, uvi: 1),
          ],
        );

        final double result = interpolatedUvi(
          data: data,
          lat: _lat,
          lon: _lon,
          atUtc: _solarNoonUtc,
        );

        expect(result, 50);
      },
    );

    test('returns 0 at a high-latitude location during polar night', () {
      // Above the Arctic Circle, near winter solstice: the sun does not
      // rise, so elevation stays negative all day.
      const double arcticLat = 78;
      final DateTime winterSolstice = DateTime.utc(2024, 12, 21, 12);

      final double elevation = solarElevationDegrees(
        lat: arcticLat,
        lon: 0,
        utcTime: winterSolstice,
      );
      expect(elevation, lessThanOrEqualTo(0));

      final UvData data = makeUvData();

      expect(
        interpolatedUvi(
          data: data,
          lat: arcticLat,
          lon: 0,
          atUtc: winterSolstice,
        ),
        0,
      );
    });
  });
}
