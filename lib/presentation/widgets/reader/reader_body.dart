import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/reader_constants.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/chapter.dart';
import '../../providers/activity_provider.dart';
import '../../providers/audio_sync_provider.dart';
import '../../providers/content_block_provider.dart';
import '../../providers/reader_provider.dart';
import 'chapter_completion_card.dart';
import 'collapsible_reader_header.dart';
import 'content_block_list.dart';
import 'integrated_reader_content.dart';
import 'reader_settings_sheet.dart';

/// Main scrollable body of the reader screen.
/// Contains the collapsible header and chapter content.
class ReaderBody extends ConsumerWidget {
  const ReaderBody({
    super.key,
    required this.book,
    required this.chapter,
    required this.chapters,
    required this.settings,
    required this.onVocabularyTap,
    required this.onWordTap,
    required this.onClose,
    required this.onNextChapter,
    required this.onBackToBook,
  });

  final Book book;
  final Chapter chapter;
  final List<Chapter> chapters;
  final ReaderSettings settings;
  final void Function(ChapterVocabulary vocab, Offset position) onVocabularyTap;
  final void Function(String word, Offset position) onWordTap;
  final VoidCallback onClose;
  final Future<void> Function(Chapter nextChapter) onNextChapter;
  final VoidCallback onBackToBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityProgress = ref.watch(activityProgressProvider);
    final isChapterComplete = ref.watch(isChapterCompleteProvider);
    final sessionXP = ref.watch(sessionXPProvider);
    final readingTime = ref.watch(readingTimerProvider);

    final currentIndex = chapters.indexWhere((c) => c.id == chapter.id);
    final hasNextChapter = currentIndex < chapters.length - 1;
    final nextChapter = hasNextChapter ? chapters[currentIndex + 1] : null;

    // Set total activities count for progress calculation
    final activitiesAsync = ref.watch(inlineActivitiesProvider(chapter.id));
    final inlineActivitiesCount = activitiesAsync.when(
      data: (activities) => activities.length,
      loading: () => 0,
      error: (_, __) => 0,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(totalActivitiesProvider.notifier).state = inlineActivitiesCount;
    });

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // User scroll detection - disable follow mode when user drags
        if (notification is ScrollStartNotification) {
          if (notification.dragDetails != null) {
            // User initiated scroll (finger drag) - not programmatic
            try {
              ref.read(audioSyncControllerProvider.notifier).disableFollowScroll();
            } catch (_) {
              // Audio controller not ready
            }
          }
        }

        // Scroll progress tracking for header collapse
        if (notification is ScrollUpdateNotification) {
          final maxScroll = notification.metrics.maxScrollExtent;
          final currentScroll = notification.metrics.pixels;
          if (maxScroll > 0) {
            final progress = (currentScroll / maxScroll).clamp(0.0, 1.0);
            ref.read(scrollProgressProvider.notifier).state = progress;
          }
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          // Collapsible header
          SliverAppBar(
            expandedHeight: ReaderConstants.expandedHeaderHeight,
            toolbarHeight: ReaderConstants.collapsedHeaderHeight,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: settings.theme.background,
            flexibleSpace: CollapsibleReaderHeader(
              book: book,
              chapter: chapter,
              chapterNumber: currentIndex + 1,
              scrollProgress: activityProgress,
              sessionXP: sessionXP,
              readingTimeSeconds: readingTime,
              backgroundColor: settings.theme.background,
              textColor: settings.theme.text,
              onClose: onClose,
              onSettingsTap: () => ReaderSettingsSheet.show(context),
            ),
          ),

          // Chapter content
          SliverToBoxAdapter(
            child: Padding(
              padding: ReaderConstants.contentPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chapter content - uses ContentBlockList if available,
                  // falls back to IntegratedReaderContent for legacy content
                  _ChapterContent(
                    chapter: chapter,
                    settings: settings,
                    onVocabularyTap: onVocabularyTap,
                    onWordTap: onWordTap,
                  ),

                  const SizedBox(height: ReaderConstants.sectionSpacing),

                  // Chapter completion actions (only visible when all activities done)
                  if (isChapterComplete)
                    ChapterCompletionCard(
                      hasNextChapter: hasNextChapter,
                      nextChapter: nextChapter,
                      settings: settings,
                      sessionXP: sessionXP,
                      onNextChapter: () {
                        if (nextChapter != null) {
                          onNextChapter(nextChapter);
                        }
                      },
                      onBackToBook: onBackToBook,
                    ),

                  // Extra padding at bottom
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Internal widget for rendering chapter content based on content type.
class _ChapterContent extends ConsumerWidget {
  const _ChapterContent({
    required this.chapter,
    required this.settings,
    required this.onVocabularyTap,
    required this.onWordTap,
  });

  final Chapter chapter;
  final ReaderSettings settings;
  final void Function(ChapterVocabulary vocab, Offset position) onVocabularyTap;
  final void Function(String word, Offset position) onWordTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usesContentBlocks = ref.watch(chapterUsesContentBlocksProvider(chapter.id));

    return usesContentBlocks.when(
      data: (usesBlocks) {
        if (usesBlocks) {
          // New content block system
          return ContentBlockList(
            key: ValueKey('blocks-${chapter.id}'),
            chapter: chapter,
            settings: settings,
            onVocabularyTap: onVocabularyTap,
            onWordTap: onWordTap,
          );
        } else if (chapter.content != null) {
          // Legacy plain text content
          return IntegratedReaderContent(
            key: ValueKey(chapter.id),
            chapter: chapter,
            settings: settings,
            onVocabularyTap: onVocabularyTap,
            onWordTap: onWordTap,
            scrollController: null,
          );
        } else {
          return _buildNoContentMessage();
        }
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: settings.theme.text.withValues(alpha: 0.5),
        ),
      ),
      error: (_, __) {
        // On error, try legacy content
        if (chapter.content != null) {
          return IntegratedReaderContent(
            key: ValueKey(chapter.id),
            chapter: chapter,
            settings: settings,
            onVocabularyTap: onVocabularyTap,
            onWordTap: onWordTap,
            scrollController: null,
          );
        }
        return _buildErrorMessage();
      },
    );
  }

  Widget _buildNoContentMessage() {
    return Text(
      'No content available for this chapter.',
      style: TextStyle(
        color: settings.theme.text.withValues(alpha: 0.7),
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Text(
      'Failed to load content.',
      style: TextStyle(
        color: settings.theme.text.withValues(alpha: 0.7),
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
