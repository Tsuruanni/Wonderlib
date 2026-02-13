import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/word_pronunciation_service.dart';
import '../../../domain/entities/chapter.dart';
import '../../providers/reader_provider.dart';
import '../../providers/usecase_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/word_definition_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../../domain/usecases/vocabulary/add_word_to_vocabulary_usecase.dart';
import '../../../domain/usecases/vocabulary/search_words_usecase.dart';
import 'reader_vocab_highlight_popup.dart';
import 'reader_word_tap_popup.dart';

/// Manages vocabulary and word tap popups in the reader screen.
/// Extracts popup logic from the main reader screen for cleaner code.
class ReaderPopups extends ConsumerWidget {
  const ReaderPopups({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedVocab = ref.watch(selectedVocabularyProvider);
    final popupPosition = ref.watch(vocabularyPopupPositionProvider);
    final tappedWord = ref.watch(tappedWordProvider);
    final tappedWordPosition = ref.watch(tappedWordPositionProvider);

    final hasVocabPopup = selectedVocab != null && popupPosition != null;
    final hasWordPopup = tappedWord != null && tappedWordPosition != null;

    // If no popups are active, don't block any taps
    if (!hasVocabPopup && !hasWordPopup) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Vocabulary popup (legacy - for pre-highlighted vocab words)
        if (hasVocabPopup)
          ReaderVocabHighlightPopup(
            vocabulary: selectedVocab,
            position: popupPosition,
            onClose: () => _closeReaderVocabHighlightPopup(ref),
            onAddToVocabulary: () => _addWordToVocabulary(
              context,
              ref,
              selectedVocab.word,
            ),
          ),

        // Word tap popup (new - for any word tap)
        if (hasWordPopup)
          ReaderWordTapPopup(
            word: tappedWord,
            position: tappedWordPosition,
            onClose: () => _closeReaderWordTapPopup(ref),
            onPlayAudio: () => _playWordAudio(ref, tappedWord),
          ),
      ],
    );
  }

  void _closeReaderVocabHighlightPopup(WidgetRef ref) {
    ref.read(selectedVocabularyProvider.notifier).state = null;
    ref.read(vocabularyPopupPositionProvider.notifier).state = null;
  }

  void _closeReaderWordTapPopup(WidgetRef ref) {
    ref.read(tappedWordProvider.notifier).state = null;
    ref.read(tappedWordPositionProvider.notifier).state = null;
    ref.read(tappedWordInfoProvider.notifier).state = null;
  }

  Future<void> _playWordAudio(WidgetRef ref, String word) async {
    try {
      final service = await ref.read(wordPronunciationServiceProvider.future);
      await service.speak(word);
    } catch (_) {
      // TTS service not ready, ignore
    }
  }

  Future<void> _addWordToVocabulary(
    BuildContext context,
    WidgetRef ref,
    String word,
  ) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final searchUseCase = ref.read(searchWordsUseCaseProvider);
    final addWordUseCase = ref.read(addWordToVocabularyUseCaseProvider);

    // Search for the word to get its ID
    final searchResult = await searchUseCase(SearchWordsParams(query: word));
    final wordData = searchResult.fold(
      (failure) => null,
      (words) => words.isNotEmpty ? words.first : null,
    );

    if (wordData == null) {
      if (context.mounted) {
        showAppSnackBar(context, 'Could not find "$word" in vocabulary database', type: SnackBarType.warning);
      }
      return;
    }

    // Add to user's vocabulary (immediate: appears in today's review)
    final result = await addWordUseCase(AddWordToVocabularyParams(
      userId: userId,
      wordId: wordData.id,
      immediate: true,
    ));

    if (context.mounted) {
      result.fold(
        (failure) {
          showAppSnackBar(context, 'Failed to add "$word": ${failure.message}', type: SnackBarType.error);
        },
        (progress) {
          showAppSnackBar(context, 'Added "$word" to your vocabulary', type: SnackBarType.success);
        },
      );
    }
  }
}

/// Helper class for managing popup state from parent widgets
class ReaderPopupController {
  const ReaderPopupController(this._ref);

  final WidgetRef _ref;

  void showReaderVocabHighlightPopup(ChapterVocabulary vocab, Offset position) {
    _ref.read(selectedVocabularyProvider.notifier).state = vocab;
    _ref.read(vocabularyPopupPositionProvider.notifier).state = position;
  }

  void showReaderWordTapPopup(String word, Offset position) {
    _ref.read(tappedWordProvider.notifier).state = word;
    _ref.read(tappedWordPositionProvider.notifier).state = position;
  }

  void closeAll() {
    _ref.read(selectedVocabularyProvider.notifier).state = null;
    _ref.read(vocabularyPopupPositionProvider.notifier).state = null;
    _ref.read(tappedWordProvider.notifier).state = null;
    _ref.read(tappedWordPositionProvider.notifier).state = null;
  }
}
