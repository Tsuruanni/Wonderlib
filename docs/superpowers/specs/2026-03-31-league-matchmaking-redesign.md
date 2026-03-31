# League Matchmaking Redesign

## Summary

Replace the current school+tier-based league system with a Duolingo-style cross-school matchmaking system. Students who earn enough XP during the week are lazily assigned to ~30-person competition groups based on their tier and recent activity level. Virtual bots fill empty slots so every group always displays 30 rivals. Same-school rivals get priority placement in groups, and the existing Class/School total-XP tabs remain unchanged.

## Motivation

The current system has several structural problems:

1. **Passive user inflation** — Students who never log in still occupy Bronze tier slots, inflating group sizes and diluting competition
2. **Uncontrolled group sizes** — A school with 200 Bronze students creates a 200-person league; zone_size of 5 means only 5% promote/demote
3. **No matchmaking** — A student earning 500 XP/week competes against students earning 20 XP/week just because they're in the same school+tier
4. **Misleading rank change after promotion** — Previous rank comes from a different tier group, showing wrong deltas

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Competition scope | Cross-school, ~30-person groups | Duolingo-proven model, solves group size problem |
| Group formation | Lazy join (first 20+ XP in a week) | Eliminates passive users from groups |
| Matchmaking signal | Last week's weekly XP (bucket-based) | Most direct indicator of current activity |
| New user handling | Onboarding bucket (bucket 0) | Protects new/returning students from mismatched competition |
| Tier count | 5 tiers (unchanged) | Working well, no reason to change |
| Same-school awareness | Best-effort grouping + UI badge + school tab | Maintains school identity without limiting matchmaking |
| Class/School tabs | Unchanged (total XP) | Zero-risk, proven functionality |
| Week boundaries | UTC-Monday (via `app_now()`) | Consistent with existing system. Students near UTC midnight may see local date mismatch — known limitation. |
| Inactive tier decay | Soft-demotion after 4 weeks of inactivity | Prevents stale Diamond badges on long-inactive students |
| Empty slot filling | Virtual bots (not stored in member tables) | Groups always display 30 rivals. Bots shrink automatically as real players join. Zero cross-system contamination. |
| Bot visibility | Fully disguised — indistinguishable from real students | Maximum immersion. Profile popup disabled for bots (tap does nothing). |
| Bot zone participation | Bots count toward 30-person zone calculation | Zone always based on 30. Only real players are actually promoted/demoted. Bots can occupy zone slots, cushioning real players in small groups. |

## Data Model

### New Tables

**`league_groups`** — Weekly ~30-person competition groups.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK, default gen_random_uuid() |
| `week_start` | DATE | Monday of the competition week |
| `tier` | VARCHAR(20) | bronze/silver/gold/platinum/diamond |
| `xp_bucket` | INTEGER | Matchmaking bucket (0-4) |
| `member_count` | INTEGER | Real (human) member count only. Updated atomically on join. Default 0. |
| `processed` | BOOLEAN | Default false. Set to true by weekly reset after this group is processed. |
| `created_at` | TIMESTAMPTZ | default now() |

Indexes:
- `idx_league_groups_week_tier_bucket` on (week_start, tier, xp_bucket) — matchmaking lookup
- `idx_league_groups_unprocessed` on (week_start) WHERE processed = false — reset processing

**`league_group_members`** — Real students lazily assigned to groups. **Bots are NOT stored here.**

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK, default gen_random_uuid() |
| `group_id` | UUID | FK → league_groups(id) ON DELETE CASCADE |
| `user_id` | UUID | FK → profiles(id) ON DELETE CASCADE |
| `week_start` | DATE | Denormalized from league_groups — avoids JOIN on hot path |
| `school_id` | UUID | Denormalized for same-school badge display |
| `joined_at` | TIMESTAMPTZ | default now() |
| UNIQUE | `(user_id, week_start)` | One group per student per week |

Indexes:
- `idx_league_group_members_user_week` on (user_id, week_start) — fast "am I in a group this week?" check on every XP award (hot path)
- `idx_league_group_members_group` on (group_id) — leaderboard queries
- `idx_league_group_members_group_user` on (group_id, user_id) — auth check in `get_league_group_leaderboard` (is caller a member?)

**`bot_profiles`** — Pre-generated bot identities. Static seed data (~200 rows).

| Column | Type | Notes |
|--------|------|-------|
| `id` | SERIAL | PK, sequential for deterministic slot mapping |
| `first_name` | VARCHAR | Realistic name |
| `last_name` | VARCHAR | Realistic name |
| `avatar_equipped_cache` | JSONB | Pre-configured avatar (animal + accessories) |
| `school_name` | VARCHAR | Fake school name for display |

Seeded once during migration. No RLS needed (read-only via SECURITY DEFINER RPCs).

### Modified Tables

**`league_history`** — Add group reference:

```sql
ALTER TABLE league_history ADD COLUMN group_id UUID REFERENCES league_groups(id) ON DELETE SET NULL;
```

