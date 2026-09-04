import 'package:flutter_test/flutter_test.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/services/hero_conditional_line.dart';
import 'package:uvalert/services/solar_position.dart';

import 'fakes/fake_uv_data.dart';

/// Fixed "now" used across all branch tests, so each test only needs to vary
/// the inputs relevant to the branch it exercises.
final DateTime _now = DateTime.utc(2024, 6, 1, 12);

/// A solar-event map with every event far in the past, used as the base for
/// tests that don't care about solar-event branches (6-10, 16) -- avoids
/// every dawn/dusk branch firing before evaluation ever reaches the branch
/// under test.
Map<SolarEvent, DateTime?> _allEventsPast() => <SolarEvent, DateTime?>{
  for (final SolarEvent e in SolarEvent.values)
    e: _now.subtract(const Duration(hours: 12)),
};

/// A solar-event map with every event `null` (as if polar day/night), used
/// so no solar-event branch can ever fire.
Map<SolarEvent, DateTime?> _noEvents() => <SolarEvent, DateTime?>{
  for (final SolarEvent e in SolarEvent.values) e: null,
};

void main() {
  group('branch 1-5: dawn/sunrise events', () {
    test('1. astronomical dawn upcoming', () {
      final Map<SolarEvent, DateTime?> events = _allEventsPast();
      events[SolarEvent.astronomicalDawn] = _now.add(const Duration(hours: 1));

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: events,
        uvData: makeUvData(),
      );

      expect(line, 'Astronomical dawn begins at 1:00 PM');
    });

    test('2. nautical dawn upcoming', () {
      final Map<SolarEvent, DateTime?> events = _allEventsPast();
      events[SolarEvent.nauticalDawn] = _now.add(const Duration(hours: 1));

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: events,
        uvData: makeUvData(),
      );

      expect(line, 'Nautical dawn begins at 1:00 PM');
    });

    test('3. civil dawn upcoming', () {
      final Map<SolarEvent, DateTime?> events = _allEventsPast();
      events[SolarEvent.civilDawn] = _now.add(const Duration(hours: 1));

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: events,
        uvData: makeUvData(),
      );

      expect(line, 'Civil dawn begins at 1:00 PM');
    });

    test('4. sunrise begins upcoming', () {
      final Map<SolarEvent, DateTime?> events = _allEventsPast();
      events[SolarEvent.sunriseStart] = _now.add(const Duration(hours: 1));

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: events,
        uvData: makeUvData(),
      );

      expect(line, 'Sunrise begins at 1:00 PM');
    });

    test('5. sunrise ends upcoming', () {
      final Map<SolarEvent, DateTime?> events = _allEventsPast();
      events[SolarEvent.sunriseEnd] = _now.add(const Duration(hours: 1));

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: events,
        uvData: makeUvData(),
      );

      expect(line, 'Sunrise ends at 1:00 PM');
    });
  });

  group('branch 6-10: UV threshold crossings', () {
    test('6. UV index will exceed 2 within the look-ahead window', () {
      final UvData uvData = makeUvData(
        hourly: <UvForecastEntry>[
          UvForecastEntry(
            time: _now.subtract(const Duration(hours: 1)),
            uvi: 1,
          ),
          UvForecastEntry(time: _now, uvi: 1.5),
          UvForecastEntry(
            time: _now.add(const Duration(minutes: 30)),
            uvi: 2.5,
          ),
        ],
      );

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: _noEvents(),
        uvData: uvData,
      );

      expect(line, 'UV index will exceed 2 at 12:30 PM');
    });

    test('7. UV index reached 3', () {
      final UvData uvData = makeUvData(
        hourly: <UvForecastEntry>[
          UvForecastEntry(
            time: _now.subtract(const Duration(hours: 1)),
            uvi: 2.5,
          ),
          UvForecastEntry(
            time: _now.subtract(const Duration(minutes: 30)),
            uvi: 3.5,
          ),
          UvForecastEntry(time: _now, uvi: 4),
        ],
      );

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: _noEvents(),
        uvData: uvData,
      );

      expect(line, 'UV index reached 3 at 11:30 AM');
    });

    test("8. today's peak", () {
      final UvData uvData = makeUvData(
        hourly: <UvForecastEntry>[
          UvForecastEntry(
            time: _now.subtract(const Duration(hours: 2)),
            uvi: 4,
          ),
          UvForecastEntry(
            time: _now.subtract(const Duration(hours: 1)),
            uvi: 7.2,
          ),
          UvForecastEntry(time: _now, uvi: 3),
        ],
      );

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: _noEvents(),
        uvData: uvData,
      );

      expect(line, "Today's peak: UV 7.2 at 11:00 AM");
    });

    test('9. UV index will drop below 3 within the hour', () {
      final UvData uvData = makeUvData(
        hourly: <UvForecastEntry>[
          // The day's single highest uvi (5) is a *future* entry beyond the
          // look-ahead window, so branch 8 ("today's peak") does not
          // preempt branch 9 -- branch 8 only fires once its peak has
          // already occurred (peak.time not after `now`), and this peak is
          // still in the future relative to `_now`.
          UvForecastEntry(
            time: _now.subtract(const Duration(hours: 1)),
            uvi: 4,
          ),
          UvForecastEntry(time: _now, uvi: 4),
          UvForecastEntry(time: _now.add(const Duration(minutes: 45)), uvi: 2),
          UvForecastEntry(time: _now.add(const Duration(hours: 3)), uvi: 5),
        ],
      );

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: _noEvents(),
        uvData: uvData,
      );

      expect(line, 'UV index will drop below 3 within the hour');
    });

    test('10. UV index dropped below 3', () {
      final UvData uvData = makeUvData(
        hourly: <UvForecastEntry>[
          // The day's single highest uvi (5) is a future entry, so branch 8
          // ("today's peak") does not preempt branch 10 -- see the
          // matching comment on the branch 9 fixture above.
          UvForecastEntry(
            time: _now.subtract(const Duration(hours: 1)),
            uvi: 4,
          ),
          UvForecastEntry(
            time: _now.subtract(const Duration(minutes: 20)),
            uvi: 2,
          ),
          UvForecastEntry(time: _now, uvi: 1.5),
          UvForecastEntry(time: _now.add(const Duration(hours: 3)), uvi: 5),
        ],
      );

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: _noEvents(),
        uvData: uvData,
      );

      expect(line, 'UV index dropped below 3 at 11:40 AM');
    });
  });

  group('branch 11-15: sunset/dusk events', () {
    test('11. sunset starts upcoming', () {
      final Map<SolarEvent, DateTime?> events = _allEventsPast();
      events[SolarEvent.sunsetStart] = _now.add(const Duration(hours: 1));

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: events,
        uvData: makeUvData(),
      );

      expect(line, 'Sunset starts at 1:00 PM');
    });

    test('12. sunset upcoming', () {
      final Map<SolarEvent, DateTime?> events = _allEventsPast();
      events[SolarEvent.sunset] = _now.add(const Duration(hours: 1));

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: events,
        uvData: makeUvData(),
      );

      expect(line, 'Sunset at 1:00 PM');
    });

    test('13. civil dusk upcoming', () {
      final Map<SolarEvent, DateTime?> events = _allEventsPast();
      events[SolarEvent.civilDusk] = _now.add(const Duration(hours: 1));

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: events,
        uvData: makeUvData(),
      );

      expect(line, 'Civil dusk at 1:00 PM');
    });

    test('14. nautical dusk upcoming', () {
      final Map<SolarEvent, DateTime?> events = _allEventsPast();
      events[SolarEvent.nauticalDusk] = _now.add(const Duration(hours: 1));

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: events,
        uvData: makeUvData(),
      );

      expect(line, 'Nautical dusk at 1:00 PM');
    });

    test('15. astronomical dusk upcoming', () {
      final Map<SolarEvent, DateTime?> events = _allEventsPast();
      events[SolarEvent.astronomicalDusk] = _now.add(const Duration(hours: 1));

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: events,
        uvData: makeUvData(),
      );

      expect(line, 'Astronomical dusk at 1:00 PM');
    });
  });

  test('16. silent when nothing applies', () {
    final String? line = heroConditionalLine(
      now: _now,
      solarEvents: _noEvents(),
      uvData: makeUvData(),
    );

    expect(line, isNull);
  });

  group('priority ordering', () {
    test('an earlier-priority dawn branch wins over a later one', () {
      final Map<SolarEvent, DateTime?> events = _allEventsPast();
      events[SolarEvent.astronomicalDawn] = _now.add(const Duration(hours: 2));
      events[SolarEvent.civilDawn] = _now.add(const Duration(hours: 1));

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: events,
        uvData: makeUvData(),
      );

      expect(line, contains('Astronomical dawn'));
    });

    test('dawn branches take priority over UV-threshold branches', () {
      final Map<SolarEvent, DateTime?> events = _allEventsPast();
      events[SolarEvent.sunriseStart] = _now.add(const Duration(hours: 1));

      final UvData uvData = makeUvData(
        hourly: <UvForecastEntry>[
          UvForecastEntry(time: _now, uvi: 4),
          UvForecastEntry(time: _now.add(const Duration(minutes: 30)), uvi: 1),
        ],
      );

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: events,
        uvData: uvData,
      );

      expect(line, 'Sunrise begins at 1:00 PM');
    });

    test('UV-threshold branches take priority over dusk branches', () {
      final Map<SolarEvent, DateTime?> events = _allEventsPast();
      events[SolarEvent.sunset] = _now.add(const Duration(hours: 1));

      final UvData uvData = makeUvData(
        hourly: <UvForecastEntry>[
          UvForecastEntry(
            time: _now.subtract(const Duration(minutes: 30)),
            uvi: 2,
          ),
          UvForecastEntry(time: _now, uvi: 4),
        ],
      );

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: events,
        uvData: uvData,
      );

      expect(line, contains('UV index reached 3'));
    });

    test('a past solar event does not preempt a later still-upcoming one', () {
      final Map<SolarEvent, DateTime?> events = _allEventsPast();
      events[SolarEvent.civilDawn] = _now.add(const Duration(hours: 1));

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: events,
        uvData: makeUvData(),
      );

      // astronomicalDawn/nauticalDawn are both in the past (from
      // _allEventsPast), so evaluation should fall through to civilDawn.
      expect(line, 'Civil dawn begins at 1:00 PM');
    });
  });

  group('all-future hourly data (no past reading yet)', () {
    test('falls back to the earliest future entry as the "current" reading '
        'when hourly has no past/present entries', () {
      final UvData uvData = makeUvData(
        hourly: <UvForecastEntry>[
          UvForecastEntry(time: _now.add(const Duration(minutes: 10)), uvi: 1),
          UvForecastEntry(
            time: _now.add(const Duration(minutes: 40)),
            uvi: 2.5,
          ),
        ],
      );

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: _noEvents(),
        uvData: uvData,
      );

      expect(line, 'UV index will exceed 2 at 12:40 PM');
    });
  });

  group('empty hourly data', () {
    test('falls through to dawn/dusk-only branches when hourly is empty', () {
      final Map<SolarEvent, DateTime?> events = _allEventsPast();
      events[SolarEvent.sunset] = _now.add(const Duration(hours: 1));

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: events,
        uvData: makeUvData(),
      );

      expect(line, 'Sunset at 1:00 PM');
    });

    test('returns null (silent) when hourly is empty and no solar events '
        'are upcoming', () {
      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: _allEventsPast(),
        uvData: makeUvData(),
      );

      expect(line, isNull);
    });
  });
}
