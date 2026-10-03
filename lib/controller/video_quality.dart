/// HLS quality model and the pure selection logic behind adaptive quality.
///
/// Kept free of Flutter/plugin dependencies so it can be unit tested directly.
/// Both the mobile (mpv) and desktop (libmdk) backends lack runtime adaptive
/// bitrate switching, so "auto" is implemented here at the app level: the app
/// picks a concrete rendition and steps it down when playback stalls.
library;

import 'package:shobaki_academy/services/player_messages.dart';

class VideoQuality {
  final String label;
  final String url;
  final int? bandwidth;
  final int? width;
  final int? height;

  VideoQuality({
    required this.label,
    required this.url,
    this.bandwidth,
    this.width,
    this.height,
  });

  @override
  String toString() => 'VideoQuality($label, ${bandwidth ?? '?'}bps)';
}

/// Index reserved for the "automatic" entry at the head of a quality list.
///
/// The entry's [VideoQuality.url] is the master playlist, but it is never
/// loaded: libmpv and libmdk both pick a single rendition at open time and do
/// not switch during playback, so handing them the master playlist buys
/// nothing. Selecting this index means "let the app manage the rendition".
const int kAutoQualityIndex = 0;

/// Ceiling used when auto-selecting a starting rendition.
///
/// Auto deliberately starts *below* the top of the ladder: the whole point is
/// to avoid stalling, and a student on a fast line can pin a higher rendition
/// from the quality menu.
const int kAutoMaxBitrate = 2500000;

/// Fallback height cap used when a manifest omits `BANDWIDTH`.
const int kAutoMaxHeight = 720;

/// True when [url] points at an HLS playlist.
///
/// The path is inspected rather than the raw string so that signed URLs
/// (`master.m3u8?token=...&exp=...`) are still recognised. A plain
/// `endsWith('.m3u8')` check silently disabled the entire quality menu for
/// every tokenised CDN URL.
bool isHlsManifestUrl(String url) {
  try {
    return Uri.parse(url).path.toLowerCase().endsWith('.m3u8');
  } catch (_) {
    return false;
  }
}

/// Parses an HLS master playlist into renditions, highest quality first.
///
/// Returns variants only; the caller is responsible for inserting the
/// automatic entry at [kAutoQualityIndex]. Unparseable input yields an empty
/// list rather than throwing, because a failed manifest fetch must never break
/// playback of the source URL.
List<VideoQuality> parseHlsMasterPlaylist(String body, Uri baseUri) {
  final variants = <VideoQuality>[];
  if (!body.trimLeft().startsWith('#EXTM3U')) return variants;

  int? bandwidth;
  int? averageBandwidth;
  int? width;
  int? height;

  // Only a URI that directly follows `#EXT-X-STREAM-INF` is a variant. Without
  // this a *media* playlist (`#EXTINF` + `.ts` segments) parses as a single
  // bogus variant and the app would offer a quality menu for it.
  var expectVariantUri = false;

  for (final rawLine in body.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    if (line.startsWith('#EXT-X-STREAM-INF:')) {
      final params = line.substring('#EXT-X-STREAM-INF:'.length);
      // `AVERAGE-BANDWIDTH` is the sustainable rate and is preferred when
      // present; `BANDWIDTH` is the advertised peak and routinely overstates
      // what a student on a shared connection can actually sustain.
      averageBandwidth = _intParam(params, 'AVERAGE-BANDWIDTH');
      bandwidth = averageBandwidth ?? _intParam(params, 'BANDWIDTH');
      final resolution = _resolutionParam(params);
      if (resolution != null) {
        width = resolution.$1;
        height = resolution.$2;
      }
      expectVariantUri = true;
      continue;
    }

    if (line.startsWith('#')) {
      // Any other tag (including #EXTINF) invalidates a pending variant URI.
      expectVariantUri = false;
      bandwidth = averageBandwidth = width = height = null;
      continue;
    }

    if (!expectVariantUri) continue;

    Uri variantUri;
    try {
      variantUri = baseUri.resolve(line);
    } catch (_) {
      bandwidth = averageBandwidth = width = height = null;
      expectVariantUri = false;
      continue;
    }

    variants.add(
      VideoQuality(
        // Deliberately no trailing "p". The whole label is left-to-right, so
        // in an RTL menu a trailing Latin letter lands at the line's start
        // position and reads as detached from its own number ("720p" with the
        // `p` pushed to the far right). Digits alone sit flush like the Arabic
        // around them, and `height` already carries the same information.
        label: height != null ? '$height' : '${bandwidth ?? 0} kbps',
        url: variantUri.toString(),
        bandwidth: bandwidth,
        width: width,
        height: height,
      ),
    );

    bandwidth = averageBandwidth = width = height = null;
    expectVariantUri = false;
  }

  variants.sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
  return variants;
}

