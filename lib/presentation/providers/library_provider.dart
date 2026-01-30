import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/book.dart';
import 'book_provider.dart';

/// View mode for the library (grid or list)
enum LibraryViewMode { grid, list }

/// Current view mode state
final libraryViewModeProvider = StateProvider<LibraryViewMode>((ref) {
  return LibraryViewMode.grid;
});

/// Currently selected level filter (null = All)
final selectedLevelProvider = StateProvider<String?>((ref) => null);

/// Search query state
final librarySearchQueryProvider = StateProvider<String>((ref) => '');

/// Whether search is active
final isSearchActiveProvider = StateProvider<bool>((ref) => false);

/// Available CEFR levels for filtering
const cefrLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

/// Combined books provider that responds to filters and search
final filteredBooksProvider = FutureProvider<List<Book>>((ref) async {
  final searchQuery = ref.watch(librarySearchQueryProvider);
  final isSearchActive = ref.watch(isSearchActiveProvider);

  // If search is active, use search provider
  if (isSearchActive && searchQuery.isNotEmpty) {
    return ref.watch(bookSearchProvider(searchQuery).future);
  }

  // Otherwise, use filtered books
  final selectedLevel = ref.watch(selectedLevelProvider);
  final filters = BookFilters(
    level: selectedLevel,
    page: 1,
    pageSize: 50, // Load more books for library view
  );

  return ref.watch(booksProvider(filters).future);
});
