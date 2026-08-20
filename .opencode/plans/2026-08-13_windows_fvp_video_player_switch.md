# Plan: Switch Windows video player from media_kit to FVP 0.37.3

## Goal
Replace media_kit (mpv) on Windows with `fvp` 0.37.3 (a `video_player` backend based on libmdk/FFmpeg). Keep media_kit for Android/iOS/Linux. Reuse the existing `video_player` adapter path already proven on macOS (Chewie + custom controls) so no feature is lost (logging, quality switching, speed, volume, seek, fullscreen, auto-retry).

## Key facts
- FVP 0.37.3 is not a standalone player; it is a `video_player` platform implementation. On Windows it auto-registers via `dartPluginClass: VideoPlayerRegistrant`. On macOS/Android/iOS it has no `dartPluginClass`, so official AVFoundation/ExoPlayer implementations stay.
- The project already abstracts players behind `IPlayerAdapter` with a working `video_player`-based adapter for macOS. We reuse it on Windows.
- Windows build still bundles media_kit (mpv) libs, unused — accepted to avoid touching mobile/Linux.

## Changes

### 1. pubspec.yaml
- Add `fvp: ^0.37.3`.
- Run `flutter pub get` (regenerates `windows/flutter/generated_plugins.cmake` + `generated_plugin_registrant.cc`).

### 2. Generalize macOS adapter
- Rename `lib/controller/macos_player_adapter.dart` -> `lib/controller/video_player_adapter.dart`; class `MacOSPlayerAdapter` -> `VideoPlayerAdapter`.
- Add optional `initializeTimeout` constructor param. Windows passes ~15s so a hung `initialize()` throws -> existing `_beginLoad` retry logic runs. macOS passes `null` (unchanged behavior).

### 3. lib/main.dart
- `import 'package:fvp/fvp.dart' as fvp;`
- Before `runApp`: `if (Platform.isWindows) fvp.registerWith(options: {'platforms': ['windows']});`
- Tighten `MediaKit.ensureInitialized()` guard to `Platform.isAndroid || Platform.isIOS || Platform.isLinux`.

### 4. lib/controller/watching_page_vdocipher_controller.dart
- `_createPlayer()`: `(Platform.isMacOS || Platform.isWindows) ? VideoPlayerAdapter(initializeTimeout: Platform.isWindows ? const Duration(seconds: 15) : null) : MediaKitPlayerAdapter()`
- Update import to `video_player_adapter.dart`.

### 5. lib/view/sub/vdo_video_player.dart
- `_nativeCtrl` getter: include Windows.
- `_qualityWorker`: fire on macOS OR Windows.
- `_loadingSub`: `if (!loading) _initChewie();` (identity-guarded; no-op on media_kit platforms). Covers Chewie rebuild after reset-on-retry on Windows.
- Build branch: `(Platform.isMacOS || Platform.isWindows) ? _buildChewiePlayer() : _buildMediaKitPlayer()`. `_buildMediaKitPlayer` unchanged for Android/iOS/Linux.

### 6. Rename controls
- `lib/view/sub/macos_video_controls.dart` -> `lib/view/sub/video_player_controls.dart`; class `MacOSVideoControls` -> `VideoControls`. Update imports.

### 7. Windows build
- Clean `build/windows`, `flutter build windows --release`.
- fvp downloads prebuilt libmdk during CMake configure (needs network; mirror via `FVP_DEPS_URL`).

## Feature preservation
| Feature | Where it lives | Status |
|---|---|---|
| Supabase logging (session, 25% threshold, periodic + final logs) | `VideoPlaybackController`, adapter streams | unchanged |
| Quality switching (HLS variant + resume, chip + dialog) | controller + `_initChewie` rebuild | unchanged (macOS path) |
| Speed 0.5-2x, volume, +-10s seek, progress bar | custom controls / `setPlaybackSpeed` | fvp supports |
| Fullscreen, auto-hide, keyboard shortcuts | `VideoControls` | reused on Windows |
| Auto-retry / load watchdog | `_beginLoad` + watchdog + 15s init timeout on Windows | hardened |
| Watermark / protection overlays, session/pause expiry | app-level | untouched |

## Risks & mitigations
- fvp open error may not complete `initialize()` -> 15s timeout throws -> existing retry; error stream also routes to `_onLoadFailed`.
- Chewie must rebuild after retry-reset on Windows -> `_loadingSub` change (identity-guarded).
- Linux build compiles fvp native plugin too (auto `dartPluginClass`), but Linux uses media_kit and never constructs `VideoPlayerController` -> no functional impact.
- macOS untouched: shared adapter only gains an optional (null) timeout param.

## Testing
1. `flutter run -d windows`: HLS playback, quality switch (position preserved), speed, volume, +-10s, fullscreen, keyboard shortcuts.
2. Invalid URL / offline -> 3 auto-retries then error UI with "إعادة المحاولة".
3. Watch 3+ min -> verify Supabase `logs` rows increment (`view_duration_seconds`, `currently_log`), final log on exit.
4. Regression: macOS (AVFoundation), Android/iOS (media_kit).
5. `flutter build windows --release` + MSIX packaging.
