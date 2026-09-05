import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/services/solar_position.dart';
import 'package:uvalert/utils/time_format.dart';
import 'package:uvalert/utils/who_risk.dart';

/// UV index threshold below which UV exposure is considered safe without
/// protection, and above which the dashboard hero surfaces "reached"/
/// "dropped below" messaging (branches 7, 9, 10).
///
/// This is an [int] because WHO's public UV scale and risk labels are
/// whole-number based (Low is 0-2, Moderate is 3+ -- see [whoLowMax]), so
/// "reached 3" is the correct wording for the moment a reading enters
/// Moderate. The underlying [UvForecastEntry.uvi] comparisons throughout
/// this file stay full-precision [double]s, not truncated to whole numbers
/// -- only the threshold and displayed number are integers, so
/// crossing-time predictions (e.g. branch 6's look-ahead) remain accurate
/// down to the data's actual resolution rather than snapping to whole-hour
/// boundaries.
const int heroUnsafeUvThreshold = 3;

/// UV index threshold used for the "will exceed" look-ahead messaging
/// (branch 6) -- lower than [heroUnsafeUvThreshold] so users get an early
/// heads-up before crossing into "unsafe" territory. See
/// [heroUnsafeUvThreshold] for why this is an [int].
const int heroRisingUvThreshold = 2;

/// Look-ahead window for the "UV index will drop below 3 within the hour"
/// message (branch 9), and for the "will exceed 2" message (branch 6).
const Duration heroLookAheadWindow = Duration(hours: 1);

/// Evaluates the dashboard hero's single conditional line: a 16-step,
/// priority-ordered list of possible messages (solar events, then UV
/// threshold crossings, then more solar events), returning the text of the
/// first one that applies, or `null` if none do (branch 16, "silent").
///
/// [now] should be UTC (e.g. `DateTime.now().toUtc()`, matching
/// `dashboard_footer.dart`'s existing pattern), since [solarEvents] and
/// [uvData]'s timestamps are both UTC -- converted internally via
/// [DateTime.toUtc] regardless, matching [solarEventTimes] and
/// [solarElevationDegrees]'s defensive handling of their own time
/// parameters, so a caller passing device-local time by mistake still gets
/// correct results rather than a silent wrong-day/wrong-time bug.
///
/// Priority order (see `.private/architecture/SCREENS.md`'s "Hero" spec):
/// 1. "Astronomical dawn begins at {time}"
/// 2. "Nautical dawn begins at {time}"
/// 3. "Civil dawn begins at {time}"
/// 4. "Sunrise begins at {time}"
/// 5. "Sunrise ends at {time}"
/// 6. "UV index will exceed 2 at {time}"
/// 7. "UV index reached 3 at {time}"
/// 8. "Today's peak: UV {x} at {time}"
/// 9. "UV index will drop below 3 within the hour"
/// 10. "UV index dropped below 3 at {time}"
/// 11. "Sunset starts at {time}"
/// 12. "Sunset at {time}"
/// 13. "Civil dusk at {time}"
/// 14. "Nautical dusk at {time}"
/// 15. "Astronomical dusk at {time}"
/// 16. Silent (returns `null`)
///
/// Branches 1-5 and 11-15 fire only when the corresponding solar event is
/// still upcoming (`now` is before it) -- once an event has passed, this
/// function moves on to the next branch in priority order rather than
/// re-announcing something already in the past.
///
/// Branches 6-10 (UV threshold crossings) inspect [uvData]'s `hourly`
/// entries relative to `now`. When `hourly` is empty, all five of these
/// branches are skipped (there is nothing to evaluate), and evaluation
/// falls through toward the sunset/dusk-only branches (11-15) -- the
/// sensible choice, since a UV-based message can't be shown without any UV
/// forecast data, but solar-event messaging is still meaningful.
String? heroConditionalLine({
  required DateTime now,
  required Map<SolarEvent, DateTime?> solarEvents,
  required UvData uvData,
}) {
  final DateTime nowUtc = now.toUtc();

  String? upcoming(SolarEvent event, String Function(DateTime time) format) {
    final DateTime? time = solarEvents[event];
    if (time == null || !nowUtc.isBefore(time)) return null;
    return format(time);
  }

  final String? dawnLine =
      upcoming(
        SolarEvent.astronomicalDawn,
        (DateTime t) => 'Astronomical dawn begins at ${formatTime(t)}',
      ) ??
      upcoming(
        SolarEvent.nauticalDawn,
        (DateTime t) => 'Nautical dawn begins at ${formatTime(t)}',
      ) ??
      upcoming(
        SolarEvent.civilDawn,
        (DateTime t) => 'Civil dawn begins at ${formatTime(t)}',
      ) ??
      upcoming(
        SolarEvent.sunriseStart,
        (DateTime t) => 'Sunrise begins at ${formatTime(t)}',
      ) ??
      upcoming(
        SolarEvent.sunriseEnd,
        (DateTime t) => 'Sunrise ends at ${formatTime(t)}',
      );

  if (dawnLine != null) return dawnLine;

  final String? uvLine = _uvThresholdLine(now: nowUtc, uvData: uvData);

  if (uvLine != null) return uvLine;

  final String? duskLine =
      upcoming(
        SolarEvent.sunsetStart,
        (DateTime t) => 'Sunset starts at ${formatTime(t)}',
      ) ??
      upcoming(
        SolarEvent.sunset,
        (DateTime t) => 'Sunset at ${formatTime(t)}',
      ) ??
      upcoming(
        SolarEvent.civilDusk,
        (DateTime t) => 'Civil dusk at ${formatTime(t)}',
      ) ??
      upcoming(
        SolarEvent.nauticalDusk,
        (DateTime t) => 'Nautical dusk at ${formatTime(t)}',
      ) ??
      upcoming(
        SolarEvent.astronomicalDusk,
        (DateTime t) => 'Astronomical dusk at ${formatTime(t)}',
      );

  if (duskLine != null) return duskLine;

  return null;
}

