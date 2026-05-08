# Responsive Design Specification

## Breakpoints

| Device | Width | Navigation | Grid Columns |
|--------|-------|------------|--------------|
| Phone | < 600px | Bottom Navigation | 1-2 |
| Tablet | 600-1199px | Collapsible Sidebar (200/70px) | 2-4 (sidebar-aware) |
| Desktop | ≥ 1200px | Full Sidebar (260/75px) | 4-6 |

## ⚠️ Critical: Sidebar-Aware Grids

### Problem
Grid pages use `MediaQuery.of(context).size.width` which returns **full screen width**. When sidebar is open (200px on tablet), the available content width is `screenWidth - 200px`, causing cramped/crowded grids.

### Fix
Wrap grid areas in `LayoutBuilder` and use `constraints.maxWidth` for column calculations:

```dart
LayoutBuilder(
  builder: (context, constraints) {
    final availableWidth = constraints.maxWidth;
    final crossAxisCount = _columnsForWidth(availableWidth);
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        ...
      ),
      ...
    );
  },
)
```

### Column Count Function
```dart
int _columnsForWidth(double width) {
  if (width < 400) return 1;
  if (width < 600) return 2;
  if (width < 900) return 3;
  if (width < 1200) return 4;
  if (width < 1600) return 5;
  return 6;
}
```

This automatically accounts for sidebar taking space.

## Card Specifications

| Property | Phone | Tablet | Desktop |
|----------|-------|--------|---------|
| Border Radius | 12px | 14px | 16px |
| Shadow | `black(0.06)` blur 12 | same | same |
| Hover Scale | n/a (touch) | 1.02 | 1.02 |
| Title Size | 13px | 14px | 15px |
| Image Ratio | 4:3 | 4:3 | 4:3 |
| Max Card Width | full | 400px | 450px |

## Sidebar Specs

### Desktop Sidebar
```
collapsed: 75px
expanded: 260px
animation: 500ms easeInOutCubic
```

### Tablet Sidebar
```
collapsed: 70px
expanded: 200px
animation: 500ms easeInOutCubic
```

## Usage

```dart
// Detect device type
final device = ResponsiveUtils.getDeviceType(context);

// Card layout
final maxWidth = ResponsiveUtils.cardMaxWidth(context);
final radius = ResponsiveUtils.cardRadius(context);

// Sidebar-aware grid count — use LayoutBuilder instead
// GridView inside LayoutBuilder → constraints.maxWidth
```
