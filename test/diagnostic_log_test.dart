import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:shobaki_academy/services/diagnostic_log.dart';

void main() {
  setUp(() {
    DiagnosticLogBuffer.instance.clear();
  });

  group('parseDiagEditionEnv', () {
    test('accepts 1 and true, trimmed and case-insensitive', () {
      expect(parseDiagEditionEnv('1'), isTrue);
      expect(parseDiagEditionEnv('true'), isTrue);
      expect(parseDiagEditionEnv(' TRUE '), isTrue);
      expect(parseDiagEditionEnv('1\n'), isTrue);
    });

    test('everything else keeps the diagnostics edition off', () {
      expect(parseDiagEditionEnv(null), isFalse);
      expect(parseDiagEditionEnv(''), isFalse);
      expect(parseDiagEditionEnv('   '), isFalse);
      expect(parseDiagEditionEnv('0'), isFalse);
      expect(parseDiagEditionEnv('false'), isFalse);
      // A commented template line must never read as "on".
      expect(parseDiagEditionEnv('# DIAG_EDITION=1'), isFalse);
    });
  });

  DiagnosticLogEntry captureEvent(
    Level level,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    final buffer = DiagnosticLogBuffer.instance;
    final before = buffer.lastSeq;
    buffer.capture(
      LogEvent(
        level,
        message,
        error: error,
        stackTrace: stack,
      ),
    );
    final entry = buffer.entriesAfter(before).first;
    return entry;
  }

  group('DiagnosticLogEntry', () {
    test('json round trip preserves every field', () {
      final time = DateTime(2026, 11, 1, 12, 30);
      final entry = DiagnosticLogEntry(
        seq: 7,
        time: time,
        level: 'WARN',
        message: 'probe failed',
        errorText: 'SocketException',
        stackTraceText: 'frame a\nframe b',
      );

      final restored = DiagnosticLogEntry.fromJson(entry.toJson());

      expect(restored.seq, 7);
      expect(restored.time, time);
      expect(restored.level, 'WARN');
      expect(restored.message, 'probe failed');
      expect(restored.errorText, 'SocketException');
      expect(restored.stackTraceText, 'frame a\nframe b');
    });

    test('json omits absent error/stack keys', () {
      final json = DiagnosticLogEntry(
        seq: 1,
        time: DateTime(2026),
        level: 'INFO',
        message: 'plain',
      ).toJson();
      expect(json.containsKey('e'), isFalse);
      expect(json.containsKey('s'), isFalse);
      expect(json['l'], 'INFO');
    });

    test('formatted renders level, message and error', () {
      final text = DiagnosticLogEntry(
        seq: 1,
        time: DateTime(2026, 1, 2, 9, 0, 0, 500),
        level: 'ERROR',
        message: 'boom',
        errorText: 'StateError: bad state',
      ).formatted();
      expect(text, contains('ERROR'));
      expect(text, contains('boom'));
      expect(text, contains('StateError: bad state'));
    });
  });

  group('DiagnosticLogBuffer', () {
    test('capture maps logger levels to stable names', () {
      expect(captureEvent(Level.info, 'i').level, 'INFO');
      expect(captureEvent(Level.warning, 'w').level, 'WARN');
      expect(captureEvent(Level.error, 'e').level, 'ERROR');
      expect(captureEvent(Level.debug, 'd').level, 'DEBUG');
      expect(captureEvent(Level.fatal, 'f').level, 'FATAL');
    });

    test('entriesAfter returns only newer entries', () {
      final first = captureEvent(Level.info, 'first');
      final second = captureEvent(Level.info, 'second');
      final after = DiagnosticLogBuffer.instance.entriesAfter(first.seq);
      expect(after.map((e) => e.message), ['second']);
      expect(DiagnosticLogBuffer.instance.lastSeq, second.seq);
    });

    test('oldest entries are evicted past the cap', () {
      final buffer = DiagnosticLogBuffer.instance;
      for (var i = 0; i < DiagnosticLogBuffer.maxSize + 10; i++) {
        captureEvent(Level.info, 'entry-$i');
      }
      final entries = buffer.entriesAfter(0);
      expect(entries.length, DiagnosticLogBuffer.maxSize);
      // seq is monotonic: eviction keeps the newest by sequence number.
      expect(entries.first.message, 'entry-10');
      expect(entries.last.message, 'entry-${DiagnosticLogBuffer.maxSize + 9}');
    });

    test('dump carries header, count and formatted entries', () {
      captureEvent(Level.warning, 'careful',
          StateError('bad'), StackTrace.fromString('trace line'));
      final text = DiagnosticLogBuffer.instance.dump(header: 'unit test');
      expect(text, contains('diagnostics dump'));
      expect(text, contains('unit test'));
      expect(text, contains('entries: 1'));
      expect(text, contains('careful'));
      expect(text, contains('bad'));
      expect(text, contains('trace line'));
    });

    test('levelRank orders console filtering', () {
      expect(
        DiagnosticLogBuffer.levelRank('TRACE'),
        lessThan(DiagnosticLogBuffer.levelRank('INFO')),
      );
      expect(
        DiagnosticLogBuffer.levelRank('INFO'),
        lessThan(DiagnosticLogBuffer.levelRank('ERROR')),
      );
      // Unknown names fall into the middle band instead of hiding everything.
      expect(DiagnosticLogBuffer.levelRank('???'), 2);
    });
  });

  group('CapturingPrettyPrinter', () {
    test('log() stores the event fields verbatim, then prints', () {
      final printer = CapturingPrettyPrinter(
        methodCount: 0,
        errorMethodCount: 0,
        lineLength: 80,
        colors: false,
        printEmojis: false,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      );
      final time = DateTime(2026, 11, 1, 13, 45);
      final lines = printer.log(
        LogEvent(
          Level.error,
          'Bunny media ONLINE event lost',
          error: StateError('no state'),
          stackTrace: StackTrace.fromString('frame x'),
          time: time,
        ),
      );
      expect(lines, isNotEmpty);

      final entry = DiagnosticLogBuffer.instance.entriesAfter(0).last;
      expect(entry.level, 'ERROR');
      expect(entry.message, 'Bunny media ONLINE event lost');
      expect(entry.time, time);
      expect(entry.errorText, 'Bad state: no state');
      expect(entry.stackTraceText, contains('frame x'));
    });
  });
}
