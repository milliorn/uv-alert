import 'dart:math' as math;

/// Number of degrees in a half circle (pi radians), used to convert between
/// degrees and radians.
const double _degreesPerHalfCircle = 180;

/// Number of degrees in a full circle, used to map day-of-year onto a
/// fraction of the Earth's full orbital cycle in the declination formula.
const double _degreesPerCircle = 360;

/// Approximate solar declination amplitude (degrees) -- the sun's maximum
/// angular distance north/south of the celestial equator over the year.
const double _declinationAmplitudeDegrees = 23.45;

/// Approximate number of days in a year, used to convert day-of-year into a
/// fraction of a full orbital cycle for the declination formula.
const double _daysPerYear = 365;

/// Day-of-year offset for the declination formula, chosen so the sine wave
/// crosses zero near the spring equinox (day ~81, March 22).
const int _declinationDayOffset = 81;

/// Degrees of hour angle the Earth rotates through per hour (360 degrees /
/// 24 hours).
const double _degreesPerHour = 15;

/// The hour angle is zero (solar noon) at local solar hour 12.
const double _solarNoonHour = 12;

/// Number of minutes in an hour, used to convert [DateTime.minute] into a
/// fractional-hour component.
const double _minutesPerHour = 60;

/// Number of seconds in an hour, used to convert [DateTime.second] into a
/// fractional-hour component.
const double _secondsPerHour = 3600;

/// Number of milliseconds in an hour, used to convert [DateTime.millisecond]
/// into a fractional-hour component.
const double _millisecondsPerHour = 3600000;

/// Elevation angle (degrees) marking the start of the visible solar disc at
/// sunrise / end of sunset, accounting for atmospheric refraction and the
/// disc's own radius.
const double _sunriseStartElevationDegrees = -0.833;

/// Elevation angle (degrees) marking the end of the visible solar disc at
/// sunrise / start of sunset -- the opposite boundary from
/// [_sunriseStartElevationDegrees], bracketing the ~2-minute solar disc
/// transit.
const double _sunriseEndElevationDegrees = 0.833;

/// Elevation angle (degrees) marking civil dawn/dusk -- standard
/// astronomical definition.
const double _civilElevationDegrees = -6;

/// Elevation angle (degrees) marking nautical dawn/dusk -- standard
/// astronomical definition.
const double _nauticalElevationDegrees = -12;

/// Elevation angle (degrees) marking astronomical dawn/dusk -- standard
/// astronomical definition.
const double _astronomicalElevationDegrees = -18;

/// Converts [degrees] to radians.
double _degToRad(double degrees) => degrees * math.pi / _degreesPerHalfCircle;

/// Converts [radians] to degrees.
double _radToDeg(double radians) => radians * _degreesPerHalfCircle / math.pi;

/// A named solar event during a day's light cycle.
///
/// Ordered chronologically as they occur over the course of a normal day,
/// from the earliest pre-dawn twilight to the latest post-dusk twilight.
enum SolarEvent {
  /// Start of astronomical twilight in the morning: the sun is 18 degrees
  /// below the horizon.
  astronomicalDawn,

  /// Start of nautical twilight in the morning: the sun is 12 degrees below
  /// the horizon.
  nauticalDawn,

  /// Start of civil twilight in the morning: the sun is 6 degrees below the
  /// horizon.
  civilDawn,

  /// The first moment the solar disc becomes visible above the horizon.
  sunriseStart,

  /// The moment the solar disc has fully cleared the horizon.
  sunriseEnd,

  /// The first moment the solar disc begins dipping below the horizon.
  sunsetStart,

  /// The moment the solar disc has fully disappeared below the horizon.
  sunset,

  /// End of civil twilight in the evening: the sun is 6 degrees below the
  /// horizon.
  civilDusk,

  /// End of nautical twilight in the evening: the sun is 12 degrees below
  /// the horizon.
  nauticalDusk,

  /// End of astronomical twilight in the evening: the sun is 18 degrees
  /// below the horizon.
  astronomicalDusk,
}

