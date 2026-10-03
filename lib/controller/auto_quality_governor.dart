/// Decides when auto quality may climb back up a rendition.
///
/// The inverse of [StallDetector]: that class watches for trouble and steps
/// down, this one watches for its sustained absence and steps up. Both backends
/// (mpv and libmdk) can only open one rendition, so "climbing" is still a full
/// player reload - which is exactly why every gate here exists. A student whose
/// connection recovers should see the quality return, but not at the cost of a
/// rebuffer every thirty seconds.
///
/// Pure and clock-injectable so every timing rule is unit tested.
library;

import 'package:shobaki_academy/controller/video_quality.dart';

/// Why an automatic upgrade did not happen.
enum UpgradeSkipReason {
  /// The student pinned a rendition; the app must not override them.
  notAutoMode,

  /// Already at the highest available rendition.
  atTopOfLadder,

  /// The current rendition has not been played stall-free for long enough.
  notStableLongEnough,

  /// A quality switch happened recently. Without this the ladder would pump:
  /// upgrade, stall, downgrade, upgrade, in a loop.
  cooldownActive,

  /// This particular rendition caused a stall recently and must not be retried
  /// yet.
  rungBlocked,

  /// Not enough media buffered ahead to sustain the target rendition's rate.
  insufficientBuffer,
}

/// The outcome of asking whether auto mode should step up.
class UpgradePlan {
  const UpgradePlan._(this.targetIndex, this.skipReason);

  const UpgradePlan.upgrade(int index) : this._(index, null);

  const UpgradePlan.skip(UpgradeSkipReason reason) : this._(null, reason);

  /// Index to load, or null when no upgrade should happen.
  final int? targetIndex;

  final UpgradeSkipReason? skipReason;

  bool get shouldUpgrade => targetIndex != null;
}

/// Multiplier applied to the stability window when a rendition's bandwidth is
/// unknown and the required buffer cannot be computed from a bitrate ratio.
const int kUnknownBandwidthBufferMultiplier = 2;

/// Seconds of headroom required for [target] when [current] already sustains
/// [base] comfortably.
///
/// [bufferedAhead] is measured in media seconds of the rendition currently
/// being downloaded, so it cannot be compared against a fixed threshold: sixty
/// seconds of 480p is barely more than the twenty-eight seconds of 1080p it
/// could become. Rescaling by the bitrate ratio converts it into what the
/// target actually needs.
///
/// Falls back to a generous flat multiple when either bandwidth is missing, so
/// a manifest without `BANDWIDTH` still upgrades, just more cautiously.
Duration requiredBufferForRendition({
  required VideoQuality target,
  required VideoQuality current,
  required Duration base,
}) {
  final targetBps = target.bandwidth;
  final currentBps = current.bandwidth;
  final usable =
      targetBps != null &&
      currentBps != null &&
      targetBps > 0 &&
      currentBps > 0;
  if (!usable) return base * kUnknownBandwidthBufferMultiplier;

  // A lower or equal target needs nothing beyond the existing guarantee.
  if (targetBps <= currentBps) return base;
  return base * (targetBps / currentBps);
}

