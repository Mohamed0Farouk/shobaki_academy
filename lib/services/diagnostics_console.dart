import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:get/get.dart';
import 'package:shobaki_academy/services/diagnostic_log.dart';

/// The polling rhythm of the in-app diagnostics console: logs printed in the
/// app at any moment appear here a beat later, without any reactive plumbing.
const Duration kDiagnosticsPanelRefresh = Duration(milliseconds: 300);

/// Status snapshot providers installed on the video page's side. The console
/// never imports app controllers; the page describes the app/player to it.
typedef DiagnosticsStatusCollector = Map<String, dynamic>? Function();

/// One macOS playback experiment the video page offers the console.
class DiagnosticsExperiment {
  const DiagnosticsExperiment(this.id, this.label);

  final String id;
  final String label;
}

/// Applies an experiment and reloads the player page when the flag requires
/// it. Installed only while a Bunny webview is the active macOS player.
typedef DiagnosticsExperimentRunner = Future<void> Function(String id);

/// Owner of the in-app diagnostics console: opens it as a full-screen dialog
/// on top of whatever page is showing, and carries the live status snapshot
/// providers between the video page and the console view.
///
/// Gated on the `.env` switch (DIAG_EDITION=1, read at startup by main):
/// when off, [supported] is false and the banner, the dialog and the
/// collectors all stay inert while the capture buffer in
/// [diagnostic_log.dart] remains on and invisible.
class DiagnosticsConsoleHost {
  DiagnosticsConsoleHost._();

  static final DiagnosticsConsoleHost instance = DiagnosticsConsoleHost._();

  bool get supported => diagnosticsEnabled;

  DiagnosticsStatusCollector? appStatusCollector;
  DiagnosticsStatusCollector? playerStatusCollector;

  /// macOS Bunny webview only. Empty on every other page, so the experiment
  /// row stays hidden. The page clears these when it disposes.
  List<DiagnosticsExperiment> experiments = const [];
  DiagnosticsExperimentRunner? experimentRunner;
  String? activeExperimentId;

  bool _dialogOpen = false;

  /// Opens the console as a full-screen dialog. The player page stays
  /// mounted behind it, so logs and the status row keep streaming while it
  /// is open.
  void open() {
    if (!supported || _dialogOpen) return;
    _dialogOpen = true;
    unawaited(
      Get.dialog<void>(
        Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: const Color(0xFF101418),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          child: const DiagnosticsConsoleView(),
        ),
        barrierDismissible: true,
      ).then((_) => _dialogOpen = false),
    );
  }

  /// Status row as the console shows it: app facts plus the player's live
  /// snapshot, missing sections silently left out.
  Map<String, dynamic> collectStatus() {
    final payload = <String, dynamic>{};
    final app = appStatusCollector?.call();
    if (app != null) payload['app'] = app;
    final player = playerStatusCollector?.call();
    if (player != null) {
      final copy = Map<String, dynamic>.from(player);
      final webview = copy.remove('webview');
      payload['player'] = copy;
      if (webview is Map) {
        payload['webview'] =
            webview.map((key, value) => MapEntry(key.toString(), value));
      }
    }
    return payload;
  }
}

