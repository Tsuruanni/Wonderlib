# Database Audit Phase 2 & 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove dead badge-award code, tighten badge RLS, optimize N+1 RPCs, clean up orphan tables, and add safety constraints.

**Architecture:** Phase 2 removes unused Flutter code then drops the INSERT policy on `user_badges`. Phase 3 rewrites two N+1 RPCs with CTEs, drops orphan daily-quest-pack tables/functions, and adds CHECK/UNIQUE constraints after production data verification.

**Tech Stack:** Flutter/Dart (code removal), PostgreSQL/Supabase (migrations)

---

## File Map

### Phase 2 — Badge Dead Code + RLS

| Action | File |
|--------|------|
| Delete | `lib/domain/usecases/badge/award_badge_usecase.dart` |
| Modify | `lib/domain/repositories/badge_repository.dart` — remove `awardBadge` signature |
| Modify | `lib/data/repositories/supabase/supabase_badge_repository.dart` — remove `awardBadge` + `_awardXP` |
| Modify | `lib/presentation/providers/badge_provider.dart` — remove `BadgeController`, `BadgeState`, `badgeControllerProvider` |
| Modify | `lib/presentation/providers/usecase_providers.dart` — remove `awardBadgeUseCaseProvider` + import |
| Create | `supabase/migrations/YYYYMMDD000001_badge_rls_phase2.sql` |

### Phase 3 — RPC Performance + Cleanup + Constraints

| Action | File |
|--------|------|
| Create | `supabase/migrations/YYYYMMDD000001_rpc_n1_fix.sql` |
| Create | `supabase/migrations/YYYYMMDD000002_orphan_cleanup_and_constraints.sql` |

---

## Task 1: Remove `awardBadge` Dead Code (Flutter)

**Files:**
- Delete: `lib/domain/usecases/badge/award_badge_usecase.dart`
- Modify: `lib/domain/repositories/badge_repository.dart`
- Modify: `lib/data/repositories/supabase/supabase_badge_repository.dart`
- Modify: `lib/presentation/providers/badge_provider.dart`
- Modify: `lib/presentation/providers/usecase_providers.dart`

- [ ] **Step 1: Delete the use case file**

```bash
rm lib/domain/usecases/badge/award_badge_usecase.dart
```

- [ ] **Step 2: Remove `awardBadge` from the repository interface**

In `lib/domain/repositories/badge_repository.dart`, remove the `awardBadge` method and the unused `badge.dart` entity import (only needed if `UserBadge` is no longer referenced — but `getUserBadges` still returns `UserBadge`, so keep the import). Remove only the method:

```dart
// REMOVE these lines (10-13):
  Future<Either<Failure, UserBadge>> awardBadge({
    required String userId,
    required String badgeId,
  });
```

The file should become:

```dart
import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/badge.dart';
import '../entities/badge_earned.dart';

abstract class BadgeRepository {
  Future<Either<Failure, List<UserBadge>>> getUserBadges(String userId);

  Future<Either<Failure, List<Badge>>> getRecentlyEarned({
    required String userId,
    int limit = 5,
  });

  Future<Either<Failure, List<BadgeEarned>>> checkAndAwardBadges(String userId);

  Future<Either<Failure, List<Badge>>> getAllBadges();
}
```

- [ ] **Step 3: Remove `awardBadge` and `_awardXP` from the repository implementation**

In `lib/data/repositories/supabase/supabase_badge_repository.dart`, remove two methods:

1. Remove `awardBadge` method (lines 40-82):
```dart
// REMOVE from line 40 (@override) through line 82 (closing brace)
  @override
  Future<Either<Failure, UserBadge>> awardBadge({
    ...entire method...
  }
```

2. Remove `_awardXP` helper (lines 158-179):
```dart
// REMOVE from line 158 (comment) through line 179 (closing brace)
  // ============================================
  // HELPER METHODS
  // ============================================

  Future<void> _awardXP(String userId, int amount, String reason) async {
    ...entire method...
  }
```

- [ ] **Step 4: Remove `BadgeController`, `BadgeState`, `badgeControllerProvider` from badge_provider**

In `lib/presentation/providers/badge_provider.dart`, remove lines 4 and 47-115. The file should become:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/badge.dart';
import '../../domain/usecases/badge/get_recently_earned_usecase.dart';
import '../../domain/usecases/badge/get_user_badges_usecase.dart';
import '../../domain/usecases/usecase.dart';
import 'auth_provider.dart';
import 'usecase_providers.dart';

