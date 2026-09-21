import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:uvalert/constants.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/storage/cache.dart';
import 'package:uvalert/storage/preferences.dart';

const String _keyCachedEntry = 'flutter.uvalert_cached_entry';

/// Reports write failure (returns `false`, does not throw) for the single
/// cached-entry key, while updating `SharedPreferences`'s own optimistic
/// in-memory cache as usual (`SharedPreferences._setValue` updates that
/// cache before the platform write even starts), so a platform-level
/// failure and an in-memory success can genuinely disagree. Used to
/// reproduce what a fresh process launch (reading only the platform's
/// persisted state, not the crashed process's in-memory cache) would see
/// after such a failure.
class _FailingEntryWriteStore extends InMemorySharedPreferencesStore {
  _FailingEntryWriteStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == _keyCachedEntry) return false;
    return super.setValue(valueType, key, value);
  }
}

/// Delays the single cached-entry write whose value equals [gatedValue]
/// until [release] completes, so a specific `Cache.store` call's write can
/// be held back while a second, overlapping `store` call runs to
/// completion first. Reproduces the interleaving two `UvApi.fetch`
/// calls racing each other (see the class doc on `UvApiFetchMeta`) could
/// put `Cache.store` into.
class _GatedEntryWriteStore extends InMemorySharedPreferencesStore {
  _GatedEntryWriteStore() : super.empty();

  String? gatedValue;
  Completer<void>? release;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == _keyCachedEntry && value == gatedValue && release != null) {
      await release!.future;
    }
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

