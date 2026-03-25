# Type-Based XP + Combo Refactor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace per-activity and hardcoded vocab XP with admin-configurable type-based values from `system_settings`, and refactor combo from per-question multiplier to session-end bonus.

**Architecture:** 12 new `system_settings` entries drive XP values. Flutter reads them via the existing `SystemSettings` entity/model/provider pipeline. The `complete_vocabulary_session` RPC reads session/perfect bonuses from the settings table instead of hardcoded constants.

**Tech Stack:** Flutter/Riverpod (entity + model + provider), Supabase PostgreSQL (migration + RPC), owlio_shared enums

**Spec:** `docs/superpowers/specs/2026-03-23-type-based-xp-design.md`

---

## File Structure

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `lib/domain/entities/system_settings.dart` | Add 12 new XP fields with defaults |
| Modify | `lib/data/models/settings/system_settings_model.dart` | Add 12 fields to fromMap, defaults, toEntity, fromEntity |
| Modify | `lib/domain/entities/vocabulary_session.dart` | Remove `QuestionTypeXP` extension |
| Modify | `lib/presentation/providers/vocabulary_session_provider.dart` | Flat XP from settings, combo bonus at session end |
| Modify | `lib/presentation/providers/reader_provider.dart` | Read inline XP from settings by activity type |
| Modify | `lib/presentation/widgets/reader/reader_activity_block.dart` | Pass settings to handler instead of xpEarned |
| Modify | `lib/presentation/widgets/inline_activities/inline_true_false_activity.dart` | Stop reading activity.xpReward |
| Modify | `lib/presentation/widgets/inline_activities/inline_word_translation_activity.dart` | Stop reading activity.xpReward |
| Modify | `lib/presentation/widgets/inline_activities/inline_find_words_activity.dart` | Stop reading activity.xpReward |
| Modify | `lib/presentation/widgets/inline_activities/inline_matching_activity.dart` | Stop reading activity.xpReward |
| Modify | `lib/presentation/screens/vocabulary/session_summary_screen.dart` | Show combo bonus in XP breakdown |
| Modify | `owlio_admin/lib/features/books/widgets/activity_editor.dart` | Remove xp_reward from INSERT |
| Create | `supabase/migrations/20260323000015_type_based_xp_settings.sql` | INSERT 12 new settings |
| Create | `supabase/migrations/20260323000016_update_vocab_session_rpc_settings.sql` | ALTER RPC to read bonuses from settings |

---

## Task 1: DB Migration — Insert 12 New Settings

**Files:**
- Create: `supabase/migrations/20260323000015_type_based_xp_settings.sql`

- [ ] **Step 1: Create migration file**

```sql
-- Type-based XP settings: inline activities, vocab question types, combo bonus, session bonuses
INSERT INTO system_settings (key, value, category) VALUES
  -- Inline activity XP (per type)
  ('xp_inline_true_false', '"25"', 'xp'),
  ('xp_inline_word_translation', '"25"', 'xp'),
  ('xp_inline_find_words', '"25"', 'xp'),
  ('xp_inline_matching', '"25"', 'xp'),
  -- Vocab question type XP (grouped by difficulty)
  ('xp_vocab_multiple_choice', '"10"', 'xp'),
  ('xp_vocab_matching', '"15"', 'xp'),
  ('xp_vocab_scrambled_letters', '"20"', 'xp'),
  ('xp_vocab_spelling', '"25"', 'xp'),
  ('xp_vocab_sentence_gap', '"30"', 'xp'),
  -- Combo bonus (session-end: maxCombo × this value)
  ('combo_bonus_xp', '"5"', 'xp'),
  -- Vocab session bonuses (read by RPC)
  ('xp_vocab_session_bonus', '"10"', 'xp'),
  ('xp_vocab_perfect_bonus', '"20"', 'xp')
ON CONFLICT (key) DO NOTHING;
```

> **Note:** Values are stored as JSONB strings (e.g. `'"25"'`) to match the existing pattern in `system_settings`. The `ON CONFLICT` guard prevents duplicates if re-run.

- [ ] **Step 2: Preview migration**

Run: `supabase db push --dry-run`
Expected: Shows the new migration as pending

- [ ] **Step 3: Push migration**

Run: `supabase db push`
Expected: Migration applied successfully

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260323000015_type_based_xp_settings.sql
git commit -m "feat(db): add 12 type-based XP settings to system_settings"
```

---

## Task 2: SystemSettings Entity — Add 12 Fields

**Files:**
- Modify: `lib/domain/entities/system_settings.dart`

- [ ] **Step 1: Add fields to entity**

Add 12 new fields to the constructor and class body. Group them clearly:

```dart
import 'package:equatable/equatable.dart';

/// System-wide configuration settings entity
/// Only contains settings that are actively used at runtime
class SystemSettings extends Equatable {
  const SystemSettings({
    // XP Rewards
    this.xpChapterComplete = 50,
    this.xpBookComplete = 200,
    this.xpQuizPass = 20,
    // Inline Activity XP (per type)
    this.xpInlineTrueFalse = 25,
    this.xpInlineWordTranslation = 25,
    this.xpInlineFindWords = 25,
    this.xpInlineMatching = 25,
    // Vocab Question Type XP
    this.xpVocabMultipleChoice = 10,
    this.xpVocabMatching = 15,
    this.xpVocabScrambledLetters = 20,
    this.xpVocabSpelling = 25,
    this.xpVocabSentenceGap = 30,
    // Combo & Session Bonuses
    this.comboBonusXp = 5,
    this.xpVocabSessionBonus = 10,
    this.xpVocabPerfectBonus = 20,
    // Streak
    this.streakFreezePrice = 50,
    this.streakFreezeMax = 2,
    // Debug
    this.debugDateOffset = 0,
  });

