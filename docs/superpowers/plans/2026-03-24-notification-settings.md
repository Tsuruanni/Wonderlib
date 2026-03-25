# Notification Settings + Streak Extended — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add daily "Day X!" streak notification and make all in-app notifications admin-configurable via system_settings.

**Architecture:** 7 new system_settings entries (6 bool + 1 int) control notification visibility. Flutter reads them via existing SystemSettings pipeline. Streak extended dialog is a new case in StreakEventDialog. All event firing points in UserController are gated by settings.

**Tech Stack:** Flutter/Riverpod, Supabase PostgreSQL, owlio_shared

**Spec:** `docs/superpowers/specs/2026-03-24-notification-settings-design.md`

---

## File Structure

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `supabase/migrations/20260324000005_notification_settings.sql` | INSERT 7 notification settings with descriptions |
| Modify | `lib/domain/entities/system_settings.dart` | Add 7 new fields (6 bool + 1 int) |
| Modify | `lib/data/models/settings/system_settings_model.dart` | Add 7 fields to fromMap/defaults/toEntity/fromEntity + `_toBool` helper |
| Modify | `lib/domain/entities/streak_result.dart` | Update `hasEvent` to include `streakExtended`, update docstring |
| Modify | `lib/presentation/widgets/common/streak_event_dialog.dart` | Add streak extended case (Day 1 + Day 2+ with subtitle pool) |
| Modify | `lib/presentation/providers/user_provider.dart` | Settings-aware gating for all 3 event types (streak, level up, league) |
| Modify | `owlio_admin/lib/core/router.dart` | Add `notification` to categories list |
| Modify | `owlio_admin/lib/features/settings/screens/settings_screen.dart` | Add notification category label/icon/color |

---

## Task 1: DB Migration — Insert 7 Notification Settings

**Files:**
- Create: `supabase/migrations/20260324000005_notification_settings.sql`

- [ ] **Step 1: Create migration file**

```sql
-- Notification settings: admin-configurable toggles for in-app notifications
INSERT INTO system_settings (key, value, category, description, sort_order) VALUES
  ('notif_streak_extended', '"true"', 'notification', 'Show daily "Day X!" streak dialog', 1),
  ('notif_streak_broken', '"true"', 'notification', 'Show streak broken dialog', 2),
  ('notif_streak_broken_min', '"3"', 'notification', 'Minimum streak days to show broken dialog', 3),
  ('notif_milestone', '"true"', 'notification', 'Show milestone dialog (7, 14, 30...)', 4),
  ('notif_level_up', '"true"', 'notification', 'Show level up dialog', 5),
  ('notif_league_change', '"true"', 'notification', 'Show league promotion/demotion dialog', 6),
  ('notif_freeze_saved', '"true"', 'notification', 'Show streak freeze saved dialog', 7)
ON CONFLICT (key) DO NOTHING;
```

- [ ] **Step 2: Push migration**

Run: `supabase db push`
Expected: Migration applied successfully

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260324000005_notification_settings.sql
git commit -m "feat(db): add 7 notification settings to system_settings"
```

---

## Task 2: SystemSettings Entity + Model — Add 7 Fields

**Files:**
- Modify: `lib/domain/entities/system_settings.dart`
- Modify: `lib/data/models/settings/system_settings_model.dart`

- [ ] **Step 1: Add fields to entity**

Add 7 new fields to `SystemSettings` constructor and class body. Add them after the existing `xpVocabPerfectBonus` field group, before Streak:

```dart
// Notifications
this.notifStreakExtended = true,
this.notifStreakBroken = true,
this.notifStreakBrokenMin = 3,
this.notifMilestone = true,
this.notifLevelUp = true,
this.notifLeagueChange = true,
this.notifFreezeSaved = true,
```

Fields:
```dart
// Notifications
final bool notifStreakExtended;
final bool notifStreakBroken;
final int notifStreakBrokenMin;
final bool notifMilestone;
final bool notifLevelUp;
final bool notifLeagueChange;
final bool notifFreezeSaved;
```

Add all 7 to `props` list.

- [ ] **Step 2: Add `_toBool` helper to model**

Add after existing `_toInt` helper:

```dart
static bool _toBool(dynamic v, bool defaultValue) {
  if (v == null) return defaultValue;
  if (v is bool) return v;
  if (v is String) return v == 'true';
  return defaultValue;
}
```

- [ ] **Step 3: Add fields to model — all 5 locations**

Constructor: add 7 `required` fields (6 bool + 1 int).

`fromMap`: add 7 lines:
```dart
notifStreakExtended: _toBool(m['notif_streak_extended'], true),
notifStreakBroken: _toBool(m['notif_streak_broken'], true),
notifStreakBrokenMin: _toInt(m['notif_streak_broken_min'], 3),
notifMilestone: _toBool(m['notif_milestone'], true),
notifLevelUp: _toBool(m['notif_level_up'], true),
notifLeagueChange: _toBool(m['notif_league_change'], true),
notifFreezeSaved: _toBool(m['notif_freeze_saved'], true),
```

`defaults`: add 7 fields with same defaults.

`toEntity`: add 7 field mappings.

`fromEntity`: add 7 field mappings.

- [ ] **Step 4: Verify compile**

Run: `dart analyze lib/domain/entities/system_settings.dart lib/data/models/settings/system_settings_model.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/system_settings.dart lib/data/models/settings/system_settings_model.dart
git commit -m "feat: add 7 notification settings fields to SystemSettings entity + model"
```

---

## Task 3: StreakResult — Update hasEvent

**Files:**
- Modify: `lib/domain/entities/streak_result.dart`

- [ ] **Step 1: Update hasEvent getter and docstring**

Replace lines 26-28:

```dart
// Before:
/// Show event dialog? Milestone and freeze always. Streak broken only if >= 3 days.
bool get hasEvent =>
    milestoneBonusXp > 0 || freezeUsed || (streakBroken && previousStreak >= 3);

