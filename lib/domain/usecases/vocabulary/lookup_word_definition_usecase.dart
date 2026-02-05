import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/word_definition.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class LookupWordDefinitionParams {
  const LookupWordDefinitionParams({required this.word});
  final String word;
}

/// Use case to look up a word definition for the word-tap popup.
/// Searches the vocabulary_words database and returns ALL meanings for the word.
/// Returns WordDefinition with source indicating where it was found.
class LookupWordDefinitionUseCase
    implements UseCase<WordDefinition, LookupWordDefinitionParams> {
  const LookupWordDefinitionUseCase(this._repository);
  final VocabularyRepository _repository;

  @override
  Future<Either<Failure, WordDefinition>> call(
    LookupWordDefinitionParams params,
  ) async {
    // Clean the word (remove punctuation at start/end)
    final cleanWord = _cleanWord(params.word);
    if (cleanWord.isEmpty) {
      return Right(
        WordDefinition(
          word: params.word,
          source: WordDefinitionSource.notFound,
        ),
      );
    }

    // Search database for ALL meanings of this word
    final result = await _repository.getWordsByWord(cleanWord);

    return result.fold(
      (failure) => Left(failure),
      (vocabularyWords) {
        if (vocabularyWords.isEmpty) {
          // Not found - return notFound source
          return Right(
            WordDefinition(
              word: cleanWord,
              source: WordDefinitionSource.notFound,
            ),
          );
        }

        // Found in database - convert to WordMeaning list
        final meanings = vocabularyWords
            .map(
              (vw) => WordMeaning(
                id: vw.id,
                meaningTR: vw.meaningTR,
                meaningEN: vw.meaningEN,
                partOfSpeech: vw.partOfSpeech,
                sourceBookTitle: vw.sourceBookTitle,
                exampleSentence: vw.exampleSentence,
              ),
            )
            .toList();

        return Right(
          WordDefinition(
            word: vocabularyWords.first.word,
            meanings: meanings,
            phonetic: vocabularyWords.first.phonetic,
            audioUrl: vocabularyWords.first.audioUrl,
            source: WordDefinitionSource.database,
          ),
        );
      },
    );
  }

  /// Remove leading/trailing punctuation from word
  String _cleanWord(String word) {
    return word
        .replaceAll(RegExp(r'^[^\w]+'), '')
        .replaceAll(RegExp(r'[^\w]+$'), '')
        .trim();
  }
}
