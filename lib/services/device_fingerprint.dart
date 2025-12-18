import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeviceFingerprint {
  static Future<String> getFingerprint() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();

      String fingerprint = '';

      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        fingerprint =
            '${androidInfo.model}-${androidInfo.id}-${packageInfo.packageName}';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        fingerprint =
            '${iosInfo.model}-${iosInfo.identifierForVendor}-${packageInfo.packageName}';
      } else {
        fingerprint =
            '${defaultTargetPlatform.name}-${packageInfo.packageName}';
      }

      return fingerprint;
    } catch (e) {
      // If we can't get device info, generate a random fingerprint
      return 'unknown-device-${DateTime.now().millisecondsSinceEpoch}';
    }
  }
}
