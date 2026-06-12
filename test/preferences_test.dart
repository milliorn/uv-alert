import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:uvalert/storage/preferences.dart';

class _FailingRemoveStore extends InMemorySharedPreferencesStore {
  _FailingRemoveStore() : super.empty();

  @override
  Future<bool> remove(String key) async => false;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Preferences defaults', () {
    test('isFirstLaunch is true when no value stored', () async {
      final Preferences prefs = await Preferences.load();
      expect(prefs.isFirstLaunch, isTrue);
    });

    test('isThemeStepDone is false when no value stored', () async {
      final Preferences prefs = await Preferences.load();
      expect(prefs.isThemeStepDone, isFalse);
    });

    test('theme defaults to system', () async {
      final Preferences prefs = await Preferences.load();
      expect(prefs.theme, ThemeMode.system);
    });

    test('useGps defaults to true', () async {
      final Preferences prefs = await Preferences.load();
      expect(prefs.useGps, isTrue);
    });

    test('notificationsEnabled defaults to false', () async {
      final Preferences prefs = await Preferences.load();
      expect(prefs.notificationsEnabled, isFalse);
    });

    test('uuid is null when not set', () async {
      final Preferences prefs = await Preferences.load();
      expect(prefs.uuid, isNull);
    });

    test('cachedPayload is null when not set', () async {
      final Preferences prefs = await Preferences.load();
      expect(prefs.cachedPayload, isNull);
    });

    test('cachedPayloadAt is null when not set', () async {
      final Preferences prefs = await Preferences.load();
      expect(prefs.cachedPayloadAt, isNull);
    });

    test('manualLocation is null when not set', () async {
      final Preferences prefs = await Preferences.load();
      expect(prefs.manualLocation, isNull);
    });
  });

  group('Preferences setters', () {
    test('setFirstLaunchDone sets isFirstLaunch to false', () async {
      final Preferences prefs = await Preferences.load();
      await prefs.setFirstLaunchDone();
      expect(prefs.isFirstLaunch, isFalse);
    });

    test('setThemeStepDone sets isThemeStepDone to true', () async {
      final Preferences prefs = await Preferences.load();
      await prefs.setThemeStepDone();
      expect(prefs.isThemeStepDone, isTrue);
    });

    test('setUuid stores and retrieves uuid', () async {
      final Preferences prefs = await Preferences.load();
      await prefs.setUuid('abc-123');
      expect(prefs.uuid, 'abc-123');
    });

    test('setTheme stores and retrieves theme', () async {
      final Preferences prefs = await Preferences.load();
      await prefs.setTheme(ThemeMode.dark);
      expect(prefs.theme, ThemeMode.dark);
    });

    test('setUseGps toggles value', () async {
      final Preferences prefs = await Preferences.load();
      await prefs.setUseGps(value: false);
      expect(prefs.useGps, isFalse);
    });

    test('setManualLocation stores and retrieves location', () async {
      final Preferences prefs = await Preferences.load();
      await prefs.setManualLocation('New York, NY');
      expect(prefs.manualLocation, 'New York, NY');
    });

    test('setNotificationsEnabled stores and retrieves value', () async {
      final Preferences prefs = await Preferences.load();
      await prefs.setNotificationsEnabled(value: true);
      expect(prefs.notificationsEnabled, isTrue);
    });

    test('setCachedPayload and setCachedPayloadAt store values', () async {
      final Preferences prefs = await Preferences.load();
      await prefs.setCachedPayload('{"foo": 1}');
      await prefs.setCachedPayloadAt('2023-11-14T12:00:00.000Z');
      expect(prefs.cachedPayload, '{"foo": 1}');
      expect(prefs.cachedPayloadAt, '2023-11-14T12:00:00.000Z');
    });
  });

  group('Preferences clearCache', () {
    test('clearCache removes cached payload and timestamp', () async {
      final Preferences prefs = await Preferences.load();
      await prefs.setCachedPayload('data');
      await prefs.setCachedPayloadAt('2023-11-14T12:00:00.000Z');
      await prefs.clearCache();
      expect(prefs.cachedPayload, isNull);
      expect(prefs.cachedPayloadAt, isNull);
    });

    test('clearCache does not affect other preferences', () async {
      final Preferences prefs = await Preferences.load();
      await prefs.setUuid('keep-me');
      await prefs.clearCache();
      expect(prefs.uuid, 'keep-me');
    });
  });

  group('Preferences _assertAllRemoved', () {
    setUp(() {
      SharedPreferencesStorePlatform.instance = _FailingRemoveStore();
    });

    test('clearCache throws StateError when a key cannot be removed', () async {
      final Preferences prefs = await Preferences.load();
      expect(prefs.clearCache, throwsStateError);
    });

    test('clearAll throws StateError when a key cannot be removed', () async {
      final Preferences prefs = await Preferences.load();
      await prefs.setUuid('x');
      expect(prefs.clearAll, throwsStateError);
    });
  });

  group('Preferences clearAll', () {
    test('clearAll resets all values to defaults', () async {
      final Preferences prefs = await Preferences.load();
      await prefs.setUuid('abc');
      await prefs.setTheme(ThemeMode.dark);
      await prefs.setUseGps(value: false);
      await prefs.setManualLocation('Boston');
      await prefs.setNotificationsEnabled(value: true);
      await prefs.setCachedPayload('data');
      await prefs.setCachedPayloadAt('2023-11-14T12:00:00.000Z');
      await prefs.setFirstLaunchDone();

      await prefs.clearAll();

      expect(prefs.uuid, isNull);
      expect(prefs.theme, ThemeMode.system);
      expect(prefs.useGps, isTrue);
      expect(prefs.manualLocation, isNull);
      expect(prefs.notificationsEnabled, isFalse);
      expect(prefs.cachedPayload, isNull);
      expect(prefs.cachedPayloadAt, isNull);
      expect(prefs.isFirstLaunch, isTrue);
    });
  });
}
