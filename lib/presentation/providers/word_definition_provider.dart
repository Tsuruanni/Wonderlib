import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/word_definition.dart';
import '../../domain/usecases/vocabulary/lookup_word_definition_usecase.dart';
import 'usecase_providers.dart';

// ============================================
// TAPPED WORD STATE
// ============================================

/// The currently tapped word in the reader
final tappedWordProvider = StateProvider<String?>((ref) => null);

/// Position where the word was tapped (for popup positioning)
final tappedWordPositionProvider = StateProvider<Offset?>((ref) => null);

/// Loading state when adding word to vocabulary
final isAddingWordProvider = StateProvider<bool>((ref) => false);

// ============================================
// WORD DEFINITION LOOKUP
// ============================================

/// Look up word definition from database
/// Returns WordDefinition with source indicating where found (database/notFound)
final wordDefinitionProvider = FutureProvider.autoDispose
    .family<WordDefinition?, String>((ref, word) async {
  if (word.isEmpty) return null;

  final useCase = ref.watch(lookupWordDefinitionUseCaseProvider);
  final result = await useCase(LookupWordDefinitionParams(word: word));

  return result.fold(
    (failure) => WordDefinition(
      word: word,
      source: WordDefinitionSource.notFound,
    ),
    (definition) => definition,
  );
});

// ============================================
// DERIVED STATE
// ============================================

/// Whether the word popup should be shown
final showWordPopupProvider = Provider<bool>((ref) {
  final word = ref.watch(tappedWordProvider);
  final position = ref.watch(tappedWordPositionProvider);
  return word != null && position != null;
});

/// Get current tapped word's definition
final currentWordDefinitionProvider = Provider<AsyncValue<WordDefinition?>>((ref) {
  final word = ref.watch(tappedWordProvider);
  if (word == null) return const AsyncValue.data(null);
  return ref.watch(wordDefinitionProvider(word));
});
