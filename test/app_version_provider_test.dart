import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uvalert/providers/app_version_provider.dart';

void main() {
  test('resolves to the version from PackageInfo.fromPlatform', () async {
    PackageInfo.setMockInitialValues(
      appName: 'UV Alert',
      packageName: 'com.milliorn.uvalert',
      version: '1.2.3',
      buildNumber: '4',
      buildSignature: '',
    );

    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final String version = await container.read(appVersionProvider.future);

    expect(version, '1.2.3');
  });
}
