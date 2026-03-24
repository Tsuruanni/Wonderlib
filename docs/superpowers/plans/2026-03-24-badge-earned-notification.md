# Badge Earned Notification — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show an in-app celebration dialog when students earn badges, with admin toggle control.

**Architecture:** Move badge check from 3 repository call sites to UserController level via a new UseCase. Badge results flow through a `badgeEarnedEventProvider` (matching existing level-up/streak pattern). A dialog queue in `LevelUpCelebrationListener` ensures proper ordering when multiple events fire simultaneously.

**Tech Stack:** Flutter/Riverpod, PostgreSQL (Supabase RPC), Dart

**Spec:** `docs/superpowers/specs/2026-03-24-badge-earned-notification-design.md`

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `supabase/migrations/20260325000004_badge_earned_notification.sql` | DROP+CREATE RPC with icon return + `notif_badge_earned` setting |
| `lib/domain/entities/badge_earned.dart` | `BadgeEarned` entity (badgeId, badgeName, badgeIcon, xpReward) |
| `lib/domain/usecases/badge/check_and_award_badges_usecase.dart` | UseCase wrapping the RPC call |
| `lib/presentation/widgets/common/badge_earned_dialog.dart` | Dialog widget for single/multiple badges |

### Modified Files
| File | Change |
|------|--------|
| `lib/domain/repositories/badge_repository.dart` | Add `checkAndAwardBadges()` method |
| `lib/data/repositories/supabase/supabase_badge_repository.dart` | Implement `checkAndAwardBadges()` |
| `lib/data/repositories/supabase/supabase_user_repository.dart` | Remove 2 `check_and_award_badges` calls |
| `lib/data/repositories/supabase/supabase_activity_repository.dart` | Remove 1 `check_and_award_badges` call |
| `lib/presentation/providers/usecase_providers.dart` | Register new UseCase provider |
| `lib/presentation/providers/user_provider.dart` | Add `BadgeEarnedEvent`, `badgeEarnedEventProvider`, badge check in `addXP()` and `updateStreak()` |
| `lib/presentation/widgets/common/level_up_celebration.dart` | Convert to `ConsumerStatefulWidget`, add dialog queue, add badge listener |
| `lib/domain/entities/system_settings.dart` | Add `notifBadgeEarned` field |
| `lib/data/models/settings/system_settings_model.dart` | Parse `notif_badge_earned` |
| `owlio_admin/lib/features/notifications/screens/notification_gallery_screen.dart` | Add badge earned card |

---

## Task 1: DB Migration — RPC Icon Return + Notification Setting

**Files:**
- Create: `supabase/migrations/20260325000004_badge_earned_notification.sql`

- [ ] **Step 1: Create migration file**

Create `supabase/migrations/20260325000004_badge_earned_notification.sql`:

