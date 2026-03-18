# Pronunciation Question Type — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a pronunciation question type to vocabulary sessions where students say the English word aloud, with automatic spelling fallback when mic is unavailable.

**Architecture:** New `pronunciation` enum value in production tier (30 XP). `VocabPronunciationQuestion` widget handles both mic mode and spelling fallback internally. Provider tracks `micDisabledForSession` flag to exclude pronunciation from future questions when mic is disabled. Device STT (`speech_to_text` package) evaluates pronunciation on-device with no API costs.

**Tech Stack:** Flutter, `speech_to_text` package (on-device STT), `flutter_tts` (TTS feedback), Riverpod state management

**Spec:** `docs/superpowers/specs/2026-03-17-pronunciation-question-type-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `pubspec.yaml` | MODIFY | Add `speech_to_text` dependency |
| `android/app/src/main/AndroidManifest.xml` | MODIFY | Add RECORD_AUDIO permission + queries |
| `ios/Runner/Info.plist` | MODIFY | Add microphone + speech recognition descriptions |
| `lib/domain/entities/vocabulary_session.dart` | MODIFY | Add `pronunciation` to enum, XP, tier |
| `lib/presentation/providers/vocabulary_session_provider.dart` | MODIFY | Add `micDisabledForSession` field, builder, eligible lists, XP fallback |
| `lib/presentation/widgets/vocabulary/session/vocab_pronunciation_question.dart` | CREATE | New widget — mic mode + spelling fallback |
| `lib/presentation/screens/vocabulary/vocabulary_session_screen.dart` | MODIFY | Add switch/case dispatch for pronunciation |
| `lib/presentation/widgets/vocabulary/session/vocab_question_feedback.dart` | MODIFY | Add TTS on wrong pronunciation answer |
| `docs/vocabulary-session-system.md` | MODIFY | Update documentation with pronunciation |

---

### Task 1: Add `speech_to_text` dependency and platform permissions

**Files:**
- Modify: `pubspec.yaml:42` (after `flutter_tts`)
- Modify: `android/app/src/main/AndroidManifest.xml` (inside `<manifest>`, before `<application>`)
- Modify: `ios/Runner/Info.plist` (inside `<dict>`)

- [ ] **Step 1: Add speech_to_text to pubspec.yaml**

In `pubspec.yaml`, after line 42 (`flutter_tts: ^4.0.2`), add:

```yaml
  speech_to_text: ^7.0.0  # For pronunciation question type
```

- [ ] **Step 2: Add Android permissions**

In `android/app/src/main/AndroidManifest.xml`:

1. Inside `<manifest>` but before `<application>` (line 1-2), add the permission:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

2. Inside the **existing** `<queries>` block (lines 39-44), add a new `<intent>` alongside the existing one:

```xml
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
        <intent>
            <action android:name="android.speech.RecognitionService" />
        </intent>
    </queries>
```

- [ ] **Step 3: Add iOS permission descriptions**

In `ios/Runner/Info.plist`, inside the `<dict>` block before closing `</dict>`, add:

```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>Owlio needs speech recognition to check your pronunciation</string>
<key>NSMicrophoneUsageDescription</key>
<string>Owlio needs microphone access for pronunciation exercises</string>
```

- [ ] **Step 4: Run flutter pub get**

Run: `flutter pub get`
Expected: Dependencies resolve successfully, no errors.

- [ ] **Step 5: Verify build**

Run: `dart analyze lib/`
Expected: No new errors (existing warnings OK).

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "feat: add speech_to_text dependency and platform permissions for pronunciation"
```

---

### Task 2: Add `pronunciation` to QuestionType enum, XP, and tier

**Files:**
- Modify: `lib/domain/entities/vocabulary_session.dart:8-61`

- [ ] **Step 1: Add `pronunciation` to QuestionType enum**

In `lib/domain/entities/vocabulary_session.dart`, at line 17 (after `sentenceGap,`), add:

```dart
  pronunciation,          // Say the word into microphone (production)
```

- [ ] **Step 2: Add pronunciation XP in QuestionTypeXP extension**

In the `baseXP` getter switch (lines 21-40), add before the closing `}`:

