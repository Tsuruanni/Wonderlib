# Daily Vocabulary Review — Audit Fixes Design

Fixes all 20 findings from the Feature #8 audit (`docs/specs/08-daily-vocabulary-review.md`).

## Approach

Layer-based, 3 commits:
1. **DB migration** — RPC auth checks + index alignment
2. **Flutter fixes** — critical bugs, data consistency, UX
3. **Cleanup** — dead code, provider lifecycle, code quality

---

## Commit 1: Database Migration

**File:** `supabase/migrations/20260328000001_daily_review_audit_fixes.sql`

### Fix #1 — `complete_daily_review` RPC auth check (Critical)

`CREATE OR REPLACE FUNCTION` with auth guard at function entry:

```sql
IF auth.uid() != p_user_id THEN
  RAISE EXCEPTION 'Unauthorized';
END IF;
```

Rest of the function body unchanged. Pattern matches `20260327100001_learning_path_audit_fixes.sql`.

### Fix #2 + #15 — `get_due_review_words` auth check + index alignment

Rewrite from `sql` to `plpgsql` (auth check requires procedural block). Two changes:

1. Add same `auth.uid() != p_user_id` guard
2. Add `AND vp.status != 'mastered'` filter to WHERE clause

The `status != 'mastered'` filter enables the existing partial index `idx_vocabulary_progress_review` and aligns the RPC output with the quest threshold logic (which already filters mastered words).

**Impact on Flutter:** `dailyReviewWordsProvider` no longer receives mastered words. The `loadSession()` mastered/non-mastered split becomes unnecessary — see Fix #6.

---

## Commit 2: Flutter Fixes

### Fix #3 — Architecture: Screen reads repository directly

**Create:** `lib/domain/usecases/vocabulary/save_daily_review_position_usecase.dart`

```dart
class SaveDailyReviewPositionParams {
  const SaveDailyReviewPositionParams({
    required this.sessionId,
    required this.pathPosition,
  });
  final String sessionId;
  final int pathPosition;
}

class SaveDailyReviewPositionUseCase
    implements UseCase<void, SaveDailyReviewPositionParams> {
  // Single repo.saveDailyReviewPosition() call
}
```

**Modify:**
- `usecase_providers.dart` — register `saveDailyReviewPositionUseCaseProvider`
- `DailyReviewController` — add `saveDailyReviewPosition()` method, accept UseCase in constructor
- `daily_review_screen.dart` — remove `_saveDrPosition()` method, remove `vocabularyRepositoryProvider` import, call controller method instead

### Fix #4 — Bug: `_isProcessingAnswer` deadlock

Replace manual flag management with try/finally:

```dart
Future<void> answerWord(SM2Response response) async {
  if (_isProcessingAnswer) return;
  _isProcessingAnswer = true;
  try {
    // ... all existing logic ...
    // In currentProgress == null branch: create initial progress record
  } finally {
    _isProcessingAnswer = false;
  }
}
```

This fixes both:
- Flag not reset in `currentProgress == null` branch
- Flag not reset on any thrown exception

For the `currentProgress == null` case (new word in unit review): call `updateWordProgressUseCase` with initial SM-2 values so the word gets a progress record.

### Fix #5 — Bug: No error state

**Add to `DailyReviewState`:**

```dart
final String? errorMessage;
```

**In `loadSession()` and `loadUnitReviewSession()`:** On failure, set `errorMessage` instead of returning empty list:

```dart
final allDueWords = wordsResult.fold(
  (failure) {
    state = state.copyWith(isLoading: false, errorMessage: failure.message);
    return <VocabularyWord>[];
  },
  (words) => words,
);
if (state.errorMessage != null) return;
```

**In screen:** Add error state widget between loading and empty checks:

```dart
if (state.errorMessage != null) {
  // Error message + "Try Again" button → controller.loadSession()
}
```

### Fix #6 — Threshold mismatch

