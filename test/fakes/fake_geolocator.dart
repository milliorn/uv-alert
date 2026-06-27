import 'package:geolocator/geolocator.dart';

/// Configurable test double for [GeolocatorPlatform].
///
/// plugin_platform_interface requires extending GeolocatorPlatform rather than
/// implementing it, so Mocktail cannot be used here. Each field can be set
/// per-test before fetchGps() runs.
class FakeGeolocatorPlatform extends GeolocatorPlatform {
  LocationPermission checkResult = LocationPermission.always;
  LocationPermission requestResult = LocationPermission.always;
  Position? positionResult;
  // When set, getCurrentPosition waits this long before resolving.
  // In testWidgets (fakeAsync), advance simulated time with tester.pump(...) to
  // avoid real wall-clock delay. In plain test() calls the delay is real time.
  Duration? positionDelay;

  @override
  Future<LocationPermission> checkPermission() async => checkResult;

  @override
  Future<LocationPermission> requestPermission() async => requestResult;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (positionDelay != null) {
      await Future<void>.delayed(positionDelay!);
    }
    if (positionResult == null) {
      throw StateError(
        'FakeGeolocatorPlatform: positionResult not set for this test',
      );
    }
    return positionResult!;
  }
}

/// Builds a [Position] with sensible defaults for use in tests.
Position fakePosition({double lat = 1, double lon = 2}) => Position(
  latitude: lat,
  longitude: lon,
  timestamp: DateTime.utc(2024),
  accuracy: 0,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);
