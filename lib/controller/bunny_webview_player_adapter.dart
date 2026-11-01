import 'dart:async';
import 'dart:convert' show jsonDecode;
import 'dart:io' show Directory, Platform;

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart'
    hide WebResourceError, WebResourceRequest, WebResourceErrorType;
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';
import 'package:zikzak_inappwebview/zikzak_inappwebview.dart'
    show InAppWebViewController, NavigationAction, NavigationActionPolicy,
        URLRequest, WebResourceError, WebResourceErrorType,
        WebResourceRequest, WebUri;

import 'package:shobaki_academy/controller/bunny_embed.dart';
import 'package:shobaki_academy/controller/player_adapter.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/services/value_deduplicator.dart';

/// Name of the JavaScript channel the page uses to reach the app.
///
/// Android/iOS: the official plugin's `addJavaScriptChannel` wrapper.
/// macOS: the same string is the zikzak `addJavaScriptHandler` name, which
/// the page calls through `window.zikzak_inappwebview.callHandler`.
/// Windows has no channel: WebView2's `chrome.webview`
/// object already carries messages, and [kBridgeScript] picks whichever host
/// transport the document actually has.
const String kBunnyBridgeChannel = 'BunnyBridge';

/// Name of the state self-read helper [kBridgeScript] exports on `window`.
///
/// The probe fires it through a void `runJavaScript` (whose `undefined`
/// return WebKit explicitly tolerates) and the answer travels back as an
/// ordinary `e='probe'` bridge message, so reading the page never depends
/// on the plugin marshalling a script *result* across the platform channel.
const String kBunnyProbeExport = 'window.__shobakiProbe';

/// Whether [url] is a destination the embed page may navigate the top frame to.
///
/// Mirrors the Windows `deny` popup policy: the student stays on Bunny's own
/// surfaces (`player.mediadelivery.net` and the `b-cdn.net` CDN the embed may
/// jump to) and nothing else can take over the player on Android/iOS/macOS.
/// The app never issues a main-frame request outside that list, so this also
/// guards the platform-side `loadRequest` itself.
bool isAllowedBunnyNavigation(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (uri.scheme == 'about') return true;
  if (uri.scheme != 'https') return false;
  final host = uri.host.toLowerCase();
  return host.endsWith('.mediadelivery.net') ||
      host == 'b-cdn.net' ||
      host.endsWith('.b-cdn.net') ||
      host.endsWith('.bunnycdn.com');
}

/// Whether a web resource failure actually killed the embed load.
///
/// Only a confirmed main-frame failure means the page itself is gone. WebKit
/// frequently leaves [isForMainFrame] null (it cannot always attribute the
/// error to a frame), and it reports -999 whenever a navigation is cancelled
/// by another navigation starting - both arrive while the page is perfectly
/// alive, so neither may burn a load attempt or dead-end into the error UI.
bool isFatalBunnyResourceError({
  required bool? isForMainFrame,
  required int errorCode,
}) {
  if (isForMainFrame != true) return false;
  return errorCode != -999;
}

/// Decides whether one probe tick may read the page.
///
/// `force` (the app returning to the foreground) always probes: the
/// controller re-syncs `SessionTracker` from `isPlaying` immediately, and
/// the cached flag may predate whatever the webview did while backgrounded.
/// Otherwise the page must look settled - the navigation callback
/// confirmed it - and the bridge must have been silent for
/// [silenceThreshold], so a healthy push channel is never raced by a
/// redundant read.
bool shouldRunProbe({
  required bool pageSettled,
  required bool force,
  required DateTime? lastBridgeAt,
  required DateTime now,
  Duration silenceThreshold = const Duration(seconds: 8),
}) {
  if (force) return true;
  if (!pageSettled) return false;
  final bridge = lastBridgeAt;
  if (bridge != null && now.difference(bridge) < silenceThreshold) return false;
  return true;
}

/// Decodes the raw result of a script executed inside the embed page.
///
/// The transports hand the same JavaScript value back in different shapes:
/// WebView2's `ExecuteScript` and WKWebView return parsed values (Map, bool,
/// null), while Android's `evaluateJavascript` returns the JSON text it
/// captured - an object arrives as a JSON String, and a JavaScript String
/// arrives double-encoded. Strings are decoded at most twice, so a
/// double-encoded value collapses back to the object while a plain payload
/// survives unchanged.
dynamic asScriptValue(dynamic raw) {
  var value = raw;
  for (var i = 0; i < 2 && value is String; i++) {
    try {
      value = jsonDecode(value);
    } catch (_) {
      // Not JSON: Android's plugin falls back to the raw text for anything
      // it could not parse, so hand it back as-is.
      break;
    }
  }
  return value;
}

