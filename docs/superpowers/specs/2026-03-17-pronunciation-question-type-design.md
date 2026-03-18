# Pronunciation Question Type — Design Spec

**Date:** 2026-03-17
**Status:** Approved
**Feature:** New vocabulary session question type — pronunciation with spelling fallback

---

## Overview

Add a `pronunciation` question type to the vocabulary session system. The student sees an image + TR meaning and must **say the English word out loud** into the microphone. If the microphone is unavailable or the student opts out, the question falls back to a spelling input (typing the word).

This is a **production-tier** question (30 XP) — the hardest tier, because it requires both recall and correct pronunciation.

---

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Pronunciation evaluation | Device STT (`speech_to_text`) + confidence score | Free, on-device, no API cost, no LLM calls |
| Confidence threshold | >= 0.6 (only when word does NOT match) | Exact word match = always correct regardless of confidence. Threshold only gates unclear/wrong recognitions |
| Tier & XP | Production, 30 XP | Equal to sentenceGap — mic usage is an extra challenge |
| Fallback XP | 25 XP (spelling tier) | Spelling is easier than speaking |
| Mic button interaction | Hold-to-speak (long press) | More intentional than toggle, prevents accidental recordings |
| "Can't use microphone?" | Switches to spelling mode in-widget + disables pronunciation for entire session | One tap = permanent for session, no repeated nagging |
| Permission denied | Same as "Can't use microphone?" — spelling fallback, session-level disable | Seamless, student never gets stuck |
| What student sees | Image + TR meaning only | EN word is NOT shown — this is a recall test, not a reading test |
| TTS reference | Not shown — would give away the answer | Student must recall AND pronounce |
| Wrong answer feedback | Shows correct EN word + TTS reads it aloud | Educational — student hears correct pronunciation |
| Phases | Phase 2 (bridged/produced mastery) + Phase 3 (final) | Same eligibility as spelling, random selection from pool |
| Mic permission | OS-level, asked once in app lifetime | No per-session popups |

---

## Architecture

### Approach: Hybrid Widget Fallback + Provider Session Flag

1. Pronunciation widget handles both modes internally (mic mode / spelling fallback)
2. "Can't use microphone?" triggers in-widget transition (smooth UX for current question)
3. Simultaneously sets `micDisabledForSession` flag on provider
4. All subsequent questions: provider excludes `pronunciation` from eligible list, spelling takes its place naturally

---

## Entity & Enum Changes

### QuestionType Enum

```dart
enum QuestionType {
  // Recognition
  multipleChoice, reverseMultipleChoice, listeningSelect,
  // Bridge
  matching, scrambledLetters, wordWheel,
  // Production
  spelling, listeningWrite, sentenceGap,
  pronunciation,  // NEW
}
```

### XP & Tier Extensions

```dart
// QuestionTypeXP
QuestionType.pronunciation => 30,

// QuestionTypeTier
QuestionType.pronunciation => QuestionTier.production,
```

### VocabularySessionState — New Field

```dart
final bool micDisabledForSession;  // default: false, reset on startSession()
```

### SessionQuestion — No Changes

Existing fields sufficient:
- `targetWord` — correct answer (EN word)
- `correctAnswer` — same as targetWord (original casing, provider normalizes)
- `imageUrl` — image to display
- `targetMeaning` — TR meaning to display

Phonetic info accessed via `WordSessionState.phonetic` (already in session state).

---

## Provider Changes

### Question Generation — Phase 2

```dart
case WordMasteryLevel.bridged:
case WordMasteryLevel.produced:
  eligibleTypes = [
    QuestionType.spelling,
    QuestionType.listeningWrite,
    if (!state.micDisabledForSession && word.word.length >= 3) QuestionType.pronunciation,
    if (word.exampleSentence != null) QuestionType.sentenceGap,
  ];
```

> **Min word length:** Pronunciation requires `word.length >= 3`. STT struggles with very short words (e.g., "go", "do"). Short words fall through to spelling/other types.

### Question Generation — Phase 3

```dart
List<QuestionType> types = [
  QuestionType.spelling,
  if (!state.micDisabledForSession && word.word.length >= 3) QuestionType.pronunciation,
  if (word.exampleSentence != null) QuestionType.sentenceGap,
  QuestionType.scrambledLetters,
  QuestionType.wordWheel,
];
```

