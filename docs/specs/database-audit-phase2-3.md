# Database Audit — Phase 2 & 3 Specification

> **Depends on:** Phase 1 migration (`20260407000001_database_audit_phase1.sql`) — already applied
> **Reference:** `docs/database-audit-fixes.md` (full audit report)

---

## Phase 2: Dead Code Cleanup + Badge Security

### Context

The `awardBadge` flow in Flutter performs a **direct INSERT** to `user_badges`. Phase 1 couldn't
drop this policy without breaking the app. However, investigation revealed that this entire flow
is **dead code** — `BadgeController.awardBadge()` is never called from any screen or widget.

All badge awarding in production goes through `check_and_award_badges` RPC (SECURITY DEFINER).

The RLS policy was already tightened to `user_id = auth.uid()` in migration `20260220000001`,
so the security risk is limited to: **a user can self-award any badge by calling INSERT with
their own `user_id` and a known `badge_id`**. This requires knowing a badge UUID and using
the Supabase client directly — low probability but still exploitable.

### 2A: Remove Dead Code (Flutter)

**Files to delete:**
- `lib/domain/usecases/badge/award_badge_usecase.dart` — unused use case

**Files to modify:**

1. `lib/domain/repositories/badge_repository.dart` — remove `awardBadge` method signature
2. `lib/data/repositories/supabase/supabase_badge_repository.dart` — remove `awardBadge` method
   (lines 40-82) and `_awardXP` helper (lines 162-179, only used by `awardBadge`)
3. `lib/presentation/providers/badge_provider.dart` — remove `BadgeController` class,
   `BadgeState` class, and `badgeControllerProvider` (lines 47-115)
4. `lib/presentation/providers/usecase_providers.dart` — remove `awardBadgeUseCaseProvider`
   (line 426-428) and its import

**Verification:**
```bash
dart analyze lib/
grep -r "awardBadge\|AwardBadgeUseCase\|badgeControllerProvider\|BadgeController\|BadgeState" lib/
# Should return zero matches after cleanup
```

### 2B: Tighten Badge RLS (Migration)

After dead code is removed, drop the INSERT policy entirely:

```sql
-- user_badges: remove self-insert capability
-- All badge awarding now exclusively through check_and_award_badges (SECURITY DEFINER)
DROP POLICY IF EXISTS "Users can only insert own badges" ON user_badges;
```

**Verification:**
1. `supabase.from('user_badges').insert({...})` → RLS violation (expected)
2. `check_and_award_badges` RPC → still awards badges (SECURITY DEFINER bypasses RLS)
3. Badge list displays correctly on profile screen

---

## Phase 3: Performance, Correctness & Cleanup

### 3A: Drop Orphan Table & Functions (FIX-14)

**Problem:** `daily_quest_pack_claims` table and `claim_daily_quest_pack` / `has_daily_quest_pack_claimed`
functions were superseded by `daily_quest_bonus_claims` + `claim_daily_bonus` (migration `20260322000003`).
Flutter uses `claimDailyBonus` exclusively — zero references to the old flow.

**Evidence:**
```
grep -r "daily_quest_pack_claims\|claimDailyQuestPack\|claim_daily_quest_pack\|hasDailyQuestPackClaimed" lib/
→ No matches
```

**Migration:**
```sql
-- Drop old functions first (depend on the table)
DROP FUNCTION IF EXISTS claim_daily_quest_pack(UUID);
DROP FUNCTION IF EXISTS has_daily_quest_pack_claimed(UUID);

-- Drop orphan table
DROP TABLE IF EXISTS daily_quest_pack_claims;
```

**Risk:** Zero — dead code on both client and server.

**Shared package cleanup:** Check if `DbTables` or `RpcFunctions` reference these and remove.

---

### 3B: N+1 Query Fix — `get_class_learning_path_units` (FIX-12)

**Problem:** Two correlated subqueries per `scope_unit_items` row:
1. `SELECT ARRAY_AGG(vw.word ...)` for word list words
2. `SELECT COUNT(*) FROM chapters` for book chapter count

