import 'package:flutter/material.dart';

import '../../../core/constants/reader_constants.dart';
import '../../../domain/entities/chapter.dart';
import '../../providers/reader_provider.dart';

/// Widget shown when chapter is complete, allowing navigation to next chapter
/// or showing book completion celebration.
class ChapterCompletionCard extends StatelessWidget {
  const ChapterCompletionCard({
    super.key,
    required this.hasNextChapter,
    required this.nextChapter,
    required this.settings,
    required this.sessionXP,
    required this.onNextChapter,
    required this.onBackToBook,
  });

  final bool hasNextChapter;
  final Chapter? nextChapter;
  final ReaderSettings settings;
  final int sessionXP;
  final VoidCallback onNextChapter;
  final VoidCallback onBackToBook;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          if (hasNextChapter && nextChapter != null)
            _buildNextChapterButton()
          else
            _buildBookCompleteSection(),
        ],
      ),
    );
  }

  Widget _buildNextChapterButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onNextChapter,
        style: ElevatedButton.styleFrom(
          backgroundColor: ReaderConstants.nextChapterButtonColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ReaderConstants.cardBorderRadius),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.arrow_forward, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Next Chapter',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    nextChapter!.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookCompleteSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ReaderConstants.successColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(ReaderConstants.cardBorderRadius),
            border: Border.all(
              color: ReaderConstants.successColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.celebration,
                size: 40,
                color: ReaderConstants.successColor,
              ),
              const SizedBox(height: 8),
              Text(
                'Book Completed!',
                style: TextStyle(
                  color: settings.theme.text,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'You earned +$sessionXP XP',
                style: const TextStyle(
                  color: ReaderConstants.successColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ReaderConstants.buttonSpacing),
        OutlinedButton(
          onPressed: onBackToBook,
          style: OutlinedButton.styleFrom(
            foregroundColor: settings.theme.text,
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ReaderConstants.cardBorderRadius),
            ),
            side: BorderSide(
              color: settings.theme.text.withValues(alpha: 0.3),
            ),
          ),
          child: const Text('Back to Book Details'),
        ),
      ],
    );
  }
}