### New Method

```dart
void disableMicForSession() {
  state = state.copyWith(micDisabledForSession: true);
}
```

### New Builder

```dart
SessionQuestion _buildPronunciation(WordSessionState word) {
  return SessionQuestion(
    type: QuestionType.pronunciation,
    targetWordId: word.wordId,
    targetWord: word.word,
    targetMeaning: word.meaningTR,
    correctAnswer: word.word,  // original casing — _checkAnswer normalizes both sides
    imageUrl: word.imageUrl,
  );
}
```

### `_buildQuestion` Switch — New Case

```dart
case QuestionType.pronunciation:
  return _buildPronunciation(word);
```

### XP Calculation — Fallback Adjustment

In `answerQuestion()`:
```dart
final baseXP = (question.type == QuestionType.pronunciation && state.micDisabledForSession)
    ? QuestionType.spelling.baseXP   // 25
    : question.type.baseXP;          // 30
```

> **Ordering safety:** `disableMicForSession()` is called synchronously via `state = state.copyWith(...)` before `answerQuestion()` can fire. The fallback switch (`_switchToFallback`) sets `_isFallbackMode = true` which gates the submit button visibility — so `onMicDisabled` always completes before any answer submission.

---

## Widget: `VocabPronunciationQuestion`

### File

`lib/presentation/widgets/vocabulary/session/vocab_pronunciation_question.dart`

### Props

```dart
class VocabPronunciationQuestion extends StatefulWidget {
  final SessionQuestion question;      // imageUrl accessed via question.imageUrl
  final ValueChanged<String> onAnswer;
  final VoidCallback onMicDisabled;
}
```

### State

```dart
bool _isFallbackMode = false;
bool _isListening = false;
bool _answered = false;
bool _sttAvailable = false;
String? _statusMessage;

final SpeechToText _stt = SpeechToText();
final TextEditingController _textController;     // fallback mode
final FocusNode _focusNode;                      // fallback mode
Timer? _noResultTimer;                           // quick-release timeout
```

> **Note:** TTS for wrong-answer feedback is handled by `VocabQuestionFeedback` widget, not this widget.

### UI — Pronunciation Mode

```
┌─────────────────────────────────────────┐
│  "Say the English word"                  │
│                                          │
│  ┌─────────────────┐                     │
│  │   [Image]        │                     │
│  └─────────────────┘                     │
│                                          │
│  "ornek"                                 │  TR meaning
│                                          │
│  ┌────────────────────┐                  │
│  │   mic  HOLD TO SPEAK │               │  Hold = record
│  └────────────────────┘                  │
│  (pulse animation while listening)       │
│                                          │
│  "Can't use microphone?"                 │  TextButton
└─────────────────────────────────────────┘
```

### UI — Spelling Fallback Mode

```
┌─────────────────────────────────────────┐
│  "Type the English word"                 │  Title changes
│                                          │
│  ┌─────────────────┐                     │
│  │   [Image]        │                     │
│  └─────────────────┘                     │
│                                          │
│  "ornek"                                 │  TR meaning stays
│                                          │
│  [____________________]                  │  TextField (auto-focus)
│                                          │
│  [ Check Answer ]                        │  Submit button
└─────────────────────────────────────────┘
```

### Hold-to-Speak Flow

```
onLongPressStart:
  → _stt.listen(
      localeId: 'en-US',
      onResult: _onSpeechResult,
      listenMode: ListenMode.confirmation,  // single word mode
    )
  → setState(_isListening = true)
  → mic button pulse animation starts

onLongPressEnd:
  → _stt.stop()
  → setState(_isListening = false)
  → Start 500ms timeout: if no finalResult arrives, reset to allow retry

_onSpeechResult(SpeechRecognitionResult result):
  if result.finalResult && !_answered:
    recognizedWord = result.recognizedWords.trim().toLowerCase()
    confidence = result.confidence

    // Guard: empty result (held mic but said nothing) → let student retry
    if recognizedWord.isEmpty:
      setState → show "Didn't catch that, try again" message
      return  // do NOT submit, allow another attempt

    _answered = true

    // Exact match = always correct, regardless of confidence
    // Confidence threshold only gates unclear/wrong recognitions
    if recognizedWord == correctAnswer.toLowerCase():
      onAnswer(correctAnswer)       // CORRECT
    else:
      onAnswer(recognizedWord)      // WRONG — provider does string comparison
```

