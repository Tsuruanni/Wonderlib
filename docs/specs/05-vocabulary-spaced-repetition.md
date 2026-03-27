# Vocabulary & Spaced Repetition

## Audit

### Findings

| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Hard-coded String | `book_download_service.dart:240` uses `'vocabulary_words'` instead of `DbTables.vocabularyWords` | Low | Fixed |
| 2 | UI Language | Turkish MC distractor placeholders `'(diğer)', '(yok)', '(bilinmiyor)'` in `vocabulary_session_provider.dart:778` — should be English | Medium | Fixed |
| 3 | UI Language | Admin vocabulary screens use Turkish UI text — intentional, admin panel UI stays in Turkish | None | N/A |
| 4 | Edge Case | Session screen pops silently when word list is empty (no error feedback to user) | Low | Fixed |
| 5 | Performance | `retryWordIds` filter is client-side — fetches all list words then filters in memory | Low | Noted |
| 6 | Dead Code | `VocabComboIndicator` referenced in old doc as unused — class no longer exists, already cleaned up | None | Resolved |
| 7 | SM2 Divergence | Server-side SM2 (session system) uses `ease += 0.02`; client-side SM2 (daily review) uses standard formula — produces different interval schedules | Low | Noted |

### Checklist Result

- **Architecture Compliance:** PASS — Clean layers respected, shared package used correctly. 1 hard-coded string (Finding #1).
- **Code Quality:** PASS — Either pattern, naming conventions, provider lifecycle all correct. 1 Turkish placeholder issue (Finding #2).
- **Dead Code:** PASS — No unused code found. Previously flagged `VocabComboIndicator` already removed.
- **Database & Security:** PASS — RLS on all user-facing tables, RPC auth enforced, XP delta anti-farming mechanism.
- **Edge Cases & UX:** PASS / 1 minor issue — Empty states handled across screens. Session screen could improve empty word list feedback (Finding #4).
- **Performance:** PASS / 1 noted — Client-side retry filter (Finding #5). No N+1 queries; batch operations used.
- **Cross-System Integrity:** PASS — XP, badges, streak, and assignment progress all triggered correctly via RPC chain.

---

## Overview

The Vocabulary & Spaced Repetition system lets students learn English words through structured sessions with 10 question types across 3 difficulty tiers. Words are organized in word lists within vocabulary units. The SM-2 spaced repetition algorithm schedules review intervals. Admin creates/imports vocabulary; students practice through sessions and daily review; teachers view per-student vocabulary statistics.

## Data Model

### Core Tables

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `vocabulary_words` | Master word bank | `word`, `phonetic`, `meaning_tr`, `meaning_en`, `example_sentences[]`, `audio_url`, `image_url`, `level` (CEFR), `part_of_speech`, `source_book_id` |
| `vocabulary_progress` | Per-user SM-2 state per word | `user_id`, `word_id`, `ease_factor`, `interval_days`, `repetitions`, `next_review_at`, `status` (new_word/learning/reviewing/mastered) |
| `vocabulary_units` | Grouping units for learning paths | `name`, `sort_order`, `color`, `icon`, `is_active` |
| `word_lists` | Collections of words for study sessions | `name`, `description`, `level`, `category`, `word_count`, `unit_id`, `order_in_unit`, `source_book_id`, `is_system` |
| `word_list_items` | Junction: word list ↔ word | `word_list_id`, `word_id`, `order_index` (UNIQUE per list+word) |
| `user_word_list_progress` | Per-user session-level progress per list | `best_score`, `best_accuracy`, `total_sessions`, `last_session_at` |
| `vocabulary_sessions` | Completed session records | `word_list_id`, `accuracy`, `max_combo`, `xp_earned`, `duration_seconds`, `words_strong`, `words_weak` |
| `vocabulary_session_words` | Per-word result within a session | `session_id`, `word_id`, `correct_count`, `incorrect_count`, `mastery_level`, `is_first_try_perfect` |
| `chapter_vocabulary` | Junction: chapter ↔ word | `chapter_id`, `word_id` |
| `daily_review_sessions` | Daily review tracking | `session_date` (UNIQUE per user+date), `words_reviewed`, `correct_count`, `xp_earned`, `is_perfect`, `path_position` |
| `user_node_completions` | Learning path node completion tracking | `user_id`, `node_type`, `node_position` |

### Key Relationships

```
vocabulary_units ──1:N──> word_lists ──M:N──> vocabulary_words (via word_list_items)
                                                    │
vocabulary_words ──1:N──> vocabulary_progress (per user)
                                                    │
word_lists ──1:N──> vocabulary_sessions ──1:N──> vocabulary_session_words
                          │
                          └──> user_word_list_progress (per user, per list)
```

## Surfaces

### Admin

- **Vocabulary CRUD** (`vocabulary_edit_screen.dart`): Create/edit/delete individual words with all fields (word, phonetic, part of speech, meanings, audio URL, image URL, CEFR level, example sentences). Audio preview with play button.
- **CSV Import** (`vocabulary_import_screen.dart`): Bulk import words from CSV. Required headers: `word`, `meaning_tr`. Optional: `phonetic`, `part_of_speech`, `meaning_en`, `level`. Validates levels against CEFR values and part of speech.
- **Word List Management** (`wordlist_edit_screen.dart`, `wordlist_list_screen.dart`): Create/edit/delete word lists. Add words via search picker. Drag-and-drop reordering. Assign to vocabulary unit. Generate audio for all words in list.
- **Word Picker** (`vocabulary_word_picker.dart`): Reusable picker for assigning words to books/chapters.

### Student

**Session Flow (3 phases):**

1. **Explore Phase**: Words introduced in pairs via flashcards (image + EN word + TTS + TR meaning + example sentence). After each pair, a simple 2-option recognition question.
2. **Reinforce Phase**: Mixed question types selected by mastery level. Exits when all words ≥ `recognized` AND ≥10 questions, OR ≥14 questions (hard cap). 40% chance to pull from remediation queue on each question.
3. **Final Phase**: Focuses on weak words (incorrectCount > 0). Runs min(5, weakWords.length) production-tier questions. Skipped if no weak words.

**Question Types (10):**

| Type | Tier | Interaction | Base XP |
|------|------|-------------|---------|
| `multipleChoice` | Recognition | EN word → pick TR meaning (2 or 4 options) | 10 |
| `reverseMultipleChoice` | Recognition | TR meaning → pick EN word | 10 |
| `listeningSelect` | Recognition | Audio → pick EN word | 10 |
| `imageMatch` | Recognition | EN word → pick correct image (2 options, Explore only) | 10 |
| `matching` | Bridge | Match 4 EN↔TR pairs (tap-to-match) | 15 |
| `scrambledLetters` | Bridge | Rearrange shuffled letters to form word | 20 |
| `wordWheel` | Bridge | Connect letters in circle to form word | 20 |
| `spelling` | Production | Type EN word from TR meaning | 25 |
| `listeningWrite` | Production | Listen to audio, type EN word | 25 |
| `sentenceGap` | Production | Fill blank in example sentence | 30 |
| `pronunciation` | Production | Speak word via microphone (STT). Fallback to spelling if mic unavailable. | 30 (25 fallback) |

**Other Student Screens:**

- **Vocabulary Hub** (`vocabulary_hub_screen.dart`): Main entry with learning path visualization and story word lists.
- **Word List Detail** (`word_list_detail_screen.dart`): Shows words in list, session history, best score, start/retry session.
- **Session Summary** (`session_summary_screen.dart`): Results after session — persists via RPC, shows XP delta, accuracy, word breakdown (strong/medium/weak), retry option for weak words.
- **Daily Review** (`daily_review_screen.dart`): SM-2 based flashcard review of due words. One session per day.
- **Category Browse** (`category_browse_screen.dart`): Browse word lists by category.
- **Vocabulary Browse** (`vocabulary_screen.dart`): Browse all words with due-for-review filter.

### Teacher

- **Student Vocab Stats** (`studentVocabStatsProvider`): Per-student vocabulary statistics via `get_student_vocab_stats` RPC — total words learned, mastered count, review status.
- **Student Word List Progress** (`studentWordListProgressProvider`): Per-student word list completion via `get_student_word_list_progress` RPC — sessions completed, best scores, accuracy.

## Business Rules

1. **Minimum 2 words** required to start a session. Session screen pops back if fewer.
2. **Mastery never regresses within a session.** Incorrect answers only increment `incorrectCount` and add to remediation queue.
3. **Mastery promotion**: `unseen/introduced` → recognition question correct → `recognized` → bridge question correct → `bridged` → production question correct → `produced`.
4. **Combo system (two-strike)**: First wrong answer at combo ≥ 2 only warns. Second consecutive wrong answer breaks combo (`combo = max(0, combo - 2)`).
5. **XP formula**: `baseXP * max(1, min(combo, 5))` — combo multiplier capped at x5.
6. **XP anti-farming (delta)**: `xp_to_award = GREATEST(0, session_xp - previous_best)`. Replaying a list only awards XP exceeding previous best score.
7. **Session bonuses** (server-side, from `system_settings`): +10 XP for completion, +20 XP for 100% accuracy.
8. **SM-2 server-side (sessions)**: Strong words get increasing intervals (1d → 6d → ease-based, cap 365). Weak words reset to interval=0, ease decremented by 0.2 (min 1.3). Status: mastered when interval > 21 days.
9. **SM-2 client-side (daily review)**: Uses standard SM-2 formula (`newEF = EF + (0.1 - (5-q)*(0.08 + (5-q)*0.02))`). Produces different schedules than server-side — known divergence.
10. **Daily review**: One session per day (UNIQUE constraint on user_id + session_date). XP = 5 per correct + 10 session bonus + 20 perfect bonus. Duplicate attempts return 0 XP.
11. **Remediation queue**: 40% chance per question to pull from queue. Uses simplified 2-option MC with image support.
12. **Adaptive difficulty**: `isPerformingWell` (≥5 answered, >80% accuracy) may skip recognition questions. `isStruggling` (≥4 answered, <50% accuracy) adds more recognition questions.
13. **Pronunciation fallback**: If microphone unavailable or user opts out, pronunciation disabled for entire session. Fallback to spelling input (25 XP instead of 30).
14. **Matching partial credit**: XP = `baseXP(15) * comboMultiplier * correctMatches / totalMatches`.
15. **Word list categories**: `commonWords`, `gradeLevel`, `testPrep`, `thematic`, `storyVocab` (shared enum).

## Cross-System Interactions

### Session Completion Chain
```
Session completes
  → RPC: complete_vocabulary_session
    → vocabulary_sessions INSERT
    → vocabulary_session_words INSERT per word
    → vocabulary_progress UPSERT (SM-2 intervals)
    → user_word_list_progress UPSERT (best_score, total_sessions)
    → award_xp_transaction (XP delta only)
      → badge check (check_and_award_badges)
    → update_user_streak
  → Client: invalidate progressForListProvider, userWordListProgressProvider,
    wordListsWithProgressProvider, learningPathProvider
  → Client: refreshProfileOnly (XP, level, coins)
  → IF matching vocabulary assignment exists:
    → CompleteAssignmentUseCase (score = accuracy %)
```

### Daily Review Chain
```
Daily review completes
  → RPC: complete_daily_review
    → daily_review_sessions INSERT (1 per day)
    → award_xp_transaction
    → update_user_streak
    → check_and_award_badges
```

### Reader Integration
```
Student taps word in reader
  → LookupWordDefinitionUseCase
    → Shows word popup with meanings, phonetic, audio
    → Can add word to personal vocabulary
```

### Badge Triggers
- `vocabularyLearned` badge condition type — fires via `check_and_award_badges` after XP award.

### Assignment Integration
- Vocabulary assignments match by `wordListId`. Session summary checks for matching assignment and auto-completes with accuracy as score.

## Edge Cases

| Scenario | Handling |
|----------|----------|
| Word list has < 2 words | Session screen pops back with snackbar message |
| Word list has 0 words | Session screen pops back silently |
| All words already at `produced` mastery + no weak words | Phase 2 exits directly to completion (skips Phase 3) |
| No weak words at Phase 3 transition | Phase 3 skipped entirely |
| Matching question with < 4 eligible words | `matching` type not generated |
| `sentenceGap` with no `exampleSentence` | Question type not generated for that word |
| `pronunciation` with word length < 3 | Question type not generated |
| MC distractor pool < 3 words | Padded with placeholder strings |
| Replay completed list | XP delta mechanism: only awards difference above previous best |
| Daily review already done today | Returns 0 XP, `is_new_session = false` |
| Microphone permission denied | Pronunciation disabled for entire session, falls back to spelling |
| Network failure during session save | Error snackbar on summary screen, session data may be lost |
| `retryWordIds` filter results in < 2 words | Session pops back with snackbar |

## Test Scenarios

- [ ] Happy path: Start session with 6+ words, complete all 3 phases, verify XP on summary
- [ ] Retry session: Complete session with errors, retry with weak words only
- [ ] Daily review: Complete daily review, verify XP award, verify second attempt same day returns 0
- [ ] Empty word list: Navigate to list with 0 words, attempt start — should show feedback
- [ ] 1-word list: Attempt session with list containing only 1 word — should show "need 2 words"
- [ ] Matching edge: Session with exactly 3 words — matching type should not appear
- [ ] Pronunciation fallback: Deny mic, verify spelling fallback for entire session
- [ ] Combo system: Get 3 correct (combo=3), get 1 wrong (warning), get another wrong (combo broken to 1)
- [ ] XP delta: Complete list scoring 100 XP, replay scoring 80 XP — should award 0 XP
- [ ] XP delta improvement: Replay scoring 120 XP — should award 20 XP delta
- [ ] Cross-system: Complete vocab session matching an assignment — assignment should auto-complete
- [ ] Admin CRUD: Create word, edit, delete — verify in word list and student session
- [ ] CSV import: Import valid CSV, verify words created with correct fields
- [ ] Teacher stats: View student vocab stats after student completes sessions

## Key Files

### Main App

| Layer | Key File |
|-------|----------|
| Session Algorithm | `lib/presentation/providers/vocabulary_session_provider.dart` |
| Vocabulary Providers | `lib/presentation/providers/vocabulary_provider.dart` |
| Session Screen | `lib/presentation/screens/vocabulary/vocabulary_session_screen.dart` |
| Session Summary | `lib/presentation/screens/vocabulary/session_summary_screen.dart` |
| Vocabulary Hub | `lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart` |
| Daily Review | `lib/presentation/screens/vocabulary/daily_review_screen.dart` |
| SM-2 Algorithm (client) | `lib/core/utils/sm2_algorithm.dart` |
| Session Entities | `lib/domain/entities/vocabulary_session.dart` |
| Vocabulary Entities | `lib/domain/entities/vocabulary.dart` |
| Word List Repository | `lib/data/repositories/supabase/supabase_word_list_repository.dart` |
| Vocabulary Repository | `lib/data/repositories/supabase/supabase_vocabulary_repository.dart` |

### Admin

| Key File |
|----------|
| `owlio_admin/lib/features/vocabulary/screens/vocabulary_edit_screen.dart` |
| `owlio_admin/lib/features/vocabulary/screens/vocabulary_import_screen.dart` |
| `owlio_admin/lib/features/wordlists/screens/wordlist_edit_screen.dart` |

### Database

| Key File |
|----------|
| `supabase/migrations/20260317000001_fix_session_sm2_interval_growth.sql` — `complete_vocabulary_session` RPC (authoritative SM-2, XP delta, streak, badges) |

## Known Issues & Tech Debt

1. **SM-2 divergence**: Server (session) and client (daily review) use different SM-2 formulas. Should converge on one implementation — preferably server-side for consistency and tamper-proofing.
2. ~~Turkish placeholders~~: Fixed — MC distractor fallbacks now use English `'(other)', '(none)', '(unknown)'`.
3. ~~Admin Turkish UI~~: Admin panel UI intentionally stays in Turkish — not an issue.
4. ~~Hard-coded table name~~: Fixed — now uses `DbTables.vocabularyWords`.
5. **Client-side retry filter**: `retryWordIds` fetches all words then filters in memory. Could be optimized with server-side filter for large lists.
6. **Progress bar estimate**: Uses rough formula `words.length * 2 + 4` — doesn't account for remediation or actual phase durations.
