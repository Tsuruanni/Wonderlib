# 28 — Multi-Word Phrase Support

## Overview

The vocabulary system is currently designed around single words. Adding a multi-word phrase like "take a look!" causes broken exercises (scrambled letters renders space characters as tiles), failed pronunciation checks (STT never returns punctuation), and audio timestamp misalignment in bulk generation. This spec adds first-class phrase support across the vocabulary pipeline.

## Scope

- Vocabulary session exercise engine (question type routing, new widget, answer checking)
- Edge functions: `generate-wordlist-audio`, `generate-word-data`
- Admin panel: vocabulary edit screen (info banner)

**Out of scope:** Database schema changes, shared package changes, new tables, new RPC functions.

---

## 1. Phrase Detection

Phrases are detected automatically at runtime:

```dart
final isPhrase = word.word.contains(' ');
```

No database flag, no admin toggle. A vocabulary entry with spaces is a phrase. This is checked in `vocabulary_session_provider.dart` wherever question type selection or building occurs.

**Rationale:** English has no single words containing spaces. False positives are impossible. Zero admin overhead.

---

## 2. Question Type Routing

`_generateQuestionForWord` in `vocabulary_session_provider.dart` applies phrase-aware filtering to the eligible question type list.

### Routing Table

| Mastery Level | Single Word (unchanged) | Phrase |
|---------------|------------------------|--------|
| `unseen` / `introduced` | multipleChoice, reverseMultipleChoice, listeningSelect | **Same** — no change |
| `recognized` | scrambledLetters, wordWheel, matching | **scrambledWords**, matching |
| `bridged` / `produced` | spelling, listeningWrite, pronunciation, sentenceGap | spelling, listeningWrite, sentenceGap — **pronunciation excluded** |
| Fallback (empty list) | scrambledLetters, wordWheel | **scrambledWords** |

### Excluded Types for Phrases

| Type | Reason |
|------|--------|
| `scrambledLetters` | `split('')` renders spaces/punctuation as letter tiles |
| `wordWheel` | Fixed 110px circle radius cannot scale; same `split('')` issue |
| `pronunciation` | STT never returns punctuation → exact match always fails; child STT accuracy drops further with multi-word input |

---

## 3. New Exercise: Scrambled Words

A new question type and widget for phrase-level word reordering with distractors.

### 3.1 Enum & Model

Add `QuestionType.scrambledWords` to the question type enum.

Add `scrambledWordTiles: List<String>?` field to `SessionQuestion` (parallel to existing `scrambledLetters: List<String>?`).

### 3.2 Question Building

New method `_buildScrambledWords(WordSessionState word)` in `vocabulary_session_provider.dart`:

1. **Split phrase into words:** `word.word.split(' ')` → `["take", "a", "look!"]` (DB stores lowercase). For display, the first letter of the first and last word is capitalized: `["Take", "a", "Look!"]`
2. **Select distractors:**
   - Source 1: Other single-word vocabulary entries from the current session (`state.words.where((w) => !w.word.contains(' ') && w.wordId != word.wordId)`)
   - Source 2: Fallback pool of common English words (hard-coded): `["the", "is", "very", "not", "can", "do", "go", "my", "it", "has", "was", "but", "or", "an", "up", "out", "so", "no", "if", "at"]`
   - Count: `max(2, phraseWordCount - 1)` distractors
   - Priority: session words first, fallback pool fills remaining
   - Deduplication: distractor must not already be a word in the phrase (case-insensitive, punctuation-stripped comparison)
3. **Combine and shuffle:** phrase words + distractors → shuffled list
4. **Ensure shuffled order differs from correct order** (same retry logic as existing scrambledLetters)

### 3.3 Widget: `VocabScrambledWordsQuestion`

New file: `lib/presentation/widgets/vocabulary/session/vocab_scrambled_words_question.dart`

**Layout:**
- Top: meaning (Turkish) + optional image + audio play button
- Middle: answer slots (Wrap, horizontal) — empty slots for phrase word count only (not distractors)
- Bottom: word tile pool (Wrap, horizontal) — all tiles (phrase words + distractors), shuffled