int? _intParam(String params, String key) {
  final match = RegExp('$key=(\\d+)').firstMatch(params);
  return match == null ? null : int.tryParse(match.group(1)!);
}

(int, int)? _resolutionParam(String params) {
  final match = RegExp(r'RESOLUTION=(\d+)x(\d+)').firstMatch(params);
  if (match == null) return null;
  final w = int.tryParse(match.group(1)!);
  final h = int.tryParse(match.group(2)!);
  if (w == null || h == null) return null;
  return (w, h);
}

/// Picks the rendition auto mode should start on.
///
/// [qualities] must start with the automatic entry at [kAutoQualityIndex] and
/// be sorted highest-first (as produced by [parseHlsMasterPlaylist]).
///
/// Preference order:
///   1. highest rendition whose bandwidth fits under [maxAutoBitrate];
///   2. otherwise the cheapest rendition (the link clearly cannot sustain the
///      top of the ladder, so start at the bottom rather than stall down to it);
///   3. with no bandwidth data, highest rendition at or below [maxAutoHeight];
///   4. with neither, the lowest declared height.
int selectAutoQualityIndex(
  List<VideoQuality> qualities, {
  int maxAutoBitrate = kAutoMaxBitrate,
  int maxAutoHeight = kAutoMaxHeight,
}) {
  if (qualities.length <= 1) return kAutoQualityIndex;

  final variants = qualities.sublist(1);
  if (variants.isEmpty) return kAutoQualityIndex;

  // `variants` is a suffix of `qualities`, so variant i lives at i + 1.
  int indexOfVariant(VideoQuality q) => variants.indexOf(q) + 1;

  final withBandwidth = variants.where((q) => q.bandwidth != null).toList();
  if (withBandwidth.isNotEmpty) {
    final affordable = withBandwidth
        .where((q) => q.bandwidth! <= maxAutoBitrate)
        .toList();
    // Highest first, so the first affordable entry is the best affordable one.
    if (affordable.isNotEmpty) return indexOfVariant(affordable.first);
    return indexOfVariant(_lowestBy(variants, (q) => q.bandwidth!));
  }

  final withHeight = variants.where((q) => q.height != null).toList();
  if (withHeight.isNotEmpty) {
    final affordable = withHeight
        .where((q) => q.height! <= maxAutoHeight)
        .toList();
    if (affordable.isNotEmpty) return indexOfVariant(affordable.first);
    return indexOfVariant(_lowestBy(withHeight, (q) => q.height!));
  }

  // No usable metadata: stay on the first variant and let the stall ladder
  // handle it rather than guessing.
  return 1;
}

/// The next rung down the ladder, clamped to the lowest available rendition.
///
/// Returns [currentIndex] unchanged when already at the bottom, which callers
/// use as the signal that automatic downgrading is exhausted. An index outside
/// the list is clamped rather than returned, so a stale selection can never
/// address past the end.
int nextAutoQualityIndex(List<VideoQuality> qualities, int currentIndex) {
  if (qualities.length <= 1) return currentIndex;
  final last = qualities.length - 1;
  if (currentIndex < kAutoQualityIndex) currentIndex = kAutoQualityIndex;
  if (currentIndex >= last) return last;
  return currentIndex + 1;
}

VideoQuality _lowestBy(
  List<VideoQuality> variants,
  int Function(VideoQuality) metric,
) {
  var lowest = variants.first;
  var lowestValue = metric(lowest);
  for (final q in variants.skip(1)) {
    final value = metric(q);
    if (value < lowestValue) {
      lowest = q;
      lowestValue = value;
    }
  }
  return lowest;
}

