# Vocabulary Hub Performance Optimization Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce vocabulary hub HTTP requests from ~15+N+M to ~10 by eliminating N+1 patterns, deduplicating queries, and batching sequential calls. Add empty state UX.

**Architecture:** Fix 5 independent performance issues: (1) reuse batch progress data instead of per-list queries, (2) add batch book fetch, (3) empty state in LearningPath, (4) derive story lists from cached data, (5) single RPC for due-review words.

**Tech Stack:** Flutter/Riverpod providers, Supabase PostgREST, PostgreSQL RPC

**Spec:** `docs/superpowers/specs/2026-03-27-vocabulary-hub-performance-design.md`

---

### Task 1: Eliminate `progressForListProvider` N+1 in vocabulary hub screen

**Files:**
- Modify: `lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart:117-138`

The `_VerticalListSection` widget currently calls `ref.watch(progressForListProvider(list.id))` per word list inside a `.map()` loop — N separate HTTP requests. The data is already available via `userWordListProgressProvider` which fetches ALL progress in one query and is already loaded by `learningPathProvider`.

- [ ] **Step 1: Refactor `_VerticalListSection` to use batch data**

Replace the entire `_VerticalListSection` class:

```dart
/// Vertical list of word list items
class _VerticalListSection extends ConsumerWidget {

  const _VerticalListSection({required this.lists});
  final List<WordList> lists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allProgress = ref.watch(userWordListProgressProvider).valueOrNull ?? [];
    final progressMap = {for (final p in allProgress) p.wordListId: p};

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: lists.map((list) {
          return _WordListTile(
            wordList: list,
            progress: progressMap[list.id],
          );
        }).toList(),
      ),
    );
  }
}
```

Note: change from `StatelessWidget` to `ConsumerWidget` so it can call `ref.watch` itself. Remove the `ref` constructor parameter.

- [ ] **Step 2: Update `_VerticalListSection` usage in `VocabularyHubScreen`**

In `VocabularyHubScreen.build()`, change:

```dart
// OLD
_VerticalListSection(lists: storyLists, ref: ref),
// NEW
_VerticalListSection(lists: storyLists),
```

- [ ] **Step 3: Verify**

Run: `dart analyze lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart`
Expected: 0 errors.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart
git commit -m "perf: eliminate N+1 progressForListProvider in vocabulary hub"
```

---

### Task 2: Batch book fetch — `getBooksByIds` repository + usecase + provider

**Files:**
- Modify: `lib/domain/repositories/book_repository.dart`
- Modify: `lib/data/repositories/supabase/supabase_book_repository.dart`
- Create: `lib/domain/usecases/book/get_books_by_ids_usecase.dart`
- Modify: `lib/presentation/providers/usecase_providers.dart`
- Modify: `lib/presentation/providers/book_provider.dart`
- Modify: `lib/presentation/providers/vocabulary_provider.dart`

- [ ] **Step 1: Add `getBooksByIds` to book repository interface**

In `lib/domain/repositories/book_repository.dart`, after the `getBookById` method (line 18), add:

```dart
  /// Fetch multiple books by IDs in a single query
  Future<Either<Failure, List<Book>>> getBooksByIds(List<String> ids);
