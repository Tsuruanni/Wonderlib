# XP/Leveling Audit Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 3 audit findings from the Feature #9 (XP/Leveling) spec and update the spec's audit table.

**Architecture:** Dead code removal in Dart clean architecture layers, two SQL migrations for security + comment fixes, and a documentation update. No behavioral changes to the app.

**Tech Stack:** Dart/Flutter, Supabase PostgreSQL migrations

---

### Task 1: Remove dead `getLeaderboard()` method

**Files:**
- Modify: `lib/domain/repositories/user_repository.dart:30-35`
- Modify: `lib/data/repositories/supabase/supabase_user_repository.dart:210-242`

- [ ] **Step 1: Remove `getLeaderboard()` from the repository interface**

In `lib/domain/repositories/user_repository.dart`, delete lines 30-35:

```dart
  Future<Either<Failure, List<User>>> getLeaderboard({
    String? schoolId,
    String? classId,
    int limit = 10,
  });
```

- [ ] **Step 2: Remove `getLeaderboard()` from the Supabase implementation**

In `lib/data/repositories/supabase/supabase_user_repository.dart`, delete the entire `getLeaderboard()` override (lines 210-242):

```dart
  @override
  Future<Either<Failure, List<domain.User>>> getLeaderboard({
    String? schoolId,
    String? classId,
    int limit = 10,
  }) async {
    try {
      var query = _supabase
          .from(DbTables.profiles)
          .select()
          .eq('role', 'student');

      if (schoolId != null) {
        query = query.eq('school_id', schoolId);
      }

      if (classId != null) {
        query = query.eq('class_id', classId);
      }

      final response = await query
          .order('xp', ascending: false)
          .limit(limit);

      final users = (response as List).map((json) => UserModel.fromJson(json).toEntity()).toList();

      return Right(users);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
```

- [ ] **Step 3: Verify no compilation errors**

Run: `dart analyze lib/`
Expected: No errors (warnings OK). If `getLeaderboard` appears in any error, a caller was missed — investigate before proceeding.

- [ ] **Step 4: Commit**

```bash
git add lib/domain/repositories/user_repository.dart lib/data/repositories/supabase/supabase_user_repository.dart
git commit -m "cleanup: remove dead getLeaderboard() from UserRepository (#9 audit fix 1)"
```

---

### Task 2: Add auth check to `award_xp_transaction` RPC

**Files:**
- Create: `supabase/migrations/20260328000004_add_auth_check_to_award_xp.sql`

- [ ] **Step 1: Create the migration file**

Create `supabase/migrations/20260328000004_add_auth_check_to_award_xp.sql` with:

```sql
-- Add auth.uid() verification to award_xp_transaction RPC.
-- Prevents a client from awarding XP to another user.
-- SECURITY DEFINER bypasses RLS, so we must verify identity explicitly.
-- Same pattern used in complete_vocabulary_session (20260328000002).

CREATE OR REPLACE FUNCTION award_xp_transaction(
    p_user_id UUID,
    p_amount INTEGER,
    p_source VARCHAR,
    p_source_id UUID DEFAULT NULL,
    p_description TEXT DEFAULT NULL
)
RETURNS TABLE(new_xp INTEGER, new_level INTEGER, level_up BOOLEAN)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_xp INTEGER;
    v_current_coins INTEGER;
    v_new_xp INTEGER;
    v_new_coins INTEGER;
    v_current_level INTEGER;
    v_new_level INTEGER;
BEGIN
    -- Auth check: ensure caller is the user they claim to be
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized: user mismatch';
    END IF;

    -- Lock the row FIRST to prevent race conditions
    SELECT xp, level, coins INTO v_current_xp, v_current_level, v_current_coins
    FROM profiles
    WHERE id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: %', p_user_id;
    END IF;

    -- Idempotency check AFTER lock (prevents TOCTOU race condition)
    IF p_source_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM xp_logs
        WHERE user_id = p_user_id AND source = p_source AND source_id = p_source_id
    ) THEN
        -- Already awarded — return current state without modification
        RETURN QUERY SELECT v_current_xp, v_current_level, false;
        RETURN;
    END IF;

    -- Calculate new values
    v_new_xp := v_current_xp + p_amount;
    v_new_level := calculate_level(v_new_xp);
    v_new_coins := v_current_coins + p_amount;

    -- Update profile (XP + level + coins atomically)
    UPDATE profiles
    SET xp = v_new_xp,
        level = v_new_level,
        coins = v_new_coins,
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Log XP
    INSERT INTO xp_logs (user_id, amount, source, source_id, description)
    VALUES (p_user_id, p_amount, p_source, p_source_id, p_description);

    -- Log coins
    INSERT INTO coin_logs (user_id, amount, balance_after, source, source_id, description)
    VALUES (p_user_id, p_amount, v_new_coins, p_source, p_source_id, p_description);

    RETURN QUERY SELECT v_new_xp, v_new_level, (v_new_level > v_current_level);
END;
$$;
```

- [ ] **Step 2: Dry-run the migration**

Run: `supabase db push --dry-run`
Expected: Shows the migration will be applied, no errors.

- [ ] **Step 3: Push the migration**

