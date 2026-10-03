import 'package:flutter_test/flutter_test.dart';
import 'package:shobaki_academy/controller/video_quality.dart';

const _manifest = '''
#EXTM3U
#EXT-X-VERSION:4
#EXT-X-STREAM-INF:BANDWIDTH=5400000,AVERAGE-BANDWIDTH=5000000,RESOLUTION=1920x1080,CODECS="avc1.640028,mp4a.40.2"
1080/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2800000,AVERAGE-BANDWIDTH=2400000,RESOLUTION=1280x720,CODECS="avc1.4d401f,mp4a.40.2"
720/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1400000,AVERAGE-BANDWIDTH=1200000,RESOLUTION=854x480,CODECS="avc1.4d401e,mp4a.40.2"
480/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=700000,AVERAGE-BANDWIDTH=600000,RESOLUTION=640x360
360/index.m3u8
''';

VideoQuality q(String label, {int? bandwidth, int? width, int? height}) =>
    VideoQuality(
      label: label,
      url: 'https://cdn.test/$label.m3u8',
      bandwidth: bandwidth,
      width: width,
      height: height,
    );

void main() {
  group('isHlsManifestUrl', () {
    test('matches a plain playlist URL', () {
      expect(isHlsManifestUrl('https://cdn.test/master.m3u8'), isTrue);
    });

    test('matches a signed URL that carries a query string', () {
      // This is the regression that mattered: the old `endsWith('.m3u8')`
      // check never matched these, so the quality menu was silently dead.
      expect(
        isHlsManifestUrl(
          'https://cdn.test/hls/master.m3u8?token=abc123&expires=99',
        ),
        isTrue,
      );
    });

    test('ignores the query string when deciding', () {
      expect(isHlsManifestUrl('https://cdn.test/master.m3u8?x=.mp4'), isTrue);
    });

    test('is case insensitive on the extension', () {
      expect(isHlsManifestUrl('https://cdn.test/MASTER.M3U8'), isTrue);
    });

    test('rejects a non-playlist URL', () {
      expect(isHlsManifestUrl('https://cdn.test/video.mp4'), isFalse);
      expect(isHlsManifestUrl('https://cdn.test/master.m3u8x'), isFalse);
    });

    test('rejects a malformed URL instead of throwing', () {
      expect(isHlsManifestUrl('::::not a url::::'), isFalse);
      expect(isHlsManifestUrl(''), isFalse);
    });

    test('matches a playlist on a non-http scheme', () {
      expect(isHlsManifestUrl('file:///C:/media/master.m3u8'), isTrue);
    });
  });

  group('parseHlsMasterPlaylist', () {
    final base = Uri.parse('https://cdn.test/hls/vod/master.m3u8?token=abc');

    test('parses every variant with resolution and bandwidth', () {
      final variants = parseHlsMasterPlaylist(_manifest, base);

      expect(variants, hasLength(4));
      expect(variants.map((v) => v.height).toList(), [1080, 720, 480, 360]);
      expect(variants.first.bandwidth, 5000000);
      expect(variants.first.width, 1920);
      expect(variants.first.label, '1080');
    });

    test('resolution labels carry no trailing "p"', () {
      // The menu is RTL. A trailing Latin letter sits at the line's start
      // position, so "720p" rendered with the `p` pushed to the far right,
      // visually detached from its own digits. Digits only sit flush.
      final variants = parseHlsMasterPlaylist(_manifest, base);
      for (final v in variants.where((v) => v.height != null)) {
        expect(
          RegExp(r'p$').hasMatch(v.label),
          isFalse,
          reason: '${v.label} should not end with "p"',
        );
        expect(v.label, '${v.height}');
      }
    });

    test('prefers AVERAGE-BANDWIDTH over the advertised peak', () {
      // BANDWIDTH is a peak and routinely overstates what a student can
      // sustain, which is what caused the repeated stalls in the first place.
      final variants = parseHlsMasterPlaylist(_manifest, base);
      expect(variants.first.bandwidth, 5000000);
    });

    test('resolves relative variant URIs against the playlist URL', () {
      final variants = parseHlsMasterPlaylist(_manifest, base);
      expect(variants.first.url, 'https://cdn.test/hls/vod/1080/index.m3u8');
    });

    test('drops the query string when resolving a relative variant', () {
      // base.resolve() would otherwise carry ?token=abc onto the variant,
      // which is at best wrong and at worst an auth failure.
      final variants = parseHlsMasterPlaylist(_manifest, base);
      expect(variants.first.url.contains('?'), isFalse);
    });

    test('handles an absolute variant URI unchanged', () {
      const body = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
https://other.test/360.m3u8
''';
      final variants = parseHlsMasterPlaylist(body, base);
      expect(variants.single.url, 'https://other.test/360.m3u8');
    });

    test('keeps a variant whose metadata is missing', () {
      const body = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
360.m3u8
''';
      final variants = parseHlsMasterPlaylist(body, base);
      expect(variants.single.bandwidth, 800000);
      expect(variants.single.height, 360);
    });

    test('labels a variant with no resolution by its bandwidth', () {
      const body = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=800000
800.m3u8
''';
      final variants = parseHlsMasterPlaylist(body, base);
      expect(variants.single.label, '800000 kbps');
    });

    test('returns empty for a media playlist rather than a master', () {
      const body = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:6
#EXTINF:6.0,
segment0.ts
''';
      expect(parseHlsMasterPlaylist(body, base), isEmpty);
    });

    test('returns empty for a body that is not a playlist at all', () {
      expect(parseHlsMasterPlaylist('<html>404</html>', base), isEmpty);
      expect(parseHlsMasterPlaylist('', base), isEmpty);
    });

    test('tolerates CRLF line endings', () {
      final crlf = _manifest.replaceAll('\n', '\r\n');
      expect(parseHlsMasterPlaylist(crlf, base), hasLength(4));
    });
  });

  group('selectAutoQualityIndex', () {
    test('returns the auto index when there are no variants', () {
      expect(selectAutoQualityIndex(const []), kAutoQualityIndex);
      expect(selectAutoQualityIndex([q('تلقائي')]), kAutoQualityIndex);
    });

    test('picks the highest rendition under the bitrate ceiling', () {
      final list = [
        q('تلقائي'),
        q('1080p', bandwidth: 5000000, height: 1080),
        q('720p', bandwidth: 2400000, height: 720),
        q('480p', bandwidth: 1200000, height: 480),
      ];
      // 720p fits under the 2.5 Mbps ceiling; 1080p does not.
      expect(selectAutoQualityIndex(list), 2);
    });

    test('includes a rendition sitting exactly on the ceiling', () {
      // Exactly at the ceiling is affordable; treating it as too expensive
      // would needlessly drop every student with a 2.5 Mbps link to 720p.
      final list = [
        q('تلقائي'),
        q('1080p', bandwidth: kAutoMaxBitrate, height: 1080),
        q('720p', bandwidth: 1000000, height: 720),
      ];
      expect(selectAutoQualityIndex(list), 1);
    });

    test('skips a rendition one bit over the ceiling', () {
      final list = [
        q('تلقائي'),
        q('1080p', bandwidth: kAutoMaxBitrate + 1, height: 1080),
        q('720p', bandwidth: 1000000, height: 720),
      ];
      expect(selectAutoQualityIndex(list), 2);
    });

    test('falls back to the cheapest when nothing is affordable', () {
      final list = [
        q('تلقائي'),
        q('1080p', bandwidth: 5000000, height: 1080),
        q('720p', bandwidth: 3000000, height: 720),
      ];
      expect(selectAutoQualityIndex(list), 2);
    });

    test('uses the height ceiling when bandwidth is absent', () {
      final list = [
        q('تلقائي'),
        q('1080p', height: 1080),
        q('720p', height: 720),
        q('480p', height: 480),
      ];
      expect(selectAutoQualityIndex(list), 2);
    });

    test('falls back to the lowest height when none fit the ceiling', () {
      final list = [
        q('تلقائي'),
        q('1080p', height: 1080),
        q('900p', height: 900),
      ];
      expect(selectAutoQualityIndex(list), 2);
    });

    test('stays on the first variant when no metadata is usable', () {
      final list = [q('تلقائي'), q('a'), q('b')];
      expect(selectAutoQualityIndex(list), 1);
    });

    test('honours a custom ceiling', () {
      final list = [
        q('تلقائي'),
        q('1080p', bandwidth: 5000000, height: 1080),
        q('480p', bandwidth: 1200000, height: 480),
      ];
      expect(selectAutoQualityIndex(list, maxAutoBitrate: 6000000), 1);
    });

    test('never returns the auto sentinel when variants exist', () {
      final list = [
        q('تلقائي'),
        q('1080p', bandwidth: 5000000, height: 1080),
        q('360p', bandwidth: 500000, height: 360),
      ];
      expect(selectAutoQualityIndex(list), isNot(kAutoQualityIndex));
    });
  });

  group('nextAutoQualityIndex', () {
    final list = [
      q('تلقائي'),
      q('1080p', bandwidth: 5000000, height: 1080),
      q('720p', bandwidth: 2400000, height: 720),
      q('480p', bandwidth: 1200000, height: 480),
    ];

    test('steps one rung down', () {
      expect(nextAutoQualityIndex(list, 1), 2);
      expect(nextAutoQualityIndex(list, 2), 3);
    });

    test('stops at the lowest rendition', () {
      // The caller uses "unchanged" as the signal that the ladder is
      // exhausted, so this must never walk off the end of the list.
      expect(nextAutoQualityIndex(list, 3), 3);
    });

    test('clamps an out-of-range index instead of throwing', () {
      expect(nextAutoQualityIndex(list, 99), 3);
      expect(nextAutoQualityIndex(list, -5), 1);
    });

    test('returns the index unchanged when there are no variants', () {
      expect(nextAutoQualityIndex(const [], 0), 0);
    });

    test('walks the whole ladder exactly once, then stays put', () {
      var index = 1;
      final visited = <int>[index];
      while (true) {
        final next = nextAutoQualityIndex(list, index);
        if (next == index) break;
        index = next;
        visited.add(index);
      }
      expect(visited, [1, 2, 3]);
    });
  });

  group('planAutoDowngrade', () {
    final list = [
      q('تلقائي'),
      q('1080p', bandwidth: 5000000, height: 1080),
      q('720p', bandwidth: 2400000, height: 720),
      q('480p', bandwidth: 1200000, height: 480),
    ];

    AutoDowngradePlan plan({
      required int index,
      bool auto = true,
      bool alreadyDowngraded = false,
      List<VideoQuality>? qualities,
    }) => planAutoDowngrade(
      qualities: qualities ?? list,
      currentIndex: index,
      autoQuality: auto,
      alreadyDowngradedForStall: alreadyDowngraded,
    );

    test('steps down one rung in auto mode', () {
      final result = plan(index: 1);
      expect(result.shouldDowngrade, isTrue);
      expect(result.targetIndex, 2);
      expect(result.skipReason, isNull);
    });

    test('refuses to touch a pinned rendition', () {
      // The most important guard: dropping this would silently override a
      // student's explicit choice mid-lecture.
      final result = plan(index: 1, auto: false);
      expect(result.shouldDowngrade, isFalse);
      expect(result.skipReason, DowngradeSkipReason.notAutoMode);
    });

    test('downgrades at most once per stall', () {
      // Otherwise the ladder step and the 2-stalls-in-5-minutes rule both fire
      // for one freeze and drop two rungs.
      final result = plan(index: 1, alreadyDowngraded: true);
      expect(result.shouldDowngrade, isFalse);
      expect(result.skipReason, DowngradeSkipReason.alreadyDowngradedForStall);
    });

    test('stops at the lowest rendition', () {
      final result = plan(index: 3);
      expect(result.shouldDowngrade, isFalse);
      expect(result.skipReason, DowngradeSkipReason.noLowerRendition);
    });

    test('does nothing when there is only one variant', () {
      final two = [q('تلقائي'), q('720p', bandwidth: 2400000, height: 720)];
      final result = plan(index: 1, qualities: two);
      expect(result.shouldDowngrade, isFalse);
      expect(result.skipReason, DowngradeSkipReason.noLowerRendition);
    });

    test('does nothing when there is no rendition list at all', () {
      final result = plan(index: 0, qualities: const []);
      expect(result.shouldDowngrade, isFalse);
    });

    test('recovers the pinned check taking priority', () {
      // Both guards apply; reporting the pin makes the log actionable.
      final result = plan(index: 1, auto: false, alreadyDowngraded: true);
      expect(result.skipReason, DowngradeSkipReason.notAutoMode);
    });

    test('walks the ladder down to the bottom', () {
      final targets = <int>[];
      var index = 1;
      while (true) {
        final result = plan(index: index);
        if (!result.shouldDowngrade) break;
        index = result.targetIndex!;
        targets.add(index);
      }
      expect(targets, [2, 3]);
    });
  });

  group('shouldAnnounceAutoQuality', () {
    final withVariants = [
      q('تلقائي'),
      q('720p', bandwidth: 2400000, height: 720),
    ];

    test('announces when auto is managing real renditions', () {
      expect(
        shouldAnnounceAutoQuality(qualities: withVariants, autoQuality: true),
        isTrue,
      );
    });

    test('stays quiet when the student pinned a rendition', () {
      expect(
        shouldAnnounceAutoQuality(qualities: withVariants, autoQuality: false),
        isFalse,
      );
    });

    test('stays quiet for a non-HLS source', () {
      // Regression guard: `autoQuality` defaults to true, so without the
      // rendition check every MP4 would claim to have automatic quality.
      expect(
        shouldAnnounceAutoQuality(qualities: const [], autoQuality: true),
        isFalse,
      );
      expect(
        shouldAnnounceAutoQuality(qualities: [q('تلقائي')], autoQuality: true),
        isFalse,
      );
    });
  });

  group('resolvePlayUrl', () {
    const source = 'https://cdn.test/vod/video.mp4';
    final list = [q('تلقائي'), q('1080p'), q('720p')];

    test('resolves the selected variant', () {
      expect(
        resolvePlayUrl(sourceUrl: source, qualities: list, index: 2),
        'https://cdn.test/720p.m3u8',
      );
    });

    test('never loads the master playlist entry', () {
      // Index 0 is the auto sentinel and its URL is the master. Both backends
      // resolve that to one arbitrary variant, so it must never be handed over.
      expect(
        resolvePlayUrl(sourceUrl: source, qualities: list, index: 0),
        'https://cdn.test/1080p.m3u8',
      );
      expect(
        resolvePlayUrl(sourceUrl: source, qualities: list, index: -3),
        'https://cdn.test/1080p.m3u8',
      );
    });

    test('clamps an out-of-range index instead of throwing', () {
      expect(
        resolvePlayUrl(sourceUrl: source, qualities: list, index: 99),
        'https://cdn.test/720p.m3u8',
      );
    });

    test('falls back to the source URL when there are no renditions', () {
      expect(
        resolvePlayUrl(sourceUrl: source, qualities: const [], index: 0),
        source,
      );
      expect(
        resolvePlayUrl(sourceUrl: source, qualities: [q('تلقائي')], index: 0),
        source,
      );
    });
  });

  group('buildQualityChipLabel', () {
    final list = [q('تلقائي'), q('1080p'), q('720p')];

    test('shows the mode and the effective rendition in auto mode', () {
      expect(
        buildQualityChipLabel(qualities: list, index: 2, autoQuality: true),
        'تلقائي · 720p',
      );
    });

    test('shows only the rendition when pinned', () {
      expect(
        buildQualityChipLabel(qualities: list, index: 2, autoQuality: false),
        '720p',
      );
    });

    test('is empty when there is nothing to choose', () {
      expect(
        buildQualityChipLabel(qualities: const [], index: 0, autoQuality: true),
        '',
      );
      expect(
        buildQualityChipLabel(
          qualities: [q('تلقائي')],
          index: 0,
          autoQuality: true,
        ),
        '',
      );
    });

    test('clamps an out-of-range index instead of throwing', () {
      expect(
        buildQualityChipLabel(qualities: list, index: 42, autoQuality: true),
        'تلقائي · 720p',
      );
    });
  });

  group('selectedQualityIndex', () {
    const int count = 4;

    test('marks the auto entry while auto mode is in charge', () {
      // Regression guard: this previously reported the effective rendition, so
      // a student in auto mode saw the tick beside a quality they never chose
      // while the row that actually governed playback looked unselected.
      expect(
        selectedQualityIndex(
          autoQuality: true,
          currentIndex: 2,
          qualityCount: count,
        ),
        kAutoQualityIndex,
      );
    });

    test('marks auto even when auto is playing the first rendition', () {
      expect(
        selectedQualityIndex(
          autoQuality: true,
          currentIndex: 1,
          qualityCount: count,
        ),
        kAutoQualityIndex,
      );
    });

    test('marks the pinned rendition when pinned', () {
      expect(
        selectedQualityIndex(
          autoQuality: false,
          currentIndex: 3,
          qualityCount: count,
        ),
        3,
      );
    });

    test('never marks auto when pinned to the top rendition', () {
      expect(
        selectedQualityIndex(
          autoQuality: false,
          currentIndex: 1,
          qualityCount: count,
        ),
        1,
      );
    });

    test('falls back to auto when there is nothing to choose', () {
      expect(
        selectedQualityIndex(
          autoQuality: true,
          currentIndex: 0,
          qualityCount: 0,
        ),
        kAutoQualityIndex,
      );
      expect(
        selectedQualityIndex(
          autoQuality: false,
          currentIndex: 3,
          qualityCount: 1,
        ),
        kAutoQualityIndex,
      );
    });

    test('clamps a stale pinned index rather than throwing', () {
      expect(
        selectedQualityIndex(
          autoQuality: false,
          currentIndex: 99,
          qualityCount: count,
        ),
        count - 1,
      );
      expect(
        selectedQualityIndex(
          autoQuality: false,
          currentIndex: -4,
          qualityCount: count,
        ),
        kAutoQualityIndex + 1,
      );
    });
  });
}
