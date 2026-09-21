import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/storage/preferences.dart';

/// Maximum age of cached UV data in hours before it is considered stale.
const int cacheMaxAgeHours = 24;

/// Decimal places [Cache.locationKey] rounds coordinates to.
///
/// 2 decimal places is roughly 1.1km of latitude, comfortably coarser
/// than `LocationAccuracy.medium`'s ~100m jitter (see
/// `LocationNotifier.fetchGps` in `location_provider.dart`), so two GPS
/// fixes for the same physical spot round to the same key. UV index does
/// not meaningfully vary over a kilometer, so this loses no useful
/// precision for cache-matching purposes.
const int _locationKeyDecimals = 2;

/// SharedPreferences-backed cache for [UvData] with a
/// [cacheMaxAgeHours]-hour TTL, scoped to the coordinates it was fetched
/// for.
class Cache {
  /// Creates a [Cache] backed by the given [Preferences] instance.
  Cache(this._prefs);
  final Preferences _prefs;

  /// Encodes [lat]/[lon] into the string form the cache stores and compares
  /// against.
  ///
  /// Rounded to [_locationKeyDecimals] places (via `toStringAsFixed`, which
  /// is fixed-width and deterministic, unlike round-then-interpolate)
  /// rather than matching `UvApi.fetch`'s full-precision query parameters
  /// exactly. GPS mode re-acquires a fresh position on every fetch
  /// (`LocationNotifier.fetchGps`), and comparing raw, unrounded doubles
  /// would treat routine GPS jitter between fixes as a location change,
  /// defeating this cache almost entirely for GPS users.
  static String locationKey({required double lat, required double lon}) =>
      '${lat.toStringAsFixed(_locationKeyDecimals)},'
      '${lon.toStringAsFixed(_locationKeyDecimals)}';

  /// Persists [data] to the cache for the given [lat]/[lon], keying expiry
  /// on the server-provided [UvData.fetchedAt] timestamp.
  Future<void> store(
    UvData data, {
    required double lat,
    required double lon,
  }) async {
    final String json = jsonEncode(data.toJson());

    await Future.wait(<Future<void>>[
      _prefs.setCachedPayload(json),
      // Intentional: use server-provided fetchedAt, not DateTime.now().
      // If the server timestamp lags real time, the cache expires sooner than
      // cacheMaxAgeHours - acceptable given UV data changes infrequently.
      _prefs.setCachedPayloadAt(data.fetchedAt.toIso8601String()),
      _prefs.setCachedPayloadLocation(locationKey(lat: lat, lon: lon)),
    ]);
  }

  /// Returns the cached [UvData] for the given [lat]/[lon], or `null` if
  /// empty, the payload is corrupt, or the cached entry was stored for
  /// different coordinates.
  ///
  /// Clears the cache automatically on a corrupt or malformed payload.
  Future<UvData?> read({required double lat, required double lon}) async {
    final String? raw = _prefs.cachedPayload;

    if (raw == null) return null;

    if (_prefs.cachedPayloadLocation != locationKey(lat: lat, lon: lon)) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(raw);

      if (decoded is! Map<String, Object?>) {
        if (kDebugMode) debugPrint('Cache.read: unexpected payload shape');

        await _prefs.clearCache();
        return null;
      }
      return UvData.fromJson(decoded);
    } on Object catch (e) {
      if (kDebugMode) debugPrint('Cache.read: corrupt payload: $e');

      await _prefs.clearCache();
      return null;
    }
  }

  /// Whether the cached data has exceeded the [cacheMaxAgeHours]-hour TTL.
  ///
  /// Returns `true` when no timestamp is stored or the timestamp is corrupt.
  bool get isStale {
    final String? cachedAt = _prefs.cachedPayloadAt;

    if (cachedAt == null) return true;

    final DateTime fetched;

    try {
      fetched = DateTime.parse(cachedAt);
    } on FormatException {
      return true;
    }

    // No abs(): future fetched (clock skew) must appear fresh, not stale.
    return DateTime.now().toUtc().difference(fetched) >=
        const Duration(hours: cacheMaxAgeHours);
  }

  /// Whether no payload is currently stored.
  bool get isEmpty => _prefs.cachedPayload == null;

  /// Whether the cache has a payload for the given [lat]/[lon], it is
  /// within the TTL, and it was stored for those same coordinates.
  ///
  /// A cache entry written before location-keying existed has no stored
  /// location at all, which compares unequal to any real [locationKey] and
  /// so is correctly treated as a miss here, not a match.
  bool isValid({required double lat, required double lon}) =>
      !isEmpty &&
      !isStale &&
      _prefs.cachedPayloadLocation == locationKey(lat: lat, lon: lon);
}
