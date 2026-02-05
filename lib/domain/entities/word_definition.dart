import 'package:equatable/equatable.dart';

/// Source of the word definition
enum WordDefinitionSource {
  /// Found in vocabulary_words database
  database,
  /// Retrieved from external API
  api,
  /// Word not found in any source
  notFound,
}

/// Single meaning entry for a word (supports multiple meanings per word)
class WordMeaning extends Equatable {
  const WordMeaning({
    required this.id,
    required this.meaningTR,
    this.meaningEN,
    this.partOfSpeech,
    this.sourceBookTitle,
    this.exampleSentence,
  });

  /// ID from vocabulary_words table
  final String id;

  /// Turkish translation/meaning
  final String meaningTR;

  /// English meaning/definition
  final String? meaningEN;

  /// Part of speech (noun, verb, adjective, etc.)
  final String? partOfSpeech;

  /// Book title from which this meaning was extracted
  final String? sourceBookTitle;

  /// Example sentence showing word usage
  final String? exampleSentence;

  @override
  List<Object?> get props => [
        id,
        meaningTR,
        meaningEN,
        partOfSpeech,
        sourceBookTitle,
        exampleSentence,
      ];
}

/// Word definition for the word-tap popup feature.
/// Contains word info, translations, and audio for on-tap display.
/// Supports multiple meanings from different books.
class WordDefinition extends Equatable {
  const WordDefinition({
    required this.word,
    this.meanings = const [],
    this.phonetic,
    this.audioUrl,
    this.source = WordDefinitionSource.notFound,
  });

  /// The word itself (as tapped)
  final String word;

  /// All meanings for this word (from different books/contexts)
  final List<WordMeaning> meanings;

  /// Phonetic pronunciation (IPA format)
  final String? phonetic;

  /// Audio URL for pronunciation
  final String? audioUrl;

  /// Where this definition came from
  final WordDefinitionSource source;

  // ============================================
  // BACKWARD-COMPATIBLE GETTERS (return first meaning)
  // ============================================

  /// ID from vocabulary_words table (first meaning, null if no meanings)
  String? get id => meanings.isNotEmpty ? meanings.first.id : null;

  /// Part of speech (first meaning)
  String? get partOfSpeech =>
      meanings.isNotEmpty ? meanings.first.partOfSpeech : null;

  /// Turkish translation/meaning (first meaning)
  String? get meaningTR => meanings.isNotEmpty ? meanings.first.meaningTR : null;

  /// English meaning/definition (first meaning)
  String? get meaningEN => meanings.isNotEmpty ? meanings.first.meaningEN : null;

  // ============================================
  // COMPUTED PROPERTIES
  // ============================================

  /// Whether audio is available
  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;

  /// Whether a definition is available
  bool get hasDefinition => meanings.isNotEmpty;

  /// Whether the word has multiple different meanings
  bool get hasMultipleMeanings => meanings.length > 1;

  /// Whether the word was found in the database
  bool get isFromDatabase =>
      meanings.isNotEmpty && source == WordDefinitionSource.database;

  /// Whether the word was not found
  bool get isNotFound => source == WordDefinitionSource.notFound;

  @override
  List<Object?> get props => [
        word,
        meanings,
        phonetic,
        audioUrl,
        source,
      ];
}
