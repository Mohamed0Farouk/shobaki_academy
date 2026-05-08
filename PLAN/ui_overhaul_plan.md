# UI Overhaul Plan — Phase 2

## Design Language

**Apple-style**: Clean, minimal, editorial. Lots of whitespace, subtle depth, typography-forward.

## Card Design Spec (The Core Change)

### Current Problem

Cards are flat: thumbnail stacked on title stacked on full-width primary-colored bottom bar. Visually heavy, Android-like.

### New Card Anatomy (Apple-style)

```
┌───────────────────────────┐
│  ┌─────────────────────┐  │
│  │                     │  │
│  │    IMAGE 4:3        │  │
│  │  (BoxFit.cover)     │  │
│  │                     │  │
│  │  ░░░░░░░░░░░░░░░░░  │  │ ← gradient: transparent → black60
│  │  ┌───────────────┐  │  │
│  │  │  Title text    │  │  │ ← overlaid, white, bold
│  │  │  max 2 lines   │  │  │
│  │  └───────────────┘  │  │
│  └─────────────────────┘  │
│                           │
│  [grade]   questions/note │ ← metadata row, compact
│                           │
│  ─── thin divider ─────   │
│  action label          ▶  │ ← no full-width colored bar
│                           │
│  LOCKED STATE:            │
│  ┌─────────────────────┐  │
│  │  ░░ blur + lock ░░  │  │ ← BackdropFilter overlay
│  │  "غير متاح"          │  │
│  └─────────────────────┘  │
└───────────────────────────┘
```

### Key Design Decisions

| Before                             | After                                    |
| ---------------------------------- | ---------------------------------------- |
| Full-width primary bottom bar      | Thin divider + text + arrow (subtle)     |
| Title below image                  | Title overlaid on image (magazine-style) |
| Locked: grey container             | Locked: frosted glass blur overlay       |
| Hover: scale 1.06 + rotate 0.02rad | Hover: scale 1.02 + shadow lift only     |
| Shadows: primary tint + black      | Shadows: neutral black opacity           |
| Separate card widgets per page     | Single `_SimpleCard` used everywhere     |

---

## Task 1: Evolve Theme Palette (`lib/theme.dart`)

### Changes

- Replace `ThemeData.light().copyWith(...)` with `ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(...))`
- Remove all raw `Colors.blue.shade*` — use `colorScheme.primary.withValues(alpha:)` instead
- Define `cardShadow`: `black.withValues(alpha:0.06)`, blur 12, offset (0,4)
- Define `cardShadowLifted`: two-layer shadow for hover
- Simplify button style: elevation 0, radius 12, no white border
- Simplify input decoration: grey[100] fill, no border, radius 12
- Remove old `CardThemeData` with elevation/margin (cards self-style)
- Remove old `DividerThemeData`
- Remove old `elevatedButtonTheme` white border

### Files

- `lib/theme.dart`
- `lib/utils/constants.dart` (if needed to add/remove constants)

---

## Task 2: Redesign `_SimpleCard` (`lib/model/card_model.dart`)

### Architecture

Add optional `VoidCallback? onTap` param to `_SimpleCard`. When provided, overrides default nav behavior.

Keep `_SimpleCard` as the single card widget used by all 9 CardModel switch cases.

### Visual Changes

1. **Card wrapper**: White `Container` with `cardRadius()`, `cardShadow`, no border
2. **Image area**: `AspectRatio(4/3)` + `ImageUtils.networkWithFallback` + `BoxFit.cover`
3. **Title overlay**: `Positioned.fill` with gradient (`transparent → black.withValues(alpha:0.6)`) + title text at bottom-left with padding
4. **Metadata row**: Below image. Grade badge (primary tint, rounded) + info chips (icon + text) in a compact `Row`/`Wrap`
5. **Divider**: Thin `Divider(height: 1, thickness: 0.5)` with grey[200]
6. **Action row**: `Row` with text label + arrow icon, primary color, no background. Only shown when `navlabel != null`
7. **Locked overlay**: `ClipRRect` + `BackdropFilter` (blur 6) with `Colors.black38` overlay + lock icon + "غير متاح" text. Only shown when `navlabel == null`
8. **Hover animation**: `AnimationController` 300ms, scale 1.02, swap shadow `cardShadow → cardShadowLifted`, no rotation

### Dependencies

- Remove `dart:convert` import (no longer needed for `_getUserData`... actually keep it since `_navigate` still needs it)
- Keep `_getUserData()` and `_navigate()` as-is

---

## Task 3: Update `topics_page.dart`

### Changes

1. Delete entire `_HoverableCard` class (lines 373-591)
2. Delete `_computeCardWidth` helper (lines 356-367)
3. Delete `_buildModernTopicCard` wrapper (lines 333-351)
4. Replace `_buildResponsiveGrid` and `_buildHorizontalList` to use `CardModel(type: CardTypes.topic)` directly
5. Pass `onTap: () => controller.onSelectTopic(item, widget.inReview)` and `navPage: null` (override default navigation)
6. Keep existing `FadeInUp`/`FadeInRight` entrance animations
7. Keep search bar, section headers, overall page layout

---

## Task 4: Update `enrolled_topics.dart`

### Changes

