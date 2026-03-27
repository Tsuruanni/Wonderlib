# Word Lists Audit Fixes Design

## Summary

Fix 20 issues identified in the Feature #6 (Word Lists) audit. Covers bug fixes, architecture violations, security, dead code removal, code quality, performance, missing error states, and stale code cleanup.

Deferred: 4 items (#22 missing tests, #23 missing DB index, #24 stale migration comments).

## Scope

### Group 1: Star Count & isComplete Unification (#1, #5)

**Files:** `lib/domain/entities/word_list.dart`, `lib/domain/entities/teacher.dart`

**Star thresholds** — Unify both entities to 90/70/50/0:
- `UserWordListProgress.starCount`: change from `95/80/any` to `90/70/50/0`
- `StudentWordListProgress.starCount`: already correct, no change

**isComplete** — Unify to `completedAt != null`:
- `UserWordListProgress.isComplete`: change from `totalSessions > 0` to `completedAt != null`
- Functionally equivalent (RPC sets `completedAt` on first session via COALESCE) but semantically correct

---

### Group 2: Session Summary Architecture (#2)

**Problem:** `session_summary_screen.dart` imports 4 domain UseCase classes and orchestrates multi-step business logic (session save, assignment matching, unit progress calculation) directly in the screen.

**Fix:** Extract to a `SessionSaveNotifier` in `vocabulary_provider.dart`:
- StateNotifier managing save lifecycle (`idle`, `saving`, `saved`, `error`)
- Encapsulates: `CompleteSessionUseCase` call, `GetActiveAssignmentsUseCase` + match by wordListId, `CompleteAssignmentUseCase`, `CalculateUnitProgressUseCase`, all provider invalidations
- Screen calls `ref.read(sessionSaveProvider.notifier).save(params)` — single entry point
- Remove all 4 domain UseCase imports from the screen
- Screen observes `sessionSaveProvider` state for UI (saving indicator, success, error with retry)

---

### Group 3: UI Code in Domain (#3)

**Problem:** `WordListCategoryIcon` extension in `word_list.dart:57-72` returns emoji strings — UI concern in domain layer.

**Fix:**
- Create `lib/presentation/extensions/word_list_category_extensions.dart`
- Move `WordListCategoryIcon` extension there
- Also add `_getCategoryColor` as `WordListCategoryColor` extension in the same file (solves #11)
- Remove extension from `word_list.dart`
- Update 4 import sites (vocabulary_hub_screen, category_browse_screen, word_list_detail_screen, path_node)

---

### Group 4: Security — RPC Auth Check (#4)

**Problem:** `complete_vocabulary_session` RPC accepts `p_user_id` without verifying `auth.uid()`. SECURITY DEFINER bypasses RLS.

**Fix:** New migration adding auth guard:
```sql
IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Not authorized: user mismatch';
END IF;
```
Same pattern already used in `calculate_unit_assignment_progress` (migration `20260326000016`).

**File:** `supabase/migrations/YYYYMMDDHHMMSS_add_auth_check_to_vocab_session_rpc.sql`

---

### Group 5: Dead Code Removal (#6, #7, #8, #9, #18)

| Item | What to Delete | Files Affected |
|------|---------------|----------------|
| #6 | `UpdateWordListProgressUseCase`, its provider, `updateWordListProgress` in repo interface + impl | `update_word_list_progress_usecase.dart` (delete file), `word_list_repository.dart`, `supabase_word_list_repository.dart`, `usecase_providers.dart` |
| #7 | `getVocabularyUnits()` from repo interface + impl | `word_list_repository.dart`, `supabase_word_list_repository.dart` |
| #8 | `progressPercentage` getter | `word_list.dart` |
| #9 | `fromEntity` factory method | `word_list_model.dart` |
| #18 | `dueForReviewProvider` | `vocabulary_provider.dart` |

Also delete `WordListModel.categoryToString` static method after Group 6 replaces it with `.dbValue`.

---

### Group 6: Code Quality (#10, #11, #12, #20, #21)

**#10 — Duplicate category parsing:**
- Replace `WordListModel._parseCategory(str)` with `WordListCategory.fromDbValue(str)`
- Replace `WordListModel.categoryToString(cat)` with `cat.dbValue`
- Update call site in `supabase_word_list_repository.dart` (line 55)

**#11 — Duplicate `_getCategoryColor`:**
- Handled by Group 3: moved to `word_list_category_extensions.dart` as a shared extension
- Remove duplicate from both `word_list_detail_screen.dart` and `category_browse_screen.dart`

**#12 — Raw string category in teacher entity:**
- Change `StudentWordListProgress.wordListCategory` type from `String` to `WordListCategory`
- Parse in `StudentWordListProgressModel.toEntity()` via `WordListCategory.fromDbValue(wordListCategory)`
- Update `StudentWordListProgressModel.wordListCategory` to remain `String` (raw from RPC), conversion happens in `toEntity()`
- Update presentation call sites that currently call `WordListCategory.fromDbValue(progress.wordListCategory)` manually — they can now use `progress.wordListCategory` directly

**#20 — Turkish comment:**
- `vocabulary_session_screen.dart:37`: change `// If set, only these words (for "Tekrar Calis")` to `// If set, only these words (for "Practice Again" retry flow)`

**#21 — debugPrint statements:**
- Remove all 3 from `session_summary_screen.dart` (lines 125, 197, 209). Error handling is already present via snackbar/UI — debug prints are redundant.

---

### Group 7: Performance (#13, #14)

**#13 — N+1 progress queries in CategoryBrowseScreen:**
- Watch `userWordListProgressProvider` once at screen level
- Build `Map<String, UserWordListProgress>` by `wordListId`
- Pass pre-looked-up progress to each list card widget
- Remove per-item `progressForListProvider(list.id)` watches

**#14 — Unbounded getAllWordLists:**
- Add `.limit(500)` safety guard to the Supabase query in `supabase_word_list_repository.dart`
- Admin-curated content won't reach this, but prevents runaway fetches

---

### Group 8: Missing Error States (#15, #16, #17)

**#15 — vocabulary_hub_screen.dart:**
- Replace `.valueOrNull` usage for `storyWordListsProvider` with proper `.when()` handling
- Add loading shimmer for the "My Word Lists" section
- Add error message with retry for fetch failures

**#16 — word_list_detail_screen.dart:**
- Add error branches for `wordsAsync` and `progressAsync`
- Show inline error message with retry action when either provider fails

**#17 — vocabulary_screen.dart (Word Bank):**
- Add error branch for `learnedWordsWithDetailsProvider`
- Show error state with retry option instead of silent empty list

---

### Group 9: Stale Code Cleanup (#19 + retryWordIds)

- Remove comment block at `vocabulary_session_screen.dart:299-303` (thinking-out-loud)
- Remove placeholder comment at `path_node.dart:491` (`// ... (existing helper methods)`)
- Remove unused `retryWordIds` parameter from `VocabularySessionScreen` constructor and its handling in `_loadAndStart()` (confirmed: never populated by any call site)
- Remove corresponding `state.extra as List<String>?` in `router.dart`

---

## Out of Scope (Deferred)

| # | Item | Reason |
|---|------|--------|
| 22 | Missing tests for 3 use cases | Test expansion is a separate task |
| 23 | Missing reverse index on `word_list_items(word_id)` | No current query needs it |
| 24 | Stale migration comments | No runtime impact |

## Verification

After all fixes:
1. `dart analyze lib/` must pass with no errors
2. Manual test: browse word lists by category, start a session, complete it, verify stars appear correctly
3. Verify admin word list editor still functions (no regressions from category parsing change)
4. `supabase db push --dry-run` for the auth migration
