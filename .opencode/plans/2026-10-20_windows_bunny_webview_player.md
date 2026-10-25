# Windows player: Bunny Stream webview (in-app) with fvp fallback

## Goal

Replace the Windows video backend (fvp/video_player/chewie) with the **Bunny Stream embed player** rendered **inside the app** as a Flutter texture, so the existing watermark/security overlays keep covering it. Keep the full tracking pipeline (view logs, session/pause caps) working — driven by JS bridge events with timer-based fallback. If WebView2 is unavailable or the URL is not a Bunny CDN URL, fall back to the current fvp player.

## Key decisions (confirmed with user)

| Decision | Choice |
|---|---|
| Package | `webview_flutter_windows` ^1.3.0 (maintained fork of `webview_windows`; **not** `desktop_webview_window`, which only opens separate OS windows and would escape the watermark overlay) |
| Rendering | Offscreen WebView2 composited as a Flutter `Texture` → watermark `Stack` in `main.dart:96-117` covers it automatically |
| Library ID | Hardcoded constant `699286` |
| Tracking | JS injection into the embed page (play/pause/position/duration) + existing 1 Hz ticker & 60 s heartbeat as fallback |
| Scope | Windows only; macOS keeps fvp/chewie |
| Fallback | Non-Bunny URL or missing WebView2 Runtime → existing `VideoPlayerAdapter` (fvp) path |
| UI | Bunny's own player controls replace custom chewie controls on the webview path; Flutter page keeps AppBar/FAB/session dialogs |
| Manual override | Long-press the AppBar title → confirm dialog → persisted in SharedPreferences key `player_backend` (`'webview'` \| `'fvp'`). Default = webview. Auto-fallback (no WebView2 / non-Bunny URL) ignores the pref and uses fvp for that session. |

## URL mapping (DB value cannot change)

DB stores: `https://vz-d3e667b1-320.b-cdn.net/c285b1e8-81d2-42b6-9a88-eee138c920d6/playlist.m3u8`
Embed loaded in webview: `https://player.mediadelivery.net/embed/699286/c285b1e8-81d2-42b6-9a88-eee138c920d6?autoplay=false&loop=false&muted=false&preload=true&responsive=true`

- Detect Bunny URL: host ends with `.b-cdn.net` and path ends with `/playlist.m3u8` (reuse `isHlsManifestUrl`-style path inspection from `lib/controller/video_quality.dart:54-60`).
- Extract video UUID = second path segment (`c285b1e8-...`).
- Build embed URL with the owning topic's `library_id` (string column on `topics`) and the query params above. No hardcoded default: the id comes from the DB (`parseBunnyLibraryId` normalises the column).

## Files

### New: `lib/controller/bunny_embed.dart`
Pure Dart, testable:
- `int? parseBunnyLibraryId(Object? raw)` — normalises the `topics.library_id` string column; empty/zero/non-numeric → `null`.
- `String? tryBuildBunnyEmbedUrl(String rawUrl, {required int libraryId})` — returns embed URL or `null` when the URL is not a Bunny CDN playlist (→ caller falls back to fvp). `libraryId` is required; there is no fallback constant.
- `String? extractBunnyVideoId(String rawUrl)` — UUID extraction.

### New: `lib/controller/bunny_webview_player_adapter.dart`
`class BunnyWebviewPlayerAdapter implements IPlayerAdapter` (`lib/controller/player_adapter.dart:3-38`), wrapping a `WebviewController`:

- Owns the `WebviewController` (same pattern as `VideoPlayerAdapter.nativeController`) so `vdo_video_player.dart` can render `Webview(controller)` from `(ctrl.player as BunnyWebviewPlayerAdapter).controller`.
- `initialize()`: `getWebViewVersion()` (null → throw / signal fallback), `controller.initialize()`, `setPopupWindowPolicy(deny)`, `setBackgroundColor(Colors.black)`, subscribe `webMessage` + `onLoadError` **before** navigation.
- `open(url)` — takes the **embed URL**, calls `loadUrl`.
- **Injected script** (`addScriptToExecuteOnDocumentCreated`) — runs in top document *and* child frames:
  - MutationObserver finds the `<video>` element (Bunny player may mount it inside a nested iframe or late-create it).
  - Listens: `play`, `pause`, `ended`, `loadedmetadata`, `durationchange`, `timeupdate` (throttled ~1 s), `waiting`, `playing`.
  - Posts `{source:'shobaki', type, playing, position, duration}` upward: child frame → `window.parent.postMessage` → top document → `window.chrome.webview.postMessage`.
  - Top document also registers a command listener (`{source:'shobaki_cmd', action:'pause'|'play'}`) and forwards it into child frames so Dart can force-pause on session expiry.
