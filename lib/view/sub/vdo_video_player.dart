import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:shobaki_academy/controller/watching_page_vdocipher_controller.dart';
import 'package:shobaki_academy/controller/media_kit_player_adapter.dart';
import 'package:shobaki_academy/controller/video_player_adapter.dart';
import 'package:shobaki_academy/view/sub/video_player_controls.dart';
import 'package:get/get.dart';
import 'package:shobaki_academy/controller/watermark_controller.dart';
import 'package:window_manager/window_manager.dart';

class VideoPlayerView extends StatefulWidget {
  final String videoUrl;
  final int maxSessionDurationSeconds;

  const VideoPlayerView({
    super.key,
    required this.videoUrl,
    this.maxSessionDurationSeconds = VideoPlaybackController.defaultMaxSessionSeconds,
  });

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _FullscreenWindowListener with WindowListener {
  _FullscreenWindowListener(this.onChanged);

  final void Function(bool) onChanged;

  @override
  void onWindowEnterFullScreen() => onChanged(true);

  @override
  void onWindowLeaveFullScreen() => onChanged(false);
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  final WatermarkController watermarkController =
      Get.find<WatermarkController>();
  late final VideoPlaybackController ctrl;

  final Rx<ChewieController?> _chewieController = Rx<ChewieController?>(null);
  StreamSubscription<bool>? _loadingSub;
  late Worker _qualityWorker;

  VideoController? _videoController;
  _FullscreenWindowListener? _fsListener;

  // On Android, attaching the surface immediately (instead of waiting for the
  // video parameters) avoids the known "audio plays but video stays black"
  // issue with HLS streams. The flag is Android-only and ignored elsewhere.
  // When the controller is reset on retry, a brand-new Player is used, so the
  // VideoController must be rebuilt against it instead of reusing the stale one.
  VideoController get _mediaKitVideoController {
    final nativePlayer = (ctrl.player as MediaKitPlayerAdapter).nativePlayer;
    if (_videoController == null ||
        !identical(_videoController!.player, nativePlayer)) {
      _videoController = VideoController(
        nativePlayer,
        configuration: Platform.isAndroid
            ? const VideoControllerConfiguration(
                androidAttachSurfaceAfterVideoParameters: false,
              )
            : const VideoControllerConfiguration(),
      );
    }
    return _videoController!;
  }

  VideoPlayerController? get _nativeCtrl =>
      (Platform.isMacOS || Platform.isWindows)
          ? (ctrl.player as VideoPlayerAdapter).nativeController
          : null;

  void _initChewie({bool autoPlay = true}) {
    final videoCtrl = _nativeCtrl;
    if (videoCtrl == null) return;
    if (_chewieController.value?.videoPlayerController == videoCtrl) return;
    _chewieController.value?.dispose();
    _chewieController.value = ChewieController(
      videoPlayerController: videoCtrl,
      autoPlay: autoPlay,
      allowFullScreen: true,
      showControls: true,
      customControls: VideoControls(
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
    ctrl = Get.put(VideoPlaybackController(
      widget.videoUrl,
      maxSessionDurationSeconds: widget.maxSessionDurationSeconds,
    ));

    _qualityWorker = ever(ctrl.currentQualityIndex, (_) {
      if (Platform.isMacOS || Platform.isWindows) {
        _initChewie(autoPlay: ctrl.lastPlayIntent.value);
      }
    });

    if (Platform.isWindows || Platform.isMacOS) {
      _fsListener = _FullscreenWindowListener((fullscreen) {
        if (ctrl.isFullScreen.value != fullscreen) {
          ctrl.isFullScreen.value = fullscreen;
        }
      });
      windowManager.addListener(_fsListener!);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      watermarkController.updateWaterMarkState(true);
    });

    _loadingSub = ctrl.isLoading.listen((loading) {
      // _initChewie is identity-guarded (only rebuilds when the underlying
      // VideoPlayerController changed) and a no-op on media_kit platforms.
      // Calling it on every load completion also rebuilds Chewie after a
      // retry-reset on Windows, where a brand-new adapter is created.
      if (!loading) {
        _initChewie();
      }
    });
    if (!ctrl.isLoading.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initChewie());
    }
  }

  @override
  void dispose() {
    if (_fsListener != null) {
      windowManager.removeListener(_fsListener!);
      _fsListener = null;
    }
    if (Platform.isWindows || Platform.isMacOS && ctrl.isFullScreen.value) {
      unawaited(_exitWindowFullScreen());
    }
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

  Future<void> _exitWindowFullScreen() async {
    try {
      await windowManager.setFullScreen(false);
    } catch (_) {
      // Non-fatal: the window stays fullscreen until the user toggles it off.
    }
  }

  void _handleLeave() {
    ctrl.stopTracking();
  }

  void _toggleFullScreen() {
    final target = !ctrl.isFullScreen.value;
    ctrl.isFullScreen.value = target;
    // Drive the real OS window on desktop. window_manager is only initialized
    // on Windows/macOS (see main.dart).
    if (Platform.isWindows || Platform.isMacOS) {
      try {
        windowManager.setFullScreen(target);
      } catch (_) {
        // Revert the in-app state if the native call failed.
        ctrl.isFullScreen.value = !target;
      }
    }
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
          body: Container(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: (Platform.isMacOS || Platform.isWindows)
                      ? _buildChewiePlayer()
                      : _buildMediaKitPlayer(),
                ),
                if (ctrl.qualitiesLoaded.value) _buildQualityChip(),
                if (ctrl.isLoading.value)
                  ColoredBox(
                    color: Colors.black54,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                if (ctrl.errorMessage.value.isNotEmpty)
                  ColoredBox(
                    color: Colors.black87,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ctrl.errorMessage.value,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => ctrl.retry(),
                              icon: const Icon(Icons.refresh),
                              label: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildMediaKitPlayer() {
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
          key: ValueKey(ctrl.playerGeneration.value),
          controller: _mediaKitVideoController,
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

  Widget _buildChewiePlayer() {
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
