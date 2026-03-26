import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/extensions/context_extensions.dart';
import '../../../../domain/entities/teacher.dart';
import '../../../providers/teacher_provider.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/playful_card.dart';
import '../../../widgets/common/responsive_layout.dart';

class ReadingProgressReportScreen extends ConsumerWidget {
  const ReadingProgressReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(schoolBookReadingStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Progress'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(schoolBookReadingStatsProvider);
        },
        child: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ErrorStateWidget(
            message: 'Error loading data',
            onRetry: () => ref.invalidate(schoolBookReadingStatsProvider),
          ),
          data: (books) {
            if (books.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 64,
                      color: context.colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No books in library',
                      style: context.textTheme.titleMedium,
                    ),
                  ],
                ),
              );
            }

            final activeBooks = books.where((b) => b.totalReaders > 0).length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary
                ResponsiveConstraint(
                  maxWidth: 900,
                  child: PlayfulCard(
                    color: context.colorScheme.primaryContainer,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryItem(
                          value: '${books.length}',
                          label: 'Total Books',
                          icon: Icons.menu_book,
                        ),
                        _SummaryItem(
                          value: '$activeBooks',
                          label: 'Being Read',
                          icon: Icons.auto_stories,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Library Books',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Book cards
                ResponsiveWrap(
                  minItemWidth: 280,
                  children: books
                      .map((book) => _BookStatsCard(book: book))
                      .toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: context.colorScheme.onPrimaryContainer, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: context.colorScheme.onPrimaryContainer,
          ),
        ),
        Text(
          label,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _BookStatsCard extends StatelessWidget {
  const _BookStatsCard({required this.book});

  final BookReadingStats book;

  @override
  Widget build(BuildContext context) {
    return PlayfulCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      child: Row(
          children: [
            // Book cover
            Container(
              width: 50,
              height: 70,
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
                image: book.coverUrl != null
                    ? DecorationImage(
                        image: NetworkImage(book.coverUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: book.coverUrl == null
                  ? Icon(Icons.book, color: context.colorScheme.outline)
                  : null,
            ),
            const SizedBox(width: 12),

            // Book info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getLevelColor(book.level).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      book.level,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: _getLevelColor(book.level),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people, size: 14, color: context.colorScheme.outline),
                      const SizedBox(width: 4),
                      Text(
                        '${book.totalReaders} readers',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.check_circle, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        '${book.completedReaders} completed',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Avg progress
            if (book.totalReaders > 0)
              SizedBox(
                width: 50,
                height: 50,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: book.avgProgress / 100,
                      strokeWidth: 4,
                      backgroundColor: context.colorScheme.surfaceContainerHighest,
                    ),
                    Text(
                      '${book.avgProgress.toStringAsFixed(0)}%',
                      style: context.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level) {
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
        return Colors.grey;
    }
  }
}
