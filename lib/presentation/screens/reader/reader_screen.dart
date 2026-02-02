import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/reader_constants.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/usecases/reading/save_reading_progress_usecase.dart';
import '../../../domain/usecases/reading/update_current_chapter_usecase.dart';
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
        await _saveReadingTime();
        _initializeChapter();
      });
    }
  }

  void _initializeChapter() {
    _loadCompletedActivities();
    _updateCurrentChapter();
    ref.read(sessionXPProvider.notifier).reset();
    ref.read(readingTimerProvider.notifier).reset();
  }

  Future<void> _loadCompletedActivities() async {
    ref.read(inlineActivityStateProvider.notifier).reset();
    ref.invalidate(completedInlineActivitiesProvider(widget.chapterId));

    final completedResult = await ref.read(
      completedInlineActivitiesProvider(widget.chapterId).future,
    );
    ref.read(inlineActivityStateProvider.notifier).loadFromList(completedResult);
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
    ref.read(tappedWordProvider.notifier).state = word;
    ref.read(tappedWordPositionProvider.notifier).state = position;
  }

  Future<void> _handleNextChapter(Chapter nextChapter) async {
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
    await _saveReadingTime();
    await ref.read(chapterCompletionProvider.notifier).markComplete(
      bookId: widget.bookId,
      chapterId: widget.chapterId,
    );
    if (mounted) {
      context.go('/library/book/${widget.bookId}');
    }
  }

  Future<void> _handleClose() async {
    await _saveReadingTime();
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
