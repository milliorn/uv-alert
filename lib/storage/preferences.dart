import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  Preferences._(this._prefs);
  static const _prefix = 'uvalert_';
  static const _keyFirstLaunch = '${_prefix}first_launch';
  static const _keyUuid = '${_prefix}uuid';
  static const _keyTheme = '${_prefix}theme';
  static const _keyUseGps = '${_prefix}use_gps';
  static const _keyManualLocation = '${_prefix}manual_location';
  static const _keyNotificationsEnabled = '${_prefix}notifications_enabled';
  static const _keyCachedPayload = '${_prefix}cached_payload';
  static const _keyCachedPayloadAt = '${_prefix}cached_payload_at';

  static const _ownedKeys = [
    _keyFirstLaunch,
    _keyUuid,
    _keyTheme,
    _keyUseGps,
    _keyManualLocation,
    _keyNotificationsEnabled,
    _keyCachedPayload,
    _keyCachedPayloadAt,
  ];

  final SharedPreferences _prefs;

  static Future<Preferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return Preferences._(prefs);
  }

  bool get isFirstLaunch => _prefs.getBool(_keyFirstLaunch) ?? true;
  Future<void> setFirstLaunchDone() => _prefs.setBool(_keyFirstLaunch, false);

  String? get uuid => _prefs.getString(_keyUuid);
  Future<void> setUuid(String uuid) => _prefs.setString(_keyUuid, uuid);

  String get theme => _prefs.getString(_keyTheme) ?? 'system';
  Future<void> setTheme(String theme) => _prefs.setString(_keyTheme, theme);

  bool get useGps => _prefs.getBool(_keyUseGps) ?? true;
  Future<void> setUseGps({required bool value}) =>
      _prefs.setBool(_keyUseGps, value);

  // TODO(location): stored as a raw string; migrate to a structured type
  // (lat/lon pair or named-place object) when the location feature lands.
  String? get manualLocation => _prefs.getString(_keyManualLocation);
  Future<void> setManualLocation(String location) =>
      _prefs.setString(_keyManualLocation, location);

  bool get notificationsEnabled =>
      _prefs.getBool(_keyNotificationsEnabled) ?? false;
  Future<void> setNotificationsEnabled({required bool value}) =>
      _prefs.setBool(_keyNotificationsEnabled, value);

  String? get cachedPayload => _prefs.getString(_keyCachedPayload);
  Future<void> setCachedPayload(String json) =>
      _prefs.setString(_keyCachedPayload, json);

  String? get cachedPayloadAt => _prefs.getString(_keyCachedPayloadAt);
  Future<void> setCachedPayloadAt(String isoTimestamp) =>
      _prefs.setString(_keyCachedPayloadAt, isoTimestamp);

  Future<void> clearCache() => Future.wait([
    _prefs.remove(_keyCachedPayload),
    _prefs.remove(_keyCachedPayloadAt),
  ]);

  Future<void> clearAll() =>
      Future.wait(_ownedKeys.map(_prefs.remove));
}
