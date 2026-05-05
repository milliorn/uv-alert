import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/storage/preferences.dart';

const _cacheMaxAgeHours = 24;

class Cache {
  final Preferences _prefs;

  Cache(this._prefs);

  Future<void> store(UvData data) async {
    final json = jsonEncode(data.toJson());

    await Future.wait([
      _prefs.setCachedPayload(json),
      _prefs.setCachedPayloadAt(data.fetchedAt.toIso8601String()),
    ]);
  }

  UvData? read() {
    final raw = _prefs.cachedPayload;

    if (raw == null) return null;

    try {
      return UvData.fromJson(jsonDecode(raw));
    } on FormatException catch (e) {
      if (kDebugMode) debugPrint('Cache.read: corrupt payload: $e');
      unawaited(_prefs.clearCache());
      return null;
    } on TypeError catch (e) {
      if (kDebugMode) debugPrint('Cache.read: type mismatch in payload: $e');
      unawaited(_prefs.clearCache());
      return null;
    }
  }

  bool get isStale {
    final cachedAt = _prefs.cachedPayloadAt;

    if (cachedAt == null) return true;

    final fetched = DateTime.parse(cachedAt);

    return DateTime.now().toUtc().difference(fetched).inHours >=
        _cacheMaxAgeHours;
  }

  bool get isEmpty => _prefs.cachedPayload == null;

  bool get isValid => !isEmpty && !isStale;
}
