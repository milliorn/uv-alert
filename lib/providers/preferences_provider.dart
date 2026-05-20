import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/storage/preferences.dart';

/// Provides the shared [Preferences] instance.
final FutureProvider<Preferences> preferencesProvider =
    FutureProvider<Preferences>((Ref ref) async => Preferences.load());