Existing rows will have `group_id = NULL` (pre-redesign data). The existing `UNIQUE (user_id, week_start)` constraint is preserved — each student can only be in one group per week (enforced by `league_group_members` UNIQUE constraint), so one history row per week is still correct.

**Note:** The `result` column (VARCHAR(20)) currently accepts `promoted`, `demoted`, `stayed`. This redesign adds `inactive_demoted` as a new value. The migration must verify no CHECK constraint exists on this column; if one exists, it must be updated to include `inactive_demoted`.

**First-week behavior:** After migration, all rank change indicators will show dash (—) because old `league_history` rows have `group_id = NULL`, which triggers the cross-group suppression rule. This is expected and correct — it cleanly resets rank tracking for the new system.

### RLS Policies (New Tables)

Both `league_groups` and `league_group_members` use RLS enabled with no direct-access policies. All reads/writes go through `SECURITY DEFINER` RPCs:

```sql
ALTER TABLE league_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE league_group_members ENABLE ROW LEVEL SECURITY;
-- No SELECT/INSERT/UPDATE/DELETE policies — access only via SECURITY DEFINER RPCs
```

`bot_profiles` does not need RLS — it is only read from within SECURITY DEFINER functions.

### Unchanged Tables

- `profiles` — `league_tier`, `xp`, `avatar_equipped_cache` columns unchanged
- `xp_logs` — unchanged, still the source for weekly XP aggregation

## Virtual Bot System

### Core Concept

Bots are **virtual** — they are NOT stored in `league_group_members`, `profiles`, or `xp_logs`. They exist only as computed entries returned by leaderboard RPCs and factored into weekly reset rankings. This means:

- Zero cross-system contamination (Class/School tabs, teacher reports, badges, daily quests — none see bots)
- Bot count automatically adjusts: 30 - real_member_count = bot count
- No cleanup needed — bots have no persistent state
- As the product grows and groups fill organically, bots naturally disappear

### Bot Identity Selection (Deterministic)

Each group has up to `30 - member_count` bot slots (numbered 0, 1, 2, ...). Each slot maps to a `bot_profiles` row deterministically:

```sql
bot_profile_id = (abs(hashtext(group_id::text || '_slot_' || slot_number::text)) % total_bot_profiles) + 1
```

Note: `abs()` is required because `hashtext()` returns signed integers — without it, negative modulo in PostgreSQL produces negative IDs that don't match any `bot_profiles` row.

This ensures:
- Same group always shows same bot identities (no flicker on refresh)
- Different groups will typically show different bot combinations (not guaranteed with ~200 profiles — some overlap is possible and acceptable)
- Bot names/avatars are consistent for the entire week

### Bot XP Calculation (Deterministic, On-the-fly)

Bot XP is never stored. It is computed at query time using a deterministic formula:

**Weekly target XP** (set per-bot for the whole week):

```sql
CREATE OR REPLACE FUNCTION bot_weekly_xp_target(
    p_group_id UUID,
    p_slot INTEGER,
    p_xp_bucket INTEGER
) RETURNS INTEGER AS $$
DECLARE
    v_seed INTEGER := abs(hashtext(p_group_id::text || '_' || p_slot::text));
    v_min INTEGER;
    v_max INTEGER;
BEGIN
    -- Bucket XP ranges (what real players in this bucket typically earn)
    CASE p_xp_bucket
        WHEN 0 THEN v_min := 20;  v_max := 80;   -- onboarding
        WHEN 1 THEN v_min := 30;  v_max := 99;   -- low
        WHEN 2 THEN v_min := 100; v_max := 299;  -- medium
        WHEN 3 THEN v_min := 300; v_max := 599;  -- high
        WHEN 4 THEN v_min := 600; v_max := 1000; -- very high
        ELSE         v_min := 20;  v_max := 80;
    END CASE;

    RETURN v_min + (v_seed % (v_max - v_min + 1));
END;
$$ LANGUAGE plpgsql IMMUTABLE;
```

**Current XP at query time** (progressive throughout the week):

```sql
CREATE OR REPLACE FUNCTION bot_current_xp(
    p_group_id UUID,
    p_slot INTEGER,
    p_xp_bucket INTEGER,
    p_week_start DATE
) RETURNS INTEGER AS $$
DECLARE
    v_target INTEGER := bot_weekly_xp_target(p_group_id, p_slot, p_xp_bucket);
    v_elapsed FLOAT := EXTRACT(EPOCH FROM (app_now() - p_week_start::timestamptz)) / (7.0 * 86400);
    v_day_seed INTEGER := abs(hashtext(p_group_id::text || '_' || p_slot::text || '_' || EXTRACT(DOW FROM app_now())::text));
    v_jitter FLOAT := (v_day_seed % 20 - 10) / 100.0;  -- ±10% daily jitter
BEGIN
    v_elapsed := GREATEST(0, LEAST(1, v_elapsed));  -- clamp 0-1
    RETURN LEAST(v_target, GREATEST(0, (v_target * (v_elapsed + v_jitter))::INTEGER));  -- clamp to [0, target]
END;
$$ LANGUAGE plpgsql STABLE;
```

