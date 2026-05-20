import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uvalert/providers/device_id_provider.dart';

// The v4 UUID pattern is inherently longer than 80 chars; kept as a constant
// so it is defined once and not duplicated across tests.
final RegExp _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

ProviderContainer _makeContainer() {
  final ProviderContainer container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

void main() {
  // ---------------------------------------------------------------------------
  // No stored UUID
  // ---------------------------------------------------------------------------

  group('deviceIdProvider — no stored UUID', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('generates a non-empty UUID on first use', () async {
      final String id = await _makeContainer().read(deviceIdProvider.future);

      expect(id, isNotEmpty);
    });

    test('generated UUID is a valid v4 UUID', () async {
      final String id = await _makeContainer().read(deviceIdProvider.future);

      expect(_uuidV4.hasMatch(id), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Stored UUID
  // ---------------------------------------------------------------------------

  group('deviceIdProvider — stored UUID', () {
    const String stored = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';

    setUp(() {
      // Preferences._keyUuid is private; the literal must be duplicated here.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'uvalert_uuid': stored,
      });
    });

    test('returns the stored UUID without generating a new one', () async {
      final String id = await _makeContainer().read(deviceIdProvider.future);

      expect(id, stored);
    });
  });

  // ---------------------------------------------------------------------------
  // Empty stored UUID (platform quirk guard)
  // ---------------------------------------------------------------------------

  group('deviceIdProvider — empty stored UUID', () {
    setUp(() {
      // Preferences._keyUuid is private; the literal must be duplicated here.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'uvalert_uuid': '',
      });
    });

    test('generates a fresh UUID when stored value is empty string', () async {
      final String id = await _makeContainer().read(deviceIdProvider.future);

      expect(id, isNotEmpty);
    });

    test(
      'generated UUID after empty-string guard is a valid v4 UUID',
      () async {
        final String id = await _makeContainer().read(deviceIdProvider.future);

        expect(_uuidV4.hasMatch(id), isTrue);
      },
    );
  });
}
