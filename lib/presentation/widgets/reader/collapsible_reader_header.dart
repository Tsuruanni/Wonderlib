import 'package:flutter/material.dart';

import '../../../domain/entities/book.dart';
import '../../../domain/entities/chapter.dart';

/// Collapsible header for the reader screen
/// Shows book info in expanded state, chapter card in collapsed state
class CollapsibleReaderHeader extends StatelessWidget {
  const CollapsibleReaderHeader({
    super.key,
    required this.book,
    required this.chapter,
    required this.chapterNumber,
    required this.scrollProgress,
    required this.sessionXP,
    required this.readingTimeSeconds,
    required this.backgroundColor,
    required this.textColor,
    this.onClose,
    this.onSettingsTap,
  });

  final Book book;
  final Chapter chapter;
  final int chapterNumber;
  final double scrollProgress;
  final int sessionXP;
  final int readingTimeSeconds;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback? onClose;
  final VoidCallback? onSettingsTap;

  String _formatReadingTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate collapse progress (0 = fully expanded, 1 = fully collapsed)
        const expandedHeight = 400.0;
        const collapsedHeight = 100.0;
        final currentHeight = constraints.maxHeight;

        final collapseProgress = ((expandedHeight - currentHeight) /
            (expandedHeight - collapsedHeight)).clamp(0.0, 1.0);

        final isCollapsed = collapseProgress > 0.7;

        return ColoredBox(
          color: backgroundColor,
          child: SafeArea(
            bottom: false,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Expanded content (fades out as we scroll)
                if (!isCollapsed)
                  Opacity(
                    opacity: (1 - collapseProgress * 1.5).clamp(0.0, 1.0),
                    child: _ExpandedContent(
                      book: book,
                      chapter: chapter,
                      chapterNumber: chapterNumber,
                      scrollProgress: scrollProgress,
                      textColor: textColor,
                      backgroundColor: backgroundColor,
                    ),
                  ),

                // Collapsed content (always visible, positioned at top)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _CollapsedContent(
                    chapter: chapter,
                    chapterNumber: chapterNumber,
                    scrollProgress: scrollProgress,
                    sessionXP: sessionXP,
                    readingTime: _formatReadingTime(readingTimeSeconds),
                    textColor: textColor,
                    backgroundColor: backgroundColor,
                    opacity: collapseProgress,
                    onClose: onClose,
                    onSettingsTap: onSettingsTap,
                  ),
                ),

                // Close button (visible in expanded state)
                if (!isCollapsed)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Opacity(
                      opacity: (1 - collapseProgress * 2).clamp(0.0, 1.0),
                      child: IconButton(
                        icon: Icon(Icons.close, color: textColor),
                        onPressed: onClose,
                      ),
                    ),
                  ),

                // Settings button (visible in expanded state)
                if (!isCollapsed)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Opacity(
                      opacity: (1 - collapseProgress * 2).clamp(0.0, 1.0),
                      child: IconButton(
                        icon: Icon(Icons.settings, color: textColor),
                        onPressed: onSettingsTap,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Expanded content showing full book info
class _ExpandedContent extends StatelessWidget {
  const _ExpandedContent({
    required this.book,
    required this.chapter,
    required this.chapterNumber,
    required this.scrollProgress,
    required this.textColor,
    required this.backgroundColor,
  });

  final Book book;
  final Chapter chapter;
  final int chapterNumber;
  final double scrollProgress;
  final Color textColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 44, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Book title
          Text(
            book.title,
            style: TextStyle(
              color: textColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          // Book cover (flexible to take available space)
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: backgroundColor,
                image: book.coverUrl != null
                    ? DecorationImage(
                        image: NetworkImage(book.coverUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: book.coverUrl == null
                  ? Center(
                      child: Icon(
                        Icons.book,
                        size: 48,
                        color: textColor.withValues(alpha: 0.3),
                      ),
                    )
                  : null,
            ),
          ),

          const SizedBox(height: 12),

          // Chapter card
          _ChapterCard(
            chapter: chapter,
            chapterNumber: chapterNumber,
            scrollProgress: scrollProgress,
            textColor: textColor,
            backgroundColor: backgroundColor,
            isCompact: false,
          ),
        ],
      ),
    );
  }
}

/// Collapsed content showing only chapter info
class _CollapsedContent extends StatelessWidget {
  const _CollapsedContent({
    required this.chapter,
    required this.chapterNumber,
    required this.scrollProgress,
    required this.sessionXP,
    required this.readingTime,
    required this.textColor,
    required this.backgroundColor,
    required this.opacity,
    this.onClose,
    this.onSettingsTap,
  });

  final Chapter chapter;
  final int chapterNumber;
  final double scrollProgress;
  final int sessionXP;
  final String readingTime;
  final Color textColor;
  final Color backgroundColor;
  final double opacity;
  final VoidCallback? onClose;
  final VoidCallback? onSettingsTap;

  String? get _chapterImageUrl =>
      chapter.imageUrls.isNotEmpty ? chapter.imageUrls.first : null;

  @override
  Widget build(BuildContext context) {
    // Only show when collapsed
    if (opacity < 0.3) return const SizedBox.shrink();

    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            bottom: BorderSide(
              color: textColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Close button
            IconButton(
              icon: Icon(Icons.close, color: textColor, size: 22),
              onPressed: onClose,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),

            const SizedBox(width: 4),

            // Chapter info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top row: Chapter label + XP + Time
                  Row(
                    children: [
                      Text(
                        'CHAPTER $chapterNumber',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      // XP indicator
                      if (sessionXP > 0) ...[
                        const Icon(
                          Icons.bolt,
                          color: Color(0xFF38A169),
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '+$sessionXP',
                          style: const TextStyle(
                            color: Color(0xFF38A169),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      // Reading time
                      Icon(
                        Icons.timer_outlined,
                        color: textColor.withValues(alpha: 0.5),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        readingTime,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 2),

                  // Chapter title
                  Text(
                    chapter.title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: scrollProgress,
                      minHeight: 4,
                      backgroundColor: textColor.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFFE53935)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Chapter thumbnail
            Container(
              width: 44,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: textColor.withValues(alpha: 0.1),
                image: _chapterImageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(_chapterImageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _chapterImageUrl == null
                  ? Center(
                      child: Icon(
                        Icons.auto_stories,
                        size: 20,
                        color: textColor.withValues(alpha: 0.3),
                      ),
                    )
                  : null,
            ),

            const SizedBox(width: 4),

            // Settings button
            IconButton(
              icon: Icon(Icons.settings, color: textColor, size: 22),
              onPressed: onSettingsTap,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chapter card widget used in expanded state
class _ChapterCard extends StatelessWidget {
  const _ChapterCard({
    required this.chapter,
    required this.chapterNumber,
    required this.scrollProgress,
    required this.textColor,
    required this.backgroundColor,
    required this.isCompact,
  });

  final Chapter chapter;
  final int chapterNumber;
  final double scrollProgress;
  final Color textColor;
  final Color backgroundColor;
  final bool isCompact;

  String? get _chapterImageUrl =>
      chapter.imageUrls.isNotEmpty ? chapter.imageUrls.first : null;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Chapter info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHAPTER $chapterNumber',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  chapter.title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: scrollProgress,
                    minHeight: 4,
                    backgroundColor: textColor.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFE53935)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Chapter thumbnail
          Container(
            width: 56,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: textColor.withValues(alpha: 0.1),
              image: _chapterImageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(_chapterImageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _chapterImageUrl == null
                ? Center(
                    child: Icon(
                      Icons.auto_stories,
                      size: 24,
                      color: textColor.withValues(alpha: 0.3),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
