import 'package:uvalert/providers/location_provider.dart';

import 'fake_geolocator.dart';

/// LocationNotifier with a fixed starting lat/lon, mirroring a location that
/// was already confirmed during a prior visit to LocationOnboardingScreen.
///
/// The constructor's `platform` defaults to a bare [FakeGeolocatorPlatform];
/// pass one with its `positionResult` set to exercise a subsequent GPS fetch
/// returning a different position than the fixed starting one (e.g. a
/// silent GPS refresh of a restored confirmation).
class FakeFixedLocationNotifier extends LocationNotifier {
  /// Creates a [FakeFixedLocationNotifier].
  FakeFixedLocationNotifier({FakeGeolocatorPlatform? platform})
    : super(platform: platform ?? FakeGeolocatorPlatform());

  @override
  LocationState build() => (lat: 36.75, lon: -119.65);
}