### Mic Permission Init

```dart
@override
void initState() {
  super.initState();
  _initSpeech();
}

Future<void> _initSpeech() async {
  final available = await _stt.initialize(
    onError: (_) => _switchToFallback(),
  );
  if (!available) _switchToFallback();
}
```

### Fallback Switch

```dart
void _switchToFallback() {
  setState(() => _isFallbackMode = true);
  _focusNode.requestFocus();
  widget.onMicDisabled();  // → controller.disableMicForSession()
}
```

---

## Feedback Changes

### `VocabQuestionFeedback` — TTS on Wrong Pronunciation Answer

Scope: **pronunciation questions only** (not all question types — to avoid scope creep).

The feedback widget receives a new optional `questionType` parameter. When `isCorrect == false` AND `questionType == QuestionType.pronunciation`:

```dart
// Managed TTS instance with proper lifecycle
late final FlutterTts _tts;

@override
void initState() {
  super.initState();
  _tts = FlutterTts();
  if (!widget.isCorrect && widget.questionType == QuestionType.pronunciation && widget.targetWord != null) {
    _tts.setLanguage('en-US');
    _tts.speak(widget.targetWord!);
  }
}

@override
void dispose() {
  _tts.stop();
  super.dispose();
}
```

---

## Session Screen Dispatch

```dart
case QuestionType.pronunciation:
  return VocabPronunciationQuestion(
    key: ValueKey('q_$questionIndex'),
    question: question,
    onAnswer: (ans) => _handleAnswer(controller, ans),
    onMicDisabled: () => controller.disableMicForSession(),
  );
```

---

## Package & Platform Changes

### pubspec.yaml

```yaml
dependencies:
  speech_to_text: ^7.0.0
```

### Android — AndroidManifest.xml

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>

<!-- Required for Android 11+ (API 30+) to verify STT intent availability -->
<queries>
  <intent>
    <action android:name="android.speech.RecognitionService" />
  </intent>
</queries>
```

### iOS — Info.plist

```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>Owlio needs speech recognition to check your pronunciation</string>
<key>NSMicrophoneUsageDescription</key>
<string>Owlio needs microphone access for pronunciation exercises</string>
```

### Web

`speech_to_text` supports Chrome via Web Speech API. If unavailable → automatic spelling fallback.

---

## Files Touched

| File | Change Type |
|------|------------|
| `lib/domain/entities/vocabulary_session.dart` | MODIFY — add enum value + XP + tier |
| `lib/presentation/providers/vocabulary_session_provider.dart` | MODIFY — new field, method, builder, eligible lists, XP fallback |
| `lib/presentation/screens/vocabulary/vocabulary_session_screen.dart` | MODIFY — add switch/case dispatch |
| `lib/presentation/widgets/vocabulary/session/vocab_pronunciation_question.dart` | CREATE — new widget |
| `lib/presentation/widgets/vocabulary/session/vocab_question_feedback.dart` | MODIFY — TTS on wrong answer |
| `pubspec.yaml` | MODIFY — add speech_to_text |
| `android/app/src/main/AndroidManifest.xml` | MODIFY — add RECORD_AUDIO permission |
| `ios/Runner/Info.plist` | MODIFY — add speech recognition + microphone descriptions |
| `docs/vocabulary-session-system.md` | MODIFY — add pronunciation to documentation |

---

## Question Type Availability (Updated)

| Question Type | Phase 1 | Phase 2 | Phase 3 |
|---|:---:|:---:|:---:|
| multipleChoice | Yes (2 opt) | Yes (4 opt) | - |
| reverseMultipleChoice | Yes (2 opt) | Yes (4 opt) | - |
| listeningSelect | Yes (2 opt) | Yes (3-4 opt) | - |
| matching | - | Yes (if >=4 words) | - |
| scrambledLetters | - | Yes | Yes |
| wordWheel | - | Yes | Yes |
| spelling | - | Yes | Yes |
| listeningWrite | - | Yes | - |
| sentenceGap | - | Yes (if sentence) | Yes (if sentence) |
| **pronunciation** | **-** | **Yes (if mic enabled)** | **Yes (if mic enabled)** |
