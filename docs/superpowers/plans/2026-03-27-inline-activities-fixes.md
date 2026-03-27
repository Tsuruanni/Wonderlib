# Inline Activities Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all 21 actionable findings from the Inline Activities audit — data integrity, dead code, and UX issues.

**Architecture:** Three phases executed sequentially. Phase 1 modifies the data pipeline (DB → repository → usecase → provider). Phase 2 removes dead code and adds guard clauses. Phase 3 polishes UX (sound, loading, validation). Each phase is one commit.

**Tech Stack:** Flutter/Dart, Riverpod, Supabase (PostgreSQL), SQLite (offline cache)

**Spec:** `docs/superpowers/specs/2026-03-27-inline-activities-fixes-design.md`

---

## Phase 1: DB + Data Integrity

### Task 1: Add missing index on inline_activity_results

**Files:**
- Create: `supabase/migrations/20260327000001_add_inline_results_index.sql`

- [ ] **Step 1: Create migration file**

```sql
-- Performance index for daily quest progress queries.
-- get_quest_progress RPC counts correct answers per day:
--   WHERE user_id = X AND is_correct = true AND answered_at >= today
CREATE INDEX idx_inline_activity_results_user_answered
  ON inline_activity_results (user_id, answered_at DESC)
  WHERE is_correct = true;
```

- [ ] **Step 2: Dry-run the migration**

Run: `supabase db push --dry-run`
Expected: Shows the CREATE INDEX statement, no errors.

- [ ] **Step 3: Push migration**

Run: `supabase db push`
Expected: Migration applied successfully.

---

### Task 2: Fix getCompletedInlineActivities to return correctness

Changes the return type from `List<String>` to `Map<String, bool>` through the full chain: interface → supabase repo → cached repo → provider → screen.

**Files:**
- Modify: `lib/domain/repositories/book_repository.dart`
- Modify: `lib/data/repositories/supabase/supabase_book_repository.dart`
- Modify: `lib/data/repositories/cached/cached_book_repository.dart`
- Modify: `lib/presentation/providers/reader_provider.dart`
- Modify: `lib/presentation/screens/reader/reader_screen.dart`

- [ ] **Step 1: Update repository interface**

In `lib/domain/repositories/book_repository.dart`, change:

```dart
  Future<Either<Failure, List<String>>> getCompletedInlineActivities({
    required String userId,
    required String chapterId,
  });
```

to:

```dart
  /// Returns map of activityId → isCorrect for completed activities in this chapter.
  Future<Either<Failure, Map<String, bool>>> getCompletedInlineActivities({
    required String userId,
    required String chapterId,
  });
```

- [ ] **Step 2: Update Supabase repository implementation**

In `lib/data/repositories/supabase/supabase_book_repository.dart`, replace the `getCompletedInlineActivities` method (lines 442-479):

```dart
  @override
  Future<Either<Failure, Map<String, bool>>> getCompletedInlineActivities({
    required String userId,
    required String chapterId,
  }) async {
    try {
      // Get activity IDs for this chapter
      final activitiesResponse = await _supabase
          .from(DbTables.inlineActivities)
          .select('id')
          .eq('chapter_id', chapterId);

      final activityIds = (activitiesResponse as List)
          .map((a) => a['id'] as String)
          .toList();

      if (activityIds.isEmpty) {
        return const Right({});
      }

      // Get completed activities with correctness
      final resultsResponse = await _supabase
          .from(DbTables.inlineActivityResults)
          .select('inline_activity_id, is_correct')
          .eq('user_id', userId)
          .inFilter('inline_activity_id', activityIds);

      final completedMap = <String, bool>{};
      for (final r in resultsResponse as List) {
        completedMap[r['inline_activity_id'] as String] = r['is_correct'] as bool? ?? true;
      }

      return Right(completedMap);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
```

- [ ] **Step 3: Update cached repository**

In `lib/data/repositories/cached/cached_book_repository.dart`, replace the `getCompletedInlineActivities` method (lines 184-212):

```dart
  @override
  Future<Either<Failure, Map<String, bool>>> getCompletedInlineActivities({
    required String userId,
    required String chapterId,
  }) async {
    // 1. Try cache
    try {
      final cached = await _cacheStore.getCompletedInlineActivityIds(
        userId: userId,
        chapterId: chapterId,
      );
      if (cached.isNotEmpty) {
        // Cache only returns IDs, not correctness — assume true for cached
        return Right({for (final id in cached) id: true});
      }
    } catch (_) {
      // Cache read failed — fall through to remote.
    }

    // 2. Try remote
    if (!await _networkInfo.isConnected) {
      // Graceful degradation: return empty map instead of error
      return const Right({});
    }
    final result = await _remoteRepo.getCompletedInlineActivities(
      userId: userId,
      chapterId: chapterId,
    );

    return result;
  }
```

