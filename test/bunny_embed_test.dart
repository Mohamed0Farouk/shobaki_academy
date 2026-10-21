import 'package:flutter_test/flutter_test.dart';
import 'package:shobaki_academy/controller/bunny_embed.dart';

/// The playlist URL shape the DB actually holds. It cannot change: the value
/// is written by the backend and read back by every lecture page.
const String kPlaylistUrl =
    'https://vz-d3e667b1-320.b-cdn.net/'
    'c285b1e8-81d2-42b6-9a88-eee138c920d6/playlist.m3u8';

const String kVideoId = 'c285b1e8-81d2-42b6-9a88-eee138c920d6';

void main() {
  group('extractBunnyVideoId', () {
    test('reads the segment before playlist.m3u8', () {
      expect(extractBunnyVideoId(kPlaylistUrl), kVideoId);
    });

    test('ignores a signed query string', () {
      // Signed CDN URLs are the normal case in production; a check that only
      // matched the bare path would silently disable the embed for them.
      expect(
        extractBunnyVideoId('$kPlaylistUrl?token=abc&exp=123'),
        kVideoId,
      );
    });

    test('accepts a differently named playlist file', () {
      expect(
        extractBunnyVideoId(
          'https://vz-example.b-cdn.net/11111111-2222-3333-4444-555555555555/master.m3u8',
        ),
        '11111111-2222-3333-4444-555555555555',
      );
    });

    test('rejects a non-Bunny host', () {
      expect(
        extractBunnyVideoId('https://cdn.example.com/$kVideoId/playlist.m3u8'),
        isNull,
      );
    });

    test('rejects a Bunny URL that is not a playlist', () {
      expect(
        extractBunnyVideoId('https://vz-example.b-cdn.net/$kVideoId/video.mp4'),
        isNull,
      );
    });

    test('rejects a playlist URL with no video id', () {
      expect(
        extractBunnyVideoId('https://vz-example.b-cdn.net/playlist.m3u8'),
        isNull,
      );
    });

    test('rejects a bare host', () {
      expect(extractBunnyVideoId('https://vz-example.b-cdn.net/'), isNull);
      expect(extractBunnyVideoId('not a url at all'), isNull);
    });
  });

  group('parseBunnyLibraryId', () {
    test('parses the string column the DB actually stores', () {
      expect(parseBunnyLibraryId('699286'), 699286);
      expect(parseBunnyLibraryId(' 699286 '), 699286);
    });

    test('also accepts an already numeric value', () {
      expect(parseBunnyLibraryId(699286), 699286);
    });

    test('collapses unusable values to null', () {
      // Every one of these means "this topic has no embed library yet"; the
      // caller decides how to tell the student apart from playing under the
      // wrong library.
      expect(parseBunnyLibraryId(null), isNull);
      expect(parseBunnyLibraryId(''), isNull);
      expect(parseBunnyLibraryId('   '), isNull);
      expect(parseBunnyLibraryId('0'), isNull);
      expect(parseBunnyLibraryId('-5'), isNull);
      expect(parseBunnyLibraryId('not-a-number'), isNull);
    });
  });

  group('tryBuildBunnyEmbedUrl', () {
    const int kLibraryId = 699286;

    test('maps the DB playlist URL to the embed player', () {
      final embed = tryBuildBunnyEmbedUrl(kPlaylistUrl, libraryId: kLibraryId);
      expect(embed, isNotNull);

      final uri = Uri.parse(embed!);
      expect(uri.host, 'player.mediadelivery.net');
      expect(uri.pathSegments, ['embed', '$kLibraryId', kVideoId]);
    });

    test('uses the topic library id, never a hardcoded one', () {
      expect(
        tryBuildBunnyEmbedUrl(kPlaylistUrl, libraryId: 123456),
        contains('/123456/'),
      );
      expect(tryBuildBunnyEmbedUrl(kPlaylistUrl, libraryId: 123456),
          isNot(contains('/699286/')));
    });

    test('disables autoplay, looping and muting', () {
      // Autoplay would start a lecture the moment the page opens, which
      // breaks the "view starts when the student starts it" model the session
      // tracker is built on.
      final uri = Uri.parse(
        tryBuildBunnyEmbedUrl(kPlaylistUrl, libraryId: kLibraryId)!,
      );
      expect(uri.queryParameters['autoplay'], 'false');
      expect(uri.queryParameters['loop'], 'false');
      expect(uri.queryParameters['muted'], 'false');
      expect(uri.queryParameters['preload'], 'true');
      expect(uri.queryParameters['responsive'], 'true');
    });

    test('keeps the signed query out of the embed URL', () {
      final uri = Uri.parse(
        tryBuildBunnyEmbedUrl('$kPlaylistUrl?token=abc',
            libraryId: kLibraryId)!,
      );
      expect(uri.queryParameters.keys, unorderedEquals([
        'autoplay',
        'loop',
        'muted',
        'preload',
        'responsive',
      ]));
    });

    test('returns null for a non-Bunny URL so the caller falls back', () {
      expect(
        tryBuildBunnyEmbedUrl('https://cdn.example.com/$kVideoId/playlist.m3u8',
            libraryId: kLibraryId),
        isNull,
      );
      expect(
        tryBuildBunnyEmbedUrl('https://example.com/video.mp4',
            libraryId: kLibraryId),
        isNull,
      );
    });

    test('round-trips through isBunnyEmbedUrl', () {
      final embed =
          tryBuildBunnyEmbedUrl(kPlaylistUrl, libraryId: kLibraryId)!;
      expect(isBunnyEmbedUrl(embed), isTrue);
      expect(isBunnyEmbedUrl(kPlaylistUrl), isFalse);
      expect(isBunnyEmbedUrl('https://player.mediadelivery.net/other'), isTrue);
    });
  });
}