/// The media snapshot from [kProbeScript] or a bridge message, or null when
/// the transport returned something this shape cannot describe.
Map<String, dynamic>? asScriptMap(dynamic raw) {
  final value = asScriptValue(raw);
  return value is Map ? value.cast<String, dynamic>() : null;
}

/// A script's boolean answer (`false` = no media element found), tolerant of
/// every encoding the transports use for it.
bool? asScriptBool(dynamic raw) {
  final value = asScriptValue(raw);
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return null;
}

/// Whether the shared WebView2 environment has already been pointed at a
/// writable user-data folder.
///
/// The environment is shared by every controller in the process, so this is
/// configured once rather than per adapter. Windows-only: the official
/// plugin on Android/iOS/macOS has no equivalent.
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
/// in-app WebView.
///
/// The embed page is a normal document, so every interaction with the media
/// goes through JavaScript: events arrive as message payloads from an injected
/// bridge script, and commands are pushed back in as executed scripts. That is
/// deliberately different from the native adapters, where the platform hands
/// us position/duration for free.
///
/// Three hosts carry that traffic:
///
/// - **Windows** uses the WebView2 fork (`webview_flutter_windows`), which
///   composites its content as a Flutter `Texture` - the watermark overlay
///   painted in `main.dart` keeps covering the video - and injects the bridge
///   with `addScriptToExecuteOnDocumentCreated`, before the page runs a line.
/// - **macOS** uses `zikzak_inappwebview` (WKWebView). The bridge goes in
///   through `initialUserScripts` - the same per-document injection Windows
///   has - and messages travel over a `BunnyBridge` JavaScript handler. The
///   official `webview_flutter` macOS host is gone: its controller threw on
///   background-color wiring and never implemented dispose, which leaked
///   audio past the page.
/// - **Android/iOS** use the official `webview_flutter` plugin (system
///   WebView / WKWebView). It has no per-document injection, so the bridge is
///   injected from `onPageStarted`/`onPageFinished` (the script self-heals:
///   it scans for the media element immediately and every second), and
///   messages travel over a `BunnyBridge` JavaScript channel instead of
///   `chrome.webview`.
///
/// On iOS the official controller is built with inline playback enabled and
/// no user-gesture requirement: without the first, WKWebView ejects the video
/// into a native fullscreen player that escapes the watermark; without the
/// second, a programmatic `play()` (resume intent, `ended` recovery) is
/// refused because it is not a user gesture. Android gets the matching
/// `setMediaPlaybackRequiresUserGesture(false)`. macOS carries both flags
/// through the zikzak `InAppWebViewSettings`.
///
/// The page is loaded from the raw CDN playlist URL the DB stores: [open]
/// maps it to the embed player itself, so callers never have to know about
/// `player.mediadelivery.net`.
class BunnyWebviewPlayerAdapter implements IPlayerAdapter {
  BunnyWebviewPlayerAdapter({required int bunnyLibraryId})
      : _libraryId = bunnyLibraryId,
        _isZikzakHost = Platform.isMacOS,
        _win = Platform.isWindows ? WebviewController() : null,
        _web = (Platform.isAndroid || Platform.isIOS)
            ? _newWebViewController()
            : null {
    projectLogger.i(
      'Bunny adapter created (libraryId=$_libraryId, '
      'platform=${Platform.operatingSystem}, host=${_hostName()})',
    );
  }

  String _hostName() {
    if (_win != null) return 'WebView2';
    if (_isZikzakHost) return 'zikzak-inappwebview';
    return 'webview_flutter';
  }

  /// Bunny Stream library the video belongs to, from the owning topic's
  /// `library_id`. Required: the embed URL cannot be built without it, and
  /// the controller refuses to construct this adapter when it is missing.
  final int _libraryId;

  /// The WebView2 surface. Non-null on Windows only; the view mounts it as a
  /// texture under the watermark overlay.
  final WebviewController? _win;

