import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/storage/preferences.dart';

/// Maximum age of cached UV data in hours before it is considered stale.
const int cacheMaxAgeHours = 24;

/// SharedPreferences-backed cache for [UvData] with a
/// [cacheMaxAgeHours]-hour TTL.
class Cache {
  /// Creates a [Cache] backed by the given [Preferences] instance.
  Cache(this._prefs);
  final Preferences _prefs;

  /// Persists [data] to the cache, keying expiry on the server-provided
  /// [UvData.fetchedAt] timestamp.
  Future<void> store(UvData data) async {
    final String json = jsonEncode(data.toJson());

    await Future.wait(<Future<void>>[
      _prefs.setCachedPayload(json),
      // Intentional: use server-provided fetchedAt, not DateTime.now().
      // If the server timestamp lags real time, the cache expires sooner than
      // cacheMaxAgeHours - acceptable given UV data changes infrequently.
      _prefs.setCachedPayloadAt(data.fetchedAt.toIso8601String()),
    ]);
  }

  /// Returns the cached [UvData], or `null` if empty or the payload is corrupt.
  ///
  /// Clears the cache automatically on a corrupt or malformed payload.
  Future<UvData?> read() async {
    final String? raw = _prefs.cachedPayload;

    if (raw == null) return null;

    try {
      final dynamic decoded = jsonDecode(raw);

      if (decoded is! Map<String, dynamic>) {
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

  /// Whether the cache has a payload and it is within the TTL.
  bool get isValid => !isEmpty && !isStale;
}