1. Delete entire `_HoverableTopicCard` class (lines 191-383)
2. Delete `_topicGridCard` wrapper (lines 174-187)
3. Replace grid items with `CardModel(type: CardTypes.enrolledTopic, ...)`
4. Pass `navLabel: 'تصفح المحتوى'`, `onTap: () => controller.onSelectenrolledtopic(item)`
5. Keep `FadeInUp` entrance animations
6. Keep recommended badge logic — either pass via `note` widget or add a small badge widget in the grid item wrapper

---

## Task 5: Update `results_page.dart`

### Changes

1. Delete `_topicCardWithData` method (lines 185-237)
2. Replace with `CardModel(type: CardTypes.exam/homework, ...)`
3. Add `FadeInUp` entrance animations to match other pages
4. Fix `BoxFit.fill` → `BoxFit.cover` (via ImageUtils default)
5. Remove asymmetric border radius (`BorderRadius.only(topRight: 24, bottomLeft: 24)`)

---

## Task 6: Remove Sign Up Page

### Changes

1. In `lib/view/auth/sign_up_page.dart`: Replace entire body with a redirect
   - In `initState`, call `launchUrl('https://alshobakiacademy.com/signup')` future
   - Show a simple "جاري التوجيه..." message
   - After launch, `Get.back()` or `Get.offAll(() => LoginPage())`
2. In `lib/view/auth/login_page.dart` line 220: Change `Get.toNamed('/signup')` to `launchUrl(...)` or redirect page
3. Check routes in `main.dart` for `/signup` route — update or remove

---

## Task 7: Fix Tablet Layout

### Problem

Pages use `MediaQuery.of(context).size.width` which returns full screen width, ignoring the sidebar taking 200px. This causes cramped grids on tablet.

### Fix Strategy

- In each page that renders a grid (topics, enrolled, results), wrap the grid area in `LayoutBuilder`
- Use `constraints.maxWidth` instead of `MediaQuery.of(context).size.width` for grid calculations
- Update `gridCrossAxisCount` in `responsive_utils.dart` to accept optional `availableWidth` param

### Files

- `lib/view/topics/topics_page.dart`
- `lib/view/enrolled_topics/enrolled_topics.dart`
- `lib/view/results/results_page.dart`
- `lib/utils/responsive_utils.dart` (optional)

---

## Task 8: Redesign `topic_content_page.dart`

### Changes

1. **Header** (`_buildHeader`):
   - Remove `Material(elevation: 4)` — use clean hero image
   - Mobile: full-width image with title overlaid (like new card style)
   - Desktop: side-by-side layout (keep existing structure but clean up)
2. **Info chips** (`_infoChip`):
   - Replace `Chip` widget with custom compact pill containers
   - Style: primary tint background, small icon + text, rounded
3. **Details card** (`_detailsCard`):
   - Replace `Card(elevation: 2)` with white container + `cardShadow`
4. **Action buttons** (`_actionButton`):
   - Clean up nested if-else (currently has 3 nearly identical ElevatedButton.icon calls)
   - Extract into single button with dynamic props
5. **Guest placeholder** (`_guestPlaceholder`):
   - Refine colors, use theme instead of raw `Colors.orange`

---

## Task 9: Restructure `settings.dart`

### Changes

1. **Collapsible sections**: Use `ExpansionTile` or custom animated containers:
   - Account (logout, delete)
   - Contact (WhatsApp numbers)
   - Links (privacy, guidelines, payment)
   - About (footer, social)
2. **Theme colors**: Replace all `Colors.blue`, `Colors.redAccent` with theme colors
3. **Remove**: `showFirstLaunchDialog` method (unused)
4. **Clean up**: Footer section — wrap in a cleaner layout
5. **Shadow system**: Use `cardShadow` from theme constants

---

## Task 10: Auth Pages Polish

### Login Page

- Replace decorative circles with `CustomPaint` blob/curve shapes (subtle, layered)
- Keep TypeWriter text, FadeInUp animations
- Update input styling to match new theme (grey[100] fill, no border)

### Forgot Password Page

- Add decorative elements matching login page
- Style text field to match login page
- Add entry animations

### OTP Page

- Style Pinput colors to use theme
- Add consistent spacing with other auth pages

---

## Task 11: Verify

```bash
flutter analyze
# Target: 0 errors, 0 warnings
```

---

## Files to Touch (Complete List)

| File                                            | Action                                                   |
| ----------------------------------------------- | -------------------------------------------------------- |
| `lib/theme.dart`                                | Overwrite — evolved palette, Material 3, refined shadows |
| `lib/utils/constants.dart`                      | Minor — possibly update shadow constants                 |
| `lib/model/card_model.dart`                     | Major redesign — Apple-style card                        |
| `lib/view/topics/topics_page.dart`              | Remove `_HoverableCard`, use CardModel                   |
| `lib/view/enrolled_topics/enrolled_topics.dart` | Remove `_HoverableTopicCard`, use CardModel              |
| `lib/view/results/results_page.dart`            | Remove `_topicCardWithData`, use CardModel               |
| `lib/view/auth/sign_up_page.dart`               | Replace with URL redirect                                |
| `lib/view/auth/login_page.dart`                 | Refine decorative elements                               |
| `lib/view/auth/forgot_password_page.dart`       | Style pass                                               |
| `lib/view/auth/otp_page.dart`                   | Style pass                                               |
| `lib/view/topics/topic_content_page.dart`       | Visual overhaul                                          |
| `lib/view/settings.dart`                        | Restructure with collapsible sections                    |
| `lib/utils/responsive_utils.dart`               | Optional — add `availableWidth` param                    |
| `lib/main.dart`                                 | Check/update `/signup` route                             |
