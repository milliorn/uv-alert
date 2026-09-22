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
  ///
  /// Written as a single [Preferences.setCachedEntry] call so the payload,
  /// timestamp, and location key can never be read back as a combination
  /// that wasn't actually written together, whether the interruption is a
  /// single call cut short (process death, browser tab close) or two
  /// `store` calls racing each other (`UvApi.fetch` calls can overlap when
  /// a location change supersedes an in-flight fetch, see the class doc
  /// on `UvApiFetchMeta`). Either way, whichever write actually lands is a
  /// complete, internally consistent entry; there is no window where a
  /// reader can observe one call's payload paired with another's location.
  Future<void> store(
    UvData data, {
    required double lat,
    required double lon,
  }) async {
    await _prefs.setCachedEntry((
      payload: jsonEncode(data.toJson()),
      // Intentional: use server-provided fetchedAt, not DateTime.now().
      // If the server timestamp lags real time, the cache expires sooner than
      // cacheMaxAgeHours - acceptable given UV data changes infrequently.
      at: data.fetchedAt.toIso8601String(),
      location: locationKey(lat: lat, lon: lon),
    ));
  }

  /// Returns the cached [UvData] for the given [lat]/[lon], or `null` if
  /// empty, the payload is corrupt, or the cached entry was stored for
  /// different coordinates.
  ///
  /// Clears the cache automatically on a corrupt or malformed payload.
  Future<UvData?> read({required double lat, required double lon}) async {
    final CachedUvEntry? entry = _prefs.cachedEntry;

    if (entry == null) return null;

    if (entry.location != locationKey(lat: lat, lon: lon)) return null;

    try {
      final Object? decoded = jsonDecode(entry.payload);

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
  /// Returns `true` when no entry is stored or its timestamp is corrupt.
  bool get isStale => _isStale(_prefs.cachedEntry);

  bool _isStale(CachedUvEntry? entry) {
    if (entry == null) return true;

    final DateTime fetched;

    try {
      fetched = DateTime.parse(entry.at);
    } on FormatException {
      return true;
    }

    // No abs(): future fetched (clock skew) must appear fresh, not stale.
    return DateTime.now().toUtc().difference(fetched) >=
        const Duration(hours: cacheMaxAgeHours);
  }

  /// Whether no entry is currently stored.
  bool get isEmpty => _prefs.cachedEntry == null;

  /// Whether the cache has an entry for the given [lat]/[lon], it is within
  /// the TTL, and it was stored for those same coordinates.
  ///
  /// A cache entry written before location-keying existed is unreadable as
  /// a [CachedUvEntry] at all (see [Preferences.cachedEntry]), so it is
  /// correctly treated as a miss here, not a match.
  bool isValid({required double lat, required double lon}) {
    final CachedUvEntry? entry = _prefs.cachedEntry;

    return entry != null &&
        !_isStale(entry) &&
        entry.location == locationKey(lat: lat, lon: lon);
  }
}
