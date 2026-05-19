import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:uvalert/storage/preferences.dart';

/// Returns the persisted device UUID, generating and storing one on first use.
///
/// The UUID is stored in [Preferences] under the `uvalert_uuid` key and reused
/// on every subsequent launch so the same device ID is sent with every request.
final FutureProvider<String> deviceIdProvider = FutureProvider<String>(
  (Ref ref) async {
    final Preferences prefs = await Preferences.load();
    final String? stored = prefs.uuid;

    if (stored != null) return stored;

    final String id = const Uuid().v4();
    await prefs.setUuid(id);
    return id;
  },
);