```sql
-- =============================================
-- Badge Earned Notification
-- 1. Update check_and_award_badges to return badge icon
-- 2. Add notif_badge_earned setting
-- =============================================

-- 1. Must DROP first because return type is changing (adding badge_icon column)
DROP FUNCTION IF EXISTS check_and_award_badges(UUID);

CREATE OR REPLACE FUNCTION check_and_award_badges(p_user_id UUID)
RETURNS TABLE(badge_id UUID, badge_name VARCHAR, badge_icon VARCHAR, xp_reward INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile profiles%ROWTYPE;
    v_books_completed INTEGER;
    v_vocab_learned INTEGER;
    v_perfect_scores INTEGER;
    v_awarded RECORD;
BEGIN
    -- Get user profile
    SELECT * INTO v_profile FROM profiles WHERE id = p_user_id;
    IF NOT FOUND THEN RETURN; END IF;

    -- Get stats
    SELECT COUNT(*) INTO v_books_completed
    FROM reading_progress WHERE user_id = p_user_id AND is_completed = TRUE;

    SELECT COUNT(*) INTO v_vocab_learned
    FROM vocabulary_progress WHERE user_id = p_user_id AND status = 'mastered';

    SELECT COUNT(*) INTO v_perfect_scores
    FROM activity_results WHERE user_id = p_user_id AND score = max_score;

    -- Single set-based INSERT for all qualifying badges
    FOR v_awarded IN
        INSERT INTO user_badges (user_id, badge_id)
        SELECT p_user_id, b.id
        FROM badges b
        WHERE b.is_active = TRUE
        AND NOT EXISTS (
            SELECT 1 FROM user_badges ub
            WHERE ub.user_id = p_user_id AND ub.badge_id = b.id
        )
        AND (
            (b.condition_type = 'xp_total' AND v_profile.xp >= b.condition_value) OR
            (b.condition_type = 'streak_days' AND v_profile.current_streak >= b.condition_value) OR
            (b.condition_type = 'books_completed' AND v_books_completed >= b.condition_value) OR
            (b.condition_type = 'vocabulary_learned' AND v_vocab_learned >= b.condition_value) OR
            (b.condition_type = 'perfect_scores' AND v_perfect_scores >= b.condition_value) OR
            (b.condition_type = 'level_completed' AND v_profile.level >= b.condition_value)
        )
        ON CONFLICT DO NOTHING
        RETURNING user_badges.badge_id
    LOOP
        -- Award XP for each newly earned badge
        SELECT b.id, b.name, b.icon, b.xp_reward
        INTO badge_id, badge_name, badge_icon, xp_reward
        FROM badges b WHERE b.id = v_awarded.badge_id;

        IF xp_reward > 0 THEN
            PERFORM award_xp_transaction(
                p_user_id, xp_reward, 'badge', v_awarded.badge_id,
                'Earned: ' || badge_name
            );
        END IF;

        RETURN NEXT;
    END LOOP;
END;
$$;

COMMENT ON FUNCTION check_and_award_badges IS 'Check and award badges, returns badge_id, badge_name, badge_icon, xp_reward';

-- 2. Add notification setting
INSERT INTO system_settings (key, value, category, description) VALUES
  ('notif_badge_earned', 'true', 'notification', 'Show dialog when student earns a badge')
ON CONFLICT (key) DO NOTHING;
```

- [ ] **Step 2: Push migration**

Run:
```bash
supabase db push
```
Expected: Migration applied successfully.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260325000004_badge_earned_notification.sql
git commit -m "feat(db): add badge icon to RPC return, add notif_badge_earned setting"
```

---

## Task 2: BadgeEarned Entity + UseCase + Repository

**Files:**
- Create: `lib/domain/entities/badge_earned.dart`
- Create: `lib/domain/usecases/badge/check_and_award_badges_usecase.dart`
- Modify: `lib/domain/repositories/badge_repository.dart:6-24`
- Modify: `lib/data/repositories/supabase/supabase_badge_repository.dart`

- [ ] **Step 1: Create BadgeEarned entity**

Create `lib/domain/entities/badge_earned.dart`:

```dart
/// Represents a badge that was just earned by a user.
/// Returned by the check_and_award_badges RPC.
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

- [ ] **Step 2: Add method to BadgeRepository interface**

In `lib/domain/repositories/badge_repository.dart`, add before the closing `}` (after line 23):

```dart
  Future<Either<Failure, List<BadgeEarned>>> checkAndAwardBadges(String userId);
```

Also add the import at top:
```dart
import '../entities/badge_earned.dart';
```

- [ ] **Step 3: Implement in SupabaseBadgeRepository**

In `lib/data/repositories/supabase/supabase_badge_repository.dart`, add the import at top:
```dart
import '../../../domain/entities/badge_earned.dart';
```

Add the method implementation (at the end of the class, before final `}`):

```dart
  @override
  Future<Either<Failure, List<BadgeEarned>>> checkAndAwardBadges(String userId) async {
    try {
      final result = await _supabase.rpc(
        RpcFunctions.checkAndAwardBadges,
        params: {'p_user_id': userId},
      );

      final List rows = result is List ? result : [];
      final badges = rows.map((row) {
        final r = row as Map<String, dynamic>;
        return BadgeEarned(
          badgeId: r['badge_id'] as String,
          badgeName: r['badge_name'] as String,
          badgeIcon: r['badge_icon'] as String? ?? '🏆',
          xpReward: r['xp_reward'] as int? ?? 0,
        );
      }).toList();

      return Right(badges);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
```