/// Evaluates branches 6-10 (the UV-index-threshold messages), or `null` if
/// none apply -- including when [uvData]'s `hourly` list is empty, since
/// there is then nothing to evaluate.
String? _uvThresholdLine({required DateTime now, required UvData uvData}) {
  final List<UvForecastEntry> hourly = uvData.hourly;

  if (hourly.isEmpty) return null;

  final List<UvForecastEntry> sorted = <UvForecastEntry>[...hourly]
    ..sort((UvForecastEntry a, UvForecastEntry b) => a.time.compareTo(b.time));

  // "Today" is the location's local calendar day, via uvData.timezoneOffset
  // -- not `now`'s UTC calendar day, which can be a different day than the
  // location's "today" for any location far enough from UTC. Computed by
  // shifting `now` to location-local time (via toLocationLocal) to find its
  // local calendar day, then shifting that day's UTC midnight boundaries
  // back by the same offset -- so todayStart/todayEnd remain UTC DateTimes
  // directly comparable against hourly's UTC timestamps.
  final DateTime nowLocal = toLocationLocal(now, uvData.timezoneOffset);
  final Duration locationOffset = Duration(seconds: uvData.timezoneOffset);
  final DateTime todayStart = DateTime.utc(
    nowLocal.year,
    nowLocal.month,
    nowLocal.day,
  ).subtract(locationOffset);
  final DateTime todayEnd = todayStart.add(const Duration(days: 1));

  // past/future/today are three views over the same sorted list -- built in
  // a single pass since each entry can be classified independently instead
  // of scanning `sorted` three separate times.
  final List<UvForecastEntry> past = <UvForecastEntry>[];
  final List<UvForecastEntry> future = <UvForecastEntry>[];
  final List<UvForecastEntry> today = <UvForecastEntry>[];

  for (final UvForecastEntry e in sorted) {
    if (e.time.isAfter(now)) {
      future.add(e);
    } else {
      past.add(e);
    }

    if (!e.time.isBefore(todayStart) && e.time.isBefore(todayEnd)) {
      today.add(e);
    }
  }

  // Branch 6: "UV index will exceed 2 at [time]" -- the nearest future
  // entry whose uvi first crosses above heroRisingUvThreshold, within the
  // look-ahead window, when the most recent known reading is not already
  // above it.
  final double? currentUvi = past.isNotEmpty
      ? past.last.uvi
      : (future.isNotEmpty ? future.first.uvi : null);

  if (currentUvi != null && currentUvi <= heroRisingUvThreshold) {
    final UvForecastEntry? crossing = _firstFutureCrossing(
      future,
      now: now,
      crosses: (UvForecastEntry e) => e.uvi > heroRisingUvThreshold,
    );

    if (crossing != null) {
      return 'UV index will exceed $heroRisingUvThreshold at '
          '${formatTime(crossing.time)}';
    }
  }

  // Branch 7: "UV index reached 3 at [time]" -- the most recent past entry
  // where uvi crossed up to/above heroUnsafeUvThreshold, when the current
  // reading is still at/above it (i.e. we're in the unsafe window that
  // crossing started).
  if (currentUvi != null && currentUvi >= heroUnsafeUvThreshold) {
    final UvForecastEntry? crossing = _mostRecentCrossing(
      past,
      wasBelow: (UvForecastEntry e) => e.uvi < heroUnsafeUvThreshold,
      isAt: (UvForecastEntry e) => e.uvi >= heroUnsafeUvThreshold,
    );

    if (crossing != null) {
      return 'UV index reached $heroUnsafeUvThreshold at '
          '${formatTime(crossing.time)}';
    }
  }

  // Branch 8: "Today's peak: UV [x] at [time]" -- the max uvi among
  // `today` (built above, in the location's local calendar day).
  if (today.isNotEmpty) {
    final UvForecastEntry peak = today.reduce(
      (UvForecastEntry a, UvForecastEntry b) => b.uvi > a.uvi ? b : a,
    );
    // Only surface the peak once it has actually occurred -- otherwise this
    // would announce a future peak as though it already happened.
    if (!now.isBefore(peak.time)) {
      final String peakUvi = truncateToTenth(peak.uvi).toStringAsFixed(1);
      return "Today's peak: UV $peakUvi at ${formatTime(peak.time)}";
    }
  }

  // Branch 9: "UV index will drop below 3 within the hour" -- a future
  // entry within heroLookAheadWindow drops below heroUnsafeUvThreshold
  // while the current reading is still at/above it.
  if (currentUvi != null && currentUvi >= heroUnsafeUvThreshold) {
    final UvForecastEntry? crossing = _firstFutureCrossing(
      future,
      now: now,
      crosses: (UvForecastEntry e) => e.uvi < heroUnsafeUvThreshold,
    );

    if (crossing != null) {
      return 'UV index will drop below $heroUnsafeUvThreshold within '
          'the hour';
    }
  }

  // Branch 10: "UV index dropped below 3 at [time]" -- the most recent past
  // entry where uvi crossed down below heroUnsafeUvThreshold, when the
  // current reading is still below it.
  if (currentUvi != null && currentUvi < heroUnsafeUvThreshold) {
    final UvForecastEntry? crossing = _mostRecentCrossing(
      past,
      wasBelow: (UvForecastEntry e) => e.uvi >= heroUnsafeUvThreshold,
      isAt: (UvForecastEntry e) => e.uvi < heroUnsafeUvThreshold,
    );

    if (crossing != null) {
      return 'UV index dropped below $heroUnsafeUvThreshold at '
          '${formatTime(crossing.time)}';
    }
  }

  return null;
}

