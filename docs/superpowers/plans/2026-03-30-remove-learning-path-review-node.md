# Remove Learning Path Review Node — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the daily review node from the learning path visual rendering while preserving the word list gating behavior.

**Architecture:** Delete `PathDailyReviewItem` and all code that injects/renders/sorts it. Rewrite `dailyReviewNeededProvider` to derive gating state directly from review providers instead of scanning path items. Drop the `path_daily_review_completions` table and `path_position` column via migration.

**Tech Stack:** Flutter/Dart, Riverpod, Supabase (PostgreSQL migration)

---

### Task 1: Remove PathDailyReviewItem and injection logic from vocabulary_provider.dart

**Files:**
- Modify: `lib/presentation/providers/vocabulary_provider.dart`

- [ ] **Step 1: Delete `PathDailyReviewItem` class (lines 537-548)**

Remove the entire class:

```dart
// DELETE this entire block (lines 537-548):
class PathDailyReviewItem extends PathItemData {
  const PathDailyReviewItem({
    required super.sortOrder,
    required this.completedAt,
    required this.isCompleted,
  });
  final DateTime? completedAt;
  final bool isCompleted;

  @override
  bool get isComplete => isCompleted;
}
```

- [ ] **Step 2: Remove `'daily_review'` from `allSpecialNodeTypes` (line 551)**

Change:
```dart
const allSpecialNodeTypes = ['daily_review', 'game', 'treasure'];
```
To:
```dart
const allSpecialNodeTypes = ['game', 'treasure'];
```

- [ ] **Step 3: Remove `PathDailyReviewItem` exclusion from `isAllComplete` getter (lines 592-600)**

In `PathUnitData.isAllComplete`, change:
```dart
  bool get isAllComplete {
    final requiredItems = items.where((i) {
      if (i is PathBookItem && booksExemptFromLock) return false;
      if (i is PathDailyReviewItem) return false; // DR is a daily gate, not a progression requirement
      return true;
    });
    return requiredItems.every((i) => i.isComplete);
  }
```
To:
```dart
  bool get isAllComplete {
    final requiredItems = items.where((i) {
      if (i is PathBookItem && booksExemptFromLock) return false;
      return true;
    });
    return requiredItems.every((i) => i.isComplete);
  }
```

- [ ] **Step 4: Remove daily review data fetches from `learningPathProvider` (lines 690-703)**

Remove `todayReviewSessionProvider` and `dailyReviewWordsProvider` from the parallel fetch. Change the `Future.wait` block:

```dart
  final futures = await Future.wait([
    ref.watch(userLearningPathsProvider.future),       // [0]
    ref.watch(allWordListsProvider.future),             // [1]
    ref.watch(userWordListProgressProvider.future),     // [2]
    ref.watch(nodeCompletionsProvider.future),          // [3]
    ref.watch(completedBookIdsProvider.future),         // [4]
    ref.watch(todayReviewSessionProvider.future)        // [5]
        .catchError((_) => null),
    ref.watch(dailyReviewWordsProvider.future)    // [6]
        .catchError((_) => <VocabularyWord>[]),
  ]);

  final learningPaths = futures[0] as List<LearningPath>;
  final allLists = futures[1] as List<WordList>;
  final progressList = futures[2] as List<UserWordListProgress>;
  final nodeCompletions = futures[3] as Map<String, Set<String>>;
  final completedBookIds = futures[4] as Set<String>;
  final todaySession = futures[5] as DailyReviewSession?;
  final dailyReviewDueWords = futures[6] as List<VocabularyWord>;
  final dailyReviewDueCount = dailyReviewDueWords.length;
```

To:
```dart
  final futures = await Future.wait([
    ref.watch(userLearningPathsProvider.future),       // [0]
    ref.watch(allWordListsProvider.future),             // [1]
    ref.watch(userWordListProgressProvider.future),     // [2]
    ref.watch(nodeCompletionsProvider.future),          // [3]
    ref.watch(completedBookIdsProvider.future),         // [4]
  ]);

  final learningPaths = futures[0] as List<LearningPath>;
  final allLists = futures[1] as List<WordList>;
  final progressList = futures[2] as List<UserWordListProgress>;
  final nodeCompletions = futures[3] as Map<String, Set<String>>;
  final completedBookIds = futures[4] as Set<String>;
```