**Tile design:**
- Similar to existing `_LetterTile` but with dynamic width based on text length
- Display: original form preserved (punctuation included, original casing from split)
- Tap to select → tile moves to next empty answer slot
- Tap answer slot to deselect → tile returns to pool

**Answer checking:**
- Student fills all answer slots → auto-submit
- Correct answer: phrase words in original order
- Comparison: punctuation-stripped, case-insensitive (per Section 4)
- Distractor tiles in answer slots → always incorrect

**Visual feedback:**
- Correct: green flash on all slots (same as existing scrambledLetters)
- Incorrect: red flash, tiles return to pool, attempt counted

### 3.4 Integration

- Register widget in the session screen's question type switch/map
- `wordWheel` variant is **not** created for phrases — `scrambledWords` alone provides sufficient exercise variety at the `recognized` mastery level alongside `matching`

---

## 4. Punctuation-Tolerant Answer Checking

Update `_checkAnswer` in `vocabulary_session_provider.dart`:

### Current

```dart
bool _checkAnswer(String answer, SessionQuestion question) {
  final normalizedAnswer = answer.trim().toLowerCase();
  final normalizedCorrect = question.correctAnswer.trim().toLowerCase();
  return normalizedAnswer == normalizedCorrect;
}
```

### New

```dart
bool _checkAnswer(String answer, SessionQuestion question) {
  final normalizedAnswer = _normalize(answer);
  final normalizedCorrect = _normalize(question.correctAnswer);
  return normalizedAnswer == normalizedCorrect;
}

String _normalize(String s) {
  return s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
```

**Behavior:**
- Strips all punctuation (keeps letters, digits, spaces)
- Collapses multiple spaces into one
- `unicode: true` preserves Turkish characters (ş, ç, ğ, ı, ö, ü)
- "take a look!" → "take a look" = "take a look" ✓
- "snow" → "snow" (no change for single words)

**Affected question types:** spelling, listeningWrite, sentenceGap, scrambledWords answer validation.

---

## 5. Edge Function: `generate-wordlist-audio`

### Problem

`extractWordSegments` (line 238) splits on character-level word boundaries using regex `/[a-zA-ZÀ-ÿ'\-]/`. For "take a look", this produces 3 segments (`take`, `a`, `look`) instead of 1. Since segments are matched to vocabulary entries by array index (line 180-188), all subsequent entries get wrong timestamps.

### Fix

Replace character-level word segmentation with **DELIMITER-aware segmentation**:

```
Combined text: "snow... take a look... happy"
DELIMITER: "... "
```

**New algorithm:**

1. Find DELIMITER positions in the combined text
2. Map each vocabulary entry to a character range between delimiters
3. For each entry range, find the first and last non-silent character timestamps
4. Return one segment per vocabulary entry (not per spoken word)

**Result:** "take a look" → single segment with startMs at 't' and endMs at 'k', regardless of internal spaces.

The existing `extractWordSegments` function is replaced. No new function needed.

---

## 6. Edge Function: `generate-word-data`

### Prompt Update

Current prompt excerpt:
```
Given the English word "${word}", provide the following data...
```

Updated:
```
Given the English word or phrase "${word}", provide the following data...
```

### Part of Speech

Add `"phrase"` to the accepted values list in the prompt:

```
"part_of_speech": "one of: noun, verb, adjective, adverb, pronoun, preposition, conjunction, interjection, article, determiner, phrase"
```

Add rule:
```
- If the input contains spaces, set part_of_speech to "phrase"
```

### No Other Changes

- `meaning_tr`, `meaning_en`, `example_sentences`, `phonetic` generation all work correctly for phrases without modification
- Gemini handles multi-word input naturally

---

## 7. Admin Panel: Info Banner

### Vocabulary Edit Screen

In `vocabulary_edit_screen.dart`, add a listener to `_wordController`:

- When `_wordController.text.trim().contains(' ')` → show info banner below the word input field
- Banner: `Container` with info icon + text: *"Bu bir phrase olarak algılanacak. Harf karıştırma yerine kelime karıştırma egzersizi uygulanır."*
- Style: light blue background, info icon, body text
- Non-blocking — purely informational