RPC now returns only non-mastered words (Fix #2). Simplify `loadSession()`:
- Remove mastered/non-mastered split logic
- Remove `maxMastered = 5` constant
- Session is now: up to 25 non-mastered words (change `maxTotal` from 25, remove `maxNonMastered`/`maxMastered` split)
- `dailyReviewWordsProvider` count now matches quest RPC count (both non-mastered only)

### Fix #7 — Timezone mismatch in `saveDailyReviewPosition`

Change repository method signature: accept `sessionId` instead of `userId + date`.

```dart
// Before: UPDATE WHERE user_id = ? AND session_date = DateTime.now()
// After:  UPDATE WHERE id = sessionId
```

`DailyReviewResult.sessionId` is already available after `completeSession()`. Pass it through.

**Modify:**
- `vocabulary_repository.dart` — change `saveDailyReviewPosition(userId, pathPosition)` → `saveDailyReviewPosition(sessionId, pathPosition)`
- `supabase_vocabulary_repository.dart` — UPDATE by `id` instead of `user_id + session_date`
- `SaveDailyReviewPositionUseCase` params already designed with `sessionId` (see Fix #3)

### Fix #8 — XP labeled as "Coins"

`daily_review_screen.dart` line 231: `'+$xpEarned Coins'` → `'+$xpEarned XP'`

### Fix #13-14 — Unit review performance

**Fix #14 (all word lists fetched):** Add optional `unitId` parameter to `GetAllWordListsParams`. Repository adds `WHERE unit_id = ?` when present.

**Fix #13 (N+1):** Acceptable for now. `Future.wait` already parallelizes the per-list fetches. True fix would require a new RPC — deferred.

### Fix #20 — Unhandled auth exception

In `dailyReviewControllerProvider`: replace `throw Exception('User not logged in')` with a null-safe pattern. If `userId` is null, controller sets error state immediately in constructor/loadSession instead of throwing.

---

## Commit 3: Dead Code + Code Quality Cleanup

### Fix #9 — Dead `getWordProgressUseCase` injection

- Remove from `DailyReviewController` constructor
- Remove `ref.watch(getWordProgressUseCaseProvider)` from `dailyReviewControllerProvider`

### Fix #10 — Redundant `totalDueWordsForReviewProvider`

- Delete provider
- In `vocabulary_provider.dart`: replace `totalDueWordsForReviewProvider` usage with `dailyReviewWordsProvider` `.length`

### Fix #11 — Dead `DailyReviewSessionModel.fromEntity`

- Delete factory constructor from model

### Fix #12 — Audio button stub

- Remove `IconButton(icon: Icons.volume_up_rounded)` from `_CardFront`

### Fix #16 — Missing `.autoDispose`

- `dailyReviewWordsProvider` → `FutureProvider.autoDispose`
- `todayReviewSessionProvider` → `FutureProvider.autoDispose`
- Note: `totalDueWordsForReviewProvider` deleted in Fix #10

### Fix #17 — Redundant `.take(30)`

- Remove `.take(30)` from `dailyReviewWordsProvider` (RPC handles limit)

### Fix #18 — Mixed navigation

- `Navigator.of(context).pop()` → `context.pop()` in `daily_review_screen.dart`

### Fix #19 — Completion stats inflation

- Compute `knownPercent` from `firstPassCorrectCount / originalWordCount`
- Compute Easy/Good/Hard breakdown from first-pass responses only (filter by word uniqueness)

---

## Files Modified

### Created (2)
- `supabase/migrations/20260328000001_daily_review_audit_fixes.sql`
- `lib/domain/usecases/vocabulary/save_daily_review_position_usecase.dart`

### Modified (7)
- `lib/domain/repositories/vocabulary_repository.dart` — `saveDailyReviewPosition` signature change
- `lib/data/repositories/supabase/supabase_vocabulary_repository.dart` — repo impl update
- `lib/data/models/vocabulary/daily_review_session_model.dart` — remove `fromEntity`
- `lib/presentation/providers/daily_review_provider.dart` — error state, try/finally, dead code, autoDispose, UseCase changes
- `lib/presentation/providers/usecase_providers.dart` — register new UseCase provider
- `lib/presentation/providers/vocabulary_provider.dart` — remove `totalDueWordsForReviewProvider`, update usage
- `lib/presentation/screens/vocabulary/daily_review_screen.dart` — error UI, label fix, nav fix, remove stub, remove repo import

---

## Verification

After all changes:
1. `dart analyze lib/` — must pass with no issues
2. `supabase db push --dry-run` — verify migration applies cleanly
3. Manual test: daily review happy path (login as active@demo.com)
4. Manual test: unit review mode (navigate to a unit review node)
5. Check: completed DR shows XP (not "Coins"), error state on network disconnect
