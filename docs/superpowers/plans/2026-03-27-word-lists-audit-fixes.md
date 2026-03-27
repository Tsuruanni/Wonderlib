# Word Lists Audit Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 20 audit findings from the Word Lists feature review (spec: `docs/specs/06-word-lists.md`).

**Architecture:** Pure cleanup — no new features. Fixes span domain entities, data models, repository interfaces, providers, screens, and one DB migration. Groups are ordered so earlier tasks don't break later ones.

**Tech Stack:** Flutter/Dart, Riverpod, Supabase (PostgreSQL RPC migration), owlio_shared

---

### Task 1: Unify Star Count & isComplete (#1, #5)

**Files:**
- Modify: `lib/domain/entities/word_list.dart:100-115`

- [ ] **Step 1: Fix `isComplete` and `starCount` in `UserWordListProgress`**

In `lib/domain/entities/word_list.dart`, replace lines 100-115:

```dart
  /// Whether the user has completed at least one session
  bool get isComplete => totalSessions > 0;

  /// Star rating based on best accuracy (0-3)
  int get starCount {
    if (!isComplete || bestAccuracy == null) return 0;
    if (bestAccuracy! >= 95) return 3;
    if (bestAccuracy! >= 80) return 2;
    return 1;
  }

  /// Progress percentage for display (0.0 - 1.0)
  double get progressPercentage {
    if (!isComplete) return 0.0;
    return (bestAccuracy ?? 0) / 100.0;
  }
```

with:

```dart
  /// Whether the user has completed at least one session
  bool get isComplete => completedAt != null;

  /// Star rating: 3 stars for ≥90%, 2 for ≥70%, 1 for ≥50%, 0 otherwise
  int get starCount {
    if (bestAccuracy == null) return 0;
    if (bestAccuracy! >= 90) return 3;
    if (bestAccuracy! >= 70) return 2;
    if (bestAccuracy! >= 50) return 1;
    return 0;
  }
```

