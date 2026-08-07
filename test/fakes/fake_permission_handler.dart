import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

/// Configurable test double for [PermissionHandlerPlatform].
///
/// A hand-written fake (rather than a Mocktail mock via
/// `MockPlatformInterfaceMixin`, as used for `UrlLauncherPlatform` in
/// `dashboard_footer_test.dart`) so per-field defaults and call flags are
/// simple properties. Each field can be set per-test before the service
/// under test runs.
class FakePermissionHandlerPlatform extends PermissionHandlerPlatform {
  /// Status returned by [requestPermissions] for [Permission.notification].
  PermissionStatus requestResult = PermissionStatus.granted;

  /// Value returned by [openAppSettings].
  bool openAppSettingsResult = true;

  /// Set to `true` once [openAppSettings] has been invoked.
  bool openAppSettingsCalled = false;

  /// Set to `true` once [requestPermissions] has been invoked.
  bool requestCalled = false;

  /// When set, [requestPermissions] throws this instead of returning.
  Object? throwOnRequest;

  /// When set, [openAppSettings] throws this instead of returning.
  Object? throwOnOpenAppSettings;

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    requestCalled = true;

    if (throwOnRequest != null) {
      // ignore: only_throw_errors (test fake injects arbitrary error values)
      throw throwOnRequest!;
    }

    return <Permission, PermissionStatus>{
      Permission.notification: requestResult,
    };
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalled = true;

    if (throwOnOpenAppSettings != null) {
      // ignore: only_throw_errors (test fake injects arbitrary error values)
      throw throwOnOpenAppSettings!;
    }

    return openAppSettingsResult;
  }
}
