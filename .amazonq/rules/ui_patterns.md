# SplitEx UI Patterns — AI Reference

## Stack & Font
- Flutter + Material 3 (`useMaterial3: true`)
- Font family: `Gilmer` (all weights)
- State: `flutter_riverpod`
- Navigation: `go_router`
- Charts: `fl_chart`

---

## Color System — `AppColors` (`app_colors.dart`)

NEVER hardcode hex values in screens or widgets. Always use these helpers:

```dart
AppColors.success(context)   // green: dark=#4ADE80, light=#16A34A
AppColors.warning(context)   // amber: dark=#FBBF24, light=#D97706
AppColors.error(context)     // cs.error (#EF4444)
AppColors.info(context)      // cs.primary
AppColors.surface(context)
AppColors.surfaceHigh(context)
AppColors.primarySurface(context)   // cs.primary @ 8% opacity
AppColors.textPrimary(context)      // cs.onSurface
AppColors.textSecondary(context)    // cs.onSurface @ 60%
AppColors.textTertiary(context)     // cs.onSurface @ 40%
AppColors.divider(context)          // cs.outlineVariant
AppColors.border(context)           // cs.outline @ 15%
```

### Dashboard accent palette (use these constants in screens)
```dart
const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF4444);
const _kAmber  = Color(0xFFF59E0B);
const _kIndigo = Color(0xFF6366F1);
const _kBlue   = Color(0xFF3B82F6);
const _kTeal   = Color(0xFF14B8A6);
const _kPurple = Color(0xFF8B5CF6);
```

### Chart / category color cycle (8 slots, repeat with `% 8`)
```dart
static const _colors = [
  Color(0xFF6366F1), Color(0xFF22C55E), Color(0xFFF59E0B),
  Color(0xFFEF4444), Color(0xFF14B8A6), Color(0xFF8B5CF6),
  Color(0xFF3B82F6), Color(0xFFF97316),
];
```

### Tinting rule
- Icon container bg: `color.withValues(alpha: 0.12)`
- Row/tile bg light: `color.withValues(alpha: 0.04–0.06)`
- Row/tile bg dark: `color.withValues(alpha: 0.07–0.10)`
- Border: `color.withValues(alpha: 0.12–0.18)`
- Stat card bg light: `color.withValues(alpha: 0.06)`
- Stat card bg dark: `color.withValues(alpha: 0.10)`

---

## Spacing & Radius — `AppSpacing` / `AppRadius` (`app_spacing.dart`)

```dart
AppSpacing.xs   = 4
AppSpacing.sm   = 8
AppSpacing.md   = 12
AppSpacing.base = 16
AppSpacing.lg   = 20
AppSpacing.xl   = 24
AppSpacing.xxl  = 32
AppSpacing.xxxl = 40

AppRadius.sm  = 8
AppRadius.md  = 12
AppRadius.lg  = 16
AppRadius.xl  = 20
AppRadius.xxl = 28
```

Never use raw numeric literals for spacing or radius. Always use these constants.

---

## Typography — `AppTextStyles` (`app_text_styles.dart`)

```dart
AppTextStyles.pageTitle(context)     // 28px w700 letterSpacing:-0.5
AppTextStyles.sectionTitle(context)  // 20px w700
AppTextStyles.sectionHeader(context) // 14px w600
AppTextStyles.body(context)          // 15px w400
AppTextStyles.bodySmall(context)     // 13px w400 onSurface@60%
AppTextStyles.caption(context)       // 11px w400 onSurface@45%
AppTextStyles.label(context)         // 12px w600
AppTextStyles.stat(context)          // 28px w800 letterSpacing:-1.0
AppTextStyles.statSmall(context)     // 18px w700 letterSpacing:-0.5
AppTextStyles.button(context)        // 16px w600 onPrimary
```

### Inline text rules
- List tile title: `fontSize:13, fontWeight:w600, color:cs.onSurface`
- List tile subtitle: `fontSize:11, height:1.4, color:cs.onSurface@50%`
- Amount/value: `fontSize:14, fontWeight:w700, color:<accent>`
- Caption/hint: `fontSize:11, color:cs.onSurface@45%`
- Badge/chip label: `fontSize:9–11, fontWeight:w600, color:<accent>`
- Section label: `fontSize:13, fontWeight:w700`

