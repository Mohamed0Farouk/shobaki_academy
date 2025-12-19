import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeviceFingerprint {
  static Future<String> getFingerprint() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();

      String rawFingerprint = '';

      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = await deviceInfo.androidInfo;
        rawFingerprint =
            '${android.id}-${android.model}-${packageInfo.packageName}';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = await deviceInfo.iosInfo;
        rawFingerprint =
            '${ios.identifierForVendor}-${ios.model}-${packageInfo.packageName}';
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        final windows = await deviceInfo.windowsInfo;
        rawFingerprint =
            '${windows.deviceId}-${windows.computerName}-${packageInfo.packageName}';
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        final mac = await deviceInfo.macOsInfo;
        rawFingerprint = '${mac.systemGUID}-${packageInfo.packageName}';
      } else {
        rawFingerprint =
            '${defaultTargetPlatform.name}-${packageInfo.packageName}';
      }

      return rawFingerprint;
    } catch (e) {
      return 'unknown-${DateTime.now().millisecondsSinceEpoch}';
    }
  }
}
