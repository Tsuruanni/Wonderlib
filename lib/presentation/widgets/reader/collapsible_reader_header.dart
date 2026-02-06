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
        const collapsedHeight = 44.0;
        final currentHeight = constraints.maxHeight;

        final collapseProgress = ((expandedHeight - currentHeight) /
            (expandedHeight - collapsedHeight)).clamp(0.0, 1.0);

        final isCollapsed = collapseProgress > 0.4;

        return ClipRect(
          child: ColoredBox(
            color: backgroundColor,
            child: SafeArea(
              bottom: false,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                // Expanded content (fades out as we scroll)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: collapseProgress > 0.9,
                    child: Opacity(
                      opacity: (1 - collapseProgress).clamp(0.0, 1.0),
                      child: _ExpandedContent(
                        book: book,
                        chapter: chapter,
                        chapterNumber: chapterNumber,
                        scrollProgress: scrollProgress,
                        textColor: textColor,
                        backgroundColor: backgroundColor,
                      ),
                    ),
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
      padding: const EdgeInsets.fromLTRB(16, 44, 16, 12),
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

          // Book cover with chapter badge overlay
          Expanded(
            child: Stack(
              children: [
                // Book cover
                Positioned.fill(
                  child: Container(
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

                // Chapter badge (top-left overlay)
                Positioned(
                  top: 12,
                  left: 12,
                  child: _ChapterBadge(
                    chapter: chapter,
                    chapterNumber: chapterNumber,
                  ),
                ),
              ],
            ),
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

  @override
  Widget build(BuildContext context) {
    // Only show when collapsed
    if (opacity < 0.3) return const SizedBox.shrink();

    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
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
          children: [
            // Close button
            GestureDetector(
              onTap: onClose,
              child: Icon(Icons.close, color: textColor.withValues(alpha: 0.6), size: 20),
            ),

            const SizedBox(width: 12),

            // Chapter info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Chapter badge + title row
                  Row(
                    children: [
                      // Chapter badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'CHAPTER $chapterNumber',
                          style: const TextStyle(
                            color: Color(0xFF4F46E5),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Chapter title
                      Expanded(
                        child: Text(
                          chapter.title,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: scrollProgress,
                      minHeight: 3,
                      backgroundColor: textColor.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF6366F1)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Stats row: Time + Gold
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reading time (just minutes)
                Text(
                  readingTime,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.5),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),

                if (sessionXP > 0) ...[
                  const SizedBox(width: 12),
                  // Gold/XP indicator
                  const Icon(
                    Icons.monetization_on,
                    color: Color(0xFFEAB308),
                    size: 18,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '+$sessionXP',
                    style: const TextStyle(
                      color: Color(0xFFEAB308),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(width: 12),

            // Settings button
            GestureDetector(
              onTap: onSettingsTap,
              child: Icon(Icons.tune_rounded, color: textColor.withValues(alpha: 0.6), size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact chapter badge - overlays on book cover
class _ChapterBadge extends StatelessWidget {
  const _ChapterBadge({
    required this.chapter,
    required this.chapterNumber,
  });

  final Chapter chapter;
  final int chapterNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chapter label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E7FF),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'CHAPTER $chapterNumber',
              style: const TextStyle(
                color: Color(0xFF4F46E5),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Chapter title
          Text(
            chapter.title,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
