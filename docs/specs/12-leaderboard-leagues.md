# Leaderboard / Leagues

> **SUPERSEDED:** The league system has been redesigned with cross-school matchmaking, virtual bots, and lazy join. See `docs/superpowers/specs/2026-03-31-league-matchmaking-redesign.md` for the current design. The Class and School tabs described below remain unchanged.

## Audit

### Findings

| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Database | `process_weekly_league_reset` regression: debug-time migration (`20260323000006`) overwrites tier-based algorithm with old school-wide algorithm — live DB may be running wrong version | Medium | Fixed |
| 2 | Security | All 8 read-only leaderboard RPCs are `SECURITY DEFINER` without `auth.uid()` check — any authenticated user can query any school's leaderboard with an arbitrary `school_id` | Medium | Fixed |
| 3 | Edge Case | Zone banner `totalCount` uses fetched entry count (max 50), not actual tier group size — zone thresholds miscalculated for tiers with >50 students | Medium | Fixed |
| 4 | Code Quality | Duplicate `LeaderboardScope` enum in `get_weekly_leaderboard_usecase.dart` (2 values) and `leaderboard_provider.dart` (3 values), requiring `as weekly` import alias | Low | Fixed |
| 5 | Code Quality | `_leagueZoneSize()` in `leaderboard_screen.dart` duplicates SQL threshold logic with no shared source of truth | Low | Fixed |
| 6 | Code Quality | `leagueTier` parameter in UseCase params is raw `String?` instead of `LeagueTier` enum | Low | Fixed |
| 7 | Dead Code | `notif_league_change` system setting exists in admin panel but has no consumer in app or Edge Functions | Low | TODO |
| 8 | Performance | Teacher leaderboard (`allStudentsLeaderboardProvider`) fetches N classes serially and sorts client-side; no `autoDispose` | Low | TODO |
| 9 | Database | Stale RLS policy "Users can read classmates league history" (class-based) is redundant after migration to school-based system | Low | Fixed |
| 10 | Edge Case | No retry button on leaderboard error state | Low | Fixed |

### Checklist Result

