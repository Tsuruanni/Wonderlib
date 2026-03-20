import 'package:dartz/dartz.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/learning_path.dart';
import '../../../domain/entities/vocabulary.dart';
import '../../../domain/entities/vocabulary_session.dart';
import '../../../domain/entities/vocabulary_unit.dart';
import '../../../domain/entities/word_list.dart';
import '../../../domain/repositories/word_list_repository.dart';
import '../../models/vocabulary/learning_path_model.dart';
import '../../models/vocabulary/vocabulary_session_model.dart';
import '../../models/vocabulary/vocabulary_unit_model.dart';
import '../../models/vocabulary/vocabulary_word_model.dart';
import '../../models/vocabulary/word_list_model.dart';
import '../../models/vocabulary/word_list_progress_model.dart';

class SupabaseWordListRepository implements WordListRepository {
  SupabaseWordListRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, List<VocabularyUnit>>> getVocabularyUnits() async {
    try {
      final response = await _supabase
          .from(DbTables.vocabularyUnits)
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final units = (response as List)
          .map((json) => VocabularyUnitModel.fromJson(json).toEntity())
          .toList();

      return Right(units);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<VocabularyUnit>>> getAssignedVocabularyUnits(
    String userId,
  ) async {
    try {
      // Call RPC to resolve which units this user can access
      final rpcResponse = await _supabase.rpc(
        RpcFunctions.getAssignedVocabularyUnits,
        params: {'p_user_id': userId},
      );

      final unitIds = (rpcResponse as List)
          .map((row) => row['unit_id'] as String)
          .toList();

      if (unitIds.isEmpty) {
        return const Right([]);
      }

      // Fetch full unit details for the assigned IDs
      final unitsResponse = await _supabase
          .from(DbTables.vocabularyUnits)
          .select()
          .inFilter('id', unitIds)
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final units = (unitsResponse as List)
          .map((json) => VocabularyUnitModel.fromJson(json).toEntity())
          .toList();

      return Right(units);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<WordList>>> getAllWordLists({
    WordListCategory? category,
    bool? isSystem,
  }) async {
    try {
      var query = _supabase.from(DbTables.wordLists).select();

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
          await _supabase.from(DbTables.wordLists).select().eq('id', id).single();

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
          .from(DbTables.wordListItems)
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
          .from(DbTables.vocabularyWords)
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
          .from(DbTables.userWordListProgress)
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
          .from(DbTables.userWordListProgress)
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
        'best_score': progress.bestScore,
        'best_accuracy': progress.bestAccuracy,
        'total_sessions': progress.totalSessions,
        'last_session_at': progress.lastSessionAt?.toIso8601String(),
        'started_at': progress.startedAt?.toIso8601String(),
        'completed_at': progress.completedAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from(DbTables.userWordListProgress)
          .upsert(data, onConflict: 'user_id,word_list_id')
          .select()
          .single();

      return Right(WordListProgressModel.fromJson(response).toEntity());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, VocabularySessionResult>> completeSession({
    required String userId,
    required String wordListId,
    required int totalQuestions,
    required int correctCount,
    required int incorrectCount,
    required double accuracy,
    required int maxCombo,
    required int xpEarned,
    required int durationSeconds,
    required int wordsStrong,
    required int wordsWeak,
    required int firstTryPerfectCount,
    required List<SessionWordResult> wordResults,
  }) async {
    try {
      final wordResultsJson = wordResults
          .map((r) => SessionWordResultModel.toRpcJson(r))
          .toList();

      final response = await _supabase.rpc(
        RpcFunctions.completeVocabularySession,
        params: {
          'p_user_id': userId,
          'p_word_list_id': wordListId,
          'p_total_questions': totalQuestions,
          'p_correct_count': correctCount,
          'p_incorrect_count': incorrectCount,
          'p_accuracy': accuracy,
          'p_max_combo': maxCombo,
          'p_xp_earned': xpEarned,
          'p_duration_seconds': durationSeconds,
          'p_words_strong': wordsStrong,
          'p_words_weak': wordsWeak,
          'p_first_try_perfect_count': firstTryPerfectCount,
          'p_word_results': wordResultsJson,
        },
      );

      // RPC returns [{session_id, total_xp}]
      final rpcResult = (response as List).first as Map<String, dynamic>;

      final model = VocabularySessionModel.fromRpcResponse(
        rpcResult: rpcResult,
        userId: userId,
        wordListId: wordListId,
        totalQuestions: totalQuestions,
        correctCount: correctCount,
        incorrectCount: incorrectCount,
        accuracy: accuracy,
        maxCombo: maxCombo,
        durationSeconds: durationSeconds,
        wordsStrong: wordsStrong,
        wordsWeak: wordsWeak,
        firstTryPerfectCount: firstTryPerfectCount,
        wordResults: wordResults,
      );

      return Right(model.toEntity());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<VocabularySessionResult>>> getSessionHistory({
    required String userId,
    required String wordListId,
  }) async {
    try {
      final response = await _supabase
          .from(DbTables.vocabularySessions)
          .select()
          .eq('user_id', userId)
          .eq('word_list_id', wordListId)
          .order('completed_at', ascending: false)
          .limit(10);

      final sessions = (response as List)
          .map((json) => VocabularySessionModel.fromJson(json).toEntity())
          .toList();

      return Right(sessions);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
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
          .from(DbTables.userWordListProgress)
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

  @override
  Future<Either<Failure, List<LearningPath>>> getUserLearningPaths(
    String userId,
  ) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.getUserLearningPaths,
        params: {'p_user_id': userId},
      );
      final rows = List<Map<String, dynamic>>.from(response as List);
      return Right(LearningPathModel.fromRpcRows(rows));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
