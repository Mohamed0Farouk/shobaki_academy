import 'dart:async';
import 'dart:collection' show UnmodifiableListView;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart' show WebViewWidget;
import 'package:webview_flutter_windows/webview_flutter_windows.dart'
    show Webview, WebviewValue;
import 'package:window_manager/window_manager.dart';
import 'package:zikzak_inappwebview/zikzak_inappwebview.dart'
    show InAppWebView, InAppWebViewSettings, UserScript,
        UserScriptInjectionTime;

import 'package:shobaki_academy/controller/bunny_webview_player_adapter.dart';
import 'package:shobaki_academy/controller/video_playback_controller.dart';

/// Hosts the Bunny embed webview inside the normal player page.
///
/// On Windows the fork's [Webview] renders an empty box until its controller
/// has finished initializing, and the page's own loading spinner (driven by
/// `ctrl.isLoading`) covers that gap, so no extra state machine is needed
/// here. macOS mounts the zikzak `InAppWebView` against the adapter's
/// controller with the same loading overlay; Android/iOS mount the official
/// [WebViewWidget].
class BunnyWebviewPlayer extends StatefulWidget {
  const BunnyWebviewPlayer({
    super.key,
    required this.adapter,
    required this.ctrl,
  });

  final BunnyWebviewPlayerAdapter adapter;
  final VideoPlaybackController ctrl;

  @override
  State<BunnyWebviewPlayer> createState() => _BunnyWebviewPlayerState();
}

class _BunnyWebviewPlayerState extends State<BunnyWebviewPlayer> {
  StreamSubscription<bool>? _fullScreenSub;

  @override
  void initState() {
    super.initState();
    // The embed's own fullscreen button calls requestFullscreen on the media
    // element. WebView2 reports that here; driving the real window from it
    // keeps the two fullscreen states from drifting apart. On Android/iOS/
    // macOS the stream never fires (see the adapter): the platform webview
    // owns its own fullscreen surface.
    _fullScreenSub =
        widget.adapter.onFullScreenChanged.listen(_onFullScreenElement);
  }

  void _onFullScreenElement(bool fullScreen) {
    if (!mounted) return;
    if (widget.ctrl.isFullScreen.value == fullScreen) return;
    widget.ctrl.isFullScreen.value = fullScreen;
    if (Platform.isWindows) unawaited(_setWindowFullScreen(fullScreen));
  }

  Future<void> _setWindowFullScreen(bool fullScreen) async {
    try {
      await windowManager.setFullScreen(fullScreen);
    } catch (_) {
      // The OS refused; roll the in-app state back so the AppBar/FAB stay
      // consistent with what the student can actually see.
      if (mounted) widget.ctrl.isFullScreen.value = !fullScreen;
    }
  }

  @override
  void dispose() {
    _fullScreenSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.adapter.isZikzakHost) {
      // macOS: the bridge script rides in as a per-document user script -
      // the same injection point the WebView2 fork uses - and the four
      // navigation callbacks forward into the adapter, where the shared
      // allowlist/settle/error logic already lives.
      return InAppWebView(
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          allowsInlineMediaPlayback: true,
          mediaPlaybackRequiresUserGesture: false,
          useShouldOverrideUrlLoading: true,
          disableContextMenu: true,
          supportZoom: false,
        ),
        initialUserScripts: UnmodifiableListView<UserScript>([
          UserScript(
            source: kBridgeScript,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          ),
        ]),
        onWebViewCreated: (controller) =>
            widget.adapter.attachMac(controller),
        onLoadStart: (controller, url) =>
            widget.adapter.onMacLoadStart(url.toString()),
        onLoadStop: (controller, url) =>
            widget.adapter.onMacLoadStop(url.toString()),
        onReceivedError: (controller, request, error) =>
            widget.adapter.onMacReceivedError(request, error),
        shouldOverrideUrlLoading: (controller, action) =>
            widget.adapter.onMacShouldOverrideUrlLoading(action),
      );
    }
    final windowsController = widget.adapter.windowsController;
    if (windowsController != null) {
      // The texture only exists once the native side is up; watching the
      // controller directly means the video appears the moment initialization
      // finishes, without waiting for an unrelated rebuild higher up.
      return ValueListenableBuilder<WebviewValue>(
        valueListenable: windowsController,
        builder: (context, value, _) => Webview(windowsController),
      );
    }
    final webController = widget.adapter.webController;
    if (webController == null) {
      // Neither backend is available (should not happen: the controller only
      // builds this adapter when a WebView backend exists for the platform).
      return const SizedBox.shrink();
    }
    return WebViewWidget(controller: webController);
  }
}