```dart
      case QuestionType.pronunciation:
        return 30;
```

- [ ] **Step 3: Add pronunciation tier in QuestionTypeTier extension**

In the `tier` getter switch (lines 43-61), add `QuestionType.pronunciation` to the production tier case:

```dart
      case QuestionType.spelling:
      case QuestionType.listeningWrite:
      case QuestionType.sentenceGap:
      case QuestionType.pronunciation:
        return QuestionTier.production;
```

- [ ] **Step 4: Verify build**

Run: `dart analyze lib/`
Expected: Will show errors for exhaustive switch statements missing `pronunciation` case in `_buildQuestion`, session screen dispatch, etc. This is expected — we'll fix those in subsequent tasks.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/vocabulary_session.dart
git commit -m "feat: add pronunciation to QuestionType enum with 30 XP production tier"
```

---

### Task 3: Add `micDisabledForSession` state and provider logic

**Files:**
- Modify: `lib/presentation/providers/vocabulary_session_provider.dart:12-61` (state class), `103-155` (copyWith), `168-189` (startSession), `302-307` (XP calc), `536-573` (question gen), `616-643` (final gen), `653-673` (build switch), `789-797` (reference for new builder)

- [ ] **Step 1: Add `micDisabledForSession` field to VocabularySessionState**

At line 35 (after `final int finalQuestionsAsked;`), add:

```dart
  final bool micDisabledForSession;
```

In the constructor (line 12-37), add parameter with default:

```dart
    this.micDisabledForSession = false,
```

- [ ] **Step 2: Update copyWith method**

In `copyWith` parameters (lines 103-130), add:

```dart
    bool? micDisabledForSession,
```

In the return statement (lines 131-155), add:

```dart
      micDisabledForSession: micDisabledForSession ?? this.micDisabledForSession,
```

- [ ] **Step 3: Add `disableMicForSession` method to VocabularySessionController**

After the `startSession` method (around line 190), add:

```dart
  void disableMicForSession() {
    state = state.copyWith(micDisabledForSession: true);
  }
```

- [ ] **Step 4: Add `_buildPronunciation` method**

After `_buildSpelling` (line 797), add:

```dart
  SessionQuestion _buildPronunciation(WordSessionState word) {
    return SessionQuestion(
      type: QuestionType.pronunciation,
      targetWordId: word.wordId,
      targetWord: word.word,
      targetMeaning: word.meaningTR,
      correctAnswer: word.word,
      imageUrl: word.imageUrl,
    );
  }
```

- [ ] **Step 5: Add pronunciation case to `_buildQuestion` switch**

In the `_buildQuestion` switch (lines 653-673), add before the closing `}`:

```dart
      case QuestionType.pronunciation:
        return _buildPronunciation(word);
```

- [ ] **Step 6: Add pronunciation to Phase 2 eligible types**

In `_generateQuestionForWord`, within the `bridged`/`produced` case (lines 558-568), update to:

```dart
      case WordMasteryLevel.bridged:
      case WordMasteryLevel.produced:
        eligibleTypes = [
          QuestionType.spelling,
          QuestionType.listeningWrite,
          if (!state.micDisabledForSession && word.word.length >= 3)
            QuestionType.pronunciation,
          if (word.exampleSentence != null) QuestionType.sentenceGap,
        ];
```

- [ ] **Step 7: Add pronunciation to Phase 3 eligible types**

In `_generateFinalQuestion` (lines 628-633), update to:

```dart
    List<QuestionType> types = [
      QuestionType.spelling,
      if (!state.micDisabledForSession && word.word.length >= 3)
        QuestionType.pronunciation,
      if (word.exampleSentence != null) QuestionType.sentenceGap,
      QuestionType.scrambledLetters,
      QuestionType.wordWheel,
    ];
```

- [ ] **Step 8: Add XP fallback logic in `answerQuestion`**

In `answerQuestion` method, at the XP calculation (around line 302-307), replace:

```dart
      xpGained = question.type.baseXP * max<int>(1, comboMultiplier);