- [ ] **Step 5: Remove `drDoneToday`/`drNeeded`/`drInjected` variables (lines 712-714)**

Delete these three lines:
```dart
  final drDoneToday = todaySession != null;
  final drNeeded = dailyReviewDueCount >= minDailyReviewCount;
  bool drInjected = false; // only inject DR once across all units
```

- [ ] **Step 6: Remove daily review injection block (lines 803-837)**

Delete the entire block:
```dart
      // --- Daily Review injection (only once across all units) ---
      if (!drInjected && (drNeeded || drDoneToday)) {
        // ... entire block through drInjected = true ...
      }
```

- [ ] **Step 7: Simplify sort — remove review node tie-breaking (lines 839-846)**

Change:
```dart
      // Re-sort: DR items come before other items with the same sortOrder
      items.sort((a, b) {
        final cmp = a.sortOrder.compareTo(b.sortOrder);
        if (cmp != 0) return cmp;
        if (a is PathDailyReviewItem && b is! PathDailyReviewItem) return -1;
        if (b is PathDailyReviewItem && a is! PathDailyReviewItem) return 1;
        return 0;
      });
```
To:
```dart
      items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
```

- [ ] **Step 8: Rewrite `dailyReviewNeededProvider` (lines 927-932)**

The current implementation scans path items for `PathDailyReviewItem` — which no longer exists. Rewrite to derive directly from review providers:

Change:
```dart
final dailyReviewNeededProvider = FutureProvider<bool>((ref) async {
  final pathUnits = await ref.watch(learningPathProvider.future);
  return pathUnits.any(
    (unit) => unit.items.any((i) => i is PathDailyReviewItem && !i.isComplete),
  );
});
```
To:
```dart
final dailyReviewNeededProvider = FutureProvider<bool>((ref) async {
  final dueWords = await ref.watch(dailyReviewWordsProvider.future)
      .catchError((_) => <VocabularyWord>[]);
  if (dueWords.length < minDailyReviewCount) return false;
  final todaySession = await ref.watch(todayReviewSessionProvider.future)
      .catchError((_) => null);
  return todaySession == null;
});
```

- [ ] **Step 9: Run `dart analyze lib/`**

Expected: Errors about `PathDailyReviewItem` references in other files (learning_path.dart, daily_review_screen.dart). These will be fixed in subsequent tasks.

- [ ] **Step 10: Commit**

```bash
git add lib/presentation/providers/vocabulary_provider.dart
git commit -m "refactor: remove PathDailyReviewItem and injection logic from vocabulary_provider"
```

---

### Task 2: Remove review node rendering from learning_path.dart

**Files:**
- Modify: `lib/presentation/widgets/learning_path/learning_path.dart`
- Modify: `lib/presentation/widgets/learning_path/path_node.dart`

- [ ] **Step 1: Remove `PathDailyReviewItem` skip in active node detection (lines 98-106)**

Change:
```dart
        // Active detection: first unlocked + incomplete (skip daily review)
        bool isActive = false;
        if (!foundActive &&
            !isItemLocked &&
            !item.isComplete &&
            item is! PathDailyReviewItem) {
          isActive = true;
          foundActive = true;
        }
```
To:
```dart
        bool isActive = false;
        if (!foundActive && !isItemLocked && !item.isComplete) {
          isActive = true;
          foundActive = true;
        }
```

- [ ] **Step 2: Remove `PathDailyReviewItem` case from `_mapItemToNode` switch (lines 235-241)**

Delete the entire case:
```dart
      case PathDailyReviewItem():
        return MapTileNodeData(
          type: NodeType.review,
          state: state,
          label: 'Review',
          onTap: () => context.push(AppRoutes.vocabularyDailyReview),
        );
```

The switch on the `PathItemData` sealed class will now be exhaustive without it (since the subclass no longer exists).

