# Word Lists

## Audit

### Findings

| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Bug | `starCount` thresholds inconsistent: `UserWordListProgress` uses 95/80 (student-facing), `StudentWordListProgress` uses 90/70/50 (teacher-facing). Same data, different stars displayed. | High | Fixed |
| 2 | Architecture | `session_summary_screen.dart` imports domain UseCase classes directly and orchestrates multiple UseCases inline. Business logic in a screen. | High | Fixed |
| 3 | Architecture | `WordListCategoryIcon` extension in `word_list.dart` returns emoji strings — UI concern living in domain entity layer. | Medium | Fixed |
| 4 | Security | `complete_vocabulary_session` RPC accepts `p_user_id` as parameter without verifying it matches `auth.uid()`. RPC is `SECURITY DEFINER` so it bypasses RLS. | Medium | Fixed |
| 5 | Bug | `isComplete` semantics differ: `UserWordListProgress.isComplete` = `totalSessions > 0`, `StudentWordListProgress.isComplete` = `completedAt != null`. | Medium | Fixed |
| 6 | Dead Code | `UpdateWordListProgressUseCase` + provider registered but never called. | Medium | Fixed |
| 7 | Dead Code | `getVocabularyUnits()` in `WordListRepository` — no use case, no provider, no callers. | Low | Fixed |
| 8 | Dead Code | `UserWordListProgress.progressPercentage` computed property — zero callers in `lib/`. | Low | Fixed |
| 9 | Dead Code | `WordListModel.fromEntity` — never called from repository or elsewhere. | Low | Fixed |
| 10 | Code Quality | `WordListModel._parseCategory` / `categoryToString` duplicate logic already in `WordListCategory.fromDbValue()` / `.dbValue` from owlio_shared. | Medium | Fixed |
| 11 | Code Quality | `_getCategoryColor` switch duplicated in both `word_list_detail_screen.dart` and `category_browse_screen.dart`. | Low | Fixed |
| 12 | Code Quality | `StudentWordListProgress.wordListCategory` is `String` not `WordListCategory` — raw DB value leaks to presentation. | Low | Fixed |
| 13 | Performance | `category_browse_screen.dart` watches `progressForListProvider(list.id)` per item — N separate queries instead of one batch. | Medium | Fixed |
| 14 | Performance | `getAllWordLists` has no pagination — unbounded fetch of all word lists. | Low | Fixed |
| 15 | Edge Case | `vocabulary_hub_screen.dart` has no loading/error state for `storyWordListsProvider`. Silent failure. | Medium | Fixed |
| 16 | Edge Case | `word_list_detail_screen.dart` `wordsAsync`/`progressAsync` errors silently swallowed. | Medium | Fixed |
| 17 | Edge Case | `vocabulary_screen.dart` (Word Bank) has no error state for `learnedWordsWithDetailsProvider`. | Low | Fixed |
| 18 | Dead Code | `dueForReviewProvider` — no consumers found in word-list flow. | Low | Fixed |
| 19 | Dead Code | Stale comments: `vocabulary_session_screen.dart` (thinking-out-loud block), `path_node.dart` (placeholder comment). | Low | Fixed |
| 20 | Code Quality | Turkish comment in `vocabulary_session_screen.dart` (`"Tekrar Calis"`). Removed with retryWordIds. | Low | Fixed |
| 21 | Code Quality | `session_summary_screen.dart` had 3 `debugPrint` statements in production paths. | Low | Fixed |
| 22 | Test Coverage | `CompleteSessionUseCase`, `GetSessionHistoryUseCase`, `GetUserLearningPathsUseCase` have no unit tests (3 of 10 use cases untested). | Low | Deferred |
| 23 | Database | `word_list_items` has no reverse index on `word_id`. No current query needs it. | Low | Deferred |
| 24 | Database | Original migration comments (phase1–4 system) are stale after v2 migration. No runtime impact. | Low | Deferred |

### Checklist Result

