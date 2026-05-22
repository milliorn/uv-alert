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
}