/// Slim top strip marking the app as the diagnostics edition. Mounted once by
/// the root builder in `main.dart`, above every page, so it is impossible to
/// miss and needs no per-page wiring. Tapping anywhere on it opens the
/// console; in a regular build it collapses to nothing.
class DiagnosticsConsoleBanner extends StatelessWidget {
  const DiagnosticsConsoleBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!DiagnosticsConsoleHost.instance.supported) {
      return const SizedBox.shrink();
    }
    return Material(
      color: const Color(0xFFB26A00),
      child: InkWell(
        onTap: () => DiagnosticsConsoleHost.instance.open(),
        child: SizedBox(
          height: 32,
          child: Row(
            children: [
              const SizedBox(width: 10),
              const Icon(
                Icons.terminal_rounded,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'وضع الاختبار - سجلات التشغيل مفعّلة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () => DiagnosticsConsoleHost.instance.open(),
                icon: const Icon(Icons.receipt_long_rounded, size: 14),
                label: const Text(
                  'السجلات',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// The console itself: status row, filters, log list, copy and export. No
/// Scaffold of its own - the host wraps it in a full-screen [Dialog].
class DiagnosticsConsoleView extends StatefulWidget {
  const DiagnosticsConsoleView({super.key});

  @override
  State<DiagnosticsConsoleView> createState() => _DiagnosticsConsoleViewState();
}

class _DiagnosticsConsoleViewState extends State<DiagnosticsConsoleView> {
  final List<DiagnosticLogEntry> _entries = <DiagnosticLogEntry>[];
  final ScrollController _scroll = ScrollController();
  Timer? _refreshTimer;
  Map<String, dynamic>? _status;
  int _lastSeq = 0;
  String _query = '';
  int _minLevelRank = 0;
  bool _follow = true;
  String _experimentSig = '';

  static const _levelChoices = ['ALL', 'INFO', 'WARN', 'ERROR'];

  @override
  void initState() {
    super.initState();
    // 0 => the first refresh replays the entire capture buffer (snapshot),
    // then every later refresh appends only the new tail.
    _refresh();
    _refreshTimer = Timer.periodic(kDiagnosticsPanelRefresh, (_) => _refresh());
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// Same-engine read: no channels involved, nothing to fail.
  void _refresh() {
    final buffer = DiagnosticLogBuffer.instance;
    final host = DiagnosticsConsoleHost.instance;
    final experimentSig =
        '${host.experiments.length}:${host.activeExperimentId}';
    final experimentsChanged = experimentSig != _experimentSig;
    var statusChanged = false;
    try {
      final next = host.collectStatus();
      if (const JsonEncoder().convert(next) !=
          const JsonEncoder().convert(_status ?? const <String, dynamic>{})) {
        _status = next;
        statusChanged = true;
      }
    } catch (_) {
      // Defensiveness only: collectors never throw.
    }
    final fresh = buffer.entriesAfter(_lastSeq);
    if (fresh.isEmpty && !statusChanged && !experimentsChanged) return;
    if (mounted) {
      setState(() {
        _experimentSig = experimentSig;
        if (fresh.isNotEmpty) {
          _entries.addAll(fresh);
          _lastSeq = fresh.last.seq;
          // Same ceiling as the source buffer, plus replay slack; keeps a
          // long-watching console from growing without bound.
          while (_entries.length > DiagnosticLogBuffer.maxSize * 2) {
            _entries.removeAt(0);
          }
        }
      });
    } else if (fresh.isNotEmpty) {
      _entries.addAll(fresh);
      _lastSeq = fresh.last.seq;
    }
    if (_follow) _jumpToEnd();
  }

  Iterable<DiagnosticLogEntry> get _visibleEntries {
    final query = _query.toLowerCase();
    return _entries.where((entry) {
      if (DiagnosticLogBuffer.levelRank(entry.level) < _minLevelRank) {
        return false;
      }
      if (query.isEmpty) return true;
      return entry.message.toLowerCase().contains(query) ||
          (entry.errorText ?? '').toLowerCase().contains(query);
    });
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _onScroll() {
    final controller = _scroll.hasClients ? _scroll.position : null;
    if (controller == null) return;
    final atEnd = controller.maxScrollExtent - controller.pixels < 24;
    if (!atEnd && _follow) {
      setState(() => _follow = false);
    }
  }

  String get _logFontFamily =>
      Platform.isMacOS || Platform.isIOS ? 'Menlo' : 'Consolas';

  String _dump() {
    final out = StringBuffer()
      ..writeln('===== Shobaki Academy diagnostics dump =====')
      ..writeln('generated: ${DateTime.now().toIso8601String()}')
      ..writeln('platform: ${Platform.operatingSystem} '
          '${Platform.operatingSystemVersion}')
      ..writeln('entries: ${_visibleEntries.length} shown / ${_entries.length}'
          ' captured');
    final status = _status ?? const <String, dynamic>{};
    final app = status['app'] as Map? ?? const <String, dynamic>{};
    final player = status['player'] as Map? ?? const <String, dynamic>{};
    final webview = status['webview'] as Map? ?? const <String, dynamic>{};
    for (final key in app.keys) {
      out.writeln('app.$key: ${app[key]}');
    }
    for (final key in player.keys) {
      out.writeln('player.$key: ${player[key]}');
    }
    for (final key in webview.keys) {
      out.writeln('webview.$key: ${webview[key]}');
    }
    out.writeln('================================================');
    for (final entry in _visibleEntries) {
      out.writeln(entry.formatted());
    }
    return out.toString();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyAll() async {
    try {
      await Clipboard.setData(ClipboardData(text: _dump()));
      _toast('السجل كامل في الحافظة');
    } catch (_) {
      _toast('تعذّر النسخ');
    }
  }

  Future<void> _export() async {
    try {
      final name =
          'shobaki-diagnostics-${DateTime.now().toIso8601String()}'
              .replaceAll(RegExp(r'[:. ]'), '-');
      final bytes = Uint8List.fromList(utf8.encode(_dump()));
      await FileSaver.instance.saveAs(
        name: name,
        bytes: bytes,
        fileExtension: 'txt',
        mimeType: MimeType.text,
      );
      _toast('تم حفظ ملف السجل.');
    } catch (_) {
      _toast('تعذّر حفظ السجل.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Left-to-right internals inside the Arabic app: timestamps, levels and
    // console affordances read far better in a mono LTR column.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          _header(context),
          if (DiagnosticsConsoleHost.instance.experiments.isNotEmpty)
            _experimentBar(),
          _StatusGrid(status: _status),
          _toolbar(context),
          Expanded(child: _logList()),
        ],
      ),
    );
  }

  Future<void> _copyStats() async {
    final webview = _status?['webview'];
    if (webview is! Map || webview.isEmpty) {
      _toast('لا توجد أرقام للمشغّل بعد — انتظر نبضة ثم أعد النسخ');
      return;
    }
    try {
      final text = const JsonEncoder.withIndent('  ').convert(webview);
      await Clipboard.setData(ClipboardData(text: text));
      _toast('أرقام المشغّل في الحافظة');
    } catch (_) {
      _toast('تعذّر نسخ الأرقام');
    }
  }

  Widget _experimentBar() {
    final host = DiagnosticsConsoleHost.instance;
    return Container(
      color: const Color(0xFF1A1408),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Close this panel to watch. Seek to the same spot, wait 60–90s, '
            'reopen, then Copy stats. Baseline is today\'s player.',
            style: TextStyle(color: Color(0xFFFFCC80), fontSize: 11),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final experiment in host.experiments)
                ActionChip(
                  label: Text(
                    experiment.label,
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: host.activeExperimentId == experiment.id
                      ? const Color(0xFFB26A00)
                      : const Color(0xFF2A2418),
                  labelStyle: const TextStyle(color: Colors.white),
                  onPressed: () {
                    final runner = host.experimentRunner;
                    if (runner == null) return;
                    setState(() => host.activeExperimentId = experiment.id);
                    unawaited(runner(experiment.id));
                    _toast(
                      '${experiment.label}: applied. Close the panel and watch.',
                    );
                  },
                ),
              ActionChip(
                avatar: const Icon(Icons.copy_rounded, size: 14, color: Colors.white),
                label: const Text('Copy stats', style: TextStyle(fontSize: 11)),
                backgroundColor: const Color(0xFF1E3A2F),
                labelStyle: const TextStyle(color: Colors.white),
                onPressed: () => unawaited(_copyStats()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: const Color(0xFF141A20),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
          const Expanded(
            child: Text(
              'Diagnostics - logs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copy all',
            onPressed: () => unawaited(_copyAll()),
            icon: const Icon(Icons.copy_all_rounded, size: 20),
          ),
          IconButton(
            tooltip: 'Save .txt',
            onPressed: () => unawaited(_export()),
            icon: const Icon(Icons.save_outlined, size: 20),
          ),
          Icon(Icons.terminal_rounded, size: 14, color: colorScheme.primary),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: const Color(0xFF161C22),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: TextEditingController(text: _query),
              onChanged: (value) => setState(() => _query = value),
              style: TextStyle(fontSize: 12, fontFamily: _logFontFamily),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'search: message...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search, size: 16),
              ),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _levelChoices[_minLevelRank.clamp(0, 3)],
              items: [
                for (final choice in _levelChoices)
                  DropdownMenuItem(value: choice, child: Text(choice)),
              ],
              onChanged: (choice) {
                if (choice == null) return;
                setState(
                  () => _minLevelRank = _levelChoices.indexOf(choice),
                );
              },
            ),
          ),
          const VerticalDivider(width: 12),
          IconButton(
            tooltip: _follow
                ? 'Following (auto-scroll)'
                : 'Paused - tap to follow',
            onPressed: () {
              setState(() => _follow = true);
              _jumpToEnd();
            },
            color: _follow ? colorScheme.primary : null,
            icon: Icon(
              _follow
                  ? Icons.arrow_circle_down_rounded
                  : Icons.pause_circle_outline_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _logList() {
    final entries = _visibleEntries.toList(growable: false);
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${entry.timestamp()} ',
                style: TextStyle(
                  color: Colors.blueGrey.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontFamily: _logFontFamily,
                ),
              ),
              TextSpan(
                text: entry.level.padRight(5),
                style: TextStyle(
                  color: _levelColor(entry.level),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: _logFontFamily,
                ),
              ),
              TextSpan(
                text: ' ${entry.message}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontFamily: _logFontFamily,
                ),
              ),
              if (entry.errorText != null)
                TextSpan(
                  text: '\n  ↳ ${entry.errorText}',
                  style: TextStyle(
                    color: _levelColor(entry.level),
                    fontSize: 10.5,
                    fontFamily: _logFontFamily,
                  ),
                ),
              if (entry.stackTraceText != null)
                TextSpan(
                  text: '\n  ↳ stack: '
                      '${_firstStackLine(entry.stackTraceText ?? '')}',
                  style: TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 10.5,
                    fontFamily: _logFontFamily,
                  ),
                ),
            ],
          ),
          softWrap: true,
        );
      },
    );
  }

  String _firstStackLine(String stack) {
    return stack.split('\n').where((l) => l.trim().isNotEmpty).join(" | ");
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'TRACE':
      case 'DEBUG':
        return Colors.lightBlueAccent;
      case 'INFO':
        return Colors.lightGreenAccent;
      case 'WARN':
        return Colors.orangeAccent;
      case 'ERROR':
        return Colors.redAccent;
      case 'FATAL':
        return Colors.deepOrangeAccent;
      default:
        return Colors.white60;
    }
  }
}

class _StatusGrid extends StatelessWidget {
  const _StatusGrid({required this.status});

  final Map<String, dynamic>? status;

  @override
  Widget build(BuildContext context) {
    if (status == null) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: Text(
          'waiting for status...',
          style: TextStyle(fontSize: 11),
        ),
      );
    }
    final rows = <Widget>[];
    for (final sectionKey in ['app', 'player', 'webview']) {
      final section = status![sectionKey];
      if (section is! Map || section.isEmpty) continue;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Wrap(
          spacing: 14,
          runSpacing: 3,
          children: [
            for (final entry in section.entries)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${entry.key}: ',
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: '${entry.value}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ));
    }
    return Container(
      color: const Color(0xFF141A20),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }
}
