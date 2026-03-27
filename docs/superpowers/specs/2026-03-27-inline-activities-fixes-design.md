# Inline Activities Fixes

Fixes for all 25 findings from the Inline Activities audit (`docs/specs/03-inline-activities.md`). Grouped into 3 phases by domain: DB + data integrity, dead code + code quality, UX polish.

**Scope:** Findings #1-#25. Four findings deferred/accepted: #9 (dual rendering paths — accepted until legacy migration complete), #16 (double round trip — optimization, low priority), #19 (free function — accepted per locality of behavior), #24 (partially covered by #2 fix).

**Approach:** Phase-sequential. Each phase is a separate commit. Total: 21 actionable fixes.

---

## Phase 1: DB + Data Integrity (5 fixes)

### 1.1 — Missing index for daily quest queries (#1)

**Problem:** `get_quest_progress` RPC counts correct answers per day from `inline_activity_results` using `WHERE user_id = X AND answered_at >= today AND is_correct = true`. No index covers this — sequential scan on every quest progress check.

**Fix:** New migration:

```sql
CREATE INDEX idx_inline_activity_results_user_answered
  ON inline_activity_results (user_id, answered_at DESC)
  WHERE is_correct = true;
```

Partial index matches the query filter exactly and halves index size.

**Files:**
- `supabase/migrations/YYYYMMDD_add_inline_results_index.sql` (new)

### 1.2 — `chapterInitializedProvider` not set on load failure (#2)

**Problem:** `reader_screen.dart:91-108` — `_loadCompletedActivities` sets `chapterInitializedProvider = true` only inside `try`. If network fails, `catch` returns silently. Progressive reveal, scroll-to-next, and auto-play triggers break for the entire reading session.

**Fix:** Move `chapterInitializedProvider = true` to a `finally` block:

```dart
Future<void> _loadCompletedActivities() async {
  try {
    ref.read(inlineActivityStateProvider.notifier).reset();
    ref.invalidate(completedInlineActivitiesProvider(widget.chapterId));
    final completedResult = await ref.read(
      completedInlineActivitiesProvider(widget.chapterId).future,
    );
    if (!mounted) return;
    ref.read(inlineActivityStateProvider.notifier).loadFromMap(completedResult);
  } catch (_) {
    // Network/disposed error — proceed with empty completed list
  } finally {
    if (mounted) {
      ref.read(chapterInitializedProvider.notifier).state = true;
    }
  }
}
```

**Files:**
- `lib/presentation/screens/reader/reader_screen.dart`

### 1.3 — DB save failure silently swallowed (#3)

**Problem:** `reader_provider.dart:401-406` — when `CompleteInlineActivityUseCase` returns `Left(failure)`, the activity is already marked completed locally (line 384) but the server has no record. No user feedback, no rollback.

**Fix:**
1. Add `removeCompleted(String activityId)` method to `InlineActivityStateNotifier`
2. On failure, rollback local state — the widget rebuilds to unanswered state (this IS the user feedback: the activity reappears, student can retry)

```dart
// In InlineActivityStateNotifier:
void removeCompleted(String activityId) {
  state = Map.from(state)..remove(activityId);
}

// In _handleInlineActivityCompletionImpl, after result.fold:
final completionResult = result.fold(
  (failure) {
    // Rollback local state
    ref.read(inlineActivityStateProvider.notifier).removeCompleted(activityId);
    return null;
  },
  (r) => r,
);
```

The activity widget's `onAnswer` callback already handles UI state (showing correct/incorrect feedback). On rollback, the widget rebuilds because `inlineActivityStateProvider` changes — the activity returns to its unanswered state, allowing the student to retry.

**Files:**
- `lib/presentation/providers/reader_provider.dart` — add `removeCompleted`, update failure handling

### 1.4 — `words_learned` column never populated (#8)

**Problem:** `inline_activity_results.words_learned TEXT[]` exists in schema but `saveInlineActivityResult` never writes it. The column is always `{}`.

**Fix:** Add `wordsLearned` parameter through the chain:

```
BookRepository.saveInlineActivityResult(..., {List<String> wordsLearned = const []})
  → SupabaseBookRepository: include 'words_learned' in INSERT
  → CachedBookRepository: pass through to remote + cache
  → CompleteInlineActivityUseCase: pass params.wordsLearned to saveInlineActivityResult
```

**Files:**
- `lib/domain/repositories/book_repository.dart` — add `wordsLearned` param to interface
- `lib/data/repositories/supabase/supabase_book_repository.dart` — include in INSERT
- `lib/data/repositories/cached/cached_book_repository.dart` — pass through
- `lib/domain/usecases/activity/complete_inline_activity_usecase.dart` — pass `params.wordsLearned`

### 1.5 — Completed activities show wrong correctness on re-open (#20)

**Problem:** `getCompletedInlineActivities` returns `List<String>` (only IDs). `loadFromList` sets all to `wasCorrect = true`. Previously-wrong answers display as correct.

**Fix:** Change return type from `List<String>` to `Map<String, bool>` (activityId → isCorrect):

