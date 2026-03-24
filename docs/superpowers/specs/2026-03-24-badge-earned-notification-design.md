# Badge Earned Notification — Design Spec

**Date:** 2026-03-24
**Status:** Approved
**Scope:** Main app badge notification dialog, admin panel toggle + preview

---

## Problem

When students earn badges, there is no visual feedback. The `check_and_award_badges` RPC returns newly awarded badge data (badge_id, badge_name, xp_reward), but all 3 Flutter call sites discard the result. Students only discover their badges by visiting the profile screen. The existing notification infrastructure (event providers → global listener → showDialog) supports this pattern perfectly but no badge event has been wired in.

## Solution

### 1. Event Flow

Follow the established event provider pattern used by level up, league change, and streak events:

```
check_and_award_badges RPC
  → result captured as List<BadgeEarned>
  → Repository returns it up the chain
  → UserController writes to badgeEarnedEventProvider
  → LevelUpCelebrationListener shows BadgeEarnedDialog
```

**Trigger points (3 Flutter-side call sites):**

1. `supabase_activity_repository.dart` — `_awardXP()` method (~line 272). After `award_xp_transaction`, calls `check_and_award_badges`. Currently discards result. Will capture and return `List<BadgeEarned>`.

2. `supabase_user_repository.dart` — `addXP()` method (~line 76). Same pattern. Will capture and return.

3. `supabase_user_repository.dart` — `updateStreak()` method (~line 102). Same pattern. Will capture and return.

**SQL-embedded PERFORM calls (untouched):** `complete_vocabulary_session` and `complete_daily_review` use `PERFORM check_and_award_badges(...)` which discards results at the SQL level. These are NOT modified because Flutter already calls `addXP()` after these RPCs, which triggers its own badge check.

### 2. BadgeEarned Entity