/// Provides user's earned badges
final userBadgesProvider = FutureProvider<List<UserBadge>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final useCase = ref.watch(getUserBadgesUseCaseProvider);
  final result = await useCase(GetUserBadgesParams(userId: userId));
  return result.fold(
    (failure) => [],
    (badges) => badges,
  );
});

/// Provides recently earned badges
final recentBadgesProvider = FutureProvider<List<Badge>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final useCase = ref.watch(getRecentlyEarnedUseCaseProvider);
  final result = await useCase(GetRecentlyEarnedParams(userId: userId, limit: 3));
  return result.fold(
    (failure) => [],
    (badges) => badges,
  );
});

/// Provides all active badges (for showing earned vs unearned)
final allBadgesProvider = FutureProvider<List<Badge>>((ref) async {
  final useCase = ref.watch(getAllBadgesUseCaseProvider);
  final result = await useCase(const NoParams());
  return result.fold(
    (failure) => [],
    (badges) => badges,
  );
});
```

- [ ] **Step 5: Remove `awardBadgeUseCaseProvider` and its import from usecase_providers**

In `lib/presentation/providers/usecase_providers.dart`:

1. Remove the import (line 59):
```dart
// REMOVE:
import '../../domain/usecases/badge/award_badge_usecase.dart';
```

2. Remove the provider (lines 426-428):
```dart
// REMOVE:
final awardBadgeUseCaseProvider = Provider((ref) {
  return AwardBadgeUseCase(ref.watch(badgeRepositoryProvider));
});
```

- [ ] **Step 6: Verify build**

Run:
```bash
dart analyze lib/
```

Expected: 0 issues. If there are unused import warnings, fix them.

- [ ] **Step 7: Final grep verification**

Run:
```bash
grep -r "awardBadge\|AwardBadgeUseCase\|AwardBadgeParams\|badgeControllerProvider\|BadgeController\|BadgeState\b" lib/
```

Expected: Zero matches.

- [ ] **Step 8: Commit**

```bash
git add -A lib/domain/usecases/badge/award_badge_usecase.dart \
  lib/domain/repositories/badge_repository.dart \
  lib/data/repositories/supabase/supabase_badge_repository.dart \
  lib/presentation/providers/badge_provider.dart \
  lib/presentation/providers/usecase_providers.dart
git commit -m "refactor: remove dead awardBadge code (badge security audit phase 2)"
```

---

## Task 2: Badge RLS Migration

**Files:**
- Create: `supabase/migrations/20260407000002_badge_rls_phase2.sql`

- [ ] **Step 1: Create migration file**

```sql
-- Badge Security Phase 2: drop self-insert policy
-- All badge awarding goes through check_and_award_badges (SECURITY DEFINER).
-- The direct INSERT path (awardBadge in Flutter) was dead code and has been removed.

DROP POLICY IF EXISTS "Users can only insert own badges" ON user_badges;
```

- [ ] **Step 2: Dry-run**

Run:
```bash
supabase db push --dry-run
```

Expected: Shows `20260407000002_badge_rls_phase2.sql` as pending.

- [ ] **Step 3: Push migration**

Run:
```bash
supabase db push
```

Expected: Applied successfully.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260407000002_badge_rls_phase2.sql
git commit -m "fix(security): drop user_badges self-insert policy"
```

---

## Task 3: N+1 RPC Fix — `get_class_learning_path_units`

**Files:**
- Create: `supabase/migrations/20260407000003_rpc_n1_fix.sql`

- [ ] **Step 1: Create migration with CTE-based rewrite**