- Architecture Compliance: PASS
- Code Quality: PASS (3 issues fixed: #4, #5, #6)
- Dead Code: 1 low issue (#7 — placeholder for future push notifications)
- Database & Security: PASS (3 issues fixed: #1, #2, #9)
- Edge Cases & UX: PASS (2 issues fixed: #3, #10)
- Performance: 1 low issue (#8 — teacher leaderboard optimization)
- Cross-System Integrity: PASS

---

## Overview

The Leaderboard/Leagues system provides three ranking views for students (League, Class, School) and a leaderboard report for teachers. The **League** tab implements a Duolingo-style weekly tier competition where students within the same school and tier compete on weekly XP. Top performers promote to the next tier, bottom performers demote. **Class** and **School** tabs show all-time XP rankings within those scopes. A weekly cron job (external, via Edge Function) processes promotions/demotions every Monday 00:00 UTC.

## Data Model

### Tables

**`profiles`** (leaderboard-relevant columns only):

| Column | Type | Notes |
|--------|------|-------|
| `xp` | INTEGER | Total all-time XP; drives total leaderboard |
| `level` | INTEGER | Derived from XP |
| `league_tier` | VARCHAR(20) | Current tier: `bronze` / `silver` / `gold` / `platinum` / `diamond`; default `bronze` |
| `avatar_equipped_cache` | JSONB | Denormalized equipped avatar items for leaderboard display |

**`league_history`**:

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK |
| `user_id` | UUID | FK → profiles(id) ON DELETE CASCADE |
| `class_id` | UUID | FK → classes(id) ON DELETE SET NULL |
| `school_id` | UUID | FK → schools(id) ON DELETE SET NULL |
| `week_start` | DATE | Monday of the competed week |
| `league_tier` | VARCHAR(20) | The **new** tier after this reset (post-promotion/demotion) |
| `rank` | INTEGER | Rank within the competition group |
| `weekly_xp` | INTEGER | XP earned during that week |
| `result` | VARCHAR(20) | `promoted`, `demoted`, or `stayed` |
| `created_at` | TIMESTAMPTZ | |
| UNIQUE | `(user_id, week_start)` | One record per student per week |

**`xp_logs`** (read by weekly leaderboard RPCs):

| Column | Notes |
|--------|-------|
| `user_id` | |
| `amount` | XP earned per event |
| `created_at` | Filtered by `>= date_trunc('week', app_now())` for weekly aggregation |

### Key Relationships

- Weekly leaderboard = real-time aggregation of `xp_logs` (not materialized)
- Total leaderboard = direct read of `profiles.xp`
- `league_history` = snapshot written once per week by the reset function
- `previous_rank` in leaderboard RPCs = joined from `league_history` for last week

### Indexes

- `idx_xp_logs_created_user` — (created_at DESC, user_id) for weekly XP aggregation
- `idx_profiles_school_tier` — (school_id, league_tier) WHERE role = 'student'
- `idx_profiles_class_role` — (class_id, role) for class leaderboard
- `idx_league_history_school_tier_week` — (week_start, school_id, league_tier) for previous rank lookup
- `idx_league_history_user` — (user_id, week_start DESC) for user history

## Surfaces

### Admin

- **Notification toggle**: `notif_league_change` setting in notification gallery (placeholder — no consumer yet)
- No admin CRUD for leagues — tiers and thresholds are hard-coded in the SQL function

### Student

**Three leaderboard tabs**, toggled via scope buttons:

1. **League** (default): Weekly XP ranking within user's current tier and school
   - Podium section for top 3
   - Promotion zone (green highlight) for top N students
   - Demotion zone (red highlight) for bottom N students
   - Rank change indicator (vs. previous week)
   - Weekly date range banner with tier name
   - Shows `weeklyXp`

2. **Class**: All-time XP ranking within user's class
   - Shows `totalXp`

3. **School**: All-time XP ranking within user's school
   - Shows `totalXp`

**Shared behaviors**:
- Fetch limit: 50 entries per request
- If current user is outside top 50, their row appears at the bottom with a separator
- Tapping any entry opens a student profile popup (loads user, card stats, badges in parallel)
- Empty state shown when no entries
- Loading spinner during fetch
- Error message on failure (no retry button)

### Teacher

- **Leaderboard Report** screen: All students across teacher's classes, sorted by total XP descending
- Shows name, avatar, streak, books read, XP, level for each student
- Tapping a student navigates to teacher student profile
- Pull-to-refresh support
- Empty state and error state with retry button
- Uses `StudentSummary` objects (separate data path from student RPCs)

## Business Rules

1. **League tiers**: `bronze` → `silver` → `gold` → `platinum` → `diamond` (5 levels). All students start at bronze.

2. **Competition scope**: Students compete within the same **school + tier** group. A school's bronze students only compete against other bronze students in that school.

3. **Weekly reset cadence**: Every Monday 00:00 UTC, triggered by external cron (cron-job.org) → Edge Function → `process_weekly_league_reset()` RPC.

4. **Zone size formula** (per school+tier group):
   - < 10 students: 1 promoted, 1 demoted
   - 10–25 students: 2 promoted, 2 demoted
   - 26–50 students: 3 promoted, 3 demoted
   - \> 50 students: 5 promoted, 5 demoted

5. **Rank tiebreaker**: `ORDER BY weekly_xp DESC, total_xp DESC`. All-time XP breaks ties on equal weekly XP.

6. **Promotion ceiling**: Diamond students cannot promote further (already at max).

7. **Demotion floor**: Bronze students cannot demote further (already at min).

8. **Idempotency**: `process_weekly_league_reset()` checks `EXISTS(league_history WHERE week_start = last_week)` — if already processed, it's a no-op. Safe for cron retries.

9. **`league_history.league_tier` semantics**: Stores the **new** tier (post-promotion/demotion), not the tier the student competed in. A student promoted from bronze to silver has `league_tier = 'silver'` in their history row.

10. **Class change**: Moving a student to a different class within the same school has no effect on their league position (competition is school-scoped).

11. **Avatar denormalization**: `profiles.avatar_equipped_cache` (JSONB) is returned by all leaderboard RPCs to avoid per-row joins on avatar items.

## RPC Functions (9 total)

| RPC | Purpose | Key Params |
|-----|---------|------------|
| `get_class_leaderboard` | Total XP ranking within a class | `p_class_id`, `p_limit` |
| `get_school_leaderboard` | Total XP ranking within a school | `p_school_id`, `p_limit` |
| `get_user_class_position` | Current user's total rank in class | `p_user_id`, `p_class_id` |
| `get_user_school_position` | Current user's total rank in school | `p_user_id`, `p_school_id` |
| `get_weekly_class_leaderboard` | Weekly XP ranking within a class (+ tier filter) | `p_class_id`, `p_league_tier`, `p_limit` |
| `get_weekly_school_leaderboard` | Weekly XP ranking within a school (+ tier filter) | `p_school_id`, `p_league_tier`, `p_limit` |
| `get_user_weekly_class_position` | User's weekly rank in class | `p_user_id`, `p_class_id`, `p_league_tier` |
| `get_user_weekly_school_position` | User's weekly rank in school | `p_user_id`, `p_school_id`, `p_league_tier` |
| `process_weekly_league_reset` | Weekly promotion/demotion processing | (no params — processes all schools) |

All read RPCs return: `user_id`, `first_name`, `last_name`, `avatar_url`, `avatar_equipped_cache`, `xp`/`total_xp`, `weekly_xp`, `level`, `league_tier`, `class_name`, `rank`, `previous_rank`.

## Cross-System Interactions

### XP → Leaderboard
- Every XP award goes through `award_xp_transaction()` → inserts into `xp_logs` + updates `profiles.xp`
- Weekly leaderboard aggregates `xp_logs.amount WHERE created_at >= date_trunc('week', ...)` — real-time, not cached
- Total leaderboard reads `profiles.xp` directly
- **Chain**: any XP event → `xp_logs` INSERT → reflected in next leaderboard query

### Avatar → Leaderboard
- `profiles.avatar_equipped_cache` is denormalized JSONB updated by the avatar system
- All 8 leaderboard RPCs return this field — no per-row avatar item lookups needed

### Streak → Leaderboard (indirect)
- Streak milestone XP bonuses are awarded via `award_xp_transaction` → automatically contributes to weekly XP
- No direct streak-leaderboard interaction

### Badge → Leaderboard
- No badge conditions based on league tier currently exist
- Student profile popup (triggered by tapping a leaderboard entry) loads `user_badges` — requires the `user_badges` school-based RLS policy from migration `20260217000002`

### Class Change → League
- `update_student_class` changes `profiles.class_id` but does not affect `league_tier` or `league_history`
- League competition is school-scoped, so class changes within the same school have no impact

## Edge Cases

- **New student (0 XP)**: Appears at the bottom of their tier group. All new students start in bronze.
- **Single student in tier**: Zone size = 1. They are simultaneously in the promotion and demotion zone. Promotion takes priority (`rank <= promote_count` is checked first).
- **Diamond student**: Cannot promote. Even if ranked #1, `result = 'stayed'`.
- **Bronze student**: Cannot demote. Even if ranked last, `result = 'stayed'`.
- **No XP earned during week**: Student gets `weekly_xp = 0`. If multiple students have 0 weekly XP, `total_xp` is the tiebreaker.
- **Student without a class**: Class leaderboard returns empty. School and league leaderboards still work (school_id-based).
- **Student outside top 50**: Current user's position is fetched separately via `get_user_*_position` RPCs and appended below the list.
- **Cron fires twice**: Idempotent — second call is a no-op due to `league_history` existence check.
- **Edge Function without CRON_SECRET**: Auth check is bypassed (`if (expectedSecret && ...)`) — any caller can trigger reset, but idempotency prevents damage.

## Test Scenarios

- [ ] **Happy path (League)**: Student with XP sees weekly leaderboard filtered by their tier; podium shows top 3; weekly XP displayed
- [ ] **Happy path (Class)**: Student sees total XP leaderboard for their class
- [ ] **Happy path (School)**: Student sees total XP leaderboard for their school
- [ ] **Tab switching**: Toggling between League/Class/School correctly loads different data
- [ ] **Promotion zone**: Student ranked in top N sees green highlight and promotion banner
- [ ] **Demotion zone**: Student ranked in bottom N sees red highlight and danger banner
- [ ] **Outside top 50**: Student ranked >50 sees their row at the bottom with separator
- [ ] **Rank change indicator**: Shows up/down arrows based on `previousRank` from last week
- [ ] **Student profile popup**: Tapping any entry loads profile with user info, card stats, and badges
- [ ] **Empty state**: Student with no classmates/schoolmates sees "No students yet" message
- [ ] **Error state**: Network failure shows "Could not load leaderboard"
- [ ] **Weekly reset**: After Monday cron, `league_history` has new rows; promoted students see new tier
- [ ] **Idempotent reset**: Calling reset twice in the same week creates no duplicate rows
- [ ] **Teacher report**: Teacher sees all students across classes sorted by total XP
- [ ] **Teacher pull-to-refresh**: Invalidates all class student providers and reloads

## Key Files

### Domain
- `lib/domain/entities/leaderboard_entry.dart` — Entity
- `lib/domain/repositories/user_repository.dart:36-85` — Repository interface (8 leaderboard methods)
- `lib/domain/usecases/user/get_weekly_leaderboard_usecase.dart` — Weekly (league) leaderboard
- `lib/domain/usecases/user/get_total_leaderboard_usecase.dart` — Total (class/school) leaderboard

### Data
- `lib/data/models/user/leaderboard_entry_model.dart` — JSON → Entity mapping
- `lib/data/repositories/supabase/supabase_user_repository.dart:304-533` — Supabase RPC calls

### Presentation
- `lib/presentation/providers/leaderboard_provider.dart` — Providers (entries, position, display state)
- `lib/presentation/screens/leaderboard/leaderboard_screen.dart` — Main screen (3 tabs, podium, zones)
- `lib/presentation/screens/teacher/reports/leaderboard_report_screen.dart` — Teacher report

### Shared Package
- `packages/owlio_shared/lib/src/enums/league_tier.dart` — `LeagueTier` enum
- `packages/owlio_shared/lib/src/constants/rpc_functions.dart:34-45` — 9 RPC constants
- `packages/owlio_shared/lib/src/constants/league_constants.dart` — `leagueZoneSize()` shared function

### Database
- `supabase/migrations/20260217000001_create_league_system.sql` — Initial tables + RPCs
- `supabase/migrations/20260218000003_league_tier_based_competition.sql` — Tier-based redesign
- `supabase/migrations/20260316000010_optimize_league_reset.sql` — Temp table optimization
- `supabase/migrations/20260323000006_debug_time_offset.sql` — `app_now()` wrapper (regression fixed by below)
- `supabase/migrations/20260326000003_update_leaderboard_rpcs_avatar.sql` — Avatar cache in RPCs
- `supabase/migrations/20260328000009_fix_leaderboard_audit.sql` — Audit fixes: tier-based reset, auth checks, total_count, stale RLS drop
- `supabase/functions/league-reset/index.ts` — Edge Function (cron entry point)

## Known Issues & Tech Debt

1. **[Low] `notif_league_change` placeholder**: System setting exists but has no consumer. Will be addressed when push notification infrastructure is built.

2. **[Low] Teacher leaderboard inefficiency**: `allStudentsLeaderboardProvider` fetches N classes serially; no `autoDispose`. Acceptable for current scale but should be revisited for schools with many classes.
