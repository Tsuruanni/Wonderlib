# XP/Leveling

## Audit

### Findings
| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Dead Code | `getLeaderboard()` in `UserRepository` and `SupabaseUserRepository` — old method replaced by RPC-based leaderboard methods, never called | Low | Fixed |
| 2 | Security | `award_xp_transaction` is SECURITY DEFINER but doesn't validate `p_user_id = auth.uid()` — client could award XP to any user | Medium | Fixed |
| 3 | Documentation | SQL comments in `create_functions.sql` show wrong threshold values ("0, 100, 300, 600" but actual formula gives "0, 200, 600, 1200") | Low | Fixed |
| 4 | UX | `XPBadge` widget and session summary use coin icon (`Icons.monetization_on`) for XP — technically correct (XP=coins 1:1) but semantically ambiguous | Low | Accepted |

### Checklist Result
- Architecture Compliance: PASS
- Code Quality: PASS
- Dead Code: PASS (fixed)
- Database & Security: PASS (fixed)
- Edge Cases & UX: PASS (1 accepted quirk)
- Performance: PASS
- Cross-System Integrity: PASS

---

## Overview

The XP/Leveling system is the core progression mechanic. Students earn XP from activities (reading, vocabulary, quizzes, inline activities) which determines their level. **Every XP award also grants equal coins** (1:1 ratio) via a single atomic transaction. XP values are admin-configurable through system_settings. The system feeds into leaderboards, badges, and level-up celebrations.

## Data Model

### Tables

**profiles** (XP/level columns)
- `xp` INTEGER — total lifetime XP (non-negative constraint)
- `level` INTEGER — current level (calculated from XP, capped at 100)
- `coins` INTEGER — spendable currency (awarded 1:1 with XP)

**xp_logs** — audit trail of all XP awards
- `user_id` UUID → profiles
- `amount` INTEGER
- `source` VARCHAR(50) — reading, activity, vocabulary, streak, badge, manual
- `source_id` UUID (nullable) — links to the triggering record
- `description` TEXT
- `created_at` TIMESTAMPTZ
- Partial unique index: `(user_id, source, source_id) WHERE source_id IS NOT NULL` — idempotency guard

**system_settings** — admin-configurable XP values
- `key` VARCHAR, `value` JSONB, `category`, `description`, `sort_order`

### Key Relationships
- `xp_logs.user_id → profiles.id` (CASCADE delete)
- XP values come from `system_settings` (loaded once, cached in `systemSettingsProvider`)
- Level is derived from XP via `calculate_level()` — no independent storage

## Surfaces

### Admin

Admin configures XP values through the Settings screen, organized by category:

| Category | Settings | Defaults |
|----------|----------|----------|
| `xp_reading` | xp_chapter_complete, xp_book_complete, xp_quiz_pass | 50, 200, 20 |
| `xp_vocab` | xp_vocab_multiple_choice, xp_vocab_matching, xp_vocab_scrambled_letters, xp_vocab_spelling, xp_vocab_sentence_gap | 10, 15, 20, 25, 30 |
| `xp_vocab` | xp_inline_true_false, xp_inline_word_translation, xp_inline_find_words, xp_inline_matching | 25, 25, 25, 25 |
| `xp_vocab` | combo_bonus_xp, xp_vocab_session_bonus, xp_vocab_perfect_bonus | 5, 10, 20 |

Settings are live-editable with immediate database sync. Changes apply to the next session/activity (cached until provider invalidation).

### Student

**Earning XP** — XP is awarded through multiple activity types:

| Activity | XP Source | Amount |
|----------|-----------|--------|
| Chapter complete | `addXP` via book_provider | settings.xpChapterComplete (50) |
| Book complete (no quiz) | `addXP` via book_provider | settings.xpBookComplete (200) |
| Quiz pass (>=70%) | `addXP` via book_quiz_provider | settings.xpQuizPass (20) |
| Inline activity (4 types) | `addXP` via reader_provider | 25 each (per-type configurable) |
| Vocab question (correct) | Accumulated in session state | 10-30 by question type |
| Vocab combo bonus | Session end calculation | maxCombo * settings.comboBonusXp (5) |
| Vocab session bonus | Server-side RPC | settings.xpVocabSessionBonus (10) |
| Vocab perfect bonus | Server-side RPC (100% accuracy) | settings.xpVocabPerfectBonus (20) |
| Streak milestone | Server-side RPC | Configurable per milestone |
| Badge XP reward | Server-side badge check | Per-badge xp_reward |

