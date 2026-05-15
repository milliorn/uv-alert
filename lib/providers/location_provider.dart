import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Latitude/longitude pair; `null` until a location is acquired.
typedef LocationState = ({double lat, double lon})?;

/// Riverpod provider for [LocationNotifier].
final NotifierProvider<LocationNotifier, LocationState> locationProvider =
    NotifierProvider<LocationNotifier, LocationState>(LocationNotifier.new);

/// Manages location state.
class LocationNotifier extends Notifier<LocationState> {
  @override
  LocationState build() => null;

  /// Requests GPS permission then acquires the current position.
  Future<void> fetchGps() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      throw const PermissionDeniedException('Location permission denied.');
    }

    final Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );

    state = (lat: position.latitude, lon: position.longitude);
  }

  /// Overrides state with manually supplied coordinates.
  void setManual({required double lat, required double lon}) {
    state = (lat: lat, lon: lon);
  }
}
