import 'package:logger/logger.dart';

/// The single diagnostics switch, read at startup from `.env`
/// (`DIAG_EDITION=1`) - never from a build flag: editing `.env` and
/// restarting the app is the whole opt-in procedure, locally and for the
/// codemagic `macos-diagnostics-build` workflow alike (that workflow
/// forces the line to 1 at build time only). False in regular builds, so
/// the top strip, the log dialog and the status collectors stay out of the
/// way while the capture buffer below stays on and invisible.
bool diagnosticsEnabled = false;

/// Reads the `.env` value of DIAG_EDITION: `1` or `true` (trimmed,
/// case-insensitive) turn the diagnostics edition on; anything else -
/// including an absent line - keeps it off.
bool parseDiagEditionEnv(String? raw) {
  final value = raw?.trim().toLowerCase();
  return value == '1' || value == 'true';
}

/// One captured log record, transported to the diagnostics console window as
/// JSON and rendered there almost exactly like the console printer does.
class DiagnosticLogEntry {
  DiagnosticLogEntry({
    required this.seq,
    required this.time,
    required this.level,
    required this.message,
    this.errorText,
    this.stackTraceText,
  });

  factory DiagnosticLogEntry.fromJson(Map<String, dynamic> json) {
    return DiagnosticLogEntry(
      seq: json['seq'] as int,
      time: DateTime.tryParse(json['t'] as String? ?? '') ?? DateTime.now(),
      level: json['l'] as String? ?? 'INFO',
      message: json['m'] as String? ?? '',
      errorText: json['e'] as String?,
      stackTraceText: json['s'] as String?,
    );
  }

  /// Monotonic id handed out by [DiagnosticLogBuffer]; drives incremental
  /// sync so a reopened console window can bootstrap from a full snapshot
  /// and then receive only what is new.
  final int seq;
  final DateTime time;
  final String level;
  final String message;
  final String? errorText;
  final String? stackTraceText;

  Map<String, dynamic> toJson() => {
        'seq': seq,
        't': time.toIso8601String(),
        'l': level,
        'm': message,
        if (errorText != null) 'e': errorText,
        if (stackTraceText != null) 's': stackTraceText,
      };

  String timestamp() => time.toIso8601String().substring(0, 23);

  /// Outline for the console list and the exported file.
  String formatted({String indent = ''}) {
    final line = '$indent${timestamp()} ▸ ${level.padRight(5)} ▸ $message';
    final error = errorText;
    final stack = stackTraceText;
    if (error == null && stack == null) return line;
    final parts = <String>[line];
    if (error != null) parts.add('$indent       ↳ error: $error');
    if (stack != null) parts.add('$indent       ↳ stack: $stack');
    return parts.join('\n');
  }
}

/// Bounded in-memory replica of everything [projectLogger] printed this run.
///
/// Lives in the main window's isolate; the diagnostics console sub-window is
/// a separate engine and can only receive these through the push channel, so
/// the buffer deliberately exposes no streams - just [entriesAfter] for the
/// incremental sends and [dump] for export.
class DiagnosticLogBuffer {
  DiagnosticLogBuffer._();

  static final DiagnosticLogBuffer instance = DiagnosticLogBuffer._();

  /// Older entries are evicted (oldest first) past this size.
  static const int maxSize = 2000;

  final List<DiagnosticLogEntry> _entries = <DiagnosticLogEntry>[];
  int _nextSeq = 0;
  DateTime? _firstEntryAt;

  int get lastSeq => _entries.isEmpty ? 0 : _entries.last.seq;

  /// Every entry with [seq] > [fromSeq], oldest first.
  ///
  /// A plain scan is clearer than an index for a list capped at
  /// [maxSize].
  List<DiagnosticLogEntry> entriesAfter(int fromSeq) {
    final out = <DiagnosticLogEntry>[];
    for (final entry in _entries) {
      if (entry.seq > fromSeq) out.add(entry);
    }
    return out;
  }

  void clear() {
    _entries.clear();
    _nextSeq = 0;
    _firstEntryAt = null;
  }

  void _add(DiagnosticLogEntry entry) {
    if (_entries.length >= maxSize) _entries.removeAt(0);
    _entries.add(entry);
    _firstEntryAt ??= entry.time;
  }

  void capture(LogEvent event) {
    final entry = DiagnosticLogEntry(
      seq: ++_nextSeq,
      time: event.time,
      level: levelName(event.level),
      message: event.message?.toString() ?? '',
      errorText: event.error?.toString(),
      stackTraceText: event.stackTrace?.toString(),
    );
    _add(entry);
  }

  /// Console-print compatible tablet for the level column.
  static String levelName(Level level) {
    if (level == Level.trace) return 'TRACE';
    if (level == Level.debug) return 'DEBUG';
    if (level == Level.info) return 'INFO';
    if (level == Level.warning) return 'WARN';
    if (level == Level.error) return 'ERROR';
    if (level == Level.fatal) return 'FATAL';
    return 'LOG';
  }

  /// Console list + export file share this ordering.
  static int levelRank(String level) {
    switch (level) {
      case 'TRACE':
        return 0;
      case 'DEBUG':
        return 1;
      case 'LOG':
        return 2;
      case 'INFO':
        return 3;
      case 'WARN':
        return 4;
      case 'ERROR':
        return 5;
      case 'FATAL':
        return 6;
      default:
        return 2;
    }
  }

  /// The whole buffer as a human-readable plaintext document.
  String dump({String? header}) {
    final out = StringBuffer();
    out.writeln('===== Shobaki Academy diagnostics dump =====');
    if (header != null && header.isNotEmpty) {
      for (final line in header.split('\n')) {
        out.writeln(line);
      }
      out.writeln('============');
    }
    out.writeln('entries: ${_entries.length} '
        '(first at ${_firstEntryAt?.toIso8601String() ?? '-'})');
    out.writeln('');
    for (final entry in _entries) {
      out.writeln(entry.formatted());
    }
    return out.toString();
  }
}

/// The only printer [projectLogger] uses: behaves bit-for-bit like the
/// configured [PrettyPrinter] on the console, and keeps a structured copy of
/// every record for the diagnostics edition.
///
/// Override target verified against logger 2.6.2: `LogPrinter.log(LogEvent)`
/// is the entry point, so the raw message/error/stack/time are available
/// before formatting.
class CapturingPrettyPrinter extends PrettyPrinter {
  CapturingPrettyPrinter({
    required super.methodCount,
    required super.errorMethodCount,
    required super.lineLength,
    required super.colors,
    required super.printEmojis,
    required super.dateTimeFormat,
  });

  @override
  List<String> log(LogEvent event) {
    DiagnosticLogBuffer.instance.capture(event);
    return super.log(event);
  }
}
