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

/// Converts a UTC [time] to a location's local time, using
/// [timezoneOffsetSeconds] (i.e. `UvData.timezoneOffset`) rather than the
/// device's own timezone, so callers reflect the queried location's day
/// rather than the viewer's. Shared by `UvHourlyChart`, `UvDailyChart`, and
/// `heroConditionalLine`'s "today's peak" branch, all of which need the
/// location's local calendar day rather than `now`'s UTC calendar day.
DateTime toLocationLocal(DateTime time, int timezoneOffsetSeconds) =>
    time.add(Duration(seconds: timezoneOffsetSeconds));
