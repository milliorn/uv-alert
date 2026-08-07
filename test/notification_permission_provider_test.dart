import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uvalert/providers/notification_permission_provider.dart';

import 'fakes/fake_permission_handler.dart';

void main() {
  // -------------------------------------------------------------------------
  // requestNotificationPermission
  // -------------------------------------------------------------------------

  test('requestNotificationPermission returns granted', () async {
    final FakePermissionHandlerPlatform platform =
        FakePermissionHandlerPlatform()
          ..requestResult = PermissionStatus.granted;
    final NotificationPermissionService service = NotificationPermissionService(
      platform: platform,
    );

    final PermissionStatus result = await service
        .requestNotificationPermission();

    expect(result, PermissionStatus.granted);
    expect(platform.requestCalled, isTrue);
  });

  test('requestNotificationPermission returns denied', () async {
    final FakePermissionHandlerPlatform platform =
        FakePermissionHandlerPlatform()
          ..requestResult = PermissionStatus.denied;
    final NotificationPermissionService service = NotificationPermissionService(
      platform: platform,
    );

    final PermissionStatus result = await service
        .requestNotificationPermission();

    expect(result, PermissionStatus.denied);
  });

  test('requestNotificationPermission returns permanentlyDenied', () async {
    final FakePermissionHandlerPlatform platform =
        FakePermissionHandlerPlatform()
          ..requestResult = PermissionStatus.permanentlyDenied;
    final NotificationPermissionService service = NotificationPermissionService(
      platform: platform,
    );

    final PermissionStatus result = await service
        .requestNotificationPermission();

    expect(result, PermissionStatus.permanentlyDenied);
  });

  // -------------------------------------------------------------------------
  // openAppSettings
  // -------------------------------------------------------------------------

  test('openAppSettings delegates to the platform', () async {
    final FakePermissionHandlerPlatform platform =
        FakePermissionHandlerPlatform()..openAppSettingsResult = true;
    final NotificationPermissionService service = NotificationPermissionService(
      platform: platform,
    );

    final bool result = await service.openAppSettings();

    expect(result, isTrue);
    expect(platform.openAppSettingsCalled, isTrue);
  });

  // -------------------------------------------------------------------------
  // Default instance fallback
  // -------------------------------------------------------------------------

  test('constructs with the default platform instance when none supplied', () {
    expect(NotificationPermissionService(), isNotNull);
  });

  // -------------------------------------------------------------------------
  // Provider wiring
  // -------------------------------------------------------------------------

  test('notificationPermissionProvider creates a service instance', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final NotificationPermissionService service = container.read(
      notificationPermissionProvider,
    );

    expect(service, isA<NotificationPermissionService>());
  });
}
