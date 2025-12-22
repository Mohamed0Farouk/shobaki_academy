import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shobaki_academy/controller/watching_page_vdocipher_controller.dart';
//import 'package:shobaki_academy/view/home.dart';
import 'package:vdocipher_flutter/vdocipher_flutter.dart';
import 'package:get/get.dart';
//import 'package:webview_windows/webview_windows.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class VideoPlayerView extends StatelessWidget {
  final String videoId;

  const VideoPlayerView({super.key, required this.videoId});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(VdoWatchingController(videoId));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.offAllNamed("/home");
        },
        child: Icon(Icons.home, color: Theme.of(context).colorScheme.primary),
      ),
      appBar: AppBar(
        title: Text(
          "صفحة المشاهدة",
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Obx(() {
        if (ctrl.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (ctrl.errorMessage.isNotEmpty) {
          return Center(child: Text(ctrl.errorMessage.value));
        }

        // Mobile (vdocipher_flutter)
        if (Platform.isAndroid || Platform.isIOS) {
          return VdoPlayer(
            embedInfo: ctrl.embedInfo!,
            onPlayerCreated: (controller) => ctrl.onPlayerCreated(controller),
            onFullscreenChange: ctrl.onFullscreenChange,
            onError: ctrl.onVdoError,
            controls: true,
          );
        }

        // Windows WebView
        if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          openVdoCipherDesktopPlayer(
            otp: ctrl.embedInfo!.otp!,
            playbackInfo: ctrl.embedInfo!.playbackInfo!,
          );
          //return Webview( ctrl.windowsController);
          return Center(
            child: Text(
              "تم فتح مشغل الفيديو في المتصفح الافتراضي لديك.",
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          );
        }
        return const Center(child: Text("Unsupported platform"));
      }),
    );
  }

  String buildVdoHtml({required String otp, required String playbackInfo}) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Secure Player</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">

  <style>
    html, body {
      margin: 0;
      padding: 0;
      height: 100%;
      background: #000;
      color: #fff;
      font-family: Arial, sans-serif;
      overflow: hidden;
    }

    #embedBox {
      width: 100%;
      height: 100%;
    }

    #expired {
      display: none;
      height: 100%;
      align-items: center;
      justify-content: center;
      text-align: center;
      flex-direction: column;
    }

    .message-icon {
      font-size: 48px;
      margin-bottom: 20px;
    }
  </style>
</head>

<body>

<div id="embedBox"></div>

<div id="expired">
  <div>
    <div class="message-icon">⏱️</div>
    <h2>Session Expired</h2>
    <p>Please return to the app to continue watching.</p>
  </div>
</div>

<!-- VdoCipher Player SDK -->
<script src="https://player.vdocipher.com/v2/api.js"></script>

<script>
(function () {
  'use strict';

  const SESSION_DURATION = 3 * 60 * 60 * 1000; // 3 hours
  
  const otp = decodeURIComponent("${Uri.encodeComponent(otp)}");
  const playbackInfo = decodeURIComponent("${Uri.encodeComponent(playbackInfo)}");

  const embedBox = document.getElementById("embedBox");
  const expiredDiv = document.getElementById("expired");
  
  let sessionStartTime = Date.now();
  let sessionTimer = null;

  function showExpired(message = null) {
    embedBox.style.display = "none";
    expiredDiv.style.display = "flex";
    
    if (message) {
      expiredDiv.querySelector('p').textContent = message;
    }

    try {
      localStorage.clear();
      sessionStorage.clear();
    } catch (_) {}
  }

  function checkSessionExpiry() {
    const elapsed = Date.now() - sessionStartTime;
    if (elapsed >= SESSION_DURATION) {
      showExpired('Please return to the app to continue watching.');
    }
  }

 // 🎬 Initialize VdoCipher Player using iframe embed
  window.addEventListener('load', function() {
    try {
      // Create iframe with VdoCipher player URL
      const iframe = document.createElement('iframe');
      iframe.src = `https://player.vdocipher.com/v2/?otp=$otp&playbackInfo=$playbackInfo&theme=9ae8bbe8dd964ddc9bdb932cca1cb59a`;
      iframe.style.border = '0';
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      iframe.allow = 'encrypted-media';
      iframe.allowFullscreen = true;
      embedBox.appendChild(iframe);

      console.log('✅ VdoCipher player initialized with DRM protection');

      // Start session expiration timer
      sessionTimer = setTimeout(() => {
        showExpired('Please return to the app to continue watching.');
      }, SESSION_DURATION);

    } catch (error) {
      console.error('Failed to initialize player:', error);
      showExpired('Failed to initialize video player.');
    }
  });

  // Cleanup on page close
  window.addEventListener('beforeunload', () => {
    if (sessionTimer) {
      clearTimeout(sessionTimer);
    }
    try {
      localStorage.clear();
      sessionStorage.clear();
    } catch (_) {}
  });

  // Handle visibility change (user switches tabs)
  let hiddenTime = null;
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      hiddenTime = Date.now();
    } else if (hiddenTime) {
      const timeHidden = Date.now() - hiddenTime;
      // If away for more than 30 minutes, expire session
      if (timeHidden > 30 * 60 * 1000) {
        if (sessionTimer) {
          clearTimeout(sessionTimer);
        }
        showExpired('Session expired due to inactivity.');
      }
      hiddenTime = null;
    }
  });

  // Check session every minute
  setInterval(checkSessionExpiry, 60 * 1000);

})();
</script>

</body>
</html>
''';
  }

  Future<void> openVdoCipherDesktopPlayer({
    required String otp,
    required String playbackInfo,
  }) async {
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return;
    }

    final html = buildVdoHtml(otp: otp, playbackInfo: playbackInfo);

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/vdo_player.html');

    await file.writeAsString(html, flush: true);

    final uri = Uri.file(file.path);

    await launchUrl(uri, mode: LaunchMode.externalApplication);

    Future.delayed(const Duration(minutes: 3), () {
      if (file.existsSync()) {
        file.deleteSync();
      }
    });
  }
}
