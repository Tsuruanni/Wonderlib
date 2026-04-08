import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../data/datasources/mock_books_data.dart';
import '../../../domain/entities/book.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_access_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/book_quiz_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/system_settings_provider.dart';
import '../../widgets/common/cached_book_image.dart';
import '../../widgets/common/error_state_widget.dart';
import '../../widgets/common/pressable_scale.dart';
import '../../widgets/common/responsive_layout.dart';
import '../../widgets/common/top_navbar.dart';

// --- Providers ---

final selectedCategoryProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Tracks which levels are expanded in the library grid (web only).
final expandedLevelsProvider = StateProvider<Set<String>>((ref) => {});

/// Returns books filtered by Search and Category (Genre).
/// Grouping by Level happens in the UI.
final libraryFilteredBooksProvider = Provider<AsyncValue<List<Book>>>((ref) {
  final booksAsync = ref.watch(booksProvider(null));
  final searchQuery = ref.watch(librarySearchQueryProvider).toLowerCase();
  final selectedCategory = ref.watch(selectedCategoryProvider);

  return booksAsync.whenData((books) {
    return books.where((book) {
      // 1. Search Filter
      final matchesSearch = book.title.toLowerCase().contains(searchQuery);
      
      // 2. Category Filter
      final matchesCategory = selectedCategory == null || book.genre == selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
  });
});

/// Books grouped by level (A1, A2, B1...), sorted by level key.
/// When mock mode is enabled, appends mock books to the end of each level.
final booksByLevelProvider = Provider<Map<String, List<Book>>>((ref) {
  final books = ref.watch(libraryFilteredBooksProvider).valueOrNull ?? [];
  final mockEnabled = ref.watch(mockLibraryEnabledProvider);
  final searchQuery = ref.watch(librarySearchQueryProvider).toLowerCase();
  final selectedCategory = ref.watch(selectedCategoryProvider);

  final map = <String, List<Book>>{};

  // Add real books
  for (var book in books) {
    map.putIfAbsent(book.level.toUpperCase(), () => []).add(book);
  }

  // Append filtered mock books at the end of each level
  if (mockEnabled) {
    for (var mock in kMockBooks) {
      final matchesSearch = searchQuery.isEmpty ||
          mock.title.toLowerCase().contains(searchQuery);
      final matchesCategory =
          selectedCategory == null || mock.genre == selectedCategory;
      if (matchesSearch && matchesCategory) {
        map.putIfAbsent(mock.level.toUpperCase(), () => []).add(mock);
      }
    }
  }

  return Map.fromEntries(
    map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
});

/// Extracts unique categories from all books (and mock books when enabled) for the filter chips.
final availableCategoriesProvider = Provider<AsyncValue<List<String>>>((ref) {
  final booksAsync = ref.watch(booksProvider(null));
  final mockEnabled = ref.watch(mockLibraryEnabledProvider);
  return booksAsync.whenData((books) {
    final genres = books
        .map((b) => b.genre)
        .where((g) => g != null && g.isNotEmpty)
        .map((g) => g!)
        .toSet();

    // Include mock book genres when mock mode is enabled
    if (mockEnabled) {
      for (var mock in kMockBooks) {
        if (mock.genre != null && mock.genre!.isNotEmpty) {
          genres.add(mock.genre!);
        }
      }
    }

    return genres.toList()..sort();
  });
});

/// Whether mock library mode is enabled (from system settings).
final mockLibraryEnabledProvider = Provider<bool>((ref) {
  return ref.watch(systemSettingsProvider).valueOrNull?.mockLibraryEnabled ?? false;
});

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  // --- Helper to build Category Chips with Search Button ---
  Widget _buildTopBar(WidgetRef ref, String? selectedCategory, List<String> categories, bool isSearchActive) {
    if (isSearchActive) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.secondary, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withOpacity(0.2),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
             const SizedBox(width: 14),
             Icon(Icons.search_rounded, color: AppColors.secondary, size: 28),
             const SizedBox(width: 12),
             Expanded(
               child: TextField(
                 autofocus: true,
                 style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 18),
                 decoration: InputDecoration(
                   hintText: 'Search books...',
                   hintStyle: GoogleFonts.nunito(color: AppColors.neutralText),
                   border: InputBorder.none,
                   enabledBorder: InputBorder.none,
                   focusedBorder: InputBorder.none,
                   contentPadding: const EdgeInsets.symmetric(vertical: 14),
                 ),
                 onChanged: (val) => ref.read(librarySearchQueryProvider.notifier).state = val,
               ),
             ),
             IconButton(
               icon: Icon(Icons.close_rounded, color: AppColors.neutralText),
               onPressed: () {
                  ref.read(isSearchActiveProvider.notifier).state = false;
                  ref.read(librarySearchQueryProvider.notifier).state = '';
               },
             )
          ],
        ),
      );
    }

    final isWide = MediaQuery.sizeOf(ref.context).width >= 600;

    final chipItems = <Widget>[
      // Search Button as first item
      GestureDetector(
         onTap: () => ref.read(isSearchActiveProvider.notifier).state = true,
         child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.neutral, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neutral.withOpacity(0.5),
                  offset: const Offset(0, 2),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Icon(Icons.search_rounded, color: AppColors.neutralText, size: 20),
         ),
      ),
      _buildChip(
        label: 'All',
        isSelected: selectedCategory == null,
        onTap: () => ref.read(selectedCategoryProvider.notifier).state = null,
      ),
      ...categories.map((category) => _buildChip(
            label: category,
            isSelected: selectedCategory == category,
            onTap: () {
              ref.read(selectedCategoryProvider.notifier).state =
                  selectedCategory == category ? null : category;
            },
          )),
    ];

    if (isWide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chipItems,
        ),
      );
    }

    return Container(
      height: 48,
      margin: const EdgeInsets.fromLTRB(0, 24, 0, 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: chipItems.map((chip) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: chip,
        )).toList(),
      ),
    );
  }

  Widget _buildChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.secondary : AppColors.neutral,
            width: 2,
          ),
          boxShadow: [
            if (!isSelected)
            BoxShadow(
              color: AppColors.neutral.withOpacity(0.5),
              offset: const Offset(0, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            color: isSelected ? Colors.white : AppColors.neutralText,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSearchActive = ref.watch(isSearchActiveProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final booksAsync = ref.watch(libraryFilteredBooksProvider);
    final categoriesAsync = ref.watch(availableCategoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false, // Let scroll view handle bottom padding
        child: Column(
          children: [
            const TopNavbar(),
            
            // --- Locked Banner ---
            const _LockedLibraryBanner(),

            // --- Search & Categories Row ---
            categoriesAsync.when(
              data: (categories) => _buildTopBar(ref, selectedCategory, categories, isSearchActive),
              loading: () => const SizedBox(height: 80),
              error: (_, __) => SizedBox(
                height: 80,
                child: Center(
                  child: TextButton.icon(
                    onPressed: () => ref.invalidate(booksProvider),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                  ),
                ),
              ),
            ),

            // --- Content (Shelves) ---
            Expanded(
              child: booksAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ErrorStateWidget(
                  message: 'Failed to load books',
                  onRetry: () => ref.invalidate(booksProvider),
                ),
                data: (books) {
                  final booksByLevel = ref.watch(booksByLevelProvider);

                  if (booksByLevel.isEmpty) {
                    return _EmptyState(isSearchActive: isSearchActive);
                  }

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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _LibraryShelf extends ConsumerWidget {
  final String level;
  final List<Book> books;

  const _LibraryShelf({required this.level, required this.books});

  static const _bookWidth = 140.0;
  static const _bookHeight = 240.0;
  static const _spacing = 16.0;

  Color _getLevelColor(String level) {
    switch (level.toUpperCase()) {
      case 'A1': return AppColors.primary;
      case 'A2': return AppColors.secondary;
      case 'B1': return AppColors.wasp;
      case 'B2': return AppColors.streakOrange;
      case 'C1': return AppColors.cardEpic;
      case 'C2': return AppColors.danger;
      default: return AppColors.neutralText;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _getLevelColor(level);
    final completedIds = ref.watch(completedBookIdsProvider).valueOrNull ?? {};
    final realBooks = books.where((b) => !b.isMock).toList();
    final completedCount = realBooks.where((b) => completedIds.contains(b.id)).length;
    final progress = realBooks.isEmpty ? 0.0 : completedCount / realBooks.length;

    final sortedBooks = [...books]
      ..sort((a, b) {
        final aCompleted = completedIds.contains(a.id) ? 1 : 0;
        final bCompleted = completedIds.contains(b.id) ? 1 : 0;
        return aCompleted.compareTo(bCompleted);
      });

    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final expandedLevels = ref.watch(expandedLevelsProvider);
    final isExpanded = expandedLevels.contains(level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            children: [
              Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(
                   color: color.withOpacity(0.1),
                   shape: BoxShape.circle,
                 ),
                 child: Icon(Icons.auto_stories_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Level $level",
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.neutral.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$completedCount / ${realBooks.length}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutralText,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Progress Bar Line
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.neutral.withOpacity(0.3),
              color: color,
              minHeight: 4,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Books: horizontal scroll on mobile, collapsible grid on wide
        if (isWide)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemsPerRow = ((constraints.maxWidth + _spacing) / (_bookWidth + _spacing)).floor().clamp(1, 20);
                final maxVisible = itemsPerRow * 2;
                final hasMore = sortedBooks.length > maxVisible && !isExpanded;
                final visibleCount = hasMore ? maxVisible - 1 : sortedBooks.length;

                return Wrap(
                  spacing: _spacing,
                  runSpacing: _spacing,
                  children: [
                    for (int i = 0; i < visibleCount; i++)
                      SizedBox(
                        width: _bookWidth,
                        height: _bookHeight,
                        child: _BookShelfItem(book: sortedBooks[i]),
                      ),
                    if (hasMore)
                      _LoadMoreButton(
                        remaining: sortedBooks.length - visibleCount,
                        color: color,
                        onTap: () {
                          ref.read(expandedLevelsProvider.notifier).state = {
                            ...expandedLevels,
                            level,
                          };
                        },
                      ),
                  ],
                );
              },
            ),
          )
        else
          SizedBox(
            height: _bookHeight,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: sortedBooks.length,
              separatorBuilder: (_, __) => const SizedBox(width: _spacing),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: _bookWidth,
                  child: _BookShelfItem(book: sortedBooks[index]),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({
    required this.remaining,
    required this.color,
    required this.onTap,
  });

  final int remaining;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 140,
        height: 240,
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.expand_more_rounded,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '+$remaining more',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookShelfItem extends ConsumerWidget {
  final Book book;

  const _BookShelfItem({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mock books get a completely different card
    if (book.isMock) {
      return _MockBookCard(book: book);
    }

    final mockEnabled = ref.watch(mockLibraryEnabledProvider);
    final canAccess = ref.watch(canAccessBookProvider(book.id));
    final isCompleted = ref.watch(completedBookIdsProvider).valueOrNull?.contains(book.id) ?? false;
    final isQuizReady = ref.watch(isQuizReadyProvider(book.id)).valueOrNull ?? false;
    final progress = ref.watch(readingProgressProvider(book.id)).valueOrNull;
    final percentage = progress?.completionPercentage ?? 0;

    return PressableScale(
      onTap: () {
        if (canAccess) {
          context.go(AppRoutes.bookDetailPath(book.id));
        } else {
           showDialog(
             context: context,
             builder: (_) => AlertDialog(
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
               title: Text("Locked", style: GoogleFonts.fredoka(fontSize: 24, color: AppColors.danger)),
               content: Text(
                 "Complete your assignment to read this book.",
                 style: GoogleFonts.nunito(fontSize: 16),
               ),
               actions: [
                 TextButton(
                   onPressed: () => Navigator.pop(context),
                   child: Text("OK", style: GoogleFonts.fredoka(fontSize: 18, color: AppColors.primary))
                 )
               ],
             ),
           );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10), // For shadow
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.neutral, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.neutral.withOpacity(0.6),
              offset: const Offset(0, 4),
              blurRadius: 0,
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: CachedBookImage(
                      imageUrl: book.coverUrl,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        color: AppColors.neutral.withOpacity(0.2),
                        child: Center(child: Icon(Icons.menu_book_rounded, size: 40, color: AppColors.neutralText)),
                      ),
                    ),
                  ),
                  if (!canAccess)
                    Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(child: Icon(Icons.lock_rounded, color: Colors.white, size: 36)),
                    ),
                  if (isCompleted)
                     Positioned(
                        top: 8, right: 8,
                        child: Container(
                           padding: const EdgeInsets.all(6),
                           decoration: BoxDecoration(
                             color: AppColors.success,
                             shape: BoxShape.circle,
                             border: Border.all(color: Colors.white, width: 2),
                           ),
                           child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                        ),
                     ),
                  if (!isCompleted && isQuizReady)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: _QuizBadge(),
                    ),
                  // Demo badge (only when mock mode is on and book has no other badge)
                  if (mockEnabled && !isCompleted && !isQuizReady)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: _DemoBadge(),
                    ),
                ],
              ),
            ),
            // Reading progress bar
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      book.genre?.toUpperCase() ?? 'GENERAL',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 9,
                        color: AppColors.neutralText,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
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


class _MockBookCard extends StatelessWidget {
  final Book book;

  const _MockBookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.neutral.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral.withValues(alpha: 0.4),
            offset: const Offset(0, 4),
            blurRadius: 0,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                color: AppColors.neutral.withValues(alpha: 0.12),
                child: Center(
                  child: Icon(
                    Icons.lock_rounded,
                    size: 32,
                    color: AppColors.neutralText.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    book.genre?.toUpperCase() ?? 'GENERAL',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 9,
                      color: AppColors.neutralText,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isSearchActive;

  const _EmptyState({required this.isSearchActive});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
           Icon(Icons.menu_book_rounded, size: 60, color: AppColors.neutral),
           const SizedBox(height: 16),
           Text(
             'No books found',
             style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.neutralText),
           ),
        ],
      ),
    );
  }
}

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
                height: 250,
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

class _ContinueReadingCard extends ConsumerWidget {
  const _ContinueReadingCard({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mockEnabled = ref.watch(mockLibraryEnabledProvider);
    final isCompleted = ref.watch(completedBookIdsProvider).valueOrNull?.contains(book.id) ?? false;
    final isQuizReady =
        ref.watch(isQuizReadyProvider(book.id)).valueOrNull ?? false;
    final progress =
        ref.watch(readingProgressProvider(book.id)).valueOrNull;
    final percentage = progress?.completionPercentage ?? 0;

    return PressableScale(
      onTap: () => context.go(AppRoutes.bookDetailPath(book.id)),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.neutral, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.neutral.withOpacity(0.6),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: CachedBookImage(
                      imageUrl: book.coverUrl,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        color: AppColors.neutral.withOpacity(0.2),
                        child: Center(child: Icon(Icons.menu_book_rounded, size: 40, color: AppColors.neutralText)),
                      ),
                    ),
                  ),
                  if (isCompleted)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  if (!isCompleted && isQuizReady)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: _QuizBadge(),
                    ),
                  if (mockEnabled && !isCompleted && !isQuizReady)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: _DemoBadge(),
                    ),
                ],
              ),
            ),
            // Always show progress bar for continue reading
            ClipRRect(
              child: LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: AppColors.neutral.withValues(alpha: 0.3),
                color: AppColors.secondary,
                minHeight: 4,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      book.genre?.toUpperCase() ?? 'GENERAL',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 9,
                        color: AppColors.neutralText,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
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

// ─── Shared Badges ───

class _QuizBadge extends StatelessWidget {
  const _QuizBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/icons/quiz.png', width: 12, height: 12, filterQuality: FilterQuality.high),
          const SizedBox(width: 4),
          Text(
            'Take the Quiz!',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoBadge extends StatelessWidget {
  const _DemoBadge();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: AppColors.wasp,
        borderRadius: 10,
        dashWidth: 4,
        dashGap: 3,
        strokeWidth: 2,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.wasp.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'DEMO',
          style: GoogleFonts.nunito(
            color: AppColors.wasp,
            fontWeight: FontWeight.w900,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
    required this.dashWidth,
    required this.dashGap,
    required this.strokeWidth,
  });

  final Color color;
  final double borderRadius;
  final double dashWidth;
  final double dashGap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().first;
    final totalLength = metrics.length;

    double distance = 0;
    while (distance < totalLength) {
      final end = (distance + dashWidth).clamp(0.0, totalLength);
      final segment = metrics.extractPath(distance, end);
      canvas.drawPath(segment, paint);
      distance += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LockedLibraryBanner extends ConsumerWidget {
  const _LockedLibraryBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTeacher = ref.watch(isTeacherProvider);
    if (isTeacher) return const SizedBox.shrink();

    final lockInfo = ref.watch(bookLockProvider);

    return lockInfo.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (info) {
        if (!info.hasLock) return const SizedBox.shrink();
        
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.danger, width: 2),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_rounded, color: AppColors.danger),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Complete your assignment to unlock the full library!',
                  style: GoogleFonts.nunito(
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn().shake();
      },
    );
  }
}