- [ ] **Step 3: Remove `NodeType.review` from path_node.dart (line 12)**

Change:
```dart
enum NodeType {
  wordList(Icons.menu_book_rounded, AppColors.secondary, Color(0xFF1899D6)),
  book(Icons.auto_stories_rounded, Color(0xFF1565C0), Color(0xFFE3F2FD)),
  game(Icons.sports_esports_rounded, Color(0xFF7B1FA2), Color(0xFFF3E5F5)),
  treasure(Icons.card_giftcard_rounded, AppColors.cardLegendary, Color(0xFFFFF8E1)),
  review(Icons.style_rounded, Color(0xFFE65100), Color(0xFFFFF3E0));
```
To:
```dart
enum NodeType {
  wordList(Icons.menu_book_rounded, AppColors.secondary, Color(0xFF1899D6)),
  book(Icons.auto_stories_rounded, Color(0xFF1565C0), Color(0xFFE3F2FD)),
  game(Icons.sports_esports_rounded, Color(0xFF7B1FA2), Color(0xFFF3E5F5)),
  treasure(Icons.card_giftcard_rounded, AppColors.cardLegendary, Color(0xFFFFF8E1));
```

- [ ] **Step 4: Remove unused import of `PathDailyReviewItem` if present in learning_path.dart**

Check the imports at the top of `learning_path.dart`. The `PathDailyReviewItem` comes from `vocabulary_provider.dart` which is already imported for other types — no separate import to remove, but verify no compile errors remain.

- [ ] **Step 5: Run `dart analyze lib/`**

Expected: Errors about `PathDailyReviewItem` in `daily_review_screen.dart`. Fixed in next task.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/widgets/learning_path/learning_path.dart lib/presentation/widgets/learning_path/path_node.dart
git commit -m "refactor: remove review node rendering from learning path UI"
```

---

### Task 3: Remove pathPosition save from daily_review_screen.dart and daily_review_provider.dart

**Files:**
- Modify: `lib/presentation/screens/vocabulary/daily_review_screen.dart`
- Modify: `lib/presentation/providers/daily_review_provider.dart`

- [ ] **Step 1: Delete `_saveDrPosition` method from daily_review_screen.dart (lines 144-169)**

Delete the entire method:
```dart
  Future<void> _saveDrPosition(String sessionId) async {
    try {
      final pathUnits = ref.read(learningPathProvider).valueOrNull;
      if (pathUnits == null) return;

      int? drPosition;
      for (final unit in pathUnits) {
        for (final item in unit.items) {
          if (item is PathDailyReviewItem && !item.isComplete) {
            drPosition = item.sortOrder;
            break;
          }
        }
        if (drPosition != null) break;
      }

      if (drPosition == null) return;

      await ref.read(dailyReviewControllerProvider.notifier)
          .saveDailyReviewPosition(
            sessionId: sessionId,
            pathPosition: drPosition,
          );
    } catch (_) {
      // Non-critical
    }
  }
```

- [ ] **Step 2: Remove `_saveDrPosition` call from completion flow (line 125)**

In the daily review completion handler, remove:
```dart
    // Save DR position to daily_review_sessions so it stays fixed in the path
    await _saveDrPosition(result.sessionId);
```

- [ ] **Step 3: Remove `completePathNode` call for `'daily_review'` in unit review mode (lines 102-105)**

In the unit review completion handler, remove:
```dart
      // Mark daily_review node complete in the learning path lock chain
      if (widget.unitId != null) {
        await completePathNode(ref, widget.unitId!, 'daily_review');
      }
      // Refresh learning path so DR node shows as complete
