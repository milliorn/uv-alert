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

  /// Sets the active theme and persists it to preferences.
  Future<void> setTheme(String theme) async {
    final SettingsState? current = state.value;
    if (current == null) return;

    final Preferences prefs = await ref.read(preferencesProvider.future);
    await prefs.setTheme(theme);

    if (!ref.mounted) return;

    state = AsyncValue<SettingsState>.data(current.copyWith(theme: theme));
  }

  /// Sets whether GPS location is enabled and persists it to preferences.
  Future<void> setUseGps({required bool value}) async {
    final SettingsState? current = state.value;
    if (current == null) return;

    final Preferences prefs = await ref.read(preferencesProvider.future);
    await prefs.setUseGps(value: value);

    if (!ref.mounted) return;

    state = AsyncValue<SettingsState>.data(current.copyWith(useGps: value));
  }

  /// Sets the manual location string and persists it to preferences.
  Future<void> setManualLocation(String location) async {
    final SettingsState? current = state.value;
    if (current == null) return;

    final Preferences prefs = await ref.read(preferencesProvider.future);
    await prefs.setManualLocation(location);

    if (!ref.mounted) return;

    state = AsyncValue<SettingsState>.data(
      current.copyWith(manualLocation: location),
    );
  }

  /// Sets whether push notifications are enabled and persists it to
  /// preferences.
  Future<void> setNotificationsEnabled({required bool value}) async {
    final SettingsState? current = state.value;
    if (current == null) return;

    final Preferences prefs = await ref.read(preferencesProvider.future);
    await prefs.setNotificationsEnabled(value: value);

    if (!ref.mounted) return;

    state = AsyncValue<SettingsState>.data(
      current.copyWith(notificationsEnabled: value),
    );
  }
}
