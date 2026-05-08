# Al Shobaki Academy - Refactoring Plan

## Overview
E-learning Flutter app (Arabic/RTL) using GetX + Supabase. Modern UI overhaul targeting Apple-style design language.

## Project Status
- **State Management:** GetX
- **Backend:** Supabase
- **Font:** Almarai (Google Fonts)
- **Primary:** #00A8E8 | **Background:** #FFFBF5 (cream)
- **Target:** Android, iOS, Windows, macOS
- **Analyze:** 0 errors, 0 warnings, 51 info issues (down from ~102)

---

## ✅ Completed (Phase 1 — Responsive Foundation)

- `lib/utils/constants.dart` — Breakpoints, sizing, aspect ratio constants
- `lib/utils/responsive_utils.dart` — 3-tier device detection (phone/tablet/desktop)
- `lib/utils/image_utils.dart` — Shimmer loading, error handling, responsive sizing
- `lib/view/home.dart` — 3-tier responsive: phone (bottom nav), tablet (sidebar 200/70px), desktop (260/75px)
- `lib/model/card_model.dart` — 4:3 aspect ratio, removed unused `description` field, compact padding
- All 6 content pages — 4:3 ratio, BoxFit.cover, ImageUtils integration
- Dead code cleanup (deleted `webview_model.dart`, `paintdripping_container.dart`)

---

## ✅ Phase 2 — UI Overhaul (Complete)

### Direction
**Apple-style** — clean, minimal, editorial feel with premium typography and subtle depth.

### What Was Done

| File | Change |
|------|--------|
| `lib/theme.dart` | Material 3 with `ColorScheme.fromSeed`, `cardShadow`/`cardShadowLifted` static members, simplified button/input/card themes, removed `Colors.blue.shade*` hardcodes |
| `lib/model/card_model.dart` | Apple-style `_SimpleCard`: title overlaid on image with gradient, `BackdropFilter` blur for locked state, hover scale 1.02 + shadow lift via `AnimationController` (300ms), thin divider + text/arrow action row, optional `onTap` param |
| `lib/view/topics/topics_page.dart` | Removed `_HoverableCard` (220+ lines), replaced with `CardModel`, `LayoutBuilder` sidebar-aware grid |
| `lib/view/enrolled_topics/enrolled_topics.dart` | Removed `_HoverableTopicCard` (190+ lines), replaced with `CardModel`, `LayoutBuilder` sidebar-aware grid |
| `lib/view/results/results_page.dart` | Removed `_topicCardWithData` (50+ lines), replaced with `CardModel`, `FadeInUp` entrance animations |
| `lib/view/auth/sign_up_page.dart` | Replaced inline form with website redirect (`https://alshobakiacademy.com/signup`) |
| `lib/view/topics/topic_content_page.dart` | Clean hero header, compact info pills (replaced Chips), `Container+cardShadow` cards (replaced `Card(elevation:2)`) |
| `lib/view/settings.dart` | Sectioned cards with theme colors, `AppTheme.cardShadow`, `ListTile` rows, removed all unused dialogs/helpers |
| `lib/view/auth/login_page.dart` | Subtle gradient orbs (replaced solid circles), theme colors (replaced `Colors.grey`), theme defaults for inputs/buttons |
| `lib/view/auth/forgot_password_page.dart` | Gradient orb, `theme.colorScheme.error`, theme defaults for input/button |
| `lib/view/auth/otp_page.dart` | Gradient orb, consolidated button patterns, theme defaults, cleaned pin theme colors |

### Fixes & Cleanup
- **settings.dart** — Removed duplicate `_SettingsPageState` class (was breaking the build)
- **answers.dart** — Fixed broken `AppTheme.surfaceColor` reference
- **withOpacity → withValues(alpha:)** — Replaced all 28+ deprecated calls across 8 files
- **flutter analyze** — 0 errors, 0 warnings, 51 info issues (down from ~102)

### Keep Unchanged
- Books page (`lib/view/books.dart`) — user confirmed "feels good"

---

## 📋 Future Considerations
- Fix remaining 51 info issues (mostly `BuildContext` across async gaps, `print` calls, and pre-existing `RxMap.value` usage)
- Potential Phase 3: animations, transitions, loading states, onboarding flow
