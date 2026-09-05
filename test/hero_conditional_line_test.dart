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

    test('branch 7 wins over branch 9 when both guards are simultaneously '
        'true (a brief spike then a forecast drop)', () {
      // currentUvi (4, at _now) satisfies both branch 7's guard (>= 3, just
      // crossed up 30 min ago) and branch 9's guard (>= 3, forecast to drop
      // back below 3 within the look-ahead window) -- branch 7 must win per
      // the documented priority order (7 before 9).
      final UvData uvData = makeUvData(
        hourly: <UvForecastEntry>[
          UvForecastEntry(
            time: _now.subtract(const Duration(minutes: 30)),
            uvi: 2,
          ),
          UvForecastEntry(time: _now, uvi: 4),
          UvForecastEntry(time: _now.add(const Duration(minutes: 30)), uvi: 2),
        ],
      );

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: _noEvents(),
        uvData: uvData,
      );

      expect(line, 'UV index reached 3 at 12:00 PM');
    });

    test('branch 7 fires at exactly currentUvi == 3 (the inclusive '
        'lower-bound guard)', () {
      final UvData uvData = makeUvData(
        hourly: <UvForecastEntry>[
          UvForecastEntry(
            time: _now.subtract(const Duration(minutes: 30)),
            uvi: 2,
          ),
          UvForecastEntry(time: _now, uvi: 3),
        ],
      );

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: _noEvents(),
        uvData: uvData,
      );

      expect(line, 'UV index reached 3 at 12:00 PM');
    });

    test('branch 6 does not fire at exactly currentUvi == 2 exceeding the '
        'rising threshold (guard requires e.uvi > 2, strictly greater)', () {
      final UvData uvData = makeUvData(
        hourly: <UvForecastEntry>[
          UvForecastEntry(time: _now, uvi: 1.5),
          UvForecastEntry(time: _now.add(const Duration(minutes: 30)), uvi: 2),
        ],
      );

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: _noEvents(),
        uvData: uvData,
      );

      expect(line, isNull);
    });

    test('branch 7 reports the most recent of two up-crossings, not the '
        'first', () {
      // UV crosses to unsafe at 10am, drops back below 3 at 10:30am, then
      // crosses up again at 11:45am and stays there -- the message should
      // describe the crossing that started the *current* unsafe window
      // (11:45am), not the earlier, since-ended one (10am).
      final UvData uvData = makeUvData(
        hourly: <UvForecastEntry>[
          UvForecastEntry(
            time: _now.subtract(const Duration(hours: 2)),
            uvi: 2,
          ),
          UvForecastEntry(
            time: _now.subtract(const Duration(hours: 1, minutes: 30)),
            uvi: 3.5,
          ),
          UvForecastEntry(
            time: _now.subtract(const Duration(hours: 1)),
            uvi: 2,
          ),
          UvForecastEntry(
            time: _now.subtract(const Duration(minutes: 15)),
            uvi: 4,
          ),
          UvForecastEntry(time: _now, uvi: 4),
        ],
      );

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: _noEvents(),
        uvData: uvData,
      );

      expect(line, 'UV index reached 3 at 11:45 AM');
    });

    test("8. today's peak excludes a high reading that falls on the "
        "location's local yesterday, even though it's the same UTC "
        'calendar day as now', () {
      // _now is 2024-06-01 12:00 UTC. At UTC+12, local time is 2024-06-02
      // 00:00 -- just past local midnight, so the location's "today" is
      // 2024-06-02, and everything before local midnight (all of UTC
      // 2024-06-01) is the location's "yesterday". The 9-uvi entry (an hour
      // before `_now`, still UTC 2024-06-01) is on the location's
      // yesterday and must be excluded; the 3-uvi entry (an hour after
      // local midnight) is on the location's today and already in the
      // past, so it alone should be reported as the peak.
      final UvData uvData = makeUvData(
        timezoneOffset: 12 * 3600,
        hourly: <UvForecastEntry>[
          UvForecastEntry(
            time: _now.subtract(const Duration(hours: 1)),
            uvi: 9,
          ),
          UvForecastEntry(time: _now.add(const Duration(hours: 1)), uvi: 3),
        ],
      );

      final String? line = heroConditionalLine(
        now: _now.add(const Duration(hours: 2)),
        solarEvents: _noEvents(),
        uvData: uvData,
      );

      expect(line, "Today's peak: UV 3.0 at 1:00 PM");
    });

    test("8. today's peak correctly includes an entry that is today in "
        "the location's local day but was excluded under the old "
        'UTC-day logic', () {
      // _now is 2024-06-01 12:00 UTC. At UTC-10, local time is 2024-06-01
      // 02:00 -- so the location's "today" spans UTC 2024-06-01T10:00
      // through UTC 2024-06-02T10:00. A UTC 2024-06-01T11:00 peak (an hour
      // ago) is within that window and already in the past, so it should
      // be reported.
      final UvData uvData = makeUvData(
        timezoneOffset: -10 * 3600,
        hourly: <UvForecastEntry>[
          UvForecastEntry(
            time: _now.subtract(const Duration(hours: 1)),
            uvi: 6.5,
          ),
        ],
      );

      final String? line = heroConditionalLine(
        now: _now,
        solarEvents: _noEvents(),
        uvData: uvData,
      );

      expect(line, "Today's peak: UV 6.5 at 11:00 AM");
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

  group('real solarEventTimes() polar output, fed through '
      'heroConditionalLine', () {
    test('stays silent (not a crash or a bogus event) at 85N in deep '
        'winter, where every solar event is null', () {
      // Same fixture as solar_position_test.dart's "returns null for events
      // that do not occur during polar night" test -- confirmed there that
      // every one of the 10 SolarEvent keys is null on this date/location.
      final DateTime polarNow = DateTime.utc(2024, 12, 21, 12);
      final Map<SolarEvent, DateTime?> events = solarEventTimes(
        lat: 85,
        lon: 0,
        date: polarNow,
      );

      final String? line = heroConditionalLine(
        now: polarNow,
        solarEvents: events,
        uvData: makeUvData(),
      );

      expect(line, isNull);
    });

    test('surfaces only the two non-null events (astronomical dawn/dusk) '
        'at 80N in winter, where most solar events are null', () {
      // Same fixture as solar_position_test.dart's "returns non-null
      // astronomical dawn/dusk at 80N in winter" test -- confirmed there
      // that astronomicalDawn/astronomicalDusk are non-null while
      // sunriseStart/sunset/civilDawn (and by the same logic, the rest of
      // the non-astronomical events) are null.
      final DateTime polarDate = DateTime.utc(2024, 12, 21);
      final Map<SolarEvent, DateTime?> events = solarEventTimes(
        lat: 80,
        lon: 0,
        date: polarDate,
      );

      // Pick `now` just before the earlier of the two non-null events, so
      // it is the one branch 1-5/11-15 upcoming-event check can find.
      final DateTime justBeforeDawn = events[SolarEvent.astronomicalDawn]!
          .subtract(const Duration(minutes: 1));

      final String? line = heroConditionalLine(
        now: justBeforeDawn,
        solarEvents: events,
        uvData: makeUvData(),
      );

      expect(line, contains('Astronomical dawn begins at'));
    });
  });
}
