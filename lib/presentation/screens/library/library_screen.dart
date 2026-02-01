import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/book_access_provider.dart';
import '../../providers/library_provider.dart';
import '../../widgets/book/book_grid_card.dart';
import '../../widgets/book/book_list_tile.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  void _showLockedBookDialog(BuildContext context, String bookTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.lock_outline, size: 48),
        title: const Text('Book Locked'),
        content: Text(
          'You have an active assignment. Complete your assigned reading first to unlock "$bookTitle" and other books.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
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
      appBar: AppBar(
        title: isSearchActive
            ? _SearchField(ref: ref)
            : const Text('Library'),
        actions: [
          // Search toggle
          IconButton(
            icon: Icon(isSearchActive ? Icons.close : Icons.search),
            onPressed: () {
              ref.read(isSearchActiveProvider.notifier).state = !isSearchActive;
              if (!isSearchActive) {
                // Clear search when closing
                ref.read(librarySearchQueryProvider.notifier).state = '';
              }
            },
          ),
          // View mode toggle
          IconButton(
            icon: Icon(
              viewMode == LibraryViewMode.grid
                  ? Icons.view_list
                  : Icons.grid_view,
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
      body: Column(
        children: [
          // Locked library banner
          _LockedLibraryBanner(ref: ref),

          // Level filter chips (hidden during search)
          if (!isSearchActive)
            _LevelFilterChips(
              selectedLevel: selectedLevel,
              onLevelSelected: (level) {
                ref.read(selectedLevelProvider.notifier).state = level;
              },
            ),

          // Books grid/list
          Expanded(
            child: booksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    Text('Error loading books: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(filteredBooksProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (books) {
                if (books.isEmpty) {
                  return _EmptyState(
                    isSearchActive: isSearchActive,
                    selectedLevel: selectedLevel,
                  );
                }

                if (viewMode == LibraryViewMode.grid) {
                  return _BookGrid(
                    books: books,
                    onBookTap: (bookId) => context.go('/library/book/$bookId'),
                    onLockedBookTap: (bookTitle) =>
                        _showLockedBookDialog(context, bookTitle),
                  );
                } else {
                  return _BookList(
                    books: books,
                    onBookTap: (bookId) => context.go('/library/book/$bookId'),
                    onLockedBookTap: (bookTitle) =>
                        _showLockedBookDialog(context, bookTitle),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofocus: true,
      decoration: const InputDecoration(
        hintText: 'Search books...',
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      onChanged: (value) {
        ref.read(librarySearchQueryProvider.notifier).state = value;
      },
    );
  }
}

class _LockedLibraryBanner extends ConsumerWidget {
  const _LockedLibraryBanner({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockInfo = ref.watch(bookLockProvider);

    return lockInfo.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (info) {
        if (!info.hasLock) return const SizedBox.shrink();

        final colorScheme = Theme.of(context).colorScheme;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: colorScheme.primaryContainer,
          child: Row(
            children: [
              Icon(
                Icons.assignment,
                color: colorScheme.onPrimaryContainer,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You have an active reading assignment. Complete it to unlock all books.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LevelFilterChips extends StatelessWidget {
  const _LevelFilterChips({
    required this.selectedLevel,
    required this.onLevelSelected,
  });

  final String? selectedLevel;
  final ValueChanged<String?> onLevelSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // "All" chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: selectedLevel == null,
              onSelected: (_) => onLevelSelected(null),
              selectedColor: colorScheme.primaryContainer,
              checkmarkColor: colorScheme.primary,
            ),
          ),
          // Level chips
          ...cefrLevels.map((level) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(level),
                  selected: selectedLevel == level,
                  onSelected: (_) => onLevelSelected(
                    selectedLevel == level ? null : level,
                  ),
                  selectedColor: colorScheme.primaryContainer,
                  checkmarkColor: colorScheme.primary,
                ),
              ),),
        ],
      ),
    );
  }
}

class _BookGrid extends ConsumerWidget {
  const _BookGrid({
    required this.books,
    required this.onBookTap,
    required this.onLockedBookTap,
  });

  final List<dynamic> books;
  final ValueChanged<String> onBookTap;
  final ValueChanged<String> onLockedBookTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        final canAccess = ref.watch(canAccessBookProvider(book.id));

        return BookGridCard(
          book: book,
          showLockIcon: !canAccess,
          onTap: () {
            if (canAccess) {
              onBookTap(book.id);
            } else {
              onLockedBookTap(book.title);
            }
          },
        );
      },
    );
  }
}

class _BookList extends ConsumerWidget {
  const _BookList({
    required this.books,
    required this.onBookTap,
    required this.onLockedBookTap,
  });

  final List<dynamic> books;
  final ValueChanged<String> onBookTap;
  final ValueChanged<String> onLockedBookTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        final canAccess = ref.watch(canAccessBookProvider(book.id));

        return BookListTile(
          book: book,
          showLockIcon: !canAccess,
          onTap: () {
            if (canAccess) {
              onBookTap(book.id);
            } else {
              onLockedBookTap(book.title);
            }
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.isSearchActive,
    required this.selectedLevel,
  });

  final bool isSearchActive;
  final String? selectedLevel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    String message;
    IconData icon;

    if (isSearchActive) {
      message = 'No books found for your search';
      icon = Icons.search_off;
    } else if (selectedLevel != null) {
      message = 'No $selectedLevel books available yet';
      icon = Icons.library_books_outlined;
    } else {
      message = 'No books available yet';
      icon = Icons.library_books_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