UvData _makeData({DateTime? fetchedAt, double currentUvi = 5}) {
  final DateTime raw = fetchedAt ?? DateTime.now().toUtc();
  // Truncate to whole seconds: epoch-seconds serialization has 1s precision.
  final DateTime now = DateTime.fromMillisecondsSinceEpoch(
    raw.millisecondsSinceEpoch - raw.millisecondsSinceEpoch % msPerSecond,
    isUtc: true,
  );
  return UvData(
    currentUvi: currentUvi,
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
      await prefs.setCachedEntry((
        payload: '{}',
        at: 'not-a-date',
        location: Cache.locationKey(lat: _lat, lon: _lon),
      ));
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
      'is invalid when fresh but stored for different coordinates',
      () async {
        await cache.store(_makeData(), lat: _lat, lon: _lon);
        expect(cache.isValid(lat: _otherLat, lon: _otherLon), isFalse);
      },
    );

    test('is invalid when the stored entry is missing the location field '
        '(as with an entry from before location-keying existed)', () async {
      // Simulates an existing install's cache entry from before
      // cachedEntry's location field existed: payload and timestamp
      // present, location absent. A record missing a required field is
      // unreadable as a CachedUvEntry at all (Preferences.cachedEntry
      // returns null), so it is structurally a miss, not merely "nothing
      // to compare against."
      SharedPreferences.setMockInitialValues(<String, Object>{
        _keyCachedEntry:
            '{"payload": "{}", '
            '"at": "${DateTime.now().toUtc().toIso8601String()}"}',
      });
      final Preferences seededPrefs = await Preferences.load();
      final Cache seededCache = Cache(seededPrefs);

      expect(seededCache.isValid(lat: _lat, lon: _lon), isFalse);
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
      await prefs.setCachedEntry((
        payload: 'not valid json {{{',
        at: DateTime.now().toUtc().toIso8601String(),
        location: Cache.locationKey(lat: _lat, lon: _lon),
      ));

      final UvData? result = await cache.read(lat: _lat, lon: _lon);

      expect(result, isNull);
      expect(cache.isEmpty, isTrue);
    });

    test(
      'clears cache and returns null when payload is not a JSON object',
      () async {
        await prefs.setCachedEntry((
          payload: '[1, 2, 3]',
          at: DateTime.now().toUtc().toIso8601String(),
          location: Cache.locationKey(lat: _lat, lon: _lon),
        ));

        final UvData? result = await cache.read(lat: _lat, lon: _lon);

        expect(result, isNull);
        expect(cache.isEmpty, isTrue);
      },
    );
  });

  group('Cache store', () {
    test('stores payload, timestamp, and location as one entry', () async {
      final UvData data = _makeData();

      await cache.store(data, lat: _lat, lon: _lon);

      final CachedUvEntry? entry = prefs.cachedEntry;
      expect(entry, isNotNull);
      expect(entry!.payload, isNotEmpty);
      expect(entry.at, isNotEmpty);
      expect(entry.location, Cache.locationKey(lat: _lat, lon: _lon));
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

    test(
      "never pairs one call's payload with a different call's location, "
      'when two store() calls for different locations overlap',
      () async {
        // Reproduces the interleaving two overlapping UvApi.fetch calls can
        // put Cache.store into (a location change superseding an in-flight
        // fetch, see the class doc on UvApiFetchMeta): call A reaches the
        // point of committing its own entry only after call B, for a
        // different location, has already completed in full. Against the
        // pre-fix three-key shape, this let A's location key persist
        // alongside B's payload (reproduced directly against that shape
        // while designing this fix); with a single entry, whichever call's
        // write lands last wins as one complete, internally consistent
        // record.
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final _GatedEntryWriteStore store = _GatedEntryWriteStore();
        SharedPreferencesStorePlatform.instance = store;

        final Preferences racePrefs = await Preferences.load();
        final Cache raceCache = Cache(racePrefs);

        // Distinct currentUvi values (rather than _makeData's identical
        // defaults) so a cross-pairing between A's location key and B's
        // payload (the exact failure mode this test guards against)
        // is distinguishable from either call cleanly winning outright.
        final UvData dataA = _makeData(currentUvi: 1);
        final UvData dataB = _makeData(currentUvi: 2);
        final String keyA = Cache.locationKey(lat: _lat, lon: _lon);

        store
          ..gatedValue = jsonEncode(<String, Object>{
            'payload': jsonEncode(dataA.toJson()),
            'at': dataA.fetchedAt.toIso8601String(),
            'location': keyA,
          })
          ..release = Completer<void>();

        final Future<void> storeA = raceCache.store(
          dataA,
          lat: _lat,
          lon: _lon,
        );

        await raceCache.store(dataB, lat: _otherLat, lon: _otherLon);

        store.release!.complete();
        await storeA;

        final bool aWon = raceCache.isValid(lat: _lat, lon: _lon);
        final bool bWon = raceCache.isValid(
          lat: _otherLat,
          lon: _otherLon,
        );

        // Exactly one call's entry must have won outright, never a mix.
        expect(aWon ^ bWon, isTrue);
        if (aWon) {
          expect(
            (await raceCache.read(lat: _lat, lon: _lon))?.currentUvi,
            dataA.currentUvi,
          );
          expect(await raceCache.read(lat: _otherLat, lon: _otherLon), isNull);
        } else {
          expect(await raceCache.read(lat: _lat, lon: _lon), isNull);
          expect(
            (await raceCache.read(lat: _otherLat, lon: _otherLon))
                ?.currentUvi,
            dataB.currentUvi,
          );
        }
      },
    );

    test(
      'leaves the previous entry fully intact when the write fails at the '
      'platform level, rather than a partial record mixing old and new',
      () async {
        // A platform-level write failure (returns false, does not throw)
        // must not leave a stale location paired with a payload that
        // belongs to neither the old nor the new store() call. With one
        // entry, a failed write simply leaves whatever was persisted
        // before untouched.
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final _FailingEntryWriteStore store = _FailingEntryWriteStore();
        SharedPreferencesStorePlatform.instance = store;

        final Preferences failingPrefs = await Preferences.load();
        final Cache failingCache = Cache(failingPrefs);

        final Map<String, Object> persisted = await store.getAll();
        expect(persisted[_keyCachedEntry], isNull);

        await failingCache.store(_makeData(), lat: _lat, lon: _lon);

        final Map<String, Object> persistedAfter = await store.getAll();
        expect(persistedAfter[_keyCachedEntry], isNull);
      },
    );
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