This unifies with `StudentWordListProgress.starCount` (teacher.dart:181-186) and removes dead `progressPercentage` (#8).

- [ ] **Step 2: Run analyzer**

Run: `dart analyze lib/domain/entities/word_list.dart`
Expected: No errors. No callers of `progressPercentage` exist.

- [ ] **Step 3: Commit**

```bash
git add lib/domain/entities/word_list.dart
git commit -m "fix: unify star count thresholds and isComplete semantics (#1, #5, #8)

Align UserWordListProgress with StudentWordListProgress:
- starCount: 90/70/50/0 (was 95/80/any)
- isComplete: completedAt != null (was totalSessions > 0)
- Remove dead progressPercentage getter"
```

---

### Task 2: Dead Code Removal — Domain & Data (#6, #7, #9)

**Files:**
- Delete: `lib/domain/usecases/wordlist/update_word_list_progress_usecase.dart`
- Modify: `lib/domain/repositories/word_list_repository.dart:13,39-41`
- Modify: `lib/data/repositories/supabase/supabase_word_list_repository.dart:26-44,189-217`
- Modify: `lib/data/models/vocabulary/word_list_model.dart:40-56`
- Modify: `lib/presentation/providers/usecase_providers.dart:131,430-432`

- [ ] **Step 1: Delete `UpdateWordListProgressUseCase` file**

Delete the entire file: `lib/domain/usecases/wordlist/update_word_list_progress_usecase.dart`

- [ ] **Step 2: Remove `updateWordListProgress` from repository interface**

In `lib/domain/repositories/word_list_repository.dart`, remove lines 39-41:

```dart
  /// Update or create progress for a word list
  Future<Either<Failure, UserWordListProgress>> updateWordListProgress(
    UserWordListProgress progress,
  );
```

- [ ] **Step 3: Remove `getVocabularyUnits` from repository interface**

In `lib/domain/repositories/word_list_repository.dart`, remove lines 12-13:

```dart
  /// Get all active vocabulary units ordered by sort_order
  Future<Either<Failure, List<VocabularyUnit>>> getVocabularyUnits();
```

Also remove the unused import if `VocabularyUnit` is no longer referenced:
```dart
import '../entities/vocabulary_unit.dart';
```

- [ ] **Step 4: Remove implementations from `SupabaseWordListRepository`**

In `lib/data/repositories/supabase/supabase_word_list_repository.dart`:

Remove `getVocabularyUnits` method (lines 25-44):
```dart
  @override
  Future<Either<Failure, List<VocabularyUnit>>> getVocabularyUnits() async {
    ...
  }
```

Remove `updateWordListProgress` method (lines 189-217):
```dart
  @override
  Future<Either<Failure, UserWordListProgress>> updateWordListProgress(
    ...
  }
```

Remove now-unused imports at the top if applicable:
```dart
import '../../../domain/entities/vocabulary_unit.dart';
import '../../models/vocabulary/vocabulary_unit_model.dart';
```

- [ ] **Step 5: Remove `fromEntity` from `WordListModel`**

In `lib/data/models/vocabulary/word_list_model.dart`, remove lines 40-56:

```dart
  factory WordListModel.fromEntity(WordList entity) {
    return WordListModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      level: entity.level,
      category: categoryToString(entity.category),
      wordCount: entity.wordCount,
      coverImageUrl: entity.coverImageUrl,
      isSystem: entity.isSystem,
      sourceBookId: entity.sourceBookId,
      unitId: entity.unitId,
      orderInUnit: entity.orderInUnit,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
```

- [ ] **Step 6: Remove provider registration**

In `lib/presentation/providers/usecase_providers.dart`:

Remove the import (line 131):
```dart
import '../../domain/usecases/wordlist/update_word_list_progress_usecase.dart';
```

Remove the provider (lines 430-432):
```dart
final updateWordListProgressUseCaseProvider = Provider((ref) {
  return UpdateWordListProgressUseCase(ref.watch(wordListRepositoryProvider));
});
```

- [ ] **Step 7: Run analyzer**

Run: `dart analyze lib/`
Expected: No errors. Fix any remaining unused import warnings.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor: remove dead word list code (#6, #7, #9)

- Delete UpdateWordListProgressUseCase (never called, bypasses RPC)
- Remove getVocabularyUnits from repository (no use case or provider)
- Remove WordListModel.fromEntity (never called)"
```

---

### Task 3: Replace Duplicate Category Parsing (#10)

**Files:**
- Modify: `lib/data/models/vocabulary/word_list_model.dart:28,89-135`
- Modify: `lib/data/repositories/supabase/supabase_word_list_repository.dart:55`

- [ ] **Step 1: Replace `_parseCategory` with `fromDbValue` in `WordListModel`**

In `lib/data/models/vocabulary/word_list_model.dart`:

In `fromJson` (line 28), change:
```dart
      category: json['category'] as String? ?? 'common_words',
```
to:
```dart
      category: json['category'] as String? ?? 'common_words',
```
(No change needed here — the raw string is stored in the model. The conversion happens in `toEntity`.)

In `toEntity` (around line 95 after fromEntity removal), change:
```dart
      category: _parseCategory(category),
```
to:
```dart
      category: WordListCategory.fromDbValue(category),
```

Then delete the `_parseCategory` static method entirely (was lines 107-120).

- [ ] **Step 2: Replace `categoryToString` with `.dbValue`**

In `lib/data/repositories/supabase/supabase_word_list_repository.dart` (line 55), change:
```dart
      query = query.eq('category', WordListModel.categoryToString(category));
```
to:
```dart
      query = query.eq('category', category.dbValue);
```

Then in `lib/data/models/vocabulary/word_list_model.dart`, delete the `categoryToString` static method entirely (was lines 122-135).

- [ ] **Step 3: Run analyzer**

Run: `dart analyze lib/`
Expected: No errors. The only caller of `categoryToString` was the repository line updated above.

- [ ] **Step 4: Commit**

```bash
git add lib/data/models/vocabulary/word_list_model.dart lib/data/repositories/supabase/supabase_word_list_repository.dart
git commit -m "refactor: use shared enum for category parsing (#10)

Replace WordListModel._parseCategory with WordListCategory.fromDbValue
and categoryToString with .dbValue from owlio_shared."
```

---

### Task 4: Move UI Extension from Domain & Fix Category Color (#3, #11)

**Files:**
- Modify: `lib/domain/entities/word_list.dart:56-72`
- Modify: `lib/presentation/screens/vocabulary/word_list_detail_screen.dart:8,265-281`
- Modify: `lib/presentation/screens/vocabulary/category_browse_screen.dart:8,175-192`

- [ ] **Step 1: Remove `WordListCategoryIcon` extension from domain**

In `lib/domain/entities/word_list.dart`, remove lines 56-72:

```dart
/// Emoji icons for word list categories (UI-specific)
extension WordListCategoryIcon on WordListCategory {
  String get icon {
    switch (this) {
      case WordListCategory.commonWords:
        return '📚';
      case WordListCategory.gradeLevel:
        return '🎓';
      case WordListCategory.testPrep:
        return '📝';
      case WordListCategory.thematic:
        return '🏷️';
      case WordListCategory.storyVocab:
        return '📖';
    }
  }
}
```

- [ ] **Step 2: Add `WordListCategoryIcon` extension to `ui_helpers.dart`**

In `lib/presentation/utils/ui_helpers.dart`, add the following after the existing `VocabularyColors` class (after line 137):

```dart
/// Emoji icons for word list categories
extension WordListCategoryIcon on WordListCategory {
  String get icon {
    switch (this) {
      case WordListCategory.commonWords:
        return '📚';
      case WordListCategory.gradeLevel:
        return '🎓';
      case WordListCategory.testPrep:
        return '📝';
      case WordListCategory.thematic:
        return '🏷️';
      case WordListCategory.storyVocab:
        return '📖';
    }
  }
}
```

Ensure `ui_helpers.dart` imports `WordListCategory` (it already imports `word_list.dart` for `VocabularyColors`).

- [ ] **Step 3: Add `ui_helpers.dart` import to files that use `.icon`**

The following files use `category.icon` for word lists and will need the new import. Check each — some may already import `ui_helpers.dart`:

In `lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart`, add:
```dart
import '../../utils/ui_helpers.dart';
```

In `lib/presentation/screens/vocabulary/category_browse_screen.dart`, add:
```dart
import '../../utils/ui_helpers.dart';
```

In `lib/presentation/screens/vocabulary/word_list_detail_screen.dart`, add:
```dart
import '../../utils/ui_helpers.dart';
```

In `lib/presentation/widgets/vocabulary/path_node.dart`, add (if not already present):
```dart
import '../../utils/ui_helpers.dart';
```

- [ ] **Step 4: Replace duplicate `_getCategoryColor` with `VocabularyColors.getCategoryColor`**

In `lib/presentation/screens/vocabulary/word_list_detail_screen.dart`:
- Delete the `_getCategoryColor` method (lines 265-281)
- Replace all calls to `_getCategoryColor(...)` with `VocabularyColors.getCategoryColor(...)`

In `lib/presentation/screens/vocabulary/category_browse_screen.dart`:
- Delete the `_getCategoryColor` method (lines 175-192)
- Replace all calls to `_getCategoryColor(...)` with `VocabularyColors.getCategoryColor(...)`

- [ ] **Step 5: Run analyzer**

Run: `dart analyze lib/`
Expected: No errors. The `.icon` getter resolves via the new extension in `ui_helpers.dart`.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/entities/word_list.dart lib/presentation/utils/ui_helpers.dart lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart lib/presentation/screens/vocabulary/category_browse_screen.dart lib/presentation/screens/vocabulary/word_list_detail_screen.dart lib/presentation/widgets/vocabulary/path_node.dart
git commit -m "refactor: move WordListCategoryIcon to presentation layer (#3, #11)

Move UI extension from domain entity to ui_helpers.dart.
Replace duplicate _getCategoryColor with VocabularyColors.getCategoryColor."
```

---

### Task 5: Type `StudentWordListProgress.wordListCategory` as `WordListCategory` (#12)

**Files:**
- Modify: `lib/domain/entities/teacher.dart:169`
- Modify: `lib/data/models/teacher/student_word_list_progress_model.dart:54-67`
- Modify: `lib/presentation/screens/teacher/student_detail_screen.dart:675-676`

- [ ] **Step 1: Change entity field type**

In `lib/domain/entities/teacher.dart`, change the `wordListCategory` field (line 169) from:
```dart
  final String wordListCategory;
```
to:
```dart
  final WordListCategory wordListCategory;
```

Update the constructor parameter type accordingly (line 157):
```dart
    required this.wordListCategory,
```

Add the import at the top of the file:
```dart
import 'package:owlio_shared/owlio_shared.dart';
```

(Check if it's already imported — if `teacher.dart` already imports `owlio_shared`, no change needed.)

- [ ] **Step 2: Parse in model's `toEntity()`**

In `lib/data/models/teacher/student_word_list_progress_model.dart`, change `toEntity()` (line 59):

From:
```dart
      wordListCategory: wordListCategory,
```
To:
```dart
      wordListCategory: WordListCategory.fromDbValue(wordListCategory),
```

Add the import at the top:
```dart
import 'package:owlio_shared/owlio_shared.dart';
```

- [ ] **Step 3: Remove manual parsing at call site**

In `lib/presentation/screens/teacher/student_detail_screen.dart` (line 675-676), change:
```dart
    final color = VocabularyColors.getCategoryColor(
      WordListCategory.fromDbValue(progress.wordListCategory),
    );
```
To:
```dart
    final color = VocabularyColors.getCategoryColor(progress.wordListCategory);
```

- [ ] **Step 4: Run analyzer**

Run: `dart analyze lib/`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/teacher.dart lib/data/models/teacher/student_word_list_progress_model.dart lib/presentation/screens/teacher/student_detail_screen.dart
git commit -m "refactor: type wordListCategory as WordListCategory enum (#12)

Parse at model boundary in toEntity() instead of leaking raw
string to presentation layer."
```

---

### Task 6: Dead Provider Removal (#18)

**Files:**
- Modify: `lib/presentation/providers/vocabulary_provider.dart:66-77`

- [ ] **Step 1: Remove `dueForReviewProvider`**

In `lib/presentation/providers/vocabulary_provider.dart`, remove lines 66-77:

```dart
/// Provides words due for review
final dueForReviewProvider = FutureProvider<List<VocabularyWord>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final useCase = ref.watch(getDueForReviewUseCaseProvider);
  final result = await useCase(GetDueForReviewParams(userId: userId));
  return result.fold(
    (failure) => [],
    (words) => words,
  );
});
```

- [ ] **Step 2: Run analyzer**

Run: `dart analyze lib/`
Expected: No errors (confirmed no callers exist).

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/providers/vocabulary_provider.dart
git commit -m "refactor: remove dead dueForReviewProvider (#18)"
```

---

### Task 7: Session Summary Architecture Extraction (#2, #21)

**Files:**
- Modify: `lib/presentation/providers/vocabulary_provider.dart` (add `SessionSaveNotifier`)
- Modify: `lib/presentation/screens/vocabulary/session_summary_screen.dart:1-26,81-211`

- [ ] **Step 1: Create `SessionSaveNotifier` in `vocabulary_provider.dart`**

At the end of `lib/presentation/providers/vocabulary_provider.dart` (before the closing of the file), add:

```dart
// ============================================
// SESSION SAVE
// ============================================

enum SessionSaveStatus { idle, saving, saved, error }

class SessionSaveState {
  const SessionSaveState({
    this.status = SessionSaveStatus.idle,
    this.actualXpAwarded,
    this.errorMessage,
  });

  final SessionSaveStatus status;
  final int? actualXpAwarded;
  final String? errorMessage;
}

class SessionSaveNotifier extends StateNotifier<SessionSaveState> {
  SessionSaveNotifier(this._ref) : super(const SessionSaveState());

  final Ref _ref;

  Future<void> save({
    required String userId,
    required String listId,
    required int totalQuestions,
    required int correctCount,
    required int incorrectCount,
    required double accuracy,
    required int maxCombo,
    required int xpEarned,
    required int durationSeconds,
    required int wordsStrong,
    required int wordsWeak,
    required int firstTryPerfectCount,
    required List<SessionWordResult> wordResults,
  }) async {
    if (state.status == SessionSaveStatus.saving) return;
    state = const SessionSaveState(status: SessionSaveStatus.saving);

    final completeSessionUseCase = _ref.read(completeSessionUseCaseProvider);
    final result = await completeSessionUseCase(CompleteSessionParams(
      userId: userId,
      wordListId: listId,
      totalQuestions: totalQuestions,
      correctCount: correctCount,
      incorrectCount: incorrectCount,
      accuracy: accuracy,
      maxCombo: maxCombo,
      xpEarned: xpEarned,
      durationSeconds: durationSeconds,
      wordsStrong: wordsStrong,
      wordsWeak: wordsWeak,
      firstTryPerfectCount: firstTryPerfectCount,
      wordResults: wordResults,
    ));

    result.fold(
      (failure) {
        state = SessionSaveState(
          status: SessionSaveStatus.error,
          errorMessage: failure.message,
        );
      },
      (savedResult) {
        // Invalidate all dependent providers
        _ref.invalidate(progressForListProvider(listId));
        _ref.invalidate(userWordListProgressProvider);
        _ref.invalidate(wordListsWithProgressProvider);
        _ref.invalidate(learningPathProvider);
        _ref.invalidate(userVocabularyProgressProvider);
        _ref.invalidate(learnedWordsWithDetailsProvider);
        _ref.read(userControllerProvider.notifier).refreshProfileOnly();
        _ref.invalidate(leaderboardEntriesProvider);
        _ref.invalidate(dailyQuestProgressProvider);

        // Complete matching assignments
        _completeAssignments(userId: userId, listId: listId, accuracy: accuracy);

        state = SessionSaveState(
          status: SessionSaveStatus.saved,
          actualXpAwarded: savedResult.xpEarned,
        );
      },
    );
  }

  Future<void> _completeAssignments({
    required String userId,
    required String listId,
    required double accuracy,
  }) async {
    try {
      final getActiveAssignmentsUseCase = _ref.read(getActiveAssignmentsUseCaseProvider);
      final result = await getActiveAssignmentsUseCase(
        GetActiveAssignmentsParams(studentId: userId),
      );

      final assignments = result.fold(
        (failure) => <StudentAssignment>[],
        (assignments) => assignments,
      );

      for (final assignment in assignments) {
        if (assignment.wordListId == listId &&
            assignment.status != StudentAssignmentStatus.completed) {
          final completeAssignmentUseCase = _ref.read(completeAssignmentUseCaseProvider);
          await completeAssignmentUseCase(CompleteAssignmentParams(
            studentId: userId,
            assignmentId: assignment.assignmentId,
            score: accuracy,
          ));
          _ref.invalidate(studentAssignmentsProvider);
          _ref.invalidate(activeAssignmentsProvider);
          _ref.invalidate(studentAssignmentDetailProvider(assignment.assignmentId));
        }
      }

      // Check unit assignments
      for (final assignment in assignments) {
        if (assignment.scopeLpUnitId != null &&
            assignment.status != StudentAssignmentStatus.completed) {
          final calculateUseCase = _ref.read(calculateUnitProgressUseCaseProvider);
          await calculateUseCase(CalculateUnitProgressParams(
            assignmentId: assignment.assignmentId,
            studentId: userId,
          ));
          _ref.invalidate(studentAssignmentsProvider);
          _ref.invalidate(activeAssignmentsProvider);
          _ref.invalidate(studentAssignmentDetailProvider(assignment.assignmentId));
        }
      }
    } catch (_) {
      // Assignment completion is best-effort; session save already succeeded
    }
  }
}

final sessionSaveProvider =
    StateNotifierProvider.autoDispose<SessionSaveNotifier, SessionSaveState>(
  (ref) => SessionSaveNotifier(ref),
);
```

Add the required imports at the top of `vocabulary_provider.dart`:

```dart
import '../../domain/entities/student_assignment.dart';
import '../../domain/entities/vocabulary_session.dart';
import '../../domain/usecases/wordlist/complete_session_usecase.dart';
import '../../domain/usecases/student_assignment/complete_assignment_usecase.dart';
import '../../domain/usecases/student_assignment/calculate_unit_progress_usecase.dart';
import '../../domain/usecases/student_assignment/get_active_assignments_usecase.dart';
import 'student_assignment_provider.dart';
import 'leaderboard_provider.dart';
import 'daily_quest_provider.dart';
```

- [ ] **Step 2: Refactor `session_summary_screen.dart` to use `SessionSaveNotifier`**

Replace the imports section (lines 1-26). Remove domain UseCase imports, add:

```dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/router.dart';
import '../../../domain/entities/system_settings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/system_settings_provider.dart';
import '../../providers/usecase_providers.dart';
import '../../providers/user_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../providers/vocabulary_session_provider.dart';
import '../../utils/ui_helpers.dart';
```

Replace `_saveSession()` (lines 81-161) with:

```dart
  Future<void> _saveSession() async {
    if (_saving) return;
    setState(() => _saving = true);

    final controller = ref.read(vocabularySessionControllerProvider.notifier);
    final session = ref.read(vocabularySessionControllerProvider);
    final userId = ref.read(currentUserIdProvider);

    if (userId == null) {
      setState(() => _saving = false);
      return;
    }

    final settings = ref.read(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();
    final comboBonus = session.maxCombo * settings.comboBonusXp;
    setState(() => _comboBonus = comboBonus);

    final wordResults = controller.buildWordResults();
    final accuracy = session.correctCount + session.incorrectCount > 0
        ? (session.correctCount /
                (session.correctCount + session.incorrectCount)) *
            100
        : 0.0;

    await ref.read(sessionSaveProvider.notifier).save(
          userId: userId,
          listId: widget.listId,
          totalQuestions: session.totalQuestionsAnswered,
          correctCount: session.correctCount,
          incorrectCount: session.incorrectCount,
          accuracy: accuracy,
          maxCombo: session.maxCombo,
          xpEarned: session.xpEarned + comboBonus,
          durationSeconds: session.durationSeconds,
          wordsStrong: controller.wordsStrongCount,
          wordsWeak: controller.wordsWeakCount,
          firstTryPerfectCount: controller.firstTryPerfectCount,
          wordResults: wordResults,
        );

    final saveState = ref.read(sessionSaveProvider);
    if (!mounted) return;

    if (saveState.status == SessionSaveStatus.error) {
      setState(() => _saving = false);
      showAppSnackBar(
        context,
        'Failed to save session. Check your connection.',
        type: SnackBarType.error,
        actionLabel: 'Retry',
        onAction: _saveSession,
      );
    } else if (saveState.status == SessionSaveStatus.saved) {
      setState(() {
        _saved = true;
        _actualXpAwarded = saveState.actualXpAwarded;
      });
    }
  }
```

Delete `_completeVocabularyAssignment()` method entirely (lines 163-211).

- [ ] **Step 3: Run analyzer**

Run: `dart analyze lib/`
Expected: No errors. The removed imports (`complete_assignment_usecase.dart`, `calculate_unit_progress_usecase.dart`, `get_active_assignments_usecase.dart`, `complete_session_usecase.dart`, `student_assignment.dart`, `student_assignment_provider.dart`, `daily_quest_provider.dart`, `leaderboard_provider.dart`) should produce no warnings since they're no longer referenced in the screen.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/providers/vocabulary_provider.dart lib/presentation/screens/vocabulary/session_summary_screen.dart
git commit -m "refactor: extract session save logic to SessionSaveNotifier (#2, #21)

Move multi-UseCase orchestration from session_summary_screen to a
dedicated provider. Screen now calls sessionSaveProvider.save().
Removes 4 domain UseCase imports from screen and 3 debugPrint calls."
```

---

### Task 8: Fix N+1 Progress Queries in CategoryBrowseScreen (#13)

**Files:**
- Modify: `lib/presentation/screens/vocabulary/category_browse_screen.dart:29,43-59`

- [ ] **Step 1: Watch progress once and pass to list items**

In `lib/presentation/screens/vocabulary/category_browse_screen.dart`, change the build method.

Add a `userWordListProgressProvider` watch at the screen level (after line 29):

```dart
    final listsAsync = ref.watch(wordListsByCategoryProvider(category));
    final allProgress = ref.watch(userWordListProgressProvider).valueOrNull ?? [];
    final progressMap = {for (final p in allProgress) p.wordListId: p};
```

Then change the `ListView.builder` (lines 48-58) from:

```dart
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: lists.length,
                itemBuilder: (context, index) {
                  final list = lists[index];
                  final progressAsync = ref.watch(progressForListProvider(list.id));
                  return _WordListCard(
                    wordList: list,
                    progress: progressAsync.valueOrNull,
                  );
                },
              ),
