import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/storage/preferences.dart';

/// Holds the user-facing settings state.
class SettingsState {
  /// Creates a [SettingsState] with all fields required.
  const SettingsState({
    required this.theme,
    required this.useGps,
    required this.manualLocation,
    required this.notificationsEnabled,
  });

  /// Active theme name; one of `'system'`, `'light'`, or `'dark'`.
  final String theme;

  /// Whether GPS location is enabled. When `false`, [manualLocation] is used.
  final bool useGps;

  /// Manually entered location string; `null` when not set.
  final String? manualLocation;

  /// Whether push notifications are enabled.
  final bool notificationsEnabled;

  /// Returns a copy of this state with the given fields replaced.
  SettingsState copyWith({
    String? theme,
    bool? useGps,
    String? manualLocation,
    bool? notificationsEnabled,
    bool clearManualLocation = false,
  }) {
    return SettingsState(
      theme: theme ?? this.theme,
      useGps: useGps ?? this.useGps,
      manualLocation: clearManualLocation
          ? null
          : (manualLocation ?? this.manualLocation),
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

/// Riverpod provider for [SettingsNotifier].
final NotifierProvider<SettingsNotifier, AsyncValue<SettingsState>>
settingsProvider =
    NotifierProvider<SettingsNotifier, AsyncValue<SettingsState>>(
      SettingsNotifier.new,
    );

/// Manages user settings state.
///
/// Reads initial values from preferences on first build and persists each
/// change back immediately.
class SettingsNotifier extends Notifier<AsyncValue<SettingsState>> {
  @override
  AsyncValue<SettingsState> build() {
    unawaited(
      Future<void>.microtask(() async {
        try {
          final Preferences prefs = await ref.read(preferencesProvider.future);

          if (!ref.mounted) return;

          state = AsyncValue<SettingsState>.data(
            SettingsState(
              theme: prefs.theme,
              useGps: prefs.useGps,
              manualLocation: prefs.manualLocation,
              notificationsEnabled: prefs.notificationsEnabled,
            ),
          );
        } on Object catch (e, st) {
          if (!ref.mounted) return;

          state = AsyncValue<SettingsState>.error(e, st);
        }
      }),
    );
    return const AsyncValue<SettingsState>.loading();
  }

  /// Sets the active theme.
  Future<void> setTheme(String theme) => _update(
    persist: (Preferences prefs) => prefs.setTheme(theme),
    update: (SettingsState s) => s.copyWith(theme: theme),
  );

  /// Sets whether GPS location is enabled.
  Future<void> setUseGps({required bool value}) => _update(
    persist: (Preferences prefs) => prefs.setUseGps(value: value),
    update: (SettingsState s) => s.copyWith(useGps: value),
  );

  /// Sets the manual location string.
  Future<void> setManualLocation(String location) => _update(
    persist: (Preferences prefs) => prefs.setManualLocation(location),
    update: (SettingsState s) => s.copyWith(manualLocation: location),
  );

  /// Sets whether push notifications are enabled.
  Future<void> setNotificationsEnabled({required bool value}) => _update(
    persist: (Preferences prefs) => prefs.setNotificationsEnabled(value: value),
    update: (SettingsState s) => s.copyWith(notificationsEnabled: value),
  );

  Future<void> _update({
    required Future<void> Function(Preferences) persist,
    required SettingsState Function(SettingsState) update,
  }) async {
    final Preferences prefs = await ref.read(preferencesProvider.future);
    await persist(prefs);

    if (!ref.mounted) return;

    final SettingsState? current = state.value;
    if (current == null) return;

    state = AsyncValue<SettingsState>.data(update(current));
  }
}
