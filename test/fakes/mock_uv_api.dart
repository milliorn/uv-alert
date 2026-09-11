import 'package:mocktail/mocktail.dart';
import 'package:uvalert/api/uv_api.dart';

/// Mocktail mock for [UvApi], shared across tests that need to stub or
/// verify `fetch` calls.
///
/// [wasLastFetchFromCache] is overridden with a real field (default `false`)
/// rather than left to mocktail's `noSuchMethod` dispatch, because mocktail
/// returns `null` for an unstubbed non-nullable getter -- which would throw
/// at the `!api.wasLastFetchFromCache` null-check in `uv_provider.dart` for
/// every test that doesn't explicitly stub it. Set it directly (rather than
/// via `when()`) in the rare test that needs to simulate a cache hit.
class MockUvApi extends Mock implements UvApi {
  @override
  bool wasLastFetchFromCache = false;
}
