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
  - Day 2+: `"Day X!"` + subtitle pool listed (Keep it up!, You're on fire!, Great habit!, Consistency is key!, Unstoppable!, Nice streak!)

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
- Inline parameter: `notif_streak_broken_min` (number input)
- Preview (tiered):
  - ≤6 days: `"Welcome Back!"` / `"Start a new streak today."`
  - 7-9 days: `"Your X-day streak ended"` / `"You can build it again!"`
  - 10-20 days: `"Your X-day streak was broken"` / `"Don't give up!"`
  - 20+ days: `"Your X-day streak was broken"` / `"That was impressive — you can do it again!"`

**Card 5: Level Up**
- Icon: ⬆️ (celebration, indigo)
- Toggle: `notif_level_up`
- Preview: `"Level Up! Level X → Level Y"`

**Card 6: League Change**
- Icon: 🏅 (trophy, varied)
- Toggle: `notif_league_change`
- Preview:
  - Promotion: `"League Promoted! Bronze → Silver"`
  - Demotion: `"League Demoted"`

### C. Toggle Behavior

Toggles read and write directly to `system_settings` via the existing Supabase REST API pattern (same as the settings page). When toggled, `UPDATE system_settings SET value = '"true"'/"false"' WHERE key = '...'`.

The `notif_streak_broken_min` number input uses `onFieldSubmitted` to save (same pattern as settings page).

### D. Settings Page Cleanup

Remove `notification` from the settings page categories list. Notification settings are now managed exclusively on `/notifications`.

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
