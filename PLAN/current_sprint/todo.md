# Current Sprint — Layout Redesign: Header + Responsive Two-Column Layout

## Tasks
- [x] 🔥 **Restore exact primary color** — `lib/theme.dart`: Added `primary: primaryColor` to `ColorScheme.fromSeed()` to preserve `0xFF00A8E8` instead of using the generated tonal palette shade
- [x] 🔥 **Replace horizontal scroll with grid** — `lib/view/topics/topic_content_page.dart`: Replaced `ListView.builder(scrollDirection: Axis.horizontal)` + fixed-height `SizedBox` with unified `Wrap`-based adaptive grid in both `_topicDetails` and `_parentTopicDetails`. Removed unused `extentions.dart` import.
- [x] 🔥 **Fix infinite height layout crash** — `lib/model/card_model.dart`: Changed `StackFit.expand` to `StackFit.loose` in `_SimpleCard` to prevent `Wrap`'s infinite height constraints from propagating through `Stack(expand)` to children, which caused `BoxConstraints forces an infinite height` error
- [x] 🔥 **Adjust grid breakpoints for tablets** — Changed from `<400→2, <600→3, <900→4, else→5` to `<500→2, <1000→3, else→4` — gives wider cards (~300-380px vs 233-290px) on tablet-width screens
- [x] 🔥 **Remove extra locked card spacing** — Removed `if (isLocked) const SizedBox(height: 48)` from `card_model.dart:259` — locked cards no longer have empty height behind the overlay
- [x] 🔥 **Reduce post-Wrap spacing** — Changed `SizedBox(24)` to `SizedBox(16)` after both Wrap grids to tighten bottom margin
- [x] 🔥 **Simplify `_buildHeader`** — Removed the solid primary-color bar variant (`isWide >= 700`). Always uses Stack with image + gradient overlay. Added `BorderRadius.circular(16)`. Accepts optional `height` parameter.
- [x] 🔥 **Responsive two-column layout** — Created `_buildContentLayout` shared by `_topicDetails`/`_parentTopicDetails`. On >=800px: left column (flex 2) = header + details card, right column (flex 3) = section title + Wrap grid. On <800px: vertical layout preserved.
- [x] 🔥 **4:3 header aspect ratio in landscape** — Header height in wide layout calculated dynamically based on left column width × ¾, clamped between 200-360px.
- [x] 🔥 **Removed unused `constants.dart` import** — `AppConstants.cardAspectRatio` was only used by the removed colored bar variant.
- [x] 🔥 **flutter analyze** — 0 errors, 0 warnings (1 pre-existing warning: `RxMap.value` in `otp_page.dart`)

## Grid Column Breakpoints (topic content page)
- `< 500` → 2 columns
- `< 1000` → 3 columns
- `else` → 4 columns

## Changes Summary
| File | Change |
|------|--------|
| `lib/theme.dart:13` | Added `primary: primaryColor` to `ColorScheme.fromSeed()` |
| `lib/model/card_model.dart:250` | `StackFit.loose` (was `expand`) |
| `lib/model/card_model.dart:259` | Removed `if (isLocked) const SizedBox(height: 48)` |
| `lib/view/topics/topic_content_page.dart:155-169` | Lectures grid breakpoints: 2/3/4 columns |
| `lib/view/topics/topic_content_page.dart:242-257` | Sub-topics grid breakpoints: 2/3/4 columns |
| `lib/view/topics/topic_content_page.dart:172,260` | Post-Wrap spacing: `SizedBox(16)` (was `SizedBox(24)`) |
| `lib/view/topics/topic_content_page.dart:14` | Removed unused `constants.dart` import |
| `lib/view/topics/topic_content_page.dart:342-391` | `_buildHeader` simplified: always Stack+gradient, rounded corners, optional height |
| `lib/view/topics/topic_content_page.dart:170-340` | `_buildContentLayout` added: responsive two-column layout, 4:3 header in landscape |
