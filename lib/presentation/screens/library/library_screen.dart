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

  Widget _buildNavbar(BuildContext context, WidgetRef ref, dynamic user) {
    final streak = user?.currentStreak ?? 0;
    final xp = user?.xp ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.primary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: UK Flag
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 16, color: const Color(0xFF012169)),
                Container(width: 8, height: 16, color: Colors.white),
                Container(width: 8, height: 16, color: const Color(0xFFC8102E)),
              ],
            ),
          ),

          _buildNavDivider(),

          // Streak
          _buildNavStat(
            icon: Icons.local_fire_department,
            value: streak,
            iconColor: AppColors.streakOrange,
          ),

          _buildNavDivider(),

          // XP
          _buildNavStat(
            icon: Icons.monetization_on,
            value: xp,
            iconColor: AppColors.wasp,
          ),

          _buildNavDivider(),

          // Right: Profile Button
          GestureDetector(
            onTap: () => context.push(AppRoutes.profile),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      user?.initials ?? '?',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.neutral.withValues(alpha: 0),
                    AppColors.neutral,
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title.toUpperCase(),
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.neutralText,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.neutral,
                    AppColors.neutral.withValues(alpha: 0),
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(WidgetRef ref, String? selectedLevel, bool isSearchActive, LibraryViewMode viewMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Level chips (scrollable)
          Expanded(
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildLevelChip('All', selectedLevel == null, () {
                    ref.read(selectedLevelProvider.notifier).state = null;
                  }),
                  ...cefrLevels.map((level) => _buildLevelChip(
                    level,
                    selectedLevel == level,
                    () {
                      ref.read(selectedLevelProvider.notifier).state =
                          selectedLevel == level ? null : level;
                    },
                  )),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Search button
          GestureDetector(
            onTap: () {
              ref.read(isSearchActiveProvider.notifier).state = !isSearchActive;
              if (!isSearchActive) {
                ref.read(librarySearchQueryProvider.notifier).state = '';
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSearchActive ? AppColors.secondary : AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.neutral, width: 2),
              ),
              child: Icon(
                isSearchActive ? Icons.close_rounded : Icons.search_rounded,
                color: isSearchActive ? Colors.white : AppColors.neutralText,
                size: 18,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // View mode button
          GestureDetector(
            onTap: () {
              ref.read(libraryViewModeProvider.notifier).state =
                  viewMode == LibraryViewMode.grid
                      ? LibraryViewMode.list
                      : LibraryViewMode.grid;
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.neutral, width: 2),
              ),
              child: Icon(
                viewMode == LibraryViewMode.grid ? Icons.view_list_rounded : Icons.grid_view_rounded,
                color: AppColors.neutralText,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.secondary : AppColors.neutral,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            color: isSelected ? Colors.white : AppColors.neutralText,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildNavDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        height: 24,
        width: 2,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _buildNavStat({
    required IconData icon,
    required int value,
    required Color iconColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.3), size: 28),
            Icon(icon, color: iconColor, size: 24),
          ],
        ),
        const SizedBox(width: 4),
        Text(
          value.toString(),
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

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
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // --- Duolingo-style Navbar ---
            _buildNavbar(context, ref, user),

            const SizedBox(height: 16),

            // --- Locked Banner ---
            _LockedLibraryBanner(ref: ref),

            // --- Filter Section Header + Level Chips + Search/View ---
            _buildSectionHeader('Filter by Level'),
            const SizedBox(height: 8),
            _buildFilterRow(ref, selectedLevel, isSearchActive, viewMode),

            // --- Search Bar (when active) ---
            if (isSearchActive)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _SearchField(ref: ref),
              ),

            const SizedBox(height: 16),

            // --- Library Section Header ---
            _buildSectionHeader('Library'),
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

class _BookGrid extends ConsumerWidget {
  final List<Book> books;
  final ValueChanged<String> onBookTap;
  final ValueChanged<String> onLockedBookTap;

  const _BookGrid({required this.books, required this.onBookTap, required this.onLockedBookTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
     final completedIds = ref.watch(completedBookIdsProvider).valueOrNull ?? {};

     return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
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
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Text(
                             book.title,
                             maxLines: 2,
                             overflow: TextOverflow.ellipsis,
                             style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 11, height: 1.2),
                           ),
                           Text(
                             book.level,
                             style: GoogleFonts.nunito(color: AppColors.secondary, fontWeight: FontWeight.w800, fontSize: 10),
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
