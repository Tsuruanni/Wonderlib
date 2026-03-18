# Vocabulary Session System — Complete Technical Reference

> **Purpose:** This document describes the FULL implementation of vocabulary sessions.
> **When to read:** Before ANY change to vocabulary features — new question types, algorithm changes, XP modifications, session flow changes, or provider/state modifications.

---

## Table of Contents

1. [Session Flow Overview](#1-session-flow-overview)
2. [The Three Phases](#2-the-three-phases)
3. [Question Types — Complete Reference](#3-question-types--complete-reference)
4. [Session Algorithm](#4-session-algorithm)
5. [Mastery Level Progression](#5-mastery-level-progression)
6. [Combo & XP System](#6-combo--xp-system)
7. [SM2 Spaced Repetition](#7-sm2-spaced-repetition)
8. [State Management & Providers](#8-state-management--providers)
9. [Data Flow (Supabase → UI)](#9-data-flow-supabase--ui)
10. [Session Completion & Persistence](#10-session-completion--persistence)
11. [Key Files Reference](#11-key-files-reference)
12. [Architecture Observations & Known Quirks](#12-architecture-observations--known-quirks)

---

## 1. Session Flow Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    SESSION LIFECYCLE                          │
│                                                              │
│  Screen Load                                                 │
│    → wordsForListProvider(listId)                            │
│    → (optional) filter by retryWordIds                       │
│    → controller.startSession(words)                          │
│                                                              │
│  ┌──────────┐    ┌───────────┐    ┌────────────┐            │
│  │ Phase 1  │───▶│  Phase 2  │───▶│  Phase 3   │──▶ Done   │
│  │ EXPLORE  │    │ REINFORCE │    │   FINAL    │            │
│  └──────────┘    └───────────┘    └────────────┘            │
│   Introduce       Mixed types      Weak words               │
│   words in        by mastery       production                │
│   pairs           level            questions                 │
│                                                              │
│  Done → context.go(sessionSummaryPath)                       │
│       → RPC: complete_vocabulary_session                     │
│       → XP delta awarded, SM2 updated, badges checked        │
└─────────────────────────────────────────────────────────────┘
```

**Entry point:** `VocabularySessionScreen` accepts `listId` (required) and `retryWordIds` (optional for retry sessions). Minimum 2 words required to start.

---

## 2. The Three Phases

### Phase 1: Explore (`SessionPhase.explore`)

Words are introduced in **pairs** (ceil(N/2) pairs for N words).

For each pair:
1. Two `VocabWordIntroductionCard` widgets shown (image, EN word + TTS button, TR meaning pill, example sentence)
2. User taps "Continue"
3. `finishIntroduction()` marks words as `WordMasteryLevel.introduced`
4. A simple **2-option** question is generated:
   - **Even pairs:** EN word shown → pick correct TR meaning
   - **Odd pairs:** Audio plays (TTS) → pick correct EN word (`listeningSelect`)
5. After answering → `advanceAfterExploreQuestion()` → next pair or Phase 2

### Phase 2: Reinforce (`SessionPhase.reinforce`)

Mixed question types determined by each word's mastery level.

**Exit conditions** (whichever comes first):
- All words ≥ `recognized` AND ≥ 10 questions answered
- ≥ 14 questions answered (hard cap)
- No target word found (all words at `produced` mastery) AND no weak words

**Word selection priority** (strictly lower-mastery-first):
1. Words at `unseen`/`introduced` → recognition-tier questions
2. Words at `recognized` → bridge-tier questions
3. Words at `bridged`/`produced` → production-tier questions
4. All at max mastery → random pick

**Remediation system:** When a word is answered incorrectly, it's added to `remediationQueue`. Each question generation has a **40% chance** to pull from the queue and generate a simplified 2-option MC with image support (`isRemediation: true`).

### Phase 3: Final (`SessionPhase.finalPhase`)

Focuses only on **weak words** (any word with `incorrectCount > 0`, sorted by most errors first).

- Runs `min(5, weakWords.length)` questions
- Uses **production-tier question types only**: spelling, sentenceGap, scrambledLetters, wordWheel
- If no weak words exist → Phase 3 is skipped, session completes directly

### Phase Transition Summary

| From | To | Condition |
|---|---|---|
| explore | reinforce | All pairs introduced + their questions answered |
| reinforce | finalPhase | (all words ≥ recognized AND ≥10 questions) OR ≥14 questions |
| reinforce | complete | No target word found + no weak words |
| finalPhase | complete | finalQuestionsAsked ≥ min(5, weakWords.length) |
| finalPhase | complete | weakWords.isEmpty at transition time |

---

## 3. Question Types — Complete Reference

### Enum: `QuestionType` (10 types)

```
Recognition Tier          Bridge Tier              Production Tier
─────────────────         ──────────────           ─────────────────
multipleChoice            matching                 spelling
reverseMultipleChoice     scrambledLetters         listeningWrite
listeningSelect           wordWheel                sentenceGap
                                                   pronunciation
```

---

### Recognition Tier

#### `multipleChoice` — `VocabMultipleChoiceQuestion`
- **Prompt:** "Select the correct meaning"
- **Display:** EN word + optional image + TTS speaker button
- **Options:** 2 options (Phase 1) or 4 options (Phase 2/3)
- **Distractors:** Other words from session pool; padded with placeholders `('(diger)', '(yok)', '(bilinmiyor)')` if pool < 3
- **Evaluation:** Immediate on tap
- **Feedback:** Cards turn green (correct) / red (wrong selected) / green (correct not chosen)
- **Base XP:** 10

#### `reverseMultipleChoice` — `VocabMultipleChoiceQuestion` (same widget)
- **Prompt:** "Select the correct English word"
- **Display:** TR meaning shown, user picks EN word. No TTS button.
- **Flag:** `isReverse = true` swaps display direction
- **Base XP:** 10

#### `listeningSelect` — `VocabListeningQuestion` (select mode)
- **Prompt:** "Listen and select the correct word"
- **Display:** Large pulsing speaker button, auto-plays TTS on load
- **Options:** 2 options (Phase 1) or 3-4 (Phase 2)
- **Flag:** `isWriteMode = false`
- **Base XP:** 10

---

### Bridge Tier

#### `matching` — `VocabMatchingQuestion`
- **Prompt:** "Tap pairs to match them"
- **Display:** Two columns — 4 shuffled EN words (left) | 4 shuffled TR meanings (right)
- **Interaction:** Tap word → tap meaning. Correct pairs fade out. Wrong pairs shake + red for 800ms.
- **Completion:** When all 4 pairs matched
- **Evaluation:** `answerMatchingQuestion()` (NOT `answerQuestion()`) with per-word correct/incorrect breakdown
- **XP:** `baseXP(15) * comboMultiplier * correctMatches / totalMatches` (partial credit)
- **Requirement:** Only generated when ≥4 words available at recognized level
- **Base XP:** 15

#### `scrambledLetters` — `VocabScrambledLettersQuestion`
- **Prompt:** "Arrange letters to form the word"
- **Display:** TR meaning + optional image as hint. Letter tiles (56x56) in pool at bottom, answer slots at top.
- **Interaction:** Tap letters from pool → appear in slots. Tap filled slot → deselects it and everything after.
- **Auto-submit:** When all letters placed
- **Scrambling:** `shuffle()` loop, up to 20 attempts to ensure different from original
- **Evaluation:** `selectedLetters.join().toLowerCase() == correctWord.toLowerCase()`
- **Base XP:** 20

#### `wordWheel` — `VocabWordWheelQuestion`
- **Prompt:** "Connect the letters"
- **Display:** Letters arranged in a circle (radius=110). `CustomPaint` draws connection lines.
- **Interaction:** Drag between letters or tap in sequence. Hit radius = 38px.
- **Auto-submit:** When `selectedIndices.length == letters.length`
- **Deselect:** Tap already-selected letter → removes it and subsequent selections
- **Base XP:** 20

---

### Production Tier

#### `spelling` — `VocabSpellingQuestion`
- **Prompt:** "Type the English word"
- **Display:** TR meaning in highlighted pill + optional image. Auto-focused keyboard.
- **Submit:** "Check Answer" button (enabled when non-empty) or keyboard "done"
- **Evaluation:** Case-insensitive trim comparison
- **Base XP:** 25

#### `listeningWrite` — `VocabListeningQuestion` (write mode)
- **Prompt:** "Listen and type the word"
- **Display:** Large speaker button (auto-plays TTS on load) + text field
- **Flag:** `isWriteMode = true`
- **Submit:** "Check Answer" button or keyboard action
- **Availability:** Only in Phase 2 when word mastery is `bridged`/`produced`
- **Base XP:** 25

#### `sentenceGap` — `VocabSentenceGapQuestion`
- **Prompt:** "Fill in the blank"
- **Display:** TR meaning (italic). Sentence as `RichText` with `___` inline placeholder showing typed text in real time.
- **Sentence source:** `exampleSentence.replaceFirst(word, '___')`. Falls back to `'The ___ is important.'` if null.
- **Requirement:** Only generated if `word.exampleSentence != null`
- **Base XP:** 30

#### `pronunciation` — `VocabPronunciationQuestion`
- **Prompt:** "Say the English word"
- **Display:** Image (if available) + TR meaning. EN word is NOT shown (recall test).
- **Interaction:** Hold-to-speak (long press mic button). Device STT evaluates pronunciation.
- **Fallback:** "Can't use microphone?" → switches to spelling mode (TextField). Disables pronunciation for entire session.
- **Evaluation:** Exact word match = always correct regardless of confidence. Empty result = retry prompt.
- **Min word length:** Only generated for words with length >= 3
- **Base XP:** 30 (falls to 25 in spelling fallback mode)

---

### Question Type Availability by Phase

| Question Type | Phase 1 (Explore) | Phase 2 (Reinforce) | Phase 3 (Final) |
|---|:---:|:---:|:---:|
| multipleChoice | Yes (2 options) | Yes (4 options) | - |
| reverseMultipleChoice | Yes (2 options) | Yes (4 options) | - |
| listeningSelect | Yes (2 options) | Yes (3-4 options) | - |
| matching | - | Yes (if ≥4 words) | - |
| scrambledLetters | - | Yes | Yes |
| wordWheel | - | Yes | Yes |
| spelling | - | Yes | Yes |
| listeningWrite | - | Yes | - |
| sentenceGap | - | Yes (if sentence exists) | Yes (if sentence exists) |
| pronunciation | - | Yes (if mic enabled, word >= 3 chars) | Yes (if mic enabled, word >= 3 chars) |

---

## 4. Session Algorithm

### Question Generation Logic

`_generateQuestionForWord()` selects eligible types based on mastery:

```
masteryLevel == unseen/introduced
  → eligible: [multipleChoice, reverseMultipleChoice, listeningSelect]
  → if isStruggling: adds reverseMultipleChoice (easier reinforcement)

masteryLevel == recognized
  → eligible: [scrambledLetters, wordWheel, (matching if ≥4 words)]
  → if isStruggling: also adds reverseMultipleChoice

masteryLevel == bridged/produced
  → eligible: [spelling, listeningWrite, (sentenceGap if exampleSentence exists)]
  → if none eligible: falls back to [scrambledLetters, wordWheel]
```

### Adaptive Difficulty Triggers

| Condition | Threshold | Effect |
|---|---|---|
| `isPerformingWell` | ≥5 answered AND accuracy > 80% | Recognition questions may be skipped |
| `isStruggling` | ≥4 answered AND accuracy < 50% | More recognition questions, reverseMultipleChoice added to eligible types |

### Remediation Queue

- **Add:** On incorrect answer, `wordId` added to `remediationQueue`
- **Pull:** 40% chance per question generation to pull from queue
- **Question:** Simplified 2-option MC with image support (`isRemediation: true`)
- **Remove:** On correct answer for a remediated word

---

## 5. Mastery Level Progression

### Levels (in-session only)

```
unseen → introduced → recognized → bridged → produced
```

### Promotion Rules

| Current Level | Correct Answer Type | Promotes To |
|---|---|---|
| unseen / introduced | Recognition question | recognized |
| recognized | Bridge question | bridged |
| bridged | Production question | produced |

**Mastery never regresses within a session.** Incorrect answers only:
- Set `needsRemediation = true`
- Increment `incorrectCount`
- Add to `remediationQueue`

### WordSessionState Result Status (for post-session)

| Result | Condition |
|---|---|
| `strong` | `incorrectCount == 0` |
| `medium` | `correctCount > incorrectCount` |
| `weak` | Everything else |

---

## 6. Combo & XP System

### Base XP by Tier

| Tier | Types | Base XP |
|---|---|---|
| Recognition | multipleChoice, reverseMultipleChoice, listeningSelect | 10 |
| Bridge (matching) | matching | 15 |
| Bridge (letters) | scrambledLetters, wordWheel | 20 |
| Production | spelling, listeningWrite | 25 |
| Production (sentence) | sentenceGap | 30 |
| Production (pronunciation) | pronunciation | 30 (25 in fallback) |

### Combo Multiplier

- Correct answer: `combo += 1`
- XP gained: `baseXP * max(1, min(combo, 5))` — capped at x5 multiplier
- First correct (combo=0): gets `baseXP * 1` (no penalty)

### Two-Strike Warning System

| Situation | Result |
|---|---|
| Wrong answer, combo ≥ 2, no warning active | Warning only — combo preserved, `comboWarningActive = true` |
| Wrong answer, warning already active OR combo < 2 | `combo = max(0, combo - 2)`, `lastComboBroken = true` |

### Feedback Display (`VocabQuestionFeedback`)

- **Correct:** Shows `+{xp} XP` with combo badge `COMBO x{n}` if combo ≥ 2
- **Wrong + warning:** "Careful! x{n} combo at risk"
- **Wrong + broken:** "Combo broken! x{n}"
- **Auto-dismiss:** 2200ms on correct | manual "GOT IT" button on incorrect

### Session Bonus (server-side, in RPC)

| Bonus | Amount |
|---|---|
| Session completion | +10 XP always |
| Perfect accuracy (100%) | +20 XP additional |

### XP Anti-Farming (Delta Mechanism)

```sql
v_xp_to_award = GREATEST(0, v_total_xp - v_previous_best)
```

Replaying a completed list only awards XP if you **beat your previous best score**. The summary screen shows `v_xp_to_award` (the delta), not the full session XP.

---

## 7. SM2 Spaced Repetition

### Two Parallel SM2 Implementations

#### Server-Side SM2 (Active — used by session system)

Lives in `complete_vocabulary_session` RPC. Applied per word after each session.

**Strong word (incorrectCount == 0):**
```
If no existing progress:
  INSERT: repetitions=1, interval=1 day, next_review=+1 day

If existing and status != 'mastered':
  repetitions += 1
  rep 1 → interval = 1 day
  rep 2 → interval = 6 days
  rep ≥ 3 → interval = CEIL(current_interval * ease_factor), cap 365 days
  ease_factor = min(ease + 0.02, 3.0)
  status = 'mastered' if interval > 21 days, 'reviewing' if reps ≥ 2, else 'learning'
```

**Weak word (incorrectCount > 0):**
```
UPSERT: repetitions=0, interval=0, next_review=NOW()
ease_factor = max(ease - 0.2, 1.3)
status = 'learning'
```

#### Client-Side SM2 (Legacy — used by daily review flashcards)

Lives in `VocabularyProgress.calculateNextReview(quality)` where quality is 0-5.

```
newEF = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
newEF = max(1.3, newEF)

if quality < 3: repetitions = 0, interval = 1
if quality >= 3:
  rep 1 → interval = 1
  rep 2 → interval = 6
  rep ≥ 3 → interval = round(prev_interval * newEF)

interval = min(interval, 365)
status = 'mastered' if interval > 21
```

> **Note:** Server uses `ease += 0.02` (slow accumulation), client uses standard SM2 formula. These produce different schedules over time.

---

## 8. State Management & Providers

### Primary Provider

```dart
vocabularySessionControllerProvider
  : StateNotifierProvider<VocabularySessionController, VocabularySessionState>
```

- **NOT** `autoDispose` — state must survive navigation from session → summary screen
- `startSession()` fully resets all fields (no cross-session leakage risk)

### VocabularySessionState Fields

| Field | Type | Purpose |
|---|---|---|
| `phase` | `SessionPhase` | Current phase (explore/reinforce/finalPhase) |
| `words` | `List<WordSessionState>` | Per-word state (mastery, counts, remediation) |
| `currentQuestion` | `SessionQuestion?` | Active question (null between questions) |
| `questionIndex` | `int` | Monotonically increasing — used as `ValueKey` for widget rebuild |
| `totalQuestionsAnswered` | `int` | Running total across all phases |
| `combo` / `maxCombo` | `int` | Current and peak combo |
| `xpEarned` | `int` | Cumulative session XP |
| `correctCount` / `incorrectCount` | `int` | Running totals |
| `remediationQueue` | `List<String>` | Word IDs pending retry |
| `introductionPairIndex` | `int` | Current pair index in Explore phase |
| `isShowingIntroduction` | `bool` | True = showing cards, false = showing question |
| `isShowingFeedback` | `bool` | Feedback footer visible |
| `lastAnswerCorrect` | `bool?` | Last answer result for feedback display |
| `lastCorrectAnswer` | `String?` | Correct answer text for wrong-answer feedback |
| `lastXPGained` | `int` | XP for last question |
| `comboWarningActive` | `bool` | First-strike warning active |
| `lastComboBroken` | `bool` | Combo was broken on last answer |
| `isSessionComplete` | `bool` | Triggers navigation to summary |
| `startTime` | `DateTime` | For duration calculation |
| `reinforceQuestionsAsked` | `int` | Phase 2 counter for exit condition |
| `finalQuestionsAsked` | `int` | Phase 3 counter for exit condition |

### Supporting Providers

| Provider | Type | Purpose |
|---|---|---|
| `wordsForListProvider(listId)` | `FutureProvider.family` | Fetches words via `GetWordsForListUseCase` |
| `completeSessionUseCaseProvider` | `Provider` | Wires `CompleteSessionUseCase` → repository |
| `progressForListProvider` | `FutureProvider.family` | Word progress data for a list |
| `userWordListProgressProvider` | `FutureProvider.family` | User's best score / completion for a list |
| `wordListsWithProgressProvider` | `FutureProvider` | All word lists with progress |
| `learningPathProvider` | `FutureProvider` | Learning path nodes with completion |

---

## 9. Data Flow (Supabase → UI)

### Session Start

```
VocabularySessionScreen._loadAndStart()
  → ref.read(wordsForListProvider(listId).future)
    → GetWordsForListUseCase.call(listId)
      → SupabaseWordListRepository.getWordsForList(listId)
        → Supabase: SELECT word_id FROM word_list_items WHERE word_list_id = ? ORDER BY order_index
        → Supabase: SELECT * FROM vocabulary_words WHERE id IN (wordIds)
        → VocabularyWordModel.fromJson(json).toEntity() for each row
        → returns List<VocabularyWord>
  → (optional) filter by retryWordIds
  → controller.startSession(words)
    → VocabularySessionState initialized
    → phase = explore, words → WordSessionState list, startTime = now
```

### Answer Processing

```
User interaction (tap/type/drag)
  → Widget calls controller.answerQuestion(answer) or answerMatchingQuestion()
    → _checkAnswer(): answer.trim().toLowerCase() == correctAnswer.trim().toLowerCase()
    → Updates WordSessionState (mastery, counts, remediation flag)
    → Calculates combo (two-strike system)
    → Calculates xpGained = baseXP * max(1, min(combo, 5))
    → Updates remediationQueue
    → state = state.copyWith(isShowingFeedback: true, ...)

  → Screen detects isShowingFeedback → renders VocabQuestionFeedback
    → Correct: auto-dismiss after 2200ms
    → Wrong: manual "GOT IT" button

  → controller.dismissFeedback()
    → If explore: advanceAfterExploreQuestion()
    → If reinforce/final: _generateNextQuestion()
```

---

## 10. Session Completion & Persistence

```
controller._completeSession()
  → state = state.copyWith(isSessionComplete: true)

VocabularySessionScreen.build() detects isSessionComplete
  → addPostFrameCallback → context.go(sessionSummaryPath(listId))

SessionSummaryScreen.initState() → _saveSession()
  → ref.read(completeSessionUseCaseProvider).call(CompleteSessionParams(
      listId, userId, wordResults, xpEarned, accuracy, durationSeconds))
    → SupabaseWordListRepository.completeSession()
      → Supabase.rpc('complete_vocabulary_session', params: {
          p_user_id, p_word_list_id, p_xp_earned, p_accuracy,
          p_duration_seconds, p_word_results: jsonList })
```

### RPC: `complete_vocabulary_session` Steps

1. Calculate total XP: `p_xp_earned + 10` (+ 20 if 100% accuracy)
2. Fetch previous best: `SELECT best_score FROM user_word_list_progress`
3. Delta: `v_xp_to_award = GREATEST(0, total_xp - previous_best)`
4. INSERT into `vocabulary_sessions`
5. For each word result:
   - INSERT into `vocabulary_session_words`
   - If strong (incorrectCount=0): Update `vocabulary_progress` with SM2 intervals
   - If weak (incorrectCount>0): Reset progress (interval=0, ease_factor -= 0.2)
6. UPSERT `user_word_list_progress` (best_score, best_accuracy, total_sessions++)
7. `award_xp_transaction()` (only if delta > 0)
8. `update_user_streak()`
9. `check_and_award_badges()`
10. RETURN `(session_id, v_xp_to_award)`

### Post-Save Provider Invalidation

```dart
ref.invalidate(progressForListProvider(listId));
ref.invalidate(userWordListProgressProvider(listId));
ref.invalidate(wordListsWithProgressProvider);
ref.invalidate(learningPathProvider);
ref.read(userControllerProvider.notifier).refresh(); // XP/level update
```

---

## 11. Key Files Reference

### Domain Layer

| File | Contains |
|---|---|
| `lib/domain/entities/vocabulary_session.dart` | `SessionPhase`, `QuestionType`, `WordMasteryLevel`, `WordSessionState`, `SessionQuestion`, `VocabularySessionResult`, `SessionWordResult`, XP/tier extensions |
| `lib/domain/entities/vocabulary.dart` | `VocabularyWord`, `VocabularyProgress` (client-side SM2), `VocabularyStatus`, `NodeCompletion` |
| `lib/domain/entities/word_list.dart` | `WordList`, `UserWordListProgress` (star rating, completion) |
| `lib/domain/usecases/wordlist/complete_session_usecase.dart` | Thin use case wrapping `completeSession()` |

### Data Layer

| File | Contains |
|---|---|
| `lib/data/repositories/supabase/supabase_word_list_repository.dart` | `completeSession()` → RPC call, `getWordsForList()` |
| `lib/data/repositories/supabase/supabase_vocabulary_repository.dart` | Word/progress CRUD, daily review, legacy SM2 path |
| `lib/data/models/vocabulary/vocabulary_session_model.dart` | Serialization: `VocabularySessionModel`, `SessionWordResultModel.toRpcJson()` |

### Presentation Layer — Providers

| File | Contains |
|---|---|
| `lib/presentation/providers/vocabulary_session_provider.dart` | `VocabularySessionState`, `VocabularySessionController` — entire session algorithm |
| `lib/presentation/providers/vocabulary_provider.dart` | `wordsForListProvider`, `learningPathProvider`, legacy `VocabularyReviewController` |

### Presentation Layer — Screens

| File | Contains |
|---|---|
| `lib/presentation/screens/vocabulary/vocabulary_session_screen.dart` | Session screen: loads words, dispatches question widgets, feedback footer |
| `lib/presentation/screens/vocabulary/session_summary_screen.dart` | Summary: persists via RPC, invalidates providers, shows results |

### Presentation Layer — Widgets (all in `lib/presentation/widgets/vocabulary/session/`)

| File | Widget | Question Type |
|---|---|---|
| `vocab_word_introduction_card.dart` | `VocabWordIntroductionCard` | Phase 1 flashcard |
| `vocab_multiple_choice_question.dart` | `VocabMultipleChoiceQuestion` | multipleChoice, reverseMultipleChoice |
| `vocab_listening_question.dart` | `VocabListeningQuestion` | listeningSelect, listeningWrite |
| `vocab_matching_question.dart` | `VocabMatchingQuestion` | matching |
| `vocab_scrambled_letters_question.dart` | `VocabScrambledLettersQuestion` | scrambledLetters |
| `vocab_word_wheel_question.dart` | `VocabWordWheelQuestion` | wordWheel |
| `vocab_spelling_question.dart` | `VocabSpellingQuestion` | spelling |
| `vocab_sentence_gap_question.dart` | `VocabSentenceGapQuestion` | sentenceGap |
| `vocab_pronunciation_question.dart` | `VocabPronunciationQuestion` | pronunciation (mic + spelling fallback) |
| `vocab_question_feedback.dart` | `VocabQuestionFeedback` | Feedback overlay (XP, combo states) |

### Database

| File | Contains |
|---|---|
| `supabase/migrations/20260317000001_fix_session_sm2_interval_growth.sql` | `complete_vocabulary_session` RPC (authoritative SM2, XP delta, streak, badges) |

---

## 12. Architecture Observations & Known Quirks

### Design Strengths

1. **Mastery gate enforcement:** Phase 2 word selection strictly prioritizes lower mastery levels. A word cannot receive a bridge question until it passes recognition.

2. **Two-strike combo system:** First wrong answer only warns — reduces frustration while maintaining risk.

3. **Anti-farming XP delta:** `GREATEST(0, session_xp - previous_best)` computed in RPC. Client cannot bypass this.

4. **Widget key strategy:** `questionIndex` (monotonically increasing) used as `ValueKey`, not `SessionQuestion.hashCode`. Since `SessionQuestion` extends `Equatable`, two identical questions would produce the same hash and trick `AnimatedSwitcher` into reusing old widget state with `_answered = true`.

5. **Provider lifecycle:** Intentionally NOT `autoDispose` — state survives `context.go()` navigation to summary. `startSession()` fully resets, preventing cross-session leakage.

### Known Quirks

1. **SM2 divergence:** Server-side (session system) uses `ease += 0.02` per correct session. Client-side (legacy daily review) uses standard SM2 formula. These produce different interval schedules.

2. **Progress bar estimate:** `estimatedTotal = words.length * 2 + 4` — rough, doesn't account for remediation questions or actual phase durations.

3. **`retryWordIds` filter is client-side:** All words for the list are fetched, then filtered in memory. Wastes network for large lists.

4. **`listeningWrite` not in Phase 3:** Final phase uses `[spelling, sentenceGap, scrambledLetters, wordWheel]` — not `listeningWrite`. Intentional to focus on typing/spelling for weak words.

5. **`VocabComboIndicator` widget exists but is unused** in the active session flow. Combo info is shown only inside `VocabQuestionFeedback`.
