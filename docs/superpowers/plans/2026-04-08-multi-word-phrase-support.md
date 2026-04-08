# Multi-Word Phrase Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the vocabulary system handle multi-word phrases (e.g. "take a look!") with phrase-aware exercise routing, a new scrambled-words widget with distractors, punctuation-tolerant answer checking, and fixes to bulk audio generation and AI content generation.

**Architecture:** Phrase detection is automatic (`word.contains(' ')`) with no DB changes. A new `scrambledWords` question type replaces letter-based exercises for phrases. Answer comparison strips punctuation globally. Edge functions get DELIMITER-aware timestamp extraction and updated AI prompts.

**Tech Stack:** Flutter/Dart (mobile app), Deno/TypeScript (Supabase edge functions), Flutter admin panel

**Spec:** `docs/specs/28-multi-word-phrase-support.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `lib/domain/entities/vocabulary_session.dart` | Modify | Add `scrambledWords` enum, `scrambledWordTiles` field |
| `lib/presentation/providers/vocabulary_session_provider.dart` | Modify | Phrase routing, `_buildScrambledWords`, `_normalize` helper |
| `lib/presentation/widgets/vocabulary/session/vocab_scrambled_words_question.dart` | Create | New scrambled words widget |
| `lib/presentation/screens/vocabulary/vocabulary_session_screen.dart` | Modify | Register new question type |
| `supabase/functions/generate-wordlist-audio/index.ts` | Modify | DELIMITER-aware timestamp extraction |
| `supabase/functions/generate-word-data/index.ts` | Modify | Prompt + part_of_speech update |
| `owlio_admin/lib/features/vocabulary/screens/vocabulary_edit_screen.dart` | Modify | Phrase info banner + `phrase` in parts of speech |

---

### Task 1: Add `scrambledWords` enum and model field

**Files:**
- Modify: `lib/domain/entities/vocabulary_session.dart`

- [ ] **Step 1: Add `scrambledWords` to `QuestionType` enum**

In `lib/domain/entities/vocabulary_session.dart`, add the new enum value after `wordWheel`:

```dart
enum QuestionType {
  multipleChoice,        // EN word → pick TR meaning (4 options)
  reverseMultipleChoice, // TR meaning → pick EN word (4 options)
  listeningSelect,       // Audio plays → pick correct word (4 options)
  imageMatch,            // EN word shown → pick correct image (2 options)
  matching,              // Match 4 words ↔ 4 meanings
  scrambledLetters,      // Rearrange shuffled letter buttons
  wordWheel,             // Circular drag-to-connect letter wheel
  scrambledWords,        // Rearrange shuffled word tiles (for phrases)
  spelling,              // TR meaning given → type EN word
  listeningWrite,        // Audio plays → type the word
  sentenceGap,           // Fill the blank in a sentence
  pronunciation,          // Say the word — recall + speak into microphone (production)
}
```

- [ ] **Step 2: Add `scrambledWords` to the tier extension**

In the same file, update `QuestionTypeTier.tier` switch to include the new type in `bridge` tier:

```dart
case QuestionType.matching:
case QuestionType.scrambledLetters:
case QuestionType.wordWheel:
case QuestionType.scrambledWords:
  return QuestionTier.bridge;
```

- [ ] **Step 3: Add `scrambledWordTiles` field to `SessionQuestion`**

In `SessionQuestion`, add the new field alongside `scrambledLetters`:

```dart
class SessionQuestion extends Equatable {
  const SessionQuestion({
    required this.type,
    required this.targetWordId,
    required this.targetWord,
    required this.targetMeaning,
    required this.correctAnswer,
    this.options,
    this.sentence,
    this.audioUrl,
    this.audioStartMs,
    this.audioEndMs,
    this.imageUrl,
    this.matchingPairs,
    this.scrambledLetters,
    this.scrambledWordTiles,
    this.isRemediation = false,
  });

