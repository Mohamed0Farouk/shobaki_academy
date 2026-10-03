import 'package:flutter_test/flutter_test.dart';
import 'package:shobaki_academy/controller/auto_quality_governor.dart';
import 'package:shobaki_academy/controller/video_quality.dart';

class TestClock {
  DateTime now = DateTime(2026, 1, 1, 12);
  DateTime call() => now;
  void advance(Duration by) => now = now.add(by);
}

VideoQuality rung(String label, int? bandwidth) => VideoQuality(
  label: label,
  url: 'https://cdn.test/$label.m3u8',
  bandwidth: bandwidth,
);

/// Sentinel at index 0, then highest-first as `parseHlsMasterPlaylist` sorts:
/// index 1 = 1080p (top), 2 = 720p, 3 = 480p (bottom).
final List<VideoQuality> ladder = [
  VideoQuality(label: 'تلقائي', url: 'https://cdn.test/master.m3u8'),
  rung('1080p', 5000000),
  rung('720p', 2400000),
  rung('480p', 1200000),
];

void main() {
  late TestClock clock;

  AutoQualityGovernor governor({
    Duration stableBeforeUpgrade = const Duration(seconds: 30),
    Duration upgradeCooldown = const Duration(minutes: 2),
    Duration rungMemory = const Duration(minutes: 5),
  }) => AutoQualityGovernor(
    stableBeforeUpgrade: stableBeforeUpgrade,
    upgradeCooldown: upgradeCooldown,
    rungMemory: rungMemory,
    clock: clock.call,
  );

  UpgradePlan plan(
    AutoQualityGovernor g, {
    int currentIndex = 3,
    bool autoQuality = true,
    Duration bufferedAhead = const Duration(hours: 2),
  }) => g.planAutoUpgrade(
    qualities: ladder,
    currentIndex: currentIndex,
    autoQuality: autoQuality,
    bufferedAhead: bufferedAhead,
  );

  setUp(() => clock = TestClock());

  group('requiredBufferForRendition', () {
    test('scales by the bitrate ratio', () {
      // 1080p at 5 Mbps over a 720p rendition at 2.4 Mbps needs 2.08x the
      // media-seconds of headroom: a buffer that looks healthy for the lower
      // rendition may be far too thin for the higher one.
      final required = requiredBufferForRendition(
        target: ladder[1],
        current: ladder[2],
        base: const Duration(seconds: 30),
      );
      expect(required.inMilliseconds, 62500);
    });

    test('does not shrink the guarantee for an equal bitrate', () {
      final required = requiredBufferForRendition(
        target: rung('a', 2400000),
        current: rung('b', 2400000),
        base: const Duration(seconds: 30),
      );
      expect(required, const Duration(seconds: 30));
    });

    test('never asks for less than the base for a smaller target', () {
      final required = requiredBufferForRendition(
        target: rung('480p', 1200000),
        current: rung('1080p', 5000000),
        base: const Duration(seconds: 30),
      );
      expect(required, const Duration(seconds: 30));
    });

    test('falls back to a flat multiple when bandwidth is missing', () {
      // A manifest without BANDWIDTH must still be able to climb; guessing a
      // ratio from silence would be worse than asking for twice as much proof.
      final required = requiredBufferForRendition(
        target: rung('1080p', null),
        current: ladder[2],
        base: const Duration(seconds: 30),
      );
      expect(required, const Duration(seconds: 60));
      expect(
        requiredBufferForRendition(
          target: ladder[1],
          current: rung('720p', null),
          base: const Duration(seconds: 30),
        ),
        const Duration(seconds: 60),
      );
    });

    test('treats a zero bandwidth as unknown', () {
      final required = requiredBufferForRendition(
        target: rung('1080p', 0),
        current: ladder[2],
        base: const Duration(seconds: 30),
      );
      expect(required, const Duration(seconds: 60));
    });
  });

  group('planAutoUpgrade gates', () {
    test('refuses when the student pinned a rendition', () {
      final g = governor();
      g.sample(isStalled: false);
      clock.advance(const Duration(minutes: 5));
      g.sample(isStalled: false);

      final result = plan(g, autoQuality: false);
      expect(result.shouldUpgrade, isFalse);
      expect(result.skipReason, UpgradeSkipReason.notAutoMode);
    });

    test('refuses at the top of the ladder', () {
      final g = governor();
      g.sample(isStalled: false);
      clock.advance(const Duration(minutes: 5));
      g.sample(isStalled: false);

      expect(
        plan(g, currentIndex: 1).skipReason,
        UpgradeSkipReason.atTopOfLadder,
      );
    });

    test('refuses when there is no ladder at all', () {
      final g = governor();
      final result = g.planAutoUpgrade(
        qualities: const [],
        currentIndex: 0,
        autoQuality: true,
        bufferedAhead: Duration.zero,
      );
      expect(result.skipReason, UpgradeSkipReason.atTopOfLadder);
    });

    test('refuses before anything has been proven stable', () {
      final g = governor();
      expect(plan(g).skipReason, UpgradeSkipReason.notStableLongEnough);
    });

    test('refuses while still inside the stability window', () {
      final g = governor();
      g.sample(isStalled: false);
      clock.advance(const Duration(seconds: 29));
      g.sample(isStalled: false);

      expect(plan(g).skipReason, UpgradeSkipReason.notStableLongEnough);
    });

    test('refuses inside the dwell after a switch', () {
      // The anti-pump guard: a link that recovers immediately after a
      // downgrade would otherwise climb straight back into trouble. Stability
      // has to be satisfied first, so this asserts the dwell once it is the
      // only rule still unmet.
      final g = governor();
      g.noteQualityChanged();
      g.sample(isStalled: false);
      clock.advance(const Duration(seconds: 31));
      g.sample(isStalled: false);

      final result = plan(g);
      expect(result.skipReason, UpgradeSkipReason.cooldownActive);
      expect(result.shouldUpgrade, isFalse);
    });

    test('permits once the dwell has elapsed', () {
      final g = governor();
      g.noteQualityChanged();
      g.sample(isStalled: false);
      clock.advance(const Duration(seconds: 31));
      g.sample(isStalled: false);
      expect(plan(g).skipReason, UpgradeSkipReason.cooldownActive);

      clock.advance(const Duration(minutes: 2));
      g.sample(isStalled: false);
      expect(plan(g).shouldUpgrade, isTrue);
    });

    test('refuses a rung that recently failed', () {
      final g = governor();
      // Currently at 480p (3); the rung above it is 720p (2).
      g.noteRungFailed(2);
      g.sample(isStalled: false);
      clock.advance(const Duration(minutes: 4));
      g.sample(isStalled: false);

      final result = plan(g, currentIndex: 3);
      expect(result.skipReason, UpgradeSkipReason.rungBlocked);
      // Still one rung at a time: the block is on 720p only, and it sits
      // directly above us so there is no alternative route.
      expect(result.targetIndex, isNull);
    });

    test('forgets a blocked rung at the memory boundary', () {
      final g = governor();
      g.noteRungFailed(2);
      g.sample(isStalled: false);
      clock.advance(const Duration(minutes: 5));
      g.sample(isStalled: false);

      // Exactly on the boundary the rung is free again, and because we only
      // ever step one rung the target is precisely the rung that had failed.
      final result = plan(g, currentIndex: 3);
      expect(result.shouldUpgrade, isTrue);
      expect(result.targetIndex, 2);
    });

    test('ignores an attempt to block the auto sentinel', () {
      final g = governor();
      g.noteRungFailed(kAutoQualityIndex);
      g.sample(isStalled: false);
      clock.advance(const Duration(minutes: 5));
      g.sample(isStalled: false);

      expect(plan(g, currentIndex: 3).shouldUpgrade, isTrue);
    });

    test('refuses when read-ahead cannot sustain the target', () {
      final g = governor();
      g.sample(isStalled: false);
      clock.advance(const Duration(minutes: 5));
      g.sample(isStalled: false);

      // Target is 720p (2.4 Mbps) from 480p (1.2 Mbps) = 2x 30s = 60s.
      final result = plan(g, currentIndex: 3, bufferedAhead: Duration.zero);
      expect(result.skipReason, UpgradeSkipReason.insufficientBuffer);
    });

    test('permits when both signals agree', () {
      final g = governor();
      g.noteQualityChanged();
      g.sample(isStalled: false);
      clock.advance(const Duration(minutes: 3));
      g.sample(isStalled: false);

      final result = plan(
        g,
        currentIndex: 3,
        bufferedAhead: const Duration(seconds: 90),
      );
      expect(result.shouldUpgrade, isTrue);
      expect(result.targetIndex, 2);
    });
  });

  group('stability window', () {
    test('starts on the first healthy sample', () {
      final g = governor();
      expect(g.hasStabilityWindow, isFalse);
      g.sample(isStalled: false);
      expect(g.hasStabilityWindow, isTrue);
      expect(g.stableFor, Duration.zero);
    });

    test('does not restart the clock on later healthy samples', () {
      final g = governor();
      g.sample(isStalled: false);
      clock.advance(const Duration(seconds: 40));
      g.sample(isStalled: false);
      expect(g.stableFor, const Duration(seconds: 40));
    });

    test('is discarded entirely by a single stall', () {
      // Not merely paused: a rendition that just failed should not be credited
      // for the minute before it failed.
      final g = governor();
      g.sample(isStalled: false);
      clock.advance(const Duration(minutes: 4));
      g.sample(isStalled: true);

      expect(g.hasStabilityWindow, isFalse);
      expect(g.stableFor, Duration.zero);
      expect(plan(g).skipReason, UpgradeSkipReason.notStableLongEnough);
    });

    test('a stall drops back to square one rather than resuming', () {
      final g = governor();
      g.sample(isStalled: false);
      clock.advance(const Duration(minutes: 4));
      g.sample(isStalled: true);
      g.sample(isStalled: false);
      clock.advance(const Duration(seconds: 10));
      g.sample(isStalled: false);

      expect(g.stableFor, const Duration(seconds: 10));
      expect(plan(g).skipReason, UpgradeSkipReason.notStableLongEnough);
    });

    test('noteQualityChanged discards accumulated stability', () {
      final g = governor();
      g.sample(isStalled: false);
      clock.advance(const Duration(minutes: 4));
      expect(g.stableFor, const Duration(minutes: 4));

      g.noteQualityChanged();
      expect(g.hasStabilityWindow, isFalse);
      expect(plan(g).skipReason, UpgradeSkipReason.notStableLongEnough);
    });
  });

  group('noteBufferCleared', () {
    test('discards stability but keeps the rung memory', () {
      final g = governor();
      g.sample(isStalled: false);
      clock.advance(const Duration(minutes: 1));
      g.noteRungFailed(2);

      g.noteBufferCleared();

      expect(g.hasStabilityWindow, isFalse);
      // The failed rung must survive a reload, otherwise tearing the player
      // down would be a way to launder a rendition straight back into
      // consideration. Checked while the memory is still live, and because
      // the block outranks stability this holds even though stability was
      // just discarded.
      clock.advance(const Duration(minutes: 4));
      g.sample(isStalled: false);
      expect(
        plan(g, currentIndex: 3).skipReason,
        UpgradeSkipReason.rungBlocked,
      );
    });

    test('discards stability but keeps the dwell clock', () {
      final g = governor();
      g.sample(isStalled: false);
      clock.advance(const Duration(minutes: 1));
      g.noteQualityChanged();

      g.noteBufferCleared();
      clock.advance(const Duration(minutes: 1));
      g.sample(isStalled: false);
      // Long enough to clear the stability rule, so the dwell is the one
      // still holding the ladder back.
      clock.advance(const Duration(seconds: 31));
      g.sample(isStalled: false);

      expect(plan(g).skipReason, UpgradeSkipReason.cooldownActive);
    });
  });

  group('reset', () {
    test('clears stability, dwell and rung memory', () {
      final g = governor();
      g.sample(isStalled: false);
      g.noteRungFailed(2);
      g.noteQualityChanged();

      g.reset();

      expect(g.hasStabilityWindow, isFalse);
      expect(plan(g).skipReason, UpgradeSkipReason.notStableLongEnough);
    });

    test('lets a blocked rung be considered again after reset', () {
      final g = governor();
      g.noteRungFailed(2);
      g.reset();
      g.sample(isStalled: false);
      clock.advance(const Duration(minutes: 5));
      g.sample(isStalled: false);

      expect(plan(g, currentIndex: 3).shouldUpgrade, isTrue);
    });
  });

  group('downgrade then climb round trip', () {
    test('one rung at a time, after the link has earned it', () {
      final g = governor();

      // Link fails while at 720p: controller records the failed rung and
      // switches to 480p.
      g.sample(isStalled: true);
      g.noteRungFailed(2);
      g.noteQualityChanged();
      g.sample(isStalled: false);

      // The block is reported ahead of the transient gates because it is the
      // constraint that outlives them: even once stable, 720p is not an option.
      expect(
        plan(g, currentIndex: 3).skipReason,
        UpgradeSkipReason.rungBlocked,
      );

      // Stable and past the dwell, still blocked - the link has not earned the
      // rung back yet.
      clock.advance(const Duration(minutes: 4));
      g.sample(isStalled: false);
      expect(
        plan(g, currentIndex: 3).skipReason,
        UpgradeSkipReason.rungBlocked,
      );

      // Memory expires; still one rung, not a jump to 1080p.
      clock.advance(const Duration(minutes: 3));
      g.sample(isStalled: false);
      final climbed = plan(g, currentIndex: 3);
      expect(climbed.shouldUpgrade, isTrue);
      expect(climbed.targetIndex, 2);

      // The next step up needs its own full dwell on the new rendition.
      g.noteQualityChanged();
      g.sample(isStalled: false);
      clock.advance(const Duration(minutes: 3));
      g.sample(isStalled: false);
      final next = plan(g, currentIndex: 2);
      expect(next.shouldUpgrade, isTrue);
      expect(next.targetIndex, 1);
      expect(next.targetIndex, lessThan(3), reason: 'never skips a rung');
    });
  });
}