Move `BadgeEarned` from `edge_function_service.dart` (where it's defined but unused) to a proper domain entity:

```dart
// lib/domain/entities/badge_earned.dart
class BadgeEarned {
  final String badgeId;
  final String badgeName;
  final int xpReward;

  const BadgeEarned({
    required this.badgeId,
    required this.badgeName,
    required this.xpReward,
  });
}
```

Update `edge_function_service.dart` to import from the entity instead of defining its own class.

### 3. Repository Changes

**Return type changes:**

The `check_and_award_badges` call sites currently return `void` (or the parent method ignores the badge result). Changes needed:

- `SupabaseActivityRepository._awardXP()` — capture RPC result, parse into `List<BadgeEarned>`, return it. The parent method `submitActivityResult()` must propagate this up.
- `SupabaseUserRepository.addXP()` — capture RPC result, parse into `List<BadgeEarned>`, return alongside existing return value.
- `SupabaseUserRepository.updateStreak()` — capture RPC result, parse into `List<BadgeEarned>`, return alongside `StreakResult`.

**Parsing:** The RPC returns `List<Map<String, dynamic>>` with keys `badge_id`, `badge_name`, `xp_reward`. Parse each row into `BadgeEarned`.

### 4. Provider Changes

**New event provider** in `user_provider.dart`:

```dart
final badgeEarnedEventProvider = StateProvider<List<BadgeEarned>?>((ref) => null);
```

**UserController changes:**

- `addXP()`: After calling `AddXPUseCase`, if badges returned and `_notifSettings.notifBadgeEarned` is true, write to `badgeEarnedEventProvider`.
- `updateStreak()`: After calling `UpdateStreakUseCase`, if badges returned and setting is true, write to `badgeEarnedEventProvider`.

**Activity completion path:** The activity result flow needs to propagate badges from `submitActivityResult()` → provider layer → `badgeEarnedEventProvider`. This may go through `reader_provider.dart` where `handleInlineActivityCompletion()` is called.

### 5. Dialog Design

**File:** `lib/presentation/widgets/common/badge_earned_dialog.dart`

Follows the same visual language as `StreakEventDialog` and `_LevelUpDialog`:
- `GoogleFonts.nunito` typography
- `Dialog` with `BoxDecoration` (white, rounded corners, shadow)
- Animated scale entrance

**Single badge layout:**
```
    🏆  (badge icon, large)
   "New Badge!"  (title, bold)
  "Streak Master"  (badge name)
    +100 XP  (purple badge)
     [OK]
```

**Multiple badge layout:**
```
   "2 New Badges!"  (title, bold)
   ┌──────────────────┐
   │ 🔥 Streak Master  +100 XP │
   │ ⭐ Rising Star    +50 XP  │
   └──────────────────┘
     [OK]
```

**Badge icon:** Uses the `icon` field from the `badges` table (emoji string). However, `check_and_award_badges` RPC only returns `badge_id`, `badge_name`, `xp_reward` — NOT the icon. Two options:

**Option A (recommended):** Modify the RPC to also return `badge_icon` in the result set. One-line SQL change.

**Option B:** Use a generic trophy emoji for all badge notifications. Simpler but less personalized.

**Decision: Option A** — modify RPC to include `icon` in the return columns. The `BadgeEarned` entity gets an `icon` field.

### 6. Dialog Ordering

Badge dialog shows **after** level up and streak dialogs. Implementation: In `LevelUpCelebrationListener`, the badge `ref.listen` callback checks if other event providers have pending events. If so, it queues itself (via a `Future.delayed` or by chaining after dialog dismiss callbacks).

Simpler approach: The existing pattern already handles this naturally — each dialog's `then()` callback resets its provider to `null`, and Riverpod listeners fire asynchronously. The badge listener simply needs to be registered last in the listener list, and when showing the dialog, wrap in `Future.microtask()` to yield to any pending dialog queues.

### 7. Admin Toggle

**Migration:** Insert `notif_badge_earned` into `system_settings`:

```sql
INSERT INTO system_settings (key, value, category, description) VALUES
  ('notif_badge_earned', 'true', 'notification', 'Show dialog when student earns a badge')
ON CONFLICT (key) DO NOTHING;
```

**SystemSettings entity:** Add `notifBadgeEarned` bool field (default: `true`).

**SystemSettingsModel:** Parse `notif_badge_earned` from DB rows.

**Admin notification gallery:** Add a card with:
- Toggle switch for `notif_badge_earned`
- Message preview section showing dialog text variants:
  - Single: "New Badge! 🏆 Streak Master +100 XP"
  - Multiple: "2 New Badges! 🔥 Streak Master +100 XP, ⭐ Rising Star +50 XP"

### 8. SQL RPC Change

Modify `check_and_award_badges` to return `icon` alongside existing columns:

```sql
-- Current return: TABLE(badge_id UUID, badge_name VARCHAR, xp_reward INTEGER)
-- New return: TABLE(badge_id UUID, badge_name VARCHAR, badge_icon VARCHAR, xp_reward INTEGER)
```

The LOOP body already fetches badge details with `SELECT b.id, b.name, b.xp_reward FROM badges b WHERE b.id = v_awarded.badge_id`. Add `b.icon` to this SELECT and to the output assignment.

## Files Changed

### New Files
- `supabase/migrations/YYYYMMDD_badge_earned_notification.sql` — RPC update + `notif_badge_earned` setting
- `lib/domain/entities/badge_earned.dart` — `BadgeEarned` entity
- `lib/presentation/widgets/common/badge_earned_dialog.dart` — Dialog widget

### Modified Files (Main App)
- `lib/data/repositories/supabase/supabase_activity_repository.dart` — capture badge result from RPC
- `lib/data/repositories/supabase/supabase_user_repository.dart` — capture badge result from RPC (2 methods)
- `lib/domain/repositories/user_repository.dart` — update return types if needed
- `lib/domain/repositories/activity_repository.dart` — update return types if needed
- `lib/domain/usecases/user/add_xp_usecase.dart` — propagate badge result
- `lib/domain/usecases/user/update_streak_usecase.dart` — propagate badge result
- `lib/presentation/providers/user_provider.dart` — `badgeEarnedEventProvider` + write logic in `addXP()` and `updateStreak()`
- `lib/presentation/widgets/common/level_up_celebration.dart` — add badge listener
- `lib/domain/entities/system_settings.dart` — `notifBadgeEarned` field
- `lib/data/models/settings/system_settings_model.dart` — parse `notif_badge_earned`
- `lib/core/services/edge_function_service.dart` — replace local `BadgeEarned` with import from entity

### Modified Files (Admin Panel)
- `owlio_admin/lib/features/notifications/screens/notification_gallery_screen.dart` — add badge earned card

### Not Changed
- `check_and_award_badges` SQL logic (only return columns change)
- SQL `PERFORM` calls in vocab/daily review RPCs
- `BadgeController` / `badgeControllerProvider` (dead code, separate cleanup)
- Existing streak/levelup/league dialogs
- Push notifications / Supabase Realtime

## Verification

```bash
# Main app compiles
dart analyze lib/

# Admin panel compiles
cd owlio_admin && dart analyze lib/

# Migration applies
supabase db push --dry-run

# Tests pass
flutter test

# Manual test: complete an activity that triggers a badge → dialog appears
```