```

- [ ] **Step 2: Implement `getBooksByIds` in Supabase repository**

In `lib/data/repositories/supabase/supabase_book_repository.dart`, after the `getBookById` method (after line 68), add:

```dart
  @override
  Future<Either<Failure, List<Book>>> getBooksByIds(List<String> ids) async {
    if (ids.isEmpty) return const Right([]);
    try {
      final response = await _supabase
          .from(DbTables.books)
          .select()
          .inFilter('id', ids);

      final books =
          (response as List).map((json) => _mapToBook(json)).toList();
      return Right(books);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
```

- [ ] **Step 3: Create `GetBooksByIdsUseCase`**

Create `lib/domain/usecases/book/get_books_by_ids_usecase.dart`:

```dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/book.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetBooksByIdsParams {
  const GetBooksByIdsParams({required this.ids});
  final List<String> ids;
}

class GetBooksByIdsUseCase implements UseCase<List<Book>, GetBooksByIdsParams> {
  const GetBooksByIdsUseCase(this._repository);
  final BookRepository _repository;

  @override
  Future<Either<Failure, List<Book>>> call(GetBooksByIdsParams params) {
    return _repository.getBooksByIds(params.ids);
  }
}
```

- [ ] **Step 4: Register usecase provider**

In `lib/presentation/providers/usecase_providers.dart`, find the book usecase providers section and add:

```dart
import '../../domain/usecases/book/get_books_by_ids_usecase.dart';
```

And the provider:

```dart
final getBooksByIdsUseCaseProvider = Provider<GetBooksByIdsUseCase>((ref) {
  return GetBooksByIdsUseCase(ref.watch(bookRepositoryProvider));
});
```

- [ ] **Step 5: Replace `bookByIdProvider` loop in `learningPathProvider`**

In `lib/presentation/providers/vocabulary_provider.dart`, replace the book fetching block (lines 637-655):

```dart
// OLD (N+1 pattern)
  final allBookIds = <String>{};
  for (final path in learningPaths) {
    for (final lpUnit in path.units) {
      for (final item in lpUnit.items) {
        if (item.itemType == LearningPathItemType.book) {
          allBookIds.add(item.itemId);
        }
      }
    }
  }
  final bookFutures = allBookIds.map(
    (id) => ref.watch(bookByIdProvider(id).future).then((b) => MapEntry(id, b)),
  );
  final bookEntries = await Future.wait(bookFutures);
  final bookMap = {
    for (final e in bookEntries)
      if (e.value != null) e.key: e.value!,
  };

// NEW (single batch query)
  final allBookIds = <String>{};
  for (final path in learningPaths) {
    for (final lpUnit in path.units) {
      for (final item in lpUnit.items) {
        if (item.itemType == LearningPathItemType.book) {
          allBookIds.add(item.itemId);
        }
      }
    }
  }
  final bookMap = <String, Book>{};
  if (allBookIds.isNotEmpty) {
    final useCase = ref.watch(getBooksByIdsUseCaseProvider);
    final result = await useCase(GetBooksByIdsParams(ids: allBookIds.toList()));
    result.fold(
      (_) {},
      (books) {
        for (final book in books) {
          bookMap[book.id] = book;
        }
      },
    );
  }
```

Add the import at the top of `vocabulary_provider.dart`:

```dart
import '../../domain/usecases/book/get_books_by_ids_usecase.dart';
```

Remove the `book_provider.dart` import if `bookByIdProvider` is no longer used in this file. Check first: `bookByIdProvider` is imported from `book_provider.dart`. After removing its usage, if nothing else in this file uses `book_provider.dart`, remove the import.

- [ ] **Step 6: Verify**

Run: `dart analyze lib/`
Expected: 0 errors.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/repositories/book_repository.dart lib/data/repositories/supabase/supabase_book_repository.dart lib/domain/usecases/book/get_books_by_ids_usecase.dart lib/presentation/providers/usecase_providers.dart lib/presentation/providers/vocabulary_provider.dart
git commit -m "perf: batch book fetch in learningPathProvider (N+1 → 1 query)"
```

---

### Task 3: Empty state in LearningPath widget

**Files:**
- Modify: `lib/presentation/widgets/vocabulary/learning_path.dart:36-37`

- [ ] **Step 1: Replace `SizedBox.shrink()` with empty state message**

In `lib/presentation/widgets/vocabulary/learning_path.dart`, replace:

```dart
// OLD
      data: (pathUnits) {
        if (pathUnits.isEmpty) return const SizedBox.shrink();
// NEW
      data: (pathUnits) {
        if (pathUnits.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Column(
              children: [
                Icon(Icons.route_rounded, size: 48, color: AppColors.neutralText.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text(
                  'No learning path yet',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.neutralText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your teacher will assign one soon!',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: AppColors.neutralText.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
```

- [ ] **Step 2: Verify**

Run: `dart analyze lib/presentation/widgets/vocabulary/learning_path.dart`
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/vocabulary/learning_path.dart
git commit -m "fix: show empty state message when no learning path assigned"
```

---

### Task 4: Derive `storyWordListsProvider` from cached `allWordListsProvider`

**Files:**
- Modify: `lib/presentation/providers/vocabulary_provider.dart:283-288`

- [ ] **Step 1: Change `storyWordListsProvider` to derive from cache**

In `lib/presentation/providers/vocabulary_provider.dart`, replace:

```dart
// OLD
/// Story vocabulary lists (from books user has read)
final storyWordListsProvider = FutureProvider<List<WordList>>((ref) async {
  final useCase = ref.watch(getAllWordListsUseCaseProvider);
  final result = await useCase(const GetAllWordListsParams(category: WordListCategory.storyVocab));
  return result.fold((f) => [], (lists) => lists);
});

// NEW
/// Story vocabulary lists — derived from allWordListsProvider (no extra HTTP request)
final storyWordListsProvider = FutureProvider<List<WordList>>((ref) async {
  final allLists = await ref.watch(allWordListsProvider.future);
  return allLists.where((l) => l.category == WordListCategory.storyVocab).toList();
});
```

- [ ] **Step 2: Verify**

Run: `dart analyze lib/presentation/providers/vocabulary_provider.dart`
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/providers/vocabulary_provider.dart
git commit -m "perf: derive storyWordListsProvider from cached allWordListsProvider"
```

---

### Task 5: Single RPC for `getDueForReview` (2 sequential → 1 query)

**Files:**
- Create: `supabase/migrations/20260327000008_get_due_review_words_rpc.sql`
- Modify: `packages/owlio_shared/lib/src/constants/rpc_functions.dart`
- Modify: `lib/data/repositories/supabase/supabase_vocabulary_repository.dart:237-285`

- [ ] **Step 1: Create migration**

Create `supabase/migrations/20260327000008_get_due_review_words_rpc.sql`:

```sql
-- Single RPC to fetch vocabulary words due for review (replaces 2 sequential queries)
CREATE OR REPLACE FUNCTION get_due_review_words(
  p_user_id UUID,
  p_limit INT DEFAULT 30
)
RETURNS SETOF vocabulary_words
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT vw.*
  FROM vocabulary_words vw
  INNER JOIN vocabulary_progress vp ON vp.word_id = vw.id
  WHERE vp.user_id = p_user_id
    AND vp.next_review_at <= NOW()
  ORDER BY vp.next_review_at ASC
  LIMIT p_limit;
$$;
```

- [ ] **Step 2: Push migration**

Run: `supabase db push`
Expected: Migration applied successfully.

- [ ] **Step 3: Add RPC constant to shared package**

In `packages/owlio_shared/lib/src/constants/rpc_functions.dart`, add in the appropriate section:

```dart
  // Vocabulary
  static const getDueReviewWords = 'get_due_review_words';
```

- [ ] **Step 4: Replace `getDueForReview` implementation**

In `lib/data/repositories/supabase/supabase_vocabulary_repository.dart`, replace the `getDueForReview` method (lines 237-285):

```dart
  @override
  Future<Either<Failure, List<VocabularyWord>>> getDueForReview(
    String userId,
  ) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.getDueReviewWords,
        params: {'p_user_id': userId, 'p_limit': 30},
      );

      final words = (response as List)
          .map((json) => VocabularyWordModel.fromJson(json).toEntity())
          .toList();

      return Right(words);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
```

- [ ] **Step 5: Verify**

Run: `dart analyze lib/` and `dart analyze packages/owlio_shared/lib/`
Expected: 0 errors.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/20260327000008_get_due_review_words_rpc.sql packages/owlio_shared/lib/src/constants/rpc_functions.dart lib/data/repositories/supabase/supabase_vocabulary_repository.dart
git commit -m "perf: single RPC for getDueForReview (2 sequential queries → 1)"
```
