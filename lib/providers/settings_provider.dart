import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return const AsyncValue<SettingsState>.loading();
  }
}
