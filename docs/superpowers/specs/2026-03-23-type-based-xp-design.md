# Type-Based XP + Combo Refactor — Design Spec

**Date:** 2026-03-23
**Scope:** Replace per-activity XP and hardcoded vocab XP with type-based system_settings values. Refactor combo from multiplier to session-end bonus.

---

## Problem Statement

Two XP systems have configuration issues:
1. **Inline activities:** Each activity has its own `xp_reward` DB column — too granular, creates inconsistency
2. **Vocab sessions:** Per-question-type baseXP is hardcoded in a Dart enum extension, combo multiplier is hardcoded at 5x cap, session/perfect bonuses are hardcoded in SQL RPC

Both should read from `system_settings` so admins can configure XP values.

---

## Design

### A. Inline Activities → Type-Based Fixed XP

**Current:** `inline_activities.xp_reward` per-row (default 5)
**New:** 4 settings in `system_settings`, all defaulting to 25:

| Setting Key | Default | For |
|-------------|---------|-----|
| `xp_inline_true_false` | 25 | TrueFalse activities |
| `xp_inline_word_translation` | 25 | WordTranslation activities |
| `xp_inline_find_words` | 25 | FindWords activities |
| `xp_inline_matching` | 25 | Matching activities |

**Changes:**
- Inline activity widgets stop reading `activity.xpReward`
- Instead, `handleInlineActivityCompletion` reads the XP value from `systemSettingsProvider` based on activity type
- Per-activity `xp_reward` column stays in DB (no migration needed to drop it) but is no longer read by Flutter code
- Admin panel activity editor no longer shows XP field per activity

**Entity/Model:** Add 4 `int` fields to `SystemSettings` entity and `SystemSettingsModel`

---

### B. Vocab Session → Type-Based Fixed XP from Settings

**Current:** `QuestionTypeXP.baseXP` enum extension (hardcoded 10/15/20/25/30)
**New:** 11 settings in `system_settings`:

| Setting Key | Default | Question Types |
|-------------|---------|----------------|
| `xp_vocab_multiple_choice` | 10 | multipleChoice, reverseMultipleChoice, listeningSelect, imageMatch |
| `xp_vocab_matching` | 15 | matching |
| `xp_vocab_scrambled_letters` | 20 | scrambledLetters, wordWheel |
| `xp_vocab_spelling` | 25 | spelling, listeningWrite |
| `xp_vocab_sentence_gap` | 30 | sentenceGap, pronunciation |

Note: Question types that share the same XP share one setting (5 settings, not 11). Pronunciation with mic disabled uses `xp_vocab_spelling` value.

**Changes:**
- Remove `QuestionTypeXP` extension from `vocabulary_session.dart`
- `vocabulary_session_provider.dart` reads XP from `systemSettingsProvider` instead of `question.type.baseXP`
- New helper method maps `QuestionType` → setting field

---

### C. Combo Refactor → Session-End Bonus

**Current:** `baseXP × min(combo, 5)` applied per-question (instant)
**New:**
- Each correct answer → flat `baseXP` (no multiplier)
- Session end → `max_combo_achieved × combo_bonus_xp` (one-time bonus)
- `max_combo_achieved` = highest consecutive correct streak during the session

| Setting Key | Default | Description |
|-------------|---------|-------------|
| `combo_bonus_xp` | 5 | XP per combo count at session end |

**Changes:**
- `vocabulary_session_provider.dart`: Remove combo multiplier from per-question XP calc
- Track `maxCombo` in session state (already tracking `combo` — just add `maxCombo = max(combo, maxCombo)`)
- At session end: include `maxCombo × combo_bonus_xp` in `p_xp_earned` sent to RPC
- Session summary screen shows combo bonus separately

---

### D. Server-Side Bonuses → Settings

**Current:** Hardcoded in `complete_vocabulary_session` RPC: `v_session_bonus = 10`, `v_perfect_bonus = 20`
**New:** RPC reads from `system_settings` table:

| Setting Key | Default | Description |
|-------------|---------|-------------|
| `xp_vocab_session_bonus` | 10 | Bonus for completing any session |
| `xp_vocab_perfect_bonus` | 20 | Bonus for 100% accuracy |

**Changes:**
- New migration: ALTER `complete_vocabulary_session` to read bonuses from `system_settings`
- Fallback to defaults if settings not found

---

## New system_settings Entries (Total: 12)

| Key | Value | Category |
|-----|-------|----------|
| `xp_inline_true_false` | 25 | xp |
| `xp_inline_word_translation` | 25 | xp |
| `xp_inline_find_words` | 25 | xp |
| `xp_inline_matching` | 25 | xp |
| `xp_vocab_multiple_choice` | 10 | xp |
| `xp_vocab_matching` | 15 | xp |
| `xp_vocab_scrambled_letters` | 20 | xp |
| `xp_vocab_spelling` | 25 | xp |
| `xp_vocab_sentence_gap` | 30 | xp |
| `combo_bonus_xp` | 5 | xp |
| `xp_vocab_session_bonus` | 10 | xp |
| `xp_vocab_perfect_bonus` | 20 | xp |

---

## Files Changed

### DB Migrations
| File | Change |
|------|--------|
| `supabase/migrations/YYYYMMDD_type_based_xp_settings.sql` | INSERT 12 new settings |
| `supabase/migrations/YYYYMMDD_update_vocab_session_rpc.sql` | ALTER `complete_vocabulary_session` to read bonuses from settings |

### Domain Layer
| File | Change |
|------|--------|
| `lib/domain/entities/system_settings.dart` | Add 12 new fields |
| `lib/domain/entities/vocabulary_session.dart` | Remove `QuestionTypeXP` extension |

### Data Layer
| File | Change |
|------|--------|
| `lib/data/models/settings/system_settings_model.dart` | Add 12 fields to all methods |

### Presentation Layer
| File | Change |
|------|--------|
| `lib/presentation/providers/vocabulary_session_provider.dart` | New XP calc: flat baseXP + track maxCombo + combo bonus at session end |
| `lib/presentation/providers/reader_provider.dart` | Read inline XP from settings by activity type |
| `lib/presentation/widgets/inline_activities/*.dart` | Stop passing `activity.xpReward`, pass activity type instead |
| `lib/presentation/screens/vocabulary/session_summary_screen.dart` | Show combo bonus separately (optional) |

### Admin Panel
| File | Change |
|------|--------|
| `owlio_admin/.../activity_editor.dart` | Remove XP field from activity form (auto from settings now) |

---

## Out of Scope

- Dropping `inline_activities.xp_reward` DB column (no migration risk — just stop reading it)
- Daily review XP refactor (separate system, works differently)
- Inline activity dead legacy code cleanup (separate task)

---

## Verification

```bash
dart analyze lib/
# Grep for removed patterns:
grep -r "\.baseXP" lib/
grep -r "activity\.xpReward\|activity.xp_reward" lib/
grep -r "comboMultiplier\|min.*combo.*5" lib/
```