```sql
-- Fix N+1 correlated subqueries in get_class_learning_path_units and get_unit_assignment_items.
-- Problem: per-row SELECT ARRAY_AGG and SELECT COUNT(*) run once per scope_unit_items row.
-- Fix: pre-aggregate with CTEs, join once.

-- =============================================================================
-- 1. get_class_learning_path_units — replace correlated subqueries with CTEs
-- Return type is unchanged; only the execution plan changes.
-- =============================================================================
CREATE OR REPLACE FUNCTION get_class_learning_path_units(p_class_id UUID)
RETURNS TABLE (
  path_id UUID,
  path_name VARCHAR,
  unit_id UUID,
  scope_lp_unit_id UUID,
  unit_name VARCHAR,
  unit_color VARCHAR,
  unit_icon VARCHAR,
  unit_sort_order INTEGER,
  item_type VARCHAR,
  item_id UUID,
  item_sort_order INTEGER,
  word_list_id UUID,
  word_list_name VARCHAR,
  words TEXT[],
  book_id UUID,
  book_title VARCHAR,
  book_chapter_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_school_id UUID;
  v_grade INTEGER;
BEGIN
  -- Auth: caller must be teacher/admin
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role IN ('teacher', 'admin')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT cl.school_id, cl.grade INTO v_school_id, v_grade
  FROM classes cl WHERE cl.id = p_class_id;

  IF v_school_id IS NULL THEN
    RAISE EXCEPTION 'Class not found: %', p_class_id;
  END IF;

  RETURN QUERY
  WITH word_list_words AS (
    SELECT wli.word_list_id, ARRAY_AGG(vw.word ORDER BY vw.word) AS words
    FROM word_list_items wli
    JOIN vocabulary_words vw ON vw.id = wli.word_id
    GROUP BY wli.word_list_id
  ),
  book_chapters AS (
    SELECT ch.book_id, COUNT(*)::BIGINT AS chapter_count
    FROM chapters ch
    GROUP BY ch.book_id
  )
  SELECT
    slp.id AS path_id,
    slp.name::VARCHAR AS path_name,
    vu.id AS unit_id,
    slpu.id AS scope_lp_unit_id,
    vu.name::VARCHAR AS unit_name,
    vu.color::VARCHAR AS unit_color,
    vu.icon::VARCHAR AS unit_icon,
    slpu.sort_order AS unit_sort_order,
    sui.item_type::VARCHAR,
    sui.id AS item_id,
    sui.sort_order AS item_sort_order,
    sui.word_list_id,
    wl.name::VARCHAR AS word_list_name,
    wlw.words,
    sui.book_id,
    b.title::VARCHAR AS book_title,
    bc.chapter_count AS book_chapter_count
  FROM scope_learning_paths slp
  JOIN scope_learning_path_units slpu ON slpu.scope_learning_path_id = slp.id
  JOIN vocabulary_units vu ON vu.id = slpu.unit_id
  LEFT JOIN scope_unit_items sui ON sui.scope_lp_unit_id = slpu.id
  LEFT JOIN word_lists wl ON wl.id = sui.word_list_id
  LEFT JOIN books b ON b.id = sui.book_id
  LEFT JOIN word_list_words wlw ON wlw.word_list_id = sui.word_list_id
  LEFT JOIN book_chapters bc ON bc.book_id = sui.book_id
  WHERE slp.school_id = v_school_id
    AND (
      (slp.grade IS NULL AND slp.class_id IS NULL)
      OR (slp.grade = v_grade AND slp.class_id IS NULL)
      OR (slp.class_id = p_class_id)
    )
    AND vu.is_active = true
  ORDER BY slp.sort_order, slpu.sort_order, sui.sort_order;
END;
$$;

-- =============================================================================
-- 2. get_unit_assignment_items — replace 5 correlated subqueries with CTEs
-- Return type is unchanged; only the execution plan changes.
-- =============================================================================
CREATE OR REPLACE FUNCTION get_unit_assignment_items(
  p_scope_lp_unit_id UUID,
  p_student_id UUID
)
RETURNS TABLE (
  item_type VARCHAR,
  sort_order INTEGER,
  word_list_id UUID,
  word_list_name VARCHAR,
  word_count BIGINT,
  is_word_list_completed BOOLEAN,
  book_id UUID,
  book_title VARCHAR,
  total_chapters BIGINT,
  completed_chapters BIGINT,
  is_book_completed BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF auth.uid() != p_student_id THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  WITH word_counts AS (
    SELECT wli.word_list_id, COUNT(*)::BIGINT AS cnt
    FROM word_list_items wli
    GROUP BY wli.word_list_id
  ),
  wl_completions AS (
    SELECT uwlp.word_list_id
    FROM user_word_list_progress uwlp
    WHERE uwlp.user_id = p_student_id AND uwlp.completed_at IS NOT NULL
  ),
  chapter_counts AS (
    SELECT ch.book_id, COUNT(*)::BIGINT AS total
    FROM chapters ch
    GROUP BY ch.book_id
  ),
  reading AS (
    SELECT rp.book_id,
           COALESCE(array_length(rp.completed_chapter_ids, 1), 0)::BIGINT AS completed
    FROM reading_progress rp
    WHERE rp.user_id = p_student_id
  )
  SELECT
    sui.item_type::VARCHAR,
    sui.sort_order,
    sui.word_list_id,
    wl.name::VARCHAR AS word_list_name,
    wc.cnt AS word_count,
    (wlc.word_list_id IS NOT NULL) AS is_word_list_completed,
    sui.book_id,
    b.title::VARCHAR AS book_title,
    cc.total AS total_chapters,
    r.completed AS completed_chapters,
    CASE
      WHEN sui.book_id IS NOT NULL AND cc.total IS NOT NULL AND cc.total > 0
      THEN COALESCE(r.completed, 0) >= cc.total
      ELSE NULL
    END AS is_book_completed
  FROM scope_unit_items sui
  LEFT JOIN word_lists wl ON wl.id = sui.word_list_id
  LEFT JOIN books b ON b.id = sui.book_id
  LEFT JOIN word_counts wc ON wc.word_list_id = sui.word_list_id
  LEFT JOIN wl_completions wlc ON wlc.word_list_id = sui.word_list_id
  LEFT JOIN chapter_counts cc ON cc.book_id = sui.book_id
  LEFT JOIN reading r ON r.book_id = sui.book_id
  WHERE sui.scope_lp_unit_id = p_scope_lp_unit_id
  ORDER BY sui.sort_order;
END;
$$;
```