This means:
- Monday morning: bots have low XP
- Mid-week: bots have ~50% of their target
- Sunday night: bots approach their full target
- Daily jitter prevents linear growth (some bots "play more" on certain days)
- Deterministic: same query at same time = same results (no flicker)

### Bot Integration in Leaderboard RPC

`get_league_group_leaderboard()` merges real players + virtual bots:

Note: `get_league_group_leaderboard` is a **PL/pgSQL** function (not pure SQL). The `DECLARE` block defines:
- `v_group RECORD` — fetched with `SELECT * INTO v_group FROM league_groups WHERE id = p_group_id FOR SHARE` (FOR SHARE prevents concurrent member_count changes during this read)
- `v_total_bots INTEGER := (SELECT count(*) FROM bot_profiles)`
- Early exit: `IF v_total_bots = 0 THEN` skip bot generation entirely (guards against division-by-zero if bot_profiles is empty)

All subsequent references use `v_group.member_count`, `v_group.xp_bucket`, `v_group.week_start` — local PL/pgSQL variables, not re-read from the table. This ensures consistency within a single function call even under concurrent joins.

```sql
-- Inside PL/pgSQL function body, after DECLARE, group fetch, and v_total_bots check:
v_bot_count := GREATEST(0, 30 - v_group.member_count);

RETURN QUERY
WITH real_entries AS (
    SELECT p.id AS user_id, p.first_name, p.last_name, ...,
           COALESCE(wxc.week_xp, 0) AS weekly_xp, p.xp AS total_xp,
           FALSE AS is_bot, lgm.school_id, s.name AS school_name
    FROM league_group_members lgm
    JOIN profiles p ON lgm.user_id = p.id
    LEFT JOIN schools s ON p.school_id = s.id
    LEFT JOIN weekly_xp_calc wxc ON p.id = wxc.uid
    WHERE lgm.group_id = p_group_id
),
bot_entries AS (
    SELECT
        ('00000000-0000-0000-0000-' || LPAD(bp.id::text, 12, '0'))::UUID AS user_id,
        bp.first_name, bp.last_name, NULL AS avatar_url,
        bp.avatar_equipped_cache,
        bot_current_xp(p_group_id, slot_num, v_group.xp_bucket, v_group.week_start) AS weekly_xp,
        0 AS total_xp,
        (bot_weekly_xp_target(p_group_id, slot_num, v_group.xp_bucket) / 50 + 1) AS level,
        TRUE AS is_bot,
        NULL::UUID AS school_id,
        bp.school_name
    FROM generate_series(0, v_bot_count - 1) AS slot_num
    JOIN bot_profiles bp ON bp.id = (abs(hashtext(p_group_id::text || '_slot_' || slot_num::text)) % v_total_bots) + 1
    WHERE v_bot_count > 0
),
all_entries AS (
    SELECT * FROM real_entries
    UNION ALL
    SELECT * FROM bot_entries
),
ranked AS (
    SELECT *, RANK() OVER (ORDER BY weekly_xp DESC, total_xp DESC) AS rank
    FROM all_entries
)
SELECT ... FROM ranked ORDER BY rank LIMIT p_limit;
```

Key SQL notes:
- `v_group` is fetched once with `FOR SHARE` lock — no double-read inconsistency
- `v_bot_count` is computed from `v_group.member_count` (local variable, not re-read)
- `generate_series(0, v_bot_count - 1)` produces exactly `v_bot_count` slots (0 when no bots needed)
- `WHERE v_bot_count > 0` guard prevents empty bot generation
- `IF v_total_bots = 0` early exit prevents division-by-zero on empty `bot_profiles`
- `abs(hashtext(...))` prevents negative modulo results

The `is_bot` flag is returned to the client to disable profile popup taps.

### Bot Integration in Weekly Reset

`process_weekly_league_reset()` uses the same merge pattern:

```
For each unprocessed league_group:
  1. Merge real members + virtual bots (using bot_weekly_xp_target for end-of-week XP)
  2. Rank all 30 entries by weekly_xp DESC, total_xp DESC
  3. Zone size = 5 (always, since display is always 30)
  4. For each REAL player in top 5 → promote (unless Diamond)
  5. For each REAL player in bottom 5 → demote (unless Bronze)
  6. Bots in zones → skip (no action, no league_history row)
  7. Insert league_history rows for real players only
  8. Update profiles.league_tier for real players where changed
  9. Mark group as processed
```

Bots in promotion/demotion zones effectively "cushion" real players — in a group with 5 real players and 25 bots, most zone slots are occupied by bots, meaning fewer real players get demoted. This is intentional: early-stage protection that naturally fades as more real players join.

## Matchmaking Algorithm

### XP Bucket Calculation

Based on **last week's** weekly XP (calculated using `app_now()` for consistency with time offset wrapper):

| Last Week XP | Bucket | Label |
|--------------|--------|-------|
| 0 (new/returning/inactive) | 0 | onboarding |
| 1–99 | 1 | low |
| 100–299 | 2 | medium |
| 300–599 | 3 | high |
| 600+ | 4 | very high |

### Lazy Join Trigger