  // ... existing fields ...
  final List<String>? scrambledLetters;    // For scrambled letters
  final List<String>? scrambledWordTiles;  // For scrambled words (phrases)

  final bool isRemediation;

  @override
  List<Object?> get props => [
        type, targetWordId, targetWord, targetMeaning, correctAnswer,
        options, sentence, audioUrl, audioStartMs, audioEndMs, imageUrl, matchingPairs,
        scrambledLetters, scrambledWordTiles, isRemediation,
      ];
}
```

- [ ] **Step 4: Verify no compile errors**

Run: `dart analyze lib/domain/entities/vocabulary_session.dart`

Expected: The `_buildQuestion` switch in `vocabulary_session_provider.dart` will warn about non-exhaustive switch — this is expected and fixed in Task 2.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/vocabulary_session.dart
git commit -m "feat(vocab): add scrambledWords question type and scrambledWordTiles field"
```

---

### Task 2: Phrase-aware question type routing and answer checking

**Files:**
- Modify: `lib/presentation/providers/vocabulary_session_provider.dart`

- [ ] **Step 1: Add `_normalize` helper method**

Add this private method to `VocabularySessionNotifier`, just above `_checkAnswer`:

```dart
String _normalize(String s) {
  return s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
```

- [ ] **Step 2: Update `_checkAnswer` to use `_normalize`**

Replace the existing `_checkAnswer` method:

```dart
bool _checkAnswer(String answer, SessionQuestion question) {
  final normalizedAnswer = _normalize(answer);
  final normalizedCorrect = _normalize(question.correctAnswer);
  return normalizedAnswer == normalizedCorrect;
}
```

- [ ] **Step 3: Update `_generateQuestionForWord` with phrase routing**

Replace the body of `_generateQuestionForWord` (lines 600-638) with phrase-aware version:

```dart
SessionQuestion _generateQuestionForWord(WordSessionState word) {
  final isPhrase = word.word.contains(' ');
  List<QuestionType> eligibleTypes;

  switch (word.masteryLevel) {
    case WordMasteryLevel.unseen:
    case WordMasteryLevel.introduced:
      eligibleTypes = [
        QuestionType.multipleChoice,
        QuestionType.reverseMultipleChoice,
        QuestionType.listeningSelect,
      ];
    case WordMasteryLevel.recognized:
      if (isPhrase) {
        eligibleTypes = [
          QuestionType.scrambledWords,
          if (state.words.length >= 4) QuestionType.matching,
        ];
      } else {
        eligibleTypes = [
          QuestionType.scrambledLetters,
          QuestionType.wordWheel,
          if (state.words.length >= 4) QuestionType.matching,
        ];
      }
      if (state.isStruggling) {
        eligibleTypes.add(QuestionType.reverseMultipleChoice);
      }
    case WordMasteryLevel.bridged:
    case WordMasteryLevel.produced:
      eligibleTypes = [
        QuestionType.spelling,
        QuestionType.listeningWrite,
        if (!isPhrase && !state.micDisabledForSession && word.word.length >= 3)
          QuestionType.pronunciation,
        if (word.exampleSentence != null) QuestionType.sentenceGap,
      ];
      if (eligibleTypes.isEmpty) {
        eligibleTypes = isPhrase
            ? [QuestionType.scrambledWords]
            : [QuestionType.scrambledLetters, QuestionType.wordWheel];
      }
  }

  final type = _pickAvoidingRepeat(eligibleTypes);
  return _buildQuestion(type, word);
}
```

- [ ] **Step 4: Update `_generateFinalQuestion` with phrase routing**

In `_generateFinalQuestion` (around line 710), update the types list:

```dart
void _generateFinalQuestion() {
  final targetFinalQuestions = min(5, state.weakWords.length);
  if (state.finalQuestionsAsked >= targetFinalQuestions) {
    _completeSession();
    return;
  }

  final weak = state.weakWords;
  final word = weak[state.finalQuestionsAsked % weak.length];
  final isPhrase = word.word.contains(' ');

  List<QuestionType> types = [
    QuestionType.spelling,
    if (!isPhrase && !state.micDisabledForSession && word.word.length >= 3)
      QuestionType.pronunciation,
    if (word.exampleSentence != null) QuestionType.sentenceGap,
    if (isPhrase)
      QuestionType.scrambledWords
    else ...[
      QuestionType.scrambledLetters,
      QuestionType.wordWheel,
    ],
  ];

  final type = _pickAvoidingRepeat(types);
  final question = _buildQuestion(type, word);

  state = state.copyWith(
    currentQuestion: question,
    questionIndex: state.questionIndex + 1,
    finalQuestionsAsked: state.finalQuestionsAsked + 1,
  );
}
```

- [ ] **Step 5: Add `_buildScrambledWords` method**

Add this method after the existing `_buildScrambledLetters` method:

```dart
static const _distractorFallbackPool = [
  'the', 'is', 'very', 'not', 'can', 'do', 'go', 'my', 'it', 'has',
  'was', 'but', 'or', 'an', 'up', 'out', 'so', 'no', 'if', 'at',
];

SessionQuestion _buildScrambledWords(WordSessionState word) {
  final phraseWords = word.word.split(' ');
  final distractorCount = max(2, phraseWords.length - 1);

  // Normalize phrase words for dedup comparison
  final phraseWordsNormalized = phraseWords
      .map((w) => _normalize(w))
      .toSet();

  // Source 1: single-word session entries
  final sessionDistractors = state.words
      .where((w) => !w.word.contains(' ') && w.wordId != word.wordId)
      .where((w) => !phraseWordsNormalized.contains(_normalize(w.word)))
      .map((w) => w.word)
      .toList()
    ..shuffle(_random);

  // Source 2: fallback pool
  final fallbackDistractors = _distractorFallbackPool
      .where((w) => !phraseWordsNormalized.contains(w))
      .toList()
    ..shuffle(_random);

  // Combine: session first, fallback fills remaining
  final distractors = <String>[];
  for (final d in sessionDistractors) {
    if (distractors.length >= distractorCount) break;
    distractors.add(d);
  }
  for (final d in fallbackDistractors) {
    if (distractors.length >= distractorCount) break;
    if (!distractors.contains(d)) distractors.add(d);
  }

  // Combine phrase words + distractors and shuffle
  final allTiles = [...phraseWords, ...distractors];

  // Ensure shuffled order differs from correct order
  int attempts = 0;
  do {
    allTiles.shuffle(_random);
    attempts++;
  } while (_tilesMatchPhrase(allTiles, phraseWords) && attempts < 20);

  return SessionQuestion(
    type: QuestionType.scrambledWords,
    targetWordId: word.wordId,
    targetWord: word.word,
    targetMeaning: word.meaningTR,
    correctAnswer: word.word,
    scrambledWordTiles: allTiles,
    imageUrl: word.imageUrl,
  );
}

bool _tilesMatchPhrase(List<String> tiles, List<String> phraseWords) {
  if (tiles.length != phraseWords.length) return false;
  for (int i = 0; i < phraseWords.length; i++) {
    if (tiles[i] != phraseWords[i]) return false;
  }
  return true;
}
```

- [ ] **Step 6: Wire `scrambledWords` into `_buildQuestion` switch**

Update the switch in `_buildQuestion`:

```dart
case QuestionType.scrambledLetters:
case QuestionType.wordWheel:
  return _buildScrambledLetters(word, type: type);
case QuestionType.scrambledWords:
  return _buildScrambledWords(word);
```

- [ ] **Step 7: Verify compile**

Run: `dart analyze lib/presentation/providers/vocabulary_session_provider.dart`

