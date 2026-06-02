import 'dart:async';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:shobaki_academy/controller/watching_page_vdocipher_controller.dart';
import 'package:chewie/src/notifiers/player_notifier.dart';

class MacOSVideoControls extends StatefulWidget {
  final VideoPlaybackController controller;
  final VoidCallback onFullscreenToggle;

  const MacOSVideoControls({
    super.key,
    required this.controller,
    required this.onFullscreenToggle,
  });

  @override
  State<MacOSVideoControls> createState() => _MacOSVideoControlsState();
}

class _MacOSVideoControlsState extends State<MacOSVideoControls>
    with SingleTickerProviderStateMixin {
  late PlayerNotifier notifier;
  late VideoPlayerValue _latestValue;
  double? _latestVolume;
  Timer? _hideTimer;
  Timer? _initTimer;
  bool _dragging = false;
  late final FocusNode _focusNode;

  ChewieController? _chewieCtrl;
  ChewieController get chewieCtrl => _chewieCtrl!;
  VideoPlayerController get vpc => chewieCtrl.videoPlayerController;

  static const double _barHeight = 72.0;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.requestFocus();
    notifier = Provider.of<PlayerNotifier>(context, listen: false);
  }

  @override
  void didChangeDependencies() {
    final oldCtrl = _chewieCtrl;
    _chewieCtrl = ChewieController.of(context);
    if (oldCtrl != chewieCtrl) {
      _dispose();
      _initialize();
    }
    super.didChangeDependencies();
  }

  void _dispose() {
    vpc.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
  }

  @override
  void dispose() {
    _dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _initialize() {
    vpc.addListener(_updateState);
    _updateState();
    if (vpc.value.isPlaying || chewieCtrl.autoPlay) {
      _startHideTimer();
    }
    if (chewieCtrl.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        notifier.hideStuff = false;
      });
    }
  }

  void _updateState() {
    if (!mounted) return;
    setState(() {
      _latestValue = vpc.value;
    });
  }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();
    notifier.hideStuff = false;
  }

  void _startHideTimer() {
    final hideControlsTimer = chewieCtrl.hideControlsTimer.isNegative
        ? ChewieController.defaultHideControlsTimer
        : chewieCtrl.hideControlsTimer;
    _hideTimer = Timer(hideControlsTimer, () {
      notifier.hideStuff = true;
    });
  }

  void _handleKeyPress(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      _playPause();
    } else if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _seekRelative(10);
    } else if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _seekRelative(-10);
    } else if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      if (chewieCtrl.isFullScreen) {
        _onExpandCollapse();
      }
    }
  }

  void _onExpandCollapse() {
    notifier.hideStuff = true;
    widget.onFullscreenToggle();
  }

  void _playPause() {
    if (vpc.value.isPlaying) {
      notifier.hideStuff = false;
      _hideTimer?.cancel();
      vpc.pause();
    } else {
      _cancelAndRestartTimer();
      if (!vpc.value.isInitialized) {
        vpc.initialize().then((_) => vpc.play());
      } else {
        vpc.play();
      }
    }
  }

  void _seekRelative(int seconds) {
    _cancelAndRestartTimer();
    final position = _latestValue.position + Duration(seconds: seconds);
    final duration = _latestValue.duration;
    if (position < Duration.zero) {
      vpc.seekTo(Duration.zero);
    } else if (position > duration) {
      vpc.seekTo(duration);
    } else {
      vpc.seekTo(position);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_latestValue.hasError) {
      return chewieCtrl.errorBuilder?.call(
            context,
            vpc.value.errorDescription!,
          ) ??
          const Center(child: Icon(Icons.error, color: Colors.white, size: 42));
    }

    final bool isFinished =
        _latestValue.position >= _latestValue.duration &&
        _latestValue.duration.inSeconds > 0;
    final bool showPlayButton = !_dragging && !notifier.hideStuff;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyPress,
      child: MouseRegion(
        onHover: (_) {
          _focusNode.requestFocus();
          _cancelAndRestartTimer();
        },
        child: GestureDetector(
          onTap: () {
            if (_latestValue.isPlaying) {
              if (chewieCtrl.pauseOnBackgroundTap) {
                _playPause();
                _cancelAndRestartTimer();
              } else {
                setState(() {
                  notifier.hideStuff = !notifier.hideStuff;
                });
                if (!notifier.hideStuff) {
                  _cancelAndRestartTimer();
                }
              }
            } else {
              _playPause();
              notifier.hideStuff = true;
            }
          },
          child: AbsorbPointer(
            absorbing: notifier.hideStuff,
            child: Stack(
              children: [
                _buildHitArea(isFinished, showPlayButton),
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildBottomBar(context),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHitArea(bool isFinished, bool showPlayButton) {
    return GestureDetector(
      onTap: () {
        if (_latestValue.isPlaying) {
          setState(() {
            notifier.hideStuff = !notifier.hideStuff;
          });
          if (!notifier.hideStuff) {
            _cancelAndRestartTimer();
          }
        } else {
          _playPause();
          notifier.hideStuff = true;
        }
      },
      child: Center(
        child: AnimatedOpacity(
          opacity: showPlayButton ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              iconSize: 32,
              padding: const EdgeInsets.all(12),
              icon: isFinished
                  ? const Icon(Icons.replay, color: Colors.white)
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        vpc.value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        key: ValueKey(vpc.value.isPlaying),
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
              onPressed: _playPause,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final iconColor = Colors.white;

    return AnimatedOpacity(
      opacity: notifier.hideStuff ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        height: _barHeight + (chewieCtrl.isFullScreen ? 20.0 : 0),
        padding: EdgeInsets.only(
          bottom: chewieCtrl.isFullScreen ? 10.0 : 15,
        ),
        child: SafeArea(
          bottom: chewieCtrl.isFullScreen,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            verticalDirection: VerticalDirection.up,
            children: [
              Flexible(
                child: Row(
                  children: [
                    _buildReplayButton(),
                    _buildPlayPause(),
                    _buildForwardButton(),
                    if (chewieCtrl.allowMuting) _buildMuteButton(iconColor),
                    _buildPosition(iconColor),
                    const Spacer(),
                    if (chewieCtrl.showOptions) _buildOptionsButton(),
                    if (chewieCtrl.allowFullScreen) _buildFullscreenButton(),
                  ],
                ),
              ),
              if (!chewieCtrl.isLive)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: 20,
                      left: 20,
                      bottom: chewieCtrl.isFullScreen ? 5.0 : 0,
                    ),
                    child: _buildProgressBar(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplayButton() {
    return IconButton(
      icon: const Icon(Icons.replay_10, color: Colors.white),
      onPressed: () => _seekRelative(-10),
      tooltip: 'Replay 10s',
    );
  }

  Widget _buildForwardButton() {
    return IconButton(
      icon: const Icon(Icons.forward_10, color: Colors.white),
      onPressed: () => _seekRelative(10),
      tooltip: 'Forward 10s',
    );
  }

  GestureDetector _buildPlayPause() {
    return GestureDetector(
      onTap: _playPause,
      child: Container(
        height: _barHeight,
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(
          vpc.value.isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  GestureDetector _buildMuteButton(Color iconColor) {
    return GestureDetector(
      onTap: () {
        _cancelAndRestartTimer();
        if (_latestValue.volume == 0) {
          vpc.setVolume(_latestVolume ?? 0.5);
        } else {
          _latestVolume = vpc.value.volume;
          vpc.setVolume(0.0);
        }
      },
      child: AnimatedOpacity(
        opacity: notifier.hideStuff ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: ClipRect(
          child: Container(
            height: _barHeight,
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              _latestValue.volume > 0 ? Icons.volume_up : Icons.volume_off,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPosition(Color iconColor) {
    final position = _latestValue.position;
    final duration = _latestValue.duration;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        '${_formatDuration(position)} / ${_formatDuration(duration)}',
        style: const TextStyle(fontSize: 14.0, color: Colors.white),
      ),
    );
  }

  Widget _buildOptionsButton() {
    return AnimatedOpacity(
      opacity: notifier.hideStuff ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 250),
      child: IconButton(
        onPressed: () async {
          _hideTimer?.cancel();
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (ctx) => _OptionsDialog(
              onSpeedTap: () {
                Navigator.pop(ctx);
                widget.controller.showSpeedDialog(context);
              },
              onQualityTap: () {
                Navigator.pop(ctx);
                widget.controller.showQualityDialog(context);
              },
            ),
          );
          if (_latestValue.isPlaying) {
            _startHideTimer();
          }
        },
        icon: const Icon(Icons.settings, color: Colors.white),
        tooltip: 'Options',
      ),
    );
  }

  GestureDetector _buildFullscreenButton() {
    return GestureDetector(
      onTap: _onExpandCollapse,
      child: AnimatedOpacity(
        opacity: notifier.hideStuff ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          height: _barHeight + (chewieCtrl.isFullScreen ? 15.0 : 0),
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.only(left: 8, right: 8),
          child: Center(
            child: Obx(() => Icon(
              widget.controller.isFullScreen.value
                  ? Icons.fullscreen_exit
                  : Icons.fullscreen,
              color: Colors.white,
            )),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Expanded(
      child: MaterialVideoProgressBar(
        vpc,
        onDragStart: () {
          setState(() => _dragging = true);
          _hideTimer?.cancel();
        },
        onDragUpdate: () => _hideTimer?.cancel(),
        onDragEnd: () {
          setState(() => _dragging = false);
          _startHideTimer();
        },
        draggableProgressBar: chewieCtrl.draggableProgressBar,
      ),
    );
  }

  String _formatDuration(Duration position) {
    final ms = position.inMilliseconds;
    int seconds = ms ~/ 1000;
    final int hours = seconds ~/ 3600;
    seconds = seconds % 3600;
    final minutes = seconds ~/ 60;
    seconds = seconds % 60;

    final hoursStr = hours >= 10
        ? '$hours'
        : hours == 0
            ? '00'
            : '0$hours';
    final minutesStr =
        minutes >= 10 ? '$minutes' : minutes == 0 ? '00' : '0$minutes';
    final secondsStr =
        seconds >= 10 ? '$seconds' : seconds == 0 ? '00' : '0$seconds';

    return '${hoursStr == '00' ? '' : '$hoursStr:'}$minutesStr:$secondsStr';
  }
}

class _OptionsDialog extends StatelessWidget {
  final VoidCallback onSpeedTap;
  final VoidCallback onQualityTap;

  const _OptionsDialog({
    required this.onSpeedTap,
    required this.onQualityTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('Playback speed'),
            onTap: onSpeedTap,
          ),
          ListTile(
            leading: const Icon(Icons.high_quality),
            title: const Text('Quality'),
            onTap: onQualityTap,
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Cancel'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
