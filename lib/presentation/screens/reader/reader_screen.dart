import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/usecases/reading/save_reading_progress_usecase.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/reader_provider.dart';
import '../../providers/repository_providers.dart';
import '../../providers/usecase_providers.dart';
import '../../widgets/reader/collapsible_reader_header.dart';
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
  Timer? _readingTimer;

  @override
  void initState() {
    super.initState();
    // Load completed activities and reset state after frame is built
    // (Riverpod doesn't allow provider modification during widget lifecycle)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompletedActivities();
      _updateCurrentChapter();
      ref.read(sessionXPProvider.notifier).reset();
      ref.read(readingTimerProvider.notifier).reset();
    });
    _startReadingTimer();
  }

  Future<void> _loadCompletedActivities() async {
    // 1. Reset state first to prevent stale data from previous chapters
    ref.read(inlineActivityStateProvider.notifier).reset();

    // 2. Invalidate cached provider to force fresh fetch from DB
    ref.invalidate(completedInlineActivitiesProvider(widget.chapterId));

    // 3. Fetch fresh data from database
    final completedResult = await ref.read(
      completedInlineActivitiesProvider(widget.chapterId).future,
    );

    // 4. Load completed activities into state
    ref.read(inlineActivityStateProvider.notifier).loadFromList(completedResult);
  }

  Future<void> _updateCurrentChapter() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final bookRepo = ref.read(bookRepositoryProvider);
    await bookRepo.updateCurrentChapter(
      userId: userId,
      bookId: widget.bookId,
      chapterId: widget.chapterId,
    );
  }

  @override
  void dispose() {
    _readingTimer?.cancel();
    _saveReadingTime();
    super.dispose();
  }

  Future<void> _saveReadingTime() async {
    final readingTime = ref.read(readingTimerProvider);
    if (readingTime <= 0) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final useCase = ref.read(saveReadingProgressUseCaseProvider);
    await useCase(SaveReadingProgressParams(
      userId: userId,
      bookId: widget.bookId,
      chapterId: widget.chapterId,
      additionalReadingTime: readingTime,
    ),);
  }

  @override
  void didUpdateWidget(ReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Handle chapter change (deferred to avoid provider modification during build)
    if (oldWidget.chapterId != widget.chapterId) {
      Future.microtask(() async {
        // Save reading time before switching chapters
        await _saveReadingTime();
        _loadCompletedActivities();
        _updateCurrentChapter();
        ref.read(sessionXPProvider.notifier).reset();
        ref.read(readingTimerProvider.notifier).reset();
      });
    }
  }

  void _startReadingTimer() {
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      ref.read(readingTimerProvider.notifier).tick();

      // Save reading time every 30 seconds to prevent data loss
      final seconds = ref.read(readingTimerProvider);
      if (seconds > 0 && seconds % 30 == 0) {
        _saveReadingTime();
        // Reset timer after saving to avoid double-counting
        ref.read(readingTimerProvider.notifier).reset();
      }
    });
  }

  void _onVocabularyTap(vocab, Offset position) {
    ref.read(selectedVocabularyProvider.notifier).state = vocab;
    ref.read(vocabularyPopupPositionProvider.notifier).state = position;
  }

  void _closeVocabularyPopup() {
    ref.read(selectedVocabularyProvider.notifier).state = null;
    ref.read(vocabularyPopupPositionProvider.notifier).state = null;
  }

  Future<void> _addWordToVocabulary(String word) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final vocabRepo = ref.read(vocabularyRepositoryProvider);

    // Search for the word to get its ID
    final searchResult = await vocabRepo.searchWords(word);
    final wordData = searchResult.fold(
      (failure) => null,
      (words) => words.isNotEmpty ? words.first : null,
    );

    if (wordData == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not find "$word" in vocabulary database'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Add to user's vocabulary
    final result = await vocabRepo.addWordToVocabulary(
      userId: userId,
      wordId: wordData.id,
    );

    if (mounted) {
      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add "$word": ${failure.message}'),
              backgroundColor: Colors.red,
            ),
          );
        },
        (progress) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added "$word" to your vocabulary'),
              backgroundColor: Colors.green,
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapterAsync = ref.watch(chapterByIdProvider(widget.chapterId));
    final chaptersAsync = ref.watch(chaptersProvider(widget.bookId));
    final bookAsync = ref.watch(bookByIdProvider(widget.bookId));
    final settings = ref.watch(readerSettingsProvider);
    final activityProgress = ref.watch(activityProgressProvider);
    final isChapterComplete = ref.watch(isChapterCompleteProvider);
    final selectedVocab = ref.watch(selectedVocabularyProvider);
    final popupPosition = ref.watch(vocabularyPopupPositionProvider);
    final sessionXP = ref.watch(sessionXPProvider);
    final readingTime = ref.watch(readingTimerProvider);

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

        final book = bookAsync.valueOrNull;
        if (book == null) {
          return Scaffold(
            backgroundColor: settings.theme.background,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final chapters = chaptersAsync.valueOrNull ?? [];
        final currentIndex = chapters.indexWhere((c) => c.id == widget.chapterId);
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

        return Scaffold(
          backgroundColor: settings.theme.background,
          body: Stack(
            children: [
              // Main scrollable content with collapsible header
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
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
                      expandedHeight: 400,
                      collapsedHeight: 100,
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
                        onClose: () async {
                          await _saveReadingTime();
                          if (context.mounted) {
                            context.go('/library/book/${widget.bookId}');
                          }
                        },
                        onSettingsTap: () => ReaderSettingsSheet.show(context),
                      ),
                    ),

                    // Chapter content
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Chapter content with inline activities
                            // Key ensures widget recreates when chapter changes,
                            // resetting internal state like _previousCompletedCount
                            if (chapter.content != null)
                              IntegratedReaderContent(
                                key: ValueKey(chapter.id),
                                chapter: chapter,
                                settings: settings,
                                onVocabularyTap: _onVocabularyTap,
                                scrollController: null,
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

                            // Chapter completion actions (only visible when all activities done)
                            if (chapter.content != null && isChapterComplete)
                              Center(
                                child: Column(
                                  children: [
                                    // Next chapter button
                                    if (hasNextChapter && nextChapter != null) ...[
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            // Save reading time before navigating
                                            await _saveReadingTime();
                                            // Mark current chapter as complete
                                            await ref.read(chapterCompletionProvider.notifier).markComplete(
                                              bookId: widget.bookId,
                                              chapterId: widget.chapterId,
                                            );
                                            if (context.mounted) {
                                              context.go('/reader/${widget.bookId}/${nextChapter.id}');
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFE53935),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
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
                                                      nextChapter.title,
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
                                      ),
                                    ],

                                    // Book complete indicator (last chapter)
                                    if (!hasNextChapter) ...[
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF38A169).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFF38A169).withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            const Icon(
                                              Icons.celebration,
                                              size: 40,
                                              color: Color(0xFF38A169),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Book Completed! 🎉',
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
                                                color: Color(0xFF38A169),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      OutlinedButton(
                                        onPressed: () async {
                                          // Save reading time before navigating
                                          await _saveReadingTime();
                                          // Mark chapter as complete
                                          await ref.read(chapterCompletionProvider.notifier).markComplete(
                                            bookId: widget.bookId,
                                            chapterId: widget.chapterId,
                                          );
                                          if (context.mounted) {
                                            context.go('/library/book/${widget.bookId}');
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: settings.theme.text,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          side: BorderSide(
                                            color: settings.theme.text.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: const Text('Back to Book Details'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
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
                    _addWordToVocabulary(selectedVocab.word);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
