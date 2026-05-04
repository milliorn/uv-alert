import 'dart:convert';

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

    return UvData.fromJson(jsonDecode(raw));
  }

  bool get isStale {
    final cachedAt = _prefs.cachedPayloadAt;

    if (cachedAt == null) return true;

    final fetched = DateTime.parse(cachedAt);

    return DateTime.now().toUtc().difference(fetched).inHours >= 24;
  }

  bool get isEmpty => _prefs.cachedPayload == null;

  bool get isValid => !isEmpty && !isStale;
}
