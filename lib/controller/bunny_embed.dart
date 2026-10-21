/// Maps the HLS playlist URLs stored in the DB to Bunny Stream embed URLs.
///
/// The DB only ever holds the CDN playlist form
/// (`https://vz-<zone>.b-cdn.net/<video-id>/playlist.m3u8`) and cannot be
/// changed, while the embeddable player lives on a different host and needs a
/// library id that the playlist URL does not carry. Both pieces are derived
/// here: the video id from the playlist path, the library id from the
/// `library_id` column on the owning topic.
library;

/// Query parameters for the embed player, matching the same options the
/// website iframes use.
const Map<String, String> _kEmbedQueryParams = {
  'autoplay': 'false',
  'loop': 'false',
  'muted': 'false',
  'preload': 'true',
  'responsive': 'true',
};

/// Extracts the Bunny video id from a CDN playlist URL.
///
/// The id is the path segment directly before `playlist.m3u8`
/// (`/c285b1e8-.../playlist.m3u8` → `c285b1e8-...`). Returns `null` when the
/// URL is not a Bunny CDN playlist (other CDN, plain mp4, unparseable).
String? extractBunnyVideoId(String rawUrl) {
  final uri = Uri.tryParse(rawUrl);
  if (uri == null) return null;
  if (!uri.host.endsWith('.b-cdn.net')) return null;

  final segments =
      uri.pathSegments.where((s) => s.isNotEmpty).toList(growable: false);
  if (segments.length < 2) return null;
  if (!segments.last.toLowerCase().endsWith('.m3u8')) return null;

  final videoId = segments[segments.length - 2];
  return videoId.isEmpty ? null : videoId;
}

/// Normalises the `topics.library_id` column into the number the embed URL
/// needs.
///
/// The column is a string, but it can legitimately hold an empty value, a
/// zero, or (while a row is being migrated) something that is not a number at
/// all. Anything unusable collapses to `null` so callers can treat it as
/// "this video has no embed library yet".
int? parseBunnyLibraryId(Object? raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  final parsed = int.tryParse(text);
  return (parsed == null || parsed <= 0) ? null : parsed;
}

/// Whether [rawUrl] is already a Bunny Stream embed player page.
///
/// The adapter maps CDN playlist URLs to embed URLs itself, but callers that
/// hand it an embed URL directly (a retry, a reload) must not be remapped.
bool isBunnyEmbedUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl);
  return uri != null && uri.host == 'player.mediadelivery.net';
}

/// Builds the Bunny embed page URL for the given DB-stored playlist URL.
///
/// [libraryId] is the owning topic's `library_id`; there is deliberately no
/// hardcoded default, so a topic whose video library is unknown never plays
/// under the wrong library - the caller decides what to do about that.
///
/// Returns `null` when [rawUrl] is not a Bunny CDN playlist so callers can
/// fall back to the native player for sources Bunny cannot embed (mp4, other
/// CDNs, signed non-Bunny manifests).
String? tryBuildBunnyEmbedUrl(String rawUrl, {required int libraryId}) {
  final videoId = extractBunnyVideoId(rawUrl);
  if (videoId == null) return null;

  final query = _kEmbedQueryParams.entries
      .map((e) => '${Uri.encodeQueryComponent(e.key)}='
          '${Uri.encodeQueryComponent(e.value)}')
      .join('&');

  return 'https://player.mediadelivery.net/embed/'
      '$libraryId/$videoId?$query';
}
