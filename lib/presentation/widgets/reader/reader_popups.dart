import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/chapter.dart';
import '../../providers/reader_provider.dart';
import '../../providers/usecase_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/word_definition_provider.dart';
import '../../../domain/usecases/vocabulary/add_word_to_vocabulary_usecase.dart';
import '../../../domain/usecases/vocabulary/search_words_usecase.dart';
import 'vocabulary_popup.dart';
import 'word_tap_popup.dart';

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

    return Stack(
      children: [
        // Vocabulary popup (legacy - for pre-highlighted vocab words)
        if (selectedVocab != null && popupPosition != null)
          VocabularyPopup(
            vocabulary: selectedVocab,
            position: popupPosition,
            onClose: () => _closeVocabularyPopup(ref),
            onAddToVocabulary: () => _addWordToVocabulary(
              context,
              ref,
              selectedVocab.word,
            ),
          ),

        // Word tap popup (new - for any word tap)
        if (tappedWord != null && tappedWordPosition != null)
          WordTapPopup(
            word: tappedWord,
            position: tappedWordPosition,
            onClose: () => _closeWordTapPopup(ref),
            onPlayAudio: (audioUrl) {
              // TODO: Implement word pronunciation playback
              debugPrint('Play audio: $audioUrl');
            },
          ),
      ],
    );
  }

  void _closeVocabularyPopup(WidgetRef ref) {
    ref.read(selectedVocabularyProvider.notifier).state = null;
    ref.read(vocabularyPopupPositionProvider.notifier).state = null;
  }

  void _closeWordTapPopup(WidgetRef ref) {
    ref.read(tappedWordProvider.notifier).state = null;
    ref.read(tappedWordPositionProvider.notifier).state = null;
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
    final result = await addWordUseCase(AddWordToVocabularyParams(
      userId: userId,
      wordId: wordData.id,
    ));

    if (context.mounted) {
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
}

/// Helper class for managing popup state from parent widgets
class ReaderPopupController {
  const ReaderPopupController(this._ref);

  final WidgetRef _ref;

  void showVocabularyPopup(ChapterVocabulary vocab, Offset position) {
    _ref.read(selectedVocabularyProvider.notifier).state = vocab;
    _ref.read(vocabularyPopupPositionProvider.notifier).state = position;
  }

  void showWordTapPopup(String word, Offset position) {
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
