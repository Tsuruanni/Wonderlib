import 'package:flutter/material.dart';

import '../../../domain/entities/book.dart';
import 'level_badge.dart';

/// A list tile widget for displaying a book in list view
/// Shows cover thumbnail, title, author, level, and description preview
class BookListTile extends StatelessWidget {
  const BookListTile({
    super.key,
    required this.book,
    required this.onTap,
  });

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover thumbnail
              Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: colorScheme.surfaceContainerHighest,
                ),
                clipBehavior: Clip.antiAlias,
                child: book.coverUrl != null
                    ? Image.network(
                        book.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _ThumbnailPlaceholder(colorScheme: colorScheme);
                        },
                      )
                    : _ThumbnailPlaceholder(colorScheme: colorScheme),
              ),

              const SizedBox(width: 12),

              // Book info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and level row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            book.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        LevelBadge(level: book.level),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Author (from metadata)
                    if (book.metadata['author'] != null)
                      Text(
                        book.metadata['author'] as String,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),

                    const SizedBox(height: 4),

                    // Description preview
                    if (book.description != null)
                      Text(
                        book.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 8),

                    // Stats row
                    Row(
                      children: [
                        _StatChip(
                          icon: Icons.schedule,
                          label: book.readingTime.isNotEmpty
                              ? book.readingTime
                              : '${book.estimatedMinutes ?? 0} min',
                          colorScheme: colorScheme,
                        ),
                        const SizedBox(width: 12),
                        _StatChip(
                          icon: Icons.menu_book,
                          label: '${book.chapterCount} chapters',
                          colorScheme: colorScheme,
                        ),
                        if (book.wordCount != null) ...[
                          const SizedBox(width: 12),
                          _StatChip(
                            icon: Icons.text_fields,
                            label: '${(book.wordCount! / 1000).toStringAsFixed(1)}k words',
                            colorScheme: colorScheme,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colorScheme.primaryContainer,
      child: Center(
        child: Icon(
          Icons.book,
          size: 24,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
