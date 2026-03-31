# System Settings Audit Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 4 audit findings from System Settings feature review: daily review hard-coded bonuses, JSONB format inconsistency in admin writes, vestigial game category, and tripled default values.

**Architecture:** All fixes are isolated — no cross-dependencies between tasks. Migration aligns `complete_daily_review` with the existing `complete_vocabulary_session` pattern. Admin write path fix adds type coercion before Supabase update. Model refactor uses entity as single source of truth for defaults.

**Tech Stack:** Supabase SQL migrations, Flutter/Dart, Riverpod

---

### Task 1: Migration — `complete_daily_review` reads bonuses from `system_settings`

**Files:**
- Create: `supabase/migrations/20260328700001_daily_review_read_settings.sql`

- [ ] **Step 1: Write migration**

```sql
-- Fix: complete_daily_review reads session/perfect bonus from system_settings
-- instead of hard-coding v_session_bonus := 10 and v_perfect_bonus := 20.
-- Mirrors the pattern used in complete_vocabulary_session (20260328000002).

CREATE OR REPLACE FUNCTION complete_daily_review(
    p_user_id UUID,
    p_words_reviewed INTEGER,
    p_correct_count INTEGER,
    p_incorrect_count INTEGER
)
RETURNS TABLE(
    session_id UUID,
    total_xp INTEGER,
    is_new_session BOOLEAN,
    is_perfect BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_existing_session daily_review_sessions%ROWTYPE;
    v_base_xp INTEGER;
    v_session_bonus INTEGER;
    v_perfect_bonus INTEGER;
    v_total_xp INTEGER;
    v_is_perfect BOOLEAN;
    v_session_id UUID;
BEGIN
    -- Auth check: user can only complete own daily review
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- Read bonuses from system_settings (with fallback defaults)
    SELECT COALESCE(
      (SELECT (value #>> '{}')::INTEGER FROM system_settings WHERE key = 'xp_vocab_session_bonus'),
      10
    ) INTO v_session_bonus;

    SELECT COALESCE(
      (SELECT (value #>> '{}')::INTEGER FROM system_settings WHERE key = 'xp_vocab_perfect_bonus'),
      20
    ) INTO v_perfect_bonus;

    SELECT * INTO v_existing_session
    FROM daily_review_sessions
    WHERE user_id = p_user_id AND session_date = app_current_date();

    IF v_existing_session.id IS NOT NULL THEN
        RETURN QUERY SELECT
            v_existing_session.id,
            0::INTEGER,
            FALSE,
            v_existing_session.is_perfect;
        RETURN;
    END IF;

    v_base_xp := p_correct_count * 5;
    v_is_perfect := (p_correct_count = p_words_reviewed AND p_incorrect_count = 0 AND p_words_reviewed > 0);

    v_total_xp := v_base_xp + v_session_bonus;
    IF v_is_perfect THEN
        v_total_xp := v_total_xp + v_perfect_bonus;
    END IF;

    INSERT INTO daily_review_sessions (
        user_id, session_date, words_reviewed, correct_count,
        incorrect_count, xp_earned, is_perfect
    ) VALUES (
        p_user_id, app_current_date(), p_words_reviewed, p_correct_count,
        p_incorrect_count, v_total_xp, v_is_perfect
    ) RETURNING id INTO v_session_id;

    PERFORM award_xp_transaction(
        p_user_id, v_total_xp, 'daily_review',
        v_session_id, 'Daily vocabulary review completed'
    );

    PERFORM check_and_award_badges(p_user_id);

    RETURN QUERY SELECT v_session_id, v_total_xp, TRUE, v_is_perfect;
END;
$$;
```

- [ ] **Step 2: Dry-run migration**

Run: `supabase db push --dry-run`
Expected: Migration listed as pending, no errors.

- [ ] **Step 3: Push migration**

Run: `supabase db push`
Expected: Migration applied successfully.

---

### Task 2: Fix admin JSONB write path — send typed values

