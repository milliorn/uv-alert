import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uvalert/api/uv_api.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/providers/device_id_provider.dart';
import 'package:uvalert/providers/location_provider.dart';
import 'package:uvalert/providers/uv_provider.dart';
import 'package:uvalert/storage/cache.dart';

class _MockUvApi extends Mock implements UvApi {}

class _FakeUvData extends Fake implements UvData {}

UvData _makeData() => UvData(
  currentUvi: 3,
  sunrise: DateTime.utc(2024, 6, 1, 6),
  sunset: DateTime.utc(2024, 6, 1, 20),
  clouds: 10,
  hourly: const <UvForecastEntry>[],
  daily: const <UvForecastEntry>[],
  timezone: 'UTC',
  timezoneOffset: 0,
  fetchedAt: DateTime.utc(2024, 6, 1, 12),
);

ProviderContainer _makeContainerWith(_MockUvApi api) {
  final ProviderContainer container = ProviderContainer(
    // Override type inference is not exposed publicly in flutter_riverpod.
    // ignore: always_specify_types
    overrides: [
      uvProvider.overrideWith(() => UvNotifier(api: api)),
      deviceIdProvider.overrideWith((_) async => 'test-uuid'),
      locationProvider.overrideWith(LocationNotifier.new),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  late _MockUvApi mockApi;

  setUpAll(() {
    registerFallbackValue(_FakeUvData());
  });

  setUp(() {
    mockApi = _MockUvApi();
  });

  tearDown(resetMocktailState);

  // ---------------------------------------------------------------------------
  // Initial state
  // ---------------------------------------------------------------------------

  test('initial state is AsyncLoading when location is null', () {
    final ProviderContainer container = _makeContainerWith(mockApi);

    expect(container.read(uvProvider), isA<AsyncLoading<UvData>>());
  });

  // ---------------------------------------------------------------------------
  // fetch() — success
  // ---------------------------------------------------------------------------

  test('fetch() transitions state to AsyncData on success', () async {
    final UvData data = _makeData();
    when(
      () => mockApi.fetch(
        lat: any(named: 'lat'),
        lon: any(named: 'lon'),
        uuid: any(named: 'uuid'),
      ),
    ).thenAnswer((_) async => data);

    final ProviderContainer container = _makeContainerWith(mockApi);

    await container.read(uvProvider.notifier).fetch(lat: 51.5, lon: -0.1);

    expect(container.read(uvProvider), isA<AsyncData<UvData>>());
    expect(container.read(uvProvider).value, data);
  });

  // ---------------------------------------------------------------------------
  // fetch() — error
  // ---------------------------------------------------------------------------

  test('fetch() transitions state to AsyncError on failure', () async {
    when(
      () => mockApi.fetch(
        lat: any(named: 'lat'),
        lon: any(named: 'lon'),
        uuid: any(named: 'uuid'),
      ),
    ).thenThrow(UvApiException(500, 'server error'));

    final ProviderContainer container = _makeContainerWith(mockApi);

    await container.read(uvProvider.notifier).fetch(lat: 51.5, lon: -0.1);

    expect(container.read(uvProvider), isA<AsyncError<UvData>>());
  });

  // ---------------------------------------------------------------------------
  // uvApiProvider fallback — no constructor injection
  // ---------------------------------------------------------------------------

  test('fetch() uses uvApiProvider when no api is injected', () async {
    final UvData data = _makeData();
    when(
      () => mockApi.fetch(
        lat: any(named: 'lat'),
        lon: any(named: 'lon'),
        uuid: any(named: 'uuid'),
      ),
    ).thenAnswer((_) async => data);

    // No api passed to UvNotifier; it must fall back to uvApiProvider.
    final ProviderContainer container = ProviderContainer(
      // Override type inference is not exposed publicly in flutter_riverpod.
      // ignore: always_specify_types
      overrides: [
        uvProvider.overrideWith(UvNotifier.new),
        uvApiProvider.overrideWith((_) async => mockApi),
        deviceIdProvider.overrideWith((_) async => 'test-uuid'),
      ],
    );
    addTearDown(container.dispose);

    final Completer<UvData> completer = Completer<UvData>();
    container.listen<AsyncValue<UvData>>(uvProvider, (
      _,
      AsyncValue<UvData> next,
    ) {
      next.whenData<void>(completer.complete);
    });

    unawaited(container.read(uvProvider.notifier).fetch(lat: 51.5, lon: -0.1));

    final UvData result = await completer.future;
    expect(result, data);
  });

  // ---------------------------------------------------------------------------
  // cacheProvider and uvApiProvider — happy path via overrides
  // ---------------------------------------------------------------------------

  test('cacheProvider resolves to a Cache backed by Preferences', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final Cache cache = await container.read(cacheProvider.future);
    expect(cache, isA<Cache>());
  });

  test('uvApiProvider resolves to UvApi when proxyBaseUrl is non-empty',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final ProviderContainer container = ProviderContainer(
      // Override type inference is not exposed publicly in flutter_riverpod.
      // ignore: always_specify_types
      overrides: [
        proxyBaseUrlProvider.overrideWithValue('https://proxy.example.com'),
      ],
    );
    addTearDown(container.dispose);

    final UvApi api = await container.read(uvApiProvider.future);
    expect(api, isA<UvApi>());
  });

  // ---------------------------------------------------------------------------
  // uvApiProvider — empty proxyBaseUrl
  // ---------------------------------------------------------------------------

  test('uvApiProvider throws StateError when proxyBaseUrl is empty', () async {
    // proxyBaseUrl is '' in tests (no --dart-define), so uvApiProvider must
    // throw before constructing a UvApi.
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(uvApiProvider.future),
      throwsStateError,
    );
  });

  // ---------------------------------------------------------------------------
  // build() microtask — error path while container is still mounted
  // ---------------------------------------------------------------------------

  test(
    'build() microtask sets AsyncError when deviceIdProvider throws',
    () async {
      final ProviderContainer container = ProviderContainer(
        // Override type inference is not exposed publicly in flutter_riverpod.
        // ignore: always_specify_types
        overrides: [
          uvProvider.overrideWith(() => UvNotifier(api: mockApi)),
          deviceIdProvider.overrideWith(
            (_) async => throw StateError('device id unavailable'),
          ),
          locationProvider.overrideWith(LocationNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      final Completer<AsyncValue<UvData>> errorState =
          Completer<AsyncValue<UvData>>();
      container.listen<AsyncValue<UvData>>(uvProvider, (
        _,
        AsyncValue<UvData> next,
      ) {
        if (next is AsyncError<UvData> && !errorState.isCompleted) {
          errorState.complete(next);
        }
      });

      container.read(locationProvider.notifier).setManual(lat: 1, lon: 2);

      final AsyncValue<UvData> result = await errorState.future;
      expect(result, isA<AsyncError<UvData>>());
    },
  );

  // ---------------------------------------------------------------------------
  // Generation counter — stale microtask is discarded
  // ---------------------------------------------------------------------------

  test('rapid location changes discard the first stale fetch', () async {
    final UvData data = _makeData();
    final Completer<void> allowFirstFetch = Completer<void>();

    // First call: stall; second call: resolve immediately.
    int callCount = 0;
    when(
      () => mockApi.fetch(
        lat: any(named: 'lat'),
        lon: any(named: 'lon'),
        uuid: any(named: 'uuid'),
      ),
    ).thenAnswer((_) async {
      callCount++;
      if (callCount == 1) {
        await allowFirstFetch.future;
      }
      return data;
    });

    final ProviderContainer container = ProviderContainer(
      // Override type inference is not exposed publicly in flutter_riverpod.
      // ignore: always_specify_types
      overrides: [
        uvProvider.overrideWith(() => UvNotifier(api: mockApi)),
        deviceIdProvider.overrideWith((_) async => 'test-uuid'),
        locationProvider.overrideWith(LocationNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    // Prime both providers before any location change so the microtasks
    // that fire inside build() can reach their .wait without blocking.
    container.read(uvProvider);
    await container.read(deviceIdProvider.future);

    final Completer<UvData> secondDone = Completer<UvData>();
    container.listen<AsyncValue<UvData>>(uvProvider, (
      _,
      AsyncValue<UvData> next,
    ) {
      if (!secondDone.isCompleted) next.whenData<void>(secondDone.complete);
    });

    // Fire both location changes before yielding; the second increments
    // _fetchGeneration so fetch #1's microtask sees a stale generation.
    container.read(locationProvider.notifier).setManual(lat: 1, lon: 2);
    container.read(locationProvider.notifier).setManual(lat: 10, lon: 20);

    // Release fetch #1 (stale — discarded) and let fetch #2 run.
    allowFirstFetch.complete();

    final UvData result = await secondDone.future;
    expect(result, data);

    // The second fetch (lat:10, lon:20) must have produced the final data.
    verify(
      () => mockApi.fetch(lat: 10, lon: 20, uuid: 'test-uuid'),
    ).called(1);
  });

  // ---------------------------------------------------------------------------
  // Location change triggers auto-fetch
  // ---------------------------------------------------------------------------

  test('setManual() triggers auto-fetch via build() watcher', () async {
    final UvData data = _makeData();
    when(
      () => mockApi.fetch(
        lat: any(named: 'lat'),
        lon: any(named: 'lon'),
        uuid: any(named: 'uuid'),
      ),
    ).thenAnswer((_) async => data);

    final ProviderContainer container = ProviderContainer(
      // Override type inference is not exposed publicly in flutter_riverpod.
      // ignore: always_specify_types
      overrides: [
        uvProvider.overrideWith(() => UvNotifier(api: mockApi)),
        deviceIdProvider.overrideWith((_) async => 'test-uuid'),
        locationProvider.overrideWith(LocationNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    // Read uvProvider first so build() starts watching locationProvider.
    // Await deviceIdProvider so it is resolved before setManual fires build()
    // again — ensures the microtask's concurrent .wait completes in one turn.
    container.read(uvProvider);
    await container.read(deviceIdProvider.future);

    final Completer<UvData> completer = Completer<UvData>();
    container.listen<AsyncValue<UvData>>(uvProvider, (
      _,
      AsyncValue<UvData> next,
    ) {
      next.whenData<void>(completer.complete);
    });

    container.read(locationProvider.notifier).setManual(lat: 10, lon: 20);

    final UvData result = await completer.future;
    expect(result, data);

    // Confirm the fetch was triggered by the build() watcher, not a direct
    // call, and that it received the coordinates from setManual().
    verify(() => mockApi.fetch(lat: 10, lon: 20, uuid: 'test-uuid')).called(1);
    verifyNoMoreInteractions(mockApi);
  });
}
