import 'package:flutter_test/flutter_test.dart';
import 'package:shobaki_academy/controller/playback_edge_cases.dart';

BufferedRange r(int startSeconds, int endSeconds) => (
  start: Duration(seconds: startSeconds),
  end: Duration(seconds: endSeconds),
);

void main() {
  group('computeBufferedAhead', () {
    test('measures the range containing the playhead', () {
      expect(
        computeBufferedAhead([r(0, 300)], const Duration(seconds: 100)),
        const Duration(seconds: 200),
      );
    });

    test('measures the furthest range containing the playhead', () {
      // r(120, 400) is excluded: it starts after the playhead, so it is media
      // the player has not reached yet.
      expect(
        computeBufferedAhead([
          r(0, 120),
          r(120, 400),
          r(0, 200),
        ], const Duration(seconds: 100)),
        const Duration(seconds: 100),
      );
    });

    test('picks the later range once the playhead reaches it', () {
      expect(
        computeBufferedAhead([
          r(0, 120),
          r(120, 400),
        ], const Duration(seconds: 150)),
        const Duration(seconds: 250),
      );
    });

    test('counts a range that genuinely spans the playhead', () {
      // After a seek from 0 to 600 the platform still reports one wide range.
      // It really does cover 600, so it must not be discarded.
      expect(
        computeBufferedAhead([
          r(0, 1000),
          r(595, 640),
        ], const Duration(seconds: 600)),
        const Duration(seconds: 400),
      );
    });

    test('ignores a range left behind entirely by a seek', () {
      expect(
        computeBufferedAhead([
          r(0, 300),
          r(595, 640),
        ], const Duration(seconds: 600)),
        const Duration(seconds: 40),
      );
    });

    test('ignores a range that starts after the playhead', () {
      // A seek to 600 with a buffer that only covers 0-300: reporting 900s of
      // headroom here would convince the stall detector nothing is wrong.
      expect(
        computeBufferedAhead([r(0, 300)], const Duration(seconds: 600)),
        Duration.zero,
      );
    });

    test('ignores stale ranges from before the seek', () {
      expect(
        computeBufferedAhead([r(0, 300)], const Duration(seconds: 600)),
        Duration.zero,
      );
    });

    test('returns zero when the playhead sits in a hole', () {
      expect(
        computeBufferedAhead([
          r(0, 100),
          r(200, 900),
        ], const Duration(seconds: 150)),
        Duration.zero,
      );
    });

    test('returns zero with no ranges', () {
      expect(
        computeBufferedAhead(const [], const Duration(seconds: 10)),
        Duration.zero,
      );
    });

    test('never returns a negative amount', () {
      // A range ending exactly at the playhead, or a zero-length one.
      expect(
        computeBufferedAhead([r(0, 60)], const Duration(seconds: 60)),
        Duration.zero,
      );
      expect(
        computeBufferedAhead([r(30, 30)], const Duration(seconds: 30)),
        Duration.zero,
      );
    });

    test('handles a range that starts before zero after a backwards seek', () {
      expect(
        computeBufferedAhead([r(0, 90)], Duration.zero),
        const Duration(seconds: 90),
      );
    });
  });

  group('classifyCompletion', () {
    const total = Duration(hours: 1, minutes: 30);

    test('accepts a genuine end of media', () {
      expect(
        classifyCompletion(
          maxPosition: total,
          duration: total,
          recoveryInFlight: false,
          lastRecoveryAttemptPosition: null,
        ),
        CompletionVerdict.genuineEnd,
      );
    });

    test('accepts a completion within the slack of the end', () {
      // Keyframe-accurate duration reporting means the final few seconds are
      // legitimately a little short of the stated duration.
      expect(
        classifyCompletion(
          maxPosition: const Duration(hours: 1, minutes: 29, seconds: 57),
          duration: total,
          recoveryInFlight: false,
          lastRecoveryAttemptPosition: null,
        ),
        CompletionVerdict.genuineEnd,
      );
    });

    test('resumes when the backend stops mid-lecture', () {
      // The bug: fvp maps MDK's PlaybackState.stopped - which a network error
      // also produces - to `completed`, and video_player then seeks to the end.
      expect(
        classifyCompletion(
          maxPosition: const Duration(minutes: 42),
          duration: total,
          recoveryInFlight: false,
          lastRecoveryAttemptPosition: null,
        ),
        CompletionVerdict.resumeFromLastPosition,
      );
    });

    test('suppresses while a resume is already in flight', () {
      expect(
        classifyCompletion(
          maxPosition: const Duration(minutes: 42),
          duration: total,
          recoveryInFlight: true,
          lastRecoveryAttemptPosition: null,
        ),
        CompletionVerdict.suppress,
      );
    });

    test('stops retrying once the resume from this position has failed', () {
      // Without this the adapter would seek and play forever on a genuinely
      // wedged backend. The stall ladder is the backstop from here.
      expect(
        classifyCompletion(
          maxPosition: const Duration(minutes: 42),
          duration: total,
          recoveryInFlight: false,
          lastRecoveryAttemptPosition: const Duration(minutes: 42),
        ),
        CompletionVerdict.genuineEnd,
      );
    });

    test('allows a new attempt once the playhead has moved on', () {
      expect(
        classifyCompletion(
          maxPosition: const Duration(minutes: 43),
          duration: total,
          recoveryInFlight: false,
          lastRecoveryAttemptPosition: const Duration(minutes: 42),
        ),
        CompletionVerdict.resumeFromLastPosition,
      );
    });

    test('stays quiet when the duration is unknown', () {
      expect(
        classifyCompletion(
          maxPosition: const Duration(minutes: 42),
          duration: Duration.zero,
          recoveryInFlight: false,
          lastRecoveryAttemptPosition: null,
        ),
        CompletionVerdict.suppress,
      );
    });

    test('honours a custom slack', () {
      expect(
        classifyCompletion(
          maxPosition: const Duration(minutes: 42),
          duration: total,
          recoveryInFlight: false,
          lastRecoveryAttemptPosition: null,
          slack: Duration.zero,
        ),
        CompletionVerdict.resumeFromLastPosition,
      );
      expect(
        classifyCompletion(
          maxPosition: const Duration(minutes: 42),
          duration: total,
          recoveryInFlight: false,
          lastRecoveryAttemptPosition: null,
          slack: const Duration(hours: 2),
        ),
        CompletionVerdict.genuineEnd,
      );
    });

    test('never resumes a player that has not played anything', () {
      // A video that reports "completed" without ever playing is not finished;
      // treating it as such would show the student the end of the lecture with
      // no way back. null must stay distinct from Duration.zero for this.
      expect(
        classifyCompletion(
          maxPosition: Duration.zero,
          duration: total,
          recoveryInFlight: false,
          lastRecoveryAttemptPosition: null,
        ),
        CompletionVerdict.resumeFromLastPosition,
      );
    });

    test('distinguishes "never attempted" from "attempted at zero"', () {
      expect(
        classifyCompletion(
          maxPosition: Duration.zero,
          duration: total,
          recoveryInFlight: false,
          lastRecoveryAttemptPosition: Duration.zero,
        ),
        CompletionVerdict.genuineEnd,
      );
    });
  });
}
