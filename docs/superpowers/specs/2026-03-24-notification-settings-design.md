# Notification Settings + Streak Extended — Design Spec

**Date:** 2026-03-24
**Scope:** Add daily streak extended notification, make all in-app notifications admin-configurable via system_settings.

---

## Problem Statement

1. **No daily streak notification:** When a user opens the app and their streak extends (Day 1, Day 2, ...), no dialog is shown. Only milestones (Day 7, 14, 30...), freeze saves, and streak breaks trigger notifications. Users get no daily feedback on their streak progress.

2. **Hardcoded notification behavior:** All notification conditions are hardcoded in Dart. The `previousStreak >= 3` threshold for streak broken dialog, and the on/off state of each notification type, cannot be changed without a code deploy.

---

## Design

### A. Streak Extended Dialog

Add a new case to `StreakEventDialog` with **lowest priority** — only shows if no other event (milestone, freeze, broken) is active.

**Priority order:** milestone > freeze saved > streak broken > **streak extended**

**`hasEvent` change in `streak_result.dart`:**
```dart
bool get hasEvent =>
    streakExtended ||
    milestoneBonusXp > 0 || freezeUsed || (streakBroken && previousStreak >= 3);
```

**Dialog messages:**

| Condition | Title | Subtitle |
|-----------|-------|----------|
| Day 1 (`previousStreak == 0`) | "Day 1! Let's go!" | "Your learning streak starts today!" |
| Day 2+ (`previousStreak >= 1`) | "Day {newStreak}!" | Random from pool |

**Subtitle pool for Day 2+:**
- "Keep it up!"
- "You're on fire!"
- "Great habit!"
- "Consistency is key!"
- "Unstoppable!"
- "Nice streak!"

Selection: `pool[newStreak % pool.length]` — deterministic per day (not truly random, so reopening the app on the same day shows the same message).

**Dialog appearance:**
- Icon: `Icons.local_fire_department_rounded`
- Icon color: `AppColors.streakOrange` (same as milestone)
- No XP line (unlike milestone dialog)

---

### B. Notification Settings (system_settings)

7 new entries in `system_settings` table with category `notification`:

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `notif_streak_extended` | bool | `true` | Show daily "Day X!" dialog |
| `notif_streak_broken` | bool | `true` | Show streak broken dialog |
| `notif_streak_broken_min` | int | `3` | Minimum streak days to trigger broken dialog |
| `notif_milestone` | bool | `true` | Show milestone dialog (7, 14, 30...) |
| `notif_level_up` | bool | `true` | Show level up dialog |
| `notif_league_change` | bool | `true` | Show league promotion/demotion dialog |
| `notif_freeze_saved` | bool | `true` | Show streak freeze saved dialog |

---

### C. SystemSettings Entity + Model Changes

Add 7 new fields to `SystemSettings` entity and `SystemSettingsModel`:

| Field | Type | Default | Maps to DB key |
|-------|------|---------|----------------|
| `notifStreakExtended` | `bool` | `true` | `notif_streak_extended` |
| `notifStreakBroken` | `bool` | `true` | `notif_streak_broken` |
| `notifStreakBrokenMin` | `int` | `3` | `notif_streak_broken_min` |
| `notifMilestone` | `bool` | `true` | `notif_milestone` |
| `notifLevelUp` | `bool` | `true` | `notif_level_up` |
| `notifLeagueChange` | `bool` | `true` | `notif_league_change` |
| `notifFreezeSaved` | `bool` | `true` | `notif_freeze_saved` |

**Model parsing:** `SystemSettingsModel.fromMap` needs `_toBool` helper (similar to existing `_toInt`):
```dart
static bool _toBool(dynamic v, bool defaultValue) {
  if (v == null) return defaultValue;
  if (v is bool) return v;
  if (v is String) return v == 'true';
  return defaultValue;
}
```

---

### D. Flutter Integration — Notification Gating

#### D1. Streak events (`user_provider.dart`)

Replace the current simple `hasEvent` check with settings-aware logic:

```dart
// Current:
if (streakResult.hasEvent) {
  _ref.read(streakEventProvider.notifier).state = streakResult;
}

// New:
final settings = _ref.read(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();
final shouldShow = _shouldShowStreakEvent(streakResult, settings);
if (shouldShow) {
  _ref.read(streakEventProvider.notifier).state = streakResult;
}
```

