# Streak Milestone XP Configurable — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make milestone XP values admin-configurable via `system_settings` and add repeating milestones for 100+ day streaks.

**Architecture:** New `system_settings` keys store milestone config as JSONB. SQL function reads config at runtime instead of hard-coded CASE. Flutter entity/model updated for completeness.

**Tech Stack:** PostgreSQL (Supabase), Dart/Flutter

---

### Task 1: SQL migration — seed settings + refactor function

**Files:**
- Create: `supabase/migrations/20260328000007_streak_milestone_configurable.sql`

- [ ] **Step 1: Create the migration file**

```sql
-- Make streak milestone XP admin-configurable (audit findings #7, #8)
-- 1. Seed milestone settings in system_settings
-- 2. Refactor update_user_streak to read milestones from settings
-- 3. Add repeating milestone for 100+ day streaks

-- Seed new settings
INSERT INTO system_settings (key, value, category, description) VALUES
  ('streak_milestones', '{"7":50,"14":100,"30":200,"60":400,"100":1000}', 'progression', 'Streak milestone day→XP mapping (JSON object)'),
  ('streak_milestone_repeat_interval', '"100"', 'progression', 'Repeat milestone every N days after last defined milestone (0 to disable)'),
  ('streak_milestone_repeat_xp', '"1000"', 'progression', 'XP awarded for each repeating milestone')
ON CONFLICT (key) DO NOTHING;

-- Redefine update_user_streak with configurable milestones
DROP FUNCTION IF EXISTS update_user_streak(UUID);
CREATE OR REPLACE FUNCTION update_user_streak(p_user_id UUID)
RETURNS TABLE(
    new_streak INTEGER,
    longest_streak INTEGER,
    streak_broken BOOLEAN,
    streak_extended BOOLEAN,
    freeze_used BOOLEAN,
    freezes_consumed INTEGER,
    freezes_remaining INTEGER,
    milestone_bonus_xp INTEGER,
    previous_streak INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_last_activity DATE;
    v_current_streak INTEGER;
    v_longest_streak INTEGER;
    v_freeze_count INTEGER;
    v_today DATE := app_current_date();
    v_new_streak INTEGER;
    v_streak_broken BOOLEAN := FALSE;
    v_streak_extended BOOLEAN := FALSE;
    v_freeze_used BOOLEAN := FALSE;
    v_freezes_consumed INTEGER := 0;
    v_days_missed INTEGER;
    v_milestone_xp INTEGER := 0;
    v_milestones JSONB;
    v_repeat_interval INTEGER;
    v_repeat_xp INTEGER;
    i INTEGER;
BEGIN
    -- Auth check: prevent updating another user's streak
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    SELECT p.last_activity_date, p.current_streak, p.longest_streak, p.streak_freeze_count
    INTO v_last_activity, v_current_streak, v_longest_streak, v_freeze_count
    FROM profiles p
    WHERE p.id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: %', p_user_id;
    END IF;

    INSERT INTO daily_logins (user_id, login_date, is_freeze)
    VALUES (p_user_id, v_today, false)
    ON CONFLICT (user_id, login_date) DO UPDATE SET is_freeze = false;

    IF v_last_activity IS NULL THEN
        v_new_streak := 1;
        v_streak_extended := TRUE;
    ELSIF v_last_activity = v_today THEN
        v_new_streak := v_current_streak;
    ELSIF v_last_activity = v_today - 1 THEN
        v_new_streak := v_current_streak + 1;
        v_streak_extended := TRUE;
    ELSE
        v_days_missed := (v_today - v_last_activity) - 1;

        IF v_days_missed <= v_freeze_count THEN
            v_freeze_count := v_freeze_count - v_days_missed;
            v_new_streak := v_current_streak + 1;
            v_streak_extended := TRUE;
            v_freeze_used := TRUE;
            v_freezes_consumed := v_days_missed;

            FOR i IN 1..v_days_missed LOOP
                INSERT INTO daily_logins (user_id, login_date, is_freeze)
                VALUES (p_user_id, v_last_activity + i, true)
                ON CONFLICT (user_id, login_date) DO NOTHING;
            END LOOP;

        ELSIF v_freeze_count > 0 THEN
            v_freezes_consumed := v_freeze_count;
            v_freeze_count := 0;
            v_new_streak := 1;
            v_streak_broken := TRUE;
            v_freeze_used := TRUE;

            FOR i IN 1..v_freezes_consumed LOOP
                INSERT INTO daily_logins (user_id, login_date, is_freeze)
                VALUES (p_user_id, v_last_activity + i, true)
                ON CONFLICT (user_id, login_date) DO NOTHING;
            END LOOP;

        ELSE
            v_new_streak := 1;
            v_streak_broken := TRUE;
        END IF;
    END IF;

    IF v_new_streak > v_longest_streak THEN
        v_longest_streak := v_new_streak;
    END IF;

    IF v_streak_extended THEN
        -- Load milestone config from system_settings
        SELECT value INTO v_milestones FROM system_settings WHERE key = 'streak_milestones';
        SELECT COALESCE((SELECT (value#>>'{}')::INT FROM system_settings WHERE key = 'streak_milestone_repeat_interval'), 100) INTO v_repeat_interval;
        SELECT COALESCE((SELECT (value#>>'{}')::INT FROM system_settings WHERE key = 'streak_milestone_repeat_xp'), 1000) INTO v_repeat_xp;

        -- Check defined milestones
        IF v_milestones IS NOT NULL THEN
            v_milestone_xp := COALESCE((v_milestones->>v_new_streak::TEXT)::INT, 0);
        END IF;

        -- Check repeating milestone (beyond defined milestones)
        IF v_milestone_xp = 0 AND v_repeat_interval > 0 AND v_new_streak > 100 AND v_new_streak % v_repeat_interval = 0 THEN
            v_milestone_xp := v_repeat_xp;
        END IF;

        IF v_milestone_xp > 0 THEN
            PERFORM award_xp_transaction(
                p_user_id, v_milestone_xp, 'streak_milestone',
                'day_' || v_new_streak, 'Streak milestone: ' || v_new_streak || ' days'
            );
        END IF;
    END IF;

    UPDATE profiles
    SET current_streak = v_new_streak,
        longest_streak = v_longest_streak,
        last_activity_date = v_today,
        streak_freeze_count = v_freeze_count,
        updated_at = NOW()
    WHERE id = p_user_id;

    RETURN QUERY SELECT v_new_streak, v_longest_streak, v_streak_broken, v_streak_extended,
                        v_freeze_used, v_freezes_consumed, v_freeze_count, v_milestone_xp,
                        v_current_streak;
END;
$$;
```

