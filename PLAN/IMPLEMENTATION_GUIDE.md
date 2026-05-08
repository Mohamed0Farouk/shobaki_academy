# Implementation Guide — Phase 2 UI Overhaul

## Prerequisites

- Phase 1 complete (responsive utils, image utils, constants)
- `flutter analyze` shows 0 errors

---

## Execution Order

### Step 1: Theme Palette

**File:** `lib/theme.dart`

Replace with Material 3 theme using `ColorScheme.fromSeed(seedColor: Color(0xFF00A8E8))`.

- Remove all `Colors.blue.shade*`
- Define `cardShadow` and `cardShadowLifted` as static members
- Simplify button/input/card themes
- Remove white border from buttons

```bash
flutter analyze  # verify no regressions
```

### Step 2: Apple-Style Card

**File:** `lib/model/card_model.dart`

Redesign `_SimpleCard`:

- Title overlaid on image with gradient backdrop
- Thin divider + text/arrow action row (no full-width colored bar)
- `BackdropFilter` blur for locked state
- Hover: scale 1.02 + shadow lift (AnimationController, 300ms)
- Add optional `VoidCallback? onTap` param

```bash
flutter analyze  # verify
```

### Step 3-5: Unify Cards Across Pages

**Files:**

- `lib/view/topics/topics_page.dart` — remove `_HoverableCard`
- `lib/view/enrolled_topics/enrolled_topics.dart` — remove `_HoverableTopicCard`
- `lib/view/results/results_page.dart` — remove `_topicCardWithData`

Each: replace custom card widget with `CardModel(type: CardTypes.xxx, onTap: ..., ...)`

```bash
flutter analyze  # verify
```

### Step 6: Remove Sign Up Page

**File:** `lib/view/auth/sign_up_page.dart`

Replace with URL redirect on init.
**File:** `lib/view/auth/login_page.dart`
Change sign-up link to redirect to website.

```bash
flutter analyze  # verify
```

### Step 7: Fix Tablet Layout

**Files:** `topics_page.dart`, `enrolled_topics.dart`, `results_page.dart`
**Optional:** `responsive_utils.dart`

Wrap grids in `LayoutBuilder`, use `constraints.maxWidth` for column count.

### Step 8: Topic Content Page

**File:** `topic_content_page.dart`

Hero header, compact chip pills, clean action buttons.

### Step 9: Settings Restructure

**File:** `settings.dart`

Collapsible sections, theme colors, remove dead code.

### Step 10: Auth Polish

**Files:** `login_page.dart`, `forgot_password_page.dart`, `otp_page.dart`

Consistent styling, refined decorative elements.

### Step 11: Final Verify

```bash
flutter analyze
# Target: 0 errors, 0 warnings
```

---

## Testing Checklist

- [ ] Phone (<600px): Bottom nav, 1-2 column grid
- [ ] Tablet (600-1199px): Sidebar 200/70px, 2-3 column grid, no cramping
- [ ] Desktop (≥1200px): Sidebar 260/75px, 4-6 column grid
- [ ] Cards show overlaid title on image
- [ ] Cards have no full-width primary bottom bar
- [ ] Cards have subtle hover scale (1.02) on desktop
- [ ] Locked cards show blur overlay
- [ ] Sign up page redirects to website
- [ ] All pages compile without errors
- [ ] No hardcoded `Colors.blue.shade*` remains
- [ ] Settings page has collapsible sections

## Color Reference

- Primary: `#00A8E8`
- Background: `#FFFBF5`
- Card: White
- Surface: `#FFFBF5`
- Text: `black87` / `black54` / `white`
- Shadows: `black.withValues(alpha:0.06)` / `black.withValues(alpha:0.10)`
