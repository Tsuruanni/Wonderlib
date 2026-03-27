import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/constants/reader_constants.dart';
import '../../../core/services/word_pronunciation_service.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/usecases/reading/save_reading_progress_usecase.dart';
import '../../../domain/usecases/reading/update_current_chapter_usecase.dart';
import '../../providers/audio_sync_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../domain/entities/book.dart';
import '../../providers/book_provider.dart';
import '../../providers/book_quiz_provider.dart';
import '../../providers/reader_provider.dart';
import '../../providers/usecase_providers.dart';
import '../../providers/word_definition_provider.dart';
import '../../widgets/reader/reader_audio_controls.dart';
import '../../widgets/reader/reader_body.dart';
import '../../widgets/reader/reader_popups.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.bookId,
    required this.chapterId,
  });

  final String bookId;
  final String chapterId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  Timer? _readingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChapter();
    });
    _startReadingTimer();
  }


  @override
  void dispose() {
    _readingTimer?.cancel();
    _saveReadingTime();
    super.dispose();
  }

  @override
  void didUpdateWidget(ReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapterId != widget.chapterId) {
      Future.microtask(() async {
        _stopCurrentAudio(); // Stop audio before changing chapter
        await _saveReadingTime();
        _initializeChapter();
      });
    }
  }

  /// Stop current audio playback
  void _stopCurrentAudio() {
    try {
      ref.read(audioSyncControllerProvider.notifier).stop();
    } catch (_) {
      // Provider might not be ready, ignore
    }
  }

  void _initializeChapter() {
    // Mark chapter as not initialized until activities are loaded
    ref.read(chapterInitializedProvider.notifier).state = false;
    _loadCompletedActivities();
    _updateCurrentChapter();
    ref.read(sessionXPProvider.notifier).reset();
    ref.read(readingTimerProvider.notifier).reset();
    // Set current chapter ID for word audio playback
    ref.read(currentChapterIdProvider.notifier).state = widget.chapterId;
  }

  Future<void> _loadCompletedActivities() async {
    try {
      ref.read(inlineActivityStateProvider.notifier).reset();
      ref.invalidate(completedInlineActivitiesProvider(widget.chapterId));

      final completedResult = await ref.read(
        completedInlineActivitiesProvider(widget.chapterId).future,
      );

      if (!mounted) return;

      ref.read(inlineActivityStateProvider.notifier).loadFromMap(completedResult);
    } catch (_) {
      // Network/disposed error — proceed with empty completed list
    } finally {
      if (mounted) {
        ref.read(chapterInitializedProvider.notifier).state = true;
      }
    }
  }

  Future<void> _updateCurrentChapter() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final useCase = ref.read(updateCurrentChapterUseCaseProvider);
    await useCase(UpdateCurrentChapterParams(
      userId: userId,
      bookId: widget.bookId,
      chapterId: widget.chapterId,
    ));
  }

  Future<void> _saveReadingTime() async {
    // Capture all values synchronously before any async work
    // This prevents "ref after dispose" errors
    final int readingTime;
    final String? userId;
    final SaveReadingProgressUseCase saveReadingProgressUseCase;

    try {
      readingTime = ref.read(readingTimerProvider);
      if (readingTime <= 0) return;

      userId = ref.read(currentUserIdProvider);
      if (userId == null) return;

      saveReadingProgressUseCase = ref.read(saveReadingProgressUseCaseProvider);
    } catch (_) {
      // Widget might be disposed, ignore
      return;
    }

    await saveReadingProgressUseCase(SaveReadingProgressParams(
      userId: userId,
      bookId: widget.bookId,
      chapterId: widget.chapterId,
      additionalReadingTime: readingTime,
    ));
  }

  void _startReadingTimer() {
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      ref.read(readingTimerProvider.notifier).tick();

      final seconds = ref.read(readingTimerProvider);
      if (seconds > 0 && seconds % ReaderConstants.autoSaveIntervalSeconds == 0) {
        _saveReadingTime().then((_) {
          if (!mounted) return;
          ref.read(readingTimerProvider.notifier).reset();
        });
      }
    });
  }

  void _onVocabularyTap(vocab, Offset position) {
    ref.read(selectedVocabularyProvider.notifier).state = vocab;
    ref.read(vocabularyPopupPositionProvider.notifier).state = position;
  }

  void _onWordTap(String word, Offset position) {
    // Set word info for popup
    ref.read(tappedWordInfoProvider.notifier).state = TappedWordInfo(
      word: word,
      position: position,
    );
    // Keep legacy providers for backward compatibility
    ref.read(tappedWordProvider.notifier).state = word;
    ref.read(tappedWordPositionProvider.notifier).state = position;

    // Speak word using TTS (ducks main audio automatically)
    _speakWord(word);
  }

  Future<void> _speakWord(String word) async {
    try {
      final service = await ref.read(wordPronunciationServiceProvider.future);
      await service.speak(word);
    } catch (_) {
      // TTS service not ready, ignore
    }
  }

  /// Marks the current chapter complete. Called after async gaps so the
  /// autoDispose provider is read fresh each time (avoiding stale refs).
  Future<void> _markCurrentChapterComplete() async {
    try {
      final completionNotifier = ref.read(chapterCompletionProvider.notifier);
      await completionNotifier.markComplete(
        bookId: widget.bookId,
        chapterId: widget.chapterId,
      );
    } catch (e) {
      debugPrint('ChapterCompletionNotifier error: $e');
    }
  }

  Future<void> _handleNextChapter(Chapter nextChapter) async {
    debugPrint('>>> _handleNextChapter called for: ${nextChapter.title}');

    _stopCurrentAudio(); // Stop audio before navigation
    await _saveReadingTime();

    // Check if still mounted after async operation
    if (!mounted) return;

    await _markCurrentChapterComplete();

    if (mounted) {
      context.go(AppRoutes.readerPath(widget.bookId, nextChapter.id));
    }
  }

  Future<void> _handleBackToBook() async {
    _stopCurrentAudio(); // Stop audio before navigation
    await _saveReadingTime();

    // Check if still mounted after async operation
    if (!mounted) return;

    await _markCurrentChapterComplete();

    if (mounted) {
      // Invalidate providers to refresh home screen + book detail data
      ref.invalidate(readingProgressProvider(widget.bookId));
      ref.invalidate(continueReadingProvider);
      ref.invalidate(recommendedBooksProvider);
      context.go(AppRoutes.bookDetailPath(widget.bookId));
    }
  }

  Future<void> _handleTakeQuiz() async {
    _stopCurrentAudio();
    await _saveReadingTime();

    if (!mounted) return;

    await _markCurrentChapterComplete();

    if (mounted) {
      ref.invalidate(readingProgressProvider(widget.bookId));
      ref.invalidate(continueReadingProvider);
      ref.invalidate(recommendedBooksProvider);
      context.push(AppRoutes.bookQuizPath(widget.bookId));
    }
  }

  Future<void> _handleClose() async {
    _stopCurrentAudio(); // Stop audio before navigation
    await _saveReadingTime();
    // Invalidate providers to refresh home screen + book detail data
    ref.invalidate(readingProgressProvider(widget.bookId));
    ref.invalidate(continueReadingProvider);
    ref.invalidate(recommendedBooksProvider);
    if (mounted) {
      context.go(AppRoutes.bookDetailPath(widget.bookId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapterAsync = ref.watch(chapterByIdProvider((bookId: widget.bookId, chapterId: widget.chapterId)));
    final chaptersAsync = ref.watch(chaptersProvider(widget.bookId));
    final bookAsync = ref.watch(bookByIdProvider(widget.bookId));
    final settings = ref.watch(readerSettingsProvider);

    return chapterAsync.when(
      loading: () => _buildLoadingScaffold(settings),
      error: (error, _) => _buildErrorScaffold(settings, error),
      data: (chapter) {
        if (chapter == null) {
          return _buildNotFoundScaffold(settings);
        }

        final book = bookAsync.valueOrNull;
        if (book == null) {
          return _buildLoadingScaffold(settings);
        }

        final chapters = chaptersAsync.valueOrNull ?? [];

        return Scaffold(
          backgroundColor: settings.theme.background,
          body: Stack(
            children: [
              // Main scrollable content
              _ReaderBodyWithQuiz(
                book: book,
                chapter: chapter,
                chapters: chapters,
                settings: settings,
                onVocabularyTap: _onVocabularyTap,
                onWordTap: _onWordTap,
                onClose: _handleClose,
                onNextChapter: _handleNextChapter,
                onBackToBook: _handleBackToBook,
                onTakeQuiz: _handleTakeQuiz,
              ),

              // Popup overlays
              const ReaderPopups(),

              // Floating audio player controls (top center, below collapsed header)
              Positioned(
                left: 0,
                right: 0,
                top: MediaQuery.of(context).padding.top + 44,
                child: ReaderAudioControls(settings: settings),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingScaffold(ReaderSettings settings) {
    return Scaffold(
      backgroundColor: settings.theme.background,
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorScaffold(ReaderSettings settings, Object error) {
    return Scaffold(
      backgroundColor: settings.theme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: settings.theme.text,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Something went wrong loading this chapter.',
              style: TextStyle(color: settings.theme.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundScaffold(ReaderSettings settings) {
    return Scaffold(
      backgroundColor: settings.theme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: settings.theme.text,
      ),
      body: const Center(child: Text('Chapter not found')),
    );
  }
}

/// Wraps [ReaderBody] with quiz provider data.
/// Separated to avoid watching quiz providers at ReaderScreen level.
class _ReaderBodyWithQuiz extends ConsumerWidget {
  const _ReaderBodyWithQuiz({
    required this.book,
    required this.chapter,
    required this.chapters,
    required this.settings,
    required this.onVocabularyTap,
    required this.onWordTap,
    required this.onClose,
    required this.onNextChapter,
    required this.onBackToBook,
    required this.onTakeQuiz,
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
  final VoidCallback onTakeQuiz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasQuiz =
        ref.watch(bookHasQuizProvider(book.id)).valueOrNull ?? false;
    final bestResult =
        ref.watch(bestQuizResultProvider(book.id)).valueOrNull;
    final progress =
        ref.watch(readingProgressProvider(book.id)).valueOrNull;
    final quizPassed = progress?.quizPassed ?? false;

    return ReaderBody(
      book: book,
      chapter: chapter,
      chapters: chapters,
      settings: settings,
      onVocabularyTap: onVocabularyTap,
      onWordTap: onWordTap,
      onClose: onClose,
      onNextChapter: onNextChapter,
      onBackToBook: onBackToBook,
      bookHasQuiz: hasQuiz,
      quizPassed: quizPassed,
      bestQuizScore: bestResult?.percentage,
      onTakeQuiz: onTakeQuiz,
    );
  }
}
