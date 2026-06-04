import 'dart:async';
import 'package:video_player/video_player.dart';
import 'player_adapter.dart';

class MacOSPlayerAdapter implements IPlayerAdapter {
  VideoPlayerController? _controller;
  final StreamController<bool> _playingCtrl =
      StreamController<bool>.broadcast();
  final StreamController<Duration> _durationCtrl =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _completedCtrl =
      StreamController<bool>.broadcast();
  final StreamController<String?> _errorCtrl =
      StreamController<String?>.broadcast();
  final StreamController<Duration> _positionCtrl =
      StreamController<Duration>.broadcast();

  bool _isInitialized = false;
  bool _isDisposed = false;

  VideoPlayerController? get nativeController => _controller;

  @override
  bool get isPlaying => _controller?.value.isPlaying ?? false;

  @override
  Duration get position => _controller?.value.position ?? Duration.zero;

  @override
  Duration get duration => _controller?.value.duration ?? Duration.zero;

  @override
  bool get isCompleted => _controller?.value.isCompleted ?? false;

  @override
  String? get error => _controller?.value.errorDescription;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Stream<bool> get onPlayingChanged => _playingCtrl.stream;

  @override
  Stream<Duration> get onDurationChanged => _durationCtrl.stream;

  @override
  Stream<bool> get onCompleted => _completedCtrl.stream;

  @override
  Stream<String?> get onError => _errorCtrl.stream;

  @override
  Stream<Duration> get onPositionChanged => _positionCtrl.stream;

  void _onControllerUpdate() {
    if (_isDisposed || _controller == null) return;
    try {
      final v = _controller!.value;
      if (!_playingCtrl.isClosed) _playingCtrl.add(v.isPlaying);
      if (!_durationCtrl.isClosed) _durationCtrl.add(v.duration);
      if (!_positionCtrl.isClosed) _positionCtrl.add(v.position);
      if (v.isCompleted && !_completedCtrl.isClosed) _completedCtrl.add(true);
      if (v.hasError && !_errorCtrl.isClosed) _errorCtrl.add(v.errorDescription);
    } catch (_) {}
  }

  @override
  Future<void> open(String url, {Duration? start}) async {
    await _controller?.dispose();
    _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller!.addListener(_onControllerUpdate);
    await _controller!.initialize();
    _isInitialized = true;
    if (start != null && start > Duration.zero) {
      await _controller!.seekTo(start);
    }
  }

  @override
  Future<void> play() => _controller?.play() ?? Future.value();

  @override
  Future<void> pause() => _controller?.pause() ?? Future.value();

  @override
  Future<void> seek(Duration position) =>
      _controller?.seekTo(position) ?? Future.value();

  @override
  Future<void> setRate(double rate) =>
      _controller?.setPlaybackSpeed(rate) ?? Future.value();

  @override
  Future<void> setVolume(double volume) =>
      _controller?.setVolume(volume) ?? Future.value();

  @override
  Future<void> stop() {
    pause();
    return seek(Duration.zero);
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    _controller?.removeListener(_onControllerUpdate);
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    await _playingCtrl.close();
    await _durationCtrl.close();
    await _completedCtrl.close();
    await _errorCtrl.close();
    await _positionCtrl.close();
  }
}
