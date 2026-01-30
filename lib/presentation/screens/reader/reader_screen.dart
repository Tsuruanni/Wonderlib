import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/book_provider.dart';
import '../../providers/reader_provider.dart';
import '../../widgets/reader/chapter_navigation_bar.dart';
import '../../widgets/reader/integrated_reader_content.dart';
import '../../widgets/reader/reader_settings_sheet.dart';
import '../../widgets/reader/vocabulary_popup.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final String bookId;
  final String chapterId;

  const ReaderScreen({
    super.key,
    required this.bookId,
    required this.chapterId,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  Timer? _readingTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _startReadingTimer();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _readingTimer?.cancel();
    super.dispose();
  }

  void _startReadingTimer() {
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(readingTimerProvider.notifier).tick();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;

    if (maxScroll > 0) {
      final progress = (currentScroll / maxScroll).clamp(0.0, 1.0);
      ref.read(scrollProgressProvider.notifier).state = progress;
    }
  }

  void _onVocabularyTap(vocab, Offset position) {
    ref.read(selectedVocabularyProvider.notifier).state = vocab;
    ref.read(vocabularyPopupPositionProvider.notifier).state = position;
  }

  void _closeVocabularyPopup() {
    ref.read(selectedVocabularyProvider.notifier).state = null;
    ref.read(vocabularyPopupPositionProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final chapterAsync = ref.watch(chapterByIdProvider(widget.chapterId));
    final chaptersAsync = ref.watch(chaptersProvider(widget.bookId));
    final bookAsync = ref.watch(bookByIdProvider(widget.bookId));
    final settings = ref.watch(readerSettingsProvider);
    final scrollProgress = ref.watch(scrollProgressProvider);
    final selectedVocab = ref.watch(selectedVocabularyProvider);
    final popupPosition = ref.watch(vocabularyPopupPositionProvider);

    return chapterAsync.when(
      loading: () => Scaffold(
        backgroundColor: settings.theme.background,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: settings.theme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: settings.theme.text,
        ),
        body: Center(child: Text('Error: $error')),
      ),
      data: (chapter) {
        if (chapter == null) {
          return Scaffold(
            backgroundColor: settings.theme.background,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: settings.theme.text,
            ),
            body: const Center(child: Text('Chapter not found')),
          );
        }

        final chapters = chaptersAsync.valueOrNull ?? [];
        final currentIndex = chapters.indexWhere((c) => c.id == widget.chapterId);
        final hasPrevious = currentIndex > 0;
        final hasNext = currentIndex < chapters.length - 1;
        final isLastChapter = currentIndex == chapters.length - 1;

        return Scaffold(
          backgroundColor: settings.theme.background,
          appBar: AppBar(
            backgroundColor: settings.theme.background,
            foregroundColor: settings.theme.text,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.home_outlined, color: settings.theme.text),
              onPressed: () => context.go('/library/book/${widget.bookId}'),
            ),
            title: Text(
              chapter.title,
              style: TextStyle(
                color: settings.theme.text,
                fontSize: 16,
              ),
            ),
            actions: [
              // Session XP indicator
              Consumer(
                builder: (context, ref, child) {
                  final sessionXP = ref.watch(sessionXPProvider);
                  if (sessionXP > 0) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38A169).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt,
                            color: Color(0xFF38A169),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '+$sessionXP XP',
                            style: const TextStyle(
                              color: Color(0xFF38A169),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              // Settings button
              IconButton(
                icon: Icon(Icons.settings, color: settings.theme.text),
                onPressed: () => ReaderSettingsSheet.show(context),
              ),
            ],
          ),
          body: Stack(
            children: [
              // Main content
              SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chapter title
                    Text(
                      chapter.title,
                      style: TextStyle(
                        fontSize: settings.fontSize + 8,
                        fontWeight: FontWeight.bold,
                        color: settings.theme.text,
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Chapter content with inline activities
                    if (chapter.content != null)
                      IntegratedReaderContent(
                        chapter: chapter,
                        settings: settings,
                        onVocabularyTap: _onVocabularyTap,
                        scrollController: _scrollController,
                      )
                    else
                      Text(
                        'No content available for this chapter.',
                        style: TextStyle(
                          color: settings.theme.text.withValues(alpha: 0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),

                    const SizedBox(height: 32),

                    // End of chapter indicator
                    if (chapter.content != null)
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.auto_stories,
                              size: 32,
                              color: settings.theme.text.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'End of Chapter',
                              style: TextStyle(
                                color: settings.theme.text.withValues(alpha: 0.5),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Vocabulary popup
              if (selectedVocab != null && popupPosition != null)
                VocabularyPopup(
                  vocabulary: selectedVocab,
                  position: popupPosition,
                  onClose: _closeVocabularyPopup,
                  onAddToVocabulary: () {
                    // TODO: Add to user's vocabulary
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added "${selectedVocab.word}" to vocabulary'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
            ],
          ),
          bottomNavigationBar: ChapterNavigationBar(
            chapterNumber: currentIndex + 1,
            totalChapters: chapters.length,
            scrollProgress: scrollProgress,
            hasPrevious: hasPrevious,
            hasNext: hasNext,
            isLastChapter: isLastChapter,
            onPrevious: hasPrevious
                ? () {
                    final prevChapter = chapters[currentIndex - 1];
                    context.go('/reader/${widget.bookId}/${prevChapter.id}');
                  }
                : null,
            onNext: hasNext
                ? () {
                    final nextChapter = chapters[currentIndex + 1];
                    context.go('/reader/${widget.bookId}/${nextChapter.id}');
                  }
                : null,
            onComplete: () {
              // Mark chapter as complete and go back to book detail
              // TODO: Update reading progress
              context.go('/library/book/${widget.bookId}');
            },
          ),
        );
      },
    );
  }
}