### No Validation Changes

- No character restrictions added
- No rejection of spaces or punctuation
- CSV import unchanged — phrases flow through identically

---

## 8. Files Changed

| File | Change |
|------|--------|
| `lib/domain/entities/vocabulary_session.dart` | Add `QuestionType.scrambledWords`, add `scrambledWordTiles` field to `SessionQuestion` |
| `lib/presentation/providers/vocabulary_session_provider.dart` | Phrase detection in `_generateQuestionForWord`, new `_buildScrambledWords` method, updated `_checkAnswer` with `_normalize` helper, distractor selection logic |
| `lib/presentation/widgets/vocabulary/session/vocab_scrambled_words_question.dart` | **New file** — scrambled words widget |
| `lib/presentation/screens/vocabulary/vocabulary_session_screen.dart` | Register `scrambledWords` in question type widget map |
| `supabase/functions/generate-wordlist-audio/index.ts` | Replace `extractWordSegments` with DELIMITER-aware segmentation |
| `supabase/functions/generate-word-data/index.ts` | Update prompt for phrase support, add `phrase` to part_of_speech |
| `owlio_admin/lib/features/vocabulary/screens/vocabulary_edit_screen.dart` | Add phrase info banner with controller listener |

---

## 9. What Does NOT Change

- **Database schema** — `VARCHAR(100)` already supports phrases, no migration needed
- **Shared package** — no enum or constant changes
- **Daily review** — flashcard-only UI, displays text, no character operations
- **Inline activities** — `find_words` is chip-selection, not character-grid
- **CSV import** — no validation changes, phrases import normally
- **Existing single-word behavior** — all changes are gated behind `isPhrase` check; single words follow identical code paths as before
- **matching, multipleChoice, reverseMultipleChoice, listeningSelect, listeningWrite, sentenceGap** — these types work with phrases without modification (text display only or already use tolerant comparison after this spec)

---

## 10. Test Scenarios

### Session Provider

| Test | Input | Expected |
|------|-------|----------|
| Phrase detection | `"take a look!"` | `isPhrase = true` |
| Single word detection | `"snow"` | `isPhrase = false` |
| Recognized phrase → eligible types | `"take a look!"`, mastery=recognized | `[scrambledWords, matching]` |
| Recognized word → eligible types | `"snow"`, mastery=recognized | `[scrambledLetters, wordWheel, matching]` |
| Produced phrase → no pronunciation | `"take a look!"`, mastery=produced | pronunciation not in eligible list |
| Produced word → has pronunciation | `"snow"`, mastery=produced | pronunciation in eligible list |

### Answer Checking

| Test | Student Answer | Correct Answer | Expected |
|------|---------------|----------------|----------|
| Exact match | `"take a look"` | `"take a look!"` | ✓ correct |
| With punctuation | `"take a look!"` | `"take a look!"` | ✓ correct |
| Wrong order | `"a take look"` | `"take a look!"` | ✗ incorrect |
| Extra spaces | `"take  a  look"` | `"take a look!"` | ✓ correct |
| Single word unchanged | `"snow"` | `"snow"` | ✓ correct |

### Scrambled Words Builder

| Test | Input | Expected |
|------|-------|----------|
| Word split | `"take a look!"` | `["Take", "a", "Look!"]` |
| Distractor count (3-word phrase) | phrase=3 words | `max(2, 3-1) = 2` distractors |
| Distractor count (2-word phrase) | phrase=2 words | `max(2, 2-1) = 2` distractors |
| Total tiles | 3-word phrase | 3 + 2 = 5 tiles |
| No duplicate distractors | session has "a" as vocab word | "a" excluded if already in phrase |
| Fallback pool used | session has 0 other words | 2 distractors from fallback pool |

### Audio Timestamp Extraction

| Test | Combined Text | Expected Segments |
|------|--------------|-------------------|
| All single words | `"snow... happy... run"` | 3 segments, one per word |
| Phrase in middle | `"snow... take a look... happy"` | 3 segments: `snow`, `take a look`, `happy` |
| All phrases | `"take a look... give up"` | 2 segments |
| Trailing delimiter | `"snow... "` | 1 segment |