// After:
/// Show event dialog? Streak extended always. Milestone and freeze always.
/// Streak broken only if >= 3 days (default, overridable via settings).
bool get hasEvent =>
    streakExtended ||
    milestoneBonusXp > 0 || freezeUsed || (streakBroken && previousStreak >= 3);
```

- [ ] **Step 2: Verify compile**

Run: `dart analyze lib/domain/entities/streak_result.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/domain/entities/streak_result.dart
git commit -m "feat: include streakExtended in StreakResult.hasEvent"
```

---

## Task 4: Streak Extended Dialog Case

**Files:**
- Modify: `lib/presentation/widgets/common/streak_event_dialog.dart`

- [ ] **Step 1: Add streak extended case to build method**

Add as the **last case** (lowest priority) in `build()`, before the `SizedBox.shrink()` fallback:

```dart
@override
Widget build(BuildContext context) {
  // Priority: milestone > freeze-saved > streak-broken > streak-extended
  if (result.milestoneBonusXp > 0) {
    return _buildMilestoneDialog(context);
  } else if (result.freezeUsed && !result.streakBroken) {
    return _buildFreezeSavedDialog(context);
  } else if (result.streakBroken && result.previousStreak >= 3) {
    return _buildStreakBrokenDialog(context);
  } else if (result.streakExtended) {
    return _buildStreakExtendedDialog(context);
  }
  return const SizedBox.shrink();
}
```

- [ ] **Step 2: Add _buildStreakExtendedDialog method**

Add after `_buildStreakBrokenDialog`:

```dart
static const _streakSubtitles = [
  'Keep it up!',
  "You're on fire!",
  'Great habit!',
  'Consistency is key!',
  'Unstoppable!',
  'Nice streak!',
];

