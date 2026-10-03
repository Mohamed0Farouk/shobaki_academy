import 'dart:async';

abstract class IPlayerAdapter {
  bool get isPlaying;
  Duration get position;
  Duration get duration;
  bool get isCompleted;
  String? get error;
  bool get isInitialized;
  bool get isBuffering;

  /// How much media is already downloaded ahead of [position].
  ///
  /// Used to tell a network underrun (buffer drained) apart from a wedged
  /// decoder (buffer full but playhead frozen).
  Duration get bufferedAhead;

  Stream<bool> get onPlayingChanged;
  Stream<Duration> get onDurationChanged;
  Stream<bool> get onCompleted;
  Stream<String?> get onError;
  Stream<Duration> get onPositionChanged;

  /// Emits whenever the player enters or leaves the buffering state.
  ///
  /// Previously buffering was only readable as a polled [isBuffering] bool,
  /// which made mid-playback stalls invisible to the app.
  Stream<bool> get onBufferingChanged;

  Future<void> open(String url, {Duration? start});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setRate(double rate);
  Future<void> setVolume(double volume);
  Future<void> stop();
  Future<void> dispose();
}
