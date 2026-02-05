import 'package:flutter/material.dart';

import '../../../domain/entities/chapter.dart';

/// A popup widget that shows vocabulary word definition
/// Appears when user taps on a highlighted word
class VocabularyPopup extends StatelessWidget {
  const VocabularyPopup({
    super.key,
    required this.vocabulary,
    required this.position,
    required this.onClose,
    this.onAddToVocabulary,
  });

  final ChapterVocabulary vocabulary;
  final Offset position;
  final VoidCallback onClose;
  final VoidCallback? onAddToVocabulary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;

    // Calculate popup position to keep it on screen
    const popupWidth = 280.0;
    const popupHeight = 180.0;

    double left = position.dx - popupWidth / 2;
    double top = position.dy - popupHeight - 20;

    // Adjust if off screen horizontally
    if (left < 16) left = 16;
    if (left + popupWidth > screenSize.width - 16) {
      left = screenSize.width - popupWidth - 16;
    }

    // Show below if not enough space above
    if (top < 100) {
      top = position.dy + 20;
    }

    return Stack(
      children: [
        // Dismiss overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: Container(color: Colors.transparent),
          ),
        ),

        // Popup card
        Positioned(
          left: left,
          top: top,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: colorScheme.surface,
            child: Container(
              width: popupWidth,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with word and close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vocabulary.word,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            if (vocabulary.phonetic != null)
                              Text(
                                vocabulary.phonetic!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: onClose,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Meaning
                  if (vocabulary.meaning != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.translate,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              vocabulary.meaning!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (onAddToVocabulary != null)
                        TextButton.icon(
                          onPressed: () {
                            onAddToVocabulary!();
                            onClose();
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add to vocabulary'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
