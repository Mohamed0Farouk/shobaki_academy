import 'package:flutter_test/flutter_test.dart';
import 'package:shobaki_academy/services/value_deduplicator.dart';

void main() {
  group('shouldEmit', () {
    test('passes the first value', () {
      final d = ValueDeduplicator<bool>();
      expect(d.shouldEmit(true), isTrue);
    });

    test('suppresses an unchanged repeat', () {
      // The reason this exists: video_player notifies ~10x/second, and each
      // notification used to re-trigger play/pause/load reconciliation.
      final d = ValueDeduplicator<bool>();
      d.shouldEmit(true);
      for (var i = 0; i < 10; i++) {
        expect(d.shouldEmit(true), isFalse);
      }
    });

    test('passes again once the value changes', () {
      final d = ValueDeduplicator<bool>();
      d.shouldEmit(true);
      expect(d.shouldEmit(false), isTrue);
      expect(d.shouldEmit(false), isFalse);
      expect(d.shouldEmit(true), isTrue);
    });

    test('compares by value, not identity', () {
      // Durations arrive as fresh instances every poll; identical values must
      // not count as a change.
      final d = ValueDeduplicator<Duration>();
      d.shouldEmit(const Duration(seconds: 5));
      expect(d.shouldEmit(const Duration(seconds: 5)), isFalse);
      expect(d.shouldEmit(const Duration(milliseconds: 5000)), isFalse);
      expect(d.shouldEmit(const Duration(seconds: 6)), isTrue);
    });

    test('treats the first null as a real value when T is nullable', () {
      final d = ValueDeduplicator<String?>();
      expect(d.shouldEmit(null), isTrue);
      expect(d.shouldEmit(null), isFalse);
      expect(d.shouldEmit('x'), isTrue);
    });
  });

  group('reset', () {
    test('makes the same value emit again', () {
      final d = ValueDeduplicator<Duration>();
      d.shouldEmit(const Duration(seconds: 5));
      d.reset();
      expect(d.shouldEmit(const Duration(seconds: 5)), isTrue);
    });

    test('clears last and hasValue', () {
      final d = ValueDeduplicator<bool>();
      expect(d.hasValue, isFalse);
      d.shouldEmit(true);
      expect(d.last, isTrue);
      expect(d.hasValue, isTrue);
      d.reset();
      expect(d.last, isNull);
      expect(d.hasValue, isFalse);
    });

    test('resets are idempotent', () {
      final d = ValueDeduplicator<Duration>();
      d.shouldEmit(const Duration(seconds: 5));
      d.reset();
      d.reset();
      expect(d.shouldEmit(const Duration(seconds: 5)), isTrue);
    });
  });

  group('rendition switch (regression)', () {
    test('emits after a reset even though every value is unchanged', () {
      // Switching renditions of the same lecture produces an identical
      // duration and an identical resume position. Before reset() existed,
      // every channel was suppressed and load-completion never ran, leaving
      // the player stuck on its loading spinner.
      final duration = ValueDeduplicator<Duration>();
      final position = ValueDeduplicator<Duration>();
      final playing = ValueDeduplicator<bool>();

      duration.shouldEmit(const Duration(minutes: 90));
      position.shouldEmit(const Duration(minutes: 42));
      playing.shouldEmit(false);

      // Simulate open() replacing the source controller.
      duration.reset();
      position.reset();
      playing.reset();

      expect(duration.shouldEmit(const Duration(minutes: 90)), isTrue);
      expect(position.shouldEmit(const Duration(minutes: 42)), isTrue);
      expect(playing.shouldEmit(false), isTrue);
    });
  });
}