Helper method:
```dart
bool _shouldShowStreakEvent(StreakResult r, SystemSettings s) {
  if (r.milestoneBonusXp > 0 && s.notifMilestone) return true;
  if (r.freezeUsed && !r.streakBroken && s.notifFreezeSaved) return true;
  if (r.streakBroken && r.previousStreak >= s.notifStreakBrokenMin && s.notifStreakBroken) return true;
  if (r.streakExtended && s.notifStreakExtended) return true;
  return false;
}
```

Note: `previousStreak >= 3` hardcode is replaced with `previousStreak >= s.notifStreakBrokenMin`.

#### D2. Level up events (`user_provider.dart`)

Gate the existing level up event with `settings.notifLevelUp`:
```dart
if (settings.notifLevelUp) {
  _ref.read(levelUpEventProvider.notifier).state = LevelUpEvent(...);
}
```

#### D3. League tier change events (`user_provider.dart`)

Gate with `settings.notifLeagueChange`:
```dart
if (settings.notifLeagueChange) {
  _ref.read(leagueTierChangeEventProvider.notifier).state = event;
}
```

#### D4. StreakResult.hasEvent

`hasEvent` on the entity is no longer the sole gate — settings override it. However, `hasEvent` is still useful as a "would this event show with defaults?" check. Update it to include `streakExtended`:

```dart
bool get hasEvent =>
    streakExtended ||
    milestoneBonusXp > 0 || freezeUsed || (streakBroken && previousStreak >= 3);
```

The `previousStreak >= 3` stays as the entity's default — the settings-based threshold is applied at the provider level.

---

### E. Admin Panel

**New category in router:** `notification`

**Settings screen updates:**
- `categoryLabels`: `'notification': 'Notifications'`
- `categoryIcons`: `'notification': Icons.notifications_active`
- `categoryColors`: `'notification': Color(0xFF6366F1)` (indigo)

**Auto-type detection** handles everything:
- Bool values (`"true"/"false"`) → Switch toggle
- Int value (`"3"`) → Number input

---

## New system_settings Entries (Total: 7)

| Key | Value | Category |
|-----|-------|----------|
| `notif_streak_extended` | `"true"` | `notification` |
| `notif_streak_broken` | `"true"` | `notification` |
| `notif_streak_broken_min` | `"3"` | `notification` |
| `notif_milestone` | `"true"` | `notification` |
| `notif_level_up` | `"true"` | `notification` |
| `notif_league_change` | `"true"` | `notification` |
| `notif_freeze_saved` | `"true"` | `notification` |

---

## Files Changed

### DB Migrations
| File | Change |
|------|--------|
| `supabase/migrations/YYYYMMDD_notification_settings.sql` | INSERT 7 new settings with descriptions |

### Domain Layer
| File | Change |
|------|--------|
| `lib/domain/entities/system_settings.dart` | Add 7 new fields (6 bool + 1 int) |
| `lib/domain/entities/streak_result.dart` | Update `hasEvent` to include `streakExtended` |

### Data Layer
| File | Change |
|------|--------|
| `lib/data/models/settings/system_settings_model.dart` | Add 7 fields + `_toBool` helper |

### Presentation Layer
| File | Change |
|------|--------|
| `lib/presentation/providers/user_provider.dart` | Settings-aware gating for streak, level up, league events |
| `lib/presentation/widgets/common/streak_event_dialog.dart` | Add streak extended case (Day 1 + Day 2+ with subtitle pool) |

### Admin Panel
| File | Change |
|------|--------|
| `owlio_admin/lib/core/router.dart` | Add `notification` to categories list |
| `owlio_admin/lib/features/settings/screens/settings_screen.dart` | Add notification category label/icon/color |

---

## Out of Scope

- Push notifications (this is in-app dialog only)
- Per-user notification preferences (these are global admin settings)
- Custom milestone day configuration (stays hardcoded in RPC: 7, 14, 30, 60, 100)
- Message text customization from admin panel (messages stay in Dart code)

---

## Verification

```bash
dart analyze lib/

# Check no hardcoded previousStreak >= 3 remains:
grep -r "previousStreak >= 3" lib/

# Check all notification types are gated:
grep -r "streakEventProvider\|levelUpEventProvider\|leagueTierChangeEventProvider" lib/presentation/providers/user_provider.dart
```
