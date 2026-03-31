# Notification Overlay Redesign

## Problem

Current notification system uses `showDialog()` with a FIFO queue — shows one dialog at a time, blocks interaction until dismissed. Visual styles are inconsistent across 8 notification types (gradient vs white card, system font vs Nunito). User wants stacked, simultaneously visible, individually dismissible notifications with unified Duolingo-like styling.

## Decisions

- **Display:** Overlay-based system replacing `showDialog()` — all active notifications visible simultaneously
- **Position:** Center of screen, stacked as layered cards (fan/cascade effect)
- **Dismiss:** X button on each card + barrier tap dismisses topmost
- **Stacking:** Cascade with scale reduction and upward offset (max 3 visible)
- **Style:** All types use unified white card design with type-specific icon/color
- **Approach:** Overlay + Stack (Approach A)

## Architecture

### Overlay System

`AppNotificationListener` still listens to event providers via `ref.listen()`, but calls `NotificationOverlayManager.show()` instead of `showDialog()`.

`NotificationOverlayManager`:
- Manages `List<NotificationEntry>` for active notifications
- Creates/removes `OverlayEntry` instances
- Single barrier OverlayEntry (semi-transparent black) when any notification is active
- Barrier tap dismisses topmost notification
- When last notification dismissed, barrier fades out

### Cascade Positioning

```
Card 0 (top):    scale=1.0,  translateY=0
Card 1:          scale=0.95, translateY=-20
Card 2:          scale=0.90, translateY=-40
Card 3+:         hidden (max 3 visible cards)
```

### Event Flow (unchanged)

```
Event Provider fires → AppNotificationListener detects
  → NotificationOverlayManager.show(type, data)
  → OverlayEntry created, added to stack
  → Cascade positions recalculated for all visible cards

User dismisses (X or barrier tap)
  → OverlayEntry removed
  → Cascade positions animate to new state
  → Event provider reset to null
  → If empty: barrier fades out
```

## Unified Card Design

All 8 notification types share one card template:

### Card Anatomy
```
┌─────────────────────────────┐
│                          [X] │  ← Top-right close (gray400)
│         🎉 (icon/emoji)      │  ← Type-specific, 64px
│                               │
│     **Title**                 │  ← Nunito w900, 24px, AppColors.black
│     Subtitle                  │  ← Nunito w600, 16px, type-specific color
│                               │
│   ┌─────────────────────┐    │  ← Optional: pill (level/league transition)
│   │  Level 5  →  Level 6│    │
│   └─────────────────────┘    │
│                               │
│   [====== Button(s) ======]  │  ← Full-width, borderRadius 16
└─────────────────────────────┘
```

### Card Style
- Background: white
- Border radius: 24
- Shadow: `black.withOpacity(0.15)`, blur 16, offset (0, 8)
- Padding: 32
- X button: top-right, `AppColors.gray400`, 20px icon

### Type-Specific Properties

| Type | Icon | Icon Color | Button Color | Buttons |
|------|------|------------|-------------|---------|
| Level Up | 🎉 emoji | — | `primary` | OK |
| League Promotion | Tier emoji | — | tier color | OK |
| League Demotion | 📉 emoji | — | `danger` | OK |
| Streak Extended | `fire` icon | `streakOrange` | `streakOrange` | OK |
| Streak Milestone | `fire` icon | `streakOrange` | `streakOrange` | OK |
| Streak Freeze | `ac_unit` icon | `secondary` | `secondary` | OK |
| Streak Broken | `fire` icon | `gray400` | `gray400` | OK |
| Badge Earned | Badge emoji | — | `wasp` | OK |
| Assignment | 📋 emoji | — | `secondary` | Later (outlined) / View (filled) |

### Preserved Elements
- Level-up: old→new level pill (white card with colored pill instead of gradient)
- League: old→new tier pill
- Badge: single badge (icon+name+XP) or multi-badge list
- Streak: all 4 sub-types (milestone/freeze/broken/extended) with tiered messages
- Assignment: single vs multi count, navigation to detail/list

## Animations

### Entry (per card)
- Scale: 0.8 → 1.0 (elasticOut, 500ms)
- Fade: 0.0 → 1.0 (easeOut, 300ms)
- Existing cards animate to new cascade positions (300ms easeOut)

### Exit (dismiss)
- Scale: 1.0 → 0.8 + Fade: 1.0 → 0.0 (200ms easeIn)
- Remaining cards animate to new positions (300ms easeOut)
- Below card "comes forward": scale 0.95→1.0, translateY -20→0

### Barrier
- Fade in: 200ms, `Colors.black.withOpacity(0.4)`
- Fade out: 200ms (when last card dismissed)

## File Changes

### New Files
| File | Content |
|------|---------|
| `lib/presentation/widgets/common/notification_overlay_manager.dart` | OverlayEntry management, cascade positioning, barrier control |
| `lib/presentation/widgets/common/notification_card.dart` | Unified white card widget — renders all 8 types |

### Modified Files
| File | Change |
|------|--------|
| `notification_listener.dart` | `showDialog()` → `NotificationOverlayManager.show()`. Remove FIFO queue (`_dialogQueue`, `_isShowingDialog`, `_processQueue`). Remove `_LevelUpDialog` and `_LeagueTierChangeDialog` inner classes. |
| `app.dart` | Initialize `NotificationOverlayManager` |

### Deleted Files
| File | Reason |
|------|--------|
| `streak_event_dialog.dart` | UI moved to `notification_card.dart` |
| `badge_earned_dialog.dart` | UI moved to `notification_card.dart` |
| `assignment_notification_dialog.dart` | UI moved to `notification_card.dart` |

### Untouched
- Event providers (user_provider.dart, student_assignment_provider.dart)
- System settings
- Admin panel

## Edge Cases

- **Max 3 visible cards:** 4th+ cards are queued hidden; shown as earlier ones are dismissed
- **Rapid-fire events:** All arrive and stack immediately, no artificial delay
- **Assignment navigation:** "View" button dismisses all notifications, then navigates
- **Barrier tap:** Only dismisses topmost card, not all
- **Logout:** All overlay entries cleared, barrier removed
- **No navigator context:** Skip showing (same guard as current)
- **Route change while notifications showing:** Notifications persist (Overlay is above Navigator)
