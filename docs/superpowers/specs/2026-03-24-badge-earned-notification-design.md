# Badge Earned Notification — Design Spec

**Date:** 2026-03-24
**Status:** Approved
**Scope:** Main app badge notification dialog, admin panel toggle + preview

---

## Problem

When students earn badges, there is no visual feedback. The `check_and_award_badges` RPC returns newly awarded badge data (badge_id, badge_name, xp_reward), but all 3 Flutter call sites discard the result. Students only discover their badges by visiting the profile screen. The existing notification infrastructure (event providers → global listener → showDialog) supports this pattern perfectly but no badge event has been wired in.

## Solution

### 1. Architectural Approach — Badge Check at Controller Level

**Key decision:** Rather than changing repository/usecase return types (which would cascade through interfaces, use cases, and providers), we move the badge check from repository level to UserController level.

**Changes:**
- **Remove** `check_and_award_badges` calls from all 3 repository methods (`supabase_activity_repository._awardXP()`, `supabase_user_repository.addXP()`, `supabase_user_repository.updateStreak()`)
- **Add** a new `CheckAndAwardBadgesUseCase` that wraps the RPC call and returns `List<BadgeEarned>`
- **Call** this use case from `UserController.addXP()` and `UserController.updateStreak()` after the existing operations succeed

**Benefits:**
- Zero changes to existing repository interfaces, use cases, or return types
- Badge result captured exactly where it's needed (provider layer)
- Single point of control for badge notification logic
- Clean architecture maintained (UseCase wraps RPC, not direct repository access from provider)

**Trade-off:** Badge check is no longer atomic with XP award at the repository level. However, the SQL-level `PERFORM` calls inside `complete_vocabulary_session` and `complete_daily_review` still ensure badges are checked atomically for those paths. For Flutter-side paths, the badge check happens milliseconds after XP award — no practical risk.

**Coverage of all XP paths:** `UserController.addXP()` is the centralized entry point called from ALL XP-granting providers:
- `reader_provider.dart` — inline activity completion
- `book_provider.dart` — chapter and book completion XP
- `book_quiz_provider.dart` — quiz pass XP

By placing badge check in `UserController.addXP()`, all these paths automatically get badge notifications.

**Vocabulary/daily review path:** These use `refreshProfileOnly()` (NOT `addXP()`) after SQL RPCs that internally award XP and check badges via `PERFORM`. Badges are still awarded in the DB, but no Flutter-side notification fires. This is acceptable for now — vocab/daily review badge notifications can be added later by calling badge check in `refreshProfileOnly()`.

### 2. Event Flow

```
UserController.addXP() or updateStreak()
  → existing operation succeeds
  → calls CheckAndAwardBadgesUseCase
  → RPC returns List<BadgeEarned>
  → if non-empty AND notifBadgeEarned setting is true
  → writes to badgeEarnedEventProvider
  → LevelUpCelebrationListener shows BadgeEarnedDialog
```

### 3. BadgeEarned Entity

New domain entity (NOT moved from edge_function_service — they have different JSON schemas):

```dart
// lib/domain/entities/badge_earned.dart
class BadgeEarned {
  final String badgeId;
  final String badgeName;
  final String badgeIcon;
  final int xpReward;

  const BadgeEarned({
    required this.badgeId,
    required this.badgeName,
    required this.badgeIcon,
    required this.xpReward,
  });
}
```

`edge_function_service.dart` is left untouched — its `BadgeEarned` class has different JSON keys (camelCase from Edge Function vs snake_case from RPC) and serves a different purpose.

### 4. New UseCase + Repository Method

**BadgeRepository interface** — add method:

```dart
Future<Either<Failure, List<BadgeEarned>>> checkAndAwardBadges(String userId);
```

**SupabaseBadgeRepository** — implement:

```dart
Future<Either<Failure, List<BadgeEarned>>> checkAndAwardBadges(String userId) async {
  final result = await _supabase.rpc(RpcFunctions.checkAndAwardBadges, params: {'p_user_id': userId});
  // Parse List<Map> into List<BadgeEarned>
}
```

**CheckAndAwardBadgesUseCase:**

```dart
class CheckAndAwardBadgesUseCase implements UseCase<List<BadgeEarned>, CheckAndAwardBadgesParams> {
  final BadgeRepository _repository;
  // ...
}
```

### 5. Provider Changes

**New event provider** in `user_provider.dart`:

```dart
final badgeEarnedEventProvider = StateProvider<BadgeEarnedEvent?>((ref) => null);
```

**BadgeEarnedEvent wrapper** (for consistency with other event providers which use single objects, not lists):

```dart
class BadgeEarnedEvent {
  final List<BadgeEarned> badges;
  const BadgeEarnedEvent(this.badges);
}
```

**UserController changes:**

