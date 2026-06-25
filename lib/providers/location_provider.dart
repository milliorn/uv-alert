import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uvalert/constants.dart';

/// Latitude/longitude pair; `null` until a location is acquired.
typedef LocationState = ({double lat, double lon})?;

/// Riverpod provider for [LocationNotifier].
final NotifierProvider<LocationNotifier, LocationState> locationProvider =
    NotifierProvider<LocationNotifier, LocationState>(LocationNotifier.new);

/// Manages location state.
class LocationNotifier extends Notifier<LocationState> {
  /// Creates a [LocationNotifier]; [platform] defaults to
  /// [GeolocatorPlatform.instance] for production use.
  LocationNotifier({GeolocatorPlatform? platform})
    : _platform = platform ?? GeolocatorPlatform.instance;

  final GeolocatorPlatform _platform;

  @override
  LocationState build() => null;

  /// Requests GPS permission then acquires the current position.
  Future<void> fetchGps() async {
    LocationPermission permission = await _platform.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await _platform.requestPermission();
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      throw const PermissionDeniedException('Location permission denied.');
    }

    final Position position = await _platform
        .getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        )
        .timeout(apiDefaultTimeout);

    state = (lat: position.latitude, lon: position.longitude);
  }

  /// Overrides state with manually supplied coordinates.
  void setManual({required double lat, required double lon}) {
    state = (lat: lat, lon: lon);
  }
}
