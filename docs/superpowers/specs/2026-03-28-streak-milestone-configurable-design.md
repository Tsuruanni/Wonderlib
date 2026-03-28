# Streak Milestone XP — Admin-Configurable

**Date:** 2026-03-28
**Scope:** Make milestone XP values admin-configurable + add repeating milestone for 100+ days
**Fixes:** Audit findings #7 and #8 from `docs/specs/10-streak-system.md`

---

## Problem

1. Milestone XP values (7d=50, 14d=100, 30d=200, 60d=400, 100d=1000) are hard-coded in SQL `CASE` statement. Every other XP value in the system is admin-configurable via `system_settings`.
2. No milestone exists for streaks beyond 100 days — long-streak users get no further reward.

## Solution

### New `system_settings` Keys

| Key | Value (JSONB) | Category | Purpose |
|-----|---------------|----------|---------|
| `streak_milestones` | `{"7":50,"14":100,"30":200,"60":400,"100":1000}` | `progression` | Day→XP mapping for one-time milestones |
| `streak_milestone_repeat_interval` | `100` | `progression` | Every N days after last defined milestone, repeat |
| `streak_milestone_repeat_xp` | `1000` | `progression` | XP for each repeating milestone |

### SQL Function Change

Replace the hard-coded `CASE` in `update_user_streak` with:

```sql
-- Load milestone config
SELECT value INTO v_milestones FROM system_settings WHERE key = 'streak_milestones';
SELECT COALESCE((SELECT (value#>>'{}')::INT FROM system_settings WHERE key = 'streak_milestone_repeat_interval'), 100) INTO v_repeat_interval;
SELECT COALESCE((SELECT (value#>>'{}')::INT FROM system_settings WHERE key = 'streak_milestone_repeat_xp'), 1000) INTO v_repeat_xp;

-- Check defined milestones first
v_milestone_xp := COALESCE((v_milestones->>v_new_streak::TEXT)::INT, 0);

-- Check repeating milestone (100+ days)
IF v_milestone_xp = 0 AND v_repeat_interval > 0 AND v_new_streak > 100 AND v_new_streak % v_repeat_interval = 0 THEN
    v_milestone_xp := v_repeat_xp;
END IF;
```

### Flutter Side

Add three fields to `SystemSettings` entity and `SystemSettingsModel`:
- `streakMilestones: Map<int, int>` — parsed from JSON object
- `streakMilestoneRepeatInterval: int` (default 100)
- `streakMilestoneRepeatXp: int` (default 1000)

The Flutter app doesn't use these values at runtime (milestone XP comes from the RPC result), but the admin panel's settings editor can display/edit them.

---

## Files Changed

| File | Change |
|------|--------|
| `supabase/migrations/20260328000007_streak_milestone_configurable.sql` | NEW — settings seed + function redefinition |
| `lib/domain/entities/system_settings.dart` | Add 3 milestone fields |
| `lib/data/models/settings/system_settings_model.dart` | Parse milestone JSON + 2 scalar fields |
| `docs/specs/10-streak-system.md` | Update #7, #8 statuses to Fixed |

---

## Edge Cases

- **Missing `streak_milestones` key:** Function uses `COALESCE` → 0 XP (safe fallback)
- **Empty JSON object `{}`:** No milestones awarded (admin disabled all)
- **`streak_milestone_repeat_interval = 0`:** Repeat disabled (checked with `v_repeat_interval > 0`)
- **Day 200, 300, 400...:** Each awards `v_repeat_xp` (1000 XP by default)