- Bridges events into `IPlayerAdapter` streams: `onPlayingChanged`, `onPositionChanged`, `onDurationChanged`, `onCompleted` (ended), `onBufferingChanged` (waiting/playing), `onError`.
- Getters: `position`/`duration` from last event; `isBuffering` (true until the first known duration, so the load watchdog keeps extending); `bufferedAhead` = `Duration.zero` (unused on this path).
- Commands (`pause`/`play`/`seek`/`setRate`/`setVolume`) go through `executeScript` with a self-contained deep-video finder script — not `postWebMessage` — so every command is synchronous and its result is observable. `postWebMessage` remains event-only (page → Dart).
- **Timer fallback**: a 5 s Dart timer probes the page with `executeScript` whenever no bridge message has arrived for >8 s since the page reported `navigationCompleted`. The probe reads the real `<video>` state, so it never invents a "playing" state. If the probe also finds nothing, `isBuffering` stays true and the existing load watchdog takes the normal retry path.
- `dispose()`: cancel subscriptions, dispose controller.

### New: `lib/view/sub/bunny_webview_player.dart`
Thin stateful widget: given `BunnyWebviewPlayerAdapter`, renders `Webview(controller)` (with loading spinner until `value.isInitialized`), plus:
- Hide in-page HTML5 fullscreen chrome issues: listen `containsFullScreenElementChanged` → drive `ctrl.isFullScreen` (in-app fullscreen: hide AppBar/FAB; optionally keep `windowManager.setFullScreen` in sync like `vdo_video_player.dart:173-186`).

### Modified: `lib/controller/watching_page_vdocipher_controller.dart`
- `_createPlayer()` (`:158-169`): on `Platform.isWindows`, first check the persisted `player_backend` pref (default webview), WebView2 available (`WebviewController.getWebViewVersion() != null`, probed once in `onInit`) **and** `tryBuildBunnyEmbedUrl(videoUrl) != null` → `BunnyWebviewPlayerAdapter()`; else keep `VideoPlayerAdapter(initializeTimeout: 15s)`.
- Embed-URL mapping lives inside the adapter's `open()` (it accepts the raw DB playlist URL), so `_beginLoad()` needs no change.
- Gates to skip on webview path (`player is BunnyWebviewPlayerAdapter`): `_fetchQualities` (`:352-381`). Stall ladder / governor sampling in `_tickDuration` and `switchQuality` already early-return when `qualities.length <= 1`, which is always true on the webview path; an explicit guard is still added to `switchQuality` for readability. Keep: `_startTracking` timers, `_createInitialLog`, `_tickLogging`, `SessionTracker`, lifecycle observer, `onClose` final flush — all unchanged. (The 25 % `viewed` threshold latch was removed afterwards: the dashboard does not consume `viewed`, and a latch could never come back down from a wrong first-reported duration.)
- Load watchdog (`:241-266`): no change needed. The adapter reports `isBuffering=true` until the first known duration, so the watchdog extends to `_maxLoadWaitSeconds` while the embed boots, and a bridge/probe duration trips `_onMediaLoaded`.
- Session-expiry pause (`_onSessionExpired` `:937-964`) already calls `player.pause()` → `executeScript` pause actually pauses the Bunny player.
- New: `switchPlayerBackend()` — persists `player_backend`, tears the player down through `_resetPlayer()`, clears the rendition list, reloads, and shows a snackbar. Refuses to switch to webview when WebView2 is missing or the URL is not Bunny.

### Modified: `lib/view/sub/vdo_video_player.dart`
- `_nativeCtrl` (`:75-78`) currently assumes `VideoPlayerAdapter` on Windows — guard with `is VideoPlayerAdapter` (webview path returns null).
- `_initChewie` / quality worker (`:108-112`, `:80-98`): no-op on webview path (`_nativeCtrl` is null).
- Build branch (`:239-242`): `Platform.isWindows && ctrl.player is BunnyWebviewPlayerAdapter` → `BunnyWebviewPlayer(key: ValueKey(ctrl.playerGeneration.value), ...)`; the key forces the Obx build to re-read `playerGeneration` and rebuild after a backend switch or player reset. Else existing macOS/Windows chewie branch.
- AppBar title gets an `onLongPress` (Windows only) → confirm dialog → `ctrl.switchPlayerBackend()`.
- Keep: watermark enable/disable (`:123-125`, `:153-155`), PopScope/stopTracking, AppBar, FAB, error overlay + retry button (works against `errorMessage` as today).

