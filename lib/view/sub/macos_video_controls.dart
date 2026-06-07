import 'dart:async';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:shobaki_academy/controller/watching_page_vdocipher_controller.dart';

class _ControlsNotifier {
  bool hideStuff = false;
}

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
  final _controlsNotifier = _ControlsNotifier();
  VideoPlayerValue _latestValue = VideoPlayerValue.uninitialized();
  double? _latestVolume;
  Timer? _hideTimer;
  Timer? _initTimer;
  bool _dragging = false;
  bool _draggingVolume = false;
  double _sliderVolume = 0.5;
  String? _hoveredButton;
  late final FocusNode _focusNode;

  ChewieController? _chewieCtrl;
  ChewieController? get chewieCtrl => _chewieCtrl;
  VideoPlayerController? get vpc => _chewieCtrl?.videoPlayerController;

  static const double _barHeight = 72.0;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.requestFocus();
  }

  @override
  void didChangeDependencies() {
    final oldCtrl = _chewieCtrl;
    _chewieCtrl = ChewieController.of(context);
    if (oldCtrl != _chewieCtrl && _chewieCtrl != null) {
      _dispose();
      _initialize();
    }
    super.didChangeDependencies();
  }

  void _dispose() {
    vpc?.removeListener(_updateState);
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
    final ctrl = vpc;
    final ch = chewieCtrl;
    if (ctrl == null || ch == null) return;
    ctrl.addListener(_updateState);
    _updateState();
    if (ctrl.value.isPlaying || ch.autoPlay) {
      _startHideTimer();
    }
    if (ch.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        _setShowControls(true);
      });
    }
  }

  void _updateState() {
    if (!mounted) return;
    final ctrl = vpc;
    if (ctrl == null) return;
    setState(() {
      _latestValue = ctrl.value;
      if (!_draggingVolume) {
        _sliderVolume = ctrl.value.volume;
      }
    });
  }

  void _setShowControls(bool show) {
    if (!mounted) return;
    setState(() {
      _controlsNotifier.hideStuff = !show;
    });
  }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();
    _setShowControls(true);
  }

  void _startHideTimer() {
    final ch = chewieCtrl;
    if (ch == null) return;
    final hideControlsTimer = ch.hideControlsTimer.isNegative
        ? ChewieController.defaultHideControlsTimer
        : ch.hideControlsTimer;
    _hideTimer = Timer(hideControlsTimer, () {
      _setShowControls(false);
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
      if (widget.controller.isFullScreen.value) {
        _onExpandCollapse();
      }
    }
  }

  void _onExpandCollapse() {
    _setShowControls(false);
    widget.onFullscreenToggle();
  }

  void _playPause() {
    final ctrl = vpc;
    if (ctrl == null) return;
    if (ctrl.value.isPlaying) {
      _setShowControls(true);
      _hideTimer?.cancel();
      ctrl.pause();
    } else {
      _cancelAndRestartTimer();
      if (!ctrl.value.isInitialized) {
        ctrl.initialize().then((_) => ctrl.play());
      } else {
        ctrl.play();
      }
    }
  }

  void _seekRelative(int seconds) {
    final ctrl = vpc;
    if (ctrl == null) return;
    _cancelAndRestartTimer();
    final position = _latestValue.position + Duration(seconds: seconds);
    final duration = _latestValue.duration;
    if (position < Duration.zero) {
      ctrl.seekTo(Duration.zero);
    } else if (position > duration) {
      ctrl.seekTo(duration);
    } else {
      ctrl.seekTo(position);
    }
  }

  Widget _iconButton({
    required String id,
    required Widget icon,
    required VoidCallback onTap,
  }) {
    final isHovered = _hoveredButton == id;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        _cancelAndRestartTimer();
        setState(() => _hoveredButton = id);
      },
      onExit: (_) => setState(() => _hoveredButton = null),
      child: GestureDetector(
        onTap: () {
          _cancelAndRestartTimer();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isHovered
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: SizedBox(width: 24, height: 24, child: icon),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ch = chewieCtrl;
    if (ch == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_latestValue.hasError) {
      return ch.errorBuilder?.call(
            context,
            _latestValue.errorDescription!,
          ) ??
          const Center(child: Icon(Icons.error, color: Colors.white, size: 42));
    }

    final bool isFinished =
        _latestValue.position >= _latestValue.duration &&
        _latestValue.duration.inSeconds > 0;
    final bool showPlayButton = !_dragging && !_controlsNotifier.hideStuff;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyPress,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onHover: (_) {
          _focusNode.requestFocus();
          _cancelAndRestartTimer();
        },
        child: GestureDetector(
          onTap: () {
            if (_latestValue.isPlaying) {
              if (ch.pauseOnBackgroundTap) {
                _playPause();
                _cancelAndRestartTimer();
              } else {
                setState(() {
                  _controlsNotifier.hideStuff =
                      !_controlsNotifier.hideStuff;
                });
                if (!_controlsNotifier.hideStuff) {
                  _cancelAndRestartTimer();
                }
              }
            } else {
              _playPause();
              _setShowControls(false);
            }
          },
          child: AbsorbPointer(
            absorbing: _controlsNotifier.hideStuff,
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
    final ctrl = vpc;
    return GestureDetector(
      onTap: () {
        if (_latestValue.isPlaying) {
          setState(() {
            _controlsNotifier.hideStuff = !_controlsNotifier.hideStuff;
          });
          if (!_controlsNotifier.hideStuff) {
            _cancelAndRestartTimer();
          }
        } else {
          _playPause();
          _setShowControls(false);
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
                        ctrl?.value.isPlaying == true
                            ? Icons.pause
                            : Icons.play_arrow,
                        key: ValueKey(ctrl?.value.isPlaying ?? false),
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
    final ch = chewieCtrl;
    if (ch == null) return const SizedBox.shrink();

    return AnimatedOpacity(
      opacity: _controlsNotifier.hideStuff ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        height: _barHeight + (ch.isFullScreen ? 20.0 : 0),
        padding: EdgeInsets.only(
          bottom: ch.isFullScreen ? 10.0 : 15,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black54],
          ),
        ),
        child: SafeArea(
          bottom: ch.isFullScreen,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            verticalDirection: VerticalDirection.up,
            children: [
              Flexible(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildReplayButton(),
                    _buildPlayPause(),
                    _buildForwardButton(),
                    if (ch.allowMuting) _buildVolumeControl(),
                    _buildPosition(),
                    const Spacer(),
                    if (ch.showOptions) _buildOptionsButton(),
                    if (ch.allowFullScreen) _buildFullscreenButton(),
                  ],
                ),
              ),
              if (!ch.isLive)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: 20,
                      left: 20,
                      bottom: ch.isFullScreen ? 5.0 : 0,
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
    return _iconButton(
      id: 'replay',
      icon: const Icon(Icons.replay_10, color: Colors.white, size: 24),
      onTap: () => _seekRelative(-10),
    );
  }

  Widget _buildForwardButton() {
    return _iconButton(
      id: 'forward',
      icon: const Icon(Icons.forward_10, color: Colors.white, size: 24),
      onTap: () => _seekRelative(10),
    );
  }

  Widget _buildPlayPause() {
    return _iconButton(
      id: 'playpause',
      icon: Icon(
        vpc?.value.isPlaying == true ? Icons.pause : Icons.play_arrow,
        color: Colors.white,
        size: 24,
      ),
      onTap: _playPause,
    );
  }

  Widget _buildVolumeControl() {
    final isHovered = _hoveredButton == 'volume';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) {
            _cancelAndRestartTimer();
            setState(() => _hoveredButton = 'volume');
          },
          onExit: (_) {
            if (!_draggingVolume) {
              setState(() => _hoveredButton = null);
            }
          },
          child: GestureDetector(
            onTap: () {
              _cancelAndRestartTimer();
              if (_latestValue.volume == 0) {
                final restore = _latestVolume ?? 0.5;
                vpc?.setVolume(restore);
              } else {
                _latestVolume = vpc?.value.volume;
                vpc?.setVolume(0.0);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isHovered
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Icon(
                    _latestValue.volume > 0
                        ? Icons.volume_up
                        : Icons.volume_off,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 80,
            height: 24,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 12,
                ),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white38,
                thumbColor: Colors.white,
                overlayColor: Colors.white24,
              ),
              child: Slider(
                value: _draggingVolume
                    ? _sliderVolume
                    : _latestValue.volume,
                onChanged: (v) {
                  _cancelAndRestartTimer();
                  setState(() {
                    _draggingVolume = true;
                    _sliderVolume = v;
                  });
                  vpc?.setVolume(v);
                },
                onChangeEnd: (v) {
                  setState(() => _draggingVolume = false);
                  if (vpc?.value.isPlaying == true) {
                    _startHideTimer();
                  }
                  if (_hoveredButton != 'volume') {
                    setState(() => _hoveredButton = null);
                  }
                },
              ),
            ),
          ),
        ],
    );
  }


  Widget _buildPosition() {
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
    return _iconButton(
      id: 'options',
      icon: const Icon(Icons.settings, color: Colors.white, size: 24),
      onTap: () async {
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
    );
  }

  Widget _buildFullscreenButton() {
    return _iconButton(
      id: 'fullscreen',
      icon: Obx(() => Icon(
        widget.controller.isFullScreen.value
            ? Icons.fullscreen_exit
            : Icons.fullscreen,
        color: Colors.white,
        size: 24,
      )),
      onTap: _onExpandCollapse,
    );
  }

  Widget _buildProgressBar() {
    final ctrl = vpc;
    final ch = chewieCtrl;
    if (ctrl == null || ch == null) return const SizedBox.shrink();
    return MaterialVideoProgressBar(
      ctrl,
      onDragStart: () {
        setState(() => _dragging = true);
        _hideTimer?.cancel();
      },
      onDragUpdate: () => _hideTimer?.cancel(),
      onDragEnd: () {
        setState(() => _dragging = false);
        _startHideTimer();
      },
      draggableProgressBar: ch.draggableProgressBar,
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