---

## Screen Scaffold Pattern

Every screen follows this exact structure:

```dart
Scaffold(
  appBar: AppHeader(
    title: 'Screen Title',
    showBack: true,          // detail screens
    showHamburger: true,     // home screen only
    showNotification: false, // false on all non-home screens
  ),
  floatingActionButton: FloatingActionButton.extended(...), // if needed
  body: GradientBody(
    child: ListView(
      padding: const EdgeInsets.all(AppSpacing.base),
      children: [...],
    ),
  ),
)
```

- `GradientBody` wraps every screen body — never skip it.
- `ListView` padding is always `EdgeInsets.all(AppSpacing.base)` or `EdgeInsets.fromLTRB(base, base, base, 100)` when FAB is present.
- Never use `SingleChildScrollView` as the top-level body — use `ListView`.

---

## AppHeader (`app_header.dart`)

```dart
AppHeader(
  title: 'Page Title',
  showBack: true,
  showNotification: false,
  trailing: IconButton(...), // optional right slot
)
```

- Has a gradient background (primary @ 45–55% → primary @ 18%).
- Title is centered, 14px w600.
- Left slot: back arrow or hamburger menu icon in a 40×40 `surfaceContainerHighest` rounded container (radius 12).
- Right slot: notification bell with unread dot, or `trailing`, or empty `SizedBox(width:40)`.
- Notification dot: 8×8 `cs.error` circle with 1.5px white border.

---

## GradientBody (`app_header.dart`)

Wraps the scaffold body with a top-fade gradient from `primary@18%` → scaffold bg.
Always the direct child of `Scaffold.body`. Never nest another gradient inside it.

---

## Cards & Containers — `appCardDecoration(context)`

```dart
Container(
  decoration: appCardDecoration(context),
  padding: const EdgeInsets.all(AppSpacing.base),
  child: ...,
)
```

`appCardDecoration` returns:
- Light: `cs.surface` bg, `cs.outline@8%` border, `radius:AppRadius.xl(20)`, shadow `black@4% blur:12 offset:(0,3)`
- Dark: `cs.surfaceContainerHigh` bg, same border/shadow

Optional `accentColor` tints the shadow.

### Card layout rules
- All content cards use `appCardDecoration` — never raw `Card()` widget.
- Cards are separated by `SizedBox(height: AppSpacing.lg)` (20px).
- Inside a card, sections are separated by `SizedBox(height: AppSpacing.md)` (12px).
- Multiple tiles inside one card are separated by `Divider(height:1, color:cs.outline@8–10%)`.

---

## List Items — `AppFinanceTile` (`app_finance_tile.dart`)

The standard row for all finance lists:

```dart
AppFinanceTile(
  icon: Icons.north_rounded,
  color: AppColors.error(context),   // accent — drives bg, border, icon color
  title: 'Grocery',
  subtitle: 'Food · 12 Jan 2025',
  value: '₹1,200',
  valueColor: cs.onSurface,          // optional override
  detail: 'Expense',                 // optional second line under value
  action: IconButton(...),           // optional trailing widget
  badges: Row(...),                  // optional badge row below subtitle
  onTap: () {},
)
```

Internal anatomy:
- 38×38 icon container: `color@12%` bg, `radius:11`
- Title: 13px w600
- Subtitle: 11px h:1.4 onSurface@50%
- Value: 14px w700, right-aligned
- Tile bg: `color@4%` light / `color@7%` dark, border `color@12%`, radius 14

Never build a custom row tile from scratch — always use `AppFinanceTile`.

---

## Empty States

### Full-screen empty (`AppEmptyState`)
```dart
AppEmptyState(
  icon: Icons.receipt_long_outlined,
  title: 'No transactions yet',
  subtitle: 'Tap + to record your first transaction',
  actionLabel: 'Add Transaction', // optional
  onAction: () {},                // optional
)
```
72×72 icon container, `surfaceContainerHighest` bg, icon @ 30% opacity.