```

with:

```dart
      final baseXP = (question.type == QuestionType.pronunciation &&
              state.micDisabledForSession)
          ? QuestionType.spelling.baseXP
          : question.type.baseXP;
      xpGained = baseXP * max<int>(1, comboMultiplier);
```

- [ ] **Step 9: Verify build**

Run: `dart analyze lib/`
Expected: Error only in session screen (missing `pronunciation` case in switch). Provider should be clean.

- [ ] **Step 10: Commit**

```bash
git add lib/presentation/providers/vocabulary_session_provider.dart
git commit -m "feat: add pronunciation provider logic with mic session flag and XP fallback"
```

---

### Task 4: Create `VocabPronunciationQuestion` widget

**Files:**
- Create: `lib/presentation/widgets/vocabulary/session/vocab_pronunciation_question.dart`

Reference template: `lib/presentation/widgets/vocabulary/session/vocab_spelling_question.dart`

- [ ] **Step 1: Create the widget file**

Create `lib/presentation/widgets/vocabulary/session/vocab_pronunciation_question.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import '../../../../domain/entities/vocabulary_session.dart';
import 'vocab_question_container.dart';
import 'vocab_question_image.dart';

/// Pronunciation question: Image + TR meaning shown, say the English word.
/// Falls back to spelling (TextField) when mic is unavailable.
class VocabPronunciationQuestion extends StatefulWidget {
  const VocabPronunciationQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.onMicDisabled,
  });

  final SessionQuestion question;
  final ValueChanged<String> onAnswer;
  final VoidCallback onMicDisabled;

  @override
  State<VocabPronunciationQuestion> createState() =>
      _VocabPronunciationQuestionState();
}