/// The target solar elevation (degrees) and whether it occurs in the
/// morning (ascending) or evening (descending) half of the day, for each
/// [SolarEvent].
const Map<SolarEvent, ({double elevationDegrees, bool isMorning})>
_eventDefinitions = <SolarEvent, ({double elevationDegrees, bool isMorning})>{
  SolarEvent.astronomicalDawn: (
    elevationDegrees: _astronomicalElevationDegrees,
    isMorning: true,
  ),
  SolarEvent.nauticalDawn: (
    elevationDegrees: _nauticalElevationDegrees,
    isMorning: true,
  ),
  SolarEvent.civilDawn: (
    elevationDegrees: _civilElevationDegrees,
    isMorning: true,
  ),
  SolarEvent.sunriseStart: (
    elevationDegrees: _sunriseStartElevationDegrees,
    isMorning: true,
  ),
  SolarEvent.sunriseEnd: (
    elevationDegrees: _sunriseEndElevationDegrees,
    isMorning: true,
  ),
  SolarEvent.sunsetStart: (
    elevationDegrees: _sunriseEndElevationDegrees,
    isMorning: false,
  ),
  SolarEvent.sunset: (
    elevationDegrees: _sunriseStartElevationDegrees,
    isMorning: false,
  ),
  SolarEvent.civilDusk: (
    elevationDegrees: _civilElevationDegrees,
    isMorning: false,
  ),
  SolarEvent.nauticalDusk: (
    elevationDegrees: _nauticalElevationDegrees,
    isMorning: false,
  ),
  SolarEvent.astronomicalDusk: (
    elevationDegrees: _astronomicalElevationDegrees,
    isMorning: false,
  ),
};

/// The day-of-year for [date], where January 1st is day 1.
///
/// [date] is converted to UTC internally, so callers may pass a [DateTime]
/// in any time zone. Computed relative to the start of that UTC year so it
/// is unaffected by [date]'s time-of-day component.
int _dayOfYear(DateTime date) {
  final DateTime utc = date.toUtc();
  return utc.difference(DateTime.utc(utc.year)).inDays + 1;
}

/// The approximate solar declination (degrees) on the given day-of-year,
/// using a single-sine-wave approximation (not a full ephemeris).
double _solarDeclinationDegrees(int dayOfYear) {
  final double fractionOfYear =
      (_degreesPerCircle / _daysPerYear) * (dayOfYear - _declinationDayOffset);
  return _declinationAmplitudeDegrees * math.sin(_degToRad(fractionOfYear));
}

/// Computes the UTC [DateTime] for [SolarEvent] at [lat]/[lon] on [date],
/// or `null` if that event does not occur that day (e.g. polar day/night).
///
/// The returned map always has all 10 [SolarEvent] keys, but values are
/// only guaranteed non-null away from the polar circles -- callers must
/// null-check each lookup (e.g. `events[SolarEvent.sunset]`) rather than
/// force-unwrapping, since any event can be `null` near the poles.
///
/// [date] is converted to UTC before use, so its calendar day is always the
/// UTC calendar day regardless of the [DateTime]'s original time zone.
///
/// All angular math (declination, hour angle, elevation) is performed in
/// degrees and converted to radians immediately before any trigonometric
/// call. The returned times are derived from [lon] (`lon / 15` degrees of
/// longitude per hour of solar offset from UTC), not the location's IANA
/// timezone -- this service has no access to that.
///
/// [lat] must be finite and within `[-90, 90]`, and [lon] must be finite
/// and within `[-180, 180]`; violated, this throws [ArgumentError] in both
/// debug and release builds.
Map<SolarEvent, DateTime?> solarEventTimes({
  required double lat,
  required double lon,
  required DateTime date,
}) {
  if (!(lat.isFinite && lat >= -90 && lat <= 90)) {
    throw ArgumentError.value(
      lat,
      'lat',
      'must be finite and within [-90, 90]',
    );
  }

  if (!(lon.isFinite && lon >= -180 && lon <= 180)) {
    throw ArgumentError.value(
      lon,
      'lon',
      'must be finite and within [-180, 180]',
    );
  }

  final DateTime utc = date.toUtc();
  final int dayOfYear = _dayOfYear(utc);
  final double declinationDegrees = _solarDeclinationDegrees(dayOfYear);
  final DateTime utcMidnight = DateTime.utc(utc.year, utc.month, utc.day);

  return <SolarEvent, DateTime?>{
    for (final MapEntry<SolarEvent, ({double elevationDegrees, bool isMorning})>
        entry
        in _eventDefinitions.entries)
      entry.key: _eventTime(
        lat: lat,
        lon: lon,
        utcMidnight: utcMidnight,
        declinationDegrees: declinationDegrees,
        elevationDegrees: entry.value.elevationDegrees,
        isMorning: entry.value.isMorning,
      ),
  };
}

