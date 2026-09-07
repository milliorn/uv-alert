import 'package:uvalert/constants.dart';

/// The inclusive bound, in whole seconds, of epoch values [fromEpochSeconds]
/// can convert without its `s * msPerSecond` multiplication overflowing a
/// 64-bit [int] (which would silently wrap around rather than throw) or
/// exceeding the range [DateTime.fromMillisecondsSinceEpoch] can represent
/// (100,000,000 days before/after the Unix epoch, per [DateTime]'s docs).
const int _maxEpochSeconds = 8640000000000000 ~/ msPerSecond;

/// Converts Unix epoch seconds [s] to a UTC [DateTime].
///
/// Shared by any model that deserializes OpenWeatherMap's epoch-seconds
/// timestamps (e.g. `UvData`, `UvForecastEntry`, `WeatherAlert`), so the
/// conversion logic lives in exactly one place.
///
/// Throws [FormatException] if [s] is outside the range that can be
/// converted to a valid [DateTime], so callers that catch [FormatException]
/// to skip a malformed payload entry also catch this case. The check runs
/// on [s] itself, before the seconds-to-milliseconds multiplication below,
/// so an extreme [s] can't first silently overflow that multiplication (on
/// a native 64-bit [int], overflow wraps around rather than throwing) into
/// some in-range value that would then produce a wrong [DateTime] instead
/// of the intended [RangeError]/[FormatException].
DateTime fromEpochSeconds(int s) {
  if (s.abs() > _maxEpochSeconds) {
    throw FormatException('epoch seconds value out of range: $s');
  }
  return DateTime.fromMillisecondsSinceEpoch(s * msPerSecond, isUtc: true);
}

/// Converts a [DateTime] to Unix epoch seconds.
///
/// The inverse of [fromEpochSeconds].
int toEpochSeconds(DateTime dt) => dt.millisecondsSinceEpoch ~/ msPerSecond;