```

Keep the `ref.invalidate(todayReviewSessionProvider)` and `ref.invalidate(learningPathProvider)` calls — they still serve to refresh the path after unit review completion.

Also update the comment on line 100 since the skip reason changes:
```dart
    // Skip the daily review RPC (avoids UNIQUE constraint conflict).
    if (state.isUnitReview) {
```
Stays as-is (comment is still accurate for the RPC skip reason).

- [ ] **Step 4: Remove `saveDailyReviewPositionUseCase` from DailyReviewController (daily_review_provider.dart)**

In the constructor (lines 150-158), remove the parameter:
```dart
    required this.saveDailyReviewPositionUseCase,
```

Remove the field (line 168):
```dart
  final SaveDailyReviewPositionUseCase saveDailyReviewPositionUseCase;
```

Remove the method (lines 403-414):
```dart
  /// Save DR position in learning path (uses session ID to avoid timezone issues)
  Future<void> saveDailyReviewPosition({
    required String sessionId,
    required int pathPosition,
  }) async {
    await saveDailyReviewPositionUseCase(
      SaveDailyReviewPositionParams(
        sessionId: sessionId,
        pathPosition: pathPosition,
      ),
    );
  }
```

- [ ] **Step 5: Remove `saveDailyReviewPositionUseCaseProvider` watch from controller providers (lines 431, 444)**

In both `dailyReviewControllerProvider` constructor calls, remove:
```dart
        saveDailyReviewPositionUseCase: ref.watch(saveDailyReviewPositionUseCaseProvider),
```

- [ ] **Step 6: Remove unused imports from daily_review_screen.dart**

After the changes, `PathDailyReviewItem`, `learningPathProvider`, and `completePathNode` imports may be unused. Check and clean up. `learningPathProvider` might still be used elsewhere in the file — verify before removing.

- [ ] **Step 7: Run `dart analyze lib/`**

Expected: Clean or errors only about the domain/data layer files to be cleaned up in the next task.

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/screens/vocabulary/daily_review_screen.dart lib/presentation/providers/daily_review_provider.dart
git commit -m "refactor: remove pathPosition save logic from daily review flow"
```

---

### Task 4: Clean up domain and data layers

**Files:**
- Modify: `lib/domain/entities/daily_review_session.dart`
- Delete: `lib/domain/usecases/vocabulary/save_daily_review_position_usecase.dart`
- Modify: `lib/domain/repositories/vocabulary_repository.dart`
- Modify: `lib/data/models/vocabulary/daily_review_session_model.dart`
- Modify: `lib/data/repositories/supabase/supabase_vocabulary_repository.dart`
- Modify: `lib/presentation/providers/usecase_providers.dart`
- Modify: `packages/owlio_shared/lib/src/constants/tables.dart`

- [ ] **Step 1: Remove `pathPosition` from `DailyReviewSession` entity**

In `lib/domain/entities/daily_review_session.dart`, change:
```dart
class DailyReviewSession extends Equatable {
  const DailyReviewSession({
    required this.id,
    required this.userId,
    required this.sessionDate,
    required this.wordsReviewed,
    required this.correctCount,
    required this.incorrectCount,
    required this.xpEarned,
    required this.isPerfect,
    required this.completedAt,
    this.pathPosition,
  });

  final String id;
  final String userId;
  final DateTime sessionDate;
  final int wordsReviewed;
  final int correctCount;
  final int incorrectCount;
  final int xpEarned;
  final bool isPerfect;
  final DateTime completedAt;
  final int? pathPosition;
```
To:
```dart
class DailyReviewSession extends Equatable {
  const DailyReviewSession({
    required this.id,
    required this.userId,
    required this.sessionDate,
    required this.wordsReviewed,
    required this.correctCount,
    required this.incorrectCount,
    required this.xpEarned,
    required this.isPerfect,
    required this.completedAt,
  });

  final String id;
  final String userId;
  final DateTime sessionDate;
  final int wordsReviewed;
  final int correctCount;
  final int incorrectCount;
  final int xpEarned;
  final bool isPerfect;
  final DateTime completedAt;
```

Also remove `pathPosition` from the `props` list:
```dart
  @override
  List<Object?> get props => [
        id,
        userId,
        sessionDate,
        wordsReviewed,
        correctCount,
        incorrectCount,
        xpEarned,
        isPerfect,
        completedAt,
      ];
```

- [ ] **Step 2: Remove `pathPosition` from `DailyReviewSessionModel`**

In `lib/data/models/vocabulary/daily_review_session_model.dart`:

Remove from constructor:
```dart
    this.pathPosition,
```

Remove from `fromJson`:
```dart
      pathPosition: json['path_position'] as int?,
```

Remove field:
```dart
  final int? pathPosition;
```

Remove from `toEntity()`:
```dart
      pathPosition: pathPosition,
```

- [ ] **Step 3: Remove `saveDailyReviewPosition` from repository interface**

In `lib/domain/repositories/vocabulary_repository.dart`, delete:
```dart
  /// Save the daily review's position in the learning path
  Future<Either<Failure, void>> saveDailyReviewPosition({
    required String sessionId,
    required int pathPosition,
  });
```

- [ ] **Step 4: Remove `saveDailyReviewPosition` from repository implementation**

In `lib/data/repositories/supabase/supabase_vocabulary_repository.dart`, delete:
```dart
  @override
  Future<Either<Failure, void>> saveDailyReviewPosition({
    required String sessionId,
    required int pathPosition,
  }) async {
    try {
      await _supabase
          .from(DbTables.dailyReviewSessions)
          .update({'path_position': pathPosition})
          .eq('id', sessionId);
      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
```

- [ ] **Step 5: Delete `save_daily_review_position_usecase.dart`**

```bash
rm lib/domain/usecases/vocabulary/save_daily_review_position_usecase.dart
```

- [ ] **Step 6: Remove `saveDailyReviewPositionUseCaseProvider` from usecase_providers.dart (lines 384-386)**

Delete:
```dart
final saveDailyReviewPositionUseCaseProvider = Provider((ref) {
  return SaveDailyReviewPositionUseCase(ref.watch(vocabularyRepositoryProvider));
});
```

Also remove the import of `SaveDailyReviewPositionUseCase` if it has a dedicated import line.

- [ ] **Step 7: Remove `pathDailyReviewCompletions` from shared tables.dart**

In `packages/owlio_shared/lib/src/constants/tables.dart`, delete:
```dart
  static const pathDailyReviewCompletions = 'path_daily_review_completions';
```

- [ ] **Step 8: Run `dart analyze lib/` and `dart analyze packages/owlio_shared/lib/`**

Expected: Clean — all references to removed code should be resolved.

- [ ] **Step 9: Commit**

```bash
git add -u lib/domain/ lib/data/ lib/presentation/providers/usecase_providers.dart packages/owlio_shared/lib/src/constants/tables.dart
git commit -m "refactor: remove pathPosition, saveDailyReviewPosition, and related domain/data layer code"
```

---

### Task 5: Database migration

**Files:**
- Create: `supabase/migrations/20260330000001_remove_review_node_artifacts.sql`

- [ ] **Step 1: Write migration**

Create `supabase/migrations/20260330000001_remove_review_node_artifacts.sql`:

```sql
-- Remove learning path review node artifacts
-- The daily review node is no longer rendered in the learning path.
-- Gating behavior is preserved via dailyReviewNeededProvider (client-side).

-- Drop the daily review completions table (never read from client code)
DROP TABLE IF EXISTS path_daily_review_completions;

-- Drop the path_position column from daily_review_sessions
ALTER TABLE daily_review_sessions DROP COLUMN IF EXISTS path_position;

-- Drop the dead RPC (already unused per audit finding #9)
DROP FUNCTION IF EXISTS get_path_daily_reviews(UUID);

-- Drop the UPDATE policy that was only needed for path_position writes
DROP POLICY IF EXISTS "daily_review_sessions_update" ON daily_review_sessions;
```

- [ ] **Step 2: Dry-run migration**

```bash
supabase db push --dry-run
```

Expected: Shows the migration will drop the table, column, function, and policy.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260330000001_remove_review_node_artifacts.sql
git commit -m "migration: drop path_daily_review_completions table and path_position column"
```

---

### Task 6: Update spec docs and verify

**Files:**
- Modify: `docs/specs/07-learning-paths.md`
- Modify: `docs/specs/08-daily-vocabulary-review.md`

- [ ] **Step 1: Update learning paths spec (07-learning-paths.md)**

In the "Student" section under "Path Navigation", update bullet 5 (line 100):
```
   - **Daily Review gate** (`PathDailyReviewNode`) — injected dynamically before the first incomplete non-exempt item
```
To:
```
   - ~~Daily Review gate~~ — removed. Gating is now dialog-only (no visible path node).
```

In "Daily Review Gate" section (lines 109-113), update:
```
**Daily Review Gate:**
- If student has ≥ `minDailyReviewCount` (10) words due for review, a DR node is injected into the path
- DR node blocks forward progress until the daily review session is completed
- Position: inserted before the first incomplete non-exempt item, or at the saved `pathPosition` if already completed today
- After completing DR, the path refreshes and the gate shows as completed
```
To:
```
**Daily Review Gate:**
- If student has ≥ `minDailyReviewCount` (10) words due for review, word list nodes show a dialog prompting daily review completion
- No visible node is rendered in the path — gating is dialog-only via `dailyReviewNeededProvider`
- After completing DR (from home screen or daily quest), providers are invalidated and word lists become accessible
```

In "Business Rules" section, update rule 6 (line 139):
```
6. **Daily review gate injection**: A DR node is injected exactly once across all units when `totalDueWords >= minDailyReviewCount (10)`. It appears before the first incomplete non-exempt item. If already completed today, it appears at the saved position.
```
To:
```
6. **Daily review gate**: When `totalDueWords >= minDailyReviewCount (10)` and no session completed today, word list nodes are gated via dialog prompt. No path node is rendered.
```

- [ ] **Step 2: Update daily vocabulary review spec (08-daily-vocabulary-review.md)**

In "Entry points" section (lines 71-73), update bullet 2:
```
2. Learning path DR gate node (injected automatically when ≥ 10 due words)
```
To:
```
2. Learning path dialog gate (word list nodes show "Complete daily review first" dialog when ≥ 10 due words)
```

In "Learning Path Integration" section (lines 142-148), update:
```
### Learning Path Integration
```
```
learningPathProvider builds path:
  → Check dailyReviewWordsProvider.length >= 10
  → Check todayReviewSessionProvider (completed today?)
  → IF needed and not done: inject PathDailyReviewItem before first locked non-exempt item
  → dailyReviewNeededProvider = true → blocks word list navigation with dialog
  → After completion: providers invalidated → gate clears → path rebuilds
```
To:
```
### Learning Path Integration
```
```
dailyReviewNeededProvider:
  → Check dailyReviewWordsProvider.length >= 10
  → Check todayReviewSessionProvider (completed today?)
  → IF needed and not done: dailyReviewNeededProvider = true → blocks word list navigation with dialog
  → After completion: providers invalidated → gate clears
```

In "Business Rules" section, update rule 7 (line 108):
```
7. **Learning path gate**: When daily review is needed (≥ 10 due words, not yet completed today), a DR node is injected into the learning path. Word list nodes are blocked until DR is completed.
```
To:
```
7. **Learning path gate**: When daily review is needed (≥ 10 due words, not yet completed today), word list nodes are blocked via dialog until DR is completed. No path node is rendered.
```

In "Business Rules" section, update rule 8 (line 109):
```
8. **Position persistence**: After completion, `path_position` is saved so the completed DR node stays at the same position when the path is revisited.
```
Remove this rule entirely (renumber subsequent rules).

In "Key Files" table, remove the `save_daily_review_position_usecase.dart` entry and update the "Path Integration" entry:
```
| Path Integration | `lib/presentation/providers/vocabulary_provider.dart` | DR injection, gate logic, `dailyReviewNeededProvider` |
```
To:
```
| Path Integration | `lib/presentation/providers/vocabulary_provider.dart` | `dailyReviewNeededProvider` gate logic |
```

- [ ] **Step 3: Run `dart analyze lib/` for final verification**

Expected: Clean — no errors.

- [ ] **Step 4: Commit**

```bash
git add docs/specs/07-learning-paths.md docs/specs/08-daily-vocabulary-review.md
git commit -m "docs: update specs to reflect review node removal from learning path"
```