- [ ] **Step 4: Create UseCase**

Create `lib/domain/usecases/badge/check_and_award_badges_usecase.dart`:

```dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/badge_earned.dart';
import '../../repositories/badge_repository.dart';
import '../usecase.dart';

class CheckAndAwardBadgesUseCase
    implements UseCase<List<BadgeEarned>, CheckAndAwardBadgesParams> {
  final BadgeRepository _repository;

  const CheckAndAwardBadgesUseCase(this._repository);

  @override
  Future<Either<Failure, List<BadgeEarned>>> call(
      CheckAndAwardBadgesParams params) {
    return _repository.checkAndAwardBadges(params.userId);
  }
}

class CheckAndAwardBadgesParams {
  final String userId;

  const CheckAndAwardBadgesParams({required this.userId});
}
```

- [ ] **Step 5: Verify compiles**

Run: `dart analyze lib/domain/ lib/data/repositories/supabase/supabase_badge_repository.dart`
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/entities/badge_earned.dart lib/domain/usecases/badge/check_and_award_badges_usecase.dart lib/domain/repositories/badge_repository.dart lib/data/repositories/supabase/supabase_badge_repository.dart
git commit -m "feat: add BadgeEarned entity, CheckAndAwardBadgesUseCase, and repository method"
```

---

## Task 3: Remove Badge Check from Repositories

**Files:**
- Modify: `lib/data/repositories/supabase/supabase_user_repository.dart:76-78,102-104`
- Modify: `lib/data/repositories/supabase/supabase_activity_repository.dart:271-274`

- [ ] **Step 1: Remove badge check from supabase_user_repository.dart addXP()**

In `lib/data/repositories/supabase/supabase_user_repository.dart`, remove lines 75-78:

```dart
      // Check for new badges
      await _supabase.rpc(RpcFunctions.checkAndAwardBadges, params: {
        'p_user_id': userId,
      },);
```

- [ ] **Step 2: Remove badge check from supabase_user_repository.dart updateStreak()**

In the same file, remove lines 102-104:

```dart
      await _supabase.rpc(RpcFunctions.checkAndAwardBadges, params: {
        'p_user_id': userId,
      });
```

- [ ] **Step 3: Remove badge check from supabase_activity_repository.dart _awardXP()**

In `lib/data/repositories/supabase/supabase_activity_repository.dart`, remove lines 271-274:

```dart
      // Also check for new badges
      await _supabase.rpc(RpcFunctions.checkAndAwardBadges, params: {
        'p_user_id': userId,
      },);
```

- [ ] **Step 4: Verify compiles**

Run: `dart analyze lib/`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/supabase/supabase_user_repository.dart lib/data/repositories/supabase/supabase_activity_repository.dart
git commit -m "refactor: move badge check from repositories to controller level"
```

---

## Task 4: Add notifBadgeEarned to Settings

**Files:**
- Modify: `lib/domain/entities/system_settings.dart:33,71,107`
- Modify: `lib/data/models/settings/system_settings_model.dart:93,96`

- [ ] **Step 1: Add field to SystemSettings entity**

In `lib/domain/entities/system_settings.dart`:

Add to constructor (after line 33 `this.notifFreezeSaved = true,`):
```dart
    this.notifBadgeEarned = true,
```

Add to fields (after line 71 `final bool notifFreezeSaved;`):
```dart
  final bool notifBadgeEarned;
```

Add to props list (after line 106 `notifFreezeSaved,`):
```dart
        notifBadgeEarned,
```

- [ ] **Step 2: Add parsing to SystemSettingsModel**

In `lib/data/models/settings/system_settings_model.dart`, add `notifBadgeEarned` to **5 locations** (the model does NOT extend SystemSettings — it has separate fields):

