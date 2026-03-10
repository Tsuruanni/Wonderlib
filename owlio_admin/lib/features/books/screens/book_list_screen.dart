import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/supabase_client.dart';

/// Provider for loading all books
final booksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.books)
      .select('*, chapters(count)')
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(response);
});

class BookListScreen extends ConsumerWidget {
  const BookListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitaplar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => context.go('/books/import'),
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('JSON İçe Aktar'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => context.go('/books/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Yeni Kitap'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: booksAsync.when(
        data: (books) {
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
                    'Henüz kitap yok',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => context.go('/books/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('İlk kitabınızı oluşturun'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              final chapterCount = book['chapters']?[0]?['count'] ?? 0;

              return _BookCard(
                book: book,
                chapterCount: chapterCount,
                onTap: () => context.go('/books/${book['id']}'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text('Hata: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(booksProvider),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
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
    final level = book['level'] as String? ?? 'Bilinmiyor';
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
                      book['title'] as String? ?? 'Başlıksız',
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
                        'Yazar: ${book['author']}',
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
                          label: '$chapterCount bölüm',
                          color: Colors.grey,
                        ),
                        if (isPublished)
                          const _Chip(
                            label: 'Yayında',
                            color: Colors.green,
                          )
                        else
                          const _Chip(
                            label: 'Taslak',
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
    switch (level.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
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