```

to:

```dart
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: lists.length,
                itemBuilder: (context, index) {
                  final list = lists[index];
                  return _WordListCard(
                    wordList: list,
                    progress: progressMap[list.id],
                  );
                },
              ),
```

- [ ] **Step 2: Run analyzer**

Run: `dart analyze lib/presentation/screens/vocabulary/category_browse_screen.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/vocabulary/category_browse_screen.dart
git commit -m "perf: batch-load word list progress in CategoryBrowseScreen (#13)

Watch userWordListProgressProvider once instead of per-item
progressForListProvider. Eliminates N separate Supabase queries."
```

---

### Task 9: Add Pagination Guard (#14)

**Files:**
- Modify: `lib/data/repositories/supabase/supabase_word_list_repository.dart`

- [ ] **Step 1: Add `.limit(500)` to `getAllWordLists`**

In `lib/data/repositories/supabase/supabase_word_list_repository.dart`, in the `getAllWordLists` method, change:

```dart
    final response = await query.order('name', ascending: true);
```

to:

```dart
    final response = await query.order('name', ascending: true).limit(500);
```

- [ ] **Step 2: Commit**

```bash
git add lib/data/repositories/supabase/supabase_word_list_repository.dart
git commit -m "perf: add .limit(500) guard to getAllWordLists (#14)"
```

---

### Task 10: Missing Error States (#15, #16, #17)

**Files:**
- Modify: `lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart:21-22,44-47`
- Modify: `lib/presentation/screens/vocabulary/word_list_detail_screen.dart:19-47`
- Modify: `lib/presentation/screens/vocabulary/vocabulary_screen.dart:35-38,65-66`

- [ ] **Step 1: Fix `vocabulary_hub_screen.dart` (#15)**

Replace lines 21-22:
```dart
    final storyListsAsync = ref.watch(storyWordListsProvider);
    final storyLists = storyListsAsync.valueOrNull ?? [];