Triggered inside `award_xp_transaction()` after XP is awarded:

```
1. Check if user already has a league_group_members row for this week
   (uses denormalized week_start column — no JOIN needed, index on (user_id, week_start))
2. If not in a group:
   a. Calculate cumulative weekly XP for current week
   b. If weekly_xp >= 20 → Call join_weekly_league(user_id)
```

### Group Assignment Priority (Concurrency-Safe)

`join_weekly_league(p_user_id)`:

```
1. Idempotency: already in a group this week? → return
2. Determine user's tier (from profiles.league_tier)
3. Calculate XP bucket from last week's xp_logs (using app_now() for time window)
4. Search for an open group (member_count < 30), in priority order:
   a. Same tier + same bucket + has >=1 member from same school
   b. Same tier + same bucket
   c. Same tier + neighbor bucket (±1) + has >=1 member from same school
   d. Same tier + neighbor bucket (±1)
   e. Same tier + ANY bucket (final fallback for sparse tiers like Diamond)
   f. None found → create new group with member_count = 0

   For steps a-e: SELECT ... FOR UPDATE SKIP LOCKED on the candidate league_groups row
   to prevent concurrent joins from overfilling a group.

5. Atomically: INSERT into league_group_members + UPDATE league_groups SET member_count = member_count + 1
   Both within the same transaction. The FOR UPDATE lock ensures no two concurrent calls
   can push the same group beyond 30.
```

**Concurrency safety:** `FOR UPDATE SKIP LOCKED` means if two students try to join the same group simultaneously, one acquires the lock and the other skips that row and finds the next available group. This prevents groups exceeding 30 members without blocking.

### Edge Cases

- **Group reaches 30 real members:** `member_count` check prevents new joins. Next student gets the next available group or a new one is created. Bot count = 0 for this group.
- **Mid-week join:** Student's XP since Monday is already in xp_logs; rank calculated correctly from the moment they join. A bot slot disappears from the display.
- **Student never reaches 20 XP:** Not assigned to any group. No demotion. Tier preserved (but see Inactive Tier Decay below).
- **New student (no last-week data):** Bucket 0 (onboarding). Matched with other new/returning students.
- **Very few active Diamond students:** Fallback step (e) ensures they join ANY open Diamond group regardless of bucket, rather than being stuck alone. Remaining slots filled by bots.
- **Concurrent joins:** `FOR UPDATE SKIP LOCKED` ensures atomicity. No group can exceed 30 real members.
- **Single real player in group:** 1 real + 29 bots. Full leaderboard experience from the start. Player sees 30 rivals immediately.

### Inactive Tier Decay

Students who do not join a league group for **4 consecutive weeks** are soft-demoted by one tier during the weekly reset. This prevents stale Diamond/Platinum badges on long-inactive students.

```
process_weekly_league_reset() additionally:
  For each student WHERE league_tier != 'bronze':
    If no league_group_members row exists for the last 4 weeks:
      → Demote by 1 tier
      → Insert league_history row with result = 'inactive_demoted'
```

Bronze students cannot be demoted further. A returning student re-enters via onboarding bucket (bucket 0) at their current (possibly decayed) tier.

## Zone Size (Promotion/Demotion)

With virtual bots, every group always displays 30 entries. Zone size is therefore always **5 promote / 5 demote**.

The `leagueZoneSize()` function is still used for the rare edge case where a group has 0 bots and <30 real members (if 30 real members join but some leave/get deleted mid-week). The table is kept for safety:

| Group Display Size | Promote | Demote | Safe Zone |
|--------------------|---------|--------|-----------|
| 1–4 | 0 | 0 | All |
| 5–9 | 1 | 1 | 3–7 |
| 10–14 | 2 | 2 | 6–10 |
| 15–24 | 3 | 3 | 9–18 |
| 25–30 | 5 | 5 | 15–20 |

In practice, with bots, the display size is always 30 → zone size always 5.

Shared function `leagueZoneSize(groupSize)` in `owlio_shared` updated to match this table. SQL function uses identical thresholds. **Both must be deployed together** — see Migration Strategy.

**Zone interaction with bots:**
- Zones are calculated on the full 30-person ranking (real + bots)
- Bots can occupy zone slots — this cushions real players in groups with few real members
- Only real players are actually promoted/demoted during weekly reset
- UI shows zone coloring for all entries (real and bot alike)

## RPC Functions

### New RPCs

**`join_weekly_league(p_user_id UUID)`**
- Called from `award_xp_transaction()` when threshold met
- Implements matchmaking algorithm above (with `FOR UPDATE SKIP LOCKED`)
- Returns void (fire-and-forget)
- SECURITY DEFINER, no auth check needed (called from another SECURITY DEFINER function)
- All time calculations use `app_now()` for consistency with debug time offset

