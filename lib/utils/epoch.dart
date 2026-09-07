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
/// to skip a malformed payload entry also catch this case, rather than
/// either an uncaught [RangeError] from [DateTime.fromMillisecondsSinceEpoch]
/// or a silently-wrapped, wrong [DateTime] from integer overflow in the
/// seconds-to-milliseconds multiplication.
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