```

with:
```dart
    final storyListsAsync = ref.watch(storyWordListsProvider);
```

Then replace lines 44-47:
```dart
              // My Word Lists
              if (storyLists.isNotEmpty) ...[
                const _SectionHeader(title: 'My Word Lists'),
                _VerticalListSection(lists: storyLists),
              ],
```

with:
```dart
              // My Word Lists
              ...storyListsAsync.when(
                loading: () => [const SizedBox.shrink()],
                error: (e, _) => [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('Failed to load word lists', style: TextStyle(color: Colors.red.shade300)),
                  ),
                ],
                data: (storyLists) => storyLists.isEmpty
                    ? []
                    : [
                        const _SectionHeader(title: 'My Word Lists'),
                        _VerticalListSection(lists: storyLists),
                      ],
              ),
```

- [ ] **Step 2: Fix `word_list_detail_screen.dart` (#16)**

After line 38 (`final wordList = wordListAsync.valueOrNull;`), add error handling for `wordsAsync`:
```dart
    final wordsError = wordsAsync.hasError;
    final words = wordsAsync.valueOrNull ?? [];
```

Then in the UI, where words are displayed, add a fallback when `wordsError` is true — show a retry message. The exact placement depends on where words are listed in the widget tree. Find the words list section and wrap:

```dart
    if (wordsError)
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Failed to load words. Pull down to retry.',
            style: TextStyle(color: Colors.red.shade300)),
      ),