  // XP Rewards
  final int xpChapterComplete;
  final int xpBookComplete;
  final int xpQuizPass;

  // Inline Activity XP (per type)
  final int xpInlineTrueFalse;
  final int xpInlineWordTranslation;
  final int xpInlineFindWords;
  final int xpInlineMatching;

  // Vocab Question Type XP
  final int xpVocabMultipleChoice;
  final int xpVocabMatching;
  final int xpVocabScrambledLetters;
  final int xpVocabSpelling;
  final int xpVocabSentenceGap;

  // Combo & Session Bonuses
  final int comboBonusXp;
  final int xpVocabSessionBonus;
  final int xpVocabPerfectBonus;

  // Streak
  final int streakFreezePrice;
  final int streakFreezeMax;

  // Debug
  final int debugDateOffset;

  /// Default settings (fallback when database is unavailable)
  factory SystemSettings.defaults() => const SystemSettings();

  @override
  List<Object?> get props => [
        xpChapterComplete,
        xpBookComplete,
        xpQuizPass,
        xpInlineTrueFalse,
        xpInlineWordTranslation,
        xpInlineFindWords,
        xpInlineMatching,
        xpVocabMultipleChoice,
        xpVocabMatching,
        xpVocabScrambledLetters,
        xpVocabSpelling,
        xpVocabSentenceGap,
        comboBonusXp,
        xpVocabSessionBonus,
        xpVocabPerfectBonus,
        streakFreezePrice,
        streakFreezeMax,
        debugDateOffset,
      ];
}
```

- [ ] **Step 2: Verify no compile errors**

Run: `dart analyze lib/domain/entities/system_settings.dart`
Expected: No issues found

---

## Task 3: SystemSettings Model — Add 12 Fields

**Files:**
- Modify: `lib/data/models/settings/system_settings_model.dart`

- [ ] **Step 1: Add fields to model**

Update all 5 locations: constructor, `fromMap`, `defaults`, `toEntity`, `fromEntity`.

```dart
import '../../../domain/entities/system_settings.dart';

/// Model for system settings with JSON serialization
class SystemSettingsModel {
  const SystemSettingsModel({
    required this.xpChapterComplete,
    required this.xpBookComplete,
    required this.xpQuizPass,
    required this.xpInlineTrueFalse,
    required this.xpInlineWordTranslation,
    required this.xpInlineFindWords,
    required this.xpInlineMatching,
    required this.xpVocabMultipleChoice,
    required this.xpVocabMatching,
    required this.xpVocabScrambledLetters,
    required this.xpVocabSpelling,
    required this.xpVocabSentenceGap,
    required this.comboBonusXp,
    required this.xpVocabSessionBonus,
    required this.xpVocabPerfectBonus,
    required this.streakFreezePrice,
    required this.streakFreezeMax,
    required this.debugDateOffset,
  });

  final int xpChapterComplete;
  final int xpBookComplete;
  final int xpQuizPass;
  final int xpInlineTrueFalse;
  final int xpInlineWordTranslation;
  final int xpInlineFindWords;
  final int xpInlineMatching;
  final int xpVocabMultipleChoice;
  final int xpVocabMatching;
  final int xpVocabScrambledLetters;
  final int xpVocabSpelling;
  final int xpVocabSentenceGap;
  final int comboBonusXp;
  final int xpVocabSessionBonus;
  final int xpVocabPerfectBonus;
  final int streakFreezePrice;
  final int streakFreezeMax;
  final int debugDateOffset;

  /// Parse from database rows (key-value pairs)
  factory SystemSettingsModel.fromRows(List<Map<String, dynamic>> rows) {
    final map = <String, dynamic>{};
    for (final row in rows) {
      final key = row['key'] as String;
      map[key] = _parseJsonbValue(row['value']);
    }
    return SystemSettingsModel.fromMap(map);
  }

  /// Parse from key-value map
  factory SystemSettingsModel.fromMap(Map<String, dynamic> m) {
    return SystemSettingsModel(
      xpChapterComplete: _toInt(m['xp_chapter_complete'], 50),
      xpBookComplete: _toInt(m['xp_book_complete'], 200),
      xpQuizPass: _toInt(m['xp_quiz_pass'], 20),
      xpInlineTrueFalse: _toInt(m['xp_inline_true_false'], 25),
      xpInlineWordTranslation: _toInt(m['xp_inline_word_translation'], 25),
      xpInlineFindWords: _toInt(m['xp_inline_find_words'], 25),
      xpInlineMatching: _toInt(m['xp_inline_matching'], 25),
      xpVocabMultipleChoice: _toInt(m['xp_vocab_multiple_choice'], 10),
      xpVocabMatching: _toInt(m['xp_vocab_matching'], 15),
      xpVocabScrambledLetters: _toInt(m['xp_vocab_scrambled_letters'], 20),
      xpVocabSpelling: _toInt(m['xp_vocab_spelling'], 25),
      xpVocabSentenceGap: _toInt(m['xp_vocab_sentence_gap'], 30),
      comboBonusXp: _toInt(m['combo_bonus_xp'], 5),
      xpVocabSessionBonus: _toInt(m['xp_vocab_session_bonus'], 10),
      xpVocabPerfectBonus: _toInt(m['xp_vocab_perfect_bonus'], 20),
      streakFreezePrice: _toInt(m['streak_freeze_price'], 50),
      streakFreezeMax: _toInt(m['streak_freeze_max'], 2),
      debugDateOffset: _toInt(m['debug_date_offset'], 0),
    );
  }

