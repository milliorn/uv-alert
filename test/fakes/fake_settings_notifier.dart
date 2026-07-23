import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uvalert/providers/settings_provider.dart';

/// Returns data immediately without reading preferences.
///
/// Use when a test needs the Continue button enabled but overrides
/// preferencesProvider to error (so [SettingsNotifier.build] never resolves).
class FakeLoadedSettingsNotifier extends SettingsNotifier {
  @override
  AsyncValue<SettingsState> build() => const AsyncValue<SettingsState>.data(
    SettingsState(
      themeMode: ThemeMode.system,
      useGps: false,
      manualLocation: null,
      notificationsEnabled: false,
    ),
  );
}

/// Returns data immediately with the given manual location name.
///
/// Use when a test needs a specific resolved (or empty-but-not-null)
/// location, e.g. for `DashboardFooter`.
class FakeManualLocationSettingsNotifier extends SettingsNotifier {
  /// Creates a [FakeManualLocationSettingsNotifier] that resolves with a
  /// [ManualLocation] named [name], defaulting to `'Fresno, CA, US'`. [lat]
  /// and [lon] default to `0`; only relevant to a test that needs specific
  /// coordinates alongside the display string, e.g. location restoration.
  FakeManualLocationSettingsNotifier([
    this.name = 'Fresno, CA, US',
    this.lat = 0,
    this.lon = 0,
  ]) : useGps = false;

  /// Creates a [FakeManualLocationSettingsNotifier] with [useGps] set to
  /// `true`, so location restoration should not use [lat]/[lon].
  FakeManualLocationSettingsNotifier.gps({
    this.name = 'Fresno, CA, US',
    this.lat = 0,
    this.lon = 0,
  }) : useGps = true;

  /// The location name returned by [build].
  final String name;

  /// The latitude returned by [build].
  final double lat;

  /// The longitude returned by [build].
  final double lon;

  /// The GPS toggle returned by [build].
  final bool useGps;

  @override
  AsyncValue<SettingsState> build() => AsyncValue<SettingsState>.data(
    SettingsState(
      themeMode: ThemeMode.system,
      useGps: useGps,
      manualLocation: (name: name, lat: lat, lon: lon),
      notificationsEnabled: false,
    ),
  );
}

/// Immediately emits an error state.
class FakeErrorSettingsNotifier extends SettingsNotifier {
  @override
  AsyncValue<SettingsState> build() => AsyncValue<SettingsState>.error(
    Exception('settings failed'),
    StackTrace.empty,
  );
}

/// Stays in loading state forever (useful for triggering timeouts).
class FakeLoadingSettingsNotifier extends SettingsNotifier {
  @override
  AsyncValue<SettingsState> build() =>
      const AsyncValue<SettingsState>.loading();
}