/// Solves for the UTC time [elevationDegrees] is reached at [lat]/[lon] on
/// the day starting at [utcMidnight], given the day's [declinationDegrees].
///
/// Returns `null` if the target elevation is never reached (the `acos`
/// argument would fall outside `[-1, 1]`), which happens during polar
/// day/night.
DateTime? _eventTime({
  required double lat,
  required double lon,
  required DateTime utcMidnight,
  required double declinationDegrees,
  required double elevationDegrees,
  required bool isMorning,
}) {
  final double latRad = _degToRad(lat);
  final double decRad = _degToRad(declinationDegrees);
  final double elevationRad = _degToRad(elevationDegrees);

  final double cosHourAngle =
      (math.sin(elevationRad) - math.sin(latRad) * math.sin(decRad)) /
      (math.cos(latRad) * math.cos(decRad));

  // Written as a positive containment check (rather than negated `< -1 ||
  // > 1`) so that NaN -- which compares `false` to every relational
  // operator -- correctly falls into the "return null" branch instead of
  // silently passing through to `acos`.
  if (!(cosHourAngle >= -1 && cosHourAngle <= 1)) return null;

  final double hourAngleDegrees = _radToDeg(math.acos(cosHourAngle));

  // acos returns [0, 180]; the morning crossing is at the negative hour
  // angle (before solar noon), the evening crossing at the positive one.
  final double signedHourAngleDegrees = isMorning
      ? -hourAngleDegrees
      : hourAngleDegrees;

  final double localSolarHour =
      _solarNoonHour + signedHourAngleDegrees / _degreesPerHour;

  // Longitude-based UTC offset: lon/15 gives hours east (+) or west (-) of
  // the prime meridian, so local solar time = UTC + lon/15, i.e.
  // UTC = local solar time - lon/15.
  final double utcHour = localSolarHour - lon / _degreesPerHour;

  return utcMidnight.add(
    Duration(microseconds: (utcHour * Duration.microsecondsPerHour).round()),
  );
}

/// Computes the sun's elevation angle above the horizon (degrees) at
/// [lat]/[lon] and the given [utcTime].
///
/// This is the inverse of [solarEventTimes]: given a time, it reports the
/// sun's elevation, using the same declination/hour-angle trigonometry via
/// shared private helpers. Negative values mean the sun is below the
/// horizon. The inverse relationship is only exact within a single UTC
/// calendar day -- feeding an evening [SolarEvent]'s time back in near a
/// UTC-day boundary may use a slightly different day-of-year's declination
/// than [solarEventTimes] used to derive that time, a sub-degree difference
/// well within this approximation's existing tolerance.
///
/// [lat] must be finite and within `[-90, 90]`, and [lon] must be finite
/// and within `[-180, 180]`; violated, this throws [ArgumentError] in both
/// debug and release builds.
double solarElevationDegrees({
  required double lat,
  required double lon,
  required DateTime utcTime,
}) {
  if (!(lat.isFinite && lat >= -90 && lat <= 90)) {
    throw ArgumentError.value(
      lat,
      'lat',
      'must be finite and within [-90, 90]',
    );
  }

  if (!(lon.isFinite && lon >= -180 && lon <= 180)) {
    throw ArgumentError.value(
      lon,
      'lon',
      'must be finite and within [-180, 180]',
    );
  }

  final DateTime utc = utcTime.toUtc();
  final int dayOfYear = _dayOfYear(utc);
  final double declinationDegrees = _solarDeclinationDegrees(dayOfYear);

  final double utcHourOfDay =
      utc.hour +
      utc.minute / _minutesPerHour +
      utc.second / _secondsPerHour +
      utc.millisecond / _millisecondsPerHour;

  final double localSolarHour = utcHourOfDay + lon / _degreesPerHour;
  final double hourAngleDegrees =
      (localSolarHour - _solarNoonHour) * _degreesPerHour;

  final double latRad = _degToRad(lat);
  final double decRad = _degToRad(declinationDegrees);
  final double hourAngleRad = _degToRad(hourAngleDegrees);

  final double sinElevation =
      math.sin(latRad) * math.sin(decRad) +
      math.cos(latRad) * math.cos(decRad) * math.cos(hourAngleRad);

  // Clamp before asin for the same reason acos is clamped in _eventTime:
  // floating-point drift could otherwise push the argument fractionally
  // outside [-1, 1] and produce NaN.
  final double clamped = sinElevation.clamp(-1.0, 1.0);

  return _radToDeg(math.asin(clamped));
}
