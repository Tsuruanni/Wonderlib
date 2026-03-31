# Home Page Removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the home page, redistribute its sections to Library (continue reading), Learning Path (daily review), and a new Quests page (daily quests + badges), then update navigation.

**Architecture:** Each home section migrates to its natural context. A new `QuestsScreen` is created with daily quests, badges grid, and placeholder cards for monthly features. The router replaces the Home branch with a Quests branch and makes Learning Path the default tab.

**Tech Stack:** Flutter, Riverpod, GoRouter, Supabase (for new `getAllBadges` query)

---

### Task 1: Add "Continue Reading" section to Library

**Files:**
- Modify: `lib/presentation/screens/library/library_screen.dart:309-322`
- Reference: `lib/presentation/screens/home/home_screen.dart:351-455` (BookCard to copy)

- [ ] **Step 1: Add imports to library_screen.dart**

Add this import at the top of `library_screen.dart`:

```dart
import '../../providers/book_quiz_provider.dart';
```

The file already imports `book_provider.dart` (which exports `continueReadingProvider` and `readingProgressProvider`), `go_router`, `google_fonts`, `pressable_scale.dart`, and `theme.dart`.

- [ ] **Step 2: Add Continue Reading sliver to CustomScrollView**

In `LibraryScreen.build`, find the `CustomScrollView` slivers list (currently at line 309). Insert a `_ContinueReadingSection` sliver before the level shelves:

```dart
return CustomScrollView(
  physics: const BouncingScrollPhysics(),
  slivers: [
    const SliverToBoxAdapter(child: SizedBox(height: 12)),
    // Continue Reading section
    SliverToBoxAdapter(
      child: _ContinueReadingSection(),
    ),
    for (final level in booksByLevel.keys)
      SliverToBoxAdapter(
        child: _LibraryShelf(
          level: level,
          books: booksByLevel[level]!,
        ),
      ),
    const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
  ],
);
```

- [ ] **Step 3: Add _ContinueReadingSection widget**

Add this widget class at the bottom of `library_screen.dart` (before the closing of the file). This replicates the home screen's continue reading logic:

```dart
class _ContinueReadingSection extends ConsumerWidget {
  const _ContinueReadingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continueReadingAsync = ref.watch(continueReadingProvider);

    return continueReadingAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (books) {
        if (books.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              Row(
                children: [
                  Text(
                    'Continue Reading',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${books.length}',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Horizontal book list
              SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: books.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => _ContinueReadingCard(book: books[index]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Add _ContinueReadingCard widget**

Add this widget class right after `_ContinueReadingSection`. This is the same card from home_screen.dart:

```dart
class _ContinueReadingCard extends ConsumerWidget {
  const _ContinueReadingCard({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isQuizReady =
        ref.watch(isQuizReadyProvider(book.id)).valueOrNull ?? false;
    final progress =
        ref.watch(readingProgressProvider(book.id)).valueOrNull;
    final percentage = progress?.completionPercentage ?? 0;

    return PressableScale(
      onTap: () => context.go(AppRoutes.bookDetailPath(book.id)),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neutral, width: 2),
          boxShadow: [
            BoxShadow(color: AppColors.neutral, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: Image.network(
                      book.coverUrl ?? '',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        child: Icon(Icons.book, color: AppColors.primary),
                      ),
                    ),
                  ),
                  if (isQuizReady)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.quiz_rounded, size: 12, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              'Quiz',
                              style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (percentage > 0 && percentage < 100)
              ClipRRect(
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: AppColors.neutral.withValues(alpha: 0.3),
                  color: AppColors.secondary,
                  minHeight: 3,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    book.level,
                    style: GoogleFonts.nunito(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Verify**

Run: `dart analyze lib/presentation/screens/library/library_screen.dart`
Expected: No issues

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/library/library_screen.dart
git commit -m "feat: add continue reading section to library screen"
```

---

### Task 2: Remove "Recommended for You"

**Files:**
- Modify: `lib/presentation/providers/book_provider.dart:98-108` (remove provider)
- Modify: `lib/presentation/providers/usecase_providers.dart:183-185` (remove usecase provider)
- Modify: `lib/presentation/screens/reader/reader_screen.dart:238,254,265` (remove invalidation lines)
- Modify: `lib/domain/repositories/book_repository.dart:25` (remove method)
- Modify: `lib/data/repositories/supabase/supabase_book_repository.dart:119-150` (remove method)
- Modify: `lib/data/repositories/cached/cached_book_repository.dart:502-503` (remove method)
- Delete: `lib/domain/usecases/book/get_recommended_books_usecase.dart`

- [ ] **Step 1: Remove recommendedBooksProvider from book_provider.dart**

Delete lines 98-108 (the entire `recommendedBooksProvider` definition):

```dart
// DELETE THIS BLOCK:
final recommendedBooksProvider = FutureProvider<List<Book>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final useCase = ref.watch(getRecommendedBooksUseCaseProvider);
  final result = await useCase(GetRecommendedBooksParams(userId: userId));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (books) => books,
  );
});
```

Also remove the `GetRecommendedBooksParams` import if it becomes unused.

- [ ] **Step 2: Remove getRecommendedBooksUseCaseProvider from usecase_providers.dart**

Delete lines 183-185:

```dart
// DELETE THIS BLOCK:
final getRecommendedBooksUseCaseProvider = Provider((ref) {
  return GetRecommendedBooksUseCase(ref.watch(bookRepositoryProvider));
});
```

Remove the `GetRecommendedBooksUseCase` import.

- [ ] **Step 3: Remove invalidation lines from reader_screen.dart**

Delete the three `ref.invalidate(recommendedBooksProvider);` lines at lines 238, 254, and 265. Also remove the `recommendedBooksProvider` import if it becomes unused.

- [ ] **Step 4: Remove getRecommendedBooks from repository interface and implementations**

In `lib/domain/repositories/book_repository.dart`, delete line 25:
```dart
Future<Either<Failure, List<Book>>> getRecommendedBooks(String userId);
```

In `lib/data/repositories/supabase/supabase_book_repository.dart`, delete lines 119-150 (the entire `getRecommendedBooks` method).

In `lib/data/repositories/cached/cached_book_repository.dart`, delete lines 502-503:
```dart
@override
Future<Either<Failure, List<Book>>> getRecommendedBooks(String userId) {
  return _remoteRepo.getRecommendedBooks(userId);
}
```

- [ ] **Step 5: Delete the usecase file**

```bash
rm lib/domain/usecases/book/get_recommended_books_usecase.dart
```

- [ ] **Step 6: Verify**

Run: `dart analyze lib/`
Expected: No issues (no remaining references to recommended books)

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor: remove recommended books feature (no longer used)"
```

---

### Task 3: Move Daily Review Section to Learning Path

**Files:**
- Modify: `lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart`

- [ ] **Step 1: Add imports to vocabulary_hub_screen.dart**

Add these imports:

```dart
import '../../providers/daily_review_provider.dart';
```

- [ ] **Step 2: Add DailyReviewBanner to VocabularyHubScreen**

In `VocabularyHubScreen.build`, insert the banner between `TopNavbar` and the `Expanded` content. Change the body from:

```dart
child: Column(
  children: [
    const TopNavbar(),
    Expanded(
      child: pathsAsync.when(
```

to:

```dart
child: Column(
  children: [
    const TopNavbar(),
    const _DailyReviewBanner(),
    Expanded(
      child: pathsAsync.when(
```

- [ ] **Step 3: Add _DailyReviewBanner widget**

Add this widget at the bottom of `vocabulary_hub_screen.dart`:

```dart
class _DailyReviewBanner extends ConsumerWidget {
  const _DailyReviewBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySession = ref.watch(todayReviewSessionProvider).valueOrNull;
    final dueWords = ref.watch(dailyReviewWordsProvider).valueOrNull ?? [];

    // Already completed today
    if (todaySession != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryShadow,
                offset: const Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review Complete!',
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '+${todaySession.xpEarned} XP earned',
                      style: GoogleFonts.nunito(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Enough words to start a review
    if (dueWords.length >= minDailyReviewCount) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: GestureDetector(
          onTap: () => context.push(AppRoutes.vocabularyDailyReview),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.streakOrange,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: const Color(0xFFC76A00), offset: const Offset(0, 3)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Review',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${dueWords.length} words ready!',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: AppColors.streakOrange, size: 20),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Not enough words — hide
    return const SizedBox.shrink();
  }
}
```

- [ ] **Step 4: Verify**

Run: `dart analyze lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart`
Expected: No issues

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart
git commit -m "feat: move daily review banner to learning path screen"
```

---

### Task 4: Add getAllBadges to domain/data layer

**Files:**
- Modify: `lib/domain/repositories/badge_repository.dart`
- Create: `lib/domain/usecases/badge/get_all_badges_usecase.dart`
- Modify: `lib/data/repositories/supabase/supabase_badge_repository.dart`
- Modify: `lib/presentation/providers/usecase_providers.dart`
- Modify: `lib/presentation/providers/badge_provider.dart`

- [ ] **Step 1: Add getAllBadges to BadgeRepository interface**

In `lib/domain/repositories/badge_repository.dart`, add after the existing methods:

```dart
Future<Either<Failure, List<Badge>>> getAllBadges();
```

- [ ] **Step 2: Create GetAllBadgesUseCase**

Create `lib/domain/usecases/badge/get_all_badges_usecase.dart`:

```dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/badge.dart';
import '../../repositories/badge_repository.dart';
import '../usecase.dart';

class GetAllBadgesUseCase implements UseCase<List<Badge>, NoParams> {
  const GetAllBadgesUseCase(this._repository);
  final BadgeRepository _repository;

  @override
  Future<Either<Failure, List<Badge>>> call(NoParams params) {
    return _repository.getAllBadges();
  }
}
```

- [ ] **Step 3: Implement getAllBadges in SupabaseBadgeRepository**

In `lib/data/repositories/supabase/supabase_badge_repository.dart`, add this method:

```dart
@override
Future<Either<Failure, List<Badge>>> getAllBadges() async {
  try {
    final response = await _supabase
        .from(DbTables.badges)
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: true);

    final badges = (response as List)
        .map((json) => BadgeModel.fromJson(json).toEntity())
        .toList();

    return Right(badges);
  } on PostgrestException catch (e) {
    return Left(ServerFailure(e.message, code: e.code));
  } catch (e) {
    return Left(ServerFailure(e.toString()));
  }
}
```

- [ ] **Step 4: Register usecase provider**

In `lib/presentation/providers/usecase_providers.dart`, in the BADGE USE CASES section, add:

```dart
final getAllBadgesUseCaseProvider = Provider((ref) {
  return GetAllBadgesUseCase(ref.watch(badgeRepositoryProvider));
});
```

Add the import: `import '../../domain/usecases/badge/get_all_badges_usecase.dart';`

- [ ] **Step 5: Add allBadgesProvider**

In `lib/presentation/providers/badge_provider.dart`, add:

```dart
import '../../domain/usecases/usecase.dart';

/// Provides all active badges (for showing earned vs unearned)
final allBadgesProvider = FutureProvider<List<Badge>>((ref) async {
  final useCase = ref.watch(getAllBadgesUseCaseProvider);
  final result = await useCase(const NoParams());
  return result.fold(
    (failure) => [],
    (badges) => badges,
  );
});
```

Also add the import for `getAllBadgesUseCaseProvider` from `usecase_providers.dart`.

- [ ] **Step 6: Verify**

Run: `dart analyze lib/`
Expected: No issues

- [ ] **Step 7: Commit**

```bash
git add lib/domain/repositories/badge_repository.dart \
  lib/domain/usecases/badge/get_all_badges_usecase.dart \
  lib/data/repositories/supabase/supabase_badge_repository.dart \
  lib/presentation/providers/usecase_providers.dart \
  lib/presentation/providers/badge_provider.dart
git commit -m "feat: add getAllBadges query for badge gallery"
```

---

### Task 5: Create Quests Screen

**Files:**
- Create: `lib/presentation/screens/quests/quests_screen.dart`

- [ ] **Step 1: Create quests directory**

```bash
mkdir -p lib/presentation/screens/quests
```

- [ ] **Step 2: Create quests_screen.dart**

Create `lib/presentation/screens/quests/quests_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/badge.dart';
import '../../../domain/entities/daily_quest.dart';
import '../../providers/badge_provider.dart';
import '../../providers/daily_quest_provider.dart';
import '../../widgets/common/top_navbar.dart';
import '../../widgets/home/daily_quest_list.dart';
import '../../widgets/home/quest_completion_dialog.dart';

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 600;

