import 'package:package_info_plus/package_info_plus.dart';

Future<String?> loadAppVersionLabel() async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version} (${packageInfo.buildNumber})';
  } catch (_) {
    return null;
  }
}
