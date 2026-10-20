import 'dart:async';
import 'dart:io' show Directory, Platform;

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import 'package:shobaki_academy/controller/bunny_embed.dart';
import 'package:shobaki_academy/controller/player_adapter.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/services/value_deduplicator.dart';

/// Whether the shared WebView2 environment has already been pointed at a
/// writable user-data folder.
///
/// The environment is shared by every controller in the process, so this is
/// configured once rather than per adapter.
bool _environmentConfigured = false;

/// Points WebView2 at a user-data folder the app can actually write to.
///
/// Its default location sits next to the executable, which is read-only for
/// an install under Program Files (MSIX or otherwise), and a browser engine
/// that cannot write its profile fails in ways that look like network errors.
///
/// Safe to call concurrently with a previous adapter still tearing down: a
/// [PlatformException] here only means another controller is alive, which
/// means the environment was already configured by that instance.
Future<void> _configureWebViewEnvironment() async {
  if (_environmentConfigured) return;
  try {
    final support = await getApplicationSupportDirectory();
    final userData = Directory(
      '${support.path}${Platform.pathSeparator}WebView2',
    );
    if (!await userData.exists()) {
      await userData.create(recursive: true);
    }
    await WebviewController.initializeEnvironment(userDataPath: userData.path);
    _environmentConfigured = true;
  } on PlatformException catch (e) {
    _environmentConfigured = true;
    projectLogger.w('WebView2 environment already configured: ${e.message}');
  } catch (e, s) {
    // Left unconfigured so the next adapter retries; the engine falls back to
    // its default folder in the meantime.
    projectLogger.e('WebView2 environment setup failed: $e\n$s');
  }
}

/// [IPlayerAdapter] backed by the Bunny Stream embed player running inside an
/// in-app WebView2 surface.
///
/// The embed page is a normal Chromium document, so every interaction with the
/// media goes through JavaScript: events arrive as `postMessage` payloads from
/// an injected bridge script, and commands are pushed back in with
/// `executeScript`. That is deliberately different from the native adapters,
/// where the platform hands us position/duration for free.
///
/// Why in-app: WebView2 composites its content as a Flutter `Texture`, so the
/// watermark overlay painted in `main.dart` keeps covering the video - a
/// separate OS window (the `desktop_webview_window` approach) would not.
///
/// The page is loaded from the raw CDN playlist URL the DB stores: [open]
/// maps it to the embed player itself, so callers never have to know about
/// `player.mediadelivery.net`.
class BunnyWebviewPlayerAdapter implements IPlayerAdapter {
  BunnyWebviewPlayerAdapter();

  /// The native webview. Created eagerly (no native side exists until
  /// [WebviewController.initialize]) so the view can mount [Webview] as soon
  /// as this adapter exists; the widget renders an empty box until then.
  final WebviewController controller = WebviewController();

  final StreamController<bool> _playingCtrl =
      StreamController<bool>.broadcast();
  final StreamController<Duration> _durationCtrl =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _completedCtrl =
      StreamController<bool>.broadcast();
  final StreamController<String?> _errorCtrl =
      StreamController<String?>.broadcast();
  final StreamController<Duration> _positionCtrl =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _bufferingCtrl =
      StreamController<bool>.broadcast();

  final _playing = ValueDeduplicator<bool>();
  final _duration = ValueDeduplicator<Duration>();
  final _position = ValueDeduplicator<Duration>();
  final _buffering = ValueDeduplicator<bool>();

  StreamSubscription<dynamic>? _messageSub;
  StreamSubscription<LoadingState>? _loadingSub;
  StreamSubscription<WebErrorStatus>? _loadErrorSub;
  Timer? _probeTimer;

  bool _wired = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  Duration _positionValue = Duration.zero;
  Duration _durationValue = Duration.zero;
  bool _isPlaying = false;
  bool _isCompleted = false;
  String? _errorText;

  /// Starts true and only clears once a duration is known. The controller's
  /// load watchdog reads this flag: staying true while the embed boots makes
  /// it extend the wait instead of declaring a premature load failure.
  bool _isBuffering = true;

  /// Set when the embed page finished its first navigation. The fallback
  /// probe must not poke a document that is still loading.
  bool _pageSettled = false;

  /// Last time the bridge script checked in. `null` means "never", which
  /// keeps the probe quiet until the page has had a chance to start.
  DateTime? _lastBridgeAt;

