/// Formats [time] as e.g. "2:00 PM" (or "2 PM" when [includeMinutes] is
/// false), shared by the hourly chart's axis/semantic labels
/// (`lib/widgets/uv_hourly_chart.dart`) and the dashboard hero's
/// conditional line (`lib/services/hero_conditional_line.dart`) so both
/// always agree on time formatting.
String formatTime(DateTime time, {bool includeMinutes = true}) {
  final int hour24 = time.hour;
  final int hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final String period = hour24 < 12 ? 'AM' : 'PM';

  if (!includeMinutes) return '$hour12 $period';

  final String minutes = time.minute.toString().padLeft(2, '0');

  return '$hour12:$minutes $period';
}

/// Abbreviated month names for [formatDate], indexed by [DateTime.month]
/// (1-12); index 0 is unused padding so the array can be indexed directly
/// without an off-by-one subtraction at each call site.
const List<String> _monthAbbreviations = <String>[
  '',
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Formats [time]'s calendar date as e.g. "Jun 1". No `intl` dependency is
/// used elsewhere in this codebase for date formatting (only [formatTime]
/// for time-of-day), so this follows the same hand-rolled convention rather
/// than introducing one. [time] should already be in the location-local
/// time this label is meant to represent (see [toLocationLocal]); this
/// function only reads off whatever date fields it is given.
String formatDate(DateTime time) =>
    '${_monthAbbreviations[time.month]} ${time.day}';

/// Converts a UTC [time] to a location's local time, using
/// [timezoneOffsetSeconds] (i.e. `UvData.timezoneOffset`) rather than the
/// device's own timezone, so callers reflect the queried location's day
/// rather than the viewer's. Shared by `UvHourlyChart`, `UvDailyChart`, and
/// `heroConditionalLine`'s "today's peak" branch, all of which need the
/// location's local calendar day rather than `now`'s UTC calendar day.
///
/// [time] is converted to UTC first (a no-op if it already is) so the
/// result is always UTC-flagged, matching callers that rely on that
/// invariant (e.g. `UvDailyChart`'s use of `add()` preserving `isUtc`).
DateTime toLocationLocal(DateTime time, int timezoneOffsetSeconds) =>
    time.toUtc().add(Duration(seconds: timezoneOffsetSeconds));

/// The UTC instant of local midnight, for the location-local calendar day
/// containing [time], per [timezoneOffsetSeconds].
///
/// Callers that need "today" for a location as an actual point in time to
/// compare against other UTC timestamps (e.g. bucketing hourly forecast
/// entries by whether they fall on or after local midnight) should use
/// this rather than [time]'s own UTC calendar day: for a location far
/// enough from UTC, [time]'s UTC day and the location's local day can
/// disagree, especially near local midnight.
///
/// A caller that instead needs to read off the location-local calendar
/// *date fields* (e.g. anchoring a `solarEventTimes`-style calculation,
/// which extracts its own UTC year/month/day from whatever instant it is
/// given) should use [toLocationLocal] directly, not this function: its
/// result is local midnight itself, so re-reading its UTC date fields
/// yields the day before the intended local date whenever the location's
/// offset is positive.
///
/// The result stays a UTC [DateTime] (comparable directly against other UTC
/// timestamps) even though it represents the location's local midnight,
/// computed by finding [time]'s local calendar date via [toLocationLocal]
/// and shifting that date's own UTC midnight back by the same offset.
DateTime startOfLocationLocalDayUtc(DateTime time, int timezoneOffsetSeconds) {
  final DateTime local = toLocationLocal(time, timezoneOffsetSeconds);
  final DateTime localMidnightAsUtc = DateTime.utc(
    local.year,
    local.month,
    local.day,
  );

  return localMidnightAsUtc.subtract(
    Duration(seconds: timezoneOffsetSeconds),
  );
}
