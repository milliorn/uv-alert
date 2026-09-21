import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:uvalert/constants.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/storage/cache.dart';
import 'package:uvalert/storage/preferences.dart';

/// Simulates a write to [_failingKey] never landing (process death, browser
/// tab close mid-write), while every other key persists normally. Used to
/// reproduce the specific interleaving `Cache.store` must fail closed
/// against: the payload/timestamp write is interrupted independently of
/// the location-key write.
class _FailingKeyStore extends InMemorySharedPreferencesStore {
  _FailingKeyStore(this._failingKey) : super.empty();

  final String _failingKey;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    // Throws rather than returning false: Preferences' setters discard
    // setString's bool result, so a false return would silently complete
    // as if the write succeeded and never exercise store()'s fail-closed
    // ordering at all.
    if (key == _failingKey) throw Exception('simulated write failure');
    return super.setValue(valueType, key, value);
  }
}

const int _staleHours = cacheMaxAgeHours + 1;
const int _freshHours = cacheMaxAgeHours - 1;

/// Fixture coordinates for tests that don't specifically exercise
/// location-keying (most of this file); any two distinct values work.
const double _lat = 40.7128;
const double _lon = -74.006;

const double _otherLat = 51.5074;
const double _otherLon = -0.1278;

/// An offset small enough to stay below [Cache]'s rounding precision, so
/// `_lat + _jitterDelta`/`_lon + _jitterDelta` still round to the same
/// [Cache.locationKey] as `_lat`/`_lon` -- simulates routine GPS
/// fix-to-fix jitter between two reads of the same physical spot.
const double _jitterDelta = 0.000001;

DateTime _staleTimestamp() =>
    DateTime.now().toUtc().subtract(const Duration(hours: _staleHours));

UvData _makeData({DateTime? fetchedAt}) {
  final DateTime raw = fetchedAt ?? DateTime.now().toUtc();
  // Truncate to whole seconds: epoch-seconds serialization has 1s precision.
  final DateTime now = DateTime.fromMillisecondsSinceEpoch(
    raw.millisecondsSinceEpoch - raw.millisecondsSinceEpoch % msPerSecond,
    isUtc: true,
  );
  return UvData(
    currentUvi: 5,
    sunrise: now,
    sunset: now.add(const Duration(hours: 12)),
    clouds: 10,
    hourly: const <UvForecastEntry>[],
    daily: const <UvForecastEntry>[],
    timezone: 'UTC',
    timezoneOffset: 0,
    fetchedAt: now,
  );
}

