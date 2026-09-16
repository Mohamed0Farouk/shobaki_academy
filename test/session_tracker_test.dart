import 'package:flutter_test/flutter_test.dart';
import 'package:shobaki_academy/controller/session_tracker.dart';

void main() {
  group('SessionTracker', () {
    late DateTime now;
    late SessionTracker tracker;

    const sessionLimit = Duration(hours: 3);
    const pauseLimit = Duration(minutes: 30);

    setUp(() {
      now = DateTime(2026, 1, 1, 10, 0, 0);
      tracker = SessionTracker(
        maxSessionDurationSeconds: sessionLimit.inSeconds,
        maxPauseSeconds: pauseLimit.inSeconds,
        clock: () => now,
      );
    });

    void advance(Duration d) => now = now.add(d);

    test('not expired before the session limit', () {
      tracker.onPlay();
      advance(const Duration(hours: 2, minutes: 59));

      expect(tracker.tick(), isFalse);
      expect(tracker.expired, isFalse);
      expect(tracker.expiryReason, isNull);
    });

    test('expires when the session exceeds the limit', () {
      tracker.onPlay();
      advance(const Duration(hours: 3));

      expect(tracker.tick(), isTrue);
      expect(tracker.expired, isTrue);
      expect(tracker.expiryReason, SessionTracker.sessionExpiredMessage);
    });

    test('expires after 30 minutes of continuous pause', () {
      tracker.onPlay();
      advance(const Duration(minutes: 5));
      tracker.onPause();
      advance(const Duration(minutes: 30));

      expect(tracker.tick(), isTrue);
      expect(tracker.expired, isTrue);
      expect(tracker.expiryReason, SessionTracker.pauseExpiredMessage);
    });

    test('pause time is not counted as viewing time', () {
      tracker.onPlay();
      advance(const Duration(minutes: 5));
      tracker.onPause();
      advance(const Duration(minutes: 20));
      tracker.tick();
      expect(tracker.viewDurationSeconds, 5 * 60);

      tracker.onPlay();
      advance(const Duration(minutes: 10));
      tracker.onPause();
      expect(tracker.viewDurationSeconds, 15 * 60);
    });

    test('view duration includes the active play segment', () {
      tracker.onPlay();
      advance(const Duration(minutes: 42));
      tracker.tick();

      expect(tracker.viewDurationSeconds, 42 * 60);
    });

    test('pause clock resets when playback resumes', () {
      tracker.onPlay();
      advance(const Duration(minutes: 5));
      tracker.onPause();
      advance(const Duration(minutes: 29));
      expect(tracker.tick(), isFalse);

      tracker.onPlay();
      advance(const Duration(minutes: 29));
      expect(tracker.tick(), isFalse);
      expect(tracker.expired, isFalse);
    });

    test('onClose flushes an active but unexpired session', () {
      tracker.onPlay();
      advance(const Duration(minutes: 15));
      tracker.onClose();

      expect(tracker.accumulatedSeconds, 15 * 60);
      expect(tracker.viewDurationSeconds, 15 * 60);
    });

    test('onClose after expiry does not inflate accumulated view time', () {
      tracker.onPlay();
      // The app was suspended; the periodic timer did not fire while the
      // media kept "playing" for ~22 hours.
      advance(const Duration(hours: 22));

      expect(tracker.tick(), isTrue);
      tracker.onClose();

      expect(tracker.expired, isTrue);
      expect(
        tracker.accumulatedSeconds,
        lessThanOrEqualTo(sessionLimit.inSeconds),
      );
      expect(
        tracker.viewDurationSeconds,
        lessThanOrEqualTo(sessionLimit.inSeconds),
      );
    });

    test('view duration is capped at the session limit on clock skew', () {
      tracker.onPlay();
      advance(const Duration(days: 2));

      expect(tracker.tick(), isTrue);
      expect(tracker.expired, isTrue);
      expect(tracker.viewDurationSeconds, sessionLimit.inSeconds);
    });

    test('background time is not counted as viewing time', () {
      tracker.onPlay();
      advance(const Duration(minutes: 10));
      tracker.onBackground();
      advance(const Duration(hours: 20));

      expect(tracker.tick(), isTrue);
      expect(tracker.expired, isTrue);
      expect(tracker.accumulatedSeconds, 10 * 60);
      expect(tracker.viewDurationSeconds, 10 * 60);
    });

    test('onPlay/onPause/onClose are no-ops after expiry', () {
      tracker.onPlay();
      advance(const Duration(hours: 3));
      tracker.tick();

      final acc = tracker.accumulatedSeconds;
      final view = tracker.viewDurationSeconds;

      tracker.onPlay();
      advance(const Duration(hours: 1));
      tracker.onPause();
      tracker.onClose();

      expect(tracker.expired, isTrue);
      expect(tracker.accumulatedSeconds, acc);
      expect(tracker.viewDurationSeconds, view);
    });

    test('expire is idempotent', () {
      tracker.onPlay();
      advance(const Duration(hours: 4));

      tracker.expire(SessionTracker.sessionExpiredMessage);
      final acc = tracker.accumulatedSeconds;
      tracker.expire(SessionTracker.pauseExpiredMessage);

      expect(tracker.expiryReason, SessionTracker.sessionExpiredMessage);
      expect(tracker.accumulatedSeconds, acc);
    });
  });

  group('SessionTracker defaults', () {
    test('default constants match the product requirements', () {
      expect(SessionTracker.sessionExpiredMessage, contains('3 ساعات'));
      expect(SessionTracker.pauseExpiredMessage, contains('30 دقيقة'));

      const maxSession = 10800;
      const maxPause = 1800;
      expect(maxSession, 3 * 60 * 60);
      expect(maxPause, 30 * 60);
    });
  });
}