  /// Resume position handed to [open], applied once the media reports a
  /// duration (before that, `currentTime` cannot be set meaningfully).
  Duration? _pendingSeek;

  /// Play intent issued before the media element exists.
  ///
  /// The embed loads with `autoplay=false`, so nothing starts on its own: a
  /// backend switch that was mid-lecture has to carry the intent across the
  /// navigation or the student lands on a paused frame.
  bool _playWhenReady = false;

  /// Whether the deferred [_playWhenReady] intent has already been replayed,
  /// so a stream of state messages cannot stack `play()` calls.
  bool _playIntentApplied = false;

  /// Position of the last spurious-end recovery attempt, so a broken stream
  /// cannot loop forever.
  Duration? _lastRecoveryAttemptPosition;

  static const Duration _completionSlack = Duration(seconds: 5);

  /// How long the bridge may stay silent (while the page is settled) before
  /// the Dart side starts probing the media element itself.
  static const Duration _bridgeSilenceThreshold = Duration(seconds: 8);

  @override
  bool get isPlaying => _isPlaying;

  @override
  Duration get position => _positionValue;

  @override
  Duration get duration => _durationValue;

  @override
  bool get isCompleted => _isCompleted;

  @override
  String? get error => _errorText;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isBuffering => _isBuffering;

  @override
  Duration get bufferedAhead => Duration.zero;

  @override
  Stream<bool> get onPlayingChanged => _playingCtrl.stream;

  @override
  Stream<Duration> get onDurationChanged => _durationCtrl.stream;

  @override
  Stream<bool> get onCompleted => _completedCtrl.stream;

  @override
  Stream<String?> get onError => _errorCtrl.stream;

  @override
  Stream<Duration> get onPositionChanged => _positionCtrl.stream;

  @override
  Stream<bool> get onBufferingChanged => _bufferingCtrl.stream;

  /// Fires when the embed page enters or leaves HTML5 fullscreen. The view
  /// turns this into an OS-level window fullscreen so the student gets the
  /// same immersive mode the native player has.
  Stream<bool> get onFullScreenChanged =>
      controller.containsFullScreenElementChanged;

  @override
  Future<void> open(String url, {Duration? start}) async {
    if (_isDisposed) return;

    final embedUrl =
        tryBuildBunnyEmbedUrl(url) ?? (isBunnyEmbedUrl(url) ? url : null);
    if (embedUrl == null) {
      throw StateError('Not an embeddable Bunny Stream URL: $url');
    }

    _pendingSeek = (start != null && start > Duration.zero) ? start : null;
    _playWhenReady = false;
    _playIntentApplied = false;
    _resetDedup();
    _positionValue = Duration.zero;
    _durationValue = Duration.zero;
    _isPlaying = false;
    _isCompleted = false;
    _errorText = null;
    _isBuffering = true;
    _pageSettled = false;
    _lastBridgeAt = null;
    _lastRecoveryAttemptPosition = null;

    await _ensureWired();
    await controller.loadUrl(embedUrl);
    _startProbe();
  }

  @override
  Future<void> play() async {
    _playWhenReady = true;
    if (await _runOnVideo('play()')) return;
    // No media element yet - the embed is still booting. The intent is
    // replayed the moment the bridge reports a duration.
  }

  @override
  Future<void> pause() async {
    _playWhenReady = false;
    await _runOnVideo('pause()');
  }

  @override
  Future<void> seek(Duration position) async {
    final clamped = position.isNegative ? Duration.zero : position;
    _positionValue = clamped;
    await _runOnVideo('currentTime=${clamped.inMilliseconds / 1000.0}');
    if (_position.shouldEmit(clamped) && !_positionCtrl.isClosed) {
      _positionCtrl.add(clamped);
    }
  }

  @override
  Future<void> setRate(double rate) {
    if (rate <= 0) return Future.value();
    return _runOnVideo('playbackRate=$rate');
  }