/// The most recent entry in [past] (assumed sorted oldest-to-newest) where
/// the entry before it satisfies [wasBelow] and the entry itself satisfies
/// [isAt] -- i.e. the start of the current run of [isAt]-satisfying entries.
///
/// Starts comparing at index 1: with no earlier entry to compare against,
/// `past[0]` alone can't tell us whether/when a crossing happened, only
/// that it already satisfies [isAt] -- so it is deliberately never reported
/// as a crossing.
///
/// Shared by branch 7 ("reached [heroUnsafeUvThreshold]", crossing up) and
/// branch 10 ("dropped below [heroUnsafeUvThreshold]", crossing down),
/// which differ only in the direction of [wasBelow]/[isAt].
UvForecastEntry? _mostRecentCrossing(
  List<UvForecastEntry> past, {
  required bool Function(UvForecastEntry e) wasBelow,
  required bool Function(UvForecastEntry e) isAt,
}) {
  UvForecastEntry? crossing;

  for (int i = 1; i < past.length; i++) {
    if (wasBelow(past[i - 1]) && isAt(past[i])) {
      crossing = past[i];
    }
  }

  return crossing;
}

/// The earliest entry in [future] (assumed sorted oldest-to-newest) within
/// [heroLookAheadWindow] of [now] that satisfies [crosses], or `null` if
/// none does before the window closes.
///
/// Shared by branch 6 ("will exceed [heroRisingUvThreshold]") and branch 9
/// ("will drop below [heroUnsafeUvThreshold]"), which differ only in the
/// [crosses] predicate and how the result is worded.
UvForecastEntry? _firstFutureCrossing(
  List<UvForecastEntry> future, {
  required DateTime now,
  required bool Function(UvForecastEntry e) crosses,
}) {
  for (final UvForecastEntry e in future) {
    if (e.time.difference(now) > heroLookAheadWindow) break;

    if (crosses(e)) return e;
  }

  return null;
}
