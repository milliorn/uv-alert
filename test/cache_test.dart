import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/storage/cache.dart';
import 'package:uvalert/storage/preferences.dart';

UvData _makeData({DateTime? fetchedAt}) {
  final now = fetchedAt ?? DateTime.now().toUtc();
  return UvData(
    currentUvi: 5.0,
    sunrise: now,
    sunset: now.add(const Duration(hours: 12)),
    clouds: 10,
    hourly: [],
    daily: [],
    timezone: 'UTC',
    timezoneOffset: 0,
    fetchedAt: now,
  );
}

void main() {
  late Preferences prefs;
  late Cache cache;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await Preferences.load();
    cache = Cache(prefs);
  });

  group('Cache isEmpty', () {
    test('is empty when no payload stored', () {
      expect(cache.isEmpty, isTrue);
    });

    test('is not empty after storing data', () async {
      await cache.store(_makeData());
      expect(cache.isEmpty, isFalse);
    });
  });

  group('Cache isStale', () {
    test('is stale when no timestamp stored', () {
      expect(cache.isStale, isTrue);
    });

    test('is not stale when data was just stored', () async {
      await cache.store(_makeData());
      expect(cache.isStale, isFalse);
    });

    test('is stale when timestamp is 25 hours old', () async {
      final old = DateTime.now().toUtc().subtract(const Duration(hours: 25));
      await cache.store(_makeData(fetchedAt: old));
      expect(cache.isStale, isTrue);
    });

    test('is not stale when timestamp is 23 hours old', () async {
      final recent = DateTime.now().toUtc().subtract(const Duration(hours: 23));
      final data = _makeData(fetchedAt: recent);
      await cache.store(data);
      expect(cache.isStale, isFalse);
    });
  });

  group('Cache isValid', () {
    test('is invalid when empty', () {
      expect(cache.isValid, isFalse);
    });

    test('is valid when data is fresh', () async {
      await cache.store(_makeData());
      expect(cache.isValid, isTrue);
    });

    test('is invalid when data is stale', () async {
      final old = DateTime.now().toUtc().subtract(const Duration(hours: 25));
      await cache.store(_makeData(fetchedAt: old));
      expect(cache.isValid, isFalse);
    });
  });

  group('Cache read', () {
    test('returns null when empty', () {
      expect(cache.read(), isNull);
    });

    test('returns stored data with matching fields', () async {
      final data = _makeData();
      await cache.store(data);
      final result = cache.read();

      expect(result, isNotNull);
      expect(result!.currentUvi, data.currentUvi);
      expect(result.timezone, data.timezone);
      expect(result.fetchedAt, data.fetchedAt);
    });

    test('clears cache and returns null on corrupt payload', () async {
      await prefs.setCachedPayload('not valid json {{{');
      final result = cache.read();
      expect(result, isNull);
      expect(cache.isEmpty, isTrue);
    });
  });

  group('Cache store', () {
    test('stores payload and timestamp', () async {
      final data = _makeData();
      await cache.store(data);

      expect(prefs.cachedPayload, isNotNull);
      expect(prefs.cachedPayloadAt, isNotNull);
    });

    test('overwrites previously stored data', () async {
      final first = _makeData(fetchedAt: DateTime.utc(2023, 1, 1));
      final second = _makeData(fetchedAt: DateTime.utc(2024, 1, 1));
      await cache.store(first);
      await cache.store(second);

      final result = cache.read();
      expect(result!.fetchedAt, second.fetchedAt);
    });
  });
}
