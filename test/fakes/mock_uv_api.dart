import 'package:mocktail/mocktail.dart';
import 'package:uvalert/api/uv_api.dart';

/// Mocktail mock for [UvApi], shared across tests that need to stub or
/// verify `fetch` calls.
class MockUvApi extends Mock implements UvApi {}
