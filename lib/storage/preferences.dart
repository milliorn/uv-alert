import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Computed once; ThemeMode.values never changes at runtime.
final Map<String, ThemeMode> _themeModeByName = ThemeMode.values.asNameMap();

/// Typed, prefixed wrapper around [SharedPreferences] for app settings.
class Preferences {
  Preferences._(this._prefs);
  static const String _prefix = 'uvalert_';
  static const String _keyFirstLaunch = '${_prefix}first_launch';

  /// The SharedPreferences key for [isFirstLaunch]. Exposed for tests only.
  @visibleForTesting
  static const String keyFirstLaunchForTesting = _keyFirstLaunch;

  static const String _keyThemeStepDone = '${_prefix}theme_step_done';

  /// The SharedPreferences key for [isThemeStepDone]. Exposed for tests only.
  @visibleForTesting
  static const String keyThemeStepDoneForTesting = _keyThemeStepDone;

  static const String _keyLocationStepDone = '${_prefix}location_step_done';

  /// The SharedPreferences key for [isLocationStepDone].
  /// Exposed for tests only.
  @visibleForTesting
  static const String keyLocationStepDoneForTesting = _keyLocationStepDone;

  static const String _keyUuid = '${_prefix}uuid';
  static const String _keyTheme = '${_prefix}theme';
  static const String _keyUseGps = '${_prefix}use_gps';
  static const String _keyManualLocation = '${_prefix}manual_location';
  static const String _keyNotificationsEnabled =
      '${_prefix}notifications_enabled';
  static const String _keyCachedPayload = '${_prefix}cached_payload';
  static const String _keyCachedPayloadAt = '${_prefix}cached_payload_at';

  final SharedPreferences _prefs;

  /// Loads and returns a [Preferences] instance backed by [SharedPreferences].
  static Future<Preferences> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return Preferences._(prefs);
  }

  /// Whether this is the first time the app has launched.
  bool get isFirstLaunch => _prefs.getBool(_keyFirstLaunch) ?? true;

  /// Marks the first launch as complete.
  Future<void> setFirstLaunchDone() async =>
      _prefs.setBool(_keyFirstLaunch, false);

  /// Whether the theme onboarding step has been completed.
  bool get isThemeStepDone => _prefs.getBool(_keyThemeStepDone) ?? false;

  /// Marks the theme onboarding step as complete.
  Future<void> setThemeStepDone() async =>
      _prefs.setBool(_keyThemeStepDone, true);

  /// Whether the location onboarding step has been completed.
  bool get isLocationStepDone =>
      _prefs.getBool(_keyLocationStepDone) ?? false;

  /// Marks the location onboarding step as complete.
  Future<void> setLocationStepDone() async =>
      _prefs.setBool(_keyLocationStepDone, true);

  /// The stored device UUID, or `null` if not yet set.
  String? get uuid => _prefs.getString(_keyUuid);

  /// Stores the device [uuid].
  Future<void> setUuid(String uuid) async => _prefs.setString(_keyUuid, uuid);

  /// The active [ThemeMode]; defaults to [ThemeMode.system].
  ThemeMode get theme {
    final String? stored = _prefs.getString(_keyTheme);

    if (stored == null) return ThemeMode.system;

    return _themeModeByName[stored] ?? ThemeMode.system;
  }

  /// Stores the active [theme].
  Future<void> setTheme(ThemeMode theme) async =>
      _prefs.setString(_keyTheme, theme.name);

  /// Whether GPS location is enabled; defaults to `true`.
  bool get useGps => _prefs.getBool(_keyUseGps) ?? true;

  /// Sets whether GPS location is enabled.
  Future<void> setUseGps({required bool value}) async =>
      _prefs.setBool(_keyUseGps, value);

  // TODO(location): stored as a raw string; migrate to a structured type
  // (lat/lon pair or named-place object) when the location feature lands.
  /// The manually entered location string, or `null` if not set.
  String? get manualLocation => _prefs.getString(_keyManualLocation);

  /// Stores the manually entered [location] string.
  Future<void> setManualLocation(String location) async =>
      _prefs.setString(_keyManualLocation, location);

  /// Whether push notifications are enabled; defaults to `false`.
  bool get notificationsEnabled =>
      _prefs.getBool(_keyNotificationsEnabled) ?? false;

  /// Sets whether push notifications are enabled.
  Future<void> setNotificationsEnabled({required bool value}) async =>
      _prefs.setBool(_keyNotificationsEnabled, value);

  /// The raw JSON string of the cached UV payload, or `null` if not set.
  String? get cachedPayload => _prefs.getString(_keyCachedPayload);

  /// Stores the raw JSON [json] string as the cached UV payload.
  Future<void> setCachedPayload(String json) async =>
      _prefs.setString(_keyCachedPayload, json);

  /// The ISO-8601 timestamp of when the payload was cached, or `null`.
  String? get cachedPayloadAt => _prefs.getString(_keyCachedPayloadAt);

  /// Stores the ISO-8601 [isoTimestamp] of when the payload was cached.
  Future<void> setCachedPayloadAt(String isoTimestamp) async =>
      _prefs.setString(_keyCachedPayloadAt, isoTimestamp);

  /// Removes the cached UV payload and its timestamp.
  ///
  /// Throws [StateError] if either key cannot be removed.
  Future<void> clearCache() async {
    final List<bool> results = await Future.wait(<Future<bool>>[
      _prefs.remove(_keyCachedPayload),
      _prefs.remove(_keyCachedPayloadAt),
    ]);

    _assertAllRemoved(results, 'clearCache');
  }

  /// Removes all preferences stored under the app prefix.
  ///
  /// Throws [StateError] if any key cannot be removed.
  Future<void> clearAll() async {
    final List<String> keys = _prefs
        .getKeys()
        .where((String k) => k.startsWith(_prefix))
        .toList();
    final List<bool> results = await Future.wait<bool>(keys.map(_prefs.remove));
    _assertAllRemoved(results, 'clearAll');
  }

  void _assertAllRemoved(List<bool> results, String operation) {
    if (results.any((bool ok) => !ok)) {
      throw StateError('$operation: one or more keys could not be removed');
    }
  }
}