Note: This also fixes #24 (offline cold-start graceful degradation) by returning `Right({})` instead of `Left(NetworkFailure())`.

- [ ] **Step 4: Update InlineActivityStateNotifier and provider**

In `lib/presentation/providers/reader_provider.dart`, replace `loadFromList` with `loadFromMap` and add `removeCompleted` (lines 191-215):

```dart
class InlineActivityStateNotifier extends StateNotifier<Map<String, bool>> {
  InlineActivityStateNotifier() : super({});

  void markCompleted(String activityId, bool isCorrect) {
    state = {...state, activityId: isCorrect};
  }

  void loadFromMap(Map<String, bool> completedActivities) {
    state = Map.from(completedActivities);
  }

  void removeCompleted(String activityId) {
    state = Map.from(state)..remove(activityId);
  }

  bool isCompleted(String activityId) {
    return state.containsKey(activityId);
  }

  bool? getResult(String activityId) {
    return state[activityId];
  }

  void reset() {
    state = {};
  }
}
```

Also update `completedInlineActivitiesProvider` return type. Find the provider (search for `completedInlineActivitiesProvider`):

```dart
final completedInlineActivitiesProvider =
    FutureProvider.autoDispose.family<Map<String, bool>, String>((ref, chapterId) async {
```

Update its implementation to match the new `Map<String, bool>` return type from the use case.

- [ ] **Step 5: Update reader_screen.dart**

In `lib/presentation/screens/reader/reader_screen.dart`, change `loadFromList` to `loadFromMap` (line 103):

```dart
      ref.read(inlineActivityStateProvider.notifier).loadFromMap(completedResult);
```

- [ ] **Step 6: Run dart analyze**

Run: `dart analyze lib/`
Expected: No errors related to inline activity type changes.

---

### Task 3: Fix chapterInitializedProvider + DB save failure handling

**Files:**
- Modify: `lib/presentation/screens/reader/reader_screen.dart`
- Modify: `lib/presentation/providers/reader_provider.dart`

- [ ] **Step 1: Add finally block to _loadCompletedActivities**

In `lib/presentation/screens/reader/reader_screen.dart`, replace `_loadCompletedActivities` (lines 91-108):

```dart
  Future<void> _loadCompletedActivities() async {
    try {
      ref.read(inlineActivityStateProvider.notifier).reset();
      ref.invalidate(completedInlineActivitiesProvider(widget.chapterId));

      final completedResult = await ref.read(
        completedInlineActivitiesProvider(widget.chapterId).future,
      );

      // Check if still mounted after async operation
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

- [ ] **Step 2: Add failure rollback to handleInlineActivityCompletion**

In `lib/presentation/providers/reader_provider.dart`, replace the `result.fold` section in `_handleInlineActivityCompletionImpl` (lines 401-406):

```dart
  final completionResult = result.fold(
    (failure) {
      // Rollback local state — widget rebuilds to unanswered state
      ref.read(inlineActivityStateProvider.notifier).removeCompleted(activityId);
      debugPrint('⚠️ Activity $activityId save failed: $failure');
      return null;
    },
    (r) => r,
  );
```

- [ ] **Step 3: Add didUpdateWidget to all 4 activity widgets for rollback support**

In each of these files, add `didUpdateWidget` after `initState` (before `dispose`):

**`lib/presentation/widgets/inline_activities/inline_true_false_activity.dart`** — after line 57:

```dart
  @override
  void didUpdateWidget(covariant InlineTrueFalseActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCompleted && !widget.isCompleted) {
      setState(() {
        _isAnswered = false;
        _isCorrect = null;
        _selectedAnswer = null;
        _showXPAnimation = false;
      });
    }
  }
```

**`lib/presentation/widgets/inline_activities/inline_word_translation_activity.dart`** — after line 61:

```dart
  @override
  void didUpdateWidget(covariant InlineWordTranslationActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCompleted && !widget.isCompleted) {
      setState(() {
        _isAnswered = false;
        _isCorrect = null;
        _selectedAnswer = null;
        _showXPAnimation = false;
      });
    }
  }
```

**`lib/presentation/widgets/inline_activities/inline_find_words_activity.dart`** — after line 58:

```dart
  @override
  void didUpdateWidget(covariant InlineFindWordsActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCompleted && !widget.isCompleted) {
      setState(() {
        _isAnswered = false;
        _isCorrect = null;
        _selectedAnswers.clear();
        _showXPAnimation = false;
      });
    }
  }
