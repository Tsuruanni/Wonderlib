# Streak Sheet Redesign

## Summary

Replace the current `StreakStatusDialog` (centered dialog, weekly-only, basic styling) with a Duolingo-inspired full-screen bottom sheet. Adds gradient banner with contextual messages, distinct day-status icons, toggleable weekly/monthly calendar with month navigation, and compact stat cards.

## Current State

- `streak_status_dialog.dart` — small centered `Dialog` opened via `showDialog`
- 7-day weekly row with fire icons (color-only differentiation)
- Static "Current Streak" title, no contextual messaging
- Freeze info + buy button at bottom
- Called from `top_navbar.dart:62` and `right_info_panel.dart:105`

## Design

### Widget Structure

**New file:** `lib/presentation/widgets/common/streak_sheet.dart`
**Delete:** `lib/presentation/widgets/common/streak_status_dialog.dart`

Opened via `showModalBottomSheet` with `isScrollControlled: true`, `useSafeArea: true`. Sheet height: `0.85 * screen height`.

**Call site changes:**
- `top_navbar.dart` — `showDialog(StreakStatusDialog(...))` → `showModalBottomSheet(StreakSheet(...))`
- `right_info_panel.dart` — same change

**Internal private widgets:**
- `_StreakBanner` — gradient header with streak count + contextual message
- `_StreakCalendar` — toggleable weekly/monthly calendar
- `_StatsSection` — longest streak + freeze cards + buy button

### Sheet Layout (top to bottom)

```
┌─────────────────────────────────────────┐
│  ─── drag handle                        │
│                                         │
│  ┌─ Gradient Banner ───────────────┐    │
│  │  "3 day streak"     🔥 (large) │    │
│  │  "Keep it up!"                 │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌─ Calendar (weekly default) ─────┐    │
│  │  S  M  T  W  T  F  S           │    │
│  │  ✅ ✅ 🧊 ⚪ ⚪ ⚪ ⚪           │    │
│  │                                 │    │
│  │        Show monthly ▼           │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌─ Stats ────┐  ┌─ Freeze ──────┐    │
│  │ 🔥 Longest │  │ 🧊 Freezes    │    │
│  │   14 days  │  │   1/2         │    │
│  └────────────┘  └───────────────┘    │
│                                         │
│  [ 🧊 Buy Freeze — 50 coins ]          │
└─────────────────────────────────────────┘
```

### Gradient Banner (`_StreakBanner`)

- Background: `LinearGradient` — light orange (`streakOrange.withOpacity(0.08)`) left to slightly more intense right
- Left: streak count + "day streak" text (Nunito, bold), contextual message below
- Right: large decorative fire icon (64px, slightly faded)
- Rounded corners, contained within sheet padding

**Contextual message pool (selected by streak range):**

| Streak Range | Messages (random selection) |
|---|---|
| == 1 | "Your learning streak starts today!", "Day 1! Let's build a habit!", "Every journey starts with one step!" |
| 2–6 | "Keep it up!", "You're building a habit!", "Nice momentum!", "Stay consistent!" |
| 7–13 | "You're on fire!", "One week strong!", "Impressive dedication!", "Unstoppable!" |
| 14–29 | "Two weeks and counting!", "You're a machine!", "Incredible focus!", "Streak master!" |
| 30+ | "Legendary streak!", "You're an inspiration!", "Absolutely amazing!", "What a champion!" |
| Near milestone (≤2 days) | "{N} days to your next milestone!" (overrides range message) |

These are independent from notification card messages — both can have their own pools.

### Calendar (`_StreakCalendar`)

Single calendar widget with two modes, toggled via a text button.

**Weekly mode (default):**
- 7-day row for current week (Mon–Sun)
- Day name labels above
- Today highlighted (orange text + down arrow indicator)

**Monthly mode (toggled via "Show monthly ▼"):**
- Full month grid (7 columns)
- Month navigation: `< MARCH 2026 >` with left/right arrows
- Left bound: month of `profiles.created_at`
- Right bound: current month (no future navigation)
- Each month change triggers a new query