**`get_league_group_leaderboard(p_group_id UUID, p_limit INTEGER DEFAULT 30)`**
- Returns group members ranked by weekly XP (tiebreaker: total XP)
- **Merges real players + virtual bots** to always return 30 entries
- Auth check: caller must be a member of this group (checked via `league_group_members` using the `idx_league_group_members_group_user` composite index on `(group_id, user_id)`)
- Returns: `user_id, first_name, last_name, avatar_url, avatar_equipped_cache, total_xp, weekly_xp, level, rank, previous_rank, league_tier, school_name, is_same_school, is_bot, group_member_count`
- `is_same_school`: true if member's school_id matches caller's school_id. Always false for bots.
- `is_bot`: true for virtual bot entries. Used by client to disable profile popup tap.
- `previous_rank`: from `league_history` for the user's last week entry. NULL for bots and for real players with no history. **The UI suppresses rank change indicators when `previous_rank` comes from a different `group_id`** (see UI section).
- `group_member_count`: always 30 (display count = real + bots)

**`get_user_league_status(p_user_id UUID)`**
- Returns user's current week league status
- Auth check: caller must be the user themselves (`auth.uid() = p_user_id`)
- Returns: `group_id, group_member_count, tier, week_start, weekly_xp, rank, joined, threshold_met, current_weekly_xp`
- `joined`: whether user is in a group this week
- `threshold_met`: whether user has >=20 weekly XP (for progress bar UI)
- `group_member_count`: always returns the constant `30` (display count = real + bots). This is NOT the `league_groups.member_count` column (which tracks real members only) — the RPC explicitly returns `30` as the display count.
- `rank`: computed using the **same bot-merge ranking** as `get_league_group_leaderboard` — real players + virtual bots ranked together, then the user's position is extracted. This ensures the rank shown in status matches the rank in the leaderboard. Internally, both RPCs share the same ranking CTE pattern.
- If not in a group: `joined = false`, `rank = NULL`, includes `current_weekly_xp` for progress display

### Helper Functions (Internal)

**`bot_weekly_xp_target(p_group_id UUID, p_slot INTEGER, p_xp_bucket INTEGER) → INTEGER`**
- IMMUTABLE — deterministic weekly target XP for a bot slot
- Uses seeded hash for consistent randomness within bucket range

**`bot_current_xp(p_group_id UUID, p_slot INTEGER, p_xp_bucket INTEGER, p_week_start DATE) → INTEGER`**
- STABLE — current XP based on time elapsed in the week
- Progressive: low on Monday, target by Sunday
- Daily jitter for realistic variation

### Modified RPCs

**`award_xp_transaction(...)`** — Add lazy join check at end of function:

```sql
-- After XP award logic...
-- Check if user should join weekly league (hot path — uses denormalized week_start)
IF NOT EXISTS (
    SELECT 1 FROM league_group_members
    WHERE user_id = v_user_id
    AND week_start = date_trunc('week', app_now())::DATE
) THEN
    SELECT COALESCE(SUM(amount), 0) INTO v_weekly_xp
    FROM xp_logs
    WHERE user_id = v_user_id
    AND created_at >= date_trunc('week', app_now());

    IF v_weekly_xp >= 20 THEN
        PERFORM join_weekly_league(v_user_id);
    END IF;
END IF;
```

Note: The `league_group_members` check uses the denormalized `week_start` column with the `idx_league_group_members_user_week` index — no JOIN to `league_groups` needed. This is critical for performance since `award_xp_transaction` is the most frequently called RPC.

**`process_weekly_league_reset()`** — Rewritten for group-based processing with bot integration:

```
1. For each league_group WHERE week_start = last Monday AND processed = false:
   a. Lock the group row (FOR UPDATE)
   b. Fetch real members + generate virtual bots (using bot_weekly_xp_target for end-of-week XP)
   c. Rank all 30 entries by weekly_xp DESC, total_xp DESC
   d. Zone size = leagueZoneSize(30) = 5
   e. For each REAL player in top 5 → promote (unless Diamond)
   f. For each REAL player in bottom 5 → demote (unless Bronze)
   g. Bots in zones → skip (no action)
   h. Insert league_history rows for real players only (with group_id)
   i. Update profiles.league_tier for real players where changed
   j. SET processed = true
2. Inactive tier decay:
   For each student WHERE league_tier != 'bronze'
   AND no league_group_members row in last 4 weeks:
   → Demote by 1 tier, insert league_history with result = 'inactive_demoted'
3. Cleanup: DELETE league_groups WHERE week_start < (app_now() - INTERVAL '8 weeks')
   (league_history.group_id becomes NULL via ON DELETE SET NULL — acceptable, history rows retain all other data)
```

**Idempotency:** Per-group via the `processed` flag. If the reset crashes after processing 40 of 200 groups, the retry picks up the remaining 160 unprocessed groups. No duplicate history rows. Safe for cron retries.

### Removed RPCs

| RPC | Replacement |
|-----|-------------|
| `get_weekly_school_leaderboard` | `get_league_group_leaderboard` |
| `get_weekly_class_leaderboard` | Removed (class tab uses total XP) |
| `get_user_weekly_school_position` | `get_user_league_status` |
| `get_user_weekly_class_position` | Removed |

**Deprecation note:** Since there are no active users currently, old RPCs can be dropped immediately. If mobile clients were in production, a compatibility window would be needed — keep old RPCs returning empty results during transition. Currently not applicable.

