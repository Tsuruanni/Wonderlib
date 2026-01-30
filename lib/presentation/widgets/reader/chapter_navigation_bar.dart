import 'package:flutter/material.dart';

/// Bottom navigation bar for reader screen
/// Shows chapter progress and navigation buttons
class ChapterNavigationBar extends StatelessWidget {
  const ChapterNavigationBar({
    super.key,
    required this.chapterNumber,
    required this.totalChapters,
    required this.scrollProgress,
    required this.onPrevious,
    required this.onNext,
    required this.onComplete,
    this.hasPrevious = true,
    this.hasNext = true,
    this.isLastChapter = false,
  });

  final int chapterNumber;
  final int totalChapters;
  final double scrollProgress;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onComplete;
  final bool hasPrevious;
  final bool hasNext;
  final bool isLastChapter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress indicator
            LinearProgressIndicator(
              value: scrollProgress,
              minHeight: 3,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(colorScheme.primary),
            ),

            // Navigation row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // Previous button
                  IconButton(
                    onPressed: hasPrevious ? onPrevious : null,
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous chapter',
                  ),

                  // Chapter info
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Chapter $chapterNumber of $totalChapters',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${(scrollProgress * 100).toStringAsFixed(0)}% complete',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Next/Complete button
                  if (isLastChapter && scrollProgress > 0.9)
                    FilledButton.icon(
                      onPressed: onComplete,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Complete'),
                    )
                  else
                    IconButton(
                      onPressed: hasNext ? onNext : null,
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'Next chapter',
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
