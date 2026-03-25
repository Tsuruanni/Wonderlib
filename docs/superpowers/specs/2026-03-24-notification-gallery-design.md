# Admin Notification Gallery — Design Spec

**Date:** 2026-03-24
**Scope:** Create a dedicated `/notifications` page in the admin panel that displays all notification types as preview cards with toggles. Remove notification settings from the general settings page.

---

## Problem Statement

Notification settings are currently buried in the general settings page alongside XP values and app config. Admins cannot see what each notification looks like — they only see toggle keys like `notif_streak_extended`. A dedicated page with visual previews makes it clear what users will see.

---

## Design

### A. New Page: `/notifications`

A standalone page showing all 6 notification types as cards. Each card contains:
- Icon + title + toggle (on/off)
- Message preview showing exactly what users see
- Configurable parameters inline (e.g., `notif_streak_broken_min`)

### B. Card Layout

Each notification type gets one card. Cards are arranged in a single-column layout:

**Card 1: Streak Extended**
- Icon: 🔥 (fire, orange)
- Toggle: `notif_streak_extended`
- Preview content:
  - Day 1: `"Day 1! Let's go!"` / `"Your learning streak starts today!"`
  - Day 2+: `"Day X!"` + subtitle cycles deterministically by streak day (`pool[newStreak % 6]`):
    1. "Keep it up!" 2. "You're on fire!" 3. "Great habit!" 4. "Consistency is key!" 5. "Unstoppable!" 6. "Nice streak!"

**Card 2: Milestone**
- Icon: 🏆 (star, orange)
- Toggle: `notif_milestone`
- Preview: `"X-Day Streak! +YZ XP earned!"`
- Note: Triggers at days 7, 14, 30, 60, 100

**Card 3: Freeze Saved**
- Icon: ❄️ (snowflake, blue)
- Toggle: `notif_freeze_saved`
- Preview: `"Streak Freeze Saved You!"` / `"Your X-day streak is safe. N freezes left."`

**Card 4: Streak Broken**
- Icon: 💔 (fire, grey)
- Toggle: `notif_streak_broken`
- Inline parameter: `notif_streak_broken_min` (number input, default 3)
- Note: Only triggers when broken streak was ≥ `notif_streak_broken_min` days
- Preview (tiered by previous streak length):
  - 3-6 days: `"Welcome Back!"` / `"Start a new streak today."`
  - 7-9 days: `"Your X-day streak ended"` / `"You can build it again!"`
  - 10-20 days: `"Your X-day streak was broken"` / `"Don't give up!"`
  - 20+ days: `"Your X-day streak was broken"` / `"That was impressive — you can do it again!"`

**Card 5: Level Up**
- Icon: ⬆️ (celebration, indigo)
- Toggle: `notif_level_up`
- Preview:
  - Title: `"Level Up!"`
  - Transition: `"Level X → Level Y"`
  - Subtitle: `"Great job! Keep it up!"`

**Card 6: League Change**
- Icon: 🏅 (trophy, varied)
- Toggle: `notif_league_change`
- Preview:
  - Promotion: `"League Promoted!"` / `"OldTier → NewTier"` / `"Great work this week! Keep climbing!"`
  - Demotion: `"League Demoted"` / `"OldTier → NewTier"` / `"Keep practicing to climb back up!"`

### C. Data Access

The page reuses the existing `settingsProvider` from `settings_screen.dart` to load all settings (it fetches all categories). The notification gallery filters for `notification` category keys from the grouped result. This avoids duplicating the Supabase query logic.

For writes, toggles and number input use the same `_updateSetting` pattern: `supabase.from(DbTables.systemSettings).update({'value': newValue}).eq('key', key)` with `settingsProvider` invalidation after save.

### D. Settings Page Cleanup

Remove `notification` from the settings page categories list in `router.dart`. Also remove the `notification` entries from `categoryLabels`, `categoryIcons`, and `categoryColors` maps in `settings_screen.dart` — they become dead code once the category is no longer passed in.

### E. Dashboard Card

Add a new `_DashboardCard` for notifications on the dashboard:
- Icon: `Icons.notifications_active`
- Title: `"Notifications"`
- Description: `"Notification types and preview"`
- Color: `Color(0xFF6366F1)` (indigo)
- Route: `/notifications`

---

## Files Changed

### Admin Panel
| File | Change |
|------|--------|
| `owlio_admin/lib/features/notifications/screens/notification_gallery_screen.dart` | **CREATE** — New page with 6 notification cards |
| `owlio_admin/lib/core/router.dart` | Add `/notifications` route, remove `notification` from settings categories |
| `owlio_admin/lib/features/dashboard/screens/dashboard_screen.dart` | Add Notifications dashboard card |
| `owlio_admin/lib/features/settings/screens/settings_screen.dart` | Remove `notification` from category maps (cleanup) |

### No Flutter App Changes
This is admin-panel-only. The main app already reads notification settings from `system_settings`.

---

## Out of Scope

- Message text editing from admin (messages stay in Dart code)
- Live notification preview (showing the actual Flutter dialog)
- Push notification management
- Per-user notification preferences
