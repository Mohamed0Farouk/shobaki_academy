import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:shobaki_academy/controller/playback_edge_cases.dart';
import 'package:shobaki_academy/services/statics.dart';
import 'package:shobaki_academy/services/value_deduplicator.dart';
import 'player_adapter.dart';

/// [video_player] based adapter.
///
/// Used on macOS (AVFoundation) and Windows (FVP/libmdk backend). On Windows an
/// [initializeTimeout] is passed so a network stream that never reports a
/// duration/initialized state fails fast and flows into the existing retry
/// logic instead of hanging the loading spinner forever.
class VideoPlayerAdapter implements IPlayerAdapter {
  VideoPlayerAdapter({this.initializeTimeout});

  final Duration? initializeTimeout;

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
  final StreamController<bool> _bufferingCtrl =
      StreamController<bool>.broadcast();

  bool _isInitialized = false;
  bool _isDisposed = false;

  /// Last emitted value per channel. `video_player` notifies listeners on
  /// every position poll (10Hz) and on every buffered-range update, so without
  /// de-duplication the controller below re-runs its play/pause/load logic ten
  /// times a second for a value that has not changed.
  ///
  /// Every one of these is reset in [open] because the underlying
  /// VideoPlayerController is replaced there.
  final _playing = ValueDeduplicator<bool>();
  final _duration = ValueDeduplicator<Duration>();
  final _position = ValueDeduplicator<Duration>();
  final _buffering = ValueDeduplicator<bool>();
  final _error = ValueDeduplicator<String>();
  final _completed = ValueDeduplicator<bool>();

  /// Furthest position the media actually reached. Used to tell a genuine
  /// end-of-media apart from a transport error that stops the player.
  Duration _maxPosition = Duration.zero;

  /// Set while we are recovering from a spurious "completed" event.
  bool _recoveringFromSpuriousEnd = false;

  /// Playhead position at the last spurious-completion recovery attempt, or
  /// null if no attempt has been made. Stops retrying forever once resuming
  /// has clearly failed.
  Duration? _lastRecoveryAttemptPosition;

  /// How close to the end still counts as genuinely finished.
  static const Duration _completionSlack = Duration(seconds: 5);

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
  bool get isBuffering => _controller?.value.isBuffering ?? false;

  @override
  Duration get bufferedAhead => computeBufferedAhead(
        (_controller?.value.buffered ?? const <DurationRange>[])
            .map((r) => (start: r.start, end: r.end)),
        _controller?.value.position ?? Duration.zero,
      );

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

  @override
  Stream<bool> get onBufferingChanged => _bufferingCtrl.stream;

  void _onControllerUpdate() {
    if (_isDisposed || _controller == null) return;
    try {
      final v = _controller!.value;

      if (v.position > _maxPosition) _maxPosition = v.position;

      if (_buffering.shouldEmit(v.isBuffering) && !_bufferingCtrl.isClosed) {
        _bufferingCtrl.add(v.isBuffering);
      }

      if (_playing.shouldEmit(v.isPlaying) && !_playingCtrl.isClosed) {
        _playingCtrl.add(v.isPlaying);
      }

      if (_duration.shouldEmit(v.duration) && !_durationCtrl.isClosed) {
        _durationCtrl.add(v.duration);
      }

      if (_position.shouldEmit(v.position) && !_positionCtrl.isClosed) {
        _positionCtrl.add(v.position);
      }

      // Edge-triggered: re-evaluated only when `isCompleted` actually flips.
      // `video_player` clears it on any seek, so a genuine end followed by a
      // seek correctly emits again later.
      if (_completed.shouldEmit(v.isCompleted) && v.isCompleted) {
        switch (_completionVerdict(v)) {
          case CompletionVerdict.resumeFromLastPosition:
            // Do NOT emit `onCompleted` for a fake completion: the app would
            // treat it as the lecture finishing. Seek back and keep playing
            // instead.
            _scheduleSpuriousEndRecovery(v.duration);
          case CompletionVerdict.suppress:
            // A resume is already in flight for this position; let it play out.
            break;
          case CompletionVerdict.genuineEnd:
            if (!_completedCtrl.isClosed) _completedCtrl.add(true);
        }
      }

      if (v.hasError && _error.shouldEmit(v.errorDescription ?? '')) {
        if (!_errorCtrl.isClosed) _errorCtrl.add(v.errorDescription);
      }
    } catch (e, s) {
      // Previously swallowed by `catch (_) {}`, which hid every adapter
      // failure including the ones that cause the player to wedge.
      projectLogger.e("VideoPlayerAdapter update failed: $e\n$s");
    }
  }

  /// Whether the current `stopped` state is a real end of media.
  CompletionVerdict _completionVerdict(VideoPlayerValue v) =>
      classifyCompletion(
        maxPosition: _maxPosition,
        duration: v.duration,
        recoveryInFlight: _recoveringFromSpuriousEnd,
        lastRecoveryAttemptPosition: _lastRecoveryAttemptPosition,
        slack: _completionSlack,
      );

  void _scheduleSpuriousEndRecovery(Duration totalDuration) {
    if (_recoveringFromSpuriousEnd) return;
    final resumeAt = _maxPosition;
    _lastRecoveryAttemptPosition = resumeAt;
    projectLogger.w(
      "Playback stopped at ${resumeAt.inSeconds}s of "
      "${totalDuration.inSeconds}s - treating as a transport error, resuming",
    );
    _recoveringFromSpuriousEnd = true;
    unawaited(() async {
      try {
        await _controller?.seekTo(resumeAt);
        await _controller?.play();
      } catch (e) {
        projectLogger.e("Spurious-completion recovery failed: $e");
      } finally {
        _recoveringFromSpuriousEnd = false;
      }
    }());
  }

  @override
  Future<void> open(String url, {Duration? start}) async {
    await _controller?.dispose();
    _maxPosition = Duration.zero;
    _recoveringFromSpuriousEnd = false;
    _lastRecoveryAttemptPosition = null;
    // Every channel must forget its previous value. Switching between
    // renditions of the same lecture reports an identical duration and an
    // identical resume position, so without this nothing would be emitted at
    // all and any load-completion logic driven by these events would never run.
    _resetDedup();
    _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller!.addListener(_onControllerUpdate);
    var init = _controller!.initialize();
    if (initializeTimeout != null) {
      init = init.timeout(initializeTimeout!);
    }
    await init;
    _isInitialized = true;
    if (start != null && start > Duration.zero) {
      await _controller!.seekTo(start);
      if (start > _maxPosition) _maxPosition = start;
    }
  }

  void _resetDedup() {
    _playing.reset();
    _duration.reset();
    _position.reset();
    _buffering.reset();
    _completed.reset();
    _error.reset();
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
    await _bufferingCtrl.close();
  }
}