### Modified: `pubspec.yaml`
- Add `webview_flutter_windows: ^1.3.0`.
- Bump `sdk:` constraint if needed (package requires Dart 3.12; installed toolchain is 3.12.2 — `sdk: ^3.12.0`).
- Do **not** remove `fvp` / `video_player` / `chewie` (macOS + Windows fallback).

### New tests
- `test/bunny_embed_test.dart`: UUID extraction from the real example URL, rejection of non-Bunny URLs, signed-URL tolerance, embed URL shape.
- Adapter bridge-script unit test optional (pure-Dart event→stream mapping with a fake message source).

## What is intentionally lost on the Windows webview path

- Custom chewie controls / keyboard shortcuts (`video_player_controls.dart`) — Bunny embed has its own controls, quality menu and speed menu.
- In-app quality selector, stall-detection ladder, auto-quality governor — Bunny's player handles ABR itself.
- Resume-after-quality-switch — not applicable (no in-app quality switching).

## Risks & mitigations

1. **Nested iframe in the embed page** — injected script runs in every document (WebView2 `AddScriptToExecuteOnDocumentCreated` applies to child frames); events bubble via `parent.postMessage`; commands fan out from the top document. Verify against the real embed during implementation with `openDevToolsWindow()`.
2. **WebView2 Runtime missing** (older Win10) — `getWebViewVersion()` null → automatic fvp fallback; optionally toast once.
3. **Offscreen capture overhead** (Windows.Graphics.Capture) — test 1080p playback smoothness on a lower-end machine; if unacceptable, revisit.
4. **No DRM** — WebView2 has no Widevine; fine because the same clear HLS URLs play in FFmpeg today.
5. `webview_flutter_windows` popup-offset bug when widget is inset — we render full-bleed in the body; context menus disabled anyway.

## Verification

1. `flutter pub get`; `flutter analyze` clean.
2. `flutter test` — existing suites (`session_tracker_test.dart`, etc.) still pass + new `bunny_embed_test.dart`.
3. `flutter run -d windows` with a real Bunny lecture:
   - Video plays via embed; watermark visible on top and still jumping every 4 s.
    - Pause in the player → `view_duration_seconds` stops advancing; resume → advances (check Supabase `logs` heartbeat).
    - The log row keeps accruing `view_duration_seconds` for the whole session; `viewed` stays `false` (the threshold latch was removed - the dashboard does not consume it).
    - Leaving the page flushes final duration (`onClose`).
   - Session-expiry dialog still pauses the actual playback.
   - Force fallback: open a non-Bunny URL → fvp player path works as before.
   - `library_id` plumbing: a topic with a valid id plays via embed; on Windows a topic with a missing/invalid id shows the "coming soon" dialog, sends the admin WhatsApp report (throttled once per video per app run, skipped for guests) and pops the page without opening any player.
4. macOS build path untouched (code-review the guards only).


## Cross-platform port (2026-10-25) - Android / iOS / macOS

The embed player is now the default backend on every platform that has a
WebView; fvp (Windows/macOS) and media_kit (Android/iOS) remain as fallbacks
for non-Bunny URLs and as the classic pin.

### Dependencies
- Added `webview_flutter: ^4.14.1` (+ explicit `webview_flutter_android`,
  `webview_flutter_wkwebview`). The Windows fork `webview_flutter_windows`
  stays; the two packages are independent (different class names:
  `WebviewController`/`Webview` vs `WebViewController`/`WebViewWidget`).
- Platform floors verified: Android `flutter.minSdkVersion = 24`, iOS Podfile
  `15.0`, macOS `12.0` - all above the plugin minimums. Android manifest keeps
  `hardwareAccelerated` + orientation in `configChanges`; minify stays off.

### Adapter (`bunny_webview_player_adapter.dart`)
- Holds `_win` (fork, Windows) or `_web` (official, Android/iOS/macOS);
  exposed via `windowsController` / `webController`; the view branches on them.
