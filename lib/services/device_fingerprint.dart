import 'dart:ffi';
import 'dart:io';
import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeviceFingerprint {
  /// Version prefix for the current fingerprint format. Fingerprints without
  /// this prefix are treated as legacy and are re-locked on the next login.
  static const String versionPrefix = 'v2:';

  static bool isCurrentVersion(String fingerprint) =>
      fingerprint.startsWith(versionPrefix);

  static Future<String> getFingerprint() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();

      final String base = packageInfo.packageName;
      final TargetPlatform platform = defaultTargetPlatform;

      String hardwareId;
      String platformName;

      switch (platform) {
        case TargetPlatform.windows:
          final uuid = await getBiosUuid();
          final windows = await deviceInfo.windowsInfo;
          hardwareId = uuid ?? '${windows.deviceId}-${windows.computerName}';
          platformName = 'Windows';
          break;
        case TargetPlatform.macOS:
          final uuid = await getBiosUuid();
          final mac = await deviceInfo.macOsInfo;
          hardwareId = uuid ?? (mac.systemGUID ?? '');
          platformName = 'MacOS';
          break;
        case TargetPlatform.linux:
          final uuid = await getBiosUuid();
          hardwareId = uuid ?? 'linux-${packageInfo.buildNumber}';
          platformName = 'Linux';
          break;
        case TargetPlatform.android:
          final android = await deviceInfo.androidInfo;
          String? androidId;
          try {
            androidId = await AndroidId().getId();
          } catch (_) {}
          hardwareId = '${androidId ?? android.id}-${android.model}';
          platformName = 'Android';
          break;
        case TargetPlatform.iOS:
          final ios = await deviceInfo.iosInfo;
          hardwareId = '${ios.identifierForVendor}-${ios.model}';
          platformName = 'IOS';
          break;
        default:
          return '$versionPrefix${platform.name}-$base';
      }

      return '$versionPrefix$hardwareId-$base-$platformName';
    } catch (e) {
      return '$versionPrefix unknown-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Best available motherboard/BIOS UUID for the current platform.
  /// Returns null when no reliable UUID can be read.
  static Future<String?> getBiosUuid() async {
    if (Platform.isWindows) return getWindowsBiosUuid();
    if (Platform.isMacOS) {
      try {
        final mac = await DeviceInfoPlugin().macOsInfo;
        final guid = mac.systemGUID;
        return (guid == null || guid.trim().isEmpty) ? null : guid.trim();
      } catch (_) {
        return null;
      }
    }
    if (Platform.isLinux) {
      try {
        final file = File('/sys/class/dmi/id/product_uuid');
        if (!await file.exists()) return null;
        final value = (await file.readAsString()).trim();
        return value.isEmpty ? null : value;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Reads the SMBIOS System Information (type 1) UUID on Windows via
  /// GetSystemFirmwareTable (kernel32).
  static String? getWindowsBiosUuid() {
    try {
      final size = _getSystemFirmwareTable(0x52534D42, 0, nullptr, 0);
      if (size == 0) return null;

      final buffer = calloc<Uint8>(size);
      try {
        final written = _getSystemFirmwareTable(0x52534D42, 0, buffer, size);
        if (written == 0) return null;

        final data = <int>[];
        for (var i = 0; i < written; i++) {
          data.add(buffer[i]);
        }
        return parseSmbiosUuid(data);
      } finally {
        calloc.free(buffer);
      }
    } catch (_) {
      return null;
    }
  }

  /// Extracts the type 1 (System Information) UUID from the raw RSMB table
  /// returned by GetSystemFirmwareTable (8-byte RawSMBIOSData header followed
  /// by the raw SMBIOS structures).
  static String? parseSmbiosUuid(List<int> data) {
    if (data.length < 8) return null;

    var offset = 8; // skip RawSMBIOSData header
    while (offset + 4 <= data.length) {
      final type = data[offset];
      final length = data[offset + 1];
      if (length < 4 || offset + length > data.length) break;

      if (type == 1 && length >= 24) {
        return formatSmbiosUuid(data.sublist(offset + 8, offset + 24));
      }

      var cursor = offset + length;
      while (cursor + 1 < data.length &&
          !(data[cursor] == 0 && data[cursor + 1] == 0)) {
        cursor++;
      }
      offset = cursor + 2;
      if (type == 127) break;
    }
    return null;
  }

  /// Formats the raw 16-byte SMBIOS UUID using the same byte order as
  /// `Win32_ComputerSystemProduct.UUID`.
  static String formatSmbiosUuid(List<int> b) {
    if (b.length != 16) return '';
    String hex(int v) => v.toRadixString(16).padLeft(2, '0');
    return '${hex(b[3])}${hex(b[2])}${hex(b[1])}${hex(b[0])}-'
        '${hex(b[5])}${hex(b[4])}-'
        '${hex(b[7])}${hex(b[6])}-'
        '${hex(b[8])}${hex(b[9])}-'
        '${hex(b[10])}${hex(b[11])}${hex(b[12])}'
        '${hex(b[13])}${hex(b[14])}${hex(b[15])}';
  }
}

typedef _GetSystemFirmwareTableNative = Uint32 Function(
  Uint32 firmwareTableProviderSignature,
  Uint32 firmwareTableId,
  Pointer<Uint8> pFirmwareTableBuffer,
  Uint32 bufferSize,
);

typedef _GetSystemFirmwareTableDart = int Function(
  int firmwareTableProviderSignature,
  int firmwareTableId,
  Pointer<Uint8> pFirmwareTableBuffer,
  int bufferSize,
);

final _getSystemFirmwareTable = DynamicLibrary.open('kernel32.dll')
    .lookupFunction<_GetSystemFirmwareTableNative, _GetSystemFirmwareTableDart>(
  'GetSystemFirmwareTable',
);