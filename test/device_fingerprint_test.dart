import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shobaki_academy/services/device_fingerprint.dart';

void main() {
  test('Windows BIOS UUID matches WMI Get-CimInstance', () async {
    if (!Platform.isWindows) return;

    final uuid = DeviceFingerprint.getWindowsBiosUuid();
    // ignore: avoid_print
    print('SMBIOS UUID=$uuid');

    expect(uuid, isNotNull, reason: 'BIOS UUID should be readable on Windows');
    expect(uuid, isNotEmpty);

    final result = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      '(Get-CimInstance Win32_ComputerSystemProduct).UUID',
    ]);
    final wmiUuid = result.stdout.toString().trim();
    // ignore: avoid_print
    print('WMI UUID=$wmiUuid');

    expect(
      uuid!.toLowerCase(),
      wmiUuid.toLowerCase(),
      reason: 'SMBIOS UUID should match Win32_ComputerSystemProduct.UUID',
    );

    final re = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    expect(re.hasMatch(uuid!), isTrue, reason: 'UUID format is invalid');
  });

  test('version prefix helpers', () {
    expect(DeviceFingerprint.isCurrentVersion('v2:abc'), isTrue);
    expect(DeviceFingerprint.isCurrentVersion('plain-fingerprint'), isFalse);
  });

  test('parseSmbiosUuid skips RawSMBIOSData header and formats byte order', () {
    // 8-byte RawSMBIOSData header, then a type 1 structure directly.
    final data = <int>[
      0x00, 0x03, 0x02, 0x00, // Used20CallingMethod, SMBIOSMajor/Minor, DmiRev
      0x00, 0x00, 0x00, 0x00, // Length (unused by parser)
      0x01, 24, 0x00, 0x00, // type 1, len 24, handle 0
      0x00, 0x00, 0x00, 0x00, // padding
      0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, // UUID 16 bytes
      0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10,
      0x00, 0x00, // strings terminator
    ];
    final uuid = DeviceFingerprint.parseSmbiosUuid(data);
    // Little-endian: 04-03-02-01-06-05-08-07-09-0A-0B-0C-0D-0E-0F-10
    expect(uuid, '04030201-0605-0807-090a-0b0c0d0e0f10');
  });
}