class AutoQualityGovernor {
  AutoQualityGovernor({
    this.stableBeforeUpgrade = const Duration(seconds: 30),
    this.upgradeCooldown = const Duration(minutes: 2),
    this.rungMemory = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Stall-free playback required before a step up is considered.
  ///
  /// This doubles as the buffer target in [requiredBufferForRendition]: we ask
  /// to have enough headroom to sustain the new rendition for at least as long
  /// as it took to prove the current one healthy.
  final Duration stableBeforeUpgrade;

  /// Minimum time at a rendition after any switch, before another one.
  final Duration upgradeCooldown;

  /// How long a rendition that caused a stall is avoided.
  final Duration rungMemory;

  final DateTime Function() _clock;

  DateTime? _stableSince;
  DateTime? _lastQualityChange;
  final Map<int, DateTime> _rungBlockedUntil = {};

  /// How long the current rendition has played without a stall.
  Duration get stableFor {
    final since = _stableSince;
    if (since == null) return Duration.zero;
    return _clock().difference(since);
  }

  bool get hasStabilityWindow => _stableSince != null;

  /// Feeds one observation of the player.
  ///
  /// Stability is only as good as the most recent second: a single stall
  /// discards the window entirely rather than merely pausing it, because a
  /// rendition that just failed should not be rewarded for the minute before
  /// it failed.
  void sample({required bool isStalled}) {
    if (isStalled) {
      _stableSince = null;
      return;
    }
    _stableSince ??= _clock();
  }

  /// Records that [index] could not sustain playback.
  ///
  /// Called with the rendition being *left*, which in the one-rung downgrade
  /// path is the higher-quality one that actually failed.
  void noteRungFailed(int index) {
    if (index <= kAutoQualityIndex) return;
    _rungBlockedUntil[index] = _clock().add(rungMemory);
  }

  /// Records that the active rendition changed, for any reason.
  ///
  /// Starts the dwell clock and discards the stability window: the new
  /// rendition has not been proven yet, even if the old one had been for an
  /// hour.
  void noteQualityChanged() {
    _lastQualityChange = _clock();
    _stableSince = null;
  }

  /// Records that the player was torn down without changing rendition.
  ///
  /// The read-ahead buffer is gone, so stability must be re-proven. The dwell
  /// clock and failed-rung memory deliberately survive: both describe what the
  /// link did, not what is currently buffered, and clearing either would let a
  /// reload bypass the anti-flap guards entirely.
  void noteBufferCleared() => _stableSince = null;

  /// Clears everything, e.g. when the player is torn down.
  void reset() {
    _stableSince = null;
    _lastQualityChange = null;
    _rungBlockedUntil.clear();
  }

  bool _isRungBlocked(int index, DateTime now) {
    final until = _rungBlockedUntil[index];
    if (until == null) return false;
    if (until.isAfter(now)) return true;
    // Expired: drop it so a rendition eventually gets its chance back.
    _rungBlockedUntil.remove(index);
    return false;
  }

  UpgradePlan planAutoUpgrade({
    required List<VideoQuality> qualities,
    required int currentIndex,
    required bool autoQuality,
    required Duration bufferedAhead,
  }) {
    if (!autoQuality) {
      return const UpgradePlan.skip(UpgradeSkipReason.notAutoMode);
    }
    // Index 0 is the auto sentinel and indices run highest quality first, so
    // anything at or below 1 has nowhere higher to go.
    if (qualities.length <= 1 || currentIndex <= 1) {
      return const UpgradePlan.skip(UpgradeSkipReason.atTopOfLadder);
    }

    final now = _clock();
    final targetIndex = currentIndex - 1;

    if (_isRungBlocked(targetIndex, now)) {
      return const UpgradePlan.skip(UpgradeSkipReason.rungBlocked);
    }

    final stableSince = _stableSince;
    if (stableSince == null) {
      return const UpgradePlan.skip(UpgradeSkipReason.notStableLongEnough);
    }
    if (now.difference(stableSince) < stableBeforeUpgrade) {
      return const UpgradePlan.skip(UpgradeSkipReason.notStableLongEnough);
    }

    final changedAt = _lastQualityChange;
    if (changedAt != null && now.difference(changedAt) < upgradeCooldown) {
      return const UpgradePlan.skip(UpgradeSkipReason.cooldownActive);
    }

    final required = requiredBufferForRendition(
      target: qualities[targetIndex],
      current: qualities[currentIndex],
      base: stableBeforeUpgrade,
    );
    if (bufferedAhead < required) {
      return const UpgradePlan.skip(UpgradeSkipReason.insufficientBuffer);
    }

    return UpgradePlan.upgrade(targetIndex);
  }
}