```

(Apply similarly for `progressAsync` error state — but since progress is non-critical display data, the `.valueOrNull` fallback to `null` is acceptable.)

- [ ] **Step 3: Fix `vocabulary_screen.dart` (#17)**

Replace lines 35-38:
```dart
    final learnedWordsAsync = ref.watch(learnedWordsWithDetailsProvider);

    // Extract learned words (starts from progress, not dictionary)
    final allWords = learnedWordsAsync.valueOrNull ?? [];
```

with:
```dart
    final learnedWordsAsync = ref.watch(learnedWordsWithDetailsProvider);
    final hasError = learnedWordsAsync.hasError;

    // Extract learned words (starts from progress, not dictionary)
    final allWords = learnedWordsAsync.valueOrNull ?? [];
```

Then update the body (around line 65), change:
```dart
      body: isLoading && allWords.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
```

to:
```dart
      body: isLoading && allWords.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : hasError && allWords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 12),
                      const Text('Failed to load vocabulary'),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(learnedWordsWithDetailsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
```

- [ ] **Step 4: Run analyzer**

Run: `dart analyze lib/presentation/screens/vocabulary/`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart lib/presentation/screens/vocabulary/word_list_detail_screen.dart lib/presentation/screens/vocabulary/vocabulary_screen.dart
git commit -m "fix: add missing error states to word list screens (#15, #16, #17)

- Hub: proper .when() for storyWordListsProvider
- Detail: error fallback for wordsAsync
- Word Bank: error + retry for learnedWordsWithDetailsProvider"
```

---

### Task 11: Stale Code Cleanup (#19, #20, retryWordIds)

**Files:**
- Modify: `lib/presentation/screens/vocabulary/vocabulary_session_screen.dart:33,37,91-96,299-302`
- Modify: `lib/presentation/widgets/vocabulary/path_node.dart:491`
- Modify: `lib/app/router.dart:309,312`

- [ ] **Step 1: Remove `retryWordIds` from `VocabularySessionScreen`**

In `lib/presentation/screens/vocabulary/vocabulary_session_screen.dart`:

Remove from constructor (lines 33 and keep the closing):
```dart
    this.retryWordIds,
```

Remove the field (line 37):
```dart
  final List<String>? retryWordIds; // If set, only these words (for "Tekrar Calis")
```

Remove the filter block in `_loadAndStart` (lines 91-96):
```dart
    // Filter to retry words if specified
    if (widget.retryWordIds != null && widget.retryWordIds!.isNotEmpty) {
      words = words
          .where((w) => widget.retryWordIds!.contains(w.id))
          .toList();
    }
```

- [ ] **Step 2: Remove `retryWordIds` from router**

In `lib/app/router.dart`, change lines 308-313 from:

```dart
                        builder: (context, state) {
                          final listId = state.pathParameters['listId']!;
                          final retryWordIds = state.extra as List<String>?;
                          return VocabularySessionScreen(
                            listId: listId,
                            retryWordIds: retryWordIds,
                          );
```

to:

```dart
                        builder: (context, state) {
                          final listId = state.pathParameters['listId']!;
                          return VocabularySessionScreen(
                            listId: listId,
                          );
```

- [ ] **Step 3: Remove stale comment in `vocabulary_session_screen.dart`**

Remove lines 299-302:
```dart
                  // Spacer for feedback area height to prevent content being hidden behind it
                  // Only if we want content to scroll above?
                  // For now, let's leave it full height, but maybe add bottom padding equal to expected feedback height?
                  // Actually, just letting it be is fine for now as feedback is an overlay.
```

- [ ] **Step 4: Remove stale comment in `path_node.dart`**

In `lib/presentation/widgets/vocabulary/path_node.dart`, remove line 491:
```dart
  // ... (existing helper methods)
```

- [ ] **Step 5: Run analyzer**

Run: `dart analyze lib/`
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/vocabulary/vocabulary_session_screen.dart lib/presentation/widgets/vocabulary/path_node.dart lib/app/router.dart
git commit -m "cleanup: remove stale comments, unused retryWordIds (#19, #20)

- Remove unused retryWordIds parameter (never populated)
- Remove thinking-out-loud comment block
- Remove placeholder comment in path_node
- Turkish comment removed with the retryWordIds field"
```

---

### Task 12: Security — RPC Auth Check (#4)

**Files:**
- Create: `supabase/migrations/YYYYMMDDHHMMSS_add_auth_check_to_vocab_session_rpc.sql`

- [ ] **Step 1: Create migration**

Create `supabase/migrations/20260327200000_add_auth_check_to_vocab_session_rpc.sql`:

```sql
-- Add auth.uid() verification to complete_vocabulary_session RPC
-- Prevents a client from writing session data for another user
-- Same pattern used in calculate_unit_assignment_progress (20260326000016)

CREATE OR REPLACE FUNCTION complete_vocabulary_session(
    p_user_id UUID,
    p_word_list_id UUID,
    p_total_questions INT,
    p_correct_count INT,
    p_incorrect_count INT,
    p_accuracy DECIMAL(5,2),
    p_max_combo INT,
    p_xp_earned INT,
    p_duration_seconds INT,
    p_words_strong INT,
    p_words_weak INT,
    p_first_try_perfect_count INT DEFAULT 0,
    p_word_results JSONB DEFAULT '[]'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_session_id UUID;
    v_total_xp INT;
    v_session_bonus INT;
    v_perfect_bonus INT;
    v_previous_best INT;
    v_xp_to_award INT;
    v_word JSONB;
    v_word_id UUID;
    v_incorrect INT;
    v_correct INT;
    v_current_ease DECIMAL(5,2);
    v_current_interval INT;
    v_current_reps INT;
    v_new_ease DECIMAL(5,2);
    v_new_interval INT;
    v_new_reps INT;
    v_new_status TEXT;
    v_next_review TIMESTAMPTZ;
BEGIN
    -- Auth check: ensure caller is the user they claim to be
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized: user mismatch';
    END IF;

    -- Get XP settings from system_settings
    SELECT COALESCE(
        (SELECT (value::JSONB->>'xp_vocab_session_bonus')::INT FROM system_settings WHERE key = 'xp_settings'),
        10
    ) INTO v_session_bonus;

    SELECT COALESCE(
        (SELECT (value::JSONB->>'xp_vocab_perfect_bonus')::INT FROM system_settings WHERE key = 'xp_settings'),
        20
    ) INTO v_perfect_bonus;

    -- Calculate total XP
    v_total_xp := p_xp_earned + v_session_bonus;
    IF p_accuracy = 100 THEN
        v_total_xp := v_total_xp + v_perfect_bonus;
    END IF;

    -- Delta anti-farming: only award XP above previous best
    SELECT COALESCE(best_score, 0) INTO v_previous_best
    FROM user_word_list_progress
    WHERE user_id = p_user_id AND word_list_id = p_word_list_id;

    IF NOT FOUND THEN
        v_previous_best := 0;
    END IF;

    v_xp_to_award := GREATEST(0, v_total_xp - v_previous_best);

    -- Create session record
    INSERT INTO vocabulary_sessions (
        user_id, word_list_id, total_questions, correct_count,
        incorrect_count, accuracy, max_combo, xp_earned,
        duration_seconds, words_strong, words_weak,
        first_try_perfect_count, completed_at
    ) VALUES (
        p_user_id, p_word_list_id, p_total_questions, p_correct_count,
        p_incorrect_count, p_accuracy, p_max_combo, v_total_xp,
        p_duration_seconds, p_words_strong, p_words_weak,
        p_first_try_perfect_count, NOW()
    ) RETURNING id INTO v_session_id;

    -- Process word results for SM-2
    FOR v_word IN SELECT * FROM jsonb_array_elements(p_word_results)
    LOOP
        v_word_id := (v_word->>'wordId')::UUID;
        v_incorrect := COALESCE((v_word->>'incorrectCount')::INT, 0);
        v_correct := COALESCE((v_word->>'correctCount')::INT, 0);

        -- Get current progress
        SELECT COALESCE(ease_factor, 2.5), COALESCE(interval_days, 0), COALESCE(repetitions, 0)
        INTO v_current_ease, v_current_interval, v_current_reps
        FROM vocabulary_progress
        WHERE user_id = p_user_id AND word_id = v_word_id;

        IF NOT FOUND THEN
            v_current_ease := 2.5;
            v_current_interval := 0;
            v_current_reps := 0;
        END IF;

        IF v_incorrect = 0 THEN
            -- Strong word: grow interval
            v_new_reps := v_current_reps + 1;
            v_new_ease := LEAST(v_current_ease + 0.02, 3.0);
            IF v_new_reps = 1 THEN
                v_new_interval := 1;
            ELSIF v_new_reps = 2 THEN
                v_new_interval := 6;
            ELSE
                v_new_interval := CEIL(v_current_interval * v_new_ease);
            END IF;
            v_new_interval := LEAST(v_new_interval, 365);
        ELSE
            -- Weak word: reset
            v_new_reps := 0;
            v_new_interval := 0;
            v_new_ease := GREATEST(v_current_ease - 0.2, 1.3);
        END IF;

        -- Determine status
        IF v_new_interval > 21 THEN
            v_new_status := 'mastered';
        ELSIF v_new_reps > 0 THEN
            v_new_status := 'reviewing';
        ELSE
            v_new_status := 'learning';
        END IF;

        v_next_review := NOW() + (v_new_interval || ' days')::INTERVAL;

        -- Upsert vocabulary_progress (never downgrade mastered)
        INSERT INTO vocabulary_progress (
            user_id, word_id, ease_factor, interval_days, repetitions,
            status, next_review_at, last_reviewed_at, updated_at
        ) VALUES (
            p_user_id, v_word_id, v_new_ease, v_new_interval, v_new_reps,
            v_new_status, v_next_review, NOW(), NOW()
        )
        ON CONFLICT (user_id, word_id) DO UPDATE SET
            ease_factor = EXCLUDED.ease_factor,
            interval_days = EXCLUDED.interval_days,
            repetitions = EXCLUDED.repetitions,
            status = CASE
                WHEN vocabulary_progress.status = 'mastered' THEN 'mastered'
                ELSE EXCLUDED.status
            END,
            next_review_at = EXCLUDED.next_review_at,
            last_reviewed_at = NOW(),
            updated_at = NOW();

        -- Save session word result
        INSERT INTO vocabulary_session_words (
            session_id, word_id, correct_count, incorrect_count
        ) VALUES (
            v_session_id, v_word_id, v_correct, v_incorrect
        );
    END LOOP;

    -- Upsert user_word_list_progress
    INSERT INTO user_word_list_progress (
        user_id, word_list_id, best_score, best_accuracy,
        total_sessions, last_session_at, started_at, completed_at, updated_at
    ) VALUES (
        p_user_id, p_word_list_id, v_total_xp, p_accuracy,
        1, NOW(), NOW(), NOW(), NOW()
    )
    ON CONFLICT (user_id, word_list_id) DO UPDATE SET
        best_score = GREATEST(user_word_list_progress.best_score, v_total_xp),
        best_accuracy = GREATEST(user_word_list_progress.best_accuracy, p_accuracy),
        total_sessions = user_word_list_progress.total_sessions + 1,
        last_session_at = NOW(),
        completed_at = COALESCE(user_word_list_progress.completed_at, NOW()),
        updated_at = NOW();

    -- Award XP (with delta)
    IF v_xp_to_award > 0 THEN
        PERFORM award_xp_transaction(p_user_id, v_xp_to_award, 'vocabulary_session', v_session_id::TEXT);
    END IF;

    -- Streak removed: now login-based (checked on app open)

    -- Badge check (always, even zero-delta)
    PERFORM check_and_award_badges(p_user_id);

    RETURN jsonb_build_object(
        'session_id', v_session_id,
        'xp_earned', v_xp_to_award,
        'total_xp', v_total_xp,
        'accuracy', p_accuracy
    );
END;
$$;
```

- [ ] **Step 2: Dry-run migration**

Run: `supabase db push --dry-run`
Expected: Shows the migration will be applied. No errors.

- [ ] **Step 3: Commit (do NOT push migration yet)**

```bash
git add supabase/migrations/20260327200000_add_auth_check_to_vocab_session_rpc.sql
git commit -m "security: add auth.uid() check to complete_vocabulary_session RPC (#4)

Prevents a client from submitting session data for another user.
SECURITY DEFINER function now verifies p_user_id matches auth.uid()."
```

---

### Task 13: Final Verification

- [ ] **Step 1: Run full analyzer**

Run: `dart analyze lib/`
Expected: No errors, no warnings related to changes.

- [ ] **Step 2: Update feature spec audit status**

In `docs/specs/06-word-lists.md`, update the Status column for all fixed findings from `TODO` to `Fixed`. Update the Checklist Result section accordingly.

- [ ] **Step 3: Commit spec updates**

```bash
git add docs/specs/06-word-lists.md
git commit -m "docs: update word lists spec — mark audit findings as fixed"
```
