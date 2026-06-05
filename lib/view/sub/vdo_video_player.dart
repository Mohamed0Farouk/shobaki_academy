import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:shobaki_academy/controller/watching_page_vdocipher_controller.dart';
import 'package:shobaki_academy/controller/media_kit_player_adapter.dart';
import 'package:shobaki_academy/controller/macos_player_adapter.dart';
import 'package:shobaki_academy/view/sub/macos_video_controls.dart';
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

  final Rx<ChewieController?> _chewieController = Rx<ChewieController?>(null);
  StreamSubscription<bool>? _loadingSub;
  late Worker _qualityWorker;

  VideoPlayerController? get _nativeCtrl =>
      Platform.isMacOS
          ? (ctrl.player as MacOSPlayerAdapter).nativeController
          : null;

  void _initChewie() {
    final videoCtrl = _nativeCtrl;
    if (videoCtrl == null) return;
    if (_chewieController.value?.videoPlayerController == videoCtrl) return;
    _chewieController.value?.dispose();
    _chewieController.value = ChewieController(
      videoPlayerController: videoCtrl,
      autoPlay: true,
      allowFullScreen: true,
      showControls: true,
      customControls: MacOSVideoControls(
        controller: ctrl,
        onFullscreenToggle: _toggleFullScreen,
      ),
      errorBuilder: (ctx, msg) => Center(
        child: Text(msg, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    ctrl = Get.put(VideoPlaybackController(widget.videoUrl));

    _qualityWorker = ever(ctrl.currentQualityIndex, (_) {
      if (Platform.isMacOS) _initChewie();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      watermarkController.updateWaterMarkState(true);
    });

    _loadingSub = ctrl.isLoading.listen((loading) {
      if (!loading && _chewieController.value == null) {
        _initChewie();
      }
    });
    if (!ctrl.isLoading.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initChewie());
    }
  }

  @override
  void dispose() {
    _qualityWorker.dispose();
    _loadingSub?.cancel();
    _chewieController.value?.dispose();
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
    final chewie = _chewieController.value;
    if (chewie == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Chewie(controller: chewie);
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
            onTap: () => _showQualityDialog(),
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

  Future<void> _showQualityDialog() async {
    if (ctrl.isFullScreen.value) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('exit fullscreen to control the quality'),
        ),
      );
      return;
    }

    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Quality'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: ctrl.qualities.length,
            itemBuilder: (ctx, i) => ListTile(
              title: Text(ctrl.qualities[i].label),
              trailing: i == ctrl.currentQualityIndex.value
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(ctx, i),
            ),
          ),
        ),
      ),
    );

    if (selected == null || selected == ctrl.currentQualityIndex.value) {
      return;
    }

    if (!mounted) return;
    await ctrl.switchQuality(selected);
  }
}
