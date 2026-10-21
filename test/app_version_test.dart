import 'package:flutter_test/flutter_test.dart';
import 'package:shobaki_academy/services/app_version.dart';

void main() {
  group('isVersionAtLeast', () {
    test('the boundary: equal versions satisfy the requirement', () {
      expect(isVersionAtLeast('1.2.3', '1.2.3'), isTrue);
    });

    test('a newer app satisfies the requirement', () {
      expect(isVersionAtLeast('2.0.0', '1.9.9'), isTrue);
      expect(isVersionAtLeast('1.3.0', '1.2.9'), isTrue);
      expect(isVersionAtLeast('1.2.4', '1.2.3'), isTrue);
    });

    test('an older app does not - the update sheet is forced', () {
      expect(isVersionAtLeast('1.2.3', '1.2.4'), isFalse);
      expect(isVersionAtLeast('1.2.9', '1.3.0'), isFalse);
      expect(isVersionAtLeast('1.9.9', '2.0.0'), isFalse);
    });

    test('pads the shorter version with zeros', () {
      expect(isVersionAtLeast('1.2', '1.2.0'), isTrue);
      expect(isVersionAtLeast('1.2.0', '1.2'), isTrue);
      expect(isVersionAtLeast('1.2', '1.2.1'), isFalse);
      expect(isVersionAtLeast('1.3', '1.2.9'), isTrue);
    });

    test('unparsable values never force an update', () {
      // A malformed dashboard value must not lock students out of the app.
      expect(isVersionAtLeast('1.2.3', 'not-a-version'), isTrue);
      expect(isVersionAtLeast('not-a-version', '1.2.3'), isTrue);
      expect(isVersionAtLeast('1.2.3', ''), isTrue);
      expect(isVersionAtLeast('1.2.0', '1.2.x'), isTrue);
    });
  });

  group('parsePlatformVersionEntry', () {
    test('reads the entry for the given platform', () {
      final column = {
        'android': {'version': '2.1.0', 'whats_new': '• إصلاح X\n• إضافة Y'},
        'windows': {'version': '1.4.0', 'whats_new': 'تحسينات'},
      };

      final windows = parsePlatformVersionEntry(column, platform: 'windows');
      expect(windows?.version, '1.4.0');
      expect(windows?.whatsNew, 'تحسينات');

      final android = parsePlatformVersionEntry(column, platform: 'android');
      expect(android?.version, '2.1.0');
      expect(android?.whatsNew, '• إصلاح X\n• إضافة Y');
    });

    test('matches the platform key case-insensitively', () {
      // The jsonb column is hand-edited; a capitalised key must not silently
      // disable the update check.
      final column = {
        'Windows': {'version': '1.4.0'},
      };
      expect(
        parsePlatformVersionEntry(column, platform: 'windows')?.version,
        '1.4.0',
      );
    });

    test('missing whats_new collapses to null', () {
      final column = {
        'windows': {'version': '1.4.0'},
      };
      final entry = parsePlatformVersionEntry(column, platform: 'windows');
      expect(entry?.version, '1.4.0');
      expect(entry?.whatsNew, isNull);
    });

    test('blank whats_new collapses to null', () {
      final column = {
        'windows': {'version': '1.4.0', 'whats_new': '   '},
      };
      expect(
        parsePlatformVersionEntry(column, platform: 'windows')?.whatsNew,
        isNull,
      );
    });

    test('an entry without a usable version is not a forced update', () {
      expect(
        parsePlatformVersionEntry({
          'windows': {'whats_new': 'x'},
        }, platform: 'windows'),
        isNull,
      );
      expect(
        parsePlatformVersionEntry({
          'windows': {'version': ''},
        }, platform: 'windows'),
        isNull,
      );
      expect(
        parsePlatformVersionEntry({
          'windows': {'version': null},
        }, platform: 'windows'),
        isNull,
      );
    });

    test('a platform that is not in the column is not a forced update', () {
      final column = {
        'android': {'version': '2.1.0'},
      };
      expect(parsePlatformVersionEntry(column, platform: 'windows'), isNull);
    });

    test('a missing or malformed column is not a forced update', () {
      expect(parsePlatformVersionEntry(null, platform: 'windows'), isNull);
      expect(parsePlatformVersionEntry([], platform: 'windows'), isNull);
      expect(parsePlatformVersionEntry('nope', platform: 'windows'), isNull);
      expect(
        parsePlatformVersionEntry({
          'windows': 'not a map',
        }, platform: 'windows'),
        isNull,
      );
    });
  });
}
