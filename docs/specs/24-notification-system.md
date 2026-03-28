# Notification System

## Audit

### Findings
| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Code Quality | `streak_event_dialog.dart:19` hardcodes `previousStreak >= 3` for streak-broken threshold — redundant with upstream `notifStreakBrokenMin` filtering in `UserController` | Low | Fixed |
| 2 | Database | Migration `20260325000004` inserts `notif_badge_earned` without `sort_order` (defaults to 0, displayed first) and uses unquoted `'true'` vs `'"true"'` used in all other notification settings | Low | Fixed |
| 3 | Code Quality | `level_up_celebration.dart` / `LevelUpCelebrationListener` orchestrates all 5 notification types but is named as if it's only for level-up — misleading | Low | Fixed |

### Checklist Result
- Architecture Compliance: PASS — clean architecture respected; admin panel uses direct Supabase (consistent with all admin screens)
- Code Quality: 2 issues (hardcoded threshold, misleading name)
- Dead Code: PASS — no unused notification code found
- Database & Security: 1 issue (missing sort_order + quoting inconsistency)
- Edge Cases & UX: PASS — dialog queue prevents stacking, assignment flag prevents re-show, settings fallback to defaults
- Performance: PASS — settings cached via FutureProvider, no N+1 queries
- Cross-System Integrity: PASS — badge checks fire after XP and streak, all events respect settings toggles

---

## Overview

The Notification System provides **in-app celebration/alert dialogs** triggered by user actions (XP gain, streak check, badge earn, assignment sync). It is entirely client-side — no notification table exists in the database. Admin controls visibility of each notification type via toggle switches in the system_settings table.

There are **8 notification types** across 4 event categories, all orchestrated by a single dialog queue in `LevelUpCelebrationListener`.

## Data Model

### Tables
- **system_settings** — stores 9 notification-related key-value pairs (category: `notification`)

No dedicated notification table. Notification events are transient — triggered by app events, displayed once, then discarded.

### Notification Settings (system_settings rows)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `notif_streak_extended` | bool | true | Daily "Day X!" streak dialog |
| `notif_streak_broken` | bool | true | Streak broken dialog |
| `notif_streak_broken_min` | int | 3 | Minimum streak days to show broken dialog |
| `notif_milestone` | bool | true | Milestone dialog (7, 14, 30, 60, 100) |
| `notif_level_up` | bool | true | Level up dialog |
| `notif_league_change` | bool | true | League promotion/demotion dialog |
| `notif_freeze_saved` | bool | true | Streak freeze saved dialog |
| `notif_badge_earned` | bool | true | Badge earned dialog |
| `notif_assignment` | bool | true | Active assignments on app open |

## Surfaces

### Admin
- **Notification Gallery** (`/notifications`): Preview and toggle all 8 notification types
- Each type shown as a card with: icon, title, description, toggle switch, message preview
- Toggle changes are saved immediately to `system_settings` via direct Supabase update
- Numeric settings (e.g., `notif_streak_broken_min`) editable via text field with submit-on-enter
- Refresh button to re-fetch current settings

### Student
- **Dialog Queue System**: All notifications displayed as modal dialogs, processed FIFO
- **Notification Types**:
  1. **Level Up** — shows old → new level transition with indigo gradient animation
  2. **League Change** — promotion (tier-colored gradient) or demotion (red gradient) with tier emoji
  3. **Streak Extended** — "Day X!" with rotating subtitle (6 options by day mod 6)
  4. **Streak Milestone** — "+XP XP earned!" at days 7, 14, 30, 60, 100+
  5. **Streak Freeze Saved** — "Your X-day streak is safe. N freezes left."
  6. **Streak Broken** — tiered messages based on previous streak length (3-6, 7-9, 10-20, 20+)
  7. **Badge Earned** — single badge (icon + name + XP) or multiple badges list
  8. **Assignment** — count + "View" button navigates to assignments screen (or detail if single)

### Teacher
N/A — teachers do not receive in-app notifications from this system.

## Business Rules

1. **Settings-gated**: Every notification type checks its corresponding `notif_*` setting before firing. If the setting is `false`, the event provider is never set.
2. **Dialog queue**: Only one dialog at a time. Dialogs are enqueued as closures and processed sequentially via `_processQueue()`.
3. **Streak event priority**: When a single `StreakResult` qualifies for multiple types, priority order is: milestone > freeze-saved > streak-broken > streak-extended. Only one dialog is shown per streak check.
4. **Streak broken threshold**: `notif_streak_broken_min` controls the minimum previous streak length that triggers the broken dialog. Default 3 — a 2-day streak breaking is silently ignored.
5. **Streak broken tiers**:
   - 3-6 days: "Welcome Back!" (gentle)
   - 7-9 days: "Your X-day streak ended" (neutral)
   - 10-20 days: "Your X-day streak was broken" (motivational)
   - 20+ days: "Your X-day streak was broken — That was impressive" (acknowledging)
6. **Streak subtitle rotation**: 6 subtitles rotated by `newStreak % 6`: "Keep it up!", "You're on fire!", "Great habit!", "Consistency is key!", "Unstoppable!", "Nice streak!"
7. **Assignment notification timing**: Fires 500ms after user profile loads — ensures streak/badge/league notifications fire first (they trigger during `_loadUserById`).
8. **Assignment once-per-session**: `_hasShownAssignmentNotif` flag prevents re-showing on profile reloads within the same session. Resets on logout.
9. **Assignment statuses shown**: `pending`, `inProgress`, and `overdue` assignments qualify.
10. **Badge earned from two sources**: Badge check runs after both `addXP()` and `updateStreak()` — different actions can trigger different badge conditions.
11. **Settings fallback**: If `systemSettingsProvider` hasn't loaded yet, `SystemSettings.defaults()` is used (all notifications enabled).
12. **Event cleanup on logout**: All 4 event providers are reset to `null` when user logs out.
13. **Level up from refreshProfileOnly**: Level-up notification also fires during `refreshProfileOnly()` (e.g., after vocab session where server-side RPC awards XP), not just `addXP()`.

