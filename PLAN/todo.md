# UI Overhaul Todo

## Priority Legend
🔥 Hot (must do) | ⚡ High | 📐 Medium | 💅 Polish

---

### Foundation
- [x] ⚡ **Evolve theme** — `lib/theme.dart`: Material 3 with `ColorScheme.fromSeed`, `cardShadow`/`cardShadowLifted` static members, simplified button/input/card themes, removed `Colors.blue.shade*` hardcodes

### Core: Card System
- [x] 🔥 **Redesign `_SimpleCard`** — `lib/model/card_model.dart`: Apple-style title overlaid on image with gradient, `BackdropFilter` blur for locked state, hover scale 1.02 + shadow lift via `AnimationController` (300ms), thin divider + text/arrow action row, optional `onTap` param

### Pages: Use Unified Card
- [x] 🔥 **topics_page.dart** — Removed `_HoverableCard` (220+ lines), replaced with `CardModel(type: CardTypes.topic)`, added `LayoutBuilder` sidebar-aware grid column count, tablet-aware padding
- [x] 🔥 **enrolled_topics.dart** — Removed `_HoverableTopicCard` (190+ lines), replaced with `CardModel(type: CardTypes.enrolledTopic)`, `LayoutBuilder` sidebar-aware grid, recommended badge preserved via `Stack`
- [x] 🔥 **results_page.dart** — Removed `_topicCardWithData` (50+ lines) with asymmetric border radius, replaced with `CardModel(type: CardTypes.exam/homework)`, added `FadeInUp` entrance animations

### Remove Sign Up
- [x] ⚡ **sign_up_page.dart** — Replaced full inline form with redirect page that opens `https://alshobakiacademy.com/signup` via `launchUrl` on init, shows status message + back-to-login button
- [x] ⚡ **login_page.dart** — Updated sign-up link target to `/signup` (which now redirects to website)

### Tablet Layout
- [x] 📐 **Fix grid breakpoints** — `LayoutBuilder` + `constraints.maxWidth` in topics/enrolled/results pages; column count: `<400→1, <600→2, <900→3, <1200→4, else→5`; tablet gets 24px horizontal padding vs phone's smaller padding

### Page Overhauls
- [x] ⚡ **topic_content_page.dart** — Removed `Material(elevation: 4)` from header, replaced `Chip`-based info chips with compact primary-tinted pill containers, replaced `Card(elevation: 2)` with `Container + cardShadow`
- [x] 📐 **settings.dart** — Replaced raw `Colors.blue`/`Colors.redAccent` with theme colors, grouped into section cards (Profile, Info, Account, Contact, Links, About), replaced `BoxShadow` hardcodes with `AppTheme.cardShadow`, replaced logout/delete buttons with `ListTile` rows, removed unused dialogs/helpers (`_tile`, `_divider`, `showFirstLaunchDialog`, `showPaymentMethodsDialog`, etc.)

### Auth Polish
- [x] 💅 **login_page.dart** — Replaced solid primary decorative circles with subtle radial gradient orbs, replaced all hardcoded `Colors.grey` with theme-based colors, removed explicit button/input style overrides (uses theme defaults now)
- [x] 💅 **forgot_password_page.dart** — Added subtle gradient orb, replaced `Colors.orange`/`Colors.red` with `theme.colorScheme.error`, replaced raw `OutlineInputBorder()` and custom button styles with theme defaults
- [x] 💅 **otp_page.dart** — Added subtle gradient orb, simplified button styling to use theme, consolidated duplicate button patterns, cleaned up pin theme colors

### Fixes & Cleanup
- [x] 🔥 **settings.dart crash** — Removed duplicate `_SettingsPageState` class that broke the build (undefined `_tile`/`_divider` methods and `expected_token` error)
- [x] 🔥 **withOpacity → withValues(alpha:)** — Replaced all 28+ deprecated `withOpacity()` calls across `home.dart`, `books.dart`, `topic_content_page.dart`, `topics_page.dart`, `answers.dart`, `otp_page.dart`, `lecture_content_page.dart`, `topic_page.dart`
- [x] 🔥 **answers.dart** — Fixed broken `AppTheme.surfaceColor` reference (no longer exists; replaced with inline `Color(0xFFF8F8F8)`)

### Verify
- [x] 🔥 **flutter analyze** — 0 errors, 0 warnings, 51 info issues (down from ~102)
