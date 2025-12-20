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
    }
    #player {
      width: 100%;
      height: 100%;
    }
  </style>
</head>
<body>

<div id="player"></div>

<script>
(function () {
  const otp = "${Uri.encodeComponent(otp)}";
  const playbackInfo = "${Uri.encodeComponent(playbackInfo)}";

  const iframe = document.createElement("iframe");
  iframe.src =
    "https://player.vdocipher.com/v2/?" +
    "otp=" + otp +
    "&playbackInfo=" + playbackInfo;

  iframe.allow = "encrypted-media";
  iframe.allowFullscreen = true;
  iframe.style.width = "100%";
  iframe.style.height = "100%";
  iframe.style.border = "0";

  document.getElementById("player").appendChild(iframe);
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
