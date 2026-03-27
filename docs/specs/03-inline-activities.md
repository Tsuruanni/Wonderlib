# Inline Activities

## Audit

### Findings

| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Performance | Missing `(user_id, answered_at)` index on `inline_activity_results` — sequential scan on every daily quest progress check (`get_quest_progress` RPC counts correct answers by date) | High | Fixed |
| 2 | Edge Case | `chapterInitializedProvider` never set to `true` when `_loadCompletedActivities` fails — progressive reveal and auto-play triggers break silently for the rest of the session | High | Fixed |
| 3 | Error State | DB save failure in `handleInlineActivityCompletion` silently swallowed — activity marked completed locally but server has no record, XP not awarded, no user feedback or retry option | High | Fixed |
| 4 | Dead Code | `SaveInlineActivityResultUseCase` + `saveInlineActivityResultUseCaseProvider` registered but never called — superseded by `CompleteInlineActivityUseCase` | Medium | Fixed |
| 5 | Dead Code | `InlineActivityWrapper`, `XPEarnedAnimation`, `AnswerFeedback` — entire `inline_activity_wrapper.dart` file (234 lines) unused | Medium | Fixed |
| 6 | Dead Code | `InlineActivity.xpReward` entity field populated from DB column but never read — XP always comes from `SystemSettings` via `getInlineActivityXP()` | Medium | Fixed |
| 7 | Dead Code | Widgetbook `activity_widgets.dart` imports non-existent path `lib/presentation/widgets/activities/` — build break | Medium | Fixed |
| 8 | Data Integrity | `inline_activity_results.words_learned` column never populated — app tracks words in session state and vocabulary_progress but never writes to this column | Medium | Fixed |
| 9 | Architecture | Two parallel rendering paths for inline activities — `ReaderContentBlockList` (content-blocks) and `ReaderLegacyContent` (legacy paragraph-interleave) — both maintained independently | Medium | Accepted |
| 10 | Code Quality | `InlineActivityModel._parseInlineActivityType` / `_inlineActivityTypeToString` duplicate logic already on `InlineActivityType.fromDbValue()` / `.dbValue` from owlio_shared | Medium | Fixed |
| 11 | UX Gap | `InlineFindWordsActivity` missing `InlineActivitySoundMixin` — no sound feedback on answer, while the other 3 types all play sounds | Medium | Fixed |
| 12 | Edge Case | Unknown activity `type` string silently becomes empty true/false card — `_parseInlineActivityType` defaults to `trueFalse` with empty statement and `correctAnswer: true` | Medium | Fixed |
| 13 | Loading | Activity blocks show transient "Failed to load activity" error card while `inlineActivitiesAsync` still loading (resolved on rebuild) | Medium | Fixed |
| 14 | Edge Case | Duplicate `right` values in matching pairs make activity unsolvable — `_matchedPairs.containsValue(right)` disables second identical value immediately | Medium | Fixed |
| 15 | Data Integrity | Vocabulary word ID validity not validated — invalid IDs in `vocabulary_words` JSONB cause silent FK violation, `vocabResult.fold((_) => 0, ...)` swallows error | Medium | Fixed |
| 16 | Performance | `getCompletedInlineActivities` makes 2 sequential Supabase round trips (fetch activity IDs, then filter results) — could be single query | Low | Deferred |
| 17 | Dead Code | `InlineActivityResult` entity and `InlineActivityResultModel.fromJson` / `toEntity` never constructed from DB — repository returns `bool` only | Low | Fixed |
| 18 | Dead Code | `SingleTickerProviderStateMixin` on `InlineFindWordsActivity` — no `AnimationController` used | Low | Fixed |
| 19 | Code Quality | `handleInlineActivityCompletion` is a 93-line top-level free function taking `WidgetRef` in provider file — business logic in presentation layer | Low | Accepted |
| 20 | Data Fidelity | Previously-incorrect activities displayed as "correct" on chapter re-open — `loadFromList` sets all completed activities to `wasCorrect = true` | Low | Fixed |
| 21 | Edge Case | `options.first` crash if options is empty on already-completed wrong activities in `word_translation` and `find_words` | Low | Fixed |
| 22 | Edge Case | Zero-length `correctAnswers` in `find_words` causes immediate auto-submit (selection count 0 == required 0) | Low | Fixed |
| 23 | UX | Chapter completion widget flashes briefly before `inlineActivitiesAsync` resolves — `totalActivitiesProvider` transiently reads 0 | Low | Fixed |
| 24 | Offline | Cold-cache offline open: `getCompletedInlineActivities` cache miss falls to network, fails, `chapterInitializedProvider` never set — all activities appear uncompleted | Low | Fixed |
| 25 | Code Quality | Admin activity editor has Turkish button labels (`'Iptal'`, `'Kaydet'`) — violates CLAUDE.md "UI in English" rule | Low | Fixed |