**A. Constructor parameter** (after line 27 `required this.notifFreezeSaved,`):
```dart
    required this.notifBadgeEarned,
```

**B. Field declaration** (after line 54 `final bool notifFreezeSaved;`):
```dart
  final bool notifBadgeEarned;
```

**C. `fromMap()` factory** (after line 93 `notifFreezeSaved: _toBool(m['notif_freeze_saved'], true),`):
```dart
      notifBadgeEarned: _toBool(m['notif_badge_earned'], true),
```

**D. `defaults()` factory** (after line 123 `notifFreezeSaved: true,`):
```dart
        notifBadgeEarned: true,
```

**E. `toEntity()` method** (after line 152 `notifFreezeSaved: notifFreezeSaved,`):
```dart
        notifBadgeEarned: notifBadgeEarned,
```

**F. `fromEntity()` factory** — find the line `notifFreezeSaved: e.notifFreezeSaved,` and add after it:
```dart
        notifBadgeEarned: e.notifBadgeEarned,
```

- [ ] **Step 3: Verify compiles**

Run: `dart analyze lib/`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/domain/entities/system_settings.dart lib/data/models/settings/system_settings_model.dart
git commit -m "feat: add notifBadgeEarned to SystemSettings"
```

---

## Task 5: Provider — Badge Event + UserController Integration

**Files:**
- Modify: `lib/presentation/providers/usecase_providers.dart:413`
- Modify: `lib/presentation/providers/user_provider.dart:1-52,193-260`

- [ ] **Step 1: Register UseCase provider**

In `lib/presentation/providers/usecase_providers.dart`, add after the `getRecentlyEarnedUseCaseProvider` (after line 413):

```dart
final checkAndAwardBadgesUseCaseProvider = Provider((ref) {
  return CheckAndAwardBadgesUseCase(ref.watch(badgeRepositoryProvider));
});
```

Add the import at top:
```dart
import '../../domain/usecases/badge/check_and_award_badges_usecase.dart';
```

- [ ] **Step 2: Add BadgeEarnedEvent and provider to user_provider.dart**

In `lib/presentation/providers/user_provider.dart`, add after `streakEventProvider` (after line 52):

```dart
/// Badge earned event for celebration dialog
class BadgeEarnedEvent {
  const BadgeEarnedEvent({required this.badges});
  final List<BadgeEarned> badges;
}

/// Provider for badge earned events - UI listens to show celebration
final badgeEarnedEventProvider = StateProvider<BadgeEarnedEvent?>((ref) => null);
```

Add import at top:
```dart
import '../../domain/entities/badge_earned.dart';
import '../../domain/usecases/badge/check_and_award_badges_usecase.dart';
```

- [ ] **Step 3: Add badge check to UserController.addXP()**

In `lib/presentation/providers/user_provider.dart`, in the `addXP()` method, add after the level-up check block (after line 223 `}`):

```dart
    // Check for new badges
    final badgeUseCase = _ref.read(checkAndAwardBadgesUseCaseProvider);
    final badgeResult = await badgeUseCase(CheckAndAwardBadgesParams(userId: userId));
    badgeResult.fold(
      (_) {}, // Ignore badge check failures
      (badges) {
        if (badges.isNotEmpty && _notifSettings.notifBadgeEarned) {
          _ref.read(badgeEarnedEventProvider.notifier).state =
              BadgeEarnedEvent(badges: badges);
        }
        // Invalidate badge providers so profile reflects new badges
        _ref.invalidate(userBadgesProvider);
      },
    );
```

Add import for `userBadgesProvider`:
```dart
import 'badge_provider.dart';
```

- [ ] **Step 4: Add badge check to UserController.updateStreak()**

In the same file, in the `updateStreak()` method, add after the streak event check (after line 259 `}`):

```dart
    // Check for new badges (streak badges)
    final badgeUseCase = _ref.read(checkAndAwardBadgesUseCaseProvider);
    final badgeResult = await badgeUseCase(CheckAndAwardBadgesParams(userId: userId));
    badgeResult.fold(
      (_) {},
      (badges) {
        if (badges.isNotEmpty && _notifSettings.notifBadgeEarned) {
          _ref.read(badgeEarnedEventProvider.notifier).state =
              BadgeEarnedEvent(badges: badges);
        }
        _ref.invalidate(userBadgesProvider);
      },
    );