  @override
  Future<void> setVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    return _runOnVideo('volume=$clamped');
  }

  @override
  Future<void> stop() => pause();

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _probeTimer?.cancel();
    await _messageSub?.cancel();
    await _loadingSub?.cancel();
    await _loadErrorSub?.cancel();
    await controller.dispose();
    await _playingCtrl.close();
    await _durationCtrl.close();
    await _completedCtrl.close();
    await _errorCtrl.close();
    await _positionCtrl.close();
    await _bufferingCtrl.close();
    _isInitialized = false;
  }

  void _resetDedup() {
    _playing.reset();
    _duration.reset();
    _position.reset();
    _buffering.reset();
  }

  /// Brings the native webview up and installs the bridge script.
  ///
  /// Everything that must happen before the first navigation is done here and
  /// exactly once per adapter: the event subscriptions are attached before
  /// [WebviewController.loadUrl], otherwise the early lifecycle events of the
  /// embed page would be lost.
  Future<void> _ensureWired() async {
    await _configureWebViewEnvironment();
    if (!controller.value.isInitialized) {
      await controller.initialize();
    }
    if (_wired) return;
    _wired = true;

    await controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    await controller.setBackgroundColor(const Color(0xFF000000));
    // The embed page is a plain media player: DevTools and its context menu
    // would only be a detour (and a screenshot surface) for the student.
    await controller.setDevToolsEnabled(false);
    await controller.setDefaultContextMenusEnabled(false);
    await controller.addScriptToExecuteOnDocumentCreated(kBridgeScript);

    _messageSub = controller.webMessage.listen(_onBridgeMessage);
    _loadingSub = controller.loadingState.listen(_onLoadingStateChanged);
    _loadErrorSub = controller.onLoadError.listen((status) {
      _emitError('تعذر تحميل صفحة المشغّل (${status.name})');
    });

    _isInitialized = true;
  }

  void _onLoadingStateChanged(LoadingState state) {
    if (_isDisposed) return;
    if (state == LoadingState.navigationCompleted) {
      _pageSettled = true;
    } else if (state == LoadingState.loading) {
      // A (re)navigation is in flight: the previous document's media is gone,
      // so the probe must wait for the new one to settle.
      _pageSettled = false;
    }
  }

  void _onBridgeMessage(dynamic raw) {
    if (_isDisposed || raw is! Map) return;
    final msg = raw.cast<String, dynamic>();
    if (msg['source'] != 'shobaki') return;

    _lastBridgeAt = DateTime.now();
    final type = msg['e'] as String? ?? '';

    _applyState(
      position: _secondsToDuration(msg['p']),
      duration: _secondsToDuration(msg['d']),
      playing: _boolOrNull(msg['playing']),
      type: type,
    );

    switch (type) {
      case 'wait':
        _setBuffering(true);
      case 'ended':
        _onEnded();
      case 'error':
        _emitError('خطأ في تشغيل الفيديو (رمز ${msg['code'] ?? '?'})');
    }
  }

  /// Folds one observation of the media element into the adapter state.
  ///
  /// [type] only decides the buffering bookkeeping below; the position,
  /// duration and playing flag are applied the same way for bridge events and
  /// for probe results, so a page whose bridge never fires still drives the
  /// tracking pipeline exactly as a healthy one does.
  void _applyState({
    required Duration position,
    required Duration duration,
    required bool? playing,
    required String type,
  }) {
    if (duration > Duration.zero) {
      _durationValue = duration;
      if (_duration.shouldEmit(duration) && !_durationCtrl.isClosed) {
        _durationCtrl.add(duration);
      }
      // First time the media is real: release the buffering latch the load
      // watchdog is waiting on, and honour any resume position. A `wait`
      // report carries the same numbers but must keep the latch set.
      if (type != 'wait' && _isBuffering) _setBuffering(false);
      _maybeApplyPendingSeek();
      _maybeReplayPlayIntent();
    }

    if (position > Duration.zero) {
      _positionValue = position;
      if (_position.shouldEmit(position) && !_positionCtrl.isClosed) {
        _positionCtrl.add(position);
      }
    }

    if (playing != null) _setPlaying(playing);
  }

  void _maybeApplyPendingSeek() {
    final target = _pendingSeek;
    if (target == null || _durationValue <= Duration.zero) return;
    _pendingSeek = null;
    unawaited(seek(target));
  }

  /// Replays a [play] that arrived before the media element existed.
  ///
  /// Once only per navigation: the bridge reports state every second, and
  /// re-issuing play() on each of those would fight a student who paused in
  /// the meantime.
  void _maybeReplayPlayIntent() {
    if (!_playWhenReady || _playIntentApplied) return;
    if (_durationValue <= Duration.zero) return;
    _playIntentApplied = true;
    unawaited(_runOnVideo('play()'));
  }

  /// A media element can report `ended` while the playhead is still minutes
  /// from the real end (a dropped HLS playlist does this). Resuming once from
  /// that position keeps a glitch from being mistaken for a finished lecture.
  void _onEnded() {
    final position = _positionValue;
    final duration = _durationValue;
    if (duration > Duration.zero && position < duration - _completionSlack) {
      if (_lastRecoveryAttemptPosition == position) {
        _emitCompleted();
        return;
      }
      _lastRecoveryAttemptPosition = position;
      projectLogger.w(
        'Bunny embed reported ended at ${position.inSeconds}s of '
        '${duration.inSeconds}s - resuming',
      );
      unawaited(() async {
        await seek(position);
        await play();
      }());
      return;
    }
    _emitCompleted();
  }

  void _emitCompleted() {
    if (_isCompleted) return;
    _isCompleted = true;
    if (!_completedCtrl.isClosed) _completedCtrl.add(true);
  }

  void _setPlaying(bool value) {
    _isPlaying = value;
    if (_playing.shouldEmit(value) && !_playingCtrl.isClosed) {
      _playingCtrl.add(value);
    }
  }

  void _setBuffering(bool value) {
    _isBuffering = value;
    if (_buffering.shouldEmit(value) && !_bufferingCtrl.isClosed) {
      _bufferingCtrl.add(value);
    }
  }

  void _emitError(String message) {
    _errorText = message;
    if (!_errorCtrl.isClosed) _errorCtrl.add(message);
  }

  void _startProbe() {
    _probeTimer?.cancel();
    _probeTimer = Timer.periodic(const Duration(seconds: 5), (_) => _probe());
  }

  /// Reads the media element directly when the bridge has gone quiet.
  ///
  /// This is the "timer fallback" half of the design: if the injected script
  /// never runs (CSP, a page change, a WebView2 quirk) playback state would
  /// otherwise freeze and the session tracker would stop counting. The probe
  /// asks the page instead of inventing an answer, so a paused student still
  /// reads as paused.
  Future<void> _probe() async {
    if (_isDisposed || !controller.value.isInitialized) return;
    if (!_pageSettled) return;
    final lastBridge = _lastBridgeAt;
    if (lastBridge != null &&
        DateTime.now().difference(lastBridge) < _bridgeSilenceThreshold) {
      return;
    }
    try {
      final result = await controller.executeScript(kProbeScript);
      if (_isDisposed || result is! Map) return;
      _applyState(
        position: _secondsToDuration(result['p']),
        duration: _secondsToDuration(result['d']),
        playing: result['playing'] == true,
        type: 'probe',
      );
    } catch (e) {
      projectLogger.d('Bunny webview probe failed: $e');
    }
  }

  /// Runs [body] against the page's `<video>` element.
  ///
  /// Commands go through `executeScript` rather than `postWebMessage` because
  /// the result is observable: a command that found no media returns `false`
  /// and is logged, instead of disappearing into an unlistened page event.
  ///
  /// Returns whether the media element was found, so callers can tell "the
  /// page refused" from "the page was not ready yet".
  Future<bool> _runOnVideo(String body) async {
    if (_isDisposed || !controller.value.isInitialized) return false;
    try {
      final found = await controller.executeScript(_commandScript(body));
      return found == true;
    } catch (e) {
      projectLogger.w('Bunny webview command "$body" failed: $e');
      return false;
    }
  }

  String _commandScript(String body) => '''
(function () {
  var v = $_kFindVideoExpr;
  if (!v) return false;
  try { $body; } catch (e) { return false; }
  return true;
})()
''';

  static Duration _secondsToDuration(dynamic value) {
    if (value is! num) return Duration.zero;
    final seconds = value.toDouble();
    if (seconds.isNaN || seconds.isInfinite || seconds <= 0) {
      return Duration.zero;
    }
    return Duration(milliseconds: (seconds * 1000).round());
  }

  /// Distinguishes a reported `false` from an absent flag, so a message that
  /// carries no playing state cannot be mistaken for "paused".
  static bool? _boolOrNull(dynamic value) {
    if (value == true) return true;
    if (value == false) return false;
    return null;
  }
}

