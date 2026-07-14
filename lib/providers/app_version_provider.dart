import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Returns the running app's version string (e.g. `'1.0.0'`), read from the
/// installed package's metadata.
///
/// Sent as the `app_version` query parameter on every proxy request so the
/// proxy can enforce a minimum supported version -- see
/// `docs/adr/0009-force-update-via-426.md`.
final FutureProvider<String> appVersionProvider = FutureProvider<String>((
  Ref ref,
) async {
  final PackageInfo info = await PackageInfo.fromPlatform();
  return info.version;
});
