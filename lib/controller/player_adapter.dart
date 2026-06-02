import 'dart:async';

abstract class IPlayerAdapter {
  bool get isPlaying;
  Duration get position;
  Duration get duration;
  bool get isCompleted;
  String? get error;
  bool get isInitialized;

  Stream<bool> get onPlayingChanged;
  Stream<Duration> get onDurationChanged;
  Stream<bool> get onCompleted;
  Stream<String?> get onError;
  Stream<Duration> get onPositionChanged;

  Future<void> open(String url, {Duration? start});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setRate(double rate);
  Future<void> setVolume(double volume);
  Future<void> stop();
  Future<void> dispose();
}
