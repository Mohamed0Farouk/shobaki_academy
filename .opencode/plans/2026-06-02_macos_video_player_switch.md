# Plan: Use video_player + Chewie on macOS, media_kit everywhere else

## Goal
Replace media_kit (mpv) on macOS with video_player (AVFoundation) + Chewie to avoid the Monterey `m_config_cache_from_shadow` SIGABRT crash. Keep media_kit for all other platforms.

## Architecture

```
lib/controller/
  player_adapter.dart              ← IPlayerAdapter interface
  media_kit_player_adapter.dart    ← wraps media_kit::Player
  macos_player_adapter.dart        ← wraps video_player::VideoPlayerController
  watching_page_vdocipher_controller.dart ← uses IPlayerAdapter

lib/view/sub/
  vdo_video_player.dart            ← Platform.isMacOS → Chewie, else media_kit Video
```

## Step 1: Add dependencies

**File: `pubspec.yaml`** (line 57-58 area)

Add after `media_kit_libs_video`:
```yaml
  video_player: ^2.11.1
  chewie: ^1.10.0
```

Then run: `flutter pub get`

## Step 2: Create `lib/controller/player_adapter.dart`

Abstract interface that both player adapters implement:

```dart
import 'dart:async';

abstract class IPlayerAdapter {
  // State
  bool get isPlaying;
  Duration get position;
  Duration get duration;
  bool get isCompleted;
  String? get error;
  bool get isInitialized;

  // Streams for reactive listeners
  Stream<bool> get onPlayingChanged;
  Stream<Duration> get onDurationChanged;
  Stream<bool> get onCompleted;
  Stream<String?> get onError;
  Stream<Duration> get onPositionChanged;

  // Methods
  Future<void> open(String url, {Duration? start});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setRate(double rate);
  Future<void> stop();
  Future<void> dispose();
}
```

## Step 3: Create `lib/controller/media_kit_player_adapter.dart`

Wraps `Player` from `package:media_kit/media_kit.dart`:

```dart
import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'player_adapter.dart';

class MediaKitPlayerAdapter implements IPlayerAdapter {
  final Player _player = Player();

  // State
  @override bool get isPlaying => _player.state.playing;
  @override Duration get position => _player.state.position;
  @override Duration get duration => _player.state.duration;
  @override bool get isCompleted => _player.state.completed;
  @override String? get error => null; // tracked via stream
  @override bool get isInitialized => true; // always ready after creation

  // Streams
  @override Stream<bool> get onPlayingChanged => _player.stream.playing;
  @override Stream<Duration> get onDurationChanged => _player.stream.duration;
  @override Stream<bool> get onCompleted => _player.stream.completed;
  @override Stream<String?> get onError => _player.stream.error.map((e) => e.toString());
  @override
  Stream<Duration> get onPositionChanged => _player.stream.position;

  // Methods
  @override
  Future<void> open(String url, {Duration? start}) async {
    await _player.open(Media(url, start: start));
  }

  @override Future<void> play() => _player.play();
  @override Future<void> pause() => _player.pause();
  @override Future<void> seek(Duration position) => _player.seek(position);
  @override Future<void> setRate(double rate) => _player.setRate(rate);
  @override Future<void> stop() => _player.stop();
  @override Future<void> dispose() => _player.dispose();
}
```

## Step 4: Create `lib/controller/macos_player_adapter.dart`

Wraps `VideoPlayerController` from `package:video_player/video_player.dart`:

```dart
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'player_adapter.dart';

class MacOSPlayerAdapter implements IPlayerAdapter {
  VideoPlayerController? _controller;
  final StreamController<bool> _playingCtrl = StreamController<bool>.broadcast();
  final StreamController<Duration> _durationCtrl = StreamController<Duration>.broadcast();
  final StreamController<bool> _completedCtrl = StreamController<bool>.broadcast();
  final StreamController<String?> _errorCtrl = StreamController<String?>.broadcast();
  final StreamController<Duration> _positionCtrl = StreamController<Duration>.broadcast();

  bool _isInitialized = false;
  bool _isDisposed = false;

  VideoPlayerController? get controller => _controller;

  @override bool get isPlaying => _controller?.value.isPlaying ?? false;
  @override Duration get position => _controller?.value.position ?? Duration.zero;
  @override Duration get duration => _controller?.value.duration ?? Duration.zero;
  @override bool get isCompleted => _controller?.value.isCompleted ?? false;
  @override String? get error => _controller?.value.errorDescription;
  @override bool get isInitialized => _isInitialized;

  @override Stream<bool> get onPlayingChanged => _playingCtrl.stream;
  @override Stream<Duration> get onDurationChanged => _durationCtrl.stream;
  @override Stream<bool> get onCompleted => _completedCtrl.stream;
  @override Stream<String?> get onError => _errorCtrl.stream;
  @override Stream<Duration> get onPositionChanged => _positionCtrl.stream;

  void _onControllerUpdate() {
    if (_isDisposed || _controller == null) return;
    final v = _controller!.value;
    _playingCtrl.add(v.isPlaying);
    _durationCtrl.add(v.duration);
    _positionCtrl.add(v.position);
    if (v.isCompleted) _completedCtrl.add(true);
    if (v.hasError) _errorCtrl.add(v.errorDescription);
  }

  @override
  Future<void> open(String url, {Duration? start}) async {
    // Dispose old controller if any
    await _controller?.dispose();

    _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller!.addListener(_onControllerUpdate);

    await _controller!.initialize();
    _isInitialized = true;

    if (start != null && start > Duration.zero) {
      await _controller!.seekTo(start);
    }
  }

  @override Future<void> play() => _controller?.play() ?? Future.value();
  @override Future<void> pause() => _controller?.pause() ?? Future.value();
  @override
  Future<void> seek(Duration position) => _controller?.seekTo(position) ?? Future.value();

  @override
  Future<void> setRate(double rate) => _controller?.setPlaybackSpeed(rate) ?? Future.value();

  @override Future<void> stop() {
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
```

## Step 5: Refactor `watching_page_vdocipher_controller.dart`

### Changes needed:

**Imports (lines 1-12):**
- Replace `import 'package:media_kit/media_kit.dart';` and `import 'package:media_kit_video/media_kit_video.dart';` with `import 'player_adapter.dart';`
- Add `import 'dart:io' show Platform;` (already present at line 3)

**Fields (lines 39-40):**
- Replace `late final Player player;` and `late final VideoController videoController;`
- With `late final IPlayerAdapter player;`
- Add `final RxBool isMacOS = Platform.isMacOS.obs;` (for widget to know)

**onInit (lines 75-87):**
```dart
@override
Future<void> onInit() async {
  super.onInit();
  if (Platform.isMacOS) {
    player = MacOSPlayerAdapter();
  } else {
    player = MediaKitPlayerAdapter();
  }
  _isMacOS = Platform.isMacOS;
  _initStreams();
  if (!Platform.isMacOS) { // only media_kit needs VideoController
    // videoController is no longer exposed; widget checks Platform
  }
  await _loadUser();
  if (Platform.isMacOS) {
    await Future.delayed(const Duration(milliseconds: 300));
  }
  await _initializePlayer();
  _startTracking();
  if (!logInitialized) _createInitialLog();
}
```

**Note:** Remove `videoController` entirely. The widget will create its own `VideoController` or `ChewieController` from the exposed platform-specific controller (see widget plan).

**Alternative approach — expose platform controller for the widget:**
- Add a getter `dynamic get platformController => Platform.isMacOS ? (player as MacOSPlayerAdapter).controller : ...`
- Or better: add `VideoPlayerController? get macosController => (player as? MacOSPlayerAdapter)?.controller;`
- And `VideoController? get mediaKitVideoController => ...` for media_kit

Actually, cleaner approach: the widget creates its own adapters. Let me think...

The widget needs:
- For media_kit: `VideoController` (wraps `Player`) to pass to `Video()` widget
- For macOS: `VideoPlayerController` to pass to `Chewie()` widget

Best approach: In the controller, expose the raw player for each platform:

```dart
// In controller fields:
MediaKitPlayerAdapter? get mediaKitPlayer =>
    player is MediaKitPlayerAdapter ? player as MediaKitPlayerAdapter : null;
MacOSPlayerAdapter? get macosPlayer =>
    player is MacOSPlayerAdapter ? player as MacOSPlayerAdapter : null;
```

In widget:
```dart
if (Platform.isMacOS) {
  final macosCtrl = ctrl.macosPlayer!.controller!;
  Chewie(
    controller: ChewieController(videoPlayerController: macosCtrl, ...)
  );
} else {
  final mediaKitCtrl = ctrl.mediaKitPlayer!;
  Video(
    controller: VideoController(mediaKitCtrl.player),
    ...
  );
}
```

Wait, `VideoController` in media_kit takes a `Player` directly:
```dart
VideoController(ctrl.mediaKitPlayer!._player)
```
But `_player` is private. So we need a public getter.

Let me adjust: expose the raw player reference.

**For MediaKitPlayerAdapter**, add:
```dart
Player get nativePlayer => _player;
```

**For MacOSPlayerAdapter**, add:
```dart
VideoPlayerController? get nativeController => _controller;
```

This keeps abstraction while allowing widget access.