- [ ] **Step 2: Dry-run the migration**

Run: `supabase db push --dry-run`
Expected: Migration listed as pending, no errors.

- [ ] **Step 3: Push the migration**

Run: `supabase db push`
Expected: Migration applied successfully.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260328000007_streak_milestone_configurable.sql
git commit -m "feat: make streak milestone XP admin-configurable + repeating milestones (#10 audit fix 7,8)"
```

---

### Task 2: Update Flutter SystemSettings entity and model

**Files:**
- Modify: `lib/domain/entities/system_settings.dart` — add 3 milestone fields
- Modify: `lib/data/models/settings/system_settings_model.dart` — add parsing + mapping

- [ ] **Step 1: Add fields to `SystemSettings` entity**

In `lib/domain/entities/system_settings.dart`, add 3 fields to the constructor and class body.

After the existing streak fields (after `this.streakFreezeMax = 2,`), add:

```dart
    // Streak Milestones
    this.streakMilestones = const {7: 50, 14: 100, 30: 200, 60: 400, 100: 1000},
    this.streakMilestoneRepeatInterval = 100,
    this.streakMilestoneRepeatXp = 1000,
```

After the existing final fields (after `final int streakFreezeMax;`), add:

```dart
  // Streak Milestones
  final Map<int, int> streakMilestones;
  final int streakMilestoneRepeatInterval;
  final int streakMilestoneRepeatXp;
```

Add the 3 fields to the `props` list (before `debugDateOffset`):

```dart
        streakMilestones,
        streakMilestoneRepeatInterval,
        streakMilestoneRepeatXp,
```

- [ ] **Step 2: Add parsing to `SystemSettingsModel`**

In `lib/data/models/settings/system_settings_model.dart`:

**Constructor:** Add 3 required fields after `streakFreezeMax`:

```dart
    required this.streakMilestones,
    required this.streakMilestoneRepeatInterval,
    required this.streakMilestoneRepeatXp,
