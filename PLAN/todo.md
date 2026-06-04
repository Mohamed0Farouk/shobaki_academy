# Shobaki Academy - Implementation Todo

## 1. macOS Player Quality Control ✅

| # | File | Change | Status |
|---|------|--------|--------|
| 1a | `controller/macos_player_adapter.dart:56-64` | Add try-catch to `_onControllerUpdate`, check stream closed before adding | ✅ |
| 1b | `controller/watching_page_vdocipher_controller.dart:84-86` | Remove 300ms delay hack | ✅ |
| 1c | `view/sub/macos_video_controls.dart` | Replace private `PlayerNotifier` import with local `_ControlsNotifier`, add null guards for `_chewieCtrl`/`vpc` | ✅ |
| 1d | `view/sub/vdo_video_player.dart:32-33` | Guard `_nativeCtrl` with `Platform.isMacOS` | ✅ |
| 1e | `view/sub/vdo_video_player.dart:60` | Guard quality worker with `Platform.isMacOS` | ✅ |

## 2. Desktop White Space — Fill Height Layout ✅

| # | File | Change | Status |
|---|------|--------|--------|
| 2a | `view/topics/topics_page.dart` | Restructure: phone → `SafeArea > SingleChildScrollView`, desktop → `Column > Expanded > SingleChildScrollView` with fluid `ConstrainedBox(maxWidth: 1400)`. Remove `Center`, use `MainAxisAlignment.start` | ✅ |
| 2b | `view/settings.dart` | Same restructure with `ConstrainedBox(maxWidth: 800)` | ✅ |
| 2c | `view/results/results_page.dart` | Same restructure, extracted search bar & sections | ✅ |
| 2d | `view/enrolled_topics/enrolled_topics.dart` | Remove `SafeArea` wrapper on desktop, keep on phone | ✅ |

## 3. iPhone Landscape → Mobile Layout ✅

Already handled by width-based breakpoints. iPhone portrait (430px) = phone layout. iPhone landscape (932px) = tablet layout (now fixed to not have whitespace/overflow thanks to fluid widths).

## 4. iPad Full Screen ✅

| # | File | Change | Status |
|---|------|--------|--------|
| 4a | `ios/Runner/Info.plist` | Add `UIRequiresFullScreen = true` to prevent iPad Slide Over | ✅ |

## 5. iPad → Same Layout as Desktop ✅

| # | File | Change | Status |
|---|------|--------|--------|
| 5a | `view/home.dart:323-325` | Remove sidebar auto-collapse (600-1400px range) — sidebar starts expanded on tablets | ✅ |
| 5b | `view/topics/topics_page.dart:35-37` | Replace fixed `contentWidth` with fluid `ConstrainedBox(maxWidth: 1400)` — no separate tablet width | ✅ |

## 6. Orientation ✅

| # | File | Change | Status |
|---|------|--------|--------|
| 6a | `view/home.dart:326-338` | Remove `SystemChrome.setPreferredOrientations` block — all orientations allowed freely | ✅ |

## 7. Supporting Changes ✅

| # | File | Change | Status |
|---|------|--------|--------|
| 7a | `utils/constants.dart` | Add `contentMaxWidth = 1400.0` | ✅ |

## Device Layout Summary

| Device | Orientation | Layout | Sidebar | Content |
|--------|:-----------:|:------:|:-------:|:-------:|
| iPhone | Portrait | Phone (bottom nav) | None | Full width, scrollable, top-aligned |
| iPhone | Landscape | Tablet (sidebar) | Expanded | Fluid max-width 1400, fills height |
| Android phone | Portrait | Phone (bottom nav) | None | Full width, scrollable, top-aligned |
| Android phone | Landscape | Tablet (sidebar) | Expanded | Fluid max-width 1400, fills height |
| iPad | Any | Desktop (sidebar) | Expanded | Fluid max-width 1400, fills height |
| Windows/Mac | Any | Desktop (sidebar) | Expanded | Fluid max-width 1400, fills height |
