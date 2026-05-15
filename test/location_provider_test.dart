import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uvalert/providers/location_provider.dart';

// ---------------------------------------------------------------------------
// Mocks
//
// GeolocatorPlatform is the abstract class that Geolocator.checkPermission(),
// requestPermission(), and getCurrentPosition() all delegate to. By swapping
// GeolocatorPlatform.instance with a Mock we intercept every GPS call without
// touching real hardware.
// ---------------------------------------------------------------------------

// plugin_platform_interface requires that the mock *extends* GeolocatorPlatform
// (not merely implements it), so we use `extends ... with Mock` rather than
// `extends Mock implements ...`.
class _MockGeolocatorPlatform extends GeolocatorPlatform with Mock {}

// A helper that builds an isolated Riverpod container.
// ProviderContainer is the non-Flutter equivalent of ProviderScope — no
// widget tree required. We create a fresh one per test so state never leaks.
ProviderContainer _makeContainer() => ProviderContainer();

// Minimal Position with only the fields our code touches (lat/lon).
Position _fakePosition({double lat = 1.0, double lon = 2.0}) => Position(
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

void main() {
  late _MockGeolocatorPlatform mock;

  setUp(() {
    mock = _MockGeolocatorPlatform();
    // Inject the mock so every Geolocator.* call hits our stub.
    GeolocatorPlatform.instance = mock;
  });

  tearDown(() {
    // Let Riverpod clean up subscriptions.
    // Containers created in each test are disposed there.
  });

  // -------------------------------------------------------------------------
  // Initial state
  // -------------------------------------------------------------------------

  test('initial state is null', () {
    final ProviderContainer container = _makeContainer();
    addTearDown(container.dispose);

    expect(container.read(locationProvider), isNull);
  });

  // -------------------------------------------------------------------------
  // setManual
  // -------------------------------------------------------------------------

  test('setManual updates state with supplied coordinates', () {
    final ProviderContainer container = _makeContainer();
    addTearDown(container.dispose);

    container
        .read(locationProvider.notifier)
        .setManual(lat: 51.5, lon: -0.1);

    final LocationState state = container.read(locationProvider);
    expect(state, isNotNull);
    expect(state!.lat, 51.5);
    expect(state.lon, -0.1);
  });

  // -------------------------------------------------------------------------
  // fetchGps — permission already granted
  // -------------------------------------------------------------------------

  test('fetchGps stores position when permission is already granted', () async {
    when(
      () => mock.checkPermission(),
    ).thenAnswer((_) async => LocationPermission.always);

    when(
      () => mock.getCurrentPosition(
        locationSettings: any(named: 'locationSettings'),
      ),
    ).thenAnswer((_) async => _fakePosition(lat: 10, lon: 20));

    final ProviderContainer container = _makeContainer();
    addTearDown(container.dispose);

    await container.read(locationProvider.notifier).fetchGps();

    final LocationState state = container.read(locationProvider);
    expect(state, isNotNull);
    expect(state!.lat, 10.0);
    expect(state.lon, 20.0);
  });

  // -------------------------------------------------------------------------
  // fetchGps — permission initially denied then granted
  // -------------------------------------------------------------------------

  test('fetchGps requests permission when initially denied', () async {
    when(
      () => mock.checkPermission(),
    ).thenAnswer((_) async => LocationPermission.denied);

    when(
      () => mock.requestPermission(),
    ).thenAnswer((_) async => LocationPermission.whileInUse);

    when(
      () => mock.getCurrentPosition(
        locationSettings: any(named: 'locationSettings'),
      ),
    ).thenAnswer((_) async => _fakePosition(lat: 3, lon: 4));

    final ProviderContainer container = _makeContainer();
    addTearDown(container.dispose);

    await container.read(locationProvider.notifier).fetchGps();

    final LocationState state = container.read(locationProvider);
    expect(state!.lat, 3.0);
    expect(state.lon, 4.0);
  });

  // -------------------------------------------------------------------------
  // fetchGps — permission denied forever
  // -------------------------------------------------------------------------

  test('fetchGps throws PermissionDeniedException when denied forever', () {
    when(
      () => mock.checkPermission(),
    ).thenAnswer((_) async => LocationPermission.deniedForever);

    final ProviderContainer container = _makeContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(locationProvider.notifier).fetchGps(),
      throwsA(isA<PermissionDeniedException>()),
    );
  });

  // -------------------------------------------------------------------------
  // fetchGps — request returns denied
  // -------------------------------------------------------------------------

  test('fetchGps throws PermissionDeniedException when request is denied', () {
    when(
      () => mock.checkPermission(),
    ).thenAnswer((_) async => LocationPermission.denied);

    when(
      () => mock.requestPermission(),
    ).thenAnswer((_) async => LocationPermission.denied);

    final ProviderContainer container = _makeContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(locationProvider.notifier).fetchGps(),
      throwsA(isA<PermissionDeniedException>()),
    );
  });
}
