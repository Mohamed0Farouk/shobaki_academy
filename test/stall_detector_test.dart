import 'package:flutter_test/flutter_test.dart';
import 'package:shobaki_academy/controller/stall_detector.dart';

void main() {
  group('StallDetector', () {
    late DateTime now;
    late StallDetector stall;

    /// Advances the fake clock and feeds one observation.
    void sample({
      required int seconds,
      required bool buffering,
      bool playing = true,
    }) {
      now = now.add(const Duration(seconds: 1));
      stall.sample(
        position: Duration(seconds: seconds),
        isBuffering: buffering,
        isPlaying: playing,
      );
    }

    /// Feeds a healthy run of advancing playback.
    void play(int from, int to, {bool buffering = false}) {
      for (var s = from; s <= to; s++) {
        sample(seconds: s, buffering: buffering);
      }
    }

    setUp(() {
      now = DateTime(2026, 1, 1, 9, 0, 0);
      stall = StallDetector(clock: () => now);
    });

    test('a single frozen tick is not a stall', () {
      play(1, 5);
      sample(seconds: 5, buffering: true);
      // One tick of no movement is scheduler jitter at a 1 Hz sample rate.
      expect(stall.isStalled, isFalse);
      expect(stall.action, StallRecoveryAction.none);
    });

    test('two frozen ticks declare a stall', () {
      play(1, 5);
      sample(seconds: 5, buffering: true);
      sample(seconds: 5, buffering: true);
      expect(stall.isStalled, isTrue);
    });

    test('a frozen playhead is a stall even when not reported buffering', () {
      // A wedged decoder with a full buffer reports neither progress nor
      // buffering, and must still be recovered.
      play(1, 5);
      sample(seconds: 5, buffering: false);
      sample(seconds: 5, buffering: false);
      expect(stall.isStalled, isTrue);
      expect(stall.lastWasBuffering, isFalse);
    });

    test('a paused player is never a stall', () {
      play(1, 5);
      sample(seconds: 5, buffering: true, playing: false);
      sample(seconds: 5, buffering: true, playing: false);
      sample(seconds: 5, buffering: true, playing: false);
      expect(stall.isStalled, isFalse);
      expect(stall.stallCount, 0);
    });

    test('resuming playback clears the stall', () {
      play(1, 5);
      sample(seconds: 5, buffering: true);
      sample(seconds: 5, buffering: true);
      expect(stall.isStalled, isTrue);

      sample(seconds: 6, buffering: false);
      expect(stall.isStalled, isFalse);
      expect(stall.action, StallRecoveryAction.none);
    });

    group('recovery ladder', () {
      setUp(() {
        play(1, 5);
        sample(seconds: 5, buffering: true);
        sample(seconds: 5, buffering: true);
        expect(stall.isStalled, isTrue);
      });

      test('waits first', () {
        expect(stall.stalledFor, lessThan(const Duration(seconds: 10)));
        expect(stall.action, StallRecoveryAction.wait);
      });

      test('seeks at 10s', () {
        now = now.add(const Duration(seconds: 10));
        expect(stall.action, StallRecoveryAction.seek);
      });

      test('downgrades at 20s', () {
        now = now.add(const Duration(seconds: 20));
        expect(stall.action, StallRecoveryAction.downgradeQuality);
      });

      test('reloads at 35s', () {
        now = now.add(const Duration(seconds: 35));
        expect(stall.action, StallRecoveryAction.reload);
      });

      test('gives up at 60s', () {
        now = now.add(const Duration(seconds: 60));
        expect(stall.action, StallRecoveryAction.failed);
      });

      test('escalates monotonically as time passes', () {
        // Advance the clock to each rung boundary in turn and confirm the
        // prescribed action at that exact point.
        for (final (offset, expected) in const [
          (10, StallRecoveryAction.seek),
          (20, StallRecoveryAction.downgradeQuality),
          (35, StallRecoveryAction.reload),
          (60, StallRecoveryAction.failed),
        ]) {
          final elapsed = stall.stalledFor;
          now = now.add(Duration(seconds: offset) - elapsed);
          expect(stall.action, expected, reason: 'at +${offset}s');
        }
      });

      test('never repeats an action already taken', () {
        // Re-seeking every second would pin the playhead on the frozen frame
        // and prevent the player from ever recovering.
        now = now.add(const Duration(seconds: 10));
        expect(stall.action, StallRecoveryAction.seek);
        stall.markActionTaken(StallRecoveryAction.seek);

        expect(stall.action, StallRecoveryAction.wait);
        now = now.add(const Duration(seconds: 1));
        expect(stall.action, StallRecoveryAction.wait);
      });

      test('clears the taken-action guard when the stall recovers', () {
        now = now.add(const Duration(seconds: 10));
        stall.markActionTaken(stall.action);

        sample(seconds: 6, buffering: false);
        expect(stall.isStalled, isFalse);

        sample(seconds: 6, buffering: true);
        sample(seconds: 6, buffering: true);
        now = now.add(const Duration(seconds: 10));
        expect(stall.action, StallRecoveryAction.seek);
      });
    });

    group('stallPosition', () {
      test('resumes from the last position that actually played', () {
        play(1, 30);
        sample(seconds: 30, buffering: true);
        sample(seconds: 30, buffering: true);
        expect(stall.stallPosition, const Duration(seconds: 30));
      });

      test('is not rewound by recovery seeks', () {
        play(1, 30);
        sample(seconds: 30, buffering: true);
        sample(seconds: 30, buffering: true);
        now = now.add(const Duration(seconds: 10));
        stall.markActionTaken(stall.action);
        expect(stall.action, StallRecoveryAction.wait);

        sample(seconds: 30, buffering: true);
        expect(stall.stallPosition, const Duration(seconds: 30));
      });

      test('tracks the playhead while playing healthily', () {
        play(1, 100);
        expect(stall.stallPosition, const Duration(seconds: 100));
      });
    });

    group('stall window', () {
      test('counts each distinct stall once', () {
        for (var round = 0; round < 3; round++) {
          play(1, 5);
          sample(seconds: 5, buffering: true);
          sample(seconds: 5, buffering: true);
          // Recover.
          sample(seconds: 6, buffering: false);
        }
        expect(stall.stallCount, 3);
        expect(stall.stallsInWindow, 3);
      });

      test('does not re-count a single continuous freeze', () {
        play(1, 5);
        for (var i = 0; i < 30; i++) {
          sample(seconds: 5, buffering: true);
        }
        expect(stall.stallCount, 1);
      });

      test('forgets stalls older than the window', () {
        play(1, 5);
        sample(seconds: 5, buffering: true);
        sample(seconds: 5, buffering: true);
        sample(seconds: 6, buffering: false);
        expect(stall.stallsInWindow, 1);

        now = now.add(const Duration(minutes: 6));
        expect(stall.stallsInWindow, 0);
      });

      test('asks for a proactive downgrade after two stalls in the window', () {
        expect(stall.shouldProactivelyDowngrade, isFalse);
        play(1, 5);
        sample(seconds: 5, buffering: true);
        sample(seconds: 5, buffering: true);
        sample(seconds: 6, buffering: false);
        expect(stall.shouldProactivelyDowngrade, isFalse);

        play(7, 10);
        sample(seconds: 10, buffering: true);
        sample(seconds: 10, buffering: true);
        expect(stall.stallsInWindow, 2);
        expect(stall.shouldProactivelyDowngrade, isTrue);
      });

      test('does not ask for a downgrade once the window has passed', () {
        play(1, 5);
        sample(seconds: 5, buffering: true);
        sample(seconds: 5, buffering: true);
        sample(seconds: 6, buffering: false);
        play(7, 10);
        sample(seconds: 10, buffering: true);
        sample(seconds: 10, buffering: true);
        expect(stall.shouldProactivelyDowngrade, isTrue);

        now = now.add(const Duration(minutes: 6));
        expect(stall.shouldProactivelyDowngrade, isFalse);
      });

      test('honours a custom window and threshold', () {
        final custom = StallDetector(
          stallWindow: const Duration(minutes: 1),
          autoDowngradeStalls: 3,
          clock: () => now,
        );

        // Two distinct stalls, each frozen long enough to be declared.
        for (var round = 0; round < 2; round++) {
          final base = round * 100;
          for (var i = 1; i <= 3; i++) {
            now = now.add(const Duration(seconds: 1));
            custom.sample(
              position: Duration(seconds: base + i),
              isBuffering: false,
              isPlaying: true,
            );
          }
          for (var i = 0; i < 2; i++) {
            now = now.add(const Duration(seconds: 1));
            custom.sample(
              position: Duration(seconds: base + 3),
              isBuffering: true,
              isPlaying: true,
            );
          }
        }

        expect(custom.stallCount, 2);
        expect(custom.stallsInWindow, 2);
        // Threshold is 3 here, not the default 2.
        expect(custom.shouldProactivelyDowngrade, isFalse);

        // The shorter window forgets the first stall.
        now = now.add(const Duration(minutes: 2));
        expect(custom.stallsInWindow, 0);
      });
    });

    group('reset', () {
      test('clears all accumulated state', () {
        play(1, 5);
        sample(seconds: 5, buffering: true);
        sample(seconds: 5, buffering: true);
        expect(stall.stallCount, 1);

        stall.reset();
        expect(stall.stallCount, 0);
        expect(stall.isStalled, isFalse);
        expect(stall.stalledFor, Duration.zero);
        expect(stall.stallPosition, Duration.zero);
        expect(stall.stallsInWindow, 0);
      });

      test('a fresh detector needs two frozen ticks again', () {
        play(1, 5);
        sample(seconds: 5, buffering: true);
        sample(seconds: 5, buffering: true);
        stall.reset();

        sample(seconds: 5, buffering: true);
        expect(stall.isStalled, isFalse);
      });
    });

    test('a long healthy session never reports a stall', () {
      // Guards against the detector mistaking normal playback for a freeze.
      for (var s = 1; s <= 5400; s++) {
        sample(seconds: s, buffering: s % 600 == 0);
      }
      expect(stall.isStalled, isFalse);
      expect(stall.stallCount, 0);
      expect(stall.action, StallRecoveryAction.none);
    });
  });
}
