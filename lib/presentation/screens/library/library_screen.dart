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
import '../../providers/library_provider.dart';
import '../../widgets/book/book_grid_card.dart';
import '../../widgets/book/book_list_tile.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  void _showLockedBookDialog(BuildContext context, String bookTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.lock_rounded, size: 48, color: AppColors.neutralText),
        title: Text(
          'Book Locked',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w900, color: AppColors.black),
        ),
        content: Text(
          'You have an active assignment. Complete your assigned reading first to unlock "$bookTitle" and other books.',
          style: GoogleFonts.nunito(fontSize: 16),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(libraryViewModeProvider);
    final selectedLevel = ref.watch(selectedLevelProvider);
    final isSearchActive = ref.watch(isSearchActiveProvider);
    final booksAsync = ref.watch(filteredBooksProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // --- Custom Header ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: AppColors.background,
              child: Row(
                children: [
                  if (isSearchActive)
                    Expanded(child: _SearchField(ref: ref))
                  else
                    Expanded(
                      child: Text(
                        'LIBRARY',
                        style: GoogleFonts.nunito(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.secondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  // Search Toggle
                  IconButton(
                    icon: Icon(
                      isSearchActive ? Icons.close_rounded : Icons.search_rounded,
                      color: AppColors.secondary,
                      size: 28,
                    ),
                    onPressed: () {
                      ref.read(isSearchActiveProvider.notifier).state = !isSearchActive;
                      if (!isSearchActive) {
                        ref.read(librarySearchQueryProvider.notifier).state = '';
                      }
                    },
                  ),
                  // View Mode Toggle
                  IconButton(
                    icon: Icon(
                      viewMode == LibraryViewMode.grid ? Icons.view_list_rounded : Icons.grid_view_rounded,
                       color: AppColors.secondary,
                       size: 28,
                    ),
                    onPressed: () {
                      ref.read(libraryViewModeProvider.notifier).state =
                          viewMode == LibraryViewMode.grid
                              ? LibraryViewMode.list
                              : LibraryViewMode.grid;
                    },
                  ),
                ],
              ),
            ),
            
            // --- Locked Banner ---
            _LockedLibraryBanner(ref: ref),

            // --- Filters ---
             if (!isSearchActive)
              _LevelFilterChips(
                selectedLevel: selectedLevel,
                onLevelSelected: (level) {
                  ref.read(selectedLevelProvider.notifier).state = level;
                },
              ),
            
            const SizedBox(height: 8),

            // --- Content ---
            Expanded(
              child: booksAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
                data: (books) {
                   if (books.isEmpty) {
                      return _EmptyState(isSearchActive: isSearchActive, selectedLevel: selectedLevel);
                   }
                   
                   // Grid/List View
                   if (viewMode == LibraryViewMode.grid) {
                     return _BookGrid(
                       books: books,
                       onBookTap: (bookId) => context.go('${AppRoutes.library}/book/$bookId'),
                       onLockedBookTap: (title) => _showLockedBookDialog(context, title),
                     );
                   } else {
                     return _BookList(
                       books: books,
                       onBookTap: (bookId) => context.go('${AppRoutes.library}/book/$bookId'),
                       onLockedBookTap: (title) => _showLockedBookDialog(context, title),
                     );
                   }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final WidgetRef ref;
  const _SearchField({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral, width: 2),
      ),
      child: TextField(
        autofocus: true,
        style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: 'Search books...',
          hintStyle: GoogleFonts.nunito(color: AppColors.neutralText),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (val) => ref.read(librarySearchQueryProvider.notifier).state = val,
      ),
    );
  }
}

class _LockedLibraryBanner extends ConsumerWidget {
  final WidgetRef ref;
  const _LockedLibraryBanner({required this.ref});

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

class _LevelFilterChips extends StatelessWidget {
  final String? selectedLevel;
  final ValueChanged<String?> onLevelSelected;

  const _LevelFilterChips({required this.selectedLevel, required this.onLevelSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _FilterButton(
            label: 'All', 
            isSelected: selectedLevel == null, 
            onTap: () => onLevelSelected(null),
          ),
          ...cefrLevels.map((level) => _FilterButton(
            label: level, 
            isSelected: selectedLevel == level, 
            onTap: () => onLevelSelected(selectedLevel == level ? null : level),
          )).toList(),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterButton({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.secondary : AppColors.neutral, 
            width: 2,
          ),
          boxShadow: isSelected ? [] : [
            BoxShadow(color: AppColors.neutral, offset: Offset(0, 2))
          ]
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.nunito(
              color: isSelected ? Colors.white : AppColors.neutralText,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _BookGrid extends ConsumerWidget {
  final List<Book> books;
  final ValueChanged<String> onBookTap;
  final ValueChanged<String> onLockedBookTap;

  const _BookGrid({required this.books, required this.onBookTap, required this.onLockedBookTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
     final completedIds = ref.watch(completedBookIdsProvider).valueOrNull ?? {};

     return GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: books.length,
        itemBuilder: (context, index) {
           final book = books[index];
           final canAccess = ref.watch(canAccessBookProvider(book.id));
           final isCompleted = completedIds.contains(book.id);

           return GestureDetector(
             onTap: () => canAccess ? onBookTap(book.id) : onLockedBookTap(book.title),
             child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.neutral, width: 2),
                  boxShadow: [
                     BoxShadow(color: AppColors.neutral, offset: Offset(0, 4))
                  ]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                       child: Stack(
                         fit: StackFit.expand,
                         children: [
                           ClipRRect(
                             borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                             child: Image.network(
                               book.coverUrl ?? '', 
                               fit: BoxFit.cover,
                               errorBuilder: (_,__,___) => Container(color: AppColors.primary.withValues(alpha: 0.1), child: Icon(Icons.book, size: 40, color: AppColors.primary)),
                             ),
                           ),
                           if (!canAccess)
                             Container(
                               color: Colors.black.withValues(alpha: 0.5),
                               child: const Center(child: Icon(Icons.lock_rounded, color: Colors.white, size: 40)),
                             ),
                           if (isCompleted)
                              Positioned(
                                top: 8, right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                                ),
                              ),
                         ],
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
                             style: GoogleFonts.nunito(color: AppColors.secondary, fontWeight: FontWeight.w800, fontSize: 12),
                           ),
                        ],
                      ),
                    )
                  ],
                ),
             ),
           );
        },
     );
  }
}

class _BookList extends ConsumerWidget {
  final List<Book> books;
  final ValueChanged<String> onBookTap;
  final ValueChanged<String> onLockedBookTap;

  const _BookList({required this.books, required this.onBookTap, required this.onLockedBookTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reusing the grid card style but in a list view for now, or just a simpler list item
    // For consistency with the "Gamified" look, list items should also be chunky cards
    final completedIds = ref.watch(completedBookIdsProvider).valueOrNull ?? {};

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: books.length,
      separatorBuilder: (_,__) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
         final book = books[index];
         final canAccess = ref.watch(canAccessBookProvider(book.id));
         
         return GestureDetector(
           onTap: () => canAccess ? onBookTap(book.id) : onLockedBookTap(book.title),
           child: Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.neutral, width: 2),
                boxShadow: [BoxShadow(color: AppColors.neutral, offset: Offset(0, 3))],
             ),
             child: Row(
               children: [
                 ClipRRect(
                   borderRadius: BorderRadius.circular(12),
                   child: Image.network(book.coverUrl ?? '', width: 60, height: 80, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(width: 60, height: 80, color: AppColors.neutral)),
                 ),
                 const SizedBox(width: 16),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        Text(book.title, style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(book.level, style: GoogleFonts.nunito(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                     ],
                   ),
                 ),
                 if (!canAccess) Icon(Icons.lock_rounded, color: AppColors.neutralText),
               ],
             ),
           ),
         );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isSearchActive;
  final String? selectedLevel;

  const _EmptyState({required this.isSearchActive, required this.selectedLevel});

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