### Inline empty (`AppFinanceEmptyState`)
```dart
AppFinanceEmptyState(
  icon: Icons.swap_horiz_rounded,
  title: 'No transfers yet',
  subtitle: 'Move money between two of your accounts.',
)
```
52×52 icon container. Use inside cards when a list section is empty.

---

## Section Headers — `AppSectionHeader`

```dart
AppSectionHeader(
  title: 'Recent Transactions',
  actionLabel: 'View All',   // optional
  onAction: () {},           // optional
)
```

Renders: 3×14px `cs.primary` accent bar | title 14px w600 | optional pill action button.
Always use this — never write a custom `Row` with a title and a text button.

---

## Stat Cards

### `AppStatCard` — vertical icon→value→label
```dart
AppStatCard(
  icon: Icons.north_rounded,
  value: '₹12,400',
  label: 'Expenses',
  color: AppColors.error(context),
)
```
32×32 icon container, value uses `AppTextStyles.statSmall` in accent color.

### `AppMiniStatCard` — compact 2-column grid card
```dart
AppMiniStatCard(
  icon: Icons.south_rounded,
  value: '₹8,000',
  label: 'Income',
  color: AppColors.success(context),
)
```
Used in pairs: `Row([Expanded(AppMiniStatCard(...)), SizedBox(width:10), Expanded(AppMiniStatCard(...))])`.

---

## Hero Card (`PersonalFinancialStatusCard`)

The large gradient card at the top of the Personal dashboard.

- `BorderRadius.circular(28)`, gradient from `AppTheme.financialHeroColors(...)`.
- Green-teal gradient when balance is positive; red-orange when overspent.
- Decorative blobs: two `BoxShape.circle` containers at `white@5–6%` opacity, positioned off-card edges.
- Big balance number: 42px w800 white, `TweenAnimationBuilder` count-up animation.
- Month nav chips: 34×34 `white@18%` rounded containers.
- Inline chips: `AppHeroChip` — `white@13%` bg, radius 12.
- Savings badge: `white@15%` bg, radius 14, icon + % + label stacked.
- Progress bar: `white@18%` bg track, `white@90%` fill, height 7, radius 8.

### `AppHeroChip`
```dart
AppHeroChip(
  icon: Icons.south_rounded,
  label: 'Income',
  value: '₹8,000',
  onCard: Colors.white,
  onCardMuted: Colors.white.withValues(alpha: 0.65),
)
```

---

## Chips & Badges

### Status badge (inline, no widget)
```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(AppRadius.sm),
  ),
  child: Text('Active', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
)
```

### Category/legend chip (reports)
```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  decoration: BoxDecoration(
    color: color.withOpacity(0.1),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: color.withOpacity(0.2)),
  ),
  child: Row(children: [
    Container(width:8, height:8, decoration: BoxDecoration(color:color, shape:BoxShape.circle)),
    SizedBox(width:6),
    Text('Food 34%', style: TextStyle(fontSize:11, fontWeight:FontWeight.w600, color:color)),
  ]),
)
```

### Month "Now" pill
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
  decoration: BoxDecoration(
    color: cs.primary.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(AppSpacing.lg),
  ),
  child: Text('Now', style: TextStyle(fontSize:10, fontWeight:FontWeight.w600, color:cs.primary)),
)
```

---

## Quick Action Tiles — `AppQuickActionTile`

```dart
AppQuickActionTile(
  icon: Icons.add_circle_outline_rounded,
  label: 'Add',
  color: AppColors.success(context),
  onTap: () {},
)
```

48×48 circle with `color@12%` bg and `color@30%` border (1.5px). Label 11px w600.
Displayed in a horizontal `ListView.separated` with `height:88`, `separatorBuilder` → `SizedBox(width:10)`.

---

## Month Selector — `AppMonthSelector`

```dart
AppMonthSelector(
  selectedMonth: _selectedMonth,
  onPrev: _prevMonth,
  onNext: _nextMonth,
)
```

36×36 nav buttons in `surfaceContainerHighest` bg, radius 12. Month label uses `AppTextStyles.sectionHeader`. "Now" pill shown when current month.

---

## Bottom Sheets / Form Sheets — `PersonalFormSheet`

All add/edit/detail sheets use `PersonalFormSheet`:

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (_) => PersonalFormSheet(
    title: 'Add Transaction',
    icon: Icons.add_circle_outline,
    trailing: IconButton(...), // optional
    child: Column(...),
  ),
);
```

