import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/providers/preferences_provider.dart';
import 'package:uvalert/storage/preferences.dart';

/// Holds the user-facing settings state.
class SettingsState {
  /// Creates a [SettingsState] with all fields required.
  const SettingsState({
    required this.themeMode,
    required this.useGps,
    required this.manualLocation,
    required this.notificationsEnabled,
  });

  /// The active [ThemeMode].
  final ThemeMode themeMode;

  /// Whether GPS location is enabled. When `false`, [manualLocation] is used.
  final bool useGps;

  /// Manually entered location string; `null` when not set.
  final String? manualLocation;

  /// Whether push notifications are enabled.
  final bool notificationsEnabled;

  /// Returns a copy of this state with the given fields replaced.
  ///
  /// [manualLocation] defaults to the current value when omitted. To represent
  /// "not set", pass `null` only at construction time -- this method cannot
  /// clear [manualLocation] back to `null` once a value has been stored.
  SettingsState copyWith({
    ThemeMode? themeMode,
    bool? useGps,
    String? manualLocation,
    bool? notificationsEnabled,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      useGps: useGps ?? this.useGps,
      manualLocation: manualLocation ?? this.manualLocation,
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
///
/// Uses `Notifier<AsyncValue<SettingsState>>` rather than
/// `AsyncNotifier<SettingsState>` intentionally. `AsyncNotifier.update()`
/// puts the provider back into a loading state on every mutation, which
/// causes UI flicker on each settings change. The manual `AsyncValue`
/// wrapping here enables optimistic writes: state is updated synchronously
/// while persistence happens in the background, keeping the UI responsive.
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
              themeMode: prefs.theme,
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
  Future<void> setTheme(ThemeMode themeMode) => _update(
    persist: (Preferences prefs) => prefs.setTheme(themeMode),
    update: (SettingsState s) => s.copyWith(themeMode: themeMode),
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

    state = AsyncValue<SettingsState>.data(update(state.requireValue));
  }
}