```

**`lib/presentation/widgets/inline_activities/inline_matching_activity.dart`** — after line 81:

```dart
  @override
  void didUpdateWidget(covariant InlineMatchingActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCompleted && !widget.isCompleted) {
      setState(() {
        _isFinished = false;
        _isCorrect = null;
        _matchedPairs.clear();
        _selectedLeft = null;
        _selectedRight = null;
        _wrongLeft = null;
        _wrongRight = null;
        _mistakeCount = 0;
        _showXPAnimation = false;
        _shuffledRightItems = content.pairs.map((p) => p.right).toList()
          ..shuffle(Random());
      });
    }
  }
```

- [ ] **Step 4: Run dart analyze**

Run: `dart analyze lib/`
Expected: No errors.

---

### Task 4: Populate words_learned column

**Files:**
- Modify: `lib/domain/repositories/book_repository.dart`
- Modify: `lib/data/repositories/supabase/supabase_book_repository.dart`
- Modify: `lib/data/repositories/cached/cached_book_repository.dart`
- Modify: `lib/domain/usecases/activity/complete_inline_activity_usecase.dart`

- [ ] **Step 1: Add wordsLearned parameter to repository interface**

In `lib/domain/repositories/book_repository.dart`, update `saveInlineActivityResult`:

```dart
  /// Saves inline activity result and returns whether this is a NEW completion.
  /// Returns `Right(true)` if newly completed, `Right(false)` if already existed.
  Future<Either<Failure, bool>> saveInlineActivityResult({
    required String userId,
    required String activityId,
    required bool isCorrect,
    required int xpEarned,
    List<String> wordsLearned = const [],
  });