For a path with 30 items → 60 extra queries per RPC call.

**Current function signature** (must not change — Flutter depends on return columns):
```sql
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
```

**Fix approach:** Replace correlated subqueries with CTEs that pre-aggregate:

```sql
WITH word_list_words AS (
  SELECT wli.word_list_id, ARRAY_AGG(vw.word ORDER BY vw.word) AS words
  FROM word_list_items wli
  JOIN vocabulary_words vw ON vw.id = wli.word_id
  GROUP BY wli.word_list_id
),
book_chapters AS (
  SELECT ch.book_id, COUNT(*) AS chapter_count
  FROM chapters ch
  GROUP BY ch.book_id
)
SELECT ...
LEFT JOIN word_list_words wlw ON wlw.word_list_id = sui.word_list_id
LEFT JOIN book_chapters bc ON bc.book_id = sui.book_id
...
```

**Risk:** Low — return type unchanged, data identical, only execution plan changes.

**Verification:**
1. Teacher opens assignment creation → unit list loads with correct word lists and chapter counts
2. Compare output before/after with test data: `SELECT * FROM get_class_learning_path_units('CLASS_ID')`

---

### 3C: N+1 Query Fix — `get_unit_assignment_items` (FIX-13)

**Problem:** 5 correlated subqueries per item row:
1. word_list_items COUNT
2. user_word_list_progress completion check
3. chapters COUNT
4. reading_progress completed chapters
5. reading_progress completion check (re-counts chapters!)

**Current function signature** (must not change):
```sql
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
```

**Fix approach:** Same CTE pattern:

```sql
WITH word_counts AS (
  SELECT wli.word_list_id, COUNT(*) AS cnt
  FROM word_list_items wli GROUP BY wli.word_list_id
),
wl_completions AS (
  SELECT uwlp.word_list_id
  FROM user_word_list_progress uwlp
  WHERE uwlp.user_id = p_student_id AND uwlp.completed_at IS NOT NULL
),
chapter_counts AS (
  SELECT ch.book_id, COUNT(*) AS total
  FROM chapters ch GROUP BY ch.book_id
),
reading AS (
  SELECT rp.book_id, COALESCE(array_length(rp.completed_chapter_ids, 1), 0) AS completed
  FROM reading_progress rp WHERE rp.user_id = p_student_id
)
SELECT ...
LEFT JOIN word_counts wc ON wc.word_list_id = sui.word_list_id
LEFT JOIN wl_completions wlc ON wlc.word_list_id = sui.word_list_id
LEFT JOIN chapter_counts cc ON cc.book_id = sui.book_id
LEFT JOIN reading r ON r.book_id = sui.book_id
...
```

**Additional fix:** The original uses `completed_chapters >= total_chapters` which re-runs the
chapters COUNT subquery. CTE version avoids this by using `r.completed >= cc.total` directly.

**Risk:** Low — same return type, same data, better plan.

**Verification:**
1. Student opens unit assignment → items show correct completion status
2. Compare output before/after: `SELECT * FROM get_unit_assignment_items('SCOPE_LP_UNIT_ID', 'STUDENT_ID')`

---

### 3D: Source CHECK Constraints (FIX-16)

**Problem:** `xp_logs.source` and `coin_logs.source` are free-form `VARCHAR(50)`. Typos are
silently accepted.

**Known source values (verified from codebase):**

XP sources (client + server):
| Value | Origin |
|-------|--------|
| `'chapter_complete'` | Client — `book_provider.dart`, `cached_book_repository.dart` |
| `'inline_activity'` | Client — `reader_provider.dart` |
| `'quiz_pass'` | Client — `book_quiz_provider.dart` |
| `'book_complete'` | Client — `book_quiz_provider.dart`, `book_provider.dart` |
| `'badge_earned'` | Client — `supabase_badge_repository.dart` (dead code, removing in 2A) |
| `'badge'` | Server — `check_and_award_badges` RPC |
| `'streak_milestone'` | Server — `update_user_streak` RPC |
| `'daily_review'` | Server — `complete_daily_review` RPC |
| `'vocabulary_session'` | Server — `complete_vocabulary_session` RPC |
| `'daily_quest'` | Server — quest reward in `complete_daily_review` |

