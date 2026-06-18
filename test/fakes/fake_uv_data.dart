import 'package:mocktail/mocktail.dart';
import 'package:uvalert/models/uv_model.dart';

/// Mocktail fallback value for [UvData].
class FakeUvData extends Fake implements UvData {}

/// Canonical [UvData] fixture for tests.
///
/// Field values are arbitrary; override only the ones your test cares about.
UvData makeUvData({
  double currentUvi = 5,
  DateTime? sunrise,
  DateTime? sunset,
  int clouds = 0,
  List<UvForecastEntry> hourly = const <UvForecastEntry>[],
  List<UvForecastEntry> daily = const <UvForecastEntry>[],
  String timezone = 'UTC',
  int timezoneOffset = 0,
  DateTime? fetchedAt,
}) {
  return UvData(
    currentUvi: currentUvi,
    sunrise: sunrise ?? DateTime.utc(2024, 6, 1, 6),
    sunset: sunset ?? DateTime.utc(2024, 6, 1, 20),
    clouds: clouds,
    hourly: hourly,
    daily: daily,
    timezone: timezone,
    timezoneOffset: timezoneOffset,
    fetchedAt: fetchedAt ?? DateTime.utc(2024, 6, 1, 12),
  );
}
