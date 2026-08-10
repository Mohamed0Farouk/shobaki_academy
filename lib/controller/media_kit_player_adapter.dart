import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'player_adapter.dart';

class MediaKitPlayerAdapter implements IPlayerAdapter {
  final Player _player = Player();

  Player get nativePlayer => _player;

  @override
  bool get isPlaying => _player.state.playing;

  @override
  Duration get position => _player.state.position;

  @override
  Duration get duration => _player.state.duration;

  @override
  bool get isCompleted => _player.state.completed;

  @override
  String? get error => null;

  @override
  bool get isInitialized => true;

  @override
  bool get isBuffering => _player.state.buffering;

  @override
  Stream<bool> get onPlayingChanged => _player.stream.playing;

  @override
  Stream<Duration> get onDurationChanged => _player.stream.duration;

  @override
  Stream<bool> get onCompleted => _player.stream.completed;

  @override
  Stream<String?> get onError =>
      _player.stream.error.map((e) => e.toString());

  @override
  Stream<Duration> get onPositionChanged => _player.stream.position;

  @override
  Future<void> open(String url, {Duration? start}) async {
    await _player.open(Media(url, start: start));
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setRate(double rate) => _player.setRate(rate);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
