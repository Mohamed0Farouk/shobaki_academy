import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shobaki_academy/controller/watching_page_vdocipher_controller.dart';
//import 'package:shobaki_academy/view/home.dart';
import 'package:vdocipher_flutter/vdocipher_flutter.dart';
import 'package:get/get.dart';
//import 'package:webview_windows/webview_windows.dart';

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
      floatingActionButtonLocation: (Platform.isAndroid || Platform.isIOS)
          ? FloatingActionButtonLocation.centerFloat
          : FloatingActionButtonLocation.endFloat,

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
          if (ctrl.initialized && ctrl.logInitialized) {
            ctrl.openVdoCipherDesktopPlayer(
              otp: ctrl.embedInfo!.otp!,
              playbackInfo: ctrl.embedInfo!.playbackInfo!,
            );
          }
          
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
}