### Unchanged RPCs

- `get_class_leaderboard` — total XP, class scope
- `get_school_leaderboard` — total XP, school scope
- `get_user_class_position` — user's total rank in class
- `get_user_school_position` — user's total rank in school

## UI States (League Tab)

### State 1: Not Joined (weekly XP < 20)

Shows a motivational card with progress bar toward the 20 XP threshold. "Earn 20 XP to join this week's league!" with current XP progress (e.g., "7/20 XP").

### State 2: Joined (always 30 entries thanks to bots)

Full leaderboard experience from the moment of joining:
- Weekly indicator: tier name + date range + "30 rivals"
- Zone preview banner (promotion/demotion) — always based on 30-person group
- Top 3 podium (may include bots)
- Ranked list with zone coloring (bots and real players colored identically)
- Rank change indicators — **only shown for real players when `previous_rank` comes from the same `group_id` as current group.** NULL/cross-group → show dash. Bots never show rank change (always dash).
- Same-school badge (school icon) next to real rivals from user's school. Never shown for bots (`is_same_school` = false for bots).
- Bot entries: **tap disabled.** `GestureDetector` only wraps entries where `is_bot == false`. No visual difference — bots look identical to real players, they just don't respond to taps.
- If user outside top 30 (impossible with 30 limit, but kept for safety): separator + user row at bottom
- Pull-to-refresh on all tabs (invalidates relevant providers)
- **Provider refresh on tab selection:** `leagueStatusProvider` and `leagueGroupEntriesProvider` should be invalidated when the League tab is selected (e.g., via scope toggle callback). This ensures that if a student earns XP on another screen and returns to the League tab, the status is fresh. This is the same pattern the current `leaderboardScopeProvider` uses — changing scope triggers `autoDispose` rebuild.

**Note:** The old "Waiting for rivals..." state (State 2 in previous version) is eliminated. Virtual bots ensure every group always has 30 entries from the moment of joining.

### Class/School Tabs

Unchanged. Total XP ranking within class/school. **Bots never appear in these tabs** — they only exist in the league group leaderboard RPC.

### Notification: League Tier Change

The existing `notif_league_change` system setting remains a placeholder. When the user opens the app after a weekly reset that changed their tier, the tier change is detected by comparing the cached `leagueTier` in `currentUserProvider` with the fresh value from the server. A notification dialog is shown:
- Promoted: celebration dialog with new tier badge
- Demoted: encouragement dialog with tips
- Inactive demoted: "Welcome back! Your tier has been adjusted" dialog

This is a client-side detection, not a push notification. Push notification integration is deferred to the push notification infrastructure project.

## Presentation Layer Changes

### New Providers

```dart
// User's league status this week (joined?, group_id, progress)
final leagueStatusProvider = FutureProvider.autoDispose<LeagueStatus>(...);

// Group leaderboard entries (only when joined — always 30 entries with bots)
final leagueGroupEntriesProvider = FutureProvider.autoDispose<List<LeaderboardEntry>>(...);
```

### Modified Providers

```dart
// leaderboardEntriesProvider — league scope branch updated:
//   Old: getWeeklyLeaderboardUseCase (school+tier)
//   New: leagueGroupEntriesProvider (group-based, includes bots)

// leaderboardDisplayProvider — league scope uses leagueStatusProvider
//   to determine which UI state to show (not joined / joined with full leaderboard)
//   LeaderboardDisplayState.leagueTotalCount removed (always 30)
```

### Removed Providers

Weekly school/class position providers for league scope (replaced by leagueStatusProvider).

### Full Dart File Change List

Files that must be created, modified, or deleted:

**Shared Package (`packages/owlio_shared`):**
- `lib/src/constants/rpc_functions.dart` — remove 4 old constants (`getWeeklyClassLeaderboard`, `getWeeklySchoolLeaderboard`, `getUserWeeklyClassPosition`, `getUserWeeklySchoolPosition`), add 3 new
- `lib/src/constants/league_constants.dart` — update `leagueZoneSize()` to new table

**Domain Layer:**
- `lib/domain/entities/leaderboard_entry.dart` — add `schoolName`, `isSameSchool`, `isBot`, `groupId` fields + update `props` list for Equatable
- `lib/domain/entities/league_status.dart` — NEW file, `LeagueStatus` entity
- `lib/domain/repositories/user_repository.dart` — remove 4 weekly methods (`getWeeklyClassLeaderboard`, `getWeeklySchoolLeaderboard`, `getUserWeeklyClassPosition`, `getUserWeeklySchoolPosition`), add 2 new (`getLeagueGroupLeaderboard`, `getUserLeagueStatus`)
- `lib/domain/usecases/user/get_weekly_leaderboard_usecase.dart` — DELETE (replaced by group-based provider)
- `lib/domain/usecases/user/get_user_weekly_position_usecase.dart` — DELETE (replaced by league status provider)
- `lib/domain/usecases/user/get_league_group_leaderboard_usecase.dart` — NEW
- `lib/domain/usecases/user/get_user_league_status_usecase.dart` — NEW

