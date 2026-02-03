import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/reader_constants.dart';
import '../../../core/services/word_pronunciation_service.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/usecases/reading/save_reading_progress_usecase.dart';
import '../../../domain/usecases/reading/update_current_chapter_usecase.dart';
import '../../providers/audio_sync_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/reader_provider.dart';
import '../../providers/usecase_providers.dart';
import '../../providers/word_definition_provider.dart';
import '../../widgets/reader/audio_player_controls.dart';
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

      // Check if still mounted after async operation
      if (!mounted) return;

      ref.read(inlineActivityStateProvider.notifier).loadFromList(completedResult);
      ref.read(chapterInitializedProvider.notifier).state = true;
    } catch (_) {
      // Widget might be disposed, ignore
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
      ref.read(readingTimerProvider.notifier).tick();

      final seconds = ref.read(readingTimerProvider);
      if (seconds > 0 && seconds % ReaderConstants.autoSaveIntervalSeconds == 0) {
        _saveReadingTime().then((_) {
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

  Future<void> _handleNextChapter(Chapter nextChapter) async {
    _stopCurrentAudio(); // Stop audio before navigation
    await _saveReadingTime();
    await ref.read(chapterCompletionProvider.notifier).markComplete(
      bookId: widget.bookId,
      chapterId: widget.chapterId,
    );
    if (mounted) {
      context.go('/reader/${widget.bookId}/${nextChapter.id}');
    }
  }

  Future<void> _handleBackToBook() async {
    _stopCurrentAudio(); // Stop audio before navigation
    await _saveReadingTime();
    await ref.read(chapterCompletionProvider.notifier).markComplete(
      bookId: widget.bookId,
      chapterId: widget.chapterId,
    );
    // Invalidate providers to refresh home screen data
    ref.invalidate(continueReadingProvider);
    ref.invalidate(recommendedBooksProvider);
    if (mounted) {
      context.go('/library/book/${widget.bookId}');
    }
  }

  Future<void> _handleClose() async {
    _stopCurrentAudio(); // Stop audio before navigation
    await _saveReadingTime();
    // Invalidate providers to refresh home screen data
    ref.invalidate(continueReadingProvider);
    ref.invalidate(recommendedBooksProvider);
    if (mounted) {
      context.go('/library/book/${widget.bookId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapterAsync = ref.watch(chapterByIdProvider(widget.chapterId));
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
              ReaderBody(
                book: book,
                chapter: chapter,
                chapters: chapters,
                settings: settings,
                onVocabularyTap: _onVocabularyTap,
                onWordTap: _onWordTap,
                onClose: _handleClose,
                onNextChapter: _handleNextChapter,
                onBackToBook: _handleBackToBook,
              ),

              // Popup overlays
              const ReaderPopups(),

              // Floating audio player controls
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: AudioPlayerControls(settings: settings),
                ),
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
      body: Center(child: Text('Error: $error')),
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
