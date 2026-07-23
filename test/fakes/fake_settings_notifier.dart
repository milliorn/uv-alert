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
      manualLat: null,
      manualLon: null,
      notificationsEnabled: false,
    ),
  );
}

/// Returns data immediately with the given [manualLocation].
///
/// Use when a test needs a specific resolved (or empty-but-not-null)
/// location, e.g. for `DashboardFooter`.
class FakeManualLocationSettingsNotifier extends SettingsNotifier {
  /// Creates a [FakeManualLocationSettingsNotifier] that resolves with
  /// [manualLocation], defaulting to `'Fresno, CA, US'`. [manualLat] and
  /// [manualLon] default to `null`; set both to exercise a test that needs
  /// coordinates alongside the display string, e.g. location restoration.
  /// [useGps] defaults to `false`.
  FakeManualLocationSettingsNotifier([
    this.manualLocation = 'Fresno, CA, US',
    this.manualLat,
    this.manualLon,
  ]) : useGps = false;

  /// Creates a [FakeManualLocationSettingsNotifier] with [useGps] set to
  /// `true`, so location restoration should not use [manualLat]/[manualLon].
  FakeManualLocationSettingsNotifier.gps([
    this.manualLocation = 'Fresno, CA, US',
    this.manualLat,
    this.manualLon,
  ]) : useGps = true;

  /// The location returned by [build].
  final String manualLocation;

  /// The latitude returned by [build].
  final double? manualLat;

  /// The longitude returned by [build].
  final double? manualLon;

  /// The GPS toggle returned by [build].
  final bool useGps;

  @override
  AsyncValue<SettingsState> build() => AsyncValue<SettingsState>.data(
    SettingsState(
      themeMode: ThemeMode.system,
      useGps: useGps,
      manualLocation: manualLocation,
      manualLat: manualLat,
      manualLon: manualLon,
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