**Data Layer:**
- `lib/data/models/user/leaderboard_entry_model.dart` — add `schoolName`, `isSameSchool`, `isBot`, `groupId` to `fromJson` + `toEntity`
- `lib/data/models/user/league_status_model.dart` — NEW file
- `lib/data/repositories/supabase/supabase_user_repository.dart` — remove 4 weekly methods (lines 409-533), add 2 new methods for group leaderboard and league status

**Presentation Layer:**
- `lib/presentation/providers/usecase_providers.dart` — remove old weekly usecase providers, add new ones
- `lib/presentation/providers/leaderboard_provider.dart` — add `leagueStatusProvider`, `leagueGroupEntriesProvider`; update league scope in `leaderboardEntriesProvider` and `leaderboardDisplayProvider`
- `lib/presentation/screens/leaderboard/leaderboard_screen.dart` — add State 1 (not joined) UI, update league tab to use group data, add `isBot` tap guard, add same-school badge, add pull-to-refresh

### New Entity

```dart
class LeagueStatus {
  final bool joined;
  final bool thresholdMet;
  final int currentWeeklyXp;
  final String? groupId;
  final int? groupMemberCount; // always 30 when joined
  final LeagueTier tier;
  final DateTime weekStart;
  final int? rank;
}
```

### LeaderboardEntry Updates

Add fields to entity and model:
- `schoolName` (String?) — for cross-school display. For real players: joined from `schools.name` via `profiles.school_id`. For bots: from `bot_profiles.school_name`.
- `isSameSchool` (bool) — for school badge rendering. Always false for bots.
- `isBot` (bool) — for disabling profile popup tap
- `previousGroupId` (String?) — from `league_history.group_id` of previous week entry. Used by UI to suppress rank change indicators when comparing across different groups.

### Shared Package Updates

```dart
// league_constants.dart — updated zone size table
int leagueZoneSize(int groupSize) {
  if (groupSize < 5) return 0;
  if (groupSize < 10) return 1;
  if (groupSize < 15) return 2;
  if (groupSize < 25) return 3;
  return 5;
}

// rpc_functions.dart — remove old weekly RPCs, add new ones
// Remove: getWeeklyClassLeaderboard, getWeeklySchoolLeaderboard,
//         getUserWeeklyClassPosition, getUserWeeklySchoolPosition
// Add:
static const joinWeeklyLeague = 'join_weekly_league';
static const getLeagueGroupLeaderboard = 'get_league_group_leaderboard';
static const getUserLeagueStatus = 'get_user_league_status';
```

## Edge Function

`league-reset/index.ts` — No changes needed. It calls `process_weekly_league_reset()` which will be rewritten server-side. The edge function itself remains the same entry point.

## Migration Strategy

Single migration file, executed in order:

1. Create `bot_profiles` table and seed with ~200 bot identities (names, avatars, school names)
2. Create helper functions: `bot_weekly_xp_target()`, `bot_current_xp()`
3. Create `league_groups` table (with `member_count` and `processed` columns) and indexes
4. Create `league_group_members` table (with denormalized `week_start`) and indexes
5. Enable RLS on `league_groups` and `league_group_members` (no direct-access policies)
6. Add `group_id` column to `league_history`; verify no CHECK constraint on `result` column (if exists, update to include `inactive_demoted`)
7. Create `join_weekly_league()` RPC (with `FOR UPDATE SKIP LOCKED`)
8. Create `get_league_group_leaderboard()` RPC (with bot merge logic)
9. Create `get_user_league_status()` RPC
10. Rewrite `process_weekly_league_reset()` for group-based logic (with `processed` flag idempotency + bot integration for ranking)
11. Modify `award_xp_transaction()` to add lazy join trigger (using denormalized `week_start` check)
12. Drop old weekly RPCs: `get_weekly_school_leaderboard`, `get_weekly_class_leaderboard`, `get_user_weekly_school_position`, `get_user_weekly_class_position`
13. Drop stale indexes related to old school+tier league queries

**Coordinated deployment:** The Dart shared package (`league_constants.dart`, `rpc_functions.dart`) and the SQL migration must be deployed together. The Flutter app update must go live at the same time as (or after) the database migration.

**Spec 12 update:** After migration, `docs/specs/12-leaderboard-leagues.md` must be updated to reflect the new design (new RPCs, new data model, matchmaking, bots). The old spec will be stale and directly contradictory. Update it as part of the implementation.

**`award_xp_transaction` integration note:** The spec shows a snippet to append. The implementer must verify the exact variable name used for the user's ID in the existing function body (it may be `v_user_id`, `p_user_id`, or another name). Grep the existing function definition before writing the lazy join check.

**Bot seed data:** The ~200 bot profiles should include a diverse mix of realistic first/last names and pre-configured avatar combinations. School names should be plausible but not match any real school in the system. The `avatar_equipped_cache` JSONB must match the format produced by `EquippedAvatarModel.toJson()` — reference `lib/data/models/avatar/equipped_avatar_model.dart` for the exact structure.

## Cross-System Interactions

