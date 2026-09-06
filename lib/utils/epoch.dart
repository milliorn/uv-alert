import 'package:uvalert/constants.dart';

/// Converts Unix epoch seconds [s] to a UTC [DateTime].
///
/// Shared by any model that deserializes OpenWeatherMap's epoch-seconds
/// timestamps (e.g. `UvData`, `UvForecastEntry`, `WeatherAlert`), so the
/// conversion logic lives in exactly one place.
DateTime fromEpochSeconds(int s) =>
    DateTime.fromMillisecondsSinceEpoch(s * msPerSecond, isUtc: true);

/// Converts a [DateTime] to Unix epoch seconds.
///
/// The inverse of [fromEpochSeconds].
int toEpochSeconds(DateTime dt) => dt.millisecondsSinceEpoch ~/ msPerSecond;
