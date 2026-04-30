import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // CountOption

import '../../../core/supabase_client.dart';

/// Search query (matches title / author)
final bookSearchProvider = StateProvider<String>((ref) => '');

/// Current page index (0-based)
final bookPageProvider = StateProvider<int>((ref) => 0);

/// Sort column for book list. `created_at` = newest first by creation date,
/// `updated_at` = most recently edited bubbles to top (key when actively
/// editing several books).
final bookSortColumnProvider = StateProvider<String>((ref) => 'created_at');

/// Loads books with search and pagination.
/// Returns `{ data, total, page, pageSize }`.
final booksProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final search = ref.watch(bookSearchProvider);
  final page = ref.watch(bookPageProvider);
  final sortColumn = ref.watch(bookSortColumnProvider);

  const pageSize = 50;
  final offset = page * pageSize;

  var query = supabase.from(DbTables.books).select('*, chapters(count)');
  var countQuery = supabase.from(DbTables.books).select();

  if (search.isNotEmpty) {
    final escaped = search.replaceAll(',', ' ');
    final orFilter = 'title.ilike.%$escaped%,author.ilike.%$escaped%';
    query = query.or(orFilter);
    countQuery = countQuery.or(orFilter);
  }

  final response = await query
      .order(sortColumn, ascending: false)
      .range(offset, offset + pageSize - 1);
  final countResult = await countQuery.count(CountOption.exact);

  return {
    'data': List<Map<String, dynamic>>.from(response),
    'total': countResult.count,
    'page': page,
    'pageSize': pageSize,
  };
});

class BookListScreen extends ConsumerStatefulWidget {
  const BookListScreen({super.key});

  @override
  ConsumerState<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends ConsumerState<BookListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(bookSearchProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _resetPage() {
    ref.read(bookPageProvider.notifier).state = 0;
  }

  void _onSearchChanged(String value) {
    setState(() {}); // refresh suffixIcon
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final trimmed = value.trim();
      if (ref.read(bookSearchProvider) != trimmed) {
        ref.read(bookSearchProvider.notifier).state = trimmed;
        _resetPage();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(booksProvider);
    final currentPage = ref.watch(bookPageProvider);
    final sortColumn = ref.watch(bookSortColumnProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Books'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => context.go('/books/import'),
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Import JSON'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => context.go('/books/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Book'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Başlık veya yazar ara...',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _debounce?.cancel();
                                _searchController.clear();
                                ref.read(bookSearchProvider.notifier).state =
                                    '';
                                _resetPage();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: 12),
                // Sort toggle
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: 'created_at',
                      icon: Icon(Icons.add_circle_outline, size: 16),
                      label: Text('Eklenen'),
                    ),
                    ButtonSegment(
                      value: 'updated_at',
                      icon: Icon(Icons.history, size: 16),
                      label: Text('Düzenlenen'),
                    ),
                  ],
                  selected: {sortColumn},
                  onSelectionChanged: (s) {
                    ref.read(bookSortColumnProvider.notifier).state =
                        s.first;
                    _resetPage();
                  },
                ),
              ],
            ),
          ),

          // List + pagination
          Expanded(
            child: booksAsync.when(
              data: (result) {
                final books = result['data'] as List<Map<String, dynamic>>;
                final total = result['total'] as int;
                final pageSize = result['pageSize'] as int;
                final totalPages = total == 0 ? 1 : (total / pageSize).ceil();

                if (books.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          ref.read(bookSearchProvider).isEmpty
                              ? 'Henüz kitap yok'
                              : 'Aramaya uygun kitap bulunamadı',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => context.go('/books/new'),
                          icon: const Icon(Icons.add),
                          label: const Text('İlk kitabını oluştur'),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$total kitaptan ${books.length} tanesi',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          Text(
                            'Sayfa ${currentPage + 1} / $totalPages',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: books.length,
                        itemBuilder: (context, index) {
                          final book = books[index];
                          final chapterCount =
                              book['chapters']?[0]?['count'] ?? 0;

                          return _BookCard(
                            book: book,
                            chapterCount: chapterCount,
                            onTap: () => context.go('/books/${book['id']}'),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: currentPage > 0
                                ? () => ref
                                    .read(bookPageProvider.notifier)
                                    .state = currentPage - 1
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          const SizedBox(width: 16),
                          Text('Sayfa ${currentPage + 1} / $totalPages'),
                          const SizedBox(width: 16),
                          IconButton(
                            onPressed: currentPage < totalPages - 1
                                ? () => ref
                                    .read(bookPageProvider.notifier)
                                    .state = currentPage + 1
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Colors.red.shade400),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(booksProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.chapterCount,
    required this.onTap,
  });

  final Map<String, dynamic> book;
  final int chapterCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final coverUrl = book['cover_image_url'] as String?;
    final level = book['level'] as String? ?? 'Unknown';
    final isPublished = book['status'] == BookStatus.published.dbValue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Cover image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 120,
                  child: coverUrl != null && coverUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _buildPlaceholder(),
                          errorWidget: (_, __, ___) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
              ),
              const SizedBox(width: 16),

              // Book info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      book['title'] as String? ?? 'Untitled',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Author
                    if (book['author'] != null)
                      Text(
                        'Author: ${book['author']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    const SizedBox(height: 8),

                    // Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _Chip(
                          label: level,
                          color: _getLevelColor(level),
                        ),
                        _Chip(
                          label: '$chapterCount chapters',
                          color: Colors.grey,
                        ),
                        if (isPublished)
                          const _Chip(
                            label: 'Published',
                            color: Colors.green,
                          )
                        else
                          const _Chip(
                            label: 'Draft',
                            color: Colors.orange,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(
        Icons.menu_book,
        color: Colors.grey.shade400,
        size: 32,
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level.toUpperCase()) {
      case 'A1':
        return Colors.green;
      case 'A2':
        return Colors.lightGreen;
      case 'B1':
        return Colors.orange;
      case 'B2':
        return Colors.deepOrange;
      case 'C1':
        return Colors.red;
      case 'C2':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