### XP → League
- `award_xp_transaction()` → lazy join check (denormalized, no JOIN) → `join_weekly_league()` (NEW)
- All XP sources (books, quiz, vocabulary, activities, streak) flow through this — no per-source changes needed

### Avatar → League
- `avatar_equipped_cache` returned by `get_league_group_leaderboard()` — same pattern as before
- Bots use pre-configured avatars from `bot_profiles.avatar_equipped_cache`

### Weekly Reset → League
- Cron → Edge Function → `process_weekly_league_reset()` — same trigger, new logic
- Per-group `processed` flag ensures crash-safe partial processing
- Bot entries factored into ranking but only real players promoted/demoted

### Class Change → League
- No impact. Groups are cross-school; class/school identity is denormalized in `league_group_members.school_id`

### Notification → League
- Tier change detection is client-side (compare cached vs fresh `leagueTier`)
- `notif_league_change` system setting controls whether the dialog is shown
- Push notification deferred to separate infrastructure project

### Badges → League
- No badge conditions currently depend on league tier. If added in the future, they would read `profiles.league_tier` which is kept up to date by the reset function.

### Bots → Other Systems
- Bots do NOT appear in: Class tab, School tab, teacher reports, badge system, daily quests, assignment system, card collection, or any other feature
- Bots exist ONLY within `get_league_group_leaderboard()` and `process_weekly_league_reset()` ranking calculations
- Bot user_ids use a synthetic UUID format (`00000000-0000-0000-0000-XXXXXXXXXXXX`) that will never collide with real Supabase auth UUIDs

## Group Lifecycle

```
Monday 00:00 UTC (Week N):
  ← process_weekly_league_reset() runs for Week N-1 groups
  ← Merges real + bot entries, ranks all 30, promotes/demotes real players only
  ← Inactive tier decay for 4+ week absent students
  ← Cleanup: deletes groups older than 8 weeks

Week N begins:
  No groups exist yet for this week.

Student earns XP during Week N:
  → award_xp_transaction() fires
  → Cumulative weekly XP >= 20?
    → join_weekly_league() creates or joins a Week N group
  → Student sees a full 30-person leaderboard immediately (real members + bots)
  → As more real students join throughout the week, bots are replaced automatically
    (member_count increases → fewer bot slots generated)

Monday 00:00 UTC (Week N+1):
  ← process_weekly_league_reset() runs for Week N groups
  ← Cycle repeats
```

## Test Scenarios

### Core Flow
- [ ] Student with <20 weekly XP sees "Join" progress card on League tab
- [ ] Student reaching 20 XP threshold gets auto-assigned to a group
- [ ] Immediately after joining, student sees full 30-person leaderboard (real + bots)
- [ ] Matchmaking prefers same-school groups when available
- [ ] Matchmaking falls back to neighbor bucket when exact bucket has no open group
- [ ] Matchmaking falls back to any same-tier group when bucket neighbors are also full (Diamond edge case)

### Bot Behavior
- [ ] Bot identities are consistent across refreshes (deterministic selection)
- [ ] Bot XP increases progressively throughout the week (low Monday, high Sunday)
- [ ] Bot count decreases as real players join (30 - real_count = bot_count)
- [ ] Group with 30 real members shows 0 bots
- [ ] Bot entries are not tappable (no profile popup)
- [ ] Bots do NOT appear in Class tab or School tab
- [ ] Bot user_ids use synthetic UUID format (never collide with real users)

### Zones & Promotion
- [ ] Zone coloring applies to all 30 entries (real and bot alike)
- [ ] Zone size always 5 (based on 30-person display)
- [ ] Weekly reset promotes only real players in top 5
- [ ] Weekly reset demotes only real players in bottom 5
- [ ] Bots in promotion/demotion zones are skipped (no action)
- [ ] Diamond students cannot promote; Bronze students cannot demote
- [ ] In small groups (few real players), bots cushion demotion zone

### Rank & History
- [ ] Rank change indicator suppressed when previous_rank is from a different group
- [ ] Bots always show dash for rank change (no previous_rank)
- [ ] league_history rows only created for real players (never for bots)

### System Integrity
- [ ] Reset idempotency: per-group processed flag prevents double processing
- [ ] Reset crash recovery: unprocessed groups are picked up on retry
- [ ] Inactive tier decay: 4+ weeks absent non-Bronze student gets demoted by 1 tier
- [ ] Concurrent joins: FOR UPDATE SKIP LOCKED prevents groups exceeding 30 real members
- [ ] Class tab unchanged: total XP ranking within class
- [ ] School tab unchanged: total XP ranking within school
- [ ] New student (first week) placed in onboarding bucket
- [ ] Returning student (inactive last week) placed in onboarding bucket
- [ ] Tab switching between League/Class/School works correctly
- [ ] Student profile popup works for real players from all tabs
- [ ] Pull-to-refresh support on all tabs
- [ ] Tier change notification dialog shown after weekly reset (promote/demote/inactive_demote)
- [ ] Group cleanup: groups older than 8 weeks are deleted, league_history.group_id becomes NULL
