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

/// 08:00 UTC on the same calendar day (01:00 local, Fresno UTC-7) -- well
/// after sunset and well before dawn, so the sun is confidently below the
/// horizon.
final DateTime _nighttimeUtc = DateTime.utc(2024, 6, 21, 8);

double _sinDegrees(double degrees) => math.sin(degrees * math.pi / 180);

void main() {
  group('interpolatedUvi', () {
    test('at night with a zero currentUvi, returns 0 (no negative UV, no '
        'direct-sun contribution)', () {
      final double elevation = solarElevationDegrees(
        lat: _lat,
        lon: _lon,
        utcTime: _nighttimeUtc,
      );
      // Sanity-check the fixture actually represents nighttime before
      // asserting on interpolatedUvi's behavior.
      expect(elevation, lessThanOrEqualTo(0));

      final UvData data = makeUvData(currentUvi: 0);

      final double result = interpolatedUvi(
        data: data,
        lat: _lat,
        lon: _lon,
        atUtc: _nighttimeUtc,
      );

      expect(result, 0);
      expect(result, isNot(lessThan(0)));
    });

    test('at night, still returns the conservative (higher) of 0 and a '
        'non-zero currentUvi. A stale reading must not be clobbered to 0 '
        'just because the sun has set', () {
      final UvData data = makeUvData(currentUvi: 3);

      final double result = interpolatedUvi(
        data: data,
        lat: _lat,
        lon: _lon,
        atUtc: _nighttimeUtc,
      );

      expect(result, 3);
    });

    test('scales the peak hourly uvi by sin(elevation) when the sun is up', () {
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
    });

    test('falls back to currentUvi as UVmax when hourly has no entry for the '
        'day', () {
      final UvData data = makeUvData(currentUvi: 4);

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
      // Note: since sin(elevation) <= 1, the conservative-max step here
      // always resolves to currentUvi regardless of what UVmax actually was.
      // This only proves interpolatedUvi doesn't crash/underreport on a
      // no-hourly-data day, not that the fallback specifically ran. See the
      // dedicated `peakUviForDay` group below for that.
      final double expectedEstimate = 4 * _sinDegrees(elevation);
      expect(result, math.max(expectedEstimate, 4));
    });

    test('ignores hourly entries from a different location-local day when '
        'computing UVmax', () {
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
    });

    test('uses the conservative (higher) value when currentUvi exceeds the '
        'interpolated estimate', () {
      final UvData data = makeUvData(
        currentUvi: 50,
        hourly: <UvForecastEntry>[UvForecastEntry(time: _solarNoonUtc, uvi: 1)],
      );

      final double result = interpolatedUvi(
        data: data,
        lat: _lat,
        lon: _lon,
        atUtc: _solarNoonUtc,
      );

      expect(result, 50);
    });

    test('buckets hourly entries by location-local day, not UTC day, when '
        'timezoneOffset is non-zero', () {
      // Fresno is UTC-7. 02:00 UTC on June 22nd is 19:00 local on June
      // 21st -- still "today" locally even though the UTC calendar day has
      // already rolled over, and the sun is still above the horizon. An
      // entry at 03:00 UTC on June 22nd (20:00 local, June 21st) should
      // count toward the same local day, while an entry at 08:00 UTC on
      // June 22nd (01:00 local, June 22nd) should not.
      const int fresnoOffsetSeconds = -7 * 3600;
      final DateTime queryUtc = DateTime.utc(2024, 6, 22, 2);

      final UvData data = makeUvData(
        currentUvi: 0,
        timezoneOffset: fresnoOffsetSeconds,
        hourly: <UvForecastEntry>[
          // Same location-local day (June 21st local) as queryUtc.
          UvForecastEntry(time: DateTime.utc(2024, 6, 22, 3), uvi: 5),
          // Next location-local day (June 22nd local) -- must be excluded.
          UvForecastEntry(time: DateTime.utc(2024, 6, 22, 8), uvi: 99),
        ],
      );

      final double elevation = solarElevationDegrees(
        lat: _lat,
        lon: _lon,
        utcTime: queryUtc,
      );
      expect(elevation, greaterThan(0));

      final double result = interpolatedUvi(
        data: data,
        lat: _lat,
        lon: _lon,
        atUtc: queryUtc,
      );

      expect(result, lessThan(99));
      expect(result, closeTo(5 * _sinDegrees(elevation), 0.01));
    });

    test('returns 0 at a high-latitude location during polar night, given a '
        'zero currentUvi', () {
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

      final UvData data = makeUvData(currentUvi: 0);

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

  // ---------------------------------------------------------------------------
  // peakUviForDay
  // ---------------------------------------------------------------------------
  //
  // Tested directly (rather than only observed through interpolatedUvi)
  // because interpolatedUvi's conservative-max step against currentUvi
  // structurally masks this function's fallback value: sin(elevation) <= 1
  // means the interpolated estimate can never exceed currentUvi when UVmax
  // is set to currentUvi via the fallback, so a broken fallback returning
  // some other value could still coincidentally produce the same
  // interpolatedUvi() result as long as it stays below currentUvi.

  group('peakUviForDay', () {
    test('falls back to currentUvi when hourly has no entry for the day', () {
      final UvData data = makeUvData(currentUvi: 4);

      expect(peakUviForDay(data, _solarNoonUtc), 4);
    });

    test('returns the peak hourly uvi for the location-local day containing '
        'atUtc', () {
      final UvData data = makeUvData(
        currentUvi: 1,
        hourly: <UvForecastEntry>[
          UvForecastEntry(time: _solarNoonUtc, uvi: 3),
          UvForecastEntry(
            time: _solarNoonUtc.add(const Duration(hours: 1)),
            uvi: 7,
          ),
          UvForecastEntry(
            time: _solarNoonUtc.add(const Duration(hours: 2)),
            uvi: 5,
          ),
        ],
      );

      expect(peakUviForDay(data, _solarNoonUtc), 7);
    });

    test('ignores hourly entries from a different location-local day', () {
      final UvData data = makeUvData(
        currentUvi: 1,
        hourly: <UvForecastEntry>[
          UvForecastEntry(
            time: _solarNoonUtc.subtract(const Duration(days: 1)),
            uvi: 99,
          ),
          UvForecastEntry(time: _solarNoonUtc, uvi: 5),
        ],
      );

      expect(peakUviForDay(data, _solarNoonUtc), 5);
    });
  });
}