**Level progression** — displayed on profile screen:
- Progress bar shows XP within current level / XP needed for next level
- Level-up triggers a celebration dialog (queued with other events)
- Level capped at 100

**Leaderboard** — ranked by total or weekly XP:
- Class and school scope
- Weekly league tiers (bronze → diamond) with promotion/demotion

### Teacher

- **Leaderboard Report**: All students sorted by total XP
- **Class Detail**: Class XP statistics
- **Student Detail**: Individual student XP history and progress
- **Dashboard**: Class XP statistics and leaderboard preview

## Business Rules

1. **XP = Coins (1:1)**: `award_xp_transaction` atomically awards both XP and coins in equal amounts. There is no separate coin-earning mechanism for XP-granting activities.

2. **Level formula**: `threshold(level) = (level - 1) * level * 100`
   - Level 1: 0 XP, Level 2: 200 XP, Level 3: 600 XP, Level 4: 1200 XP, Level 5: 2000 XP
   - Server inverse: `level = floor((-1 + sqrt(1 + xp/25)) / 2) + 1`
   - Capped at level 100 (server-side)
   - **Client `LevelHelper` MUST match server `calculate_level()`**

3. **Idempotency**: When `source_id` is provided, duplicate awards are silently ignored (returns current state). Manual/badge awards (NULL source_id) are always allowed.

4. **Combo system** (vocabulary sessions only):
   - Correct answer: combo += 1
   - First wrong answer while combo >= 2: warning only, combo preserved
   - Second wrong answer (or combo < 2): combo = max(0, combo - 2)
   - Session end bonus: `maxCombo * comboBonusXp`

5. **Vocab XP by question difficulty**:
   - Recognition tier (10 XP): multipleChoice, reverseMultipleChoice, listeningSelect, imageMatch
   - Bridge tier (15-20 XP): matching (15), scrambledLetters (20), wordWheel (20)
   - Production tier (25-30 XP): spelling (25), listeningWrite (25), sentenceGap (30), pronunciation (30)
   - Pronunciation with mic disabled → falls back to spelling XP (25)

6. **Vocab session bonuses** (server-side, in `complete_vocabulary_session` RPC):
   - Session completion bonus: +10 XP (configurable)
   - Perfect accuracy bonus: +20 XP (configurable, requires 100% accuracy)
   - These bonuses are read from system_settings with fallback defaults

7. **Level-up notification**: Fires only when new level > old level AND `notifLevelUp` setting is true. Queued with streak/badge/league events via dialog queue.

8. **Badge check after every XP award**: `addXP` → `CheckAndAwardBadgesUseCase` → may trigger badge earned notification → badge XP → profile refresh (recursive but finite).

9. **Streak does NOT update per-activity**: Only on app open via `_updateStreakIfNeeded()`. Server RPCs (complete_vocabulary_session, complete_daily_review) call `update_user_streak` internally, so client avoids duplicate calls.

10. **Atomic transaction**: `award_xp_transaction` uses `FOR UPDATE` row lock to prevent race conditions. The entire XP + level + coins + log insert is a single transaction.

## Cross-System Interactions

```
Activity completion (any type)
  → addXP(amount, source, sourceId)
    → award_xp_transaction RPC (atomic: XP + level + coins + xp_log + coin_log)
    → UserController checks level change → LevelUpEvent → celebration dialog
    → CheckAndAwardBadgesUseCase
      → IF new badge earned → BadgeEarnedEvent → celebration dialog
      → IF badge has xp_reward → refreshProfileOnly() (re-fetches profile)
    → invalidate activityHistoryProvider
```