```

- [ ] **Step 5: Clear badge event on logout**

In the `UserController` constructor, where other events are cleared on logout (line 126), add:
```dart
        _ref.read(badgeEarnedEventProvider.notifier).state = null;
```

- [ ] **Step 6: Verify compiles**

Run: `dart analyze lib/`
Expected: No errors.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/providers/usecase_providers.dart lib/presentation/providers/user_provider.dart
git commit -m "feat: add badge earned event provider and wire into UserController"
```

---

## Task 6: Badge Earned Dialog Widget

**Files:**
- Create: `lib/presentation/widgets/common/badge_earned_dialog.dart`

- [ ] **Step 1: Create dialog widget**

Create `lib/presentation/widgets/common/badge_earned_dialog.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../domain/entities/badge_earned.dart';

class BadgeEarnedDialog extends StatefulWidget {
  const BadgeEarnedDialog({super.key, required this.badges});

  final List<BadgeEarned> badges;

  @override
  State<BadgeEarnedDialog> createState() => _BadgeEarnedDialogState();
}

class _BadgeEarnedDialogState extends State<BadgeEarnedDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSingle = widget.badges.length == 1;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSingle) ...[
                  // Single badge - large icon
                  Text(
                    widget.badges.first.badgeIcon,
                    style: const TextStyle(fontSize: 64),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'New Badge!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.badges.first.badgeName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  _XPBadge(xp: widget.badges.first.xpReward),
                ] else ...[
                  // Multiple badges
                  Text(
                    '${widget.badges.length} New Badges!',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...widget.badges.map((badge) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Text(badge.badgeIcon,
                                style: const TextStyle(fontSize: 32)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                badge.badgeName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            _XPBadge(xp: badge.xpReward),
                          ],
                        ),
                      )),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _XPBadge extends StatelessWidget {
  const _XPBadge({required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) {
    if (xp <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '+$xp XP',
        style: const TextStyle(
          color: Colors.purple,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify compiles**

Run: `dart analyze lib/presentation/widgets/common/badge_earned_dialog.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/common/badge_earned_dialog.dart
git commit -m "feat: add BadgeEarnedDialog widget"
```

---

## Task 7: Dialog Queue + Badge Listener in LevelUpCelebrationListener

**Files:**
- Modify: `lib/presentation/widgets/common/level_up_celebration.dart:1-80`

- [ ] **Step 1: Convert to ConsumerStatefulWidget and add dialog queue**

Rewrite `LevelUpCelebrationListener` in `lib/presentation/widgets/common/level_up_celebration.dart`. The widget (lines 12-80) changes from `ConsumerWidget` to `ConsumerStatefulWidget`.

Replace lines 12-80 with:

```dart
class LevelUpCelebrationListener extends ConsumerStatefulWidget {
  const LevelUpCelebrationListener({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<LevelUpCelebrationListener> createState() =>
      _LevelUpCelebrationListenerState();
}

class _LevelUpCelebrationListenerState
    extends ConsumerState<LevelUpCelebrationListener> {
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
    _processQueue();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LevelUpEvent?>(levelUpEventProvider, (previous, next) {
      if (next != null) {
        _enqueueDialog(() => _showLevelUpCelebration(next));
      }
    });

    ref.listen<LeagueTierChangeEvent?>(leagueTierChangeEventProvider,
        (previous, next) {
      if (next != null) {
        _enqueueDialog(() => _showLeagueTierChange(next));
      }
    });

    ref.listen<StreakResult?>(streakEventProvider, (previous, next) {
      if (next != null && next.hasEvent) {
        _enqueueDialog(() => _showStreakEvent(next));
      }
    });

    ref.listen<BadgeEarnedEvent?>(badgeEarnedEventProvider, (previous, next) {
      if (next != null) {
        _enqueueDialog(() => _showBadgeEarned(next));
      }
    });

    return widget.child;
  }

  Future<void> _showLevelUpCelebration(LevelUpEvent event) async {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    await showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (context) => _LevelUpDialog(event: event),
    );
    ref.read(levelUpEventProvider.notifier).state = null;
  }