- **Architecture Compliance**: PASS — UseCase orchestration extracted to `SessionSaveNotifier` (#2). UI extension moved to `ui_helpers.dart` (#3).
- **Code Quality**: PASS — Shared enum for category parsing (#10). Centralized color helper (#11). Typed `WordListCategory` enum (#12). Turkish comment removed (#20). debugPrints removed (#21).
- **Dead Code**: PASS — All removed: UseCase (#6), repo method (#7), computed property (#8), fromEntity (#9), dead provider (#18), stale comments (#19).
- **Database & Security**: PASS — Auth check added to RPC (#4). RLS policies correct. Indexes adequate.
- **Edge Cases & UX**: PASS — Error states added to hub (#15), detail (#16), and word bank (#17) screens.
- **Performance**: PASS — Batch progress loading in category browse (#13). Pagination guard on getAllWordLists (#14).
- **Cross-System Integrity**: PASS — XP via `award_xp_transaction` with delta anti-farming. Badge check fires every session. Assignment completion via `SessionSaveNotifier`. Daily quest counts sessions correctly. Streak decoupled (login-based only).

---

## Overview

Word Lists organize vocabulary words into themed, categorized collections for structured study. Admins create word lists via the admin panel with drag-and-drop word ordering. Students encounter lists through a learning path (sequential unlock) or browse by category. Each list can be studied in vocabulary sessions (documented in spec #5). Progress is tracked per-list with a star rating system based on best accuracy. Teachers view per-student word list progress through the student detail screen.

## Data Model

### Tables

| Table | Key Columns | Purpose |
|-------|-------------|---------|
| `word_lists` | id, name, description, level (CHECK: A1–C2), category (CHECK: common_words/grade_level/test_prep/thematic/story_vocab), word_count, cover_image_url, is_system, source_book_id (FK books), unit_id (FK vocabulary_units), order_in_unit | Collection metadata. `is_system=true` for admin-created, `false` for auto-generated story vocab. `unit_id`+`order_in_unit` position it in a learning path. |
| `word_list_items` | word_list_id (FK CASCADE), word_id (FK CASCADE), order_index, UNIQUE(word_list_id, word_id) | Junction table with explicit ordering. Trigger auto-updates `word_lists.word_count` on INSERT/DELETE. |
| `user_word_list_progress` | user_id (FK CASCADE), word_list_id (FK CASCADE), best_score, best_accuracy (DECIMAL 5,2), total_sessions, last_session_at, started_at, completed_at, UNIQUE(user_id, word_list_id) | Session-based progress. Upserted atomically by the `complete_vocabulary_session` RPC. `best_score` and `best_accuracy` only increase (GREATEST). `completed_at` set on first session via COALESCE. |
| `vocabulary_units` | id, name, description, sort_order, is_active | Groups word lists into units for learning path organization. |

### Key Relationships

- `word_lists` → `vocabulary_words` via `word_list_items` (many-to-many with order)
- `word_lists` → `vocabulary_units` via `unit_id` (optional; null = standalone list)
- `word_lists` → `books` via `source_book_id` (optional; for story vocabulary)
- `user_word_list_progress` → `profiles` via `user_id` (cascading delete)

### Categories (WordListCategory enum, owlio_shared)

| DB Value | Display Name | Use |
|----------|-------------|-----|
| `common_words` | Common Words | General-purpose vocabulary |
| `grade_level` | Grade Level | Age/grade-appropriate words |
| `test_prep` | Test Prep | Exam preparation vocabulary |
| `thematic` | Thematic | Topic-based collections |
| `story_vocab` | Story Vocab | Auto-generated from book content |

## Surfaces

### Admin

- **Word List CRUD**: Create/edit/delete word lists with name, description, level, category, unit assignment, cover image.
- **Word Picker**: Search and add words from `vocabulary_words` table. Drag-and-drop reordering of `word_list_items` via `order_index`.
- **Audio Generation**: Generate TTS audio for words via Supabase Edge Function (`generate-audio`).
- **Unit Filter**: Filter word lists by vocabulary unit on the list screen.
- **Key workflows**: Create list → add words → set order → assign to unit → list appears in learning path.
- Admin panel UI is in Turkish (per CLAUDE.md exception).

### Student

**Learning Path Flow (primary):**
1. Student opens Vocabulary Hub → sees learning path with word list nodes
2. Sequential lock: each list unlocks only when the prior one is complete (if path has `sequentialLock=true`)
3. Daily Review gate: if due words exist, a gate node blocks progress until daily review is done
4. Tap a word list node → bottom sheet shows list details (name, word count, star rating)
5. "Start" button → vocabulary session screen (10 question types, 3 phases — see spec #5)
6. Session complete → summary screen → saves via `complete_vocabulary_session` RPC
7. Star rating appears on the path node (1–3 stars based on best accuracy)

**Category Browse Flow (secondary):**
1. Vocabulary Hub → "Browse" → `CategoryBrowseScreen`
2. Filter by category (common_words, grade_level, etc.)
3. Each list card shows name, word count, level badge, progress stars
4. Tap → `WordListDetailScreen` → see words, stats, start session button

**Word List Detail Screen:**
- Shows all words in the list with translations/images
- Displays progress stats (best accuracy, sessions, stars)
- Daily limit check: `canStartWordListProvider` limits new list starts per day (exempts in-progress lists)
- "Start Session" or "Practice Again" button depending on progress state

**Star Rating (unified across student and teacher):**
- 3 stars: best accuracy ≥ 90%
- 2 stars: best accuracy ≥ 70%
- 1 star: best accuracy ≥ 50%
- 0 stars: < 50% or not attempted

### Teacher

- **Student Detail Screen**: Shows per-student word list progress via `get_student_word_list_progress` RPC
- **Stats**: Total words learned, lists started/completed, total sessions (via `get_student_vocab_stats` RPC)
- **Star Rating**: Same thresholds as student (90/70/50/0)

## Business Rules

1. **Completion = first session**: `completed_at` is set via `COALESCE(completed_at, NOW())` on the first session, regardless of accuracy. There is no minimum pass threshold for word lists (unlike book quizzes at 70%).
2. **Star rating unified**: Both student and teacher use 90/70/50/0 thresholds.
3. **Best-only tracking**: `best_score` and `best_accuracy` only increase via `GREATEST()` in the RPC upsert. Replaying cannot worsen your record.
4. **XP delta anti-farming**: XP awarded = `GREATEST(0, total_xp - previous_best)`. Replaying a list only earns XP above the previous best score.
5. **Daily list start limit**: `canStartWordListProvider` enforces a per-day limit on starting new word lists (configurable via system settings). Already-started lists are exempt.
6. **Sequential unlock**: When a learning path has `sequentialLock=true`, each word list unlocks only after the prior item's `completedAt` is set.
7. **Word count auto-sync**: DB trigger on `word_list_items` INSERT/DELETE automatically maintains `word_lists.word_count`.
8. **Combo bonus**: Calculated client-side as `maxCombo * settings.comboBonusXp` (default 5), capped at x5 multiplier. Folded into `p_xp_earned` before RPC call.
9. **Session bonus from system_settings**: +10 XP per session (key: `xp_vocab_session_bonus`), +20 XP for 100% accuracy (key: `xp_vocab_perfect_bonus`).

## Cross-System Interactions

### XP Flow
```
Session complete → client calculates combo bonus → RPC: complete_vocabulary_session
  → v_total_xp = p_xp_earned + session_bonus(10) + perfect_bonus(20 if 100%)
  → v_xp_to_award = GREATEST(0, v_total_xp - previous_best)  [delta anti-farming]
  → award_xp_transaction('vocabulary_session', session_id)
  → profiles.xp += v_xp_to_award
  → xp_logs INSERT
```

### Badge Check
```
RPC (always, even on zero-delta replays) → PERFORM check_and_award_badges(p_user_id)
  → Checks: vocabulary_learned (mastered word count), xp_total, level_completed
```

### Assignment Completion (client-side)
```
session_summary_screen → _completeVocabularyAssignment()
  → GetActiveAssignmentsUseCase → match by wordListId
  → CompleteAssignmentUseCase (score = accuracy %)
  → IF unit assignment: CalculateUnitProgressUseCase
    → RPC counts completed items in unit → auto-complete at 100%
```

### Daily Quest
```
complete_vocabulary_session → vocabulary_sessions INSERT
  → get_daily_quest_progress counts today's sessions
  → IF quest type = 'vocab_session' AND count >= goal: auto-award quest XP (15)
```

### SM-2 Spaced Repetition
```
RPC per word:
  → Strong (0 incorrect): interval grows (1d → 6d → interval * ease_factor, cap 365d)
  → Weak (>0 incorrect): reset to interval=0, ease_factor -= 0.2 (min 1.3)
  → Status: learning → reviewing → mastered (interval > 21 days, never downgrades)
  → vocabulary_progress upsert → feeds daily review due words
```

### Learning Path
```
Session save → provider invalidation → learningPathProvider rebuilds
  → Sequential lock: checks completedAt for each item
  → Newly completed list → next item unlocks
```

### Streak
No interaction. Streak is login-based only (removed from vocabulary RPCs).

## Edge Cases

- **Empty word list**: If a word list has 0 words, session cannot start (no words to load). No explicit guard in UI — the session screen loads words and would show nothing.
- **Network failure during save**: If `_saveSession()` fails, `_completeVocabularyAssignment()` never runs. Assignment stays in-progress. Student must replay the list to trigger assignment completion again. No server-side retry mechanism.
- **Replay with delta = 0**: Session saves, badges check, daily quest counts, but no XP awarded. This is correct behavior.
- **Concurrent sessions**: No mutex. If a student somehow opens two sessions for the same list, both could save independently. The `GREATEST` upsert ensures the best result survives.
- **Deleted word list**: `word_list_items` CASCADE deletes word associations. `user_word_list_progress` CASCADE deletes progress. Learning path items referencing the list would have a dangling `word_list_id`.
- **Story vocab lists**: Auto-generated with `is_system=false`, `source_book_id` set. Appear in "My Word Lists" section on hub, not in the main learning path.

## Test Scenarios

- [ ] Happy path: Browse lists by category → select list → start session → complete → verify stars appear, XP awarded
- [ ] Happy path: Learning path → tap locked list → verify lock message → complete prior list → verify next unlocks
- [ ] Empty state: Category with no word lists → verify empty state message
- [ ] Empty state: New user with no progress → verify all stars at 0, lists accessible (if not locked)
- [ ] Error state: Kill network during session save → verify retry option shown
- [ ] Boundary: Complete session with 100% accuracy → verify 3 stars + perfect bonus XP
- [ ] Boundary: Complete session with exactly 80% accuracy → verify 2 stars (not 3)
- [ ] Boundary: Daily list start limit reached → verify "limit reached" banner, in-progress lists still accessible
- [ ] Cross-system: Complete a vocab-assigned list → verify assignment auto-completes
- [ ] Cross-system: Complete list that finishes a unit → verify unit assignment progress = 100%
- [ ] Cross-system: Replay a list with same score → verify 0 XP awarded (delta mechanism)
- [ ] Cross-system: Complete session → verify daily quest progress increments
- [ ] Teacher: View student detail → verify word list progress with correct star counts
- [ ] Admin: Create word list → add words → reorder → verify order_index saved correctly

## Key Files

### App (Student)
- `lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart` — Hub with learning path + category browse entry
- `lib/presentation/providers/vocabulary_provider.dart` — All word list state, learning path construction, progress tracking
- `lib/presentation/screens/vocabulary/session_summary_screen.dart` — Post-session save + cross-system triggers

### App (Domain)
- `lib/domain/entities/word_list.dart` — `WordList` + `UserWordListProgress` entities
- `lib/domain/repositories/word_list_repository.dart` — Repository contract
- `lib/data/repositories/supabase/supabase_word_list_repository.dart` — Supabase implementation

### Admin
- `owlio_admin/lib/features/wordlists/screens/wordlist_edit_screen.dart` — Word list editor with word picker

### Teacher
- `lib/domain/entities/teacher.dart` — `StudentWordListProgress` entity
- `lib/domain/usecases/teacher/get_student_word_list_progress_usecase.dart`

### Database
- `supabase/migrations/20260131000004_create_word_list_tables.sql` — Original schema + word_count trigger
- `supabase/migrations/20260207000002_vocabulary_session_v2.sql` — Phase columns → session-based tracking
- `supabase/migrations/20260323000016_update_vocab_session_rpc_settings.sql` — Current `complete_vocabulary_session` RPC

### Shared
- `packages/owlio_shared/lib/src/enums/word_list_category.dart` — `WordListCategory` enum

## Known Issues & Tech Debt

1. **Assignment completion is client-side**: If the app crashes after session save but before `SessionSaveNotifier._completeAssignments()` runs, the assignment is orphaned. A server-side trigger or idempotent retry would improve reliability.
2. **Missing unit tests (#22)**: `CompleteSessionUseCase`, `GetSessionHistoryUseCase`, `GetUserLearningPathsUseCase` have no unit tests.
3. **Missing reverse index (#23)**: `word_list_items` has no index on `word_id`. No current query needs it but the junction table lacks bidirectional coverage.
