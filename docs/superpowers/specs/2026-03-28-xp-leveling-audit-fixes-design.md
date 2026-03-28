# XP/Leveling Audit Fixes — Design Spec

**Date**: 2026-03-28
**Scope**: Fix 3 audit findings from Feature #9 spec + update spec audit table

---

## Context

The Feature #9 (XP/Leveling) audit at `docs/specs/09-xp-leveling.md` identified 4 findings. Finding #4 (type-based XP wiring) was already implemented — `getInlineActivityXP()` in `reader_provider.dart` already reads per-type settings. The remaining 3 findings need fixes.

## Fixes

### Fix 1: Remove dead `getLeaderboard()` method

**Problem**: `getLeaderboard()` in `UserRepository` interface and `SupabaseUserRepository` is never called. It was replaced by RPC-based methods (`getTotalClassLeaderboard`, `getWeeklyClassLeaderboard`, etc.).

**Changes**:
- `lib/domain/repositories/user_repository.dart` — remove `getLeaderboard()` method signature (lines 31-35)
- `lib/data/repositories/supabase/supabase_user_repository.dart` — remove `getLeaderboard()` implementation (lines 211-242)

**Verification**: `dart analyze lib/` must pass with no errors.

### Fix 2: Add auth check to `award_xp_transaction`

**Problem**: The RPC is `SECURITY DEFINER` (bypasses RLS) but doesn't validate that `p_user_id = auth.uid()`. A client could theoretically call `rpc('award_xp_transaction', {p_user_id: 'other_user', p_amount: 99999})`.

**Solution**: Add `IF p_user_id != auth.uid() THEN RAISE EXCEPTION 'Not authorized: user mismatch'` as the first statement after variable declarations. Same pattern as `complete_vocabulary_session` (migration `20260328000002`).

**Migration**: `supabase/migrations/20260328000004_add_auth_check_to_award_xp.sql`

Full `CREATE OR REPLACE FUNCTION` redefinition copying the latest version from `20260316000006_coin_idempotency_and_xp_constraint.sql` with the auth guard added.

**Note**: The function is also called internally by other RPCs (e.g., `complete_vocabulary_session` calls `PERFORM award_xp_transaction(...)`). Since those RPCs are themselves `SECURITY DEFINER`, they execute as the function owner — `auth.uid()` inside a SECURITY DEFINER context returns the calling user's auth ID (set at session level by PostgREST), so internal calls that pass the correct `p_user_id` will still work. The auth check only blocks direct client calls with mismatched user IDs.

### Fix 3: Fix misleading SQL comments in `calculate_level`

**Problem**: Comments in `create_functions.sql` say thresholds are "0, 100, 300, 600, 1000, 1500..." and formula is "threshold(n) = n * (n + 1) * 50". The actual formula `FLOOR((-1 + SQRT(1 + p_xp / 25.0)) / 2) + 1` produces thresholds "0, 200, 600, 1200, 2000..." matching client-side `LevelHelper.xpForLevel(level) = (level-1) * level * 100`.

**Migration**: `supabase/migrations/20260328000005_fix_calculate_level_comments.sql`

`CREATE OR REPLACE FUNCTION` with identical body but corrected comment block.

### Fix 4: Update spec audit table

Update `docs/specs/09-xp-leveling.md`:
- Finding #1 (dead code): Status → "Fixed"
- Finding #2 (security): Status → "Fixed"
- Finding #3 (SQL comments): Status → "Fixed"
- Finding #4 (type-based XP): Update description to note it was already implemented, Status → "Already Done"
- Known Issues section: Remove items #1-#3 (fixed), update #4 to reflect current state

## Out of Scope

- No changes to client-side XP logic
- No changes to admin panel
- No new features — these are pure cleanup/security/documentation fixes

## Risk Assessment

- **Fix 1**: Zero risk — dead code removal, no callers
- **Fix 2**: Low risk — auth guard is additive, internal RPC calls unaffected (SECURITY DEFINER context preserves auth.uid())
- **Fix 3**: Zero risk — comment-only change, function body identical
- **Fix 4**: Zero risk — documentation update only
