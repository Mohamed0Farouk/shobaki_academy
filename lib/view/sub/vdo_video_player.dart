import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shobaki_academy/controller/watching_page_vdocipher_controller.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:vdocipher_flutter/vdocipher_flutter.dart';
import 'package:get/get.dart';

class VideoPlayerView extends StatelessWidget {
  final String videoId;

  const VideoPlayerView({super.key, required this.videoId});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(VdoWatchingController(videoId));

    return Scaffold(
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
          return Center(child: loading(context));
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

        // Desktop fallback (WebView)
        return WebViewWidget(controller: ctrl.webController!);
      }),
    );
  }
}