/// Shared deep search for the media element.
///
/// The Bunny embed builds its player out of Media Chrome custom elements,
/// which keep the `<video>` inside an *open* shadow root. A plain
/// `document.querySelector('video')` therefore finds nothing, and the search
/// has to walk shadow roots.
const String _kFindVideoExpr = '''
(function find(root, depth) {
  try {
    if (depth > 8) return null;
    var direct = root.querySelector ? root.querySelector('video') : null;
    if (direct) return direct;
    var all = root.querySelectorAll ? root.querySelectorAll('*') : [];
    for (var i = 0; i < all.length; i++) {
      var shadow = all[i].shadowRoot;
      if (shadow) {
        var nested = find(shadow, depth + 1);
        if (nested) return nested;
      }
    }
  } catch (e) {}
  return null;
})(document, 0)
''';

/// Self-contained state snapshot, used by the Dart-side probe timer.
const String kProbeScript = '''
(function () {
  var v = $_kFindVideoExpr;
  if (!v) return null;
  return {
    p: v.currentTime || 0,
    d: (typeof v.duration === 'number' && isFinite(v.duration)) ? v.duration : 0,
    playing: !!(!v.paused && !v.ended)
  };
})()
''';

/// Bridge script injected into every document the webview creates.
///
/// It reports media state upward with `chrome.webview.postMessage` (or, from a
/// child frame, `parent.postMessage`, which the top document forwards). The
/// page carries no DRM and no nested advertising frames today; the frame
/// relay is kept because it costs a few lines and removes an entire class of
/// "the video moved into an iframe" breakage.
const String kBridgeScript = '''
(function () {
  if (window.__shobakiBridge) return;
  window.__shobakiBridge = true;

  var hasHost = !!(window.chrome && window.chrome.webview);
  var isTop = window === window.top;

  function post(msg) {
    msg.source = 'shobaki';
    try {
      if (hasHost) {
        window.chrome.webview.postMessage(msg);
      } else if (!isTop && window.parent) {
        window.parent.postMessage(msg, '*');
      }
    } catch (e) {}
  }

  // Top document: re-send anything a child frame reported, so one host
  // channel carries every frame's events.
  if (hasHost && isTop) {
    window.addEventListener('message', function (ev) {
      var data = ev.data;
      if (data && data.source === 'shobaki') {
        try { window.chrome.webview.postMessage(data); } catch (e) {}
      }
    });
  }

  function find(root, depth) {
    try {
      if (depth > 8) return null;
      var direct = root.querySelector ? root.querySelector('video') : null;
      if (direct) return direct;
      var all = root.querySelectorAll ? root.querySelectorAll('*') : [];
      for (var i = 0; i < all.length; i++) {
        var shadow = all[i].shadowRoot;
        if (shadow) {
          var nested = find(shadow, depth + 1);
          if (nested) return nested;
        }
      }
    } catch (e) {}
    return null;
  }

  var video = null;
  var lastTimePost = 0;
  var EVENTS = [
    'play', 'pause', 'ended', 'loadedmetadata', 'durationchange',
    'timeupdate', 'waiting', 'playing', 'canplay', 'error'
  ];

  function snapshot() {
    var duration = (video && isFinite(video.duration)) ? video.duration : 0;
    var position = video ? video.currentTime : 0;
    var playing = !!(video && !video.paused && !video.ended);
    return { p: position, d: duration, playing: playing };
  }

  function handlerFor(type) {
    return function () {
      if (type === 'timeupdate') {
        var now = Date.now();
        // Once a second is plenty for the session tracker and keeps the
        // message channel from drowning in events.
        if (now - lastTimePost < 1000) return;
        lastTimePost = now;
      }
      var msg = snapshot();
      msg.e = type;
      if (type === 'error' && video && video.error) msg.code = video.error.code;
      post(msg);
    };
  }

  var handlers = EVENTS.map(handlerFor);

  function detach() {
    if (!video) return;
    for (var i = 0; i < EVENTS.length; i++) {
      video.removeEventListener(EVENTS[i], handlers[i]);
    }
    video = null;
  }

  function attach(next) {
    if (video === next) return;
    detach();
    video = next;
    if (!video) return;
    for (var i = 0; i < EVENTS.length; i++) {
      video.addEventListener(EVENTS[i], handlers[i]);
    }
    post(snapshot());
  }

  function scan() {
    attach(find(document, 0));
  }

  scan();
  // The embed mounts its player after the document parses, and may rebuild it
  // on a source change, so keep looking rather than trusting one early scan.
  setInterval(scan, 1000);
  setInterval(function () {
    if (video) {
      var msg = snapshot();
      msg.e = 'hb';
      post(msg);
    }
  }, 5000);
})()
''';
