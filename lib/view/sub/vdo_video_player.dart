import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:chewie/chewie.dart';
import 'package:shobaki_academy/controller/watching_page_vdocipher_controller.dart';
import 'package:shobaki_academy/controller/media_kit_player_adapter.dart';
import 'package:shobaki_academy/controller/macos_player_adapter.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/watermark_controller.dart';

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

  ChewieController? _chewieController;

  void _updateChewieController() {
    final macos = ctrl.player as MacOSPlayerAdapter;
    final videoCtrl = macos.nativeController;
    if (videoCtrl == null) return;
    if (_chewieController != null &&
        _chewieController!.videoPlayerController == videoCtrl) {
      return;
    }
    _chewieController?.dispose();
    _chewieController = ChewieController(
      videoPlayerController: videoCtrl,
      autoPlay: true,
      allowFullScreen: false,
      showControls: true,
      errorBuilder: (ctx, msg) => Center(
        child: Text(msg, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

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
    _chewieController?.dispose();
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

  void _toggleFullScreen() {
    ctrl.isFullScreen.value = !ctrl.isFullScreen.value;
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
                    Platform.isMacOS
                        ? _buildMacOSPlayer()
                        : _buildMediaKitPlayer(),
                    if (ctrl.qualitiesLoaded.value && !ctrl.isFullScreen.value)
                      _buildQualityChip(),
                  ],
                ),
        ),
      );
    });
  }

  Widget _buildMediaKitPlayer() {
    final mediaKit = ctrl.player as MediaKitPlayerAdapter;
    return MaterialDesktopVideoControlsTheme(
      normal: MaterialDesktopVideoControlsThemeData(
        bottomButtonBar: [
          MaterialDesktopCustomButton(
            icon: const Icon(Icons.replay_10),
            onPressed: () => ctrl.seekRelative(-10),
          ),
          const MaterialDesktopPlayOrPauseButton(),
          MaterialDesktopCustomButton(
            icon: const Icon(Icons.forward_10),
            onPressed: () => ctrl.seekRelative(10),
          ),
          MaterialDesktopCustomButton(
            icon: Obx(
              () => Text(
                '${ctrl.playbackSpeed.value}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            onPressed: () => ctrl.showSpeedDialog(context),
          ),
          const MaterialDesktopPositionIndicator(),
          const Spacer(),
          const MaterialDesktopVolumeButton(),
          const MaterialDesktopFullscreenButton(),
        ],
      ),
      fullscreen: MaterialDesktopVideoControlsThemeData(
        bottomButtonBar: [
          MaterialDesktopCustomButton(
            icon: const Icon(Icons.replay_10),
            onPressed: () => ctrl.seekRelative(-10),
          ),
          const MaterialDesktopPlayOrPauseButton(),
          MaterialDesktopCustomButton(
            icon: const Icon(Icons.forward_10),
            onPressed: () => ctrl.seekRelative(10),
          ),
          MaterialDesktopCustomButton(
            icon: Obx(
              () => Text(
                '${ctrl.playbackSpeed.value}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            onPressed: () => ctrl.showSpeedDialog(context),
          ),
          const MaterialDesktopPositionIndicator(),
          const Spacer(),
          const MaterialDesktopVolumeButton(),
          const MaterialDesktopFullscreenButton(),
        ],
      ),
      child: MaterialVideoControlsTheme(
        normal: MaterialVideoControlsThemeData(
          primaryButtonBar: [
            MaterialCustomButton(
              icon: const Icon(Icons.replay_10),
              onPressed: () => ctrl.seekRelative(-10),
            ),
            const MaterialPlayOrPauseButton(iconSize: 48.0),
            MaterialCustomButton(
              icon: const Icon(Icons.forward_10),
              onPressed: () => ctrl.seekRelative(10),
            ),
            MaterialCustomButton(
              icon: Obx(
                () => Text(
                  '${ctrl.playbackSpeed.value}x',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              onPressed: () => ctrl.showSpeedDialog(context),
            ),
          ],
          bottomButtonBar: const [
            MaterialPositionIndicator(),
            Spacer(),
            MaterialFullscreenButton(),
          ],
          seekOnDoubleTap: true,
          volumeGesture: true,
          onVolumeChanged: (v) => ctrl.player.setVolume(v * 100),
          visibleOnMount: false,
        ),
        fullscreen: MaterialVideoControlsThemeData(
          primaryButtonBar: [
            MaterialCustomButton(
              icon: const Icon(Icons.replay_10),
              onPressed: () => ctrl.seekRelative(-10),
            ),
            const MaterialPlayOrPauseButton(iconSize: 48.0),
            MaterialCustomButton(
              icon: const Icon(Icons.forward_10),
              onPressed: () => ctrl.seekRelative(10),
            ),
            MaterialCustomButton(
              icon: Obx(
                () => Text(
                  '${ctrl.playbackSpeed.value}x',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              onPressed: () => ctrl.showSpeedDialog(context),
            ),
          ],
          bottomButtonBar: const [
            MaterialPositionIndicator(),
            Spacer(),
            MaterialFullscreenButton(),
          ],
          seekOnDoubleTap: true,
          volumeGesture: true,
          onVolumeChanged: (v) => ctrl.player.setVolume(v * 100),
          visibleOnMount: false,
        ),
        child: Video(
          controller: VideoController(mediaKit.nativePlayer),
          controls: AdaptiveVideoControls,
          onEnterFullscreen: () async {
            ctrl.isFullScreen.value = true;
          },
          onExitFullscreen: () async {
            ctrl.isFullScreen.value = false;
          },
        ),
      ),
    );
  }

  Widget _buildMacOSPlayer() {
    _updateChewieController();
    final chewie = _chewieController;
    if (chewie == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        Chewie(controller: chewie),
        Positioned(
          bottom: 56,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _overlayButton(Icons.replay_10, () => ctrl.seekRelative(-10)),
              const SizedBox(width: 24),
              _overlayButton(Icons.forward_10, () => ctrl.seekRelative(10)),
              const SizedBox(width: 24),
              _speedBadge(),
              const Spacer(),
              Obx(
                () => _overlayButton(
                  ctrl.isFullScreen.value
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
                  _toggleFullScreen,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _overlayButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  Widget _speedBadge() {
    return Obx(() {
      return GestureDetector(
        onTap: () => ctrl.showSpeedDialog(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${ctrl.playbackSpeed.value}x',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    });
  }

  Widget _buildQualityChip() {
    return Positioned(
      top: 8,
      right: 8,
      child: Obx(() {
        final label = ctrl.qualities[ctrl.currentQualityIndex.value].label;
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
    );
  }
}