```

- [ ] **Step 2: Update Supabase repository**

In `lib/data/repositories/supabase/supabase_book_repository.dart`, update `saveInlineActivityResult` (lines 413-440):

```dart
  @override
  Future<Either<Failure, bool>> saveInlineActivityResult({
    required String userId,
    required String activityId,
    required bool isCorrect,
    required int xpEarned,
    List<String> wordsLearned = const [],
  }) async {
    try {
      // Optimistic insert - let DB UNIQUE constraint handle duplicates
      await _supabase.from(DbTables.inlineActivityResults).insert({
        'user_id': userId,
        'inline_activity_id': activityId,
        'is_correct': isCorrect,
        'xp_earned': xpEarned,
        'answered_at': DateTime.now().toIso8601String(),
        'words_learned': wordsLearned,
      });

      return const Right(true); // New completion - XP can be awarded
    } on PostgrestException catch (e) {
      // 23505 = unique_violation (already completed)
      if (e.code == '23505') {
        return const Right(false); // Already completed - no XP should be awarded
      }
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
```

- [ ] **Step 3: Update cached repository**

In `lib/data/repositories/cached/cached_book_repository.dart`, update `saveInlineActivityResult` signature (line 297) and pass through:

```dart
  @override
  Future<Either<Failure, bool>> saveInlineActivityResult({
    required String userId,
    required String activityId,
    required bool isCorrect,
    required int xpEarned,
    List<String> wordsLearned = const [],
  }) async {
    final online = await _networkInfo.isConnected;

    if (online) {
      final result = await _remoteRepo.saveInlineActivityResult(
        userId: userId,
        activityId: activityId,
        isCorrect: isCorrect,
        xpEarned: xpEarned,
        wordsLearned: wordsLearned,
      );
      // Cache the result on success
      result.fold((_) {}, (_) async {
        try {
          final bookId = await _cacheStore.getBookIdForActivity(activityId);
          await _cacheStore.saveInlineActivityResult(
            activityId: activityId,
            bookId: bookId,
            userId: userId,
            isCorrect: isCorrect,
            xpEarned: xpEarned,
          );
        } catch (_) {}
      });
      return result;
    }

    // Offline: check if already completed, save with dirty flag
    try {
      final alreadyExists =
          await _cacheStore.hasInlineActivityResult(activityId);
      if (alreadyExists) {
        return const Right(false); // Already completed — no XP
      }

      final bookId = await _cacheStore.getBookIdForActivity(activityId);
      await _cacheStore.saveInlineActivityResult(
        activityId: activityId,
        bookId: bookId,
        userId: userId,
        isCorrect: isCorrect,
        xpEarned: xpEarned,
        isDirty: true,
      );
      // Optimistically return true (new completion)
      return const Right(true);
    } catch (e) {
      return Left(
        CacheFailure('Failed to save inline activity result offline: $e'),
      );
    }
  }
```

- [ ] **Step 4: Pass wordsLearned in UseCase**

In `lib/domain/usecases/activity/complete_inline_activity_usecase.dart`, update the `saveInlineActivityResult` call (line 55-60):

```dart
    // 1. Save activity result to DB
    final saveResult = await _bookRepository.saveInlineActivityResult(
      userId: params.userId,
      activityId: params.activityId,
      isCorrect: params.isCorrect,
      xpEarned: params.xpEarned,
      wordsLearned: params.wordsLearned,
    );
```

Also update the vocab failure logging (line 75-78):

```dart
          wordsAdded = vocabResult.fold(
            (failure) {
              debugPrint('⚠️ Failed to add vocabulary words: $failure');
              return 0;
            },
            (progressList) => progressList.length,
          );
```

Add `import 'package:flutter/foundation.dart';` at the top if `debugPrint` is not already imported.

- [ ] **Step 5: Run dart analyze**

Run: `dart analyze lib/`
Expected: No errors.

---

### Task 5: Commit Phase 1

- [ ] **Step 1: Commit all Phase 1 changes**

```bash
git add supabase/migrations/20260327000001_add_inline_results_index.sql \
  lib/domain/repositories/book_repository.dart \
  lib/data/repositories/supabase/supabase_book_repository.dart \
  lib/data/repositories/cached/cached_book_repository.dart \
  lib/domain/usecases/activity/complete_inline_activity_usecase.dart \
  lib/presentation/providers/reader_provider.dart \
  lib/presentation/screens/reader/reader_screen.dart \
  lib/presentation/widgets/inline_activities/inline_true_false_activity.dart \
  lib/presentation/widgets/inline_activities/inline_word_translation_activity.dart \
  lib/presentation/widgets/inline_activities/inline_find_words_activity.dart \
  lib/presentation/widgets/inline_activities/inline_matching_activity.dart
```

```bash
git commit -m "fix: inline activity data integrity — index, initialization, error handling, words_learned, correctness tracking"
```

---

## Phase 2: Dead Code Removal + Code Quality

### Task 6: Remove dead UseCase, wrapper file, and widgetbook

**Files:**
- Delete: `lib/domain/usecases/activity/save_inline_activity_result_usecase.dart`
- Delete: `lib/presentation/widgets/inline_activities/inline_activity_wrapper.dart`
- Delete: `widgetbook/lib/components/activity_widgets.dart`
- Modify: `lib/presentation/providers/usecase_providers.dart`
- Modify: `widgetbook/lib/main.dart`

- [ ] **Step 1: Delete dead UseCase file**

Run: `rm lib/domain/usecases/activity/save_inline_activity_result_usecase.dart`

- [ ] **Step 2: Remove provider registration**

In `lib/presentation/providers/usecase_providers.dart`, remove the `saveInlineActivityResultUseCaseProvider` block (lines 308-310):

Delete:
```dart
final saveInlineActivityResultUseCaseProvider = Provider((ref) {
  return SaveInlineActivityResultUseCase(ref.watch(bookRepositoryProvider));
});
```

Also remove the import for `SaveInlineActivityResultUseCase` if it exists as a separate import. It's likely imported via `activity.dart` barrel or the usecase file directly — check and remove.

- [ ] **Step 3: Delete dead wrapper file**

Run: `rm lib/presentation/widgets/inline_activities/inline_activity_wrapper.dart`

- [ ] **Step 4: Delete broken widgetbook file and update main.dart**

Run: `rm widgetbook/lib/components/activity_widgets.dart`

In `widgetbook/lib/main.dart`, remove:
- The import for `activity_widgets.dart`
- The `WidgetbookFolder` block referencing `activityWidgets` (lines 30-34):

Delete:
```dart
        // Activity Widgets
        WidgetbookFolder(
          name: 'Activity Widgets',
          children: activityWidgets,
        ),
```

- [ ] **Step 5: Run dart analyze**

Run: `dart analyze lib/` and `dart analyze widgetbook/lib/`
Expected: No errors. No "unused import" warnings for removed files.

---

### Task 7: Remove xpReward field + use shared enum methods + remove dead model code

**Files:**
- Modify: `lib/domain/entities/activity.dart`
- Modify: `lib/data/models/activity/inline_activity_model.dart`

- [ ] **Step 1: Remove xpReward from entity**

In `lib/domain/entities/activity.dart`, update `InlineActivity`:

Remove `this.xpReward = 5,` from constructor (line 105).
Remove `final int xpReward;` field (line 112).
Remove `xpReward,` from `props` list (line 124).

Result:
```dart
class InlineActivity extends Equatable {

  const InlineActivity({
    required this.id,
    required this.type,
    required this.afterParagraphIndex,
    required this.content,
    this.vocabularyWords = const [],
  });
  final String id;
  final InlineActivityType type;
  final int afterParagraphIndex;
  final InlineActivityContent content;

  /// Words to add to vocabulary when this activity is completed
  /// (for word_translation and find_words types)
  final List<String> vocabularyWords;

  @override
  List<Object?> get props => [
    id,
    type,
    afterParagraphIndex,
    content,
    vocabularyWords,
  ];
}
```

Also remove the entire `InlineActivityResult` class (lines 130-153) — it is never constructed from DB and has no callers.

- [ ] **Step 2: Overhaul InlineActivityModel**

In `lib/data/models/activity/inline_activity_model.dart`, apply all changes:

1. Replace redundant enum parsing with shared methods
2. Remove `xpReward` from model
3. Add unknown type handling with null return
4. Remove entire `InlineActivityResultModel` class

Replace the entire file:

```dart
import 'package:flutter/foundation.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../domain/entities/activity.dart';

/// Model for InlineActivity entity - handles JSON serialization
class InlineActivityModel {

  const InlineActivityModel({
    required this.id,
    required this.type,
    required this.afterParagraphIndex,
    required this.content,
    this.vocabularyWords = const [],
  });

  /// Returns null for unknown activity types (filtered out by repository).
  static InlineActivityModel? fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    final knownTypes = InlineActivityType.values.map((e) => e.dbValue).toSet();
    if (typeStr == null || !knownTypes.contains(typeStr)) {
      debugPrint('⚠️ Unknown inline activity type: $typeStr, skipping');
      return null;
    }

    return InlineActivityModel(
      id: json['id'] as String,
      type: typeStr,
      afterParagraphIndex: json['after_paragraph_index'] as int? ?? 0,
      content: json['content'] as Map<String, dynamic>? ?? {},
      vocabularyWords: (json['vocabulary_words'] as List<dynamic>?)
              ?.map((w) => w as String)
              .toList() ??
          [],
    );
  }

  factory InlineActivityModel.fromEntity(InlineActivity entity) {
    return InlineActivityModel(
      id: entity.id,
      type: entity.type.dbValue,
      afterParagraphIndex: entity.afterParagraphIndex,
      content: _contentToJson(entity.type, entity.content),
      vocabularyWords: entity.vocabularyWords,
    );
  }
  final String id;
  final String type;
  final int afterParagraphIndex;
  final Map<String, dynamic> content;
  final List<String> vocabularyWords;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'after_paragraph_index': afterParagraphIndex,
      'content': content,
      'vocabulary_words': vocabularyWords,
    };
  }

  InlineActivity toEntity() {
    return InlineActivity(
      id: id,
      type: InlineActivityType.fromDbValue(type),
      afterParagraphIndex: afterParagraphIndex,
      content: _parseContent(type, content),
      vocabularyWords: vocabularyWords,
    );
  }

  static InlineActivityContent _parseContent(String type, Map<String, dynamic> json) {
    switch (type) {
      case 'true_false':
        return TrueFalseContent(
          statement: json['statement'] as String? ?? '',
          correctAnswer: json['correct_answer'] as bool? ?? true,
        );
      case 'word_translation':
        return WordTranslationContent(
          word: json['word'] as String? ?? '',
          correctAnswer: json['correct_answer'] as String? ?? '',
          options: (json['options'] as List<dynamic>?)?.map((o) => o as String).toList() ?? [],
        );
      case 'find_words':
        return FindWordsContent(
          instruction: json['instruction'] as String? ?? '',
          options: (json['options'] as List<dynamic>?)?.map((o) => o as String).toList() ?? [],
          correctAnswers:
              (json['correct_answers'] as List<dynamic>?)?.map((a) => a as String).toList() ?? [],
        );
      case 'matching':
        return MatchingContent(
          instruction: json['instruction'] as String? ?? '',
          pairs: (json['pairs'] as List<dynamic>?)
                  ?.whereType<Map<String, dynamic>>()
                  .map((p) => ActivityMatchingPair(
                        left: p['left'] as String? ?? '',
                        right: p['right'] as String? ?? '',
                      ))
                  .toList() ??
              [],
        );
      default:
        // Should not reach here due to fromJson null check, but defensive
        return const TrueFalseContent(
          statement: '',
          correctAnswer: true,
        );
    }
  }

  static Map<String, dynamic> _contentToJson(InlineActivityType type, InlineActivityContent content) {
    switch (type) {
      case InlineActivityType.trueFalse:
        final trueFalse = content as TrueFalseContent;
        return {
          'statement': trueFalse.statement,
          'correct_answer': trueFalse.correctAnswer,
        };
      case InlineActivityType.wordTranslation:
        final wordTrans = content as WordTranslationContent;
        return {
          'word': wordTrans.word,
          'correct_answer': wordTrans.correctAnswer,
          'options': wordTrans.options,
        };
      case InlineActivityType.findWords:
        final findWords = content as FindWordsContent;
        return {
          'instruction': findWords.instruction,
          'options': findWords.options,
          'correct_answers': findWords.correctAnswers,
        };
      case InlineActivityType.matching:
        final matching = content as MatchingContent;
        return {
          'instruction': matching.instruction,
          'pairs': matching.pairs
              .map((p) => {'left': p.left, 'right': p.right})
              .toList(),
        };
    }
  }
}
```

- [ ] **Step 3: Update repository to handle nullable fromJson**

In `lib/data/repositories/supabase/supabase_book_repository.dart`, find the `getInlineActivities` method and update the parsing to filter nulls:

Find the line that maps JSON to models (should be something like `.map((json) => InlineActivityModel.fromJson(json))`):

Replace with:
```dart
.map((json) => InlineActivityModel.fromJson(json as Map<String, dynamic>))
.whereType<InlineActivityModel>()
```

This filters out any null results from unknown types.

- [ ] **Step 4: Run dart analyze**

Run: `dart analyze lib/`
Expected: No errors. Check for any remaining references to `xpReward` or `InlineActivityResult`.

---

### Task 8: Guard clauses + mixin cleanup in find_words

**Files:**
- Modify: `lib/presentation/widgets/inline_activities/inline_find_words_activity.dart`
- Modify: `lib/presentation/widgets/inline_activities/inline_word_translation_activity.dart`

- [ ] **Step 1: Fix find_words — remove unused mixin, add guards**

In `lib/presentation/widgets/inline_activities/inline_find_words_activity.dart`:

Replace the state class declaration (line 33-34):

```dart
class _InlineFindWordsActivityState extends State<InlineFindWordsActivity> {
```

(Remove `with SingleTickerProviderStateMixin` — Phase 3 Task 11 will add `InlineActivitySoundMixin`.)

Add guard in `_toggleOption` (after line 61):

```dart
  void _toggleOption(String option) {
    if (_isAnswered || widget.isCompleted) return;
    if (requiredSelections == 0) return; // No correct answers defined
```

Fix the completed-wrong state in `initState` (line 52-55) — guard against empty options:

```dart
      } else {
        if (content.options.isNotEmpty) {
          _selectedAnswers.add(content.options.firstWhere(
            (o) => !content.correctAnswers.contains(o),
            orElse: () => content.options.first,
          ));
        }
      }
```

- [ ] **Step 2: Fix word_translation — guard against empty options**

In `lib/presentation/widgets/inline_activities/inline_word_translation_activity.dart`, update the completed-wrong state in `initState` (line 54-59):

```dart
      _selectedAnswer = widget.wasCorrect ?? false
          ? content.correctAnswer
          : content.options.isNotEmpty
              ? content.options.firstWhere(
                  (o) => o != content.correctAnswer,
                  orElse: () => content.options.first,
                )
              : '';
```

- [ ] **Step 3: Run dart analyze**

Run: `dart analyze lib/`
Expected: No errors.

---

### Task 9: Commit Phase 2

- [ ] **Step 1: Stage and commit**

```bash
git add -A
```

Verify with `git status` that only expected files are staged. Then:

```bash
git commit -m "chore: remove inline activity dead code, add guard clauses, use shared enum methods"
```

---

## Phase 3: UX Polish

### Task 10: Chapter completion flash fix

**Files:**
- Modify: `lib/presentation/providers/reader_provider.dart`

- [ ] **Step 1: Add initialization check to isChapterCompleteProvider**

In `lib/presentation/providers/reader_provider.dart`, replace `isChapterCompleteProvider` (lines 304-312):

```dart
/// Whether all activities in the chapter are completed
/// Note: If there are no activities, chapter is considered complete
/// Returns false while activities are still loading to prevent flash
final isChapterCompleteProvider = Provider.autoDispose<bool>((ref) {
  final initialized = ref.watch(chapterInitializedProvider);
  if (!initialized) return false; // Don't evaluate until activities loaded

  final completedActivities = ref.watch(inlineActivityStateProvider);
  final totalActivities = ref.watch(totalActivitiesProvider);

  // If no activities, chapter is complete (can proceed to next)
  if (totalActivities == 0) return true;

  return completedActivities.length >= totalActivities;
});
```

---

### Task 11: Add sound feedback to find_words

**Files:**
- Modify: `lib/presentation/widgets/inline_activities/inline_find_words_activity.dart`

- [ ] **Step 1: Add InlineActivitySoundMixin**

In `lib/presentation/widgets/inline_activities/inline_find_words_activity.dart`:

Add import at top:
```dart
import 'inline_activity_sound_mixin.dart';
```

Update state class (which was changed in Task 8 to remove `SingleTickerProviderStateMixin`):

```dart
class _InlineFindWordsActivityState extends State<InlineFindWordsActivity>
    with InlineActivitySoundMixin {
```

Add `initSoundPlayer()` at the start of `initState`:
```dart
  @override
  void initState() {
    super.initState();
    initSoundPlayer();
    // ... rest of initState
  }
```

Add `dispose`:
```dart
  @override
  void dispose() {
    disposeSoundPlayer();
    super.dispose();
  }
```

In `_submitAnswer` (line 78-98), add `playSound` after calculating `isCorrect`:

```dart
  void _submitAnswer() {
    if (_isAnswered) return;

    final correctSet = content.correctAnswers.toSet();
    final isCorrect = _selectedAnswers.length == correctSet.length &&
        _selectedAnswers.every((answer) => correctSet.contains(answer));

    playSound(isCorrect);

    setState(() {
      _isAnswered = true;
      _isCorrect = isCorrect;
      if (_isCorrect!) {
        _showXPAnimation = true;
      }
    });

    widget.onAnswer(
      _isCorrect!,
      widget.activity.vocabularyWords,
    );
  }
```

---

### Task 12: Loading flicker fix for activity blocks

**Files:**
- Modify: `lib/presentation/widgets/reader/reader_content_block_list.dart`

- [ ] **Step 1: Track activities loading state**

In `lib/presentation/widgets/reader/reader_content_block_list.dart`, update the build method (around line 138-153):

```dart
    return blocksAsync.when(
      data: (blocks) {
        final activitiesLoading = inlineActivitiesAsync.isLoading;
        final inlineActivities = inlineActivitiesAsync.maybeWhen(
          data: (activities) => activities,
          orElse: () => <InlineActivity>[],
        );

        // Build activity map by ID for quick lookup
        final activityMap = <String, InlineActivity>{};
        for (final activity in inlineActivities) {
          activityMap[activity.id] = activity;
        }

        // Build visible blocks (stop at first uncompleted activity)
        final visibleBlocks = _getVisibleBlocks(blocks, activityMap, completedActivities);
```

Then find where `ReaderActivityBlock` is constructed with a null `activity`. Pass a loading flag to handle the placeholder. The exact location depends on `_getVisibleBlocks` — find where it builds the activity block widget and update:

Where `activity` is looked up from `activityMap` and could be null, add:

```dart
if (block.type == ContentBlockType.activity && activityMap[block.activityId] == null && activitiesLoading) {
  // Show placeholder instead of error while activities are loading
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    child: Container(
      height: 120,
      decoration: BoxDecoration(
        color: settings.theme.text.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
```

---

### Task 13: Matching duplicate right-values — index-based matching

**Files:**
- Modify: `lib/presentation/widgets/inline_activities/inline_matching_activity.dart`
- Modify: `owlio_admin/lib/features/books/widgets/activity_editor.dart`

- [ ] **Step 1: Change matching to index-based pairing**

In `lib/presentation/widgets/inline_activities/inline_matching_activity.dart`:

Change `_matchedPairs` type from `Map<String, String>` to `Map<int, int>` (left index → right index):

```dart
  /// Successfully matched pairs: left index → right index
  final Map<int, int> _matchedPairs = {};
```

Update `_onTapLeft` (line 97-111) — use index instead of value:

```dart
  void _onTapLeft(int leftIndex) {
    if (_isFinished || widget.isCompleted) return;
    if (_matchedPairs.containsKey(leftIndex)) return; // Already matched

    setState(() {
      _selectedLeft = leftIndex;
      _wrongLeft = null;
      _wrongRight = null;
    });

    if (_selectedRight != null) {
      _tryMatch();
    }
  }
```

Update `_onTapRight` (line 113-127):

```dart
  void _onTapRight(int rightIndex) {
    if (_isFinished || widget.isCompleted) return;
    if (_matchedPairs.containsValue(rightIndex)) return; // Already matched

    setState(() {
      _selectedRight = rightIndex;
      _wrongLeft = null;
      _wrongRight = null;
    });

    if (_selectedLeft != null) {
      _tryMatch();
    }
  }
```

Update `_selectedLeft` and `_selectedRight` types from `String?` to `int?`:

```dart
  int? _selectedLeft;
  int? _selectedRight;
  int? _wrongLeft;
  int? _wrongRight;
```

Update `_tryMatch` (line 129-167):

```dart
  void _tryMatch() {
    final leftIdx = _selectedLeft!;
    final rightIdx = _selectedRight!;
    final leftValue = content.pairs[leftIdx].left;
    final correctRight = _getCorrectRight(leftValue);
    final rightValue = _shuffledRightItems[rightIdx];

    if (rightValue == correctRight) {
      // Correct match
      playSound(true);
      setState(() {
        _matchedPairs[leftIdx] = rightIdx;
        _selectedLeft = null;
        _selectedRight = null;
      });

      // Check if all matched
      if (_matchedPairs.length == content.pairs.length) {
        _onAllMatched();
      }
    } else {
      // Wrong match
      playSound(false);
      _mistakeCount++;
      setState(() {
        _wrongLeft = leftIdx;
        _wrongRight = rightIdx;
        _selectedLeft = null;
        _selectedRight = null;
      });

      // Reset wrong indicators after 500ms
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _wrongLeft = null;
            _wrongRight = null;
          });
        }
      });
    }
  }
```

Update `initState` completed state (line 73-80) to use indices:

```dart
    if (widget.isCompleted) {
      _isFinished = true;
      _isCorrect = widget.wasCorrect;
      // Show all pairs matched by index
      for (var i = 0; i < content.pairs.length; i++) {
        final rightIdx = _shuffledRightItems.indexOf(content.pairs[i].right);
        if (rightIdx >= 0) {
          _matchedPairs[i] = rightIdx;
        }
      }
    }
```

Update the build method's left/right button rendering to use indices. Find `_onTapLeft(pair.left)` and change to `_onTapLeft(index)`. Find `_onTapRight(right)` and change to `_onTapRight(rightIndex)`. The matched/selected checks change from value-based to index-based:

```dart
// Left button: check by index
final isMatched = _matchedPairs.containsKey(index);
final isSelected = _selectedLeft == index;
final isWrong = _wrongLeft == index;

// Right button: check by index
final isMatched = _matchedPairs.containsValue(rightIndex);
final isSelected = _selectedRight == rightIndex;
final isWrong = _wrongRight == rightIndex;
```

Update `didUpdateWidget` (added in Task 3) — `_matchedPairs.clear()` already works since it's still a `Map`.

- [ ] **Step 2: Add admin editor duplicate validation**

In `owlio_admin/lib/features/books/widgets/activity_editor.dart`, find the `_handleSave` method for matching type. Before saving, add validation:

```dart
// Check for duplicate right values in matching pairs
if (type == 'matching') {
  final rightValues = pairs.map((p) => p['right'] as String).toList();
  final uniqueRights = rightValues.toSet();
  if (uniqueRights.length != rightValues.length) {
    setState(() {
      _error = 'Matching pairs must have unique right-side values';
    });
    return;
  }
}
```

- [ ] **Step 3: Translate Turkish labels to English**

In `owlio_admin/lib/features/books/widgets/activity_editor.dart`:

Line 680: Change `'İptal'` to `'Cancel'`
Line 691: Change `'Kaydet'` to `'Save'`

- [ ] **Step 4: Run dart analyze**

Run: `dart analyze lib/` and `dart analyze owlio_admin/lib/`
Expected: No errors.

---

### Task 14: Commit Phase 3

- [ ] **Step 1: Stage and commit**

```bash
git add -A
```

Verify with `git status`. Then:

```bash
git commit -m "fix: inline activity UX — sound feedback, loading states, matching validation, admin English labels"
```

---

## Phase 4: Documentation Update

### Task 15: Update audit findings status

**Files:**
- Modify: `docs/specs/03-inline-activities.md`

- [ ] **Step 1: Update finding statuses**

In `docs/specs/03-inline-activities.md`, update the Findings table. Change `TODO` to `Fixed` for all findings except #9 (Accepted) and deferred ones:

| # | Status change |
|---|--------------|
| 1-8 | TODO → Fixed |
| 9 | TODO → Accepted |
| 10-15 | TODO → Fixed |
| 16 | TODO → Deferred |
| 17-18 | TODO → Fixed |
| 19 | TODO → Accepted |
| 20-23 | TODO → Fixed |
| 24 | TODO → Fixed (partial — graceful degradation) |
| 25 | TODO → Fixed |

Update the Checklist Result section to reflect PASS for all categories.

- [ ] **Step 2: Commit**

```bash
git add docs/specs/03-inline-activities.md
git commit -m "docs: mark inline activity audit findings as resolved"
```

---

## Final Verification

- [ ] Run `dart analyze lib/` — must pass with no errors
- [ ] Run `dart analyze owlio_admin/lib/` — must pass
- [ ] Manual test: complete each of 4 activity types (correct + incorrect)
- [ ] Manual test: re-open completed chapter — verify correct/incorrect state preserved
- [ ] Manual test: trigger DB save failure (e.g., airplane mode mid-answer) — verify activity resets to unanswered