```
Vocab session complete
  → complete_vocabulary_session RPC (server-side: award XP + session/perfect bonuses)
  → Client calls refreshProfileOnly() (NOT addXP — server already awarded)
  → Level-up check in refreshProfileOnly()
```

```
Streak milestone (app open)
  → update_user_streak RPC → milestoneBonusXp > 0
  → XP already awarded server-side
  → StreakResult returned → streak event dialog
```

## Edge Cases

- **Level 100 cap**: `calculate_level` returns `LEAST(..., 100)`. XP continues accumulating but level stops at 100.
- **Negative XP prevention**: `chk_xp_non_negative` constraint on profiles. `award_xp_transaction` only adds positive amounts.
- **Duplicate XP**: Partial unique index on xp_logs + in-function idempotency check. Only enforced when `source_id IS NOT NULL`.
- **Manual/badge XP**: `source_id = NULL` bypasses idempotency — these can be awarded multiple times. Badge awards are protected by the `UNIQUE(user_id, badge_id)` constraint on user_badges.
- **Settings not loaded**: `SystemSettings.defaults()` factory provides hardcoded fallbacks matching the database seed values.
- **Race condition**: Row-level `FOR UPDATE` lock in `award_xp_transaction` serializes concurrent XP awards for the same user.
- **Profile refresh after server-side XP**: `refreshProfileOnly()` re-fetches the profile without triggering streak check, used after vocab sessions and daily reviews where the server already handled everything.

## Test Scenarios

- [ ] Happy path: Complete a chapter → XP awarded, coins increase equally, xp_log entry created
- [ ] Happy path: Complete vocab session → base XP + combo bonus + session bonus displayed, server awards total
- [ ] Level up: Earn enough XP to cross level threshold → celebration dialog appears
- [ ] Combo: Build 5-combo, miss once (warning), miss again (combo drops by 2), verify maxCombo preserved
- [ ] Idempotency: Network retry sends same addXP call twice → XP only awarded once
- [ ] Admin change: Change xp_chapter_complete in admin panel → next chapter complete uses new value
- [ ] Profile display: Level progress bar shows correct fraction (xpInCurrentLevel / xpToNextLevel)
- [ ] Leaderboard: Total and weekly XP rankings show correct positions
- [ ] Boundary: User at level 100 earns more XP → level stays 100, XP still increases
- [ ] Empty state: New user with 0 XP → Level 1, progress bar at 0%
- [ ] Error state: Server error during addXP → error logged, UI unchanged
- [ ] Cross-system: XP award → badge condition met → badge earned dialog follows level-up dialog (queue order)
- [ ] Vocab mic disabled: Pronunciation questions fall back to spelling XP value

## Key Files

**Domain**
- `lib/domain/usecases/user/add_xp_usecase.dart` — core XP award use case
- `lib/domain/entities/system_settings.dart` — all XP configuration values
- `lib/core/utils/level_helper.dart` — client-side level calculation

**Data**
- `lib/data/repositories/supabase/supabase_user_repository.dart` — addXP → RPC call

**Presentation**
- `lib/presentation/providers/user_provider.dart` — UserController (addXP, level-up events, badge checks)
- `lib/presentation/providers/vocabulary_session_provider.dart` — combo system, per-question XP
- `lib/presentation/widgets/common/level_up_celebration.dart` — event dialog queue

**Database**
- `supabase/migrations/20260131000010_create_functions.sql` — calculate_level, award_xp_transaction (original)
- `supabase/migrations/20260316000006_coin_idempotency_and_xp_constraint.sql` — latest award_xp_transaction (with idempotency + coins)
- `supabase/migrations/20260323000015_type_based_xp_settings.sql` — per-type XP settings
- `supabase/migrations/20260328000004_add_auth_check_to_award_xp.sql` — auth.uid() guard on award_xp_transaction
- `supabase/migrations/20260328000005_fix_calculate_level_comments.sql` — corrected level threshold comments

**Admin**
- `owlio_admin/lib/features/settings/screens/settings_screen.dart` — XP settings editor

## Known Issues & Tech Debt

None — all audit findings resolved. Type-based XP per inline activity type is fully wired via `getInlineActivityXP()` in `reader_provider.dart`.