  /// The official webview_flutter surface. Non-null on Android/iOS only;
  /// the view mounts it as a platform view.
  final WebViewController? _web;

  /// Whether this adapter hosts the embed through `zikzak_inappwebview`
  /// (macOS only). The view checks it to mount the matching widget.
  final bool _isZikzakHost;

  /// The zikzak macOS controller. Null until the view's `InAppWebView` is
  /// created; [attachMac] wires it, and a load handed to [open] before that
  /// waits in [_macPendingUrl].
  InAppWebViewController? _mac;

  /// Embed URL handed to [open] before the macOS view mounted.
  String? _macPendingUrl;

  /// Builds the official platform webview controller (iOS only; macOS runs
  /// zikzak, Android gets its gesture flag in [_ensureWired]).
  static WebViewController _newWebViewController() {
    return WebViewController.fromPlatformCreationParams(
      WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      ),
    );
  }

  /// The WebView2 controller, when this adapter runs on Windows. The view
  /// mounts it; nothing else needs it.
  WebviewController? get windowsController => _win;

  /// The official-plugin controller, when this adapter runs on Android/iOS.
  /// The view mounts it; nothing else needs it.
  WebViewController? get webController => _web;

  /// True while this adapter hosts the embed through `zikzak_inappwebview`
  /// (macOS). The view uses it to pick the widget branch.
  bool get isZikzakHost => _isZikzakHost;

  /// The zikzak controller once the macOS view has mounted; null before.
  InAppWebViewController? get inAppController => _mac;

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

  /// Whether the current navigation has settled (its load-finished callback
  /// arrived on the host that reports it). [shouldRunProbe] gates on it so a
  /// probe never reads a half-loaded page; a callback that never arrives
  /// shows up as a stuck gate in the navigation logs.
  bool _pageSettled = false;

  /// Whether any bridge message has been received since [open]; makes the
  /// "first message proves the transport" diagnostic log happen once per
  /// navigation instead of spamming.
  bool _bridgeSeen = false;

  /// Last probe outcome that was logged, so the diagnostic line only
  /// appears when something actually changed.
  String? _lastProbeSummary;

  /// Last bridge-injection error text, used to log a failure once per
  /// distinct problem instead of once per self-heal attempt.
  String? _lastInjectionError;

  /// True after the first `Media ONLINE` milestone of the current
  /// navigation, so the log stays one line per load instead of per message.
  bool _mediaOnlineSeen = false;

  /// When the last heartbeat receipt was logged; keeps the 5s heartbeat from
  /// drowning the log (30s sampling is enough to time-stamp liveness).
  DateTime? _lastHeartbeatLogAt;

  /// When the last probe failure was logged (throttle for the noisy
  /// "no media element yet" window while the embed boots).
  DateTime? _lastProbeFailLog;

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
  ///
  /// Windows-only: WebView2 reports the element's fullscreen state, while the
  /// official plugin has no such callback - on Android/iOS/macOS the embed's
  /// own fullscreen runs inside the platform webview instead, so there is no
  /// window state to keep in sync.
  Stream<bool> get onFullScreenChanged =>
      _win?.containsFullScreenElementChanged ?? Stream<bool>.empty();

  @override
  Future<void> open(String url, {Duration? start}) async {
    if (_isDisposed) return;

    final embedUrl = tryBuildBunnyEmbedUrl(url, libraryId: _libraryId) ??
        (isBunnyEmbedUrl(url) ? url : null);
    if (embedUrl == null) {
      throw StateError('Not an embeddable Bunny Stream URL: $url');
    }
    projectLogger.i(
      'Bunny embed open: $embedUrl (start=${start?.inSeconds ?? 0}s)',
    );

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
    _bridgeSeen = false;
    _mediaOnlineSeen = false;
    _lastProbeSummary = null;
    _lastBridgeAt = null;
    _lastRecoveryAttemptPosition = null;

    await _ensureWired();
    final win = _win;
    if (win != null) {
      await win.loadUrl(embedUrl);
    } else if (_isZikzakHost) {
      final mac = _mac;
      if (mac != null) {
        await mac.loadUrl(urlRequest: URLRequest(url: WebUri(embedUrl)));
      } else {
        // The view has not mounted yet; attachMac flushes this the moment
        // the controller exists.
        _macPendingUrl = embedUrl;
      }
    } else {
      await _web!.loadRequest(Uri.parse(embedUrl));
    }
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
    await _win?.dispose();
    final mac = _mac;
    if (mac != null) {
      // Real native teardown - unlike the official plugin's no-op surface,
      // disposing the zikzak controller destroys the WKWebView, so the
      // embed's audio dies with it instead of surviving in the background.
      try {
        await mac.evaluateJavascript(source: _commandScript('pause()'));
      } catch (_) {}
      try {
        await mac.evaluateJavascript(source: 'location.href = "about:blank";');
      } catch (_) {}
      try {
        mac.dispose();
      } catch (e) {
        projectLogger.w('Bunny webview dispose failed: $e');
      }
      _mac = null;
      _macPendingUrl = null;
    }
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
  /// the load, otherwise the early lifecycle events of the embed page would be
  /// lost.
  Future<void> _ensureWired() async {
    if (_win != null) {
      await _ensureWiredWindows();
      return;
    }
    // macOS: the zikzak host wires in attachMac when the view mounts, which
    // always precedes the first load flush; there is nothing to do here.
    if (_isZikzakHost) return;
    if (_wired) return;
    _wired = true;
    await _ensureWiredOfficial();
    _isInitialized = true;
  }

  /// Windows wiring: WebView2 environment, popup deny policy, and the
  /// per-document script injection the fork provides.
  Future<void> _ensureWiredWindows() async {
    final win = _win!;
    await _configureWebViewEnvironment();
    if (!win.value.isInitialized) {
      await win.initialize();
    }
    if (_wired) return;
    _wired = true;

    await win.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    await win.setBackgroundColor(const Color(0xFF000000));
    // The embed page is a plain media player: DevTools and its context menu
    // would only be a detour (and a screenshot surface) for the student.
    await win.setDevToolsEnabled(false);
    await win.setDefaultContextMenusEnabled(false);
    await win.addScriptToExecuteOnDocumentCreated(kBridgeScript);

    _messageSub = win.webMessage.listen(_onBridgeMessage);
    _loadingSub = win.loadingState.listen(_onLoadingStateChanged);
    _loadErrorSub = win.onLoadError.listen((status) {
      _emitError('تعذر تحميل صفحة المشغّل (${status.name})');
    });
    projectLogger.d('Bunny webview wired (WebView2 host)');

    _isInitialized = true;
  }

  /// Android/iOS wiring: JS channel, navigation policy, and the autoplay
  /// flags that keep programmatic `play()` and inline rendering working on
  /// the platform webviews.
  Future<void> _ensureWiredOfficial() async {
    final web = _web!;
    await web.setJavaScriptMode(JavaScriptMode.unrestricted);
    await web.setBackgroundColor(const Color(0xFF000000));
    await web.addJavaScriptChannel(
      kBunnyBridgeChannel,
      onMessageReceived: (message) => _onBridgeMessage(message.message),
    );
    await web.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          if (_isDisposed) return;
          projectLogger.i('Bunny webview navigation started: $url');
          // A (re)navigation is in flight: the previous document's media is
          // gone, so the probe must wait for the new one to settle. There is
          // no per-document injection API here, so the bridge goes in now -
          // it scans for the media element itself and repeats every second.
          _pageSettled = false;
          unawaited(_injectBridge());
        },
        onPageFinished: (url) {
          if (_isDisposed) return;
          projectLogger.i('Bunny webview navigation finished: $url');
          _pageSettled = true;
          // Backstop for the `onPageStarted` injection: if that run raced
          // the document, this one lands on a parsed page. The script's own
          // `__shobakiBridge` guard makes a double run a no-op.
          unawaited(_injectBridge());
        },
        onWebResourceError: (error) {
          if (_isDisposed) return;
          // Android reports subresource failures through this callback too;
          // only a fatal main-frame failure means the page itself did not
          // load. WebKit's ambiguous cases (null attribution, cancelled
          // navigation) are logged and survivable by design.
          if (error.isForMainFrame == false) return;
          final fatal = isFatalBunnyResourceError(
            isForMainFrame: error.isForMainFrame,
            errorCode: error.errorCode,
          );
          projectLogger.w(
            'Bunny webview resource error: ${error.errorCode} '
            '(main=${error.isForMainFrame}, fatal=$fatal)',
          );
          if (!fatal) return;
          _emitError('تعذر تحميل صفحة المشغّل (${error.errorCode})');
        },
        onNavigationRequest: (request) {
          // Subframe loads (the embed's own assets) are never a takeover;
          // the top frame may only move between Bunny surfaces.
          if (!request.isMainFrame) return NavigationDecision.navigate;
          if (!isAllowedBunnyNavigation(request.url)) {
            // A blocked takeover is one of the most actionable diagnostic
            // events this adapter can report: whatever the page asked for,
            // the student is still on Bunny's surface because of this line.
            projectLogger.w('Bunny navigation prevented: ${request.url}');
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ),
    );
    final platformController = web.platform;
    if (platformController is AndroidWebViewController) {
      await platformController.setMediaPlaybackRequiresUserGesture(false);
    }
    projectLogger.d('Bunny webview wired (official plugin host)');
  }

  /// Wires the zikzak macOS webview when the view mounts it.
  ///
  /// The package hands the controller out through the widget's
  /// `onWebViewCreated` (there is no pre-mount controller API), so this runs
  /// exactly where [_ensureWiredWindows] runs for Windows: before any load,
  /// registering the JS handler first, then flushing a URL that [open] handed
  /// over before the mount.
  void attachMac(InAppWebViewController controller) {
    if (_isDisposed) return;
    _mac = controller;
    controller.addJavaScriptHandler(
      handlerName: kBunnyBridgeChannel,
      callback: (args) => _onBridgeMessage(args.isNotEmpty ? args[0] : null),
    );
    _wired = true;
    _isInitialized = true;
    projectLogger.i('Bunny webview wired (zikzak inappwebview macOS host)');
    final pending = _macPendingUrl;
    if (pending != null) {
      _macPendingUrl = null;
      unawaited(() async {
        try {
          await controller.loadUrl(
            urlRequest: URLRequest(url: WebUri(pending)),
          );
        } catch (e) {
          projectLogger.e('Bunny webview pending load failed: $e');
          _emitError('تعذر تحميل صفحة المشغّل');
        }
      }());
    }
  }

  /// Load-start callback forwarded from the zikzak widget: logs the
  /// navigation and re-arms the probe gate. Injection is not needed here -
  /// `initialUserScripts` installs [kBridgeScript] per document, the same
  /// way Windows does.
  void onMacLoadStart(String url) {
    if (_isDisposed) return;
    projectLogger.i('Bunny webview navigation started: $url');
    _pageSettled = false;
  }

  /// Load-finished callback forwarded from the zikzak widget: logs the
  /// navigation and opens the probe gate.
  void onMacLoadStop(String url) {
    if (_isDisposed) return;
    projectLogger.i('Bunny webview navigation finished: $url');
    _pageSettled = true;
  }

  /// Load-error callback forwarded from the zikzak widget. The 5.x entity
  /// model carries a typed error instead of an NSError code, so the
  /// cancelled-navigation case is mapped onto the -999 sentinel the shared
  /// [isFatalBunnyResourceError] filter knows; frame attribution comes from
  /// the request, which WebKit may leave null.
  void onMacReceivedError(WebResourceRequest request, WebResourceError error) {
    if (_isDisposed) return;
    final fatal = isFatalBunnyResourceError(
      isForMainFrame: request.isForMainFrame,
      errorCode: error.type == WebResourceErrorType.CANCELLED ? -999 : 1,
    );
    projectLogger.w(
      'Bunny webview load error: ${error.type} ${error.description} '
      '(fatal=$fatal)',
    );
    if (!fatal) return;
    _emitError('تعذر تحميل صفحة المشغّل');
  }

  /// Navigation policy forwarded from the zikzak widget: subframes (the
  /// embed's own assets) always load; the top frame may only move between
  /// Bunny surfaces, mirroring the Windows deny-popup policy and the
  /// official plugin's `onNavigationRequest`.
  Future<NavigationActionPolicy> onMacShouldOverrideUrlLoading(
    NavigationAction action,
  ) async {
    if (action.isForMainFrame != true) return NavigationActionPolicy.ALLOW;
    final url = action.request.url?.toString() ?? '';
    if (isAllowedBunnyNavigation(url)) return NavigationActionPolicy.ALLOW;
    // A blocked takeover is one of the most actionable diagnostic events
    // this adapter can report: whatever the page asked for, the student is
    // still on Bunny's surface because of this line.
    projectLogger.w('Bunny navigation prevented: $url');
    return NavigationActionPolicy.CANCEL;
  }

  /// Installs [kBridgeScript] in the current document.
  ///
  /// Windows and macOS get the script per document before any page code runs
  /// (`addScriptToExecuteOnDocumentCreated` / `initialUserScripts`); this is
  /// the official-plugin path for Android/iOS, and also runs from the probe
  /// timer while the bridge stays silent, so a missed `didFinish` (or a
  /// document replaced without a callback) heals itself within one probe
  /// interval instead of stranding the player. The script's own
  /// `__shobakiBridge` guard makes a repeat a no-op.
  Future<void> _injectBridge() async {
    if (_isDisposed) return;
    try {
      final mac = _mac;
      if (mac != null) {
        await mac.evaluateJavascript(source: kBridgeScript);
      } else {
        final web = _web;
        if (web == null) return;
        await web.runJavaScript(kBridgeScript);
      }
      if (_lastInjectionError != null) {
        _lastInjectionError = null;
        projectLogger.i('Bunny bridge injection recovered');
      }
    } catch (e) {
      // The self-heal path retries every probe tick; log only a new error
      // so a persistent failure does not bury the log with identical lines.
      final text = e.toString();
      if (text != _lastInjectionError) {
        _lastInjectionError = text;
        projectLogger.w('Bunny bridge injection failed: $text');
      }
    }
  }

  void _onLoadingStateChanged(LoadingState state) {
    if (_isDisposed) return;
    projectLogger.d('Bunny webview (windows) loading state: $state');
    if (state == LoadingState.navigationCompleted) {
      _pageSettled = true;
    } else if (state == LoadingState.loading) {
      // A (re)navigation is in flight: the previous document's media is gone,
      // so the probe must wait for the new one to settle.
      _pageSettled = false;
    }
  }

  /// Accepts both transports' payload shapes: the fork delivers a parsed
  /// Map, the official plugin a JSON String through its channel.
  void _onBridgeMessage(dynamic raw) {
    if (_isDisposed) return;
    final msg = asScriptMap(raw);
    if (msg == null || msg['source'] != 'shobaki') return;

    _lastBridgeAt = DateTime.now();
    final type = msg['e'] as String? ?? '';
    if (!_bridgeSeen) {
      _bridgeSeen = true;
      projectLogger.i(
        'Bunny bridge alive: e=$type d=${msg['d']} p=${msg['p']} '
        'playing=${msg['playing']}',
      );
    }
    if (type == 'hb') {
      final now = DateTime.now();
      if (_lastHeartbeatLogAt == null ||
          now.difference(_lastHeartbeatLogAt!) >= const Duration(seconds: 30)) {
        _lastHeartbeatLogAt = now;
        projectLogger.d(
          'Bunny heartbeat: d=${msg['d']} p=${msg['p']} '
          'playing=${msg['playing']}',
        );
      }
    }

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
      if (!_mediaOnlineSeen) {
        _mediaOnlineSeen = true;
        projectLogger.i(
          'Bunny media ONLINE: d=${duration.inSeconds}s via $type',
        );
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
  /// never runs (CSP, a page change, a webview quirk, a navigation callback
  /// that never arrives) playback state would otherwise freeze and the
  /// session tracker would stop counting. The probe asks the page instead of
  /// inventing an answer, so a paused student still reads as paused.
  ///
  /// On the official plugin each tick also re-injects the bridge while it is
  /// silent ([_injectBridge] is a no-op when the script is already present)
  /// and fires [kBunnyProbeExport] so the answer can arrive over the channel
  /// too - that path only needs a void `runJavaScript`, the most reliable
  /// call the plugin has, instead of a result-marshalling one.
  ///
  /// [force] skips every gate (settle and silence); the controller uses it
  /// when the app returns to the foreground, where `SessionTracker` re-syncs
  /// from [isPlaying] immediately and the cached flag may predate whatever
  /// the platform webview did to the page while backgrounded.
  Future<void> _probe({bool force = false}) async {
    if (_isDisposed) return;
    final win = _win;
    if (win != null && !win.value.isInitialized) return;
    if (_web == null && win == null && _mac == null) return;
    if (!shouldRunProbe(
      pageSettled: _pageSettled,
      force: force,
      lastBridgeAt: _lastBridgeAt,
      now: DateTime.now(),
      silenceThreshold: _bridgeSilenceThreshold,
    )) {
      return;
    }
    if (win == null) {
      // Self-heal first: the push below is only useful once the bridge
      // script exists in the current document, and a probe that is running
      // at all means the bridge has been silent (or never phoned home) -
      // exactly what a missed navigation callback or an unloaded document
      // looks like. The script's own guard makes the repeat a no-op.
      await _injectBridge();
      unawaited(_pushProbe());
    }
    try {
      final dynamic result;
      final mac = _mac;
      if (win != null) {
        result = await win.executeScript(kProbeScript);
      } else if (mac != null) {
        result = await mac.evaluateJavascript(source: kProbeScript);
      } else {
        result = await _web!.runJavaScriptReturningResult(kProbeScript);
      }
      if (_isDisposed) return;
      final snapshot = asScriptMap(result);
      if (snapshot == null) return;
      _logProbeOutcome(snapshot);
      // A page without a media element still produces a snapshot (it carries
      // the iframe count for diagnostics) but must not be folded into the
      // state: a missing `playing` flag would read as "paused".
      if (snapshot['found'] != true) return;
      _applyState(
        position: _secondsToDuration(snapshot['p']),
        duration: _secondsToDuration(snapshot['d']),
        playing: snapshot['playing'] == true,
        type: 'probe',
      );
    } catch (e) {
      // WebKit throws `ArgumentError` whenever the script answers `null`
      // (no media element yet) - that is the normal boot window, not a
      // transport failure, so it is logged at debug and rate-limited.
      final now = DateTime.now();
      if (_lastProbeFailLog == null ||
          now.difference(_lastProbeFailLog!) >= const Duration(seconds: 30)) {
        _lastProbeFailLog = now;
        projectLogger.d('Bunny webview probe failed: $e');
      }
    }
  }

  /// Asks the page to push its own state over the bridge channel.
  ///
  /// Complements the evaluate-and-return probe: this needs only a void
  /// `runJavaScript` (whose undefined return WebKit explicitly tolerates)
  /// plus the channel the wrapper user script installs, where the direct
  /// probe needs `runJavaScriptReturningResult` to marshal an object back.
  /// The message arrives as a normal `e='probe'` bridge event, which
  /// [_onBridgeMessage] already folds into [_applyState].
  Future<void> _pushProbe() async {
    if (_isDisposed) return;
    try {
      final mac = _mac;
      if (mac != null) {
        await mac.evaluateJavascript(
          source: '$kBunnyProbeExport && $kBunnyProbeExport();',
        );
      } else {
        final web = _web;
        if (web == null) return;
        await web.runJavaScript('$kBunnyProbeExport && $kBunnyProbeExport();');
      }
    } catch (e) {
      projectLogger.d('Bunny webview push-probe failed: $e');
    }
  }

  /// Logs the probe outcome when it changes (video presence, iframe count,
  /// whether a duration is known) - the fields that identify which link of
  /// the pipeline is broken, without a line per tick.
  void _logProbeOutcome(Map<String, dynamic> snapshot) {
    final video = snapshot['found'] == true;
    final iframes = snapshot['ifr'];
    final hasDuration = _secondsToDuration(snapshot['d']) > Duration.zero;
    final summary = 'video=$video ifr=$iframes duration=$hasDuration';
    if (summary == _lastProbeSummary) return;
    _lastProbeSummary = summary;
    projectLogger.i('Bunny webview probe: $summary');
  }

  /// Probes the media element immediately, ignoring the bridge-silence gate.
  ///
  /// Called when the app returns to the foreground so the play state feeding
  /// `SessionTracker` reflects the page as it is *now*, not as it was before
  /// the platform webview was backgrounded.
  Future<void> probeNow() => _probe(force: true);

  /// Runs [body] against the page's `<video>` element.
  ///
  /// Commands go through a script execution rather than a message to the page
  /// because the result is observable: a command that found no media returns
  /// `false` and is logged, instead of disappearing into an unlistened page
  /// event.
  ///
  /// Returns whether the media element was found, so callers can tell "the
  /// page refused" from "the page was not ready yet".
  Future<bool> _runOnVideo(String body) async {
    if (_isDisposed) return false;
    try {
      final dynamic result;
      final win = _win;
      if (win != null) {
        if (!win.value.isInitialized) return false;
        result = await win.executeScript(_commandScript(body));
      } else {
        final mac = _mac;
        if (mac != null) {
          result = await mac.evaluateJavascript(source: _commandScript(body));
        } else {
          result =
              await _web!.runJavaScriptReturningResult(_commandScript(body));
        }
      }
      return asScriptBool(result) ?? false;
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
///
/// Returns an object rather than JSON text: WebView2 and WKWebView hand
/// parsed values straight back, Android's `evaluateJavascript` returns the
/// JSON text, and [asScriptMap] folds both into the same map. The answer is
/// always an object (even with no media element) so WebKit's
/// "null result" `ArgumentError` never fires and the iframe count stays
/// available as a diagnostic.
const String kProbeScript = '''
(function () {
  var v = $_kFindVideoExpr;
  var out = { found: !!v, ifr: document.querySelectorAll('iframe').length };
  if (!v) return out;
  out.p = v.currentTime || 0;
  out.d = (typeof v.duration === 'number' && isFinite(v.duration)) ? v.duration : 0;
  out.playing = !!(!v.paused && !v.ended);
  return out;
})()
''';

/// Bridge script injected into every document the webview creates.
///
/// It reports media state upward over whichever host transport the document
/// has: `chrome.webview.postMessage` on Windows,
/// `window.zikzak_inappwebview.callHandler` on macOS, the
/// [kBunnyBridgeChannel] JavaScript channel on Android/iOS (a JSON string,
/// because the channel only carries strings), or `parent.postMessage` from a
/// child frame, which the top document forwards over its own host channel.
/// The frame relay is kept because it costs a few lines and removes an
/// entire class of "the video moved into an iframe" breakage.
///
/// Windows and macOS install the script per document before any page code
/// runs (`addScriptToExecuteOnDocumentCreated` / `initialUserScripts`). The
/// official plugin has no such API, so on Android/iOS the script is injected
/// from `onPageStarted` (and again from `onPageFinished` as a backstop),
/// with the Dart probe timer re-injecting while the bridge stays silent. The
/// `__shobakiBridge` guard makes a repeated run a no-op, the immediate scan
/// plus the repeating scan below mean a slightly late injection still
/// attaches to the media element, and the [kBunnyProbeExport] helper lets
/// the Dart side read state back through a void script execution when
/// evaluating a script *result* is unreliable.
const String kBridgeScript = '''
(function () {
  if (window.__shobakiBridge) return;
  window.__shobakiBridge = true;

  var isTop = window === window.top;

  // Transports are probed per message rather than cached at script start:
  // the channel wrapper user script and the host object can appear after
  // this script first ran, and a cached "no transport" would silently drop
  // every message for the life of the document.
  function send(data) {
    if (window.chrome && window.chrome.webview) {
      window.chrome.webview.postMessage(data);
      return true;
    }
    if (window.zikzak_inappwebview && window.zikzak_inappwebview.callHandler) {
      try {
        window.zikzak_inappwebview.callHandler('BunnyBridge', JSON.stringify(data));
        return true;
      } catch (e) {}
    }
    if (window.BunnyBridge) {
      window.BunnyBridge.postMessage(JSON.stringify(data));
      return true;
    }
    return false;
  }

  function post(msg) {
    msg.source = 'shobaki';
    try {
      if (!send(msg) && !isTop && window.parent) {
        window.parent.postMessage(msg, '*');
      }
    } catch (e) {}
  }

  // Top document: re-send anything a child frame reported, so one host
  // channel carries every frame's events. Registered unconditionally, for
  // the same reason the transport check above is lazy.
  if (isTop) {
    window.addEventListener('message', function (ev) {
      var data = ev.data;
      if (data && data.source === 'shobaki') {
        try { send(data); } catch (e) {}
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

  // Proactive state read, fired by the Dart probe timer through a void
  // runJavaScript so a page whose push events are silent can still answer
  // - the reply rides back over the same channel as a normal message.
  window.__shobakiProbe = function () {
    if (!video) scan();
    if (!video) return false;
    var msg = snapshot();
    msg.e = 'probe';
    post(msg);
    return true;
  };

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