**`_initStreams` (lines 89-108):**
Replace all `player.stream.*` with the adapter's `.on*` streams:
```dart
void _initStreams() {
  _durationSub = player.onDurationChanged.listen((d) {
    if (d.inSeconds > 0) {
      _videoDurationSeconds ??= d.inSeconds;
    }
  });
  _playingSub = player.onPlayingChanged.listen((playing) {
    if (playing) {
      _onPlay();
    } else {
      _onPause();
    }
  });
  _completedSub = player.onCompleted.listen((completed) {
    if (completed) _onPause();
  });
  _errorSub = player.onError.listen((error) {
    if (error != null) projectLogger.e("Player error: $error");
  });
}
```

**`_initializePlayer` (lines 188-213):**
Replace `player.open(Media(playUrl))` with `player.open(playUrl)`

**`switchQuality` (lines 252-278):**
Replace `player.open(Media(qualities[index].url, start: position))` with `player.open(qualities[index].url, start: position)`

**`setPlaybackSpeed` (line 280-283):**
Unchanged — `player.setRate(speed)` already matches the interface.

**`seekRelative` (lines 285-291):**
Replace `player.state.position` → `player.position`, `player.state.duration` → `player.duration`, `player.seek()` → `player.seek()`

**`stopTracking` (line 463-466):**
Replace `player.stop()` with `player.stop()` (already matches)

**`cleanup` (line 471-477):**
Replace `player.dispose()` with `player.dispose()` (already matches)

## Step 6: Refactor `vdo_video_player.dart`

**Imports (lines 1-5):**
Add:
```dart
import 'dart:io' show Platform;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
```

**Build method (lines 46-299):**
Replace the entire body with a platform-conditional widget tree:

### For macOS (Platform.isMacOS):
```dart
// Get macOS controller
final macosCtrl = ctrl.player as MacOSPlayerAdapter;
final videoCtrl = macosCtrl.nativeController!;

if (!ctrl.player.isInitialized) {
  return const Center(child: CircularProgressIndicator());
}

return Chewie(
  controller: ChewieController(
    videoPlayerController: videoCtrl,
    aspectRatio: 16 / 9,
    autoPlay: true,
    allowFullScreen: true,
    allowPlayPause: true,
    showControlsOnInitialize: true,
    placeholder: const Center(child: CircularProgressIndicator()),
    additionalOptions: const [],
    errorBuilder: (ctx, msg) => Center(
      child: Text(msg, style: const TextStyle(color: Colors.white)),
    ),
  ),
);
```

Above or below Chewie, wrap with the custom overlay (quality selector, skip buttons, speed button) — same as the existing Stack with Positioned quality chip.

### For non-macOS:
Keep the existing implementation as-is, but replace `Video(controller: ctrl.videoController)` with:
```dart
final mediaKitCtrl = ctrl.player as MediaKitPlayerAdapter;
// ...
Video(
  controller: VideoController(mediaKitCtrl.nativePlayer);
  // ...
)
```

## Step 7: Update `main.dart` (optional)

**File: `lib/main.dart`** line 25 area:

`MediaKit.ensureInitialized()` is fine to keep — it's harmless on macOS (only initializes unused native bindings). No change needed unless you want to skip it on macOS:

```dart
if (!Platform.isMacOS) {
  MediaKit.ensureInitialized();
}
```

## Step 8: macOS entitlements

No changes needed. `com.apple.security.network.client` is already enabled in both `DebugProfile.entitlements` and `Release.entitlements`.

## Step 9: Podfile (optional)

The mpv v0.6.3 workaround in `macos/Podfile` can be left as-is (it won't affect video_player) or removed for cleanliness. If removed, delete lines 38-88.

## Testing

1. Build on macOS: `flutter build macos`
2. Run on macOS Monterey — verify no crash
3. Run on macOS Sonoma — verify no regression  
4. Test on Android/iOS/Windows/Linux — verify media_kit still works
5. Test HLS playback, quality switching, speed, seek on both platforms
6. Verify Supabase logging still works correctly

## Files to modify/create

| Action | File |
|--------|------|
| Edit | `pubspec.yaml` — add video_player + chewie |
| Create | `lib/controller/player_adapter.dart` |
| Create | `lib/controller/media_kit_player_adapter.dart` |
| Create | `lib/controller/macos_player_adapter.dart` |
| Edit | `lib/controller/watching_page_vdocipher_controller.dart` — use IPlayerAdapter |
| Edit | `lib/view/sub/vdo_video_player.dart` — platform-conditional rendering |
| Optional | `lib/main.dart` — conditional MediaKit.ensureInitialized() |
| Optional | `macos/Podfile` — remove mpv workaround |