`PersonalFormSheet` provides:
- `scaffoldBackgroundColor` container, `radius:AppRadius.xxl(28)` top corners.
- 48×5px drag handle pill, `onSurface@15%`.
- Header row: 24px `cs.primary` icon + 20px w700 `cs.primary` title + optional trailing.
- `SingleChildScrollView` with `EdgeInsets.fromLTRB(lg, sm, lg, viewInsets.bottom + lg)`.
- Overrides `inputDecorationTheme` and `listTileTheme` for consistent form fields inside.

Never build a custom bottom sheet chrome. Never manually add a drag handle or header row.

---

## Input Fields

All fields inherit from `InputDecorationTheme`:
- Light: white fill, `grey.shade300` border, `radius:14`, focused border `primary` 2px.
- Dark: `cardColor(#1E1E1E)` fill, `white@10%` border, same radius.
- `contentPadding: EdgeInsets.symmetric(horizontal:16, vertical:14)`

Inside `PersonalFormSheet`, the theme is further overridden:
- `labelStyle`: 14px bodyMedium
- `helperStyle`: 11px h:1.4 onSurface@50%, maxLines:3
- `contentPadding`: `symmetric(horizontal:base, vertical:md)`

### Text field
```dart
TextField(
  controller: _ctrl,
  decoration: InputDecoration(
    labelText: 'Title',
    prefixIcon: Icon(Icons.title, size: 18),
  ),
)
```

### Dropdown
```dart
DropdownButtonFormField<String>(
  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
  isExpanded: true,
  decoration: InputDecoration(labelText: 'Category'),
  items: [...],
  onChanged: (v) => setState(() => _value = v!),
)
```

Never add custom `filled`, `fillColor`, or `border` overrides to individual fields — they inherit from the theme.

---

## Switch Tiles (Settings / Preferences)

Always wrap in `appCardDecoration` card. Use `SwitchListTile.adaptive`. Separate multiple tiles with `Divider(height:1, color:cs.outline@8–10%)`.

```dart
Container(
  decoration: appCardDecoration(context),
  child: Column(children: [
    SwitchListTile.adaptive(
      secondary: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(Icons.alarm_outlined, size: 18, color: cs.primary),
      ),
      title: Text('Title', style: AppTextStyles.body(context)),
      subtitle: Text('Subtitle', style: AppTextStyles.caption(context)),
      value: _value,
      onChanged: (v) => setState(() => _value = v),
    ),
    Divider(height: 1, color: cs.outline.withValues(alpha: .08)),
    SwitchListTile.adaptive(...),
  ]),
)
```

---

## List Tiles in Cards (non-switch)

```dart
ListTile(
  contentPadding: EdgeInsets.zero,  // inside PersonalFormSheet
  leading: Icon(Icons.calendar_today_outlined, color: cs.primary),
  title: Text('Transaction date'),
  subtitle: Text(DateFormat('dd MMM yyyy').format(_date)),
  onTap: () {},
)
```

Inside `PersonalFormSheet`, `listTileTheme` is overridden: `contentPadding:zero`, title 14px w500, subtitle 11px onSurface@50%.

---

## Drawer (`_AppDrawer`)

```dart
Drawer(
  child: SafeArea(
    child: Column(children: [
      // Header: CircleAvatar(radius:26) + name/app label
      Divider(color: AppColors.divider(context), height: 1),
      Expanded(child: ListView(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [_DrawerTile(...)],
      )),
      Divider(...),
      // Sign out tile at bottom
    ]),
  ),
)
```