**Files:**
- Modify: `owlio_admin/lib/features/settings/screens/settings_screen.dart:83-122`

- [ ] **Step 1: Replace `_updateSetting` to accept `dynamic` instead of `String`**

Replace the `_updateSetting` method (lines 83–122) with a version that sends typed values:

```dart
  Future<void> _updateSetting(String key, dynamic value) async {
    if (_savingKeys.contains(key)) return;

    setState(() => _savingKeys.add(key));

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from(DbTables.systemSettings)
          .update({'value': value})
          .eq('key', key);

      if (mounted) {
        ref.invalidate(settingsProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$key güncellendi'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            width: 200,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingKeys.remove(key));
      }
    }
  }
```

- [ ] **Step 2: Update boolean Switch to send `bool`**

In `_buildInput` (line ~417–420), change the Switch onChanged to send a `bool`:

```dart
    // Boolean (switch)
    if (value == 'true' || value == 'false') {
      return Switch(
        value: value == 'true',
        onChanged: (v) => _updateSetting(key, v),
      );
    }
```

- [ ] **Step 3: Update number field to send `num`**

In `_buildInput` (line ~445–449), change `onFieldSubmitted` to parse and send a number:

```dart
          onFieldSubmitted: (v) {
            if (v.isNotEmpty && v != value) {
              final parsed = int.tryParse(v) ?? double.tryParse(v);
              _updateSetting(key, parsed ?? v);
            }
          },
```

- [ ] **Step 4: Run analyze**

Run: `dart analyze owlio_admin/lib/features/settings/screens/settings_screen.dart`
Expected: No errors.

---

### Task 3: Remove vestigial `game` category from admin router

**Files:**
- Modify: `owlio_admin/lib/core/router.dart:324`
- Modify: `owlio_admin/lib/features/settings/screens/settings_screen.dart:46-68`

- [ ] **Step 1: Remove `'game'` from router categories**

In `router.dart` line 324, change:

```dart
          categories: ['xp_reading', 'xp_vocab', 'progression', 'game', 'app'],
```

to:

```dart
          categories: ['xp_reading', 'xp_vocab', 'progression', 'app'],
```

- [ ] **Step 2: Remove `game` entries from categoryLabels, categoryIcons, categoryColors**

In `settings_screen.dart`, remove the `'game'` entries from all three maps:

From `categoryLabels` remove: `'game': 'Oyun Ayarları',`

From `categoryIcons` remove: `'game': Icons.games,`

From `categoryColors` remove: `'game': Color(0xFF3B82F6),`

- [ ] **Step 3: Run analyze**

Run: `dart analyze owlio_admin/lib/`
Expected: No new errors.

---

### Task 4: Consolidate tripled defaults — entity as single source of truth

**Files:**
- Modify: `lib/data/models/settings/system_settings_model.dart`

- [ ] **Step 1: Add static defaults reference and refactor `fromMap`**

Add a static const at the top of `SystemSettingsModel` class, and refactor `fromMap` to use entity defaults:

```dart
  /// Single source of truth for defaults — derived from entity
  static const _d = SystemSettings();

  /// Parse from key-value map
  factory SystemSettingsModel.fromMap(Map<String, dynamic> m) {
    return SystemSettingsModel(
      xpChapterComplete: _toInt(m['xp_chapter_complete'], _d.xpChapterComplete),
      xpBookComplete: _toInt(m['xp_book_complete'], _d.xpBookComplete),
      xpQuizPass: _toInt(m['xp_quiz_pass'], _d.xpQuizPass),
      xpInlineTrueFalse: _toInt(m['xp_inline_true_false'], _d.xpInlineTrueFalse),
      xpInlineWordTranslation: _toInt(m['xp_inline_word_translation'], _d.xpInlineWordTranslation),
      xpInlineFindWords: _toInt(m['xp_inline_find_words'], _d.xpInlineFindWords),
      xpInlineMatching: _toInt(m['xp_inline_matching'], _d.xpInlineMatching),
      xpVocabMultipleChoice: _toInt(m['xp_vocab_multiple_choice'], _d.xpVocabMultipleChoice),
      xpVocabMatching: _toInt(m['xp_vocab_matching'], _d.xpVocabMatching),
      xpVocabScrambledLetters: _toInt(m['xp_vocab_scrambled_letters'], _d.xpVocabScrambledLetters),
      xpVocabSpelling: _toInt(m['xp_vocab_spelling'], _d.xpVocabSpelling),
      xpVocabSentenceGap: _toInt(m['xp_vocab_sentence_gap'], _d.xpVocabSentenceGap),
      comboBonusXp: _toInt(m['combo_bonus_xp'], _d.comboBonusXp),
      xpVocabSessionBonus: _toInt(m['xp_vocab_session_bonus'], _d.xpVocabSessionBonus),
      xpVocabPerfectBonus: _toInt(m['xp_vocab_perfect_bonus'], _d.xpVocabPerfectBonus),
      notifStreakExtended: _toBool(m['notif_streak_extended'], _d.notifStreakExtended),
      notifStreakBroken: _toBool(m['notif_streak_broken'], _d.notifStreakBroken),
      notifStreakBrokenMin: _toInt(m['notif_streak_broken_min'], _d.notifStreakBrokenMin),
      notifMilestone: _toBool(m['notif_milestone'], _d.notifMilestone),
      notifLevelUp: _toBool(m['notif_level_up'], _d.notifLevelUp),
      notifLeagueChange: _toBool(m['notif_league_change'], _d.notifLeagueChange),
      notifFreezeSaved: _toBool(m['notif_freeze_saved'], _d.notifFreezeSaved),
      notifBadgeEarned: _toBool(m['notif_badge_earned'], _d.notifBadgeEarned),
      notifAssignment: _toBool(m['notif_assignment'], _d.notifAssignment),
      streakFreezePrice: _toInt(m['streak_freeze_price'], _d.streakFreezePrice),
      streakFreezeMax: _toInt(m['streak_freeze_max'], _d.streakFreezeMax),
      streakMilestones: _toIntMap(m['streak_milestones'], _d.streakMilestones),
      streakMilestoneRepeatInterval: _toInt(m['streak_milestone_repeat_interval'], _d.streakMilestoneRepeatInterval),
      streakMilestoneRepeatXp: _toInt(m['streak_milestone_repeat_xp'], _d.streakMilestoneRepeatXp),
      debugDateOffset: _toInt(m['debug_date_offset'], _d.debugDateOffset),
    );
  }

  /// Default model (fallback) — derives all values from entity defaults
  factory SystemSettingsModel.defaults() => SystemSettingsModel.fromMap({});
```

- [ ] **Step 2: Run analyze**

Run: `dart analyze lib/data/models/settings/system_settings_model.dart`
Expected: No errors.

---

### Task 5: Update spec and commit

**Files:**
- Modify: `docs/specs/23-system-settings.md`

- [ ] **Step 1: Update finding statuses in spec**

Update the audit findings table: change Finding 3 status from `TODO` to `Fixed`, Finding 4 from `Known` to `Fixed`, Finding 5 from `Known` to `Fixed`. Update the Known Issues section to reflect what was resolved.

- [ ] **Step 2: Run full analyze**

Run: `dart analyze lib/ && dart analyze owlio_admin/lib/`
Expected: No new errors.

- [ ] **Step 3: Commit all changes**

```bash
git add supabase/migrations/20260328700001_daily_review_read_settings.sql \
  owlio_admin/lib/features/settings/screens/settings_screen.dart \
  owlio_admin/lib/core/router.dart \
  lib/data/models/settings/system_settings_model.dart \
  docs/specs/23-system-settings.md \
  docs/superpowers/plans/2026-03-28-system-settings-audit-fixes.md \
  CLAUDE.md features.md
git commit -m "docs: System Settings audit & spec + fix 4 findings"
```