Coin sources:
| Value | Origin |
|-------|--------|
| `'pack_purchase'` | Server — `buy_card_pack` RPC |
| `'daily_quest'` | Server — quest reward |
| `'streak_freeze'` | Server — `buy_streak_freeze` RPC |
| `'vocabulary_session'` | Server — `complete_vocabulary_session` |
| `'daily_review'` | Server — `complete_daily_review` |
| `'card_trade'` | Server — `trade_duplicate_cards` |
| `'avatar_item'` | Server — `buy_avatar_item` |
| `'avatar_gender_change'` | Server — `set_avatar_base` (gender switch fee) |

**Pre-check required:**
```sql
-- Verify no unexpected values exist in production
SELECT DISTINCT source FROM xp_logs ORDER BY source;
SELECT DISTINCT source FROM coin_logs ORDER BY source;
```

**Migration:**
```sql
ALTER TABLE xp_logs ADD CONSTRAINT chk_xp_source CHECK (
  source IN (
    'chapter_complete', 'inline_activity', 'quiz_pass', 'book_complete',
    'badge', 'streak_milestone', 'daily_review', 'vocabulary_session',
    'daily_quest'
  )
);

ALTER TABLE coin_logs ADD CONSTRAINT chk_coin_source CHECK (
  source IN (
    'pack_purchase', 'daily_quest', 'streak_freeze',
    'vocabulary_session', 'daily_review', 'card_trade',
    'avatar_item', 'avatar_gender_change'
  )
);
```

**Important:** After removing dead `awardBadge` code (Phase 2A), `'badge_earned'` is no longer
used from the client. The server uses `'badge'`. Do NOT include `'badge_earned'` in the CHECK.

**Risk:** Medium — if a source value exists in production that we didn't list, the constraint
will fail to add. Always run the pre-check query first.

---

### 3E: Handle `daily_login` Badge Condition Type (FIX-15)

**Problem:** `badges.condition_type` CHECK allows `'daily_login'` but `check_and_award_badges`
has no handler for it. Badges with this type can never be earned.

**Decision needed:** Does any badge with `condition_type = 'daily_login'` exist in production?

**Pre-check:**
```sql
SELECT * FROM badges WHERE condition_type = 'daily_login';
```

**Option A — Implement handler** (if badges exist or are planned):
```sql
-- Add to check_and_award_badges, inside the badge condition loop:
ELSIF v_badge.condition_type = 'daily_login' THEN
  IF (SELECT COUNT(DISTINCT login_date)
      FROM daily_logins
      WHERE user_id = p_user_id) >= v_badge.condition_value THEN
    v_earned := TRUE;
  END IF;
```

**Option B — Remove unused type** (if no badges exist):
```sql
ALTER TABLE badges DROP CONSTRAINT IF EXISTS badges_condition_type_check;
ALTER TABLE badges ADD CONSTRAINT badges_condition_type_check
  CHECK (condition_type IN (
    'books_read', 'xp_earned', 'streak_days',
    'words_mastered', 'quizzes_passed', 'cards_collected'
  ));
```

**Risk:** Option A is additive (zero risk). Option B requires verifying no rows use the value.

---

### 3F: Unique Constraints on Multi-Attempt Tables (FIX-20, FIX-21)

**Problem:** `activity_results` and `book_quiz_results` allow duplicate `attempt_number` values
for the same user+activity/quiz combination. The `attempt_number` is auto-populated by trigger,
but direct INSERTs bypass the trigger default.

