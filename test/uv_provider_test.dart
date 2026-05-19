import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uvalert/api/uv_api.dart';
import 'package:uvalert/models/uv_model.dart';
import 'package:uvalert/providers/location_provider.dart';
import 'package:uvalert/providers/uv_provider.dart';

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

ProviderContainer _makeContainer(_MockUvApi api) {
  return ProviderContainer(
    // Override type inference is not exposed publicly in flutter_riverpod.
    // ignore: always_specify_types
    overrides: [uvProvider.overrideWith(() => UvNotifier(api: api))],
  );
}

void main() {
  late _MockUvApi mockApi;

  setUpAll(() {
    registerFallbackValue(_FakeUvData());
  });

  setUp(() {
    mockApi = _MockUvApi();
  });

  // ---------------------------------------------------------------------------
  // Initial state
  // ---------------------------------------------------------------------------

  test('initial state is AsyncLoading when location is null', () {
    final ProviderContainer container = _makeContainer(mockApi);
    addTearDown(container.dispose);

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

    final ProviderContainer container = _makeContainer(mockApi);
    addTearDown(container.dispose);

    await container
        .read(uvProvider.notifier)
        .fetch(lat: 51.5, lon: -0.1, uuid: 'test-uuid');

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

    final ProviderContainer container = _makeContainer(mockApi);
    addTearDown(container.dispose);

    await container
        .read(uvProvider.notifier)
        .fetch(lat: 51.5, lon: -0.1, uuid: 'test-uuid');

    expect(container.read(uvProvider), isA<AsyncError<UvData>>());
  });

  // ---------------------------------------------------------------------------
  // No api configured
  // ---------------------------------------------------------------------------

  test('fetch() sets AsyncError(StateError) when api is null', () async {
    final ProviderContainer container = ProviderContainer(
      // Override type inference is not exposed publicly in flutter_riverpod.
      // ignore: always_specify_types
      overrides: [uvProvider.overrideWith(UvNotifier.new)],
    );
    addTearDown(container.dispose);

    await container
        .read(uvProvider.notifier)
        .fetch(lat: 0, lon: 0, uuid: 'test-uuid');

    final AsyncValue<UvData> state = container.read(uvProvider);
    expect(state, isA<AsyncError<UvData>>());
    expect(state.error, isA<StateError>());
  });

  // ---------------------------------------------------------------------------
  // Location change triggers auto-fetch
  // ---------------------------------------------------------------------------

  test('setting location then fetching returns data', () async {
    final UvData data = _makeData();
    when(
      () => mockApi.fetch(
        lat: any(named: 'lat'),
        lon: any(named: 'lon'),
        uuid: any(named: 'uuid'),
      ),
    ).thenAnswer((_) async => data);

    final ProviderContainer container = _makeContainer(mockApi);
    addTearDown(container.dispose);

    container.read(locationProvider.notifier).setManual(lat: 10, lon: 20);

    await container
        .read(uvProvider.notifier)
        .fetch(lat: 10, lon: 20, uuid: 'test-uuid');

    expect(container.read(uvProvider).value, data);
  });
}