```

**Class fields:** Add after `final int streakFreezeMax;`:

```dart
  final Map<int, int> streakMilestones;
  final int streakMilestoneRepeatInterval;
  final int streakMilestoneRepeatXp;
```

**`fromMap` factory:** Add after `streakFreezeMax` line:

```dart
      streakMilestones: _toIntMap(m['streak_milestones'], {7: 50, 14: 100, 30: 200, 60: 400, 100: 1000}),
      streakMilestoneRepeatInterval: _toInt(m['streak_milestone_repeat_interval'], 100),
      streakMilestoneRepeatXp: _toInt(m['streak_milestone_repeat_xp'], 1000),
```

**`defaults` factory:** Add after `streakFreezeMax: 2,`:

```dart
        streakMilestones: const {7: 50, 14: 100, 30: 200, 60: 400, 100: 1000},
        streakMilestoneRepeatInterval: 100,
        streakMilestoneRepeatXp: 1000,
```

**`toEntity` method:** Add after `streakFreezeMax: streakFreezeMax,`:

```dart
        streakMilestones: streakMilestones,
        streakMilestoneRepeatInterval: streakMilestoneRepeatInterval,
        streakMilestoneRepeatXp: streakMilestoneRepeatXp,
```

**`fromEntity` factory:** Add after `streakFreezeMax: e.streakFreezeMax,`:

```dart
        streakMilestones: e.streakMilestones,
        streakMilestoneRepeatInterval: e.streakMilestoneRepeatInterval,
        streakMilestoneRepeatXp: e.streakMilestoneRepeatXp,
```

**New helper method:** Add after `_toBool`:

```dart
  static Map<int, int> _toIntMap(dynamic v, Map<int, int> defaultValue) {
    if (v == null) return defaultValue;
    if (v is Map) {
      return v.map((k, v) => MapEntry(
        int.tryParse(k.toString()) ?? 0,
        _toInt(v, 0),
      ));
    }
    return defaultValue;
  }
```

**Update `_parseJsonbValue`:** The existing `_parseJsonbValue` strips quotes and tries int/double/string. For the `streak_milestones` key, the value is a JSONB object `{"7":50,...}` which will arrive as a Dart `Map` from Supabase. The current `_parseJsonbValue` checks `if (v is! String) return v;` first, so it will return the Map as-is. This is correct — no change needed.

- [ ] **Step 3: Run analysis**

Run: `dart analyze lib/`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/domain/entities/system_settings.dart lib/data/models/settings/system_settings_model.dart
git commit -m "feat: add streak milestone settings to SystemSettings entity/model (#10 audit fix 7,8)"
```

---

### Task 3: Update spec audit statuses + business rules

**Files:**
- Modify: `docs/specs/10-streak-system.md`

- [ ] **Step 1: Update audit findings #7 and #8**

In `docs/specs/10-streak-system.md`, update:
- Finding #7: change `| Low | - |` to `| Low | Fixed |`
- Finding #8: change `| Low | - |` to `| Low | Fixed |`

- [ ] **Step 2: Update Business Rule #5**

Replace rule 5:
```
5. **Milestone XP** — awarded at specific streak days: 7→50, 14→100, 30→200, 60→400, 100→1000 XP. These values are hard-coded in SQL, NOT admin-configurable.
```
with:
```
5. **Milestone XP** — awarded at specific streak days, configurable via `system_settings` key `streak_milestones` (default: 7→50, 14→100, 30→200, 60→400, 100→1000 XP). Beyond defined milestones, repeating milestones award XP every `streak_milestone_repeat_interval` days (default: every 100 days, 1000 XP).
```

- [ ] **Step 3: Update rule #12**

Replace rule 12:
```
12. **No streak for streaks >100 days** — after day 100, no further milestone XP is awarded.
```
with:
```
12. **Repeating milestones** — after the last defined milestone (default day 100), XP is awarded every `streak_milestone_repeat_interval` days (default 100). Day 200, 300, etc. each award `streak_milestone_repeat_xp` (default 1000 XP). Set interval to 0 to disable.
```

- [ ] **Step 4: Update Known Issues section**

Remove item 7 ("Hard-coded milestone XP") from the Known Issues list since it's now fixed.

- [ ] **Step 5: Commit**

```bash
git add docs/specs/10-streak-system.md
git commit -m "docs: update streak spec — milestone XP now configurable (#10 audit fix 7,8)"
```