Expected: Warning about unhandled `scrambledWords` case in `vocabulary_session_screen.dart` switch — fixed in Task 4.

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/providers/vocabulary_session_provider.dart
git commit -m "feat(vocab): phrase-aware question routing, scrambled words builder, tolerant answer checking"
```

---

### Task 3: Create `VocabScrambledWordsQuestion` widget

**Files:**
- Create: `lib/presentation/widgets/vocabulary/session/vocab_scrambled_words_question.dart`

- [ ] **Step 1: Create the widget file**

Create `lib/presentation/widgets/vocabulary/session/vocab_scrambled_words_question.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';
import '../../../../core/services/letter_tap_sound_service.dart';
import '../../../../domain/entities/vocabulary_session.dart';
import 'vocab_question_container.dart';
import 'vocab_question_image.dart';

/// Scrambled words: tap word tiles in correct order to form the phrase.
/// Includes distractor tiles that don't belong to the phrase.
class VocabScrambledWordsQuestion extends StatefulWidget {
  const VocabScrambledWordsQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  final SessionQuestion question;
  final void Function(String answer) onAnswer;

  @override
  State<VocabScrambledWordsQuestion> createState() =>
      _VocabScrambledWordsQuestionState();
}

class _VocabScrambledWordsQuestionState
    extends State<VocabScrambledWordsQuestion> {
  final List<int> _selectedIndices = [];
  bool _answered = false;
  final _tapSound = LetterTapSoundService();

  List<String> get tiles => widget.question.scrambledWordTiles ?? [];

  /// Number of answer slots = number of words in the phrase (not including distractors).
  int get phraseWordCount => widget.question.correctAnswer.split(' ').length;

  @override
  void dispose() {
    _tapSound.dispose();
    super.dispose();
  }

  void _tapTile(int index) {
    if (_answered || _selectedIndices.contains(index)) return;
    if (_selectedIndices.length >= phraseWordCount) return;

    setState(() {
      _selectedIndices.add(index);
    });

    HapticFeedback.selectionClick();
    _tapSound.playTap(_selectedIndices.length - 1);

    // Auto-submit when all phrase slots are filled
    if (_selectedIndices.length == phraseWordCount) {
      _submit();
    }
  }

  void _removeTile(int selectionIndex) {
    if (_answered) return;
    if (selectionIndex >= _selectedIndices.length) return;

    setState(() {
      _selectedIndices.removeAt(selectionIndex);
    });
    HapticFeedback.lightImpact();
  }

  void _submit() {
    if (_answered) return;
    setState(() => _answered = true);
    final answer = _selectedIndices.map((i) => tiles[i]).join(' ');
    widget.onAnswer(answer);
  }

  /// Capitalize first letter of first and last word for display.
  String _displayWord(String word, int indexInPhrase) {
    if (word.isEmpty) return word;
    final phraseWords = widget.question.correctAnswer.split(' ');
    // Capitalize first and last word of the phrase for nicer display
    if (indexInPhrase == 0 || indexInPhrase == phraseWords.length - 1) {
      return word[0].toUpperCase() + word.substring(1);
    }
    return word;
  }

  Widget _buildQuestionCard(ThemeData theme, bool isWide) {
    return VocabQuestionContainer(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          VocabQuestionImage(
            imageUrl: widget.question.imageUrl,
            size: isWide ? 180 : 140,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color:
                  theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.question.targetMeaning,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.tertiary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordArea(ThemeData theme) {
    // Determine correctness for visual feedback
    _SlotStatus slotStatus = _SlotStatus.neutral;
    if (_answered) {
      final answer = _selectedIndices.map((i) => tiles[i]).join(' ');
      final normalizedAnswer = _normalizeForCompare(answer);
      final normalizedCorrect =
          _normalizeForCompare(widget.question.correctAnswer);
      slotStatus = normalizedAnswer == normalizedCorrect
          ? _SlotStatus.correct
          : _SlotStatus.incorrect;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Answer Slots (only phraseWordCount slots)
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 12,
          children: List.generate(phraseWordCount, (index) {
            final isFilled = index < _selectedIndices.length;
            final word = isFilled ? tiles[_selectedIndices[index]] : '';

            return GestureDetector(
              onTap: isFilled ? () => _removeTile(index) : null,
              child: _WordSlot(
                word: isFilled ? _displayWord(word, index) : '',
                isFilled: isFilled,
                status: _answered ? slotStatus : _SlotStatus.neutral,
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        // Word Tile Pool (all tiles including distractors)
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: List.generate(tiles.length, (i) {
            final isUsed = _selectedIndices.contains(i);
            return _WordTile(
              word: tiles[i],
              isUsed: isUsed,
              onTap: () => _tapTile(i),
            );
          }),
        ),
      ],
    );
  }

  static String _normalizeForCompare(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    if (isWide) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Arrange words to form the phrase',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralText,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _buildQuestionCard(theme, true)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildWordArea(theme)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    // Mobile
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Arrange words to form the phrase',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          _buildQuestionCard(theme, false),
          const SizedBox(height: 32),
          _buildWordArea(theme),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

enum _SlotStatus { neutral, correct, incorrect }

/// Answer slot for a word — similar to _LetterSlot but with dynamic width.
class _WordSlot extends StatelessWidget {
  const _WordSlot({
    required this.word,
    required this.isFilled,
    required this.status,
  });

  final String word;
  final bool isFilled;
  final _SlotStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color borderColor = theme.colorScheme.outline.withValues(alpha: 0.3);
    Color bgColor =
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    Color textColor = theme.colorScheme.onSurface;

    if (status == _SlotStatus.correct) {
      borderColor = Colors.green;
      bgColor = Colors.green.withValues(alpha: 0.2);
      textColor = Colors.green.shade800;
    } else if (status == _SlotStatus.incorrect) {
      borderColor = Colors.red;
      bgColor = Colors.red.withValues(alpha: 0.2);
      textColor = Colors.red.shade800;
    } else if (isFilled) {
      borderColor = theme.colorScheme.primary;
      bgColor = theme.colorScheme.surface;
      textColor = theme.colorScheme.onSurface;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      constraints: const BoxConstraints(minWidth: 56),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: isFilled || status != _SlotStatus.neutral ? 2 : 1,
        ),
        boxShadow: isFilled
            ? [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                )
              ]
            : [],
      ),
      child: isFilled
          ? Text(
              word,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack)
          : Container(
              width: 24,
              height: 2,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
    );
  }
}

/// Tappable word tile in the pool — similar to _LetterTile but with dynamic width.
class _WordTile extends StatelessWidget {
  const _WordTile({
    required this.word,
    required this.isUsed,
    required this.onTap,
  });

  final String word;
  final bool isUsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isUsed ? 0.0 : 1.0,
      child: IgnorePointer(
        ignoring: isUsed,
        child: Material(
          color: theme.colorScheme.surface,
          elevation: 2,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minWidth: 56),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.1),
                    offset: const Offset(0, 4),
                    blurRadius: 4,
                  )
                ],
              ),
              child: Text(
                word,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify compile**

Run: `dart analyze lib/presentation/widgets/vocabulary/session/vocab_scrambled_words_question.dart`

Expected: PASS (no errors)

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/vocabulary/session/vocab_scrambled_words_question.dart
git commit -m "feat(vocab): add VocabScrambledWordsQuestion widget for phrase exercises"
```

---

### Task 4: Register widget in session screen

**Files:**
- Modify: `lib/presentation/screens/vocabulary/vocabulary_session_screen.dart`

- [ ] **Step 1: Add import**

Add this import at the top of the file, after the existing scrambled letters import (line 23):

```dart
import '../../widgets/vocabulary/session/vocab_scrambled_words_question.dart';
```

- [ ] **Step 2: Add case to the question type switch**

In the `_buildQuestionWidget` method (around line 583), add the new case after the `wordWheel` case (after line 642):

```dart
      case QuestionType.scrambledWords:
        return VocabScrambledWordsQuestion(
          key: key,
          question: question,
          onAnswer: (ans) => _handleAnswer(controller, ans),
        );
```

- [ ] **Step 3: Verify full app compiles**

Run: `dart analyze lib/`

Expected: PASS (no errors). All switch statements on `QuestionType` are now exhaustive.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/screens/vocabulary/vocabulary_session_screen.dart
git commit -m "feat(vocab): register scrambledWords widget in session screen"
```

---

### Task 5: Fix `generate-wordlist-audio` edge function

**Files:**
- Modify: `supabase/functions/generate-wordlist-audio/index.ts`

- [ ] **Step 1: Replace `extractWordSegments` with DELIMITER-aware version**

Replace the entire `extractWordSegments` function (lines 238-270) with:

```typescript
function extractEntrySegments(
  timestamps: TimestampData,
  words: WordItem[],
  delimiter: string
): { word: string; startMs: number; endMs: number }[] {
  const chars = timestamps.characters;
  const starts = timestamps.character_start_times_seconds;
  const ends = timestamps.character_end_times_seconds;

  // Reconstruct the combined text to find entry boundaries
  const combinedText = words.map(w => w.word).join(delimiter);

  const segments: { word: string; startMs: number; endMs: number }[] = [];
  let charOffset = 0;

  for (let i = 0; i < words.length; i++) {
    const entryText = words[i].word;
    const entryStart = charOffset;
    const entryEnd = charOffset + entryText.length;

    // Find first and last non-silent character timestamps within this entry range
    let startMs = 0;
    let endMs = 0;
    let foundStart = false;

    for (let ci = entryStart; ci < entryEnd && ci < chars.length; ci++) {
      if (starts[ci] !== undefined && ends[ci] !== undefined) {
        if (!foundStart) {
          startMs = Math.floor(starts[ci] * 1000);
          foundStart = true;
        }
        endMs = Math.floor(ends[ci] * 1000);
      }
    }

    segments.push({
      word: entryText,
      startMs,
      endMs,
    });

    // Advance past this entry + delimiter
    charOffset = entryEnd + delimiter.length;
  }

  return segments;
}
```

- [ ] **Step 2: Update the call site**

Replace the call to `extractWordSegments` (around line 172-174):

Old:
```typescript
const wordSegments = mergedTimestamps
  ? extractWordSegments(mergedTimestamps)
  : [];
```

New:
```typescript
const wordSegments = mergedTimestamps
  ? extractEntrySegments(mergedTimestamps, words, DELIMITER)
  : [];
```

- [ ] **Step 3: Verify the function locally**

Run: `cd supabase/functions/generate-wordlist-audio && deno check index.ts`

Expected: PASS (no type errors). If `deno` is not installed locally, verify by reading the file for consistency — the function will be tested on deployment.

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/generate-wordlist-audio/index.ts
git commit -m "fix(audio): DELIMITER-aware timestamp extraction for multi-word phrases"
```

---

### Task 6: Update `generate-word-data` edge function

**Files:**
- Modify: `supabase/functions/generate-word-data/index.ts`

- [ ] **Step 1: Update the Gemini prompt**

In `supabase/functions/generate-word-data/index.ts`, update the prompt string (around line 52). Make these changes:

Change line 52:
```
Given the English word "${word}", provide the following data in JSON format:
```
to:
```
Given the English word or phrase "${word}", provide the following data in JSON format:
```

Change the `part_of_speech` line in the JSON template:
```
  "part_of_speech": "one of: noun, verb, adjective, adverb, pronoun, preposition, conjunction, interjection, article, determiner, phrase",
```

Add this rule to the Rules section:
```
- If the input contains spaces (it's a phrase), set part_of_speech to "phrase"
```

- [ ] **Step 2: Commit**

```bash
git add supabase/functions/generate-word-data/index.ts
git commit -m "feat(ai): update generate-word-data prompt for phrase support"
```

---

### Task 7: Admin panel — phrase info banner and part of speech update

**Files:**
- Modify: `owlio_admin/lib/features/vocabulary/screens/vocabulary_edit_screen.dart`

- [ ] **Step 1: Add `phrase` to `_partsOfSpeech` list**

Update the static list (line 42):

```dart
static const _partsOfSpeech = [
  'noun',
  'verb',
  'adjective',
  'adverb',
  'pronoun',
  'preposition',
  'conjunction',
  'interjection',
  'article',
  'determiner',
  'phrase',
];
```

- [ ] **Step 2: Add `_isPhrase` state variable and listener**

Add a state variable after `_source` (line 66):

```dart
String _source = 'manual';
bool _isPhrase = false;
```

In `initState`, add a listener for the word controller. After the existing `if (!isNewWord)` block (around line 75):

```dart
@override
void initState() {
  super.initState();
  _wordController.addListener(_checkPhrase);
  if (!isNewWord) {
    _loadWord();
  }
}

void _checkPhrase() {
  final isPhrase = _wordController.text.trim().contains(' ');
  if (isPhrase != _isPhrase) {
    setState(() => _isPhrase = isPhrase);
  }
}
```

Update `dispose` to remove the listener:

```dart
@override
void dispose() {
  _wordController.removeListener(_checkPhrase);
  _wordController.dispose();
  _phoneticController.dispose();
  _meaningTrController.dispose();
  _meaningEnController.dispose();
  _audioUrlController.dispose();
  _imageUrlController.dispose();
  _audioPlayer.dispose();
  super.dispose();
}
```

- [ ] **Step 3: Add info banner in the build method**

After the word `TextFormField` (after line 454, right after the `Row` containing the word input and part of speech dropdown), add the phrase info banner:

```dart
if (_isPhrase) ...[
  const SizedBox(height: 8),
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.blue.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: Colors.blue.withValues(alpha: 0.2),
      ),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline, size: 16, color: Colors.blue),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Bu bir phrase olarak algılanacak. Harf karıştırma yerine '
            'kelime karıştırma egzersizi uygulanır.',
            style: TextStyle(fontSize: 13, color: Colors.blue),
          ),
        ),
      ],
    ),
  ),
],
```

- [ ] **Step 4: Verify compile**

Run: `dart analyze owlio_admin/lib/features/vocabulary/screens/vocabulary_edit_screen.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add owlio_admin/lib/features/vocabulary/screens/vocabulary_edit_screen.dart
git commit -m "feat(admin): phrase info banner and 'phrase' part of speech in vocab editor"
```

---

### Task 8: Final verification

- [ ] **Step 1: Full app analysis**

Run: `dart analyze lib/`

Expected: No errors.

- [ ] **Step 2: Full admin analysis**

Run: `dart analyze owlio_admin/lib/`

Expected: No errors.

- [ ] **Step 3: Run tests**

Run: `flutter test`

Expected: All existing tests pass. No regressions.

- [ ] **Step 4: Manual verification checklist**

Test with a phrase like "take a look!" in the vocabulary system:

1. Add "take a look!" via admin panel → info banner appears
2. Set part of speech to "phrase" → saves correctly
3. Start vocabulary session with the phrase in a word list:
   - `unseen/introduced` level → multipleChoice/reverseMultipleChoice (phrase shown as text, works)
   - `recognized` level → scrambledWords (word tiles + distractors, reorder correctly)
   - `bridged/produced` level → spelling (type "take a look" without punctuation → accepted)
   - No pronunciation question offered for the phrase
4. Single words in the same session → all exercises work as before (no regression)

- [ ] **Step 5: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix(vocab): address any issues found during verification"
```
