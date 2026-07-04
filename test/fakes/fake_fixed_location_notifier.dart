import 'package:uvalert/providers/location_provider.dart';

import 'fake_geolocator.dart';

/// LocationNotifier with a fixed starting lat/lon, mirroring a location that
/// was already confirmed during a prior visit to LocationOnboardingScreen.
class FakeFixedLocationNotifier extends LocationNotifier {
  /// Creates a [FakeFixedLocationNotifier].
  FakeFixedLocationNotifier() : super(platform: FakeGeolocatorPlatform());

  @override
  LocationState build() => (lat: 36.75, lon: -119.65);
}