    // Listen for quest completion popup
    final bonusClaimed =
        ref.watch(dailyBonusClaimedProvider).valueOrNull ?? false;
    ref.listen<AsyncValue<List<DailyQuestProgress>>>(
      dailyQuestProgressProvider,
      (prev, next) {
        final nextData = next.valueOrNull ?? [];
        final newlyCompleted =
            nextData.where((q) => q.newlyCompleted).toList();
        if (newlyCompleted.isNotEmpty) {
          final allComplete = nextData.every((q) => q.isCompleted);
          QuestCompletionDialog.show(
            context,
            completedQuests: newlyCompleted,
            allQuestsComplete: allComplete && !bonusClaimed,
          );
        }
      },
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const TopNavbar(),
            Expanded(
              child: isWide
                  ? _WideLayout()
                  : _MobileLayout(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mobile Layout ──────────────────────────────────

class _MobileLayout extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(dailyQuestProgressProvider);
    final bonusClaimed =
        ref.watch(dailyBonusClaimedProvider).valueOrNull ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Monthly Quest placeholder
          const _MonthlyQuestCard(),
          const SizedBox(height: 24),

          // Daily Quests
          _DailyQuestsHeader(),
          const SizedBox(height: 12),
          progressAsync.when(
            data: (progress) => DailyQuestList(
              progress: progress,
              bonusClaimed: bonusClaimed,
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),

          // Badges
          const _BadgesSection(),
          const SizedBox(height: 24),

          // Monthly Badges placeholder
          const _MonthlyBadgesCard(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── Wide Layout ────────────────────────────────────

class _WideLayout extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(dailyQuestProgressProvider);
    final bonusClaimed =
        ref.watch(dailyBonusClaimedProvider).valueOrNull ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main content
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _MonthlyQuestCard(),
                  const SizedBox(height: 24),
                  _DailyQuestsHeader(),
                  const SizedBox(height: 12),
                  progressAsync.when(
                    data: (progress) => DailyQuestList(
                      progress: progress,
                      bonusClaimed: bonusClaimed,
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 24),
                  const _BadgesSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
        // Sidebar
        SizedBox(
          width: 280,
          child: Padding(
            padding: const EdgeInsets.only(top: 24, right: 24),
            child: const _MonthlyBadgesCard(),
          ),
        ),
      ],
    );
  }
}

// ─── Daily Quests Header ────────────────────────────

class _DailyQuestsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Hours until midnight
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final hoursLeft = midnight.difference(now).inHours;

    return Row(
      children: [
        Text(
          'Daily Quests',
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
        const Spacer(),
        Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(
          '$hoursLeft HOURS',
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

// ─── Monthly Quest Placeholder ──────────────────────

class _MonthlyQuestCard extends StatelessWidget {
  const _MonthlyQuestCard();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthName = DateFormat.MMMM().format(now).toUpperCase();
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final daysLeft = lastDay.difference(now).inDays;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.streakOrange,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC76A00),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              monthName,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${DateFormat.MMMM().format(now)} Quest',
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 14, color: Colors.white.withValues(alpha: 0.8)),
              const SizedBox(width: 4),
              Text(
                '$daysLeft DAYS',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Progress card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete 20 quests',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: 0,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          color: Colors.white,
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '0 / 20',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Badges Section ─────────────────────────────────

class _BadgesSection extends ConsumerWidget {
  const _BadgesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBadgesAsync = ref.watch(allBadgesProvider);
    final earnedBadgesAsync = ref.watch(userBadgesProvider);

    final allBadges = allBadgesAsync.valueOrNull ?? [];
    final earnedBadges = earnedBadgesAsync.valueOrNull ?? [];
    final earnedBadgeIds = earnedBadges.map((ub) => ub.badge.id).toSet();

    if (allBadges.isEmpty && earnedBadges.isEmpty) {
      return const SizedBox.shrink();
    }

    final earned = allBadges.where((b) => earnedBadgeIds.contains(b.id)).toList();
    final unearned = allBadges.where((b) => !earnedBadgeIds.contains(b.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Text(
              'Badges',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${earnedBadges.length} / ${allBadges.length}',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Earned badges
        if (earned.isNotEmpty) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: earned.map((badge) {
              final userBadge = earnedBadges.firstWhere((ub) => ub.badge.id == badge.id);
              return _BadgeTile(badge: badge, earnedAt: userBadge.earnedAt);
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Unearned badges
        if (unearned.isNotEmpty)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: unearned
                .map((badge) => _BadgeTile(badge: badge, earnedAt: null))
                .toList(),
          ),
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.earnedAt});
  final Badge badge;
  final DateTime? earnedAt;

  bool get isEarned => earnedAt != null;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEarned ? 1.0 : 0.4,
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEarned ? AppColors.primary : AppColors.neutral,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isEarned ? AppColors.primaryShadow : AppColors.neutral,
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              badge.icon ?? '🏅',
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 6),
            Text(
              badge.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: isEarned ? AppColors.black : AppColors.neutralText,
              ),
            ),
            if (!isEarned && badge.description != null) ...[
              const SizedBox(height: 2),
              Text(
                badge.description!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 9,
                  color: AppColors.neutralText,
                ),
              ),
            ],
            if (isEarned) ...[
              const SizedBox(height: 2),
              Icon(Icons.check_circle, size: 14, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Monthly Badges Placeholder ─────────────────────

class _MonthlyBadgesCard extends StatelessWidget {
  const _MonthlyBadgesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral, width: 2),
        boxShadow: [
          BoxShadow(color: AppColors.neutral, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MONTHLY BADGES',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: AppColors.neutralText,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Earn your first badge!',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Complete each month's challenge to earn exclusive badges",
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: AppColors.neutralText,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.streakOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.military_tech_rounded,
                size: 48,
                color: AppColors.streakOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Verify**

Run: `dart analyze lib/presentation/screens/quests/quests_screen.dart`
Expected: No issues

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/screens/quests/quests_screen.dart
git commit -m "feat: create quests screen with daily quests, badges, and monthly placeholders"
```

---

### Task 6: Update Router — remove Home, add Quests, relocate routes

**Files:**
- Modify: `lib/app/router.dart`

- [ ] **Step 1: Update AppRoutes class**

In the `AppRoutes` class:
- Change `static const home = '/';` to `static const quests = '/quests';`
- Keep all other routes unchanged.

- [ ] **Step 2: Update initialLocation**

Change line 197 from:
```dart
initialLocation: kDevBypassAuth ? AppRoutes.home : AppRoutes.splash,
```
to:
```dart
initialLocation: kDevBypassAuth ? AppRoutes.vocabulary : AppRoutes.splash,
```

- [ ] **Step 3: Update navigator keys**

Replace the `_studentHomeKey` definition:
```dart
final _studentHomeKey = GlobalKey<NavigatorState>(debugLabel: 'studentHome');
```
with:
```dart
final _studentQuestsKey = GlobalKey<NavigatorState>(debugLabel: 'studentQuests');
```

- [ ] **Step 4: Replace Home branch with Quests branch**

Replace the entire Branch 1 (Home) block (lines 340-361):

```dart
// Branch 1: Home
StatefulShellBranch(
  navigatorKey: _studentHomeKey,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.profile,
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: AppRoutes.avatarCustomize,
      builder: (context, state) => const AvatarCustomizeScreen(),
    ),
    GoRoute(
      path: AppRoutes.wordBank,
      builder: (context, state) => const VocabularyScreen(),
    ),
  ],
),
```

with the new branch order (Library as Branch 1, Quests as Branch 2):

```dart
// Branch 1: Library
StatefulShellBranch(
  navigatorKey: _studentLibraryKey,
  routes: [
    GoRoute(
      path: AppRoutes.library,
      builder: (context, state) => const LibraryScreen(),
      routes: [
        GoRoute(
          path: 'book/:bookId',
          builder: (context, state) {
            final bookId = state.pathParameters['bookId']!;
            return BookDetailScreen(bookId: bookId);
          },
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.reader,
      builder: (context, state) {
        final bookId = state.pathParameters['bookId']!;
        final chapterId = state.pathParameters['chapterId']!;
        return ReaderScreen(bookId: bookId, chapterId: chapterId);
      },
    ),
    GoRoute(
      path: AppRoutes.activity,
      builder: (context, state) {
        final chapterId = state.pathParameters['chapterId']!;
        return ActivityScreen(chapterId: chapterId);
      },
    ),
    GoRoute(
      path: AppRoutes.bookQuiz,
      builder: (context, state) {
        final bookId = state.pathParameters['bookId']!;
        return BookQuizScreen(bookId: bookId);
      },
    ),
  ],
),
// Branch 2: Quests
StatefulShellBranch(
  navigatorKey: _studentQuestsKey,
  routes: [
    GoRoute(
      path: AppRoutes.quests,
      builder: (context, state) => const QuestsScreen(),
    ),
  ],
),
```

And remove the old Branch 2 (Library) which is now merged above. Update Branch 3 (Cards) and Branch 4 (Leaderboard) comments to be Branch 3 and Branch 4.

- [ ] **Step 5: Relocate profile, avatar, word-bank routes**

The profile, avatar-customize, and word-bank routes were nested under the Home branch. Move them into the vocab branch (Branch 0) so they stay within the shell. Add them as sibling routes inside the Branch 0 `StatefulShellBranch.routes` list:

```dart
// Inside Branch 0 routes list, after the vocabulary GoRoute:
GoRoute(
  path: AppRoutes.profile,
  builder: (context, state) => const ProfileScreen(),
),
GoRoute(
  path: AppRoutes.avatarCustomize,
  builder: (context, state) => const AvatarCustomizeScreen(),
),
GoRoute(
  path: AppRoutes.wordBank,
  builder: (context, state) => const VocabularyScreen(),
),
```

- [ ] **Step 6: Add QuestsScreen import, remove HomeScreen import**

Add:
```dart
import '../presentation/screens/quests/quests_screen.dart';
```

Remove the HomeScreen import:
```dart
import '../presentation/screens/home/home_screen.dart';
```

- [ ] **Step 7: Update any redirect that references AppRoutes.home**

Search for `AppRoutes.home` references in router.dart and update them. The redirect logic (line 201) uses `kDevBypassAuth` which already got updated in Step 2. Also check the auth redirect — if it sends unauthenticated users to home, update to vocabulary.

- [ ] **Step 8: Verify**

Run: `dart analyze lib/app/router.dart`
Expected: No issues

- [ ] **Step 9: Commit**

```bash
git add lib/app/router.dart
git commit -m "feat: replace home tab with quests tab, make vocab default"
```

---

### Task 7: Update MainShellScaffold tab definitions

**Files:**
- Modify: `lib/presentation/widgets/shell/main_shell_scaffold.dart`

- [ ] **Step 1: Update _destinations list**

Replace the `_destinations` list to match the new branch order:

```dart
static const _destinations = <_NavItem>[
  _NavItem(
    icon: Icons.route_outlined,
    selectedIcon: Icons.route_rounded,
    label: 'Learning Path',
    color: AppColors.wasp,
  ),
  _NavItem(
    icon: Icons.local_library_outlined,
    selectedIcon: Icons.local_library_rounded,
    label: 'Library',
    color: AppColors.secondary,
  ),
  _NavItem(
    icon: Icons.military_tech_outlined,
    selectedIcon: Icons.military_tech_rounded,
    label: 'Quests',
    color: AppColors.streakOrange,
  ),
  _NavItem(
    icon: Icons.collections_bookmark_outlined,
    selectedIcon: Icons.collections_bookmark_rounded,
    label: 'Card Collection',
    color: AppColors.cardEpic,
  ),
  _NavItem(
    icon: Icons.emoji_events_outlined,
    selectedIcon: Icons.emoji_events_rounded,
    label: 'Leaderboards',
    color: AppColors.streakOrange,
  ),
];
```

- [ ] **Step 2: Remove HomeScreen import if present**

Check if the file imports `home_screen.dart` and remove it if so.

- [ ] **Step 3: Verify**

Run: `dart analyze lib/presentation/widgets/shell/main_shell_scaffold.dart`
Expected: No issues

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/widgets/shell/main_shell_scaffold.dart
git commit -m "feat: update navigation tabs — replace Home with Quests"
```

---

### Task 8: Update profile "See All" to navigate to /quests

**Files:**
- Modify: `lib/presentation/screens/profile/profile_screen.dart`

- [ ] **Step 1: Change "See All" button behavior**

In `_RecentBadgesSection`, replace the "See All" `TextButton.onPressed` callback. Change from:

```dart
onPressed: () {
  _showAllBadgesSheet(context, allBadges);
},
```

to:

```dart
onPressed: () {
  context.go(AppRoutes.quests);
},
```

Add the `go_router` import if not already present, and add `AppRoutes` import.

- [ ] **Step 2: Remove _showAllBadgesSheet method**

Delete the `_showAllBadgesSheet` method (the bottom sheet builder) since it's no longer called. If it's a standalone method in the file, remove it entirely.

- [ ] **Step 3: Verify**

Run: `dart analyze lib/presentation/screens/profile/profile_screen.dart`
Expected: No issues

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/screens/profile/profile_screen.dart
git commit -m "feat: profile 'See All' badges navigates to quests page"
```

---

### Task 9: Update all AppRoutes.home references

**Files:**
- Search all files referencing `AppRoutes.home`

- [ ] **Step 1: Find all remaining references**

Run: `grep -r "AppRoutes.home" lib/`

Update each reference:
- Navigation to home (e.g. `context.go(AppRoutes.home)`) → `context.go(AppRoutes.vocabulary)`
- Any redirect logic → update to vocabulary

- [ ] **Step 2: Verify**

Run: `dart analyze lib/`
Expected: No issues. Zero references to `AppRoutes.home`.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "refactor: update all AppRoutes.home references to vocabulary"
```

---

### Task 10: Delete Home screen files

**Files:**
- Delete: `lib/presentation/screens/home/home_screen.dart`
- Delete: `lib/presentation/screens/home/` (directory, if empty)

Note: `daily_quest_widget.dart` and `daily_quest_list.dart` stay in `lib/presentation/widgets/home/` since they're still used by the Quests screen. Only the home screen file itself is deleted.

- [ ] **Step 1: Delete home screen**

```bash
rm lib/presentation/screens/home/home_screen.dart
rmdir lib/presentation/screens/home/ 2>/dev/null || true
```

- [ ] **Step 2: Remove stale imports**

Search for any remaining imports of `home_screen.dart` and remove them.

- [ ] **Step 3: Final verification**

Run: `dart analyze lib/`
Expected: No issues

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: delete home screen (all sections redistributed)"
```

---

### Task 11: Full verify and smoke test

- [ ] **Step 1: Run full analysis**

Run: `dart analyze lib/`
Expected: No issues

- [ ] **Step 2: Test build**

Run: `flutter build web --release` (or `flutter run -d chrome` for interactive test)
Expected: Builds without errors

- [ ] **Step 3: Manual smoke test checklist**

Verify these flows work:
1. App opens to Learning Path tab (default)
2. Daily review banner shows on Learning Path if words are due
3. Library tab shows "Continue Reading" section at top
4. Quests tab shows monthly quest placeholder, daily quests, badges grid, monthly badges placeholder
5. Badge grid shows earned (colored) and unearned (grey) badges
6. Profile "See All" badges navigates to Quests tab
7. All 5 tabs work in bottom nav (mobile) and sidebar (wide)
8. No references to home screen or recommended books remain

- [ ] **Step 4: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix: address smoke test findings"
```