### Drawer tile
```dart
Container(
  margin: EdgeInsets.only(bottom: AppSpacing.sm),
  decoration: BoxDecoration(
    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
    borderRadius: BorderRadius.circular(AppRadius.md),
  ),
  child: ListTile(
    tileColor: Colors.transparent,
    dense: true,
    leading: Icon(icon, size: 20, color: effectiveColor.withValues(alpha: 0.75)),
    title: Text(label, style: TextStyle(fontSize:14, fontWeight:FontWeight.w500)),
    subtitle: subtitle != null ? Text(subtitle, style: AppTextStyles.caption(context)) : null,
    onTap: onTap,
  ),
)
```

---

## Bottom Navigation Bar

Custom floating pill nav bar — never use `BottomNavigationBar` or `NavigationBar`.

- Container: 66px height, `radius:22`, `surfaceContainerHigh`/`surface` bg, `outline@8–15%` border.
- Animated sliding pill indicator: `cs.primary@10–18%` bg, `radius:14`.
- Active item: `cs.primary` icon + label, `w700`.
- Inactive: `cs.onSurface@40%`, `w400`.
- Glow dot above active icon: 4×4 `cs.primary` circle with `cs.primary@60%` blur shadow.
- Label: 10px.

---

## FAB

```dart
FloatingActionButton.extended(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
  extendedTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize:14, fontWeight:FontWeight.w600),
  onPressed: () {},
  icon: Icon(Icons.add),
  label: Text('Add account'),
)
```

Simple FAB uses theme defaults (circle shape, `cs.primary` bg).

---

## Loading States

### Shimmer skeleton
```dart
AppLoadingShimmer(width: 200, height: 14, borderRadius: AppRadius.sm)
AppLoadingShimmer.block(height: 56)  // full-width block
AppLoadingListTile()                  // pre-composed icon + two lines
```

### Inline progress
```dart
const LinearProgressIndicator()  // inside cards while loading
const CircularProgressIndicator() // full-screen center
```

---

## Reports & Charts

### Report card container
```dart
Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: isDark ? cs.surfaceContainerHigh : cs.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: cs.outline.withOpacity(0.08)),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.15 : 0.04), blurRadius:12, offset:Offset(0,3))],
  ),
  child: child,
)
```

### Stats banner (3-cell horizontal row)
`IntrinsicHeight` + `Row` of `Expanded` cells separated by `VerticalDivider(width:1, color:cs.outline@10%)`.
Each cell: 32×32 icon container (`color@10%` bg, radius 9) + value 13px w800 + label 10px onSurface@45%.

### Donut / pie chart (`fl_chart PieChart`)
- `sectionsSpace: 2`, `centerSpaceRadius: 44` (full report) or `28` (dashboard mini).
- Section radius: 44 (full) or 36 (mini).
- Center label: "Total" 10px + amount 13px w800.
- Legend: `Wrap(spacing:8, runSpacing:8)` of category chips.

### Bar chart (`fl_chart BarChart`)
- No border, no grid (`FlBorderData(show:false)`, `FlGridData(show:false)`).
- Left/right/top titles hidden. Bottom titles: day numbers at 1, 7-multiples, last day.
- Bar color: `cs.primary` weekday, `_kAmber` weekend, `cs.outline@12%` for zero days.
- Bar width: 5px (31-day month) or 7px (shorter months). Top radius 3.
- Tooltip: `radius:8`, white/black text 11px w600.

### Progress bars (category breakdown)
```dart
ClipRRect(
  borderRadius: BorderRadius.circular(4),
  child: LinearProgressIndicator(
    value: pct,
    minHeight: 5,
    backgroundColor: cs.outline.withOpacity(0.1),
    valueColor: AlwaysStoppedAnimation<Color>(color),
  ),
)
```

### Weekly bar chart (dashboard inline)
Custom `Row` of `Expanded` columns — not `fl_chart`. Each column: amount label (9px w700) + gradient `Container` bar + "W1" label (10px) + 4×4 dot for current week.