- [ ] **Step 2: Dry-run**

Run:
```bash
supabase db push --dry-run
```

Expected: Shows migration as pending, no errors.

- [ ] **Step 3: Push migration**

Run:
```bash
supabase db push
```

Expected: Applied successfully.

- [ ] **Step 4: Verify output matches**

Using test user `teacher@demo.com`, run both RPCs and verify output is identical to before.
Teacher flow: open assignment creation → select class → unit list should load with word lists and chapter counts.
Student flow: open unit assignment → items should show correct completion status.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260407000003_rpc_n1_fix.sql
git commit -m "perf: replace N+1 correlated subqueries with CTEs in learning path RPCs"
```

---

## Task 4: Orphan Table Cleanup + Safety Constraints

**Files:**
- Create: `supabase/migrations/20260407000004_cleanup_and_constraints.sql`

This task requires **pre-check queries** run against production before the migration is written.
The migration file must be adapted based on the results.

- [ ] **Step 1: Run pre-check queries**

Run each query against the remote database and record results:

```bash
# 1. Check if any daily_login badges exist (decides FIX-15 approach)
supabase db execute "SELECT id, name FROM badges WHERE condition_type = 'daily_login';"

# 2. Check existing XP source values (decides FIX-16 CHECK list)
supabase db execute "SELECT DISTINCT source FROM xp_logs ORDER BY source;"

# 3. Check existing coin source values
supabase db execute "SELECT DISTINCT source FROM coin_logs ORDER BY source;"

# 4. Check for duplicate attempts in activity_results (blocks FIX-20 if duplicates exist)
supabase db execute "SELECT user_id, activity_id, attempt_number, COUNT(*) FROM activity_results GROUP BY user_id, activity_id, attempt_number HAVING COUNT(*) > 1;"

# 5. Check for duplicate attempts in book_quiz_results (blocks FIX-21)
supabase db execute "SELECT user_id, quiz_id, attempt_number, COUNT(*) FROM book_quiz_results GROUP BY user_id, quiz_id, attempt_number HAVING COUNT(*) > 1;"
```

Record the results. If query 4 or 5 return rows, those duplicates must be deduplicated before adding the UNIQUE index. Add a dedup step to the migration.

- [ ] **Step 2: Create migration file**

Based on pre-check results, create `supabase/migrations/20260407000004_cleanup_and_constraints.sql`:

```sql
-- Database Audit Phase 3: Cleanup and safety constraints
-- Pre-checks completed — adapt CHECK values based on production data.

-- =============================================================================
-- 1. Drop orphan daily_quest_pack tables & functions (FIX-14)
-- Superseded by daily_quest_bonus_claims + claim_daily_bonus.
-- Zero Flutter references confirmed by grep.
-- =============================================================================
DROP FUNCTION IF EXISTS claim_daily_quest_pack(UUID);
DROP FUNCTION IF EXISTS has_daily_quest_pack_claimed(UUID);
DROP TABLE IF EXISTS daily_quest_pack_claims;

-- =============================================================================
-- 2. XP source CHECK constraint (FIX-16)
-- Values verified from pre-check query + codebase grep.
-- Add any additional values found in pre-check step 1 query 2.
-- =============================================================================
ALTER TABLE xp_logs ADD CONSTRAINT chk_xp_source CHECK (
  source IN (
    'chapter_complete', 'inline_activity', 'quiz_pass', 'book_complete',
    'badge', 'streak_milestone', 'daily_review', 'vocabulary_session',
    'daily_quest'
    -- ADD any unexpected values found in pre-check here
  )
);

-- =============================================================================
-- 3. Coin source CHECK constraint (FIX-16)
-- Values verified from pre-check query + codebase grep.
-- Add any additional values found in pre-check step 1 query 3.
-- =============================================================================
ALTER TABLE coin_logs ADD CONSTRAINT chk_coin_source CHECK (
  source IN (
    'pack_purchase', 'daily_quest', 'streak_freeze',
    'vocabulary_session', 'daily_review', 'card_trade',
    'avatar_item', 'avatar_gender_change'
    -- ADD any unexpected values found in pre-check here
  )
);

