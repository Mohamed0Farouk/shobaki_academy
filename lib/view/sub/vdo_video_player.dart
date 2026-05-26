import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shobaki_academy/controller/watching_page_vdocipher_controller.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/watermark_controller.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io' show Platform;

class VideoPlayerView extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerView({super.key, required this.videoUrl});

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  final WatermarkController watermarkController =
      Get.find<WatermarkController>();
  late final VideoPlaybackController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = Get.put(VideoPlaybackController(widget.videoUrl));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      watermarkController.updateWaterMarkState(true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      watermarkController.updateWaterMarkState(false);
    });
    ctrl.cleanup();
    Get.delete<VideoPlaybackController>();
    super.dispose();
  }

  void _handleLeave() {
    ctrl.stopTracking();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final fullscreen = ctrl.isFullScreen.value;

      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) return;
          ctrl.stopTracking();
        },
        child: Scaffold(
          floatingActionButton: fullscreen
              ? null
              : FloatingActionButton(
                  onPressed: () {
                    _handleLeave();
                    Get.offAllNamed("/home");
                  },
                  child: Icon(
                    Icons.home,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,

          appBar: fullscreen
              ? null
              : AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      _handleLeave();
                      Get.back();
                    },
                  ),
                  title: Text(
                    "صفحة المشاهدة",
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                  ),
                  centerTitle: true,
                ),
          body: ctrl.errorMessage.value.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      ctrl.errorMessage.value,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ctrl.isLoading.value
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    Video(
                      controller: ctrl.videoController,
                      onEnterFullscreen: () async {
                        ctrl.isFullScreen.value = true;
                        if (Platform.isWindows ||
                            Platform.isMacOS ||
                            Platform.isLinux) {
                          await WindowManager.instance.setFullScreen(true);
                        }
                      },
                      onExitFullscreen: () async {
                        ctrl.isFullScreen.value = false;
                        if (Platform.isWindows ||
                            Platform.isMacOS ||
                            Platform.isLinux) {
                          await WindowManager.instance.setFullScreen(false);
                        }
                      },
                    ),
                    if (ctrl.qualitiesLoaded.value && !ctrl.isFullScreen.value)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Obx(() {
                          final label = ctrl
                              .qualities[ctrl.currentQualityIndex.value]
                              .label;
                          return Material(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () => ctrl.showQualityDialog(context),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.high_quality,
                                      size: 14,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      label,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                  ],
                ),
        ),
      );
    });
  }
}
