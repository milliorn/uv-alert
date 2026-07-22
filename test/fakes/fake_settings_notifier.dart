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

/// Returns data immediately with a non-null [SettingsState.manualLocation].
///
/// Use when a test needs a resolved city/state, e.g. for `DashboardFooter`.
class FakeManualLocationSettingsNotifier extends SettingsNotifier {
  @override
  AsyncValue<SettingsState> build() => const AsyncValue<SettingsState>.data(
    SettingsState(
      themeMode: ThemeMode.system,
      useGps: false,
      manualLocation: 'Fresno, CA, US',
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