-- =============================================================================
-- 4. Unique attempt constraints (FIX-20, FIX-21)
-- Only add if pre-check confirmed no duplicates exist.
-- If duplicates were found, add dedup logic before this:
--   DELETE FROM activity_results WHERE id NOT IN (
--     SELECT DISTINCT ON (user_id, activity_id, attempt_number) id
--     FROM activity_results ORDER BY user_id, activity_id, attempt_number, completed_at DESC
--   );
-- =============================================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_activity_results_unique_attempt
  ON activity_results(user_id, activity_id, attempt_number);

CREATE UNIQUE INDEX IF NOT EXISTS idx_quiz_results_unique_attempt
  ON book_quiz_results(user_id, quiz_id, attempt_number);

-- =============================================================================
-- 5. Fix user_card_stats drift after trades (FIX-26)
-- Add recalculation at end of trade_duplicate_cards.
-- Must CREATE OR REPLACE the full function — read current version first.
-- =============================================================================
-- NOTE: The trade_duplicate_cards function must be read from the latest migration
-- that defines it, then the stats update line added at the end before RETURN.
-- The line to add before the final RETURN:
--
--   UPDATE user_card_stats
--   SET total_unique_cards = (SELECT COUNT(*) FROM user_cards WHERE user_id = p_user_id),
--       updated_at = NOW()
--   WHERE user_id = p_user_id;
```

**IMPORTANT:** The CHECK constraint values in sections 2 and 3 must match the pre-check query results exactly. If the pre-check reveals unexpected source values, add them to the CHECK list.

- [ ] **Step 3: Handle FIX-15 (daily_login badge condition)**

Based on pre-check query 1 results:

**If no `daily_login` badges exist** — add to the migration:
```sql
ALTER TABLE badges DROP CONSTRAINT IF EXISTS badges_condition_type_check;
ALTER TABLE badges ADD CONSTRAINT badges_condition_type_check
  CHECK (condition_type IN (
    'books_read', 'xp_earned', 'streak_days',
    'words_mastered', 'quizzes_passed', 'cards_collected'
  ));
```

**If `daily_login` badges exist** — add the handler to `check_and_award_badges`. This requires reading the full current function from the latest migration that defines it, then adding the handler branch.

- [ ] **Step 4: Read and update `trade_duplicate_cards` for FIX-26**

Find the latest version of `trade_duplicate_cards`:
```bash
grep -l "trade_duplicate_cards" supabase/migrations/*.sql | tail -1
```

Read that file, copy the full function, add the stats recalculation line before the final RETURN, and include the full `CREATE OR REPLACE FUNCTION` in the migration.

- [ ] **Step 5: Dry-run**

Run:
```bash
supabase db push --dry-run
```

Expected: Shows migration as pending, no errors.

- [ ] **Step 6: Push migration**

Run:
```bash
supabase db push
```

Expected: Applied successfully.

- [ ] **Step 7: Verify**

1. Daily quest bonus claim still works (old table gone, new table unaffected)
2. XP award with valid source succeeds: `complete_vocabulary_session` → XP logged
3. Card trade → `total_unique_cards` reflects correct count
4. Attempt duplicate insert blocked by UNIQUE index

- [ ] **Step 8: Commit**

```bash
git add supabase/migrations/20260407000004_cleanup_and_constraints.sql
git commit -m "fix: drop orphan tables, add source constraints, fix card stats drift"
```

---

## Task 5: Update Audit Documentation

**Files:**
- Modify: `docs/database-audit-fixes.md`

- [ ] **Step 1: Update status header**

Add Phase 2 and Phase 3 completion status to the header of `docs/database-audit-fixes.md`:

```markdown
> ## Status
> - **Phase 1:** COMPLETED (2026-04-07) — `20260407000001_database_audit_phase1.sql`
> - **Phase 2:** COMPLETED (2026-04-07) — dead code removal + `20260407000002_badge_rls_phase2.sql`
> - **Phase 3:** COMPLETED (2026-04-07) — `20260407000003_rpc_n1_fix.sql` + `20260407000004_cleanup_and_constraints.sql`
> - **Deferred:** FIX-18 (system_settings), FIX-19 (weekly XP summary), FIX-22 (rename), FIX-25 (array FK), FIX-27 (league reset)
```

- [ ] **Step 2: Commit**

```bash
git add docs/database-audit-fixes.md
git commit -m "docs: mark database audit phases 2-3 complete"
```