Run: `supabase db push`
Expected: Migration applied successfully.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260328000004_add_auth_check_to_award_xp.sql
git commit -m "security: add auth check to award_xp_transaction RPC (#9 audit fix 2)"
```

---

### Task 3: Fix misleading comments in `calculate_level`

**Files:**
- Create: `supabase/migrations/20260328000005_fix_calculate_level_comments.sql`

- [ ] **Step 1: Create the migration file**

Create `supabase/migrations/20260328000005_fix_calculate_level_comments.sql` with:

```sql
-- Fix misleading comments in calculate_level function.
-- Old comments said thresholds were "0, 100, 300, 600" and formula was "n*(n+1)*50".
-- Actual thresholds from the formula are "0, 200, 600, 1200, 2000" matching
-- client-side LevelHelper.xpForLevel(level) = (level-1) * level * 100.
-- Function body is UNCHANGED — only comments are corrected.

CREATE OR REPLACE FUNCTION calculate_level(p_xp INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    -- Level thresholds: 0, 200, 600, 1200, 2000, 3000, 4200, 5600, 7200, 9000...
    -- Formula: threshold(level) = (level - 1) * level * 100
    -- Inverse: level = floor((-1 + sqrt(1 + xp/25)) / 2) + 1
    -- Must match client-side LevelHelper.xpForLevel() in level_helper.dart
    IF p_xp <= 0 THEN
        RETURN 1;
    END IF;
    RETURN LEAST(GREATEST(FLOOR((-1 + SQRT(1 + p_xp / 25.0)) / 2) + 1, 1), 100)::INTEGER;
END;
$$;

COMMENT ON FUNCTION calculate_level IS 'Calculate user level from XP using quadratic formula. Capped at 100.';
```

- [ ] **Step 2: Dry-run the migration**

Run: `supabase db push --dry-run`
Expected: Shows the migration will be applied, no errors.

- [ ] **Step 3: Push the migration**

Run: `supabase db push`
Expected: Migration applied successfully.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260328000005_fix_calculate_level_comments.sql
git commit -m "docs: fix misleading comments in calculate_level SQL function (#9 audit fix 3)"
```

---

### Task 4: Update spec audit table and known issues

**Files:**
- Modify: `docs/specs/09-xp-leveling.md`

- [ ] **Step 1: Update audit findings table**

In `docs/specs/09-xp-leveling.md`, replace the findings table (lines 6-11):

**Before:**
```markdown
| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Dead Code | `getLeaderboard()` in `UserRepository` and `SupabaseUserRepository` — old method replaced by RPC-based leaderboard methods, never called | Low | TODO |
| 2 | Security | `award_xp_transaction` is SECURITY DEFINER but doesn't validate `p_user_id = auth.uid()` — client could award XP to any user | Medium | TODO |
| 3 | Documentation | SQL comments in `create_functions.sql` show wrong threshold values ("0, 100, 300, 600" but actual formula gives "0, 200, 600, 1200") | Low | TODO |
| 4 | UX | `XPBadge` widget and session summary use coin icon (`Icons.monetization_on`) for XP — technically correct (XP=coins 1:1) but semantically ambiguous | Low | Accepted |
```

**After:**
```markdown
| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Dead Code | `getLeaderboard()` in `UserRepository` and `SupabaseUserRepository` — old method replaced by RPC-based leaderboard methods, never called | Low | Fixed |
| 2 | Security | `award_xp_transaction` is SECURITY DEFINER but doesn't validate `p_user_id = auth.uid()` — client could award XP to any user | Medium | Fixed |
| 3 | Documentation | SQL comments in `create_functions.sql` show wrong threshold values ("0, 100, 300, 600" but actual formula gives "0, 200, 600, 1200") | Low | Fixed |
| 4 | UX | `XPBadge` widget and session summary use coin icon (`Icons.monetization_on`) for XP — technically correct (XP=coins 1:1) but semantically ambiguous | Low | Accepted |
```

- [ ] **Step 2: Update checklist result**

Replace the checklist result section (lines 13-20):

**Before:**
```markdown
### Checklist Result
- Architecture Compliance: PASS
- Code Quality: PASS (1 dead code method)
- Dead Code: 1 issue (#1)
- Database & Security: 1 issue (#2)
- Edge Cases & UX: PASS (1 accepted quirk)
- Performance: PASS
- Cross-System Integrity: PASS
```

**After:**
```markdown
### Checklist Result
- Architecture Compliance: PASS
- Code Quality: PASS
- Dead Code: PASS (fixed)
- Database & Security: PASS (fixed)
- Edge Cases & UX: PASS (1 accepted quirk)
- Performance: PASS
- Cross-System Integrity: PASS
```

- [ ] **Step 3: Update Known Issues section**

Replace the entire "Known Issues & Tech Debt" section (lines 215-223):

**Before:**
```markdown
## Known Issues & Tech Debt

1. **Security: No auth check in `award_xp_transaction`** — ...

2. **Dead code: `getLeaderboard()` method** — ...

3. **Misleading SQL comments** — ...

4. **Planned: Type-based XP refactor** — Design spec exists at `docs/superpowers/specs/2026-03-23-type-based-xp-design.md`. Inline activity XP per-type settings are deployed but not yet wired into the inline activity completion flow (currently all use a single `xpInlineActivity` value). Vocab per-type settings are fully wired.
```

**After:**
```markdown
## Known Issues & Tech Debt

None — all audit findings resolved. Type-based XP per inline activity type is fully wired via `getInlineActivityXP()` in `reader_provider.dart`.
```

- [ ] **Step 4: Commit**

```bash
git add docs/specs/09-xp-leveling.md
git commit -m "docs: update XP/Leveling spec — mark audit findings as fixed"
```
