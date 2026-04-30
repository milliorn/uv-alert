import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  static const _keyFirstLaunch = 'first_launch';
  static const _keyUuid = 'uuid';
  static const _keyTheme = 'theme';
  static const _keyUseGps = 'use_gps';
  static const _keyManualLocation = 'manual_location';
  static const _keyNotificationsEnabled = 'notifications_enabled';
  static const _keyCachedPayload = 'cached_payload';
  static const _keyCachedPayloadAt = 'cached_payload_at';

  final SharedPreferences _prefs;

  Preferences._(this._prefs);

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
  Future<void> setUseGps(bool value) => _prefs.setBool(_keyUseGps, value);

  String? get manualLocation => _prefs.getString(_keyManualLocation);
  Future<void> setManualLocation(String location) =>
      _prefs.setString(_keyManualLocation, location);

  bool get notificationsEnabled =>
      _prefs.getBool(_keyNotificationsEnabled) ?? false;
  Future<void> setNotificationsEnabled(bool value) =>
      _prefs.setBool(_keyNotificationsEnabled, value);

  String? get cachedPayload => _prefs.getString(_keyCachedPayload);
  Future<void> setCachedPayload(String json) =>
      _prefs.setString(_keyCachedPayload, json);

  String? get cachedPayloadAt => _prefs.getString(_keyCachedPayloadAt);
  Future<void> setCachedPayloadAt(String isoTimestamp) =>
      _prefs.setString(_keyCachedPayloadAt, isoTimestamp);
}