class _VocabPronunciationQuestionState
    extends State<VocabPronunciationQuestion> {
  bool _isFallbackMode = false;
  bool _isListening = false;
  bool _answered = false;
  bool _sttAvailable = false;
  String? _statusMessage;

  final SpeechToText _stt = SpeechToText();
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _noResultTimer;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _initSpeech();
  }

  void _onTextChanged() => setState(() {});

  Future<void> _initSpeech() async {
    try {
      final available = await _stt.initialize(
        onError: (error) {
          if (mounted && !_answered) {
            _switchToFallback();
          }
        },
      );
      if (mounted) {
        if (!available) {
          _switchToFallback();
        } else {
          setState(() => _sttAvailable = true);
        }
      }
    } catch (_) {
      if (mounted) _switchToFallback();
    }
  }

  void _switchToFallback() {
    if (_isFallbackMode) return;
    setState(() => _isFallbackMode = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    widget.onMicDisabled();
  }

  void _startListening() async {
    if (_answered || !_sttAvailable) return;
    setState(() {
      _isListening = true;
      _statusMessage = null;
    });
    await _stt.listen(
      localeId: 'en-US',
      onResult: _onSpeechResult,
      listenMode: ListenMode.confirmation,
    );
  }

  void _stopListening() async {
    await _stt.stop();
    if (mounted) {
      setState(() => _isListening = false);
      // Timeout: if no final result arrives within 500ms, allow retry
      _noResultTimer?.cancel();
      _noResultTimer = Timer(const Duration(milliseconds: 500), () {
        if (!_answered && mounted) {
          setState(() => _statusMessage = "Didn't catch that, try again");
        }
      });
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!result.finalResult || _answered) return;
    _noResultTimer?.cancel();

    final recognizedWord = result.recognizedWords.trim().toLowerCase();

    // Empty result — let student retry
    if (recognizedWord.isEmpty) {
      setState(() => _statusMessage = "Didn't catch that, try again");
      return;
    }

    setState(() => _answered = true);
    HapticFeedback.lightImpact();
    final correctAnswer = widget.question.correctAnswer.toLowerCase();

    // Exact match = always correct, regardless of confidence score
    if (recognizedWord == correctAnswer) {
      widget.onAnswer(widget.question.correctAnswer);
    } else {
      widget.onAnswer(recognizedWord);
    }
  }

  void _submitSpelling() {
    if (_answered || _textController.text.trim().isEmpty) return;
    setState(() => _answered = true);
    HapticFeedback.lightImpact();
    widget.onAnswer(_textController.text.trim());
  }

  @override
  void dispose() {
    _stt.stop();
    _noResultTimer?.cancel();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _isFallbackMode ? 'Type the English word' : 'Say the English word',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 12),

          // Card with image + TR meaning
          VocabQuestionContainer(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
            child: Column(
              children: [
                VocabQuestionImage(
                  imageUrl: widget.question.imageUrl,
                  size: 120,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    widget.question.targetMeaning,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Mode-specific content
          if (_isFallbackMode) _buildSpellingMode(theme) else _buildMicMode(theme),
        ],
      ),
    );
  }

  Widget _buildMicMode(ThemeData theme) {
    return Column(
      children: [
        // Status message
        if (_statusMessage != null) ...[
          Text(
            _statusMessage!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Mic button — hold to speak
        GestureDetector(
          onLongPressStart: (_) => _startListening(),
          onLongPressEnd: (_) => _stopListening(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isListening ? 100 : 80,
            height: _isListening ? 100 : 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isListening
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primaryContainer,
              boxShadow: _isListening
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.mic,
              size: _isListening ? 44 : 36,
              color: _isListening
                  ? Colors.white
                  : theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          _isListening ? 'Listening...' : 'Hold to speak',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 24),

        // "Can't use microphone?" fallback link
        TextButton(
          onPressed: _answered ? null : _switchToFallback,
          child: Text(
            "Can't use microphone?",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpellingMode(ThemeData theme) {
    return Column(
      children: [
        // TextField — matches VocabSpellingQuestion pattern
        TextField(
          controller: _textController,
          focusNode: _focusNode,
          enabled: !_answered,
          autocorrect: false,
          textCapitalization: TextCapitalization.none,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          decoration: InputDecoration(
            hintText: 'Type answer...',
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          ),
          onSubmitted: (_) => _submitSpelling(),
        ),

        const SizedBox(height: 20),

        // Submit button — matches VocabSpellingQuestion pattern
        if (!_answered)
          FilledButton(
            onPressed:
                _textController.text.trim().isNotEmpty ? _submitSpelling : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Check Answer',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify build**

Run: `dart analyze lib/presentation/widgets/vocabulary/session/vocab_pronunciation_question.dart`
Expected: No errors in this file.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/vocabulary/session/vocab_pronunciation_question.dart
git commit -m "feat: create VocabPronunciationQuestion widget with mic and spelling fallback"
```

---

### Task 5: Add pronunciation dispatch in session screen

**Files:**
- Modify: `lib/presentation/screens/vocabulary/vocabulary_session_screen.dart:423-488`

- [ ] **Step 1: Add import**

At the top of `vocabulary_session_screen.dart`, add:

```dart
import '../../widgets/vocabulary/session/vocab_pronunciation_question.dart';
```

- [ ] **Step 2: Add pronunciation case to switch**

In the question dispatch switch (after the `spelling` case around line 482, before `sentenceGap`), add:

```dart
      case QuestionType.pronunciation:
        return VocabPronunciationQuestion(
          key: key,
          question: question,
          onAnswer: (ans) => _handleAnswer(controller, ans),
          onMicDisabled: () => controller.disableMicForSession(),
        );
```

- [ ] **Step 3: Verify build**

Run: `dart analyze lib/`
Expected: No errors. All switch cases exhaustive.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/screens/vocabulary/vocabulary_session_screen.dart
git commit -m "feat: add pronunciation question dispatch in session screen"
```

---

### Task 6: Add TTS on wrong pronunciation answer in feedback widget

**Files:**
- Modify: `lib/presentation/widgets/vocabulary/session/vocab_question_feedback.dart:8-53`

- [ ] **Step 1: Add import and questionType parameter**

Add import at top:

```dart
import 'package:flutter_tts/flutter_tts.dart';
import '../../../../domain/entities/vocabulary_session.dart';
```

Update constructor (lines 8-30) to add `questionType` parameter:

```dart
class VocabQuestionFeedback extends StatefulWidget {
  const VocabQuestionFeedback({
    super.key,
    required this.isCorrect,
    this.correctAnswer,
    this.targetWord,
    this.questionType,
    this.xpGained = 0,
    this.combo = 0,
    this.comboWarning = false,
    this.comboBroken = false,
    required this.onDismiss,
  });

  final bool isCorrect;
  final String? correctAnswer;
  final String? targetWord;
  final QuestionType? questionType;
  final int xpGained;
  final int combo;
  final bool comboWarning;
  final bool comboBroken;
  final VoidCallback onDismiss;
```

- [ ] **Step 2: Add TTS lifecycle in state**

In the state class, add TTS field:

```dart
  FlutterTts? _tts;
```

In `initState` (line 38-47), after the existing auto-dismiss timer, add:

```dart
    // TTS for wrong pronunciation answers
    if (!widget.isCorrect &&
        widget.questionType == QuestionType.pronunciation &&
        widget.targetWord != null) {
      _tts = FlutterTts();
      _tts!.setLanguage('en-US');
      _tts!.speak(widget.targetWord!);
    }
```

In `dispose` (line 50-53), add before `super.dispose()`:

```dart
    _tts?.stop();
```

- [ ] **Step 3: Pass questionType from session screen**

In `vocabulary_session_screen.dart`, in the `_buildFooter` method (around line 305), update the `VocabQuestionFeedback` constructor call to add:

```dart
              questionType: sessionState.currentQuestion?.type,
```

- [ ] **Step 4: Verify build**

Run: `dart analyze lib/`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/vocabulary/session/vocab_question_feedback.dart lib/presentation/screens/vocabulary/vocabulary_session_screen.dart
git commit -m "feat: add TTS pronunciation on wrong answer in feedback widget"
```

---

### Task 7: Update documentation

**Files:**
- Modify: `docs/vocabulary-session-system.md`

- [ ] **Step 1: Update question types section**

In `docs/vocabulary-session-system.md`, add pronunciation to:

1. The "Question Types — Complete Reference" section — add new subsection under Production Tier:

```markdown
#### `pronunciation` — `VocabPronunciationQuestion`
- **Prompt:** "Say the English word"
- **Display:** Image (if available) + TR meaning. EN word is NOT shown (recall test).
- **Interaction:** Hold-to-speak (long press mic button). Device STT evaluates pronunciation.
- **Fallback:** "Can't use microphone?" → switches to spelling mode (TextField). Disables pronunciation for entire session.
- **Evaluation:** Exact word match = always correct regardless of confidence. Empty result = retry prompt.
- **Min word length:** Only generated for words with length >= 3
- **Base XP:** 30 (falls to 25 in spelling fallback mode)
```

2. The "Question Type Availability by Phase" table — add row:

```markdown
| pronunciation | - | Yes (if mic enabled, word >= 3 chars) | Yes (if mic enabled, word >= 3 chars) |
```

3. The "Base XP by Tier" table — add row:

```markdown
| Production (pronunciation) | pronunciation | 30 (25 in fallback) |
```

- [ ] **Step 2: Commit**

```bash
git add docs/vocabulary-session-system.md
git commit -m "docs: add pronunciation question type to vocabulary session documentation"
```

---

### Task 8: Final verification

- [ ] **Step 1: Full static analysis**

Run: `dart analyze lib/`
Expected: No errors.

- [ ] **Step 2: Verify all switch cases are exhaustive**

Run: `grep -n 'QuestionType\.' lib/domain/entities/vocabulary_session.dart | head -20`
Verify 10 enum values exist (including `pronunciation`).

- [ ] **Step 3: Manual test checklist**

Test on device/emulator:
1. Start a vocabulary session with a word list
2. Progress to Phase 2 (bridged/produced mastery) — pronunciation should appear
3. Allow mic permission when prompted → hold-to-speak → say word → verify correct/incorrect feedback
4. On wrong answer → verify TTS reads correct word aloud
5. Tap "Can't use microphone?" → verify spelling fallback appears
6. Verify no more pronunciation questions appear for rest of session
7. Start new session → verify pronunciation appears again (session flag resets)
8. Deny mic permission → verify automatic spelling fallback
9. Test with short word (2 chars) → verify pronunciation is NOT generated

- [ ] **Step 4: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix: address issues from pronunciation manual testing"
```
