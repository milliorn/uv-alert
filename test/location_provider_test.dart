import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uvalert/providers/location_provider.dart';

// ---------------------------------------------------------------------------
// Fake GeolocatorPlatform
//
// plugin_platform_interface requires the mock to *extend* GeolocatorPlatform,
// not merely implement it, so Mocktail cannot be used here. We use a hand-
// rolled fake instead. Each field can be set per-test before fetchGps() runs.
// ---------------------------------------------------------------------------

class _FakePlatform extends GeolocatorPlatform {
  LocationPermission checkResult = LocationPermission.always;
  LocationPermission requestResult = LocationPermission.always;
  Position? positionResult;

  @override
  Future<LocationPermission> checkPermission() async => checkResult;

  @override
  Future<LocationPermission> requestPermission() async => requestResult;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (positionResult == null) {
      throw StateError('_FakePlatform: positionResult not set for this test');
    }
    return positionResult!;
  }
}

// Minimal Position with only the fields our code touches (lat/lon).
Position _fakePosition({double lat = 1, double lon = 2}) => Position(
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

// Builds a ProviderContainer with a LocationNotifier wired to the given fake.
// Using `overrideWith` lets us inject a custom notifier instance while keeping
// the rest of the Riverpod graph untouched.
ProviderContainer _makeContainer(_FakePlatform platform) {
  return ProviderContainer(
    // ignore: always_specify_types — Override is not in flutter_riverpod's public API
    overrides: [
      locationProvider.overrideWith(() => LocationNotifier(platform: platform)),
    ],
  );
}

void main() {
  // -------------------------------------------------------------------------
  // Initial state
  // -------------------------------------------------------------------------

  test('initial state is null', () {
    final ProviderContainer container = _makeContainer(_FakePlatform());
    addTearDown(container.dispose);

    expect(container.read(locationProvider), isNull);
  });

  // -------------------------------------------------------------------------
  // setManual
  // -------------------------------------------------------------------------

  test('setManual updates state with supplied coordinates', () {
    final ProviderContainer container = _makeContainer(_FakePlatform());
    addTearDown(container.dispose);

    container.read(locationProvider.notifier).setManual(lat: 51.5, lon: -0.1);

    final LocationState state = container.read(locationProvider);
    expect(state, isNotNull);
    expect(state!.lat, 51.5);
    expect(state.lon, -0.1);
  });

  // -------------------------------------------------------------------------
  // fetchGps — permission already granted
  // -------------------------------------------------------------------------

  test('fetchGps stores position when permission is already granted', () async {
    final _FakePlatform platform = _FakePlatform()
      ..checkResult = LocationPermission.always
      ..positionResult = _fakePosition(lat: 10, lon: 20);

    final ProviderContainer container = _makeContainer(platform);
    addTearDown(container.dispose);

    await container.read(locationProvider.notifier).fetchGps();

    final LocationState state = container.read(locationProvider);
    expect(state, isNotNull);
    expect(state!.lat, 10);
    expect(state.lon, 20);
  });

  // -------------------------------------------------------------------------
  // fetchGps — permission initially denied then granted
  // -------------------------------------------------------------------------

  test('fetchGps requests permission when initially denied', () async {
    final _FakePlatform platform = _FakePlatform()
      ..checkResult = LocationPermission.denied
      ..requestResult = LocationPermission.whileInUse
      ..positionResult = _fakePosition(lat: 3, lon: 4);

    final ProviderContainer container = _makeContainer(platform);
    addTearDown(container.dispose);

    await container.read(locationProvider.notifier).fetchGps();

    final LocationState state = container.read(locationProvider);
    expect(state!.lat, 3);
    expect(state.lon, 4);
  });

  // -------------------------------------------------------------------------
  // fetchGps — permission denied forever
  // -------------------------------------------------------------------------

  test('fetchGps throws PermissionDeniedException when denied forever',
      () async {
    final _FakePlatform platform = _FakePlatform()
      ..checkResult = LocationPermission.deniedForever;

    final ProviderContainer container = _makeContainer(platform);
    addTearDown(container.dispose);

    await expectLater(
      container.read(locationProvider.notifier).fetchGps(),
      throwsA(isA<PermissionDeniedException>()),
    );
  });

  // -------------------------------------------------------------------------
  // fetchGps — request returns denied
  // -------------------------------------------------------------------------

  test('fetchGps throws PermissionDeniedException when request is denied',
      () async {
    final _FakePlatform platform = _FakePlatform()
      ..checkResult = LocationPermission.denied
      ..requestResult = LocationPermission.denied;

    final ProviderContainer container = _makeContainer(platform);
    addTearDown(container.dispose);

    await expectLater(
      container.read(locationProvider.notifier).fetchGps(),
      throwsA(isA<PermissionDeniedException>()),
    );
  });

  // -------------------------------------------------------------------------
  // Default constructor — covers the ?? GeolocatorPlatform.instance fallback
  // -------------------------------------------------------------------------

  test('default constructor uses GeolocatorPlatform.instance', () async {
    final _FakePlatform fake = _FakePlatform()
      ..checkResult = LocationPermission.always
      ..positionResult = _fakePosition(lat: 5, lon: 6);

    final GeolocatorPlatform original = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = fake;
    addTearDown(() => GeolocatorPlatform.instance = original);

    final ProviderContainer container = ProviderContainer(
      // ignore: always_specify_types — Override is not in flutter_riverpod's public API
      overrides: [
        locationProvider.overrideWith(LocationNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await container.read(locationProvider.notifier).fetchGps();

    final LocationState state = container.read(locationProvider);
    expect(state!.lat, 5);
    expect(state.lon, 6);
  });
}