- `addXP()`: After `_addXPUseCase` succeeds, call `_checkAndAwardBadgesUseCase`. If result is non-empty and `_notifSettings.notifBadgeEarned` is true, write `BadgeEarnedEvent` to provider.
- `updateStreak()`: Same pattern after `_updateStreakUseCase` succeeds.

### 6. Dialog Design

**File:** `lib/presentation/widgets/common/badge_earned_dialog.dart`

Follows the same visual language as existing dialogs (`StreakEventDialog`, `_LevelUpDialog`):
- White `Dialog` with `BoxDecoration` (rounded corners, shadow)
- Animated scale entrance
- Match existing typography patterns in `level_up_celebration.dart`

**Single badge layout:**
```
    🏆  (badge icon from DB, large)
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

### 7. Dialog Ordering — Queue System

`addXP()` can trigger both level up AND badge earned in the same call. Existing `ref.listen` callbacks all fire synchronously, causing overlapping `showDialog()` calls.

**Solution:** Implement a simple dialog queue in `LevelUpCelebrationListener`:

```dart
final _dialogQueue = <Future<void> Function()>[];
bool _isShowingDialog = false;

void _enqueueDialog(Future<void> Function() showFn) {
  _dialogQueue.add(showFn);
  _processQueue();
}

Future<void> _processQueue() async {
  if (_isShowingDialog || _dialogQueue.isEmpty) return;
  _isShowingDialog = true;
  final fn = _dialogQueue.removeAt(0);
  await fn();
  _isShowingDialog = false;
  _processQueue(); // process next in queue
}
```

All existing `ref.listen` callbacks change from direct `showDialog()` to `_enqueueDialog(() => showDialog(...))`. Badge listener is added last to ensure it's queued after level up and streak dialogs.

### 8. Admin Toggle

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

### 9. SQL RPC Change

Modify `check_and_award_badges` to return `icon` alongside existing columns. **PostgreSQL requires DROP FUNCTION when return type changes:**

```sql
DROP FUNCTION IF EXISTS check_and_award_badges(UUID);
CREATE OR REPLACE FUNCTION check_and_award_badges(p_user_id UUID)
RETURNS TABLE(badge_id UUID, badge_name VARCHAR, badge_icon VARCHAR, xp_reward INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
-- ... same body, but SELECT now includes b.icon
-- and output assignment includes badge_icon
$$;
```

The LOOP body changes from:
```sql
SELECT b.id, b.name, b.xp_reward INTO badge_id, badge_name, xp_reward FROM badges b WHERE b.id = v_awarded.badge_id;
```
to:
```sql
SELECT b.id, b.name, b.icon, b.xp_reward INTO badge_id, badge_name, badge_icon, xp_reward FROM badges b WHERE b.id = v_awarded.badge_id;
```

## Files Changed

### New Files
- `supabase/migrations/YYYYMMDD_badge_earned_notification.sql` — DROP+CREATE RPC with icon return + `notif_badge_earned` setting
- `lib/domain/entities/badge_earned.dart` — `BadgeEarned` entity + `BadgeEarnedEvent` wrapper
- `lib/domain/usecases/badge/check_and_award_badges_usecase.dart` — new use case
- `lib/presentation/widgets/common/badge_earned_dialog.dart` — dialog widget

### Modified Files (Main App)
- `lib/data/repositories/supabase/supabase_activity_repository.dart` — **remove** `check_and_award_badges` call from `_awardXP()`
- `lib/data/repositories/supabase/supabase_user_repository.dart` — **remove** `check_and_award_badges` calls from `addXP()` and `updateStreak()`
- `lib/data/repositories/supabase/supabase_badge_repository.dart` — **add** `checkAndAwardBadges()` implementation
- `lib/domain/repositories/badge_repository.dart` — **add** `checkAndAwardBadges()` to interface
- `lib/presentation/providers/usecase_providers.dart` — register `CheckAndAwardBadgesUseCase`
- `lib/presentation/providers/user_provider.dart` — `badgeEarnedEventProvider`, `BadgeEarnedEvent`, badge check in `addXP()` and `updateStreak()`
- `lib/presentation/widgets/common/level_up_celebration.dart` — add badge listener + dialog queue system
- `lib/domain/entities/system_settings.dart` — `notifBadgeEarned` field
- `lib/data/models/settings/system_settings_model.dart` — parse `notif_badge_earned`

### Modified Files (Admin Panel)
- `owlio_admin/lib/features/notifications/screens/notification_gallery_screen.dart` — add badge earned card

### Not Changed
- Repository/UseCase return types (no cascading interface changes)
- `edge_function_service.dart` (different `BadgeEarned` class, different JSON schema)
- SQL `PERFORM` calls in vocab/daily review RPCs (badges still awarded in DB, just no Flutter dialog)
- `BadgeController` / `badgeControllerProvider` (dead code, separate cleanup)
- Existing streak/levelup/league dialog widgets
- Shared package (`RpcFunctions.checkAndAwardBadges` constant unchanged)

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