**Migration:**
```sql
-- Prevent duplicate attempts per user per activity
CREATE UNIQUE INDEX IF NOT EXISTS idx_activity_results_unique_attempt
  ON activity_results(user_id, activity_id, attempt_number);

-- Prevent duplicate attempts per user per quiz
CREATE UNIQUE INDEX IF NOT EXISTS idx_quiz_results_unique_attempt
  ON book_quiz_results(user_id, quiz_id, attempt_number);
```

**Pre-check required:**
```sql
-- Verify no duplicates exist (would block index creation)
SELECT user_id, activity_id, attempt_number, COUNT(*)
FROM activity_results
GROUP BY user_id, activity_id, attempt_number
HAVING COUNT(*) > 1;

SELECT user_id, quiz_id, attempt_number, COUNT(*)
FROM book_quiz_results
GROUP BY user_id, quiz_id, attempt_number
HAVING COUNT(*) > 1;
```

**Risk:** If duplicates exist, index creation fails. Need to deduplicate first.

---

### 3G: Fix `user_card_stats.total_unique_cards` Drift (FIX-26)

**Problem:** `total_unique_cards` is only recalculated during `open_card_pack`. When
`trade_duplicate_cards` removes all copies of a card (quantity reaches 0 and row is deleted),
the counter doesn't decrement.

**Current trade function behavior:**
```sql
-- Trades 3 duplicates for 1 random new card
-- If a card's quantity reaches 0 → DELETE FROM user_cards
-- But user_card_stats.total_unique_cards is NOT updated
```

**Fix:** Add stats recalculation at the end of `trade_duplicate_cards`:

```sql
-- At the end of trade_duplicate_cards, after the trade logic:
UPDATE user_card_stats
SET total_unique_cards = (SELECT COUNT(*) FROM user_cards WHERE user_id = p_user_id),
    updated_at = NOW()
WHERE user_id = p_user_id;
```

**Risk:** Zero — additive fix, existing behavior unchanged.

---

## Migration Grouping

### Phase 2 Migration: `YYYYMMDD000001_badge_security_phase2.sql`
- Drop `user_badges` INSERT policy (after Flutter dead code removal)

### Phase 3 Migration (can be split):

**`YYYYMMDD000001_rpc_performance.sql`** — FIX 12, 13
- `get_class_learning_path_units` CTE refactor
- `get_unit_assignment_items` CTE refactor

**`YYYYMMDD000002_cleanup_and_constraints.sql`** — FIX 14, 15, 16, 20, 21, 26
- Drop orphan table + functions
- Badge condition type fix (after pre-check)
- Source CHECK constraints (after pre-check)
- Unique indexes (after pre-check)
- Trade stats fix

---

## Deferred Items (Future Sprints)

These are valid improvements but not urgent:

| Item | Why Deferred |
|------|--------------|
| **FIX-18:** system_settings policy | Low risk — values aren't secret enough to exploit |
| **FIX-19:** Weekly XP summary table | Optimization — current perf is acceptable at current scale |
| **FIX-22:** Rename pack_purchases table | Naming only — no functional impact |
| **FIX-25:** completed_chapter_ids validation trigger | Adds write overhead, current approach works |
| **FIX-27:** League reset set-based refactor | Complex rewrite, runs weekly off-peak, acceptable perf |

---

## Testing Plan

### Phase 2 Testing
1. **Build check:** `dart analyze lib/` passes with no errors
2. **Badge display:** Profile screen shows earned badges correctly
3. **Badge awarding:** Complete a vocabulary session → badges auto-awarded via RPC
4. **Negative test:** Direct `supabase.from('user_badges').insert(...)` fails with RLS error

### Phase 3 Testing
1. **RPC output comparison:** Run old vs new RPC with same params, compare JSON output
2. **Teacher flow:** Create unit assignment → correct word lists and chapter counts
3. **Student flow:** View unit assignment → correct completion status
4. **Daily quest:** Complete all quests → bonus claim works (uses new system, not old)
5. **Card trade:** Trade duplicates → `total_unique_cards` reflects correct count
6. **XP/Coin logs:** Award XP with valid source → succeeds; invalid source → constraint error