```
BookRepository.getCompletedInlineActivities → Future<Either<Failure, Map<String, bool>>>
  → SupabaseBookRepository: SELECT inline_activity_id, is_correct
  → CachedBookRepository: same change
  → completedInlineActivitiesProvider: returns Map<String, bool>
  → InlineActivityStateNotifier.loadFromMap(Map<String, bool>): use actual values
```

Rename `loadFromList` → `loadFromMap` to reflect the new signature.

**Files:**
- `lib/domain/repositories/book_repository.dart` — change return type
- `lib/data/repositories/supabase/supabase_book_repository.dart` — `select('inline_activity_id, is_correct')`
- `lib/data/repositories/cached/cached_book_repository.dart` — adapt
- `lib/presentation/providers/reader_provider.dart` — `loadFromMap`, provider type change
- `lib/presentation/screens/reader/reader_screen.dart` — call `loadFromMap`

---

## Phase 2: Dead Code Removal + Code Quality (10 fixes)

### 2.1 — Remove `SaveInlineActivityResultUseCase` (#4)

**Files to delete:**
- `lib/domain/usecases/activity/save_inline_activity_result_usecase.dart`

**Files to edit:**
- `lib/presentation/providers/usecase_providers.dart` — remove `saveInlineActivityResultUseCaseProvider`

### 2.2 — Remove `inline_activity_wrapper.dart` (#5)

**File to delete:**
- `lib/presentation/widgets/inline_activities/inline_activity_wrapper.dart`

Check barrel export `inline_activities.dart` — if it exports this file, remove the export.

### 2.3 — Remove `InlineActivity.xpReward` field (#6)

**Files:**
- `lib/domain/entities/activity.dart` — remove `xpReward` field from `InlineActivity`, remove from `props`
- `lib/data/models/activity/inline_activity_model.dart` — stop parsing `xp_reward` from JSON, stop passing to entity constructor

### 2.4 — Fix or remove widgetbook broken imports (#7)

The file references non-existent paths and uses dead classes (`ActivityWrapper`). Remove the entire file since it's unmaintainable.

**File to delete:**
- `widgetbook/lib/components/activity_widgets.dart`

Check `widgetbook/lib/main.dart` or equivalent — remove reference to `activityWidgets` if present.

### 2.5 — Use shared enum methods instead of redundant parsing (#10)

**File:**
- `lib/data/models/activity/inline_activity_model.dart`

Replace:
- `_parseInlineActivityType(json['type'])` → `InlineActivityType.fromDbValue(json['type'])`
- `_inlineActivityTypeToString(entity.type)` → `entity.type.dbValue`

Delete the two private helper methods.

### 2.6 — Remove dead `InlineActivityResult` model methods (#17)

Phase 1.5 changes `getCompletedInlineActivities` to return `Map<String, bool>` — this uses inline parsing, not `InlineActivityResultModel.fromJson`. Confirm these remain unused after Phase 1, then remove:

**File:**
- `lib/data/models/activity/inline_activity_model.dart` — remove `InlineActivityResultModel.fromJson` and `toEntity`

Keep `InlineActivityResultModel.toJson` only if used by cached repository for SQLite writes. If not, remove the entire class.

### 2.7 — Remove unused `SingleTickerProviderStateMixin` (#18)

**File:**
- `lib/presentation/widgets/inline_activities/inline_find_words_activity.dart` — remove `with SingleTickerProviderStateMixin` from state class

(Phase 3.1 adds `InlineActivitySoundMixin` in its place.)

### 2.8 — Empty options guard clauses (#21)

**Files:**
- `lib/presentation/widgets/inline_activities/inline_word_translation_activity.dart` — in completed-wrong state, guard `options.isEmpty` before `.first`
- `lib/presentation/widgets/inline_activities/inline_find_words_activity.dart` — same guard

Replace `orElse: () => content.options.first` with `orElse: () => content.options.isNotEmpty ? content.options.first : ''`.

### 2.9 — Zero-length `correctAnswers` auto-submit guard (#22)

**File:**
- `lib/presentation/widgets/inline_activities/inline_find_words_activity.dart`

Add guard at the top of `_toggleWord` or in the auto-submit check:

```dart
if (requiredSelections == 0) return; // No correct answers defined, don't auto-submit
```

### 2.10 — Unknown type explicit handling (#12)

**File:**
- `lib/data/models/activity/inline_activity_model.dart`

After Phase 2.5 replaces parsing with `InlineActivityType.fromDbValue()`, check what that method does for unknown values. If it throws, wrap in try-catch and return `null`. If it returns a default, add a `debugPrint` warning.

In `InlineActivityModel.fromJson`, if type parsing returns null, return null from the factory. In the repository, filter out null activities. This surfaces the error visibly without crashing.

---

## Phase 3: UX Polish (6 fixes)

### 3.1 — Add sound feedback to `find_words` (#11)

**File:**
- `lib/presentation/widgets/inline_activities/inline_find_words_activity.dart`