### Circular progress (budget %)
```dart
SizedBox(
  width: 44, height: 44,
  child: Stack(alignment: Alignment.center, children: [
    CircularProgressIndicator(
      value: ratio,
      strokeWidth: 4,
      backgroundColor: cs.outline.withValues(alpha: 0.1),
      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
      strokeCap: StrokeCap.round,
    ),
    Text('$percent%', style: TextStyle(fontSize:9, fontWeight:FontWeight.w800, color:statusColor)),
  ]),
)
```

### Legend dot
```dart
Row(children: [
  Container(width:8, height:8, decoration: BoxDecoration(color:color, borderRadius:BorderRadius.circular(2))),
  SizedBox(width:5),
  Text(label, style: TextStyle(fontSize:11, color:cs.onSurface.withOpacity(0.5))),
])
```

### Insight row (weekly analysis)
```dart
Row(children: [
  Icon(Icons.lightbulb_outline_rounded, size:14, color:_kAmber),
  SizedBox(width:6),
  Expanded(child: Text('Week 2 spent 40% more than Week 1',
    style: TextStyle(fontSize:11, color:cs.onSurface.withOpacity(0.55)))),
])
```

---

## Number Formatting

```dart
// Currency (Indian locale)
NumberFormat.currency(locale:'en_IN', symbol:'₹', decimalDigits:2).format(value)

// Compact (charts/badges)
if (v >= 100000) '₹${(v/100000).toStringAsFixed(1)}L'
else if (v >= 1000) '₹${(v/1000).toStringAsFixed(1)}K'
else '₹${v.toStringAsFixed(0)}'

// Thousands separator
NumberFormat('#,##0', 'en_IN').format(v.round())

// Date
DateFormat('dd MMM yyyy').format(date)   // 12 Jan 2025
DateFormat('dd MMM').format(date)        // 12 Jan
DateFormat('MMMM yyyy').format(date)     // January 2025
DateFormat('dd MMM yy, hh:mm a').format  // edit history timestamps
```

---

## Icon Containers (standard sizes)

| Size  | Container | Icon | Radius | Usage |
|-------|-----------|------|--------|-------|
| 38×38 | color@12% | 17px | 11     | AppFinanceTile leading |
| 36×36 | primary@10% | 18px | AppRadius.sm | Switch tile secondary |
| 34×34 | color@12% | 16px | 10     | Debt stat tile |
| 32×32 | color@14% | 16px | 10     | AppStatCard |
| 28×28 | color@15% | 14px | 8      | Category budget row |
| 40×40 | gradient  | 20px | 12     | Report sheet header |

---

## Offline Banner (`OfflineIndicator`)

Animated pulsing pill in the AppHeader center row (left of title).
`orange.shade700` bg, `Icons.cloud_off` 12px + "Offline" 10px w600 white.
Pulse: `Tween(0.6→1.0)` opacity, 1200ms repeat reverse.
Returns `SizedBox.shrink()` when online.

---

## Key Anti-Patterns — Never Do These

- ❌ Raw `SwitchListTile` without a card wrapper
- ❌ Custom bottom sheet chrome (drag handle + header row) — use `PersonalFormSheet`
- ❌ Hardcoded hex colors in screens — use `AppColors.*` or the `_k*` constants
- ❌ Custom `filled`/`fillColor`/`border` on individual `TextField`s — inherit from theme
- ❌ `Card()` widget — use `Container(decoration: appCardDecoration(context))`
- ❌ `BottomNavigationBar` or `NavigationBar` — use the custom pill nav
- ❌ Raw numeric spacing literals — use `AppSpacing.*` and `AppRadius.*`
- ❌ `SingleChildScrollView` as screen body — use `ListView`
- ❌ Skipping `GradientBody` on any screen body
- ❌ Custom row tiles from scratch — use `AppFinanceTile`
- ❌ Custom section headers — use `AppSectionHeader`
- ❌ `withOpacity()` — always use `withValues(alpha:)` instead
- ❌ `OutlinedButton` / `FilledButton` with custom `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))` — use theme defaults (radius 14)