void main() {
  late Preferences prefs;
  late Cache cache;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await Preferences.load();
    cache = Cache(prefs);
  });

  group('Cache isEmpty', () {
    test('is empty when no payload stored', () {
      expect(cache.isEmpty, isTrue);
    });

    test('is not empty after storing data', () async {
      await cache.store(_makeData(), lat: _lat, lon: _lon);
      expect(cache.isEmpty, isFalse);
    });
  });

  group('Cache isStale', () {
    test('is stale when no timestamp stored', () {
      expect(cache.isStale, isTrue);
    });

    test('is not stale when data was just stored', () async {
      await cache.store(_makeData(), lat: _lat, lon: _lon);
      expect(cache.isStale, isFalse);
    });

    test('is stale when timestamp is TTL + 1 hours old', () async {
      await cache.store(
        _makeData(fetchedAt: _staleTimestamp()),
        lat: _lat,
        lon: _lon,
      );
      expect(cache.isStale, isTrue);
    });

    test('is not stale when timestamp is TTL - 1 hours old', () async {
      final DateTime recent = DateTime.now().toUtc().subtract(
        const Duration(hours: _freshHours),
      );
      await cache.store(
        _makeData(fetchedAt: recent),
        lat: _lat,
        lon: _lon,
      );
      expect(cache.isStale, isFalse);
    });

    test('is stale when stored timestamp is corrupt', () async {
      await prefs.setCachedPayloadAt('not-a-date');
      expect(cache.isStale, isTrue);
    });
  });

  group('Cache isValid', () {
    test('is invalid when empty', () {
      expect(cache.isValid(lat: _lat, lon: _lon), isFalse);
    });

    test('is valid when data is fresh and coordinates match', () async {
      await cache.store(_makeData(), lat: _lat, lon: _lon);
      expect(cache.isValid(lat: _lat, lon: _lon), isTrue);
    });

    test('is invalid when data is stale', () async {
      await cache.store(
        _makeData(fetchedAt: _staleTimestamp()),
        lat: _lat,
        lon: _lon,
      );
      expect(cache.isValid(lat: _lat, lon: _lon), isFalse);
    });

    test(
      'is invalid when payload is missing but timestamp is recent',
      () async {
        // Timestamp written without a payload (e.g. interrupted store, or a
        // clearCache that only removed the payload key).
        await prefs.setCachedPayloadAt(
          DateTime.now().toUtc().toIso8601String(),
        );
        expect(cache.isValid(lat: _lat, lon: _lon), isFalse);
      },
    );

    test(
      'is invalid when fresh but stored for different coordinates',
      () async {
        await cache.store(_makeData(), lat: _lat, lon: _lon);
        expect(cache.isValid(lat: _otherLat, lon: _otherLon), isFalse);
      },
    );

    test('is invalid when fresh but written before location-keying existed '
        '(no stored location at all)', () async {
      // Simulates an existing install's cache entry from before
      // cachedPayloadLocation existed: payload and timestamp present,
      // location key absent. A missing location must read as a mismatch,
      // not as "nothing to compare against."
      await prefs.setCachedPayload('{}');
      await prefs.setCachedPayloadAt(DateTime.now().toUtc().toIso8601String());
      expect(cache.isValid(lat: _lat, lon: _lon), isFalse);
    });
  });

  group('Cache read', () {
    test('returns null when empty', () async {
      expect(await cache.read(lat: _lat, lon: _lon), isNull);
    });

    test('returns stored data when coordinates match', () async {
      final UvData data = _makeData();

      await cache.store(data, lat: _lat, lon: _lon);

      final UvData? result = await cache.read(lat: _lat, lon: _lon);

      expect(result, isNotNull);
      expect(result!.currentUvi, data.currentUvi);
      expect(result.timezone, data.timezone);
      expect(result.fetchedAt, data.fetchedAt);
    });

    test('returns null when stored for different coordinates', () async {
      await cache.store(_makeData(), lat: _lat, lon: _lon);

      final UvData? result = await cache.read(lat: _otherLat, lon: _otherLon);

      expect(result, isNull);
    });

    test('clears cache and returns null on corrupt payload', () async {
      await prefs.setCachedPayload('not valid json {{{');
      await prefs.setCachedPayloadLocation(
        Cache.locationKey(lat: _lat, lon: _lon),
      );

      final UvData? result = await cache.read(lat: _lat, lon: _lon);

      expect(result, isNull);
      expect(cache.isEmpty, isTrue);
    });

    test(
      'clears cache and returns null when payload is not a JSON object',
      () async {
        await prefs.setCachedPayload('[1, 2, 3]');
        await prefs.setCachedPayloadLocation(
          Cache.locationKey(lat: _lat, lon: _lon),
        );

        final UvData? result = await cache.read(lat: _lat, lon: _lon);

        expect(result, isNull);
        expect(cache.isEmpty, isTrue);
      },
    );
  });

  group('Cache store', () {
    test('stores payload, timestamp, and location', () async {
      final UvData data = _makeData();

      await cache.store(data, lat: _lat, lon: _lon);

      expect(prefs.cachedPayload, isNotNull);
      expect(prefs.cachedPayloadAt, isNotNull);
      expect(
        prefs.cachedPayloadLocation,
        Cache.locationKey(lat: _lat, lon: _lon),
      );
    });

    test('overwrites previously stored data', () async {
      final UvData first = _makeData(fetchedAt: DateTime.utc(2023));
      final UvData second = _makeData(fetchedAt: DateTime.utc(2024));

      await cache.store(first, lat: _lat, lon: _lon);
      await cache.store(second, lat: _lat, lon: _lon);

      final UvData? result = await cache.read(lat: _lat, lon: _lon);

      expect(result!.fetchedAt, second.fetchedAt);
    });

    test('overwrites a previous location with a new one', () async {
      await cache.store(_makeData(), lat: _lat, lon: _lon);
      await cache.store(_makeData(), lat: _otherLat, lon: _otherLon);

      expect(cache.isValid(lat: _lat, lon: _lon), isFalse);
      expect(cache.isValid(lat: _otherLat, lon: _otherLon), isTrue);
    });

    test('fails closed rather than committing a new location key over a '
        'payload write that did not land', () async {
      // Reproduces the specific interleaving store() must not allow: the
      // payload/timestamp write is interrupted (process death, browser
      // tab close) independently of the location-key write. If the
      // location key were written unconditionally, isValid would then
      // report a match for the new location while read() actually
      // serves whatever payload happens to still be on disk (here,
      // nothing at all, but the same argument applies to a stale
      // payload from a previous store()).
      //
      // setMockInitialValues (not a bare instance swap) is required here:
      // Preferences.load() caches SharedPreferences.getInstance()'s
      // result on a static completer, and this file's own setUp already
      // populated it via its own Preferences.load() call above.
      // setMockInitialValues nulls that completer, so this Preferences.
      // load() actually resolves against _FailingKeyStore instead of
      // silently reusing the already-cached, non-failing instance.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      SharedPreferencesStorePlatform.instance = _FailingKeyStore(
        'flutter.uvalert_cached_payload',
      );
      final Preferences failingPrefs = await Preferences.load();
      final Cache failingCache = Cache(failingPrefs);

      await expectLater(
        () => failingCache.store(_makeData(), lat: _lat, lon: _lon),
        throwsA(isA<Exception>()),
      );

      expect(
        failingPrefs.cachedPayloadLocation,
        isNot(Cache.locationKey(lat: _lat, lon: _lon)),
      );
      expect(failingCache.isValid(lat: _lat, lon: _lon), isFalse);
    });
  });

  group('Cache.locationKey', () {
    test('rounds to 2 decimal places', () {
      expect(Cache.locationKey(lat: 40.7128, lon: -74.006), '40.71,-74.01');
    });

    test('differs for distinct coordinates', () {
      expect(
        Cache.locationKey(lat: _lat, lon: _lon),
        isNot(Cache.locationKey(lat: _otherLat, lon: _otherLon)),
      );
    });
  });

  group('Cache GPS jitter tolerance', () {
    test('isValid still matches when coordinates differ only below the '
        'rounding precision, as with routine GPS fix-to-fix jitter', () async {
      await cache.store(_makeData(), lat: _lat, lon: _lon);
      expect(
        cache.isValid(lat: _lat + _jitterDelta, lon: _lon + _jitterDelta),
        isTrue,
      );
    });

    test('read still returns data when coordinates differ only below the '
        'rounding precision', () async {
      final UvData data = _makeData();
      await cache.store(data, lat: _lat, lon: _lon);

      final UvData? result = await cache.read(
        lat: _lat + _jitterDelta,
        lon: _lon + _jitterDelta,
      );

      expect(result, isNotNull);
      expect(result!.currentUvi, data.currentUvi);
    });

    test('isValid is false once coordinates differ enough to round to a '
        'different key', () async {
      await cache.store(_makeData(), lat: _lat, lon: _lon);
      // 0.01 (the rounding precision itself) rather than _jitterDelta:
      // large enough to round to a genuinely different key.
      expect(cache.isValid(lat: _lat + 0.01, lon: _lon), isFalse);
    });
  });
}