Widget _buildStreakExtendedDialog(BuildContext context) {
  final isFirstDay = result.previousStreak == 0;

  final title = isFirstDay
      ? "Day 1! Let's go!"
      : 'Day ${result.newStreak}!';

  final subtitle = isFirstDay
      ? 'Your learning streak starts today!'
      : _streakSubtitles[result.newStreak % _streakSubtitles.length];

  return _buildDialog(
    context,
    icon: Icons.local_fire_department_rounded,
    iconColor: AppColors.streakOrange,
    title: title,
    subtitle: subtitle,
    subtitleColor: AppColors.streakOrange,
  );
}
```

- [ ] **Step 3: Verify compile**

Run: `dart analyze lib/presentation/widgets/common/streak_event_dialog.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/widgets/common/streak_event_dialog.dart
git commit -m "feat: add streak extended dialog (Day X! with motivational subtitles)"
```

---

## Task 5: Settings-Aware Event Gating in UserProvider

**Files:**
- Modify: `lib/presentation/providers/user_provider.dart`

This is the critical task — gate all 3 event types (streak, level up, league) with settings.

- [ ] **Step 1: Add imports**

Add at the top of `user_provider.dart`:
```dart
import '../../domain/entities/system_settings.dart';
import 'system_settings_provider.dart';
```

- [ ] **Step 2: Add helper method to UserController**

Add a private helper inside `UserController` class:

```dart
/// Read notification settings (fallback to defaults if not yet loaded)
SystemSettings get _notifSettings =>
    _ref.read(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();
```

- [ ] **Step 3: Update updateStreak — settings-aware streak event gating**

Replace lines 244-247:

```dart
// Before:
// Fire streak event if anything notable happened
if (streakResult.hasEvent) {
  _ref.read(streakEventProvider.notifier).state = streakResult;
}

// After:
// Fire streak event if settings allow it
final s = _notifSettings;
final shouldShow =
    (streakResult.milestoneBonusXp > 0 && s.notifMilestone) ||
    (streakResult.freezeUsed && !streakResult.streakBroken && s.notifFreezeSaved) ||
    (streakResult.streakBroken && streakResult.previousStreak >= s.notifStreakBrokenMin && s.notifStreakBroken) ||
    (streakResult.streakExtended && s.notifStreakExtended);
if (shouldShow) {
  _ref.read(streakEventProvider.notifier).state = streakResult;
}
```

Note: `previousStreak >= 3` hardcode is replaced with `previousStreak >= s.notifStreakBrokenMin`.

- [ ] **Step 4: Update addXP — settings-aware level up gating**

In `addXP()` method (around line 212-217), gate the level up event:

```dart
// Before:
if (user.level > oldLevel) {
  _ref.read(levelUpEventProvider.notifier).state = LevelUpEvent(
    oldLevel: oldLevel,
    newLevel: user.level,
  );
}

// After:
if (user.level > oldLevel && _notifSettings.notifLevelUp) {
  _ref.read(levelUpEventProvider.notifier).state = LevelUpEvent(
    oldLevel: oldLevel,
    newLevel: user.level,
  );
}
```

- [ ] **Step 5: Update refreshProfileOnly — settings-aware level up gating**

In `refreshProfileOnly()` method (around line 283-288), same change:

```dart
// Before:
if (user.level > oldLevel) {
  _ref.read(levelUpEventProvider.notifier).state = LevelUpEvent(
    oldLevel: oldLevel,
    newLevel: user.level,
  );
}

// After:
if (user.level > oldLevel && _notifSettings.notifLevelUp) {
  _ref.read(levelUpEventProvider.notifier).state = LevelUpEvent(
    oldLevel: oldLevel,
    newLevel: user.level,
  );
}
```

- [ ] **Step 6: Update _checkLeagueTierChange — settings-aware league gating**

In `_checkLeagueTierChange()` method (around line 156-164):

```dart
// Before:
void _checkLeagueTierChange(User? oldUser, User newUser) {
  if (oldUser == null) return;
  if (oldUser.leagueTier != newUser.leagueTier) {
    _ref.read(leagueTierChangeEventProvider.notifier).state =
        LeagueTierChangeEvent(
      oldTier: oldUser.leagueTier,
      newTier: newUser.leagueTier,
    );
  }
}

// After:
void _checkLeagueTierChange(User? oldUser, User newUser) {
  if (oldUser == null) return;
  if (oldUser.leagueTier != newUser.leagueTier && _notifSettings.notifLeagueChange) {
    _ref.read(leagueTierChangeEventProvider.notifier).state =
        LeagueTierChangeEvent(
      oldTier: oldUser.leagueTier,
      newTier: newUser.leagueTier,
    );
  }
}
```

- [ ] **Step 7: Verify compile**

Run: `dart analyze lib/presentation/providers/user_provider.dart`
Expected: No errors

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/providers/user_provider.dart
git commit -m "feat: gate all notifications with admin-configurable system_settings"
```

---

## Task 6: Admin Panel — Notification Category

**Files:**
- Modify: `owlio_admin/lib/core/router.dart`
- Modify: `owlio_admin/lib/features/settings/screens/settings_screen.dart`

- [ ] **Step 1: Add notification to router categories**

In `router.dart`, find the categories list and add `'notification'`:

```dart
// Before:
categories: ['xp_reading', 'xp_vocab', 'progression', 'game', 'app'],

// After:
categories: ['xp_reading', 'xp_vocab', 'notification', 'progression', 'game', 'app'],
```

- [ ] **Step 2: Add notification category to settings screen**

In `settings_screen.dart`, add to all 3 maps:

```dart
// categoryLabels:
'notification': 'Notifications',

// categoryIcons:
'notification': Icons.notifications_active,

// categoryColors:
'notification': Color(0xFF6366F1),
```

- [ ] **Step 3: Verify compile**

Run: `dart analyze owlio_admin/lib/`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add owlio_admin/lib/core/router.dart owlio_admin/lib/features/settings/screens/settings_screen.dart
git commit -m "feat(admin): add Notifications category to settings panel"
```

---

## Task 7: Final Verification

- [ ] **Step 1: Full analyze**

Run: `dart analyze lib/`
Expected: No errors

- [ ] **Step 2: Grep for removed hardcodes**

```bash
# Should return 0 results in user_provider (replaced with settings):
grep -n "previousStreak >= 3" lib/presentation/providers/user_provider.dart

# Verify all event providers are gated:
grep -n "streakEventProvider\|levelUpEventProvider\|leagueTierChangeEventProvider" lib/presentation/providers/user_provider.dart
```

- [ ] **Step 3: Verify streak_result.dart hasEvent includes streakExtended**

```bash
grep -A3 "get hasEvent" lib/domain/entities/streak_result.dart
```

Expected: Shows `streakExtended ||` in the getter.