- **Bridge transport feature-detect**: `chrome.webview.postMessage` (Windows)
  else `window.BunnyBridge.postMessage(JSON.stringify(msg))` (mobile channel),
  including the child-frame relay re-post in the top document. Without this
  every message dropped on mobile and `view_duration_seconds` would stay 0.
- Official plugin has no `addScriptToExecuteOnDocumentCreated`: the bridge is
  injected from `onPageStarted` + `onPageFinished` backstop (self-healing via
  `__shobakiBridge` guard + 1 Hz scan).
- `_onBridgeMessage` accepts Map (fork) and JSON String (channel) through
  `asScriptMap`; `asScriptValue`/`asScriptBool` decode all three transports'
  shapes (Windows/iOS parsed values, Android JSON text, double-encoded
  strings) - unit-tested in `test/bunny_webview_bridge_test.dart`.
- `NavigationDelegate`: `onPageStarted/Finished` drive `_pageSettled`,
  main-frame-only `onWebResourceError` feeds the existing Arabic error/retry
  path, `onNavigationRequest` allowlists `*.mediadelivery.net`/`*.b-cdn.net`/
  `*.bunnycdn.com`/`about` on the top frame (parity with the Windows popup
  `deny` policy) via `isAllowedBunnyNavigation` (unit-tested).
- Inline playback is mandatory on iOS/macOS:
  `WebKitWebViewControllerCreationParams(allowsInlineMediaPlayback: true,
  mediaTypesRequiringUserAction: {})`; Android gets
  `setMediaPlaybackRequiresUserGesture(false)` - otherwise WKWebView/WebView
  eject to native fullscreen (watermark escapes) or refuse programmatic
  `play()` (resume intent, `ended` recovery).
- `probeNow()` skips the bridge-silence gate; the controller calls it on
  `AppLifecycleState.resumed` so `SessionTracker`'s re-sync reads the page as
  it is *now*, not the pre-background cached flag.
- `onFullScreenChanged` is Windows-only (empty stream elsewhere); official
  has no fullscreen callback and the platform webview owns its own surface.
- `dispose()` calls `_win?.dispose()`; the official controller has no dispose
  API - its platform view dies with the widget (`playerGeneration` key).

### Controller (`watching_page_vdocipher_controller.dart`)
- `_probeWebViewRuntime`: non-Windows sets `_webviewRuntimeAvailable =
  Platform.isAndroid || isIOS || isMacOS` (Linux stays native).
- `shouldUseBunnyWebview` / `isMissingLibraryId`: dropped the Windows gate -
  the embed is the default everywhere and the missing-`library_id` block
  (WhatsApp + dialog + pop) now applies on all four platforms (user-approved).
- `_createPlayer`: webview check first, then macOS -> fvp (no timeout),
  Windows -> fvp (15 s timeout), else media_kit.
- `retry()`: `_resetPlayer()` also runs on macOS when the player is the
  webview (half-navigated webview needs a fresh controller).
- Logging pipeline untouched: `_createInitialLog` / `_tickLogging` / final
  flush are platform-independent; only `onPlayingChanged` feeds them, which
  is why the bridge transport fix above is the logging-critical change.
  `viewed` stays a constant `false` everywhere.

### View
- `vdo_video_player.dart`: the build branch now checks
  `player is BunnyWebviewPlayerAdapter` **before** the platform check - the
  old order made Android/iOS always build media_kit and would have hidden the
  webview (and crashed its placeholder cast).
  `_buildMediaKitPlayer` guards against the missing-library placeholder
  adapter (`is! MediaKitPlayerAdapter` -> spinner).
- `bunny_webview_player.dart`: `WebViewWidget(controller: webController)` on
  mobile, `ValueListenableBuilder + Webview(windowsController)` on Windows.

### Verification done here (Windows machine)
- `flutter analyze`: 72 pre-existing issues, 0 errors, none in touched files.
- `flutter test`: 253 pass (14 new in `bunny_webview_bridge_test.dart`), 1
  pre-existing failure (stock `widget_test.dart` counter).
- `flutter build windows --release`: OK. `flutter build apk --debug`: OK.
- Not possible on this machine: run on an Android device and build iOS/macOS
  (needs a Mac/Xcode). Device checklist: play -> `logs` row appears; pause/
  background/foreground -> `view_duration_seconds` grows only while playing
  (60 s heartbeat + final flush); rotation survives; watermark covers video;
  retry after airplane mode; missing `library_id` shows dialog + pops.
