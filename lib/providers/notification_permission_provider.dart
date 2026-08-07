import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

/// Riverpod provider for [NotificationPermissionService].
final Provider<NotificationPermissionService> notificationPermissionProvider =
    Provider<NotificationPermissionService>(
      (Ref ref) => NotificationPermissionService(),
    );

/// Requests and manages the OS notification permission.
class NotificationPermissionService {
  /// Creates a [NotificationPermissionService]; [platform] defaults to
  /// [PermissionHandlerPlatform.instance] for production use.
  NotificationPermissionService({PermissionHandlerPlatform? platform})
    : _platform = platform ?? PermissionHandlerPlatform.instance;

  final PermissionHandlerPlatform _platform;

  /// Requests OS notification permission and returns the resulting status.
  Future<PermissionStatus> requestNotificationPermission() async {
    final Map<Permission, PermissionStatus> result = await _platform
        .requestPermissions(<Permission>[Permission.notification]);

    return result[Permission.notification] ?? PermissionStatus.denied;
  }

  /// Opens the device's app settings page.
  Future<bool> openAppSettings() => _platform.openAppSettings();
}