## Cross-System Interactions

### Triggers INTO notification system
- **XP System** → Level Up notification (when `user.level > oldLevel`)
- **XP System** → Badge Earned notification (via `checkAndAwardBadges` after XP award)
- **Streak System** → Streak Extended/Broken/Milestone/Freeze-Saved notifications (via `updateStreak`)
- **Streak System** → Badge Earned notification (via `checkAndAwardBadges` after streak update)
- **Leaderboard** → League Change notification (via `_checkLeagueTierChange` comparing old/new tier)
- **Assignment System** → Assignment notification (via `activeAssignmentsProvider` on app open)

### Triggers FROM notification system
- **Assignment notification** → Navigation to assignments screen (via "View" button)
- No XP, coins, or badge side effects from dismissing notifications

### Event Chain
```
App Open
  → UserController._loadUserById()
    → _updateStreakIfNeeded() → updateStreak()
      → StreakResult → streakEventProvider (if settings allow)
      → checkAndAwardBadges → badgeEarnedEventProvider (if new badges)
    → _checkLeagueTierChange() → leagueTierChangeEventProvider (if tier changed)
  → [500ms delay] → _checkAndFireAssignmentNotification()
    → assignmentNotificationEventProvider (if active assignments exist)

Activity (chapter, quiz, inline, vocab)
  → addXP()
    → levelUpEventProvider (if level increased)
    → checkAndAwardBadges → badgeEarnedEventProvider (if new badges)
  → refreshProfileOnly()
    → levelUpEventProvider (if server-side XP pushed level up)
```

## Edge Cases

- **No settings loaded**: Falls back to `SystemSettings.defaults()` — all notifications enabled
- **Multiple badges at once**: Dialog shows list with per-badge icon + XP
- **Dialog dismissed via barrier tap**: All dialogs have `barrierDismissible: true` — tapping outside closes
- **Streak broken + freeze consumed**: Shows additional "Your N freeze(s) covered N day(s), but you were away too long"
- **No navigator context**: All dialog methods check `rootNavigatorKey.currentContext != null` before showing
- **Assignment fetch failure**: Silently caught — assignment notification is non-critical
- **First day streak**: Special message "Day 1! Let's go!" with subtitle "Your learning streak starts today!"
- **Teacher logged in**: Assignment notification skipped via `isTeacherProvider` check

## Test Scenarios

- [ ] Happy path: Student opens app, streak extended dialog shows "Day X!"
- [ ] Level up: Award XP to cross level threshold → level up dialog shows
- [ ] Badge earned: Trigger condition (e.g., XP threshold) → badge dialog with icon + XP
- [ ] League promotion: Open app after weekly reset with promotion → tier change dialog
- [ ] Streak broken: Open app after missing days → tiered broken message (varies by streak length)
- [ ] Streak milestone: Reach day 7/14/30/60/100 → milestone dialog with XP bonus
- [ ] Freeze saved: Miss a day with freeze available → freeze saved dialog with remaining count
- [ ] Assignment: Teacher creates assignment → student opens app → assignment dialog with "View" navigation
- [ ] Admin toggle off: Disable `notif_level_up` in admin → student levels up → no dialog
- [ ] Admin threshold: Set `notif_streak_broken_min` to 10 → lose 5-day streak → no dialog
- [ ] Multiple events: Trigger streak milestone + badge in same load → both dialogs shown sequentially
- [ ] Logout/login: Show assignment notification → logout → login → shows again (flag resets)
- [ ] Teacher: Login as teacher → no assignment notification shown

## Key Files

### Main App
- `lib/presentation/widgets/common/notification_listener.dart` — Dialog queue orchestrator (listens to all 5 event providers)
- `lib/presentation/providers/user_provider.dart` — Event classes, StateProviders, UserController (fires level-up, league, streak, badge events)
- `lib/presentation/providers/student_assignment_provider.dart` — AssignmentNotificationEvent class + provider

### Dialog Widgets
- `lib/presentation/widgets/common/streak_event_dialog.dart` — Streak extended/broken/milestone/freeze-saved
- `lib/presentation/widgets/common/badge_earned_dialog.dart` — Single/multiple badge celebration
- `lib/presentation/widgets/common/assignment_notification_dialog.dart` — Assignment count + navigation

### Settings
- `lib/domain/entities/system_settings.dart` — 9 notification fields with defaults
- `lib/data/models/settings/system_settings_model.dart` — Parsing from DB rows

### Admin
- `owlio_admin/lib/features/notifications/screens/notification_gallery_screen.dart` — Gallery with toggle/preview

### Database
- `supabase/migrations/20260324000006_notification_settings.sql` — 7 initial notification settings
- `supabase/migrations/20260325000004_badge_earned_notification.sql` — badge_earned setting + RPC update
- `supabase/migrations/20260327000002_notif_assignment_setting.sql` — assignment setting

## Known Issues & Tech Debt

1. ~~**Misleading orchestrator name**~~ — Fixed: renamed to `AppNotificationListener` / `notification_listener.dart`
2. ~~**Hardcoded streak-broken fallback**~~ — Fixed: removed redundant `>= 3` check in `streak_event_dialog.dart`
3. ~~**Missing sort_order on badge_earned**~~ — Fixed: migration `20260328800001` sets sort_order = 8 and normalizes JSONB quoting
4. **No persistent notification history**: All notifications are fire-and-forget — no way to review past notifications. This is by design for the current scope but may need a notification inbox feature in the future.
