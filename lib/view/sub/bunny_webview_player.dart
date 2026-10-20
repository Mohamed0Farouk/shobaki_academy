import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';
import 'package:window_manager/window_manager.dart';

import 'package:shobaki_academy/controller/bunny_webview_player_adapter.dart';
import 'package:shobaki_academy/controller/watching_page_vdocipher_controller.dart';

/// Hosts the Bunny embed webview inside the normal player page.
///
/// The [Webview] widget renders an empty box until its controller has
/// finished initializing, and the page's own loading spinner (driven by
/// `ctrl.isLoading`) covers that gap, so no extra state machine is needed
/// here.
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
    // keeps the two fullscreen states from drifting apart.
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
    // The texture only exists once the native side is up; watching the
    // controller directly means the video appears the moment initialization
    // finishes, without waiting for an unrelated rebuild higher up.
    return ValueListenableBuilder<WebviewValue>(
      valueListenable: widget.adapter.controller,
      builder: (context, value, _) => Webview(widget.adapter.controller),
    );
  }
}
