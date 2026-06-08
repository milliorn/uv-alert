import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uvalert/providers/location_provider.dart';

import 'fakes/fake_geolocator.dart';

// Builds a ProviderContainer with a LocationNotifier wired to the given fake.
// Using `overrideWith` lets us inject a custom notifier instance while keeping
// the rest of the Riverpod graph untouched.
ProviderContainer _makeContainer(FakeGeolocatorPlatform platform) {
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
    final ProviderContainer container = _makeContainer(
      FakeGeolocatorPlatform(),
    );
    addTearDown(container.dispose);

    expect(container.read(locationProvider), isNull);
  });

  // -------------------------------------------------------------------------
  // setManual
  // -------------------------------------------------------------------------

  test('setManual updates state with supplied coordinates', () {
    final ProviderContainer container = _makeContainer(
      FakeGeolocatorPlatform(),
    );
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
    final FakeGeolocatorPlatform platform = FakeGeolocatorPlatform()
      ..checkResult = LocationPermission.always
      ..positionResult = fakePosition(lat: 10, lon: 20);

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
    final FakeGeolocatorPlatform platform = FakeGeolocatorPlatform()
      ..checkResult = LocationPermission.denied
      ..requestResult = LocationPermission.whileInUse
      ..positionResult = fakePosition(lat: 3, lon: 4);

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

  test(
    'fetchGps throws PermissionDeniedException when denied forever',
    () async {
      final FakeGeolocatorPlatform platform = FakeGeolocatorPlatform()
        ..checkResult = LocationPermission.deniedForever;

      final ProviderContainer container = _makeContainer(platform);
      addTearDown(container.dispose);

      await expectLater(
        container.read(locationProvider.notifier).fetchGps(),
        throwsA(isA<PermissionDeniedException>()),
      );
    },
  );

  // -------------------------------------------------------------------------
  // fetchGps — request returns denied
  // -------------------------------------------------------------------------

  test(
    'fetchGps throws PermissionDeniedException when request is denied',
    () async {
      final FakeGeolocatorPlatform platform = FakeGeolocatorPlatform()
        ..checkResult = LocationPermission.denied
        ..requestResult = LocationPermission.denied;

      final ProviderContainer container = _makeContainer(platform);
      addTearDown(container.dispose);

      await expectLater(
        container.read(locationProvider.notifier).fetchGps(),
        throwsA(isA<PermissionDeniedException>()),
      );
    },
  );

  // -------------------------------------------------------------------------
  // Default constructor — covers the ?? GeolocatorPlatform.instance fallback
  // -------------------------------------------------------------------------

  test('default constructor uses GeolocatorPlatform.instance', () async {
    final FakeGeolocatorPlatform fake = FakeGeolocatorPlatform()
      ..checkResult = LocationPermission.always
      ..positionResult = fakePosition(lat: 5, lon: 6);

    final GeolocatorPlatform original = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = fake;
    addTearDown(() => GeolocatorPlatform.instance = original);

    final ProviderContainer container = ProviderContainer(
      // ignore: always_specify_types — Override is not in flutter_riverpod's public API
      overrides: [locationProvider.overrideWith(LocationNotifier.new)],
    );
    addTearDown(container.dispose);

    await container.read(locationProvider.notifier).fetchGps();

    final LocationState state = container.read(locationProvider);
    expect(state!.lat, 5);
    expect(state.lon, 6);
  });
}
