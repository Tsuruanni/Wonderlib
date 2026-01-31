import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/vocabulary.dart';
import '../../../domain/entities/word_list.dart';
import '../../../domain/repositories/word_list_repository.dart';

class SupabaseWordListRepository implements WordListRepository {
  SupabaseWordListRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, List<WordList>>> getAllWordLists({
    WordListCategory? category,
    bool? isSystem,
  }) async {
    try {
      var query = _supabase.from('word_lists').select();

      if (category != null) {
        query = query.eq('category', _categoryToString(category));
      }

      if (isSystem != null) {
        query = query.eq('is_system', isSystem);
      }

      final response = await query.order('name', ascending: true);

      final lists =
          (response as List).map((json) => _mapToWordList(json)).toList();

      return Right(lists);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, WordList>> getWordListById(String id) async {
    try {
      final response =
          await _supabase.from('word_lists').select().eq('id', id).single();

      return Right(_mapToWordList(response));
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return const Left(NotFoundFailure('Word list not found'));
      }
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<VocabularyWord>>> getWordsForList(
    String listId,
  ) async {
    try {
      // Get word IDs from junction table
      final junctionResponse = await _supabase
          .from('word_list_items')
          .select('word_id, order_index')
          .eq('word_list_id', listId)
          .order('order_index', ascending: true);

      final wordIds = (junctionResponse as List)
          .map((j) => j['word_id'] as String)
          .toList();

      if (wordIds.isEmpty) {
        return const Right([]);
      }

      // Get actual words
      final wordsResponse = await _supabase
          .from('vocabulary_words')
          .select()
          .inFilter('id', wordIds);

      final wordsMap = <String, VocabularyWord>{};
      for (final json in (wordsResponse as List)) {
        final word = _mapToVocabularyWord(json);
        wordsMap[word.id] = word;
      }

      // Maintain order from junction table
      final orderedWords = <VocabularyWord>[];
      for (final wordId in wordIds) {
        if (wordsMap.containsKey(wordId)) {
          orderedWords.add(wordsMap[wordId]!);
        }
      }

      return Right(orderedWords);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<UserWordListProgress>>> getUserWordListProgress(
    String userId,
  ) async {
    try {
      final response = await _supabase
          .from('user_word_list_progress')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      final progressList = (response as List)
          .map((json) => _mapToUserWordListProgress(json))
          .toList();

      return Right(progressList);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserWordListProgress?>> getProgressForList({
    required String userId,
    required String listId,
  }) async {
    try {
      final response = await _supabase
          .from('user_word_list_progress')
          .select()
          .eq('user_id', userId)
          .eq('word_list_id', listId)
          .maybeSingle();

      if (response == null) {
        return const Right(null);
      }

      return Right(_mapToUserWordListProgress(response));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserWordListProgress>> updateWordListProgress(
    UserWordListProgress progress,
  ) async {
    try {
      final data = {
        'user_id': progress.userId,
        'word_list_id': progress.wordListId,
        'phase1_complete': progress.phase1Complete,
        'phase2_complete': progress.phase2Complete,
        'phase3_complete': progress.phase3Complete,
        'phase4_complete': progress.phase4Complete,
        'phase4_score': progress.phase4Score,
        'phase4_total': progress.phase4Total,
        'started_at': progress.startedAt?.toIso8601String(),
        'completed_at': progress.completedAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Check if progress exists
      final existing = await _supabase
          .from('user_word_list_progress')
          .select('id')
          .eq('user_id', progress.userId)
          .eq('word_list_id', progress.wordListId)
          .maybeSingle();

      Map<String, dynamic> response;

      if (existing != null) {
        // Update existing
        response = await _supabase
            .from('user_word_list_progress')
            .update(data)
            .eq('id', existing['id'])
            .select()
            .single();
      } else {
        // Insert new
        response = await _supabase
            .from('user_word_list_progress')
            .insert(data)
            .select()
            .single();
      }

      return Right(_mapToUserWordListProgress(response));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserWordListProgress>> completePhase({
    required String userId,
    required String listId,
    required int phase,
    int? score,
    int? total,
  }) async {
    try {
      // Get current progress or create new
      final existingResult = await getProgressForList(
        userId: userId,
        listId: listId,
      );

      return existingResult.fold(
        (failure) => Left(failure),
        (existingProgress) async {
          final now = DateTime.now();

          UserWordListProgress progress;
          if (existingProgress == null) {
            progress = UserWordListProgress(
              id: 'new-${now.millisecondsSinceEpoch}',
              userId: userId,
              wordListId: listId,
              startedAt: now,
              updatedAt: now,
            );
          } else {
            progress = existingProgress;
          }

          // Update the appropriate phase
          switch (phase) {
            case 1:
              progress = progress.copyWith(
                phase1Complete: true,
                updatedAt: now,
              );
              break;
            case 2:
              progress = progress.copyWith(
                phase2Complete: true,
                updatedAt: now,
              );
              break;
            case 3:
              progress = progress.copyWith(
                phase3Complete: true,
                updatedAt: now,
              );
              break;
            case 4:
              progress = progress.copyWith(
                phase4Complete: true,
                phase4Score: score,
                phase4Total: total,
                completedAt: now,
                updatedAt: now,
              );
              break;
          }

          return updateWordListProgress(progress);
        },
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> resetProgress({
    required String userId,
    required String listId,
  }) async {
    try {
      await _supabase
          .from('user_word_list_progress')
          .delete()
          .eq('user_id', userId)
          .eq('word_list_id', listId);

      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ============================================
  // MAPPING FUNCTIONS
  // ============================================

  WordList _mapToWordList(Map<String, dynamic> data) {
    return WordList(
      id: data['id'] as String,
      name: data['name'] as String,
      description: data['description'] as String? ?? '',
      level: data['level'] as String?,
      category: _parseCategory(data['category'] as String?),
      wordCount: data['word_count'] as int? ?? 0,
      coverImageUrl: data['cover_image_url'] as String?,
      isSystem: data['is_system'] as bool? ?? true,
      sourceBookId: data['source_book_id'] as String?,
      createdAt: DateTime.parse(data['created_at'] as String),
      updatedAt: DateTime.parse(data['updated_at'] as String),
    );
  }

  WordListCategory _parseCategory(String? category) {
    switch (category) {
      case 'common_words':
        return WordListCategory.commonWords;
      case 'grade_level':
        return WordListCategory.gradeLevel;
      case 'test_prep':
        return WordListCategory.testPrep;
      case 'thematic':
        return WordListCategory.thematic;
      case 'story_vocab':
        return WordListCategory.storyVocab;
      default:
        return WordListCategory.commonWords;
    }
  }

  String _categoryToString(WordListCategory category) {
    switch (category) {
      case WordListCategory.commonWords:
        return 'common_words';
      case WordListCategory.gradeLevel:
        return 'grade_level';
      case WordListCategory.testPrep:
        return 'test_prep';
      case WordListCategory.thematic:
        return 'thematic';
      case WordListCategory.storyVocab:
        return 'story_vocab';
    }
  }

  UserWordListProgress _mapToUserWordListProgress(Map<String, dynamic> data) {
    return UserWordListProgress(
      id: data['id'] as String,
      userId: data['user_id'] as String,
      wordListId: data['word_list_id'] as String,
      phase1Complete: data['phase1_complete'] as bool? ?? false,
      phase2Complete: data['phase2_complete'] as bool? ?? false,
      phase3Complete: data['phase3_complete'] as bool? ?? false,
      phase4Complete: data['phase4_complete'] as bool? ?? false,
      phase4Score: data['phase4_score'] as int?,
      phase4Total: data['phase4_total'] as int?,
      startedAt: data['started_at'] != null
          ? DateTime.parse(data['started_at'] as String)
          : null,
      completedAt: data['completed_at'] != null
          ? DateTime.parse(data['completed_at'] as String)
          : null,
      updatedAt: DateTime.parse(data['updated_at'] as String),
    );
  }

  VocabularyWord _mapToVocabularyWord(Map<String, dynamic> data) {
    final examplesJson = data['example_sentences'] as List<dynamic>?;
    final examples = examplesJson?.map((e) => e as String).toList() ?? [];

    final categoriesJson = data['categories'] as List<dynamic>?;
    final categories = categoriesJson?.map((c) => c as String).toList() ?? [];

    final synonymsJson = data['synonyms'] as List<dynamic>?;
    final synonyms = synonymsJson?.map((s) => s as String).toList() ?? [];

    final antonymsJson = data['antonyms'] as List<dynamic>?;
    final antonyms = antonymsJson?.map((a) => a as String).toList() ?? [];

    return VocabularyWord(
      id: data['id'] as String,
      word: data['word'] as String,
      phonetic: data['phonetic'] as String?,
      meaningTR: data['meaning_tr'] as String? ?? '',
      meaningEN: data['meaning_en'] as String?,
      exampleSentences: examples,
      audioUrl: data['audio_url'] as String?,
      imageUrl: data['image_url'] as String?,
      level: data['level'] as String?,
      categories: categories,
      synonyms: synonyms,
      antonyms: antonyms,
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }
}