Change `StatefulWidget` → keep as `StatefulWidget` but add `InlineActivitySoundMixin`:

```dart
class _InlineFindWordsActivityState extends State<InlineFindWordsActivity>
    with InlineActivitySoundMixin {
```

Call `playSound(isCorrect)` in `_submitAnswer` before or after calling `widget.onAnswer`.

### 3.2 — Loading flicker: transient error card (#13)

**File:**
- `lib/presentation/widgets/reader/reader_content_block_list.dart`

In the `build` method (line 140), change the `inlineActivitiesAsync.maybeWhen` handling:

```dart
final activitiesLoading = inlineActivitiesAsync.isLoading;
final inlineActivities = inlineActivitiesAsync.maybeWhen(
  data: (activities) => activities,
  orElse: () => <InlineActivity>[],
);
```

In `_getVisibleBlocks`, when building an activity block and `activityMap[block.activityId]` is null:
- If `activitiesLoading` is true → render a compact placeholder (sized box with subtle opacity animation matching activity card dimensions)
- If `activitiesLoading` is false → keep current error card (genuine missing activity)

Pass `activitiesLoading` to the list builder so it can distinguish loading vs missing.

### 3.3 — Chapter completion widget flash (#23)

**File:**
- `lib/presentation/providers/reader_provider.dart`

Update `isChapterCompleteProvider`:

```dart
final isChapterCompleteProvider = Provider.autoDispose<bool>((ref) {
  final initialized = ref.watch(chapterInitializedProvider);
  if (!initialized) return false; // Don't evaluate until activities loaded

  final completedActivities = ref.watch(inlineActivityStateProvider);
  final totalActivities = ref.watch(totalActivitiesProvider);

  if (totalActivities == 0) return true;
  return completedActivities.length >= totalActivities;
});
```

Adding `chapterInitializedProvider` check prevents the transient `true` during loading.

### 3.4 — Matching duplicate right-values validation (#14)

**Admin editor validation:**
- `owlio_admin/lib/features/books/widgets/activity_editor.dart` — on save, check for duplicate `right` values in matching pairs. Show validation error if found.

**Runtime defense:**
- `lib/presentation/widgets/inline_activities/inline_matching_activity.dart` — change `_matchedPairs` from `Map<String, String>` to `Map<int, int>` (left index → right index) or use pair index tracking instead of value-based matching. This prevents the duplicate-value unsolvable state.

### 3.5 — Admin Turkish labels to English (#25)

**File:**
- `owlio_admin/lib/features/books/widgets/activity_editor.dart`

Line 680: `'İptal'` → `'Cancel'`
Line 691: `'Kaydet'` → `'Save'`

Scan for any other Turkish strings in the same file.

### 3.6 — Offline graceful degradation + vocab ID logging (#15, #24)

**Offline cold-start (#24):**
Phase 1.2's `finally` fix ensures `chapterInitializedProvider` is set even on failure. Additional: in `cached_book_repository.dart`'s `getCompletedInlineActivities`, when cache miss AND remote fails, return `Right({})` (empty map) instead of `Left(NetworkFailure())`. This allows graceful degradation — all activities appear uncompleted but the reader is usable.

**Vocab ID logging (#15):**
In `complete_inline_activity_usecase.dart`, replace the silent swallow:

```dart
wordsAdded = vocabResult.fold(
  (failure) {
    debugPrint('⚠️ Failed to add vocabulary words: $failure');
    return 0;
  },
  (progressList) => progressList.length,
);
```

**Files:**
- `lib/data/repositories/cached/cached_book_repository.dart` — fallback to empty map on both cache miss and remote failure
- `lib/domain/usecases/activity/complete_inline_activity_usecase.dart` — add debugPrint on failure

---

## Deferred / Accepted

| # | Finding | Reason |
|---|---------|--------|
| #9 | Dual rendering paths (content-blocks + legacy) | Accepted — requires full content migration, out of scope |
| #16 | Double round trip in `getCompletedInlineActivities` | Low priority optimization — 2 queries is acceptable for typical chapter size |
| #19 | `handleInlineActivityCompletion` as free function | Accepted — follows locality of behavior principle |
| #24 | Offline cold-start | Partially covered by #2 fix + #3.6 graceful degradation |

---

## Commit Strategy

| Commit | Phase | Description |
|--------|-------|-------------|
| 1 | Phase 1 | fix: inline activity data integrity — index, initialization, error handling, words_learned, correctness tracking |
| 2 | Phase 2 | chore: remove inline activity dead code, add guard clauses, use shared enum methods |
| 3 | Phase 3 | fix: inline activity UX — sound feedback, loading states, matching validation, admin English labels |
| 4 | Spec update | docs: mark inline activity audit findings as resolved |

---

## Verification

After all phases, run:
1. `dart analyze lib/` — must pass
2. Manual test: complete each of 4 activity types (correct + incorrect)
3. Manual test: re-open completed chapter — verify correct/incorrect state preserved
4. Manual test: offline activity completion + sync
5. Update `docs/specs/03-inline-activities.md` findings status from TODO → Fixed
