import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/services/solar_position.dart';

/// Fresno, CA -- reused from other tests in this suite (e.g.
/// `dashboard_screen_test.dart`'s fixed-location fakes) for consistency.
const double _lat = 36.75;
const double _lon = -119.65;

/// Summer solstice 2024, chosen as a date with well-documented reference
/// sunrise/sunset/twilight times for Fresno, CA.
final DateTime _solstice = DateTime.utc(2024, 6, 21);

/// Reference times below are published sunrise/sunset/twilight times for
/// Fresno, CA on 2024-06-21 (PDT, UTC-7), sourced from standard almanac/
/// sunrise-sunset reference tables. This implementation uses a simplified
/// single-sine-wave declination model, not a full ephemeris, so a
/// [_toleranceMinutes]-wide tolerance is used rather than exact matching --
/// a few minutes of drift from the simplified formula is expected and
/// acceptable for this app's purposes (deciding which conditional-line
/// message to show, not scientific precision).
const int _toleranceMinutes = 12;

void main() {
  group('solarEventTimes', () {
    final Map<SolarEvent, DateTime?> events = solarEventTimes(
      lat: _lat,
      lon: _lon,
      date: _solstice,
    );

    void expectNear(SolarEvent event, DateTime referenceUtc) {
      final DateTime? actual = events[event];
      expect(actual, isNotNull, reason: '$event should occur on this date');
      final Duration diff = actual!.difference(referenceUtc).abs();
      expect(
        diff.inMinutes,
        lessThanOrEqualTo(_toleranceMinutes),
        reason:
            '$event expected near $referenceUtc, got $actual '
            '(${diff.inMinutes} min off)',
      );
    }

    test('astronomicalDawn near reference time', () {
      expectNear(
        SolarEvent.astronomicalDawn,
        DateTime.utc(2024, 6, 21, 10, 46),
      );
    });

    test('nauticalDawn near reference time', () {
      expectNear(SolarEvent.nauticalDawn, DateTime.utc(2024, 6, 21, 11, 29));
    });

    test('civilDawn near reference time', () {
      expectNear(SolarEvent.civilDawn, DateTime.utc(2024, 6, 21, 12, 7));
    });

    test('sunriseStart near reference time', () {
      expectNear(SolarEvent.sunriseStart, DateTime.utc(2024, 6, 21, 12, 38));
    });

    test('sunriseEnd near reference time', () {
      expectNear(SolarEvent.sunriseEnd, DateTime.utc(2024, 6, 21, 12, 48));
    });

    test('sunsetStart near reference time', () {
      expectNear(SolarEvent.sunsetStart, DateTime.utc(2024, 6, 22, 3, 9));
    });

    test('sunset near reference time', () {
      expectNear(SolarEvent.sunset, DateTime.utc(2024, 6, 22, 3, 19));
    });

    test('civilDusk near reference time', () {
      expectNear(SolarEvent.civilDusk, DateTime.utc(2024, 6, 22, 3, 50));
    });

    test('nauticalDusk near reference time', () {
      expectNear(SolarEvent.nauticalDusk, DateTime.utc(2024, 6, 22, 4, 28));
    });

    test('astronomicalDusk near reference time', () {
      expectNear(SolarEvent.astronomicalDusk, DateTime.utc(2024, 6, 22, 5, 11));
    });

    test('events occur in chronological order', () {
      // Derived from `SolarEvent.values` (rather than a hand-written
      // literal) so this assertion stays in sync with the enum's
      // declaration order -- which its doc comment claims is already
      // chronological -- instead of silently drifting from it.
      final List<DateTime> ordered = SolarEvent.values
          .map((SolarEvent e) => events[e]!)
          .toList();

      for (int i = 1; i < ordered.length; i++) {
        expect(
          ordered[i].isAfter(ordered[i - 1]),
          isTrue,
          reason: 'event $i should be after event ${i - 1}',
        );
      }
    });

    test('returns all 10 SolarEvent keys', () {
      expect(events.keys.toSet(), SolarEvent.values.toSet());
    });
  });

  group('solarElevationDegrees', () {
    test('is near its daily maximum at solar noon', () {
      // Solar noon in UTC ≈ 12:00 - lon/15 (lon is negative, west of prime
      // meridian, so this is later in UTC).
      final DateTime solarNoonUtc = DateTime.utc(
        2024,
        6,
        21,
        12,
      ).subtract(Duration(minutes: (_lon / 15 * 60).round()));

      final double elevationAtNoon = solarElevationDegrees(
        lat: _lat,
        lon: _lon,
        utcTime: solarNoonUtc,
      );

      final double elevationAnHourBefore = solarElevationDegrees(
        lat: _lat,
        lon: _lon,
        utcTime: solarNoonUtc.subtract(const Duration(hours: 1)),
      );
      final double elevationAnHourAfter = solarElevationDegrees(
        lat: _lat,
        lon: _lon,
        utcTime: solarNoonUtc.add(const Duration(hours: 1)),
      );

      expect(elevationAtNoon, greaterThan(70));
      expect(elevationAtNoon, greaterThan(elevationAnHourBefore));
      expect(elevationAtNoon, greaterThan(elevationAnHourAfter));
    });

    test('is negative (below horizon) at midnight', () {
      final double elevationAtMidnight = solarElevationDegrees(
        lat: _lat,
        lon: _lon,
        utcTime: DateTime.utc(
          2024,
          6,
          21,
        ).subtract(Duration(minutes: (_lon / 15 * 60).round())),
      );

      expect(elevationAtMidnight, lessThan(0));
    });

    test('converts a non-UTC DateTime to UTC before computing', () {
      final DateTime utcTime = DateTime.utc(2024, 6, 21, 20);
      final DateTime localEquivalent = utcTime.toLocal();

      expect(
        solarElevationDegrees(lat: _lat, lon: _lon, utcTime: localEquivalent),
        solarElevationDegrees(lat: _lat, lon: _lon, utcTime: utcTime),
      );
    });
  });

  group('polar day/night', () {
    test('returns null for events that do not occur during polar day', () {
      // 80°N in summer: the sun never dips low enough for dawn/dusk twilight
      // events (or even sunrise/sunset) to occur -- it's polar day.
      final Map<SolarEvent, DateTime?> events = solarEventTimes(
        lat: 80,
        lon: 0,
        date: DateTime.utc(2024, 6, 21),
      );

      expect(events[SolarEvent.sunriseStart], isNull);
      expect(events[SolarEvent.sunset], isNull);
      expect(events[SolarEvent.astronomicalDawn], isNull);
    });

    test('returns null for events that do not occur during polar night', () {
      // 85°N in deep winter: the sun's elevation never exceeds roughly -20°
      // even at its daily peak, so not even astronomical twilight (-18°) is
      // reached -- true polar night, every event is null.
      final Map<SolarEvent, DateTime?> events = solarEventTimes(
        lat: 85,
        lon: 0,
        date: DateTime.utc(2024, 12, 21),
      );

      for (final SolarEvent event in SolarEvent.values) {
        expect(events[event], isNull, reason: '$event should be null');
      }
    });

    test('solarElevationDegrees stays well below the horizon at 85N in '
        'winter', () {
      final double elevation = solarElevationDegrees(
        lat: 85,
        lon: 0,
        utcTime: DateTime.utc(2024, 12, 21, 12),
      );

      expect(elevation, lessThan(-18));
    });

    test('returns non-null astronomical dawn/dusk at 80N in winter, where '
        'the sun grazes but does not cross the astronomical threshold at '
        'its daily extremes', () {
      // At 80°N on the winter solstice, the sun's daily elevation ranges
      // roughly from -33° (solar midnight) to -13° (solar noon) -- it
      // crosses the -18° astronomical threshold twice a day even though it
      // never gets close to civil twilight or sunrise.
      final Map<SolarEvent, DateTime?> events = solarEventTimes(
        lat: 80,
        lon: 0,
        date: DateTime.utc(2024, 12, 21),
      );

      expect(events[SolarEvent.astronomicalDawn], isNotNull);
      expect(events[SolarEvent.astronomicalDusk], isNotNull);
      expect(events[SolarEvent.sunriseStart], isNull);
      expect(events[SolarEvent.sunset], isNull);
      expect(events[SolarEvent.civilDawn], isNull);
    });
  });

  group('invalid lat input', () {
    test('solarEventTimes rejects NaN lat via assertion', () {
      expect(
        () => solarEventTimes(
          lat: double.nan,
          lon: 0,
          date: DateTime.utc(2024, 6, 21),
        ),
        throwsAssertionError,
      );
    });

    test('solarEventTimes rejects out-of-range lat via assertion', () {
      expect(
        () => solarEventTimes(
          lat: 200,
          lon: 0,
          date: DateTime.utc(2024, 6, 21),
        ),
        throwsAssertionError,
      );
    });

    test('solarElevationDegrees rejects NaN lat via assertion', () {
      expect(
        () => solarElevationDegrees(
          lat: double.nan,
          lon: 0,
          utcTime: DateTime.utc(2024, 6, 21),
        ),
        throwsAssertionError,
      );
    });

    test('solarElevationDegrees rejects out-of-range lat via assertion', () {
      expect(
        () => solarElevationDegrees(
          lat: -200,
          lon: 0,
          utcTime: DateTime.utc(2024, 6, 21),
        ),
        throwsAssertionError,
      );
    });
  });

  group('local-time date normalization', () {
    test('solarEventTimes produces the same result for an equivalent local '
        'or UTC date', () {
      final DateTime utcDate = DateTime.utc(2024, 6, 21);
      final DateTime localEquivalent = utcDate.toLocal();

      final Map<SolarEvent, DateTime?> fromUtc = solarEventTimes(
        lat: _lat,
        lon: _lon,
        date: utcDate,
      );
      final Map<SolarEvent, DateTime?> fromLocal = solarEventTimes(
        lat: _lat,
        lon: _lon,
        date: localEquivalent,
      );

      expect(fromLocal, fromUtc);
    });
  });
}
