import 'dart:math' as math;

import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/services/solar_position.dart';

/// Number of degrees in a half circle (pi radians), used to convert between
/// degrees and radians.
const double _degreesPerHalfCircle = 180;

/// Converts [degrees] to radians.
double _degToRad(double degrees) => degrees * math.pi / _degreesPerHalfCircle;

/// The peak `hourly[].uvi` value for the location-local calendar day
/// containing [atUtc], or `data`'s current UV index if `data`'s hourly
/// forecast has no entry for that day.
///
/// `data`'s timezone offset (seconds) shifts [atUtc] and each hourly entry's
/// time into the location's local time before comparing calendar dates, so
/// an hourly entry just after UTC midnight but still within the location's
/// "today" (or vice versa) is bucketed correctly.
double _peakUviForDay(UvData data, DateTime atUtc) {
  final Duration offset = Duration(seconds: data.timezoneOffset);
  final DateTime localToday = _localDate(atUtc, offset);

  final Iterable<double> todaysUvi = data.hourly
      .where(
        (UvForecastEntry entry) => _localDate(entry.time, offset) == localToday,
      )
      .map((UvForecastEntry entry) => entry.uvi);

  if (todaysUvi.isEmpty) return data.currentUvi;

  return todaysUvi.reduce(math.max);
}

/// The location-local calendar date (time-of-day truncated) for UTC time
/// [utc] shifted by [offset].
DateTime _localDate(DateTime utc, Duration offset) {
  final DateTime local = utc.add(offset);
  return DateTime.utc(local.year, local.month, local.day);
}

/// Estimates the current UV index between polls, using solar position math
/// applied to the hourly forecast anchors already present in [data].
///
/// Per `docs/adr/0012-uv-interpolation-between-polls.md`:
/// 1. The peak `hourly[].uvi` for the location-local day containing [atUtc]
///    is used as `UVmax` (falls back to `data.currentUvi` if no hourly data
///    covers that day).
/// 2. The sun's elevation angle at [lat]/[lon]/[atUtc] scales that peak via
///    `UVmax * sin(elevation)`.
/// 3. The sun below the horizon (elevation <= 0) always yields 0, regardless
///    of `UVmax` -- there is no UV at night.
/// 4. The conservative (higher) of the interpolated estimate and
///    `data.currentUvi` is returned, so a transient dip in the model never
///    under-reports actual risk.
///
/// Cloud cover is not modeled (see ADR 0012) -- this assumes clear sky
/// between polls, which may overestimate UV on cloudy days. That is the
/// deliberate, conservative choice: it never leads a user to underestimate
/// their exposure.
double interpolatedUvi({
  required UvData data,
  required double lat,
  required double lon,
  required DateTime atUtc,
}) {
  final double elevationDegrees = solarElevationDegrees(
    lat: lat,
    lon: lon,
    utcTime: atUtc,
  );

  if (elevationDegrees <= 0) return 0;

  final double uvMax = _peakUviForDay(data, atUtc);
  final double estimate = uvMax * math.sin(_degToRad(elevationDegrees));

  return math.max(estimate, data.currentUvi);
}
