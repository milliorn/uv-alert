import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/providers/location_provider.dart';
import 'package:uvalert/services/solar_position.dart';
import 'package:uvalert/utils/angle_math.dart';
import 'package:uvalert/utils/time_format.dart';

/// Solar elevation at or below which the sun is considered below the
/// horizon, per ADR 0012 decision point 3 -- no direct-sun UV contribution
/// at or below this elevation.
const double _horizonElevationDegrees = 0;

/// The solar-driven UV contribution once the sun is below the horizon
/// ([_horizonElevationDegrees]): always zero, since there is no direct
/// sunlight to derive a UV estimate from.
const double _noDirectSunUvi = 0;

/// The peak `hourly[].uvi` value for the location-local calendar day
/// containing [atUtc], or `data`'s current UV index if `data`'s hourly
/// forecast has no entry for that day.
///
/// `data`'s timezone offset (seconds), via [toLocationLocal], shifts [atUtc]
/// and each hourly entry's time into the location's local time before
/// comparing calendar dates, so an hourly entry just after UTC midnight but
/// still within the location's "today" (or vice versa) is bucketed
/// correctly.
///
/// Exposed (rather than kept private) so its `currentUvi` fallback is
/// directly testable: through [interpolatedUvi] alone, `sin(elevation) <= 1`
/// means the conservative-max step can never let the interpolated estimate
/// exceed `currentUvi`, so a broken fallback value can end up masked by
/// `currentUvi` winning the outer max regardless.
@visibleForTesting
double peakUviForDay(UvData data, DateTime atUtc) {
  final DateTime localToday = _localDate(atUtc, data.timezoneOffset);

  final Iterable<double> todaysUvi = data.hourly
      .where(
        (UvForecastEntry entry) =>
            _localDate(entry.time, data.timezoneOffset) == localToday,
      )
      .map((UvForecastEntry entry) => entry.uvi);

  if (todaysUvi.isEmpty) return data.currentUvi;

  return todaysUvi.reduce(math.max);
}

/// The location-local calendar date (time-of-day truncated) for UTC time
/// [utc], per [timezoneOffsetSeconds] (i.e. `UvData.timezoneOffset`).
DateTime _localDate(DateTime utc, int timezoneOffsetSeconds) {
  final DateTime local = toLocationLocal(utc, timezoneOffsetSeconds);
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
/// 3. The sun below the horizon (elevation <= 0) yields a solar estimate of
///    0, regardless of `UVmax` -- there is no direct-sun UV contribution at
///    night.
/// 4. The conservative (higher) of the interpolated estimate and
///    `data.currentUvi` is returned -- including at night, so a stale
///    non-zero `currentUvi` is never clobbered to 0 just because the sun has
///    set; a transient dip (or a zeroed-out night estimate) in the model
///    never under-reports actual risk.
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

  // No direct solar contribution once the sun is below the horizon -- but
  // this estimate is still subject to the conservative-max rule below, same
  // as any other low estimate: a stale non-zero currentUvi must not be
  // clobbered to 0 just because it's currently night at this location.
  final double estimate = elevationDegrees <= _horizonElevationDegrees
      ? _noDirectSunUvi
      : peakUviForDay(data, atUtc) * math.sin(degToRad(elevationDegrees));

  return _conservativeUvi(estimate, data.currentUvi);
}

/// Per ADR 0012 decision point 3: always report the higher of the
/// interpolated [estimate] and the last-known [currentUvi], even when they
/// diverge only slightly -- protecting user safety takes priority over
/// reporting the more "accurate" lower estimate.
double _conservativeUvi(double estimate, double currentUvi) =>
    math.max(estimate, currentUvi);

/// The UV index to display for [data] at [atUtc]: [interpolatedUvi] when
/// [location] is known, or `data.currentUvi` directly when it is not (no
/// coordinates yet means no solar elevation to interpolate against).
double displayUvi({
  required UvData data,
  required LocationState location,
  required DateTime atUtc,
}) => location == null
    ? data.currentUvi
    : interpolatedUvi(
        data: data,
        lat: location.lat,
        lon: location.lon,
        atUtc: atUtc,
      );