  /// Default model (fallback)
  factory SystemSettingsModel.defaults() => const SystemSettingsModel(
        xpChapterComplete: 50,
        xpBookComplete: 200,
        xpQuizPass: 20,
        xpInlineTrueFalse: 25,
        xpInlineWordTranslation: 25,
        xpInlineFindWords: 25,
        xpInlineMatching: 25,
        xpVocabMultipleChoice: 10,
        xpVocabMatching: 15,
        xpVocabScrambledLetters: 20,
        xpVocabSpelling: 25,
        xpVocabSentenceGap: 30,
        comboBonusXp: 5,
        xpVocabSessionBonus: 10,
        xpVocabPerfectBonus: 20,
        streakFreezePrice: 50,
        streakFreezeMax: 2,
        debugDateOffset: 0,
      );

  /// Convert to entity
  SystemSettings toEntity() => SystemSettings(
        xpChapterComplete: xpChapterComplete,
        xpBookComplete: xpBookComplete,
        xpQuizPass: xpQuizPass,
        xpInlineTrueFalse: xpInlineTrueFalse,
        xpInlineWordTranslation: xpInlineWordTranslation,
        xpInlineFindWords: xpInlineFindWords,
        xpInlineMatching: xpInlineMatching,
        xpVocabMultipleChoice: xpVocabMultipleChoice,
        xpVocabMatching: xpVocabMatching,
        xpVocabScrambledLetters: xpVocabScrambledLetters,
        xpVocabSpelling: xpVocabSpelling,
        xpVocabSentenceGap: xpVocabSentenceGap,
        comboBonusXp: comboBonusXp,
        xpVocabSessionBonus: xpVocabSessionBonus,
        xpVocabPerfectBonus: xpVocabPerfectBonus,
        streakFreezePrice: streakFreezePrice,
        streakFreezeMax: streakFreezeMax,
        debugDateOffset: debugDateOffset,
      );

  /// Create model from entity
  factory SystemSettingsModel.fromEntity(SystemSettings e) =>
      SystemSettingsModel(
        xpChapterComplete: e.xpChapterComplete,
        xpBookComplete: e.xpBookComplete,
        xpQuizPass: e.xpQuizPass,
        xpInlineTrueFalse: e.xpInlineTrueFalse,
        xpInlineWordTranslation: e.xpInlineWordTranslation,
        xpInlineFindWords: e.xpInlineFindWords,
        xpInlineMatching: e.xpInlineMatching,
        xpVocabMultipleChoice: e.xpVocabMultipleChoice,
        xpVocabMatching: e.xpVocabMatching,
        xpVocabScrambledLetters: e.xpVocabScrambledLetters,
        xpVocabSpelling: e.xpVocabSpelling,
        xpVocabSentenceGap: e.xpVocabSentenceGap,
        comboBonusXp: e.comboBonusXp,
        xpVocabSessionBonus: e.xpVocabSessionBonus,
        xpVocabPerfectBonus: e.xpVocabPerfectBonus,
        streakFreezePrice: e.streakFreezePrice,
        streakFreezeMax: e.streakFreezeMax,
        debugDateOffset: e.debugDateOffset,
      );

  // Helper: Parse JSONB value (removes quotes, converts types)
  static dynamic _parseJsonbValue(dynamic v) {
    if (v is! String) return v;
    final s = v.replaceAll('"', '');
    if (s == 'true') return true;
    if (s == 'false') return false;
    return int.tryParse(s) ?? double.tryParse(s) ?? s;
  }