### Checklist Result

- **Architecture Compliance**: PASS — Clean architecture fully respected. Screen -> Provider -> UseCase -> Repository chain intact. No JSON in entities. `DbTables.inlineActivities` / `DbTables.inlineActivityResults` used throughout. `InlineActivityType` enum from owlio_shared. One accepted deviation: `handleInlineActivityCompletion` as free function (#19).
- **Code Quality**: PASS — All issues fixed (#10 shared enum, #25 English labels). #19 accepted (locality of behavior).
- **Dead Code**: PASS — All removed (#4, #5, #6, #7, #17, #18).
- **Database & Security**: PASS — `words_learned` now populated (#8). Index added (#1). All other checks pass.
- **Edge Cases & UX**: PASS — All fixed (#2, #12, #13, #14, #21, #22, #23, #24).
- **Performance**: 1 issue deferred (#16 double round trip — acceptable for typical chapter size). #1 index added.
- **Cross-System Integrity**: PASS — XP via `userControllerProvider.addXP()` with source/sourceId (triple idempotency: local dedup + DB UNIQUE + xp_logs). Badge check via `addXP`. Daily quest invalidated. Streak not updated (correct — app-open only). Assignment progress not updated (correct — chapter-level tracking). Vocabulary integration via `addWordsToVocabularyBatch`.

---

## Overview

Inline Activities are micro-learning games embedded within book chapters. They appear between paragraphs (legacy path) or as activity-type content blocks (current path) and test comprehension during reading. Four activity types exist: true/false, word translation, find words (multi-select), and matching (tap-to-match pairs). Activities award type-based XP (from SystemSettings), integrate with the vocabulary system by adding learned words, and contribute to daily quest progress. Each activity can only be completed once per student (idempotent via UNIQUE constraint + local dedup + xp_logs triple protection).

## Data Model

### Tables

| Table | Key Columns | Purpose |
|-------|-------------|---------|
| `inline_activities` | id, chapter_id (FK CASCADE), type (CHECK: true_false/word_translation/find_words/matching), after_paragraph_index, content (JSONB), xp_reward (DB column exists but XP comes from SystemSettings), vocabulary_words (JSONB array of word IDs) | Activity definitions |
| `inline_activity_results` | id, user_id (FK), inline_activity_id (FK CASCADE), is_correct, xp_earned, words_learned (TEXT[]), answered_at | Student answers. UNIQUE(user_id, inline_activity_id) enforces one attempt per student. Indexed on (user_id, answered_at) for quest queries. |
| `content_blocks` | activity_id (FK SET NULL to inline_activities) | Links content block to an inline activity in the content-blocks rendering path |

### Content JSONB Structure per Type

**true_false:**
```json
{"statement": "Owls can rotate their heads 360 degrees", "correct_answer": true}
```

**word_translation:**
```json
{"word": "owl", "correct_answer": "baykus", "options": ["baykus", "kedi", "kopek", "kus"]}
```

**find_words (multi-select chips):**
```json
{"instruction": "Select the animals", "options": ["owl", "tree", "cat", "rock"], "correct_answers": ["owl", "cat"]}
```

**matching (tap-to-pair):**
```json
{"instruction": "Match the pairs", "pairs": [{"left": "owl", "right": "baykus"}, {"left": "cat", "right": "kedi"}]}
```

### Key Relationships

- `inline_activities.chapter_id` -> `chapters.id` (CASCADE) — deleting a chapter removes its activities
- `inline_activity_results.inline_activity_id` -> `inline_activities.id` (CASCADE) — deleting an activity removes all results
- `content_blocks.activity_id` -> `inline_activities.id` (SET NULL) — deleting an activity orphans the content block (renders as empty slot, not deleted)
- `inline_activities.vocabulary_words` contains word IDs referencing `vocabulary_words.id` (no FK — validated at runtime)

## Surfaces

### Admin

- **Activity Editor** (`owlio_admin/.../activity_editor.dart`): Full CRUD for all 4 activity types within the chapter editor
- Content authors create activities directly in the chapter content block editor
- Activities can specify `vocabulary_words` (word IDs) to integrate with vocabulary system
- Activity type is selected from a dropdown, content form adapts per type
- Admin queries Supabase directly (no Clean Architecture — accepted pattern for admin panel)

### Student

**User flow:**
1. Student opens a chapter in the reader
2. Reader loads content blocks and inline activities in parallel
3. Activities appear between text blocks (content-blocks path) or between paragraphs (legacy path)
4. Student interacts with the activity (tap true/false, select translation, select words, match pairs)
5. Immediate feedback: correct (green header, XP badge) or incorrect (red header, 0 XP)
6. Sound plays on answer (except find_words — missing, see #11)
7. On correct first-time completion: XP awarded, badge check triggered, daily quest progress updated
8. If activity has `vocabulary_words`: words added to student vocabulary via SM-2 batch
9. Activity marked as completed (cannot re-attempt for XP)
10. When all activities in chapter complete → chapter completion UI appears

**Two rendering paths (see #9):**
- **Content-blocks path** (`ReaderContentBlockList`): Activity is a `ContentBlock` with `type = activity` and `activityId` reference. Current system.
- **Legacy path** (`ReaderLegacyContent`): Activity positioned via `afterParagraphIndex` interleaved between paragraphs. Used for chapters without `use_content_blocks` flag.

### Teacher

N/A — Teachers do not interact with inline activities directly. Activity results contribute to the daily quest and XP systems which teachers see in reports.

## Business Rules

1. **One attempt per activity per student** — enforced at three levels: local `inlineActivityStateProvider` dedup, DB UNIQUE(user_id, inline_activity_id) constraint, and `xp_logs` (user_id, source, source_id) check in `award_xp_transaction` RPC.
2. **XP only on correct answers** — `xpEarned = isCorrect ? getInlineActivityXP(ref, activity.type) : 0`. Incorrect answers still save a result and mark activity as completed.
3. **XP amounts from SystemSettings, not from DB** — Despite `inline_activities.xp_reward` column existing, XP is always read from `system_settings` via `getInlineActivityXP()`, which dispatches by type (`xpInlineTrueFalse`, `xpInlineWordTranslation`, `xpInlineFindWords`, `xpInlineMatching`).
4. **Vocabulary words added on both correct AND incorrect answers** — `wordsLearned` list is always the full `activity.vocabularyWords`. The `immediate` flag differs: incorrect → `immediate: true` (review today), correct → `immediate: false` (schedule via SM-2 normal interval).
5. **true_false activities never add vocabulary** — `onAnswer` callback passes empty `[]` for words, even if `vocabularyWords` is populated on the entity.
6. **Matching requires zero mistakes** — `_mistakeCount == 0` for `isCorrect = true`. Any wrong tap during matching results in 0 XP even if all pairs eventually matched.
7. **find_words auto-submits** — When selection count equals `correctAnswers.length`, answer submits automatically (no confirm button).
8. **Chapter completion = all activities completed** — `isChapterCompleteProvider` returns `true` when `completedActivities.length >= totalActivities`. If `totalActivities == 0`, chapter is immediately complete.
9. **Re-opened chapters show all activities as "correct"** — `getCompletedInlineActivities` returns only activity IDs (not correctness), and `loadFromList` sets all to `wasCorrect = true`.

## Cross-System Interactions

### Activity Completion Chain
```
Student answers activity
  → inlineActivityStateProvider: mark completed locally (dedup)
  → CompleteInlineActivityUseCase:
    → bookRepository.saveInlineActivityResult (DB INSERT, UNIQUE dedup)
    → IF has vocabularyWords:
      → vocabularyRepository.addWordsToVocabularyBatch (SM-2 init)
  → IF isNewCompletion:
    → invalidate(dailyQuestProgressProvider) — quest "correct_answers" type counts this
    → IF isCorrect AND xp > 0:
      → sessionXPProvider.addXP (session counter)
      → userControllerProvider.addXP (Supabase award_xp_transaction RPC)
        → xp_logs INSERT (idempotency via source/sourceId)
        → profiles.xp_total += xp
        → CheckAndAwardBadgesUseCase (auto badge check)
  → IF has wordsLearned:
    → learnedWordsProvider.addWords (session state)
    → invalidate: dailyReviewWordsProvider, userVocabularyProgressProvider, learnedWordsWithDetailsProvider
```

### What This System Does NOT Trigger
- **Streak**: Updated on app open only (`_updateStreakIfNeeded`), not per-activity
- **Assignment progress**: Tracked at chapter level, not per inline activity
- **Coins**: No coin reward for inline activities

## Edge Cases

| Scenario | Current Behavior |
|----------|-----------------|
| Chapter with 0 activities | `isChapterComplete` returns `true` immediately — completion UI shown |
| Activity load failure (network error) | `_loadCompletedActivities` swallows error, `chapterInitializedProvider` never set to `true`, progressive reveal broken (#2) |
| DB save failure | Activity shown as completed locally, but server has no record. No user feedback. On re-open, activity appears uncompleted again (#3) |
| Already-completed activity | Shows completed state with green/red header. Cannot re-attempt. |
| Unknown activity type in DB | Silently rendered as empty true/false with `correctAnswer: true` (#12) |
| Duplicate right-values in matching | Second identical value disabled immediately, activity unsolvable (#14) |
| Empty options list | `word_translation`/`find_words`: crash on `.first` in completed-wrong state (#21). `find_words` with 0 `correctAnswers`: auto-submit immediately (#22) |
| Offline completion | Result saved to SQLite cache with `is_dirty = true`, synced later. XP awarded optimistically. |
| Offline cold start | `getCompletedInlineActivities` falls to network, fails — all activities appear uncompleted (#24) |

## Test Scenarios

- [ ] Happy path: Complete each of 4 activity types correctly — XP awarded, green header shown, activity marked complete
- [ ] Incorrect answer: Complete activity with wrong answer — 0 XP, red header, still marked complete, cannot retry
- [ ] Idempotency: Complete same activity twice rapidly — only one XP award, second attempt no-op
- [ ] Vocabulary integration: Complete `word_translation` activity with `vocabularyWords` — words appear in Word Bank and Daily Review
- [ ] true_false vocab: Complete `true_false` with `vocabularyWords` populated — words are NOT added to vocabulary
- [ ] Chapter completion: Complete all activities in chapter — completion widget appears
- [ ] No activities: Open chapter with 0 activities — completion widget shown immediately
- [ ] Matching mistakes: Make 1 wrong tap then correct all pairs — 0 XP awarded (strict scoring)
- [ ] Re-open completed chapter: Previously completed activities show as completed (all show "correct" regardless of actual result)
- [ ] Offline: Complete activity offline — result cached, synced on reconnect
- [ ] Daily quest: Complete correct-answer activity — `correct_answers` quest type progress increments
- [ ] Badge check: Verify badge conditions evaluated after XP award
- [ ] Activity type error: Insert unknown type in DB — app should handle gracefully (currently: silent empty true/false)

## Key Files

| Surface | File | Purpose |
|---------|------|---------|
| Domain | `lib/domain/entities/activity.dart` | `InlineActivity`, content types (`TrueFalseContent`, `WordTranslationContent`, `FindWordsContent`, `MatchingContent`) |
| Domain | `lib/domain/usecases/activity/complete_inline_activity_usecase.dart` | Orchestrates DB save + vocabulary batch |
| Shared | `packages/owlio_shared/lib/src/enums/inline_activity_type.dart` | `InlineActivityType` enum with DB values |
| Data | `lib/data/models/activity/inline_activity_model.dart` | JSON serialization for all types |
| Data | `lib/data/repositories/supabase/supabase_book_repository.dart` (lines 391-479) | Supabase queries for inline activities |
| Presentation | `lib/presentation/providers/reader_provider.dart` | State providers + `handleInlineActivityCompletion` orchestrator |
| Presentation | `lib/presentation/widgets/reader/reader_activity_block.dart` | Dispatches to activity-type widgets |
| Presentation | `lib/presentation/widgets/inline_activities/` | All 4 activity type widgets |
| Admin | `owlio_admin/lib/features/books/widgets/activity_editor.dart` | Activity CRUD editor |

## Known Issues & Tech Debt

1. **Missing index** (#1): `inline_activity_results(user_id, answered_at)` needed for daily quest performance. Fix: add partial index with `WHERE is_correct = true`.
2. **Dual rendering paths** (#9): Legacy paragraph-interleave path must be maintained alongside content-blocks path until all books are migrated. Removing legacy path requires migrating all chapter content.
3. **`xp_reward` column dead** (#6): DB column exists but SystemSettings always overrides. Decision needed: remove column or implement per-activity XP override.
4. **`words_learned` column unpopulated** (#8): Schema column never written to. Either populate it in `saveInlineActivityResult` or drop the column.
5. **Dead code accumulation** (#4, #5, #7, #17, #18): `SaveInlineActivityResultUseCase`, `InlineActivityWrapper` file, widgetbook imports, `InlineActivityResult` model methods, and `SingleTickerProviderStateMixin` — safe to remove.
6. **Error handling gap** (#3): DB save failure needs user-visible feedback and/or retry mechanism.
7. **Initialization resilience** (#2): `chapterInitializedProvider` should be set in a `finally` block to prevent broken state on load failure.
