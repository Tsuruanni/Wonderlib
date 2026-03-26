# Vocabulary Hub Performance Optimization

**Date:** 2026-03-27
**Status:** Spec
**Scope:** `vocabulary_provider.dart`, `vocabulary_hub_screen.dart`, `book_provider.dart`, `daily_review_provider.dart`, `supabase_vocabulary_repository.dart`, `book_repository.dart`

---

## Problem

The `/vocabulary` route (`VocabularyHubScreen`) is slow to render and sometimes appears blank. Root causes:

1. **15 + N + M HTTP requests** on first load (N = story word lists, M = books in path)
2. **N+1 query patterns** in two places
3. **Silent blank screen** when auth hasn't settled (no loading indicator)
4. **Duplicate fetch** of word lists data
5. **Sequential queries** that could be parallel or batched

---

## Fix 1: Eliminate `progressForListProvider` N+1 — Reuse batch data

### Current behavior

`_VerticalListSection.build()` calls `ref.watch(progressForListProvider(list.id))` per story word list. Each triggers a separate Supabase HTTP request to `user_word_list_progress` table.

### Target behavior

Reuse the already-fetched `userWordListProgressProvider` (which fetches ALL progress in one query) instead of per-list queries.

### Changes

**`vocabulary_hub_screen.dart`:**
- `_VerticalListSection` watches `userWordListProgressProvider` once and builds a `Map<String, UserWordListProgress>` lookup
- Each `_WordListTile` receives its progress from the pre-fetched map
- Remove `ref.watch(progressForListProvider(...))` from the build loop

**Result:** N HTTP requests → 0 additional requests (data already fetched by `learningPathProvider`)

---

## Fix 2: Eliminate `bookByIdProvider` N+1 — Batch book fetch

### Current behavior

`learningPathProvider` collects all book IDs, then fetches each via `ref.watch(bookByIdProvider(id).future)` — M separate HTTP requests.

### Target behavior

Add a `getBooksByIds` method to fetch all books in a single `WHERE id IN (...)` query.

### Changes

**`book_repository.dart` (interface):**
- Add: `Future<Either<Failure, List<Book>>> getBooksByIds(List<String> ids)`

**`supabase_book_repository.dart` (implementation):**
- Implement `getBooksByIds` using `.inFilter('id', ids)` — single Supabase query

**`get_books_by_ids_usecase.dart` (new usecase):**
- Standard UseCase wrapping the new repository method

**`usecase_providers.dart`:**
- Register `getBooksByIdsUseCaseProvider`

**`book_provider.dart`:**
- Add `booksByIdsProvider` — `FutureProvider.family<Map<String, Book>, List<String>>`

**`vocabulary_provider.dart` — `learningPathProvider`:**
- Replace the `bookByIdProvider` loop with a single `booksByIdsProvider` call
- Build `bookMap` from the batch result

**Result:** M HTTP requests → 1 HTTP request

---

## Fix 3: Empty state — Show message when no learning path exists

### Current behavior

When `learningPathProvider` resolves with an empty list (no learning path assigned to user's school/grade/class), `LearningPath` renders `SizedBox.shrink()` — completely invisible. Combined with empty story word lists, the screen appears blank below the TopNavbar.

**Note:** Loading state is already handled correctly by `LearningPath.when(loading: ...)`. The issue is only with empty data.

### Target behavior

Show a helpful empty state message when there are no learning paths, instead of invisible `SizedBox.shrink()`.

### Changes

**`learning_path.dart`:**
- Replace `if (pathUnits.isEmpty) return const SizedBox.shrink();` with an empty state widget showing a message like "No learning path assigned yet. Ask your teacher to set one up."

---

## Fix 4: Eliminate duplicate word lists fetch

### Current behavior

Two independent providers fetch word lists:
- `storyWordListsProvider` — `GetAllWordListsParams(category: storyVocab)` → HTTP request #1
- `allWordListsProvider` (inside `learningPathProvider`) — `GetAllWordListsParams()` → HTTP request #2

Both hit the `word_lists` table. The `allWordListsProvider` result is a superset of `storyWordListsProvider`.

### Target behavior

Derive story word lists from the already-fetched `allWordListsProvider` data instead of making a separate query.

### Changes

**`vocabulary_provider.dart`:**
- Change `storyWordListsProvider` to derive from `allWordListsProvider`:
  ```dart
  final storyWordListsProvider = FutureProvider<List<WordList>>((ref) async {
    final allLists = await ref.watch(allWordListsProvider.future);
    return allLists.where((l) => l.category == WordListCategory.storyVocab).toList();
  });
  ```

**Result:** 1 HTTP request eliminated. Both providers share the same cached data.

---

## Fix 5: Parallelize `getDueForReview` sequential queries

### Current behavior

`getDueForReview` in `supabase_vocabulary_repository.dart` runs two sequential queries:
1. `SELECT word_id FROM vocabulary_progress WHERE next_review_at <= now()` → wait
2. `SELECT * FROM vocabulary_words WHERE id IN (...)` → wait

Total: 2 sequential round-trips (200-800ms on web).

### Target behavior

Create a single Supabase RPC function that returns due words with their details in one query, or use a PostgREST join.

### Approach: RPC function

**New migration — `get_due_review_words` RPC:**
```sql
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

**`supabase_vocabulary_repository.dart`:**
- Replace the two-query `getDueForReview` with a single RPC call

**`owlio_shared` package:**
- Add `RpcFunctions.getDueReviewWords` constant

**Result:** 2 sequential HTTP requests → 1 HTTP request

---

## Summary of HTTP Request Reduction

| Provider | Before | After |
|----------|--------|-------|
| `progressForListProvider` × N | N requests | 0 (reuse batch) |
| `bookByIdProvider` × M | M requests | 1 (batch query) |
| `storyWordListsProvider` | 1 request | 0 (derive from cache) |
| `getDueForReview` | 2 sequential | 1 (RPC) |
| **Total saved** | **N + M + 2** | — |

For a typical user with 10 word lists and 5 books: **~17 fewer HTTP requests**, and the remaining requests run fully in parallel.

---

## Out of Scope

- `userControllerProvider` streak chain optimization (separate concern, affects all screens)
- `loginDatesProvider` direct Supabase call (low impact, affects TopNavbar only)
- `getNewWords` unbounded progress query (not on vocabulary hub hot path)
- `canStartWordListProvider` using `progressForListProvider` — will automatically benefit from Fix 1 if refactored to use batch data
