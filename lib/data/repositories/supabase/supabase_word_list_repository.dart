import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/vocabulary.dart';
import '../../../domain/entities/word_list.dart';
import '../../../domain/repositories/word_list_repository.dart';
import '../../models/vocabulary/vocabulary_word_model.dart';
import '../../models/vocabulary/word_list_model.dart';
import '../../models/vocabulary/word_list_progress_model.dart';

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
        query = query.eq('category', WordListModel.categoryToString(category));
      }

      if (isSystem != null) {
        query = query.eq('is_system', isSystem);
      }

      final response = await query.order('name', ascending: true);

      final lists =
          (response as List).map((json) => WordListModel.fromJson(json).toEntity()).toList();

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

      return Right(WordListModel.fromJson(response).toEntity());
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
        final word = VocabularyWordModel.fromJson(json).toEntity();
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
          .map((json) => WordListProgressModel.fromJson(json).toEntity())
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

      return Right(WordListProgressModel.fromJson(response).toEntity());
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

      return Right(WordListProgressModel.fromJson(response).toEntity());
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

}