**Toggle:** "Show monthly ▼" / "Show weekly ▲" text button below the calendar. Animated transition via `AnimatedCrossFade`.

**Day cell icons (both modes):**

| Status | Visual |
|---|---|
| Login day | Orange filled circle + white checkmark |
| Freeze day | Blue filled circle + white snowflake |
| Today (if logged in) | Orange filled circle + white checkmark |
| Today (not yet logged in) | Orange outline circle |
| Missed day (past, after created_at, not in table) | Plain grey number |
| Before created_at / future | Very faded grey number |
| Other month padding | Not shown or very faded |

### Stats Section (`_StatsSection`)

**Two side-by-side compact cards:**

```
┌──────────────┐  ┌──────────────┐
│  🔥 Longest  │  │  🧊 Freezes  │
│   14 days    │  │    1 / 2     │
└──────────────┘  └──────────────┘
```

Each card: `AppColors.gray100` background, rounded corners, icon + label top, value bottom (bold).

**Buy Freeze button (full width, below cards):**
- `freezeCount < max` → `OutlinedButton`: "🧊 Buy Freeze — {price} coins"
- `coins < price` → button disabled (greyed out)
- `freezeCount >= max` → small grey text: "Max freezes reached"
- Loading state: spinner replaces icon, "Buying..." text
- On success: sheet closes. On error: SnackBar.

Existing `_handleBuyFreeze` logic carries over unchanged.

### Provider Changes

**New family provider for monthly data:**

```dart
final monthlyLoginDatesProvider = FutureProvider.family<
  Map<DateTime, bool>,
  ({int year, int month})
>((ref, params) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};
  final from = DateTime(params.year, params.month, 1);
  final useCase = ref.watch(getLoginDatesUseCaseProvider);
  final result = await useCase(GetLoginDatesParams(userId: userId, from: from));
  return result.fold((_) => <DateTime, bool>{}, (dates) => dates);
});
```

**Existing `loginDatesProvider`** stays unchanged — used for the weekly quick view (fetches from Monday of current week).

**Repository:** No changes needed. `getLoginDates(userId, from)` already accepts any `from` date and returns all dates from that point forward.

### Sheet Parameters

The sheet receives the same data the dialog currently receives, sourced from providers at the call site:

- `currentStreak` (int)
- `longestStreak` (int)
- `streakFreezeCount` (int)
- `streakFreezeMax` (int)
- `streakFreezePrice` (int)
- `userCoins` (int)
- `calendarDays` (Map<DateTime, bool>) — weekly data, pre-warmed
- `userCreatedAt` (DateTime) — for monthly calendar left bound

`userCreatedAt` is a new parameter — needs to be available from `User` entity. Verify it's exposed.

### Files Changed

| File | Change |
|---|---|
| `lib/presentation/widgets/common/streak_sheet.dart` | **NEW** — full sheet implementation |
| `lib/presentation/widgets/common/streak_status_dialog.dart` | **DELETE** |
| `lib/presentation/widgets/common/top_navbar.dart` | `showDialog` → `showModalBottomSheet`, pass `userCreatedAt` |
| `lib/presentation/widgets/shell/right_info_panel.dart` | Same change |
| `lib/presentation/providers/user_provider.dart` | Add `monthlyLoginDatesProvider` family provider |

### Edge Cases

| Scenario | Behavior |
|---|---|
| Brand new user (0 days) | Banner: "Your learning streak starts today!", calendar all empty |
| Same-day re-open | Sheet shows current data, no streak event fires |
| Month with no logins at all | Monthly grid shows all grey numbers |
| Navigate to month before account creation | Left arrow disabled, can't go further back |
| Navigate to current month then press right | Right arrow disabled, can't go to future |
| Buy freeze in sheet, success | Sheet closes, navbar streak count refreshes |
| Buy freeze, insufficient coins | Button disabled (greyed out), no action |
| Freeze saved yesterday | Weekly: blue snowflake on yesterday's cell |
| Partial freeze (2 freeze, 5 days away) | Calendar: 2 blue days + 3 plain grey days |

### Out of Scope

- Friend Streaks / social features
- Streak Society gamification
- Notification card changes (keep existing)
- Any database/RPC changes