  static int _toInt(dynamic v, int defaultValue) {
    if (v == null) return defaultValue;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? defaultValue;
    return defaultValue;
  }
}
```

- [ ] **Step 2: Verify compile**

Run: `dart analyze lib/data/models/settings/system_settings_model.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/domain/entities/system_settings.dart lib/data/models/settings/system_settings_model.dart
git commit -m "feat: add 12 type-based XP fields to SystemSettings entity + model"
```

---

## Task 4: Inline Activity XP — Settings-Based Lookup

**Files:**
- Modify: `lib/presentation/providers/reader_provider.dart`
- Modify: `lib/presentation/widgets/reader/reader_activity_block.dart`
- Modify: `lib/presentation/widgets/inline_activities/inline_true_false_activity.dart`
- Modify: `lib/presentation/widgets/inline_activities/inline_word_translation_activity.dart`
- Modify: `lib/presentation/widgets/inline_activities/inline_find_words_activity.dart`
- Modify: `lib/presentation/widgets/inline_activities/inline_matching_activity.dart`

**Strategy:** The inline activity widgets currently call `onAnswer(isCorrect, activity.xpReward)`. We change the flow so widgets call `onAnswer(isCorrect)` (no XP arg), and the parent (`reader_activity_block.dart`) looks up XP from `systemSettingsProvider` based on `activity.type`.

- [ ] **Step 1: Add helper function to reader_provider.dart**

First, add these imports at the top of `reader_provider.dart` (none are currently present):

```dart
import 'package:owlio_shared/owlio_shared.dart'; // for InlineActivityType
import '../../domain/entities/system_settings.dart';
import 'system_settings_provider.dart';
```

Then add a top-level helper function near `handleInlineActivityCompletion`:

```dart
/// Get inline activity XP from settings based on activity type
int getInlineActivityXP(WidgetRef ref, InlineActivityType type) {
  final settings = ref.read(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();
  switch (type) {
    case InlineActivityType.trueFalse:
      return settings.xpInlineTrueFalse;
    case InlineActivityType.wordTranslation:
      return settings.xpInlineWordTranslation;
    case InlineActivityType.findWords:
      return settings.xpInlineFindWords;
    case InlineActivityType.matching:
      return settings.xpInlineMatching;
  }
}
```

- [ ] **Step 2: Update reader_activity_block.dart — resolve XP at handler level**

Change `_handleActivityAnswer` to look up XP from settings instead of receiving it as a parameter:

Current (line 132–147):
```dart
Future<void> _handleActivityAnswer(
  WidgetRef ref,
  String activityId,
  bool isCorrect,
  int xpEarned,
  List<String> wordsLearned,
) async {
  await handleInlineActivityCompletion(
    ref,
    activityId: activityId,
    isCorrect: isCorrect,
    xpEarned: xpEarned,
    wordsLearned: wordsLearned,
    onComplete: onActivityCompleted,
  );
}
```

New:
```dart
Future<void> _handleActivityAnswer(
  WidgetRef ref,
  InlineActivity activity,
  bool isCorrect,
  List<String> wordsLearned,
) async {
  final xpEarned = isCorrect ? getInlineActivityXP(ref, activity.type) : 0;
  await handleInlineActivityCompletion(
    ref,
    activityId: activity.id,
    isCorrect: isCorrect,
    xpEarned: xpEarned,
    wordsLearned: wordsLearned,
    onComplete: onActivityCompleted,
  );
}
```

And update all 4 `onAnswer` callbacks in `_buildActivity` to match. For example trueFalse (lines 92–94):

```dart
// Before:
onAnswer: (isCorrect, xpEarned) {
  _handleActivityAnswer(ref, activity.id, isCorrect, xpEarned, []);
},

// After:
onAnswer: (isCorrect) {
  _handleActivityAnswer(ref, activity, isCorrect, []);
},
```

For wordTranslation, findWords, matching (lines 103–127):
```dart
// Before:
onAnswer: (isCorrect, xpEarned, wordsLearned) {
  _handleActivityAnswer(ref, activity.id, isCorrect, xpEarned, wordsLearned);
},

// After:
onAnswer: (isCorrect, wordsLearned) {
  _handleActivityAnswer(ref, activity, isCorrect, wordsLearned);
},
```

- [ ] **Step 3: Update InlineTrueFalseActivity — remove xpEarned from callback**

File: `inline_true_false_activity.dart`

Change callback signature (line 26):
```dart
// Before:
final void Function(bool isCorrect, int xpEarned) onAnswer;

// After:
final void Function(bool isCorrect) onAnswer;
```

Change calls (lines 83, 90):
```dart
// Before:
widget.onAnswer(true, widget.activity.xpReward);
widget.onAnswer(false, 0);

// After:
widget.onAnswer(true);
widget.onAnswer(false);
```

Also update XPEarnedAnimation usage — the XP value shown should come from settings. Find where `XPEarnedAnimation` is used and either pass `0` (since the animation is visual-only and the actual XP is determined server-side) or remove the dependency on `activity.xpReward`. Check how other activity types handle this.

- [ ] **Step 4: Update InlineWordTranslationActivity — remove xpEarned from callback**

File: `inline_word_translation_activity.dart`

Change callback signature:
```dart
// Before:
final void Function(bool isCorrect, int xpEarned, List<String> wordsLearned) onAnswer;

// After:
final void Function(bool isCorrect, List<String> wordsLearned) onAnswer;
```

Change calls (lines ~86, ~97):
```dart
// Before:
widget.onAnswer(true, widget.activity.xpReward, widget.activity.vocabularyWords);
widget.onAnswer(false, 0, widget.activity.vocabularyWords);

// After:
widget.onAnswer(true, widget.activity.vocabularyWords);
widget.onAnswer(false, widget.activity.vocabularyWords);
```

- [ ] **Step 5: Update InlineFindWordsActivity — remove xpEarned from callback**

File: `inline_find_words_activity.dart`

Same pattern as word_translation:
```dart
// Before:
final void Function(bool isCorrect, int xpEarned, List<String> wordsLearned) onAnswer;

// After:
final void Function(bool isCorrect, List<String> wordsLearned) onAnswer;
```

Change call (line ~92-94):
```dart
// Before:
widget.onAnswer(_isCorrect!, _isCorrect! ? widget.activity.xpReward : 0, vocabWords);

// After:
widget.onAnswer(_isCorrect!, vocabWords);
```

- [ ] **Step 6: Update InlineMatchingActivity — remove xpEarned from callback**

File: `inline_matching_activity.dart`

Same pattern:
```dart
// Before:
final void Function(bool isCorrect, int xpEarned, List<String> wordsLearned) onAnswer;

// After:
final void Function(bool isCorrect, List<String> wordsLearned) onAnswer;
```

Change call (line ~183-185):
```dart
// Before:
widget.onAnswer(isCorrect, isCorrect ? widget.activity.xpReward : 0, vocabWords);

// After:
widget.onAnswer(isCorrect, vocabWords);
```

- [ ] **Step 7: Update XPEarnedAnimation display in activity widgets**

Each activity widget shows `XPEarnedAnimation(xp: widget.activity.xpReward)` or similar. Since the widget no longer knows the XP amount, we have two options:

**Option A (recommended):** The XP animation reads from the settings too. Add a `ConsumerStatefulWidget` mixin or pass the XP value down from the parent.

**Option B (simpler):** Keep `activity.xpReward` for animation display only — it's still present in the entity, just not used for actual XP calculation. This avoids changing animation code.

Choose **Option B** — the entity still has `xpReward`, we just don't use it for the actual award. The animation uses it as a display hint. Document this decision as a TODO for future cleanup.

- [ ] **Step 8: Update reader_legacy_content.dart**

File: `lib/presentation/widgets/reader/reader_legacy_content.dart`

This file also builds all 4 activity widgets and calls `handleInlineActivityCompletion`. Update both `_handleActivityAnswer` AND all 4 `onAnswer` lambdas in `_buildActivity`:

Update `_handleActivityAnswer` (lines 198–211):
```dart
// Before:
void _handleActivityAnswer(
  String activityId,
  bool isCorrect,
  int xpEarned,
  List<String> wordsLearned,
) {
  handleInlineActivityCompletion(
    ref,
    activityId: activityId,
    isCorrect: isCorrect,
    xpEarned: xpEarned,
    wordsLearned: wordsLearned,
  );
}

// After:
void _handleActivityAnswer(
  InlineActivity activity,
  bool isCorrect,
  List<String> wordsLearned,
) {
  final xpEarned = isCorrect ? getInlineActivityXP(ref, activity.type) : 0;
  handleInlineActivityCompletion(
    ref,
    activityId: activity.id,
    isCorrect: isCorrect,
    xpEarned: xpEarned,
    wordsLearned: wordsLearned,
  );
}
```

Update all 4 `onAnswer` lambdas in `_buildActivity` (lines 151–195):
```dart
// trueFalse — Before:
onAnswer: (isCorrect, xpEarned) {
  _handleActivityAnswer(activity.id, isCorrect, xpEarned, []);
},
// After:
onAnswer: (isCorrect) {
  _handleActivityAnswer(activity, isCorrect, []);
},

// wordTranslation — Before:
onAnswer: (isCorrect, xpEarned, wordsLearned) {
  _handleActivityAnswer(activity.id, isCorrect, xpEarned, wordsLearned);
},
// After:
onAnswer: (isCorrect, wordsLearned) {
  _handleActivityAnswer(activity, isCorrect, wordsLearned);
},

// findWords — same as wordTranslation
// matching — same as wordTranslation
```

- [ ] **Step 9: Verify compile**

Run: `dart analyze lib/`
Expected: No issues found

- [ ] **Step 10: Commit**

```bash
git add lib/presentation/providers/reader_provider.dart \
        lib/presentation/widgets/reader/reader_activity_block.dart \
        lib/presentation/widgets/reader/reader_legacy_content.dart \
        lib/presentation/widgets/inline_activities/inline_true_false_activity.dart \
        lib/presentation/widgets/inline_activities/inline_word_translation_activity.dart \
        lib/presentation/widgets/inline_activities/inline_find_words_activity.dart \
        lib/presentation/widgets/inline_activities/inline_matching_activity.dart
git commit -m "refactor: inline activity XP from system_settings instead of per-activity column"
```

---

## Task 5: Remove QuestionTypeXP Extension

**Files:**
- Modify: `lib/domain/entities/vocabulary_session.dart`

- [ ] **Step 1: Delete the QuestionTypeXP extension**

Remove lines 22–45 (the entire `QuestionTypeXP` extension). Keep `QuestionTypeTier` and everything else.

```dart
// DELETE THIS ENTIRE BLOCK:
/// XP values per question type
extension QuestionTypeXP on QuestionType {
  int get baseXP {
    switch (this) {
      // ... all cases
    }
  }
}
```

- [ ] **Step 2: Verify references are broken (expected)**

Run: `dart analyze lib/`
Expected: Errors in `vocabulary_session_provider.dart` referencing `.baseXP` — these will be fixed in Task 6.

> **IMPORTANT:** Do NOT commit at this step. Task 5 and Task 6 are one atomic unit — the `QuestionTypeXP` removal and its replacement in `vocabulary_session_provider.dart` must be committed together in Task 6 Step 7.

---

## Task 6: Vocab Session XP — Flat BaseXP from Settings + Combo Bonus

**Files:**
- Modify: `lib/presentation/providers/vocabulary_session_provider.dart`

This is the core change: replace `question.type.baseXP * comboMultiplier` with flat `baseXP` from settings, and add `maxCombo × comboBonusXp` at session end.

- [ ] **Step 1: Add helper method to get vocab XP from settings**

Add a method inside `VocabularySessionController` (or as a top-level helper):

```dart
/// Get vocab question base XP from system settings
int _getVocabBaseXP(QuestionType type, bool micDisabledForSession) {
  final settings = ref.read(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();

  // Pronunciation with mic disabled → use spelling XP
  if (type == QuestionType.pronunciation && micDisabledForSession) {
    return settings.xpVocabSpelling;
  }

  switch (type) {
    case QuestionType.multipleChoice:
    case QuestionType.reverseMultipleChoice:
    case QuestionType.listeningSelect:
    case QuestionType.imageMatch:
      return settings.xpVocabMultipleChoice;
    case QuestionType.matching:
      return settings.xpVocabMatching;
    case QuestionType.scrambledLetters:
    case QuestionType.wordWheel:
      return settings.xpVocabScrambledLetters;
    case QuestionType.spelling:
    case QuestionType.listeningWrite:
      return settings.xpVocabSpelling;
    case QuestionType.sentenceGap:
    case QuestionType.pronunciation:
      return settings.xpVocabSentenceGap;
  }
}
```

Add necessary imports at top of file:
```dart
import '../../domain/entities/system_settings.dart';
import 'system_settings_provider.dart';
```

- [ ] **Step 2: Update answerQuestion — flat XP, no combo multiplier**

Replace lines 312–321:

```dart
// Current:
int xpGained = 0;
if (isCorrect) {
  final comboMultiplier = min<int>(newCombo, 5); // Cap at x5
  final baseXP = (question.type == QuestionType.pronunciation &&
          state.micDisabledForSession)
      ? QuestionType.spelling.baseXP
      : question.type.baseXP;
  xpGained = baseXP * max<int>(1, comboMultiplier);
}

// New:
int xpGained = 0;
if (isCorrect) {
  xpGained = _getVocabBaseXP(question.type, state.micDisabledForSession);
}
```

- [ ] **Step 3: Update answerMatchingQuestion — flat XP, no combo multiplier**

Replace lines 422–426:

```dart
// Current:
final comboMult = max<int>(1, min<int>(newCombo, 5));
final xpGained = correctMatches > 0
    ? (QuestionType.matching.baseXP * comboMult * correctMatches) ~/ totalMatches
    : 0;

// New:
final matchingBaseXP = _getVocabBaseXP(QuestionType.matching, state.micDisabledForSession);
final xpGained = correctMatches > 0
    ? (matchingBaseXP * correctMatches) ~/ totalMatches
    : 0;
```

- [ ] **Step 4: Add comboBonus field to VocabularySessionState**

This field must exist before the session completion logic uses it.

Add the field and wire it through copyWith:
```dart
// Constructor (add after lastComboBroken):
this.comboBonus = 0,

// Field (add after lastComboBroken):
final int comboBonus;

// copyWith parameter:
int? comboBonus,

// copyWith body:
comboBonus: comboBonus ?? this.comboBonus,
```

- [ ] **Step 5: Add combo bonus to session XP at session completion**

Find the method where `isSessionComplete` is set to `true` (the session completion point). Add the combo bonus calculation right before it:

```dart
// At session completion, add combo bonus
final settings = ref.read(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();
final comboBonus = state.maxCombo * settings.comboBonusXp;
state = state.copyWith(
  comboBonus: comboBonus,
  xpEarned: state.xpEarned + comboBonus,
  isSessionComplete: true,
);
```

> **Note:** `comboBonus` is baked into `state.xpEarned`, which gets sent to the RPC as `p_xp_earned`. The RPC then adds `v_session_bonus` and `v_perfect_bonus` on top — no double-counting. The `comboBonus` field exists separately only for display purposes in the summary screen.

- [ ] **Step 6: Verify compile**

Run: `dart analyze lib/`
Expected: No issues found (QuestionTypeXP references all replaced)

- [ ] **Step 7: Commit**

```bash
git add lib/domain/entities/vocabulary_session.dart \
        lib/presentation/providers/vocabulary_session_provider.dart
git commit -m "refactor: vocab XP from system_settings, combo becomes session-end bonus"
```

---

## Task 7: Session Summary — Show Combo Bonus

**Files:**
- Modify: `lib/presentation/screens/vocabulary/session_summary_screen.dart`

- [ ] **Step 1: Show combo bonus in XP display**

Update the "Coins Earned" stat card to show a breakdown when combo bonus > 0.

Near line 256–261, update the value to include combo info:

```dart
_StatCard(
  icon: Icons.monetization_on,
  iconColor: Colors.amber,
  label: 'Coins Earned',
  value: '+${_actualXpAwarded ?? session.xpEarned}',
  subtitle: session.comboBonus > 0 ? '(+${session.comboBonus} combo)' : null,
  delay: 400.ms,
),
```

If `_StatCard` doesn't support `subtitle`, add the parameter:

```dart
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.subtitle,
    required this.delay,
  });
  // ...
  final String? subtitle;
```

And display it below the value text if non-null.

- [ ] **Step 2: Verify compile**

Run: `dart analyze lib/presentation/screens/vocabulary/session_summary_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/vocabulary/session_summary_screen.dart
git commit -m "feat: show combo bonus separately in session summary"
```

---

## Task 8: Server-Side RPC — Read Bonuses from Settings

**Files:**
- Create: `supabase/migrations/20260323000016_update_vocab_session_rpc_settings.sql`

- [ ] **Step 1: Create migration**

Replace the `complete_vocabulary_session` function to read `v_session_bonus` and `v_perfect_bonus` from `system_settings` instead of hardcoding them:

```sql
CREATE OR REPLACE FUNCTION complete_vocabulary_session(
    p_user_id UUID,
    p_word_list_id UUID,
    p_total_questions INTEGER,
    p_correct_count INTEGER,
    p_incorrect_count INTEGER,
    p_accuracy DECIMAL(5,2),
    p_max_combo INTEGER,
    p_xp_earned INTEGER,
    p_duration_seconds INTEGER,
    p_words_strong INTEGER,
    p_words_weak INTEGER,
    p_first_try_perfect_count INTEGER,
    p_word_results JSONB
)
RETURNS TABLE(
    session_id UUID,
    total_xp INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session_id UUID;
    v_total_xp INTEGER;
    v_xp_to_award INTEGER;
    v_previous_best INTEGER;
    v_session_bonus INTEGER;
    v_perfect_bonus INTEGER;
    v_word_result JSONB;
    v_is_perfect BOOLEAN;
    v_word_id UUID;
    v_current_reps INTEGER;
    v_current_interval INTEGER;
    v_current_ease NUMERIC;
    v_new_interval INTEGER;
    v_new_status TEXT;
BEGIN
    -- Read bonuses from system_settings (with fallback defaults)
    SELECT COALESCE(
      (SELECT (value #>> '{}')::INTEGER FROM system_settings WHERE key = 'xp_vocab_session_bonus'),
      10
    ) INTO v_session_bonus;

    SELECT COALESCE(
      (SELECT (value #>> '{}')::INTEGER FROM system_settings WHERE key = 'xp_vocab_perfect_bonus'),
      20
    ) INTO v_perfect_bonus;

    v_is_perfect := (p_accuracy >= 100.0);
    v_total_xp := p_xp_earned + v_session_bonus;
    IF v_is_perfect THEN
        v_total_xp := v_total_xp + v_perfect_bonus;
    END IF;

    SELECT COALESCE(best_score, 0) INTO v_previous_best
    FROM user_word_list_progress
    WHERE user_id = p_user_id AND word_list_id = p_word_list_id;

    IF NOT FOUND THEN
        v_previous_best := 0;
    END IF;

    v_xp_to_award := GREATEST(0, v_total_xp - v_previous_best);

    INSERT INTO vocabulary_sessions (
        user_id, word_list_id, total_questions, correct_count, incorrect_count,
        accuracy, max_combo, xp_earned, duration_seconds,
        words_strong, words_weak, first_try_perfect_count
    ) VALUES (
        p_user_id, p_word_list_id, p_total_questions, p_correct_count, p_incorrect_count,
        p_accuracy, p_max_combo, v_total_xp, p_duration_seconds,
        p_words_strong, p_words_weak, p_first_try_perfect_count
    ) RETURNING id INTO v_session_id;

    FOR v_word_result IN SELECT * FROM jsonb_array_elements(p_word_results)
    LOOP
        v_word_id := (v_word_result->>'word_id')::UUID;

        INSERT INTO vocabulary_session_words (
            session_id, word_id, correct_count, incorrect_count,
            mastery_level, is_first_try_perfect
        ) VALUES (
            v_session_id,
            v_word_id,
            (v_word_result->>'correct_count')::INTEGER,
            (v_word_result->>'incorrect_count')::INTEGER,
            COALESCE(v_word_result->>'mastery_level', 'introduced'),
            COALESCE((v_word_result->>'is_first_try_perfect')::BOOLEAN, FALSE)
        );

        IF (v_word_result->>'incorrect_count')::INTEGER = 0 THEN
            SELECT repetitions, interval_days, ease_factor
            INTO v_current_reps, v_current_interval, v_current_ease
            FROM vocabulary_progress
            WHERE user_id = p_user_id AND word_id = v_word_id;

            IF NOT FOUND THEN
                INSERT INTO vocabulary_progress (
                    user_id, word_id, status, ease_factor,
                    interval_days, repetitions, next_review_at, last_reviewed_at
                ) VALUES (
                    p_user_id, v_word_id, 'learning', 2.50,
                    1, 1, app_now() + INTERVAL '1 day', app_now()
                );
            ELSE
                v_current_reps := v_current_reps + 1;

                IF v_current_reps = 1 THEN
                    v_new_interval := 1;
                ELSIF v_current_reps = 2 THEN
                    v_new_interval := 6;
                ELSE
                    v_new_interval := LEAST(
                        CEIL(v_current_interval * v_current_ease),
                        365
                    );
                END IF;

                IF v_new_interval > 21 THEN
                    v_new_status := 'mastered';
                ELSIF v_current_reps >= 2 THEN
                    v_new_status := 'reviewing';
                ELSE
                    v_new_status := 'learning';
                END IF;

                UPDATE vocabulary_progress SET
                    last_reviewed_at = app_now(),
                    repetitions = v_current_reps,
                    interval_days = v_new_interval,
                    ease_factor = LEAST(v_current_ease + 0.02, 3.0),
                    next_review_at = app_now() + make_interval(days => v_new_interval),
                    status = v_new_status
                WHERE user_id = p_user_id
                  AND word_id = v_word_id
                  AND status != 'mastered';
            END IF;
        ELSE
            INSERT INTO vocabulary_progress (
                user_id, word_id, status, ease_factor,
                interval_days, repetitions, next_review_at, last_reviewed_at
            ) VALUES (
                p_user_id, v_word_id, 'learning', 2.50,
                0, 0, app_now(), app_now()
            )
            ON CONFLICT (user_id, word_id) DO UPDATE SET
                last_reviewed_at = app_now(),
                interval_days = 0,
                repetitions = 0,
                ease_factor = GREATEST(vocabulary_progress.ease_factor - 0.2, 1.3),
                next_review_at = app_now(),
                status = 'learning';
        END IF;
    END LOOP;

    INSERT INTO user_word_list_progress (
        user_id, word_list_id, best_score, best_accuracy,
        total_sessions, last_session_at, started_at, completed_at, updated_at
    ) VALUES (
        p_user_id, p_word_list_id, v_total_xp, p_accuracy,
        1, NOW(), NOW(), NOW(), NOW()
    )
    ON CONFLICT (user_id, word_list_id) DO UPDATE SET
        best_score = GREATEST(user_word_list_progress.best_score, v_total_xp),
        best_accuracy = GREATEST(user_word_list_progress.best_accuracy, p_accuracy),
        total_sessions = user_word_list_progress.total_sessions + 1,
        last_session_at = NOW(),
        completed_at = COALESCE(user_word_list_progress.completed_at, NOW()),
        updated_at = NOW();

    IF v_xp_to_award > 0 THEN
        PERFORM award_xp_transaction(
            p_user_id,
            v_xp_to_award,
            'vocabulary_session',
            v_session_id,
            'Vocabulary session completed'
        );
    END IF;

    -- Streak removed: now login-based (checked on app open)

    PERFORM check_and_award_badges(p_user_id);

    RETURN QUERY SELECT v_session_id, v_xp_to_award;
END;
$$;
```

Key change: lines reading from `system_settings`:
```sql
SELECT COALESCE(
  (SELECT (value #>> '{}')::INTEGER FROM system_settings WHERE key = 'xp_vocab_session_bonus'),
  10
) INTO v_session_bonus;
```

The `value #>> '{}'` extracts the raw text from JSONB (handles both `"10"` and `10`).

- [ ] **Step 2: Preview migration**

Run: `supabase db push --dry-run`
Expected: Shows the new migration as pending

- [ ] **Step 3: Push migration**

Run: `supabase db push`
Expected: Migration applied successfully

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260323000016_update_vocab_session_rpc_settings.sql
git commit -m "feat(db): vocab session RPC reads bonuses from system_settings"
```

---

## Task 9: Admin Panel — Remove xp_reward from Activity Insert

**Files:**
- Modify: `owlio_admin/lib/features/books/widgets/activity_editor.dart`

- [ ] **Step 1: Remove xp_reward from INSERT**

In `activity_editor.dart` line 300, remove the `'xp_reward': 5` line from the insert map:

```dart
// Before (line 294-302):
await supabase.from(DbTables.inlineActivities).insert({
  'id': activityId,
  'chapter_id': widget.chapterId,
  'type': widget.activityType,
  'content': content,
  'vocabulary_words': vocabIds,
  'xp_reward': 5,
  'after_paragraph_index': 0,
});

// After:
await supabase.from(DbTables.inlineActivities).insert({
  'id': activityId,
  'chapter_id': widget.chapterId,
  'type': widget.activityType,
  'content': content,
  'vocabulary_words': vocabIds,
  'after_paragraph_index': 0,
});
```

> The DB column has `DEFAULT 5`, so omitting it is safe. The Flutter app no longer reads this column for XP calculation anyway.

- [ ] **Step 2: Check book_json_import_screen.dart**

File: `owlio_admin/lib/features/books/screens/book_json_import_screen.dart` line 178

The import screen also writes `'xp_reward': pa.activity['xp_reward'] ?? 5`. Leave this as-is — the column still exists in DB, and JSON imports may include it. It's harmless since Flutter no longer reads it for XP.

- [ ] **Step 3: Verify admin panel compiles**

Run: `cd owlio_admin && dart analyze lib/`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add owlio_admin/lib/features/books/widgets/activity_editor.dart
git commit -m "refactor(admin): remove xp_reward from activity insert (now from settings)"
```

---

## Task 10: Final Verification & Cleanup

- [ ] **Step 1: Full analyze**

Run: `dart analyze lib/`
Expected: No issues found

- [ ] **Step 2: Grep for removed patterns**

```bash
# Should return 0 results (QuestionTypeXP removed):
grep -r "\.baseXP" lib/

# Should return 0 results in presentation layer (no longer used for XP calc):
grep -r "activity\.xpReward\b" lib/presentation/providers/

# Should return 0 results (combo multiplier removed):
grep -r "comboMultiplier\|min.*combo.*5" lib/presentation/providers/vocabulary_session_provider.dart
```

- [ ] **Step 3: Verify test suite**

Run: `flutter test`
Expected: All tests pass (or existing failures unrelated to this change)

- [ ] **Step 4: Final commit if any fixups needed**

```bash
git add -A
git commit -m "chore: type-based XP cleanup and verification"
```