/// Why an automatic downgrade did not happen.
enum DowngradeSkipReason {
  /// The student pinned a rendition, so the app must not override them.
  notAutoMode,

  /// This stall has already been downgraded. Without this the escalation
  /// ladder and the "2 stalls in 5 minutes" rule would both fire for a single
  /// freeze and drop two rungs at once.
  alreadyDowngradedForStall,

  /// No rendition below the current one exists.
  noLowerRendition,
}

/// The outcome of asking whether auto mode should step down.
class AutoDowngradePlan {
  const AutoDowngradePlan._(this.targetIndex, this.skipReason);

  const AutoDowngradePlan.downgrade(int index) : this._(index, null);

  const AutoDowngradePlan.skip(DowngradeSkipReason reason)
    : this._(null, reason);

  /// Index to load, or null when no downgrade should happen.
  final int? targetIndex;

  final DowngradeSkipReason? skipReason;

  bool get shouldDowngrade => targetIndex != null;
}

/// Decides whether auto mode should step down one rendition.
///
/// Separated from the controller so the guards are tested directly: a
/// regression that dropped the `notAutoMode` check would silently override a
/// student's pinned quality mid-lecture.
AutoDowngradePlan planAutoDowngrade({
  required List<VideoQuality> qualities,
  required int currentIndex,
  required bool autoQuality,
  required bool alreadyDowngradedForStall,
}) {
  if (!autoQuality) {
    return const AutoDowngradePlan.skip(DowngradeSkipReason.notAutoMode);
  }
  if (alreadyDowngradedForStall) {
    return const AutoDowngradePlan.skip(
      DowngradeSkipReason.alreadyDowngradedForStall,
    );
  }
  if (qualities.length <= 2) {
    return const AutoDowngradePlan.skip(DowngradeSkipReason.noLowerRendition);
  }
  final next = nextAutoQualityIndex(qualities, currentIndex);
  if (next == currentIndex) {
    return const AutoDowngradePlan.skip(DowngradeSkipReason.noLowerRendition);
  }
  return AutoDowngradePlan.downgrade(next);
}

/// Index of the row the quality menu should mark as chosen.
///
/// In auto mode the ladder owns the rendition, so the tick belongs on
/// [kAutoQualityIndex] - not on whichever rendition auto currently happens to
/// be playing. Reporting the effective index instead made a student in auto
/// mode look pinned to a choice they never made, while the entry that actually
/// governed playback appeared unselected.
int selectedQualityIndex({
  required bool autoQuality,
  required int currentIndex,
  required int qualityCount,
}) {
  if (qualityCount <= 1) return kAutoQualityIndex;
  if (autoQuality) return kAutoQualityIndex;
  return currentIndex.clamp(kAutoQualityIndex + 1, qualityCount - 1);
}

/// Whether the auto-quality notice should be shown to the student.
///
/// Requires an actual rendition list: for a non-HLS source nothing is being
/// managed, so announcing "quality is automatic" would be a lie. Also requires
/// auto mode, since a pinned rendition is a deliberate choice that needs no
/// explanation.
bool shouldAnnounceAutoQuality({
  required List<VideoQuality> qualities,
  required bool autoQuality,
}) => qualities.length > 1 && autoQuality;

/// URL to hand the player for the given selection.
///
/// Falls back to [sourceUrl] when there is no usable master playlist. The
/// index is clamped so a stale selection can never address outside the list,
/// and [kAutoQualityIndex] is never loaded because it points at the master
/// playlist, which both backends would just resolve to one arbitrary variant.
String resolvePlayUrl({
  required String sourceUrl,
  required List<VideoQuality> qualities,
  required int index,
}) {
  if (qualities.length <= 1) return sourceUrl;
  return qualities[index.clamp(1, qualities.length - 1)].url;
}

/// Text for the quality chip.
///
/// In auto mode the effective resolution is shown next to the mode label, so
/// the student can see a downgrade actually happen rather than the chip
/// silently changing meaning.
String buildQualityChipLabel({
  required List<VideoQuality> qualities,
  required int index,
  required bool autoQuality,
}) {
  if (qualities.length <= 1) return '';
  final effective = qualities[index.clamp(1, qualities.length - 1)].label;
  return autoQuality ? PlayerMessages.autoChipLabel(effective) : effective;
}