  Future<void> _showStreakEvent(StreakResult result) async {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    await showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (context) => StreakEventDialog(result: result),
    );
    ref.read(streakEventProvider.notifier).state = null;
  }

  Future<void> _showLeagueTierChange(LeagueTierChangeEvent event) async {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    await showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (context) => _LeagueTierChangeDialog(event: event),
    );
    ref.read(leagueTierChangeEventProvider.notifier).state = null;
  }

  Future<void> _showBadgeEarned(BadgeEarnedEvent event) async {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    await showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (context) => BadgeEarnedDialog(badges: event.badges),
    );
    ref.read(badgeEarnedEventProvider.notifier).state = null;
  }
}
```

Add import at top of file (note: `user_provider.dart` is already imported at line 7 — do NOT add it again):
```dart
import 'badge_earned_dialog.dart';
```

Note: `BadgeEarnedEvent` and `badgeEarnedEventProvider` come from `user_provider.dart` which is already imported. `BadgeEarned` type flows through `BadgeEarnedDialog`'s import. The `BadgeEarnedDialog` is imported from the new file. Make sure the existing `_LevelUpDialog` and `_LeagueTierChangeDialog` classes (lines 82+) remain unchanged — they are private widgets in the same file.

- [ ] **Step 2: Verify compiles**

Run: `dart analyze lib/`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/common/level_up_celebration.dart
git commit -m "feat: add dialog queue and badge earned listener to celebration widget"
```

---

## Task 8: Admin Panel — Badge Notification Toggle

**Files:**
- Modify: `owlio_admin/lib/features/notifications/screens/notification_gallery_screen.dart`

- [ ] **Step 1: Add badge earned card to notification gallery**

In `notification_gallery_screen.dart`, in the `build` method's `Column` children (around line 143), add after the last card (`_buildLeagueChangeCard`):

```dart
                  const SizedBox(height: 16),
                  _buildBadgeEarnedCard(grouped),
```

- [ ] **Step 2: Add the card builder method**

Add to the class (after the last `_build*Card` method, following the same pattern):

```dart
  Widget _buildBadgeEarnedCard(
      Map<String, List<Map<String, dynamic>>> grouped) {
    return _NotifCard(
      icon: Icons.emoji_events,
      iconColor: Colors.amber.shade700,
      title: 'Badge Earned',
      description: 'Shown when a student earns a new badge',
      isEnabled: _getBool(grouped, 'notif_badge_earned'),
      isSaving: _savingKeys.contains('notif_badge_earned'),
      onToggle: (v) => _updateSetting('notif_badge_earned', v.toString()),
      preview: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _previewRow('Single', 'New Badge!',
              '🏆 Streak Master  +100 XP'),
          const SizedBox(height: 8),
          _previewRow('Multiple', '2 New Badges!',
              '🔥 Streak Master +100 XP\n⭐ Rising Star +50 XP'),
        ],
      ),
    );
  }
```

Note: `_previewRow` and `_NotifCard` are existing helper widgets in this file — match their usage pattern from the other card builders.

- [ ] **Step 3: Verify admin panel compiles**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add owlio_admin/lib/features/notifications/screens/notification_gallery_screen.dart
git commit -m "feat(admin): add badge earned notification toggle and preview"
```

---

## Task 9: Final Verification

- [ ] **Step 1: Verify main app compiles**

Run: `dart analyze lib/`
Expected: No errors.

- [ ] **Step 2: Verify admin panel compiles**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/`
Expected: No errors.

- [ ] **Step 3: Run tests**

Run: `flutter test`
Expected: Badge-related tests pass (pre-existing failures in vocab tests are unrelated).

- [ ] **Step 4: Verify migration was applied**

Run: `supabase migration list | tail -3`
Expected: `20260325000004` appears in the list.
