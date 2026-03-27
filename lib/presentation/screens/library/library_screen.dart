import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/book.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_access_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/book_quiz_provider.dart';
import '../../providers/library_provider.dart';
import '../../widgets/common/cached_book_image.dart';
import '../../widgets/common/error_state_widget.dart';
import '../../widgets/common/pressable_scale.dart';
import '../../widgets/common/top_navbar.dart';

// --- Providers ---

final selectedCategoryProvider = StateProvider.autoDispose<String?>((ref) => null);

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
/// Extracted from build() to avoid recomputing on every rebuild.
final booksByLevelProvider = Provider<Map<String, List<Book>>>((ref) {
  final books = ref.watch(libraryFilteredBooksProvider).valueOrNull ?? [];
  final map = <String, List<Book>>{};
  for (var book in books) {
    map.putIfAbsent(book.level.toUpperCase(), () => []).add(book);
  }
  return Map.fromEntries(
    map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
});

/// Extracts unique categories from all books for the filter chips.
final availableCategoriesProvider = Provider<AsyncValue<List<String>>>((ref) {
  final booksAsync = ref.watch(booksProvider(null));
  return booksAsync.whenData((books) {
    return books
        .map((b) => b.genre)
        .where((g) => g != null && g.isNotEmpty)
        .map((g) => g!)
        .toSet()
        .toList()
      ..sort();
  });
});

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  // --- Helper to build Category Chips with Search Button ---
  Widget _buildTopBar(WidgetRef ref, String? selectedCategory, List<String> categories, bool isSearchActive) {
    if (isSearchActive) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 24, 20, 12), // Increased top margin
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

    return Container(
      height: 48, // Slightly taller
      margin: const EdgeInsets.fromLTRB(0, 24, 0, 12), // Increased top margin
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          // Search Button as first item
          GestureDetector(
             onTap: () => ref.read(isSearchActiveProvider.notifier).state = true,
             child: Container(
                margin: const EdgeInsets.only(right: 12),
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
        ],
      ),
    );
  }

  Widget _buildChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
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
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.nunito(
              color: isSelected ? Colors.white : AppColors.neutralText,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
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
                  if (books.isEmpty) {
                    return _EmptyState(isSearchActive: isSearchActive);
                  }

                  final booksByLevel = ref.watch(booksByLevelProvider);

                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
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

  Color _getLevelColor(String level) {
    switch (level.toUpperCase()) {
      case 'A1': return AppColors.primary;       // Green
      case 'A2': return AppColors.secondary;     // Blue
      case 'B1': return AppColors.wasp;          // Yellow
      case 'B2': return AppColors.streakOrange;  // Orange
      case 'C1': return AppColors.cardEpic;      // Purple
      case 'C2': return AppColors.danger;        // Red
      default: return AppColors.neutralText;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _getLevelColor(level);
    final completedIds = ref.watch(completedBookIdsProvider).valueOrNull ?? {};
    final completedCount = books.where((b) => completedIds.contains(b.id)).length;
    final progress = books.isEmpty ? 0.0 : completedCount / books.length;

    // Sort: completed books go to the end
    final sortedBooks = [...books]
      ..sort((a, b) {
        final aCompleted = completedIds.contains(a.id) ? 1 : 0;
        final bCompleted = completedIds.contains(b.id) ? 1 : 0;
        return aCompleted.compareTo(bCompleted);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8), // Adjusted vertical padding
          child: Row(
            children: [
              // Icon - using a generic book icon or could use level letter icon
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
                  '$completedCount / ${books.length}',
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
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
        
        const SizedBox(height: 16), // Space between line and books

        SizedBox(
          height: 240, // Height for book cards
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: sortedBooks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              return _BookShelfItem(book: sortedBooks[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _BookShelfItem extends ConsumerWidget {
  final Book book;

  const _BookShelfItem({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        width: 140,
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
                    style: GoogleFonts.nunito( // Reverted to Nunito
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
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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


