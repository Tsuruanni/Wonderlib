import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/daily_review_session.dart';
import '../../../domain/entities/vocabulary.dart';
import '../../../domain/repositories/vocabulary_repository.dart';
import '../../models/vocabulary/daily_review_session_model.dart';
import '../../models/vocabulary/vocabulary_progress_model.dart';
import '../../models/vocabulary/vocabulary_word_model.dart';

class SupabaseVocabularyRepository implements VocabularyRepository {
  SupabaseVocabularyRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, List<VocabularyWord>>> getAllWords({
    String? level,
    List<String>? categories,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      var query = _supabase.from('vocabulary_words').select();

      if (level != null) {
        query = query.eq('level', level);
      }

      if (categories != null && categories.isNotEmpty) {
        // Filter by categories (JSONB array contains)
        query = query.contains('categories', categories);
      }

      final offset = (page - 1) * pageSize;
      final response = await query
          .range(offset, offset + pageSize - 1)
          .order('word', ascending: true);

      final words =
          (response as List).map((json) => VocabularyWordModel.fromJson(json).toEntity()).toList();

      return Right(words);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, VocabularyWord>> getWordById(String id) async {
    try {
      final response =
          await _supabase.from('vocabulary_words').select().eq('id', id).single();

      return Right(VocabularyWordModel.fromJson(response).toEntity());
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return const Left(NotFoundFailure('Word not found'));
      }
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<VocabularyWord>>> searchWords(
    String query,
  ) async {
    try {
      final response = await _supabase
          .from('vocabulary_words')
          .select()
          .or('word.ilike.%$query%,meaning_tr.ilike.%$query%')
          .limit(30);

      final words =
          (response as List).map((json) => VocabularyWordModel.fromJson(json).toEntity()).toList();

      return Right(words);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<VocabularyProgress>>> getUserProgress(
    String userId,
  ) async {
    try {
      final response = await _supabase
          .from('vocabulary_progress')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final progressList = (response as List)
          .map((json) => VocabularyProgressModel.fromJson(json).toEntity())
          .toList();

      return Right(progressList);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, VocabularyProgress>> getWordProgress({
    required String userId,
    required String wordId,
  }) async {
    try {
      final response = await _supabase
          .from('vocabulary_progress')
          .select()
          .eq('user_id', userId)
          .eq('word_id', wordId)
          .maybeSingle();

      if (response == null) {
        // Create new progress for this word
        final now = DateTime.now();
        final newProgress = VocabularyProgress(
          id: 'new-${now.millisecondsSinceEpoch}',
          userId: userId,
          wordId: wordId,
          status: VocabularyStatus.newWord,
          createdAt: now,
        );
        return Right(newProgress);
      }

      return Right(VocabularyProgressModel.fromJson(response).toEntity());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, VocabularyProgress>> updateWordProgress(
    VocabularyProgress progress,
  ) async {
    try {
      final data = {
        'user_id': progress.userId,
        'word_id': progress.wordId,
        'status': VocabularyProgressModel.statusToString(progress.status),
        'ease_factor': progress.easeFactor,
        'interval_days': progress.intervalDays,
        'repetitions': progress.repetitions,
        'next_review_at': progress.nextReviewAt?.toIso8601String(),
        'last_reviewed_at': progress.lastReviewedAt?.toIso8601String(),
      };

      // Check if progress exists
      final existing = await _supabase
          .from('vocabulary_progress')
          .select('id')
          .eq('user_id', progress.userId)
          .eq('word_id', progress.wordId)
          .maybeSingle();

      Map<String, dynamic> response;

      if (existing != null) {
        // Update existing
        response = await _supabase
            .from('vocabulary_progress')
            .update(data)
            .eq('id', existing['id'])
            .select()
            .single();
      } else {
        // Insert new
        data['created_at'] = progress.createdAt.toIso8601String();
        response = await _supabase
            .from('vocabulary_progress')
            .insert(data)
            .select()
            .single();
      }

      return Right(VocabularyProgressModel.fromJson(response).toEntity());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<VocabularyWord>>> getDueForReview(
    String userId,
  ) async {
    try {
      final now = DateTime.now().toIso8601String();

      // Get word IDs that are due for review
      final progressResponse = await _supabase
          .from('vocabulary_progress')
          .select('word_id')
          .eq('user_id', userId)
          .lte('next_review_at', now)
          .neq('status', 'mastered')
          .limit(20);

      final wordIds = (progressResponse as List)
          .map((p) => p['word_id'] as String)
          .toList();

      if (wordIds.isEmpty) {
        return const Right([]);
      }

      // Get the actual words
      final wordsResponse = await _supabase
          .from('vocabulary_words')
          .select()
          .inFilter('id', wordIds);

      final words = (wordsResponse as List)
          .map((json) => VocabularyWordModel.fromJson(json).toEntity())
          .toList();

      return Right(words);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<VocabularyWord>>> getNewWords({
    required String userId,
    int limit = 10,
  }) async {
    try {
      // Get word IDs user already has progress on
      final progressResponse = await _supabase
          .from('vocabulary_progress')
          .select('word_id')
          .eq('user_id', userId);

      final existingWordIds = (progressResponse as List)
          .map((p) => p['word_id'] as String)
          .toList();

      // Get words user hasn't started
      var query = _supabase.from('vocabulary_words').select();

      if (existingWordIds.isNotEmpty) {
        // Exclude already started words (single query instead of N queries)
        query = query.not('id', 'in', '(${existingWordIds.join(',')})');
      }

      final wordsResponse = await query.limit(limit).order('level');

      final words = (wordsResponse as List)
          .map((json) => VocabularyWordModel.fromJson(json).toEntity())
          .toList();

      return Right(words);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> getVocabularyStats(
    String userId,
  ) async {
    try {
      final response = await _supabase
          .from('vocabulary_progress')
          .select('status')
          .eq('user_id', userId);

      final progressList = response as List;

      int newCount = 0;
      int learningCount = 0;
      int reviewingCount = 0;
      int masteredCount = 0;

      for (final p in progressList) {
        final status = p['status'] as String?;
        switch (status) {
          case 'new_word':
            newCount++;
          case 'learning':
            learningCount++;
          case 'reviewing':
            reviewingCount++;
          case 'mastered':
            masteredCount++;
        }
      }

      // Get due for review count
      final now = DateTime.now().toIso8601String();
      final dueResponse = await _supabase
          .from('vocabulary_progress')
          .select('id')
          .eq('user_id', userId)
          .lte('next_review_at', now)
          .neq('status', 'mastered');

      return Right({
        'total': progressList.length,
        'new': newCount,
        'learning': learningCount,
        'reviewing': reviewingCount,
        'mastered': masteredCount,
        'due_for_review': (dueResponse as List).length,
      });
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, VocabularyProgress>> addWordToVocabulary({
    required String userId,
    required String wordId,
  }) async {
    try {
      // Check if progress already exists
      final existing = await _supabase
          .from('vocabulary_progress')
          .select()
          .eq('user_id', userId)
          .eq('word_id', wordId)
          .maybeSingle();

      if (existing != null) {
        return Right(VocabularyProgressModel.fromJson(existing).toEntity());
      }

      // Create new progress entry
      final now = DateTime.now();
      final data = {
        'user_id': userId,
        'word_id': wordId,
        'status': 'learning',
        'ease_factor': 2.5,
        'interval_days': 1,
        'repetitions': 0,
        'next_review_at': now.add(const Duration(days: 1)).toIso8601String(),
        'last_reviewed_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      };

      final response = await _supabase
          .from('vocabulary_progress')
          .insert(data)
          .select()
          .single();

      return Right(VocabularyProgressModel.fromJson(response).toEntity());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, VocabularyWord?>> getWordByWord(String word) async {
    try {
      final response = await _supabase
          .from('vocabulary_words')
          .select()
          .ilike('word', word)
          .maybeSingle();

      if (response == null) {
        return const Right(null);
      }

      return Right(VocabularyWordModel.fromJson(response).toEntity());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<VocabularyWord>>> getWordsByWord(
    String word,
  ) async {
    try {
      // Query all rows matching this word, with joined book title
      final response = await _supabase
          .from('vocabulary_words')
          .select('*, books:source_book_id(title)')
          .ilike('word', word);

      final words = (response as List)
          .map(
            (json) =>
                VocabularyWordModel.fromJson(json as Map<String, dynamic>)
                    .toEntity(),
          )
          .toList();

      return Right(words);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ============================================================
  // Daily Review Methods
  // ============================================================

  @override
  Future<Either<Failure, DailyReviewSession?>> getTodayReviewSession(
    String userId,
  ) async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;

      final response = await _supabase
          .from('daily_review_sessions')
          .select()
          .eq('user_id', userId)
          .eq('session_date', today)
          .maybeSingle();

      if (response == null) {
        return const Right(null);
      }

      return Right(DailyReviewSessionModel.fromJson(response).toEntity());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, DailyReviewResult>> completeDailyReview({
    required String userId,
    required int wordsReviewed,
    required int correctCount,
    required int incorrectCount,
  }) async {
    try {
      final response = await _supabase.rpc(
        'complete_daily_review',
        params: {
          'p_user_id': userId,
          'p_words_reviewed': wordsReviewed,
          'p_correct_count': correctCount,
          'p_incorrect_count': incorrectCount,
        },
      );

      // RPC returns array with single row
      final data = (response as List).first as Map<String, dynamic>;
      return Right(DailyReviewResultModel.fromJson(data).toEntity());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<VocabularyProgress>>> addWordsToVocabularyBatch({
    required String userId,
    required List<String> wordIds,
  }) async {
    try {
      if (wordIds.isEmpty) {
        return const Right([]);
      }

      final now = DateTime.now();
      final results = <VocabularyProgress>[];

      // Get existing progress to avoid duplicates
      final existingResponse = await _supabase
          .from('vocabulary_progress')
          .select('word_id')
          .eq('user_id', userId)
          .inFilter('word_id', wordIds);

      final existingWordIds = (existingResponse as List)
          .map((e) => e['word_id'] as String)
          .toSet();

      // Filter to only new words
      final newWordIds =
          wordIds.where((id) => !existingWordIds.contains(id)).toList();

      if (newWordIds.isEmpty) {
        return const Right([]);
      }

      // Batch insert new words
      final insertData = newWordIds
          .map((wordId) => {
                'user_id': userId,
                'word_id': wordId,
                'status': 'learning',
                'ease_factor': 2.5,
                'interval_days': 1,
                'repetitions': 0,
                'next_review_at':
                    now.add(const Duration(days: 1)).toIso8601String(),
                'last_reviewed_at': now.toIso8601String(),
                'created_at': now.toIso8601String(),
              })
          .toList();

      final response = await _supabase
          .from('vocabulary_progress')
          .insert(insertData)
          .select();

      for (final json in response as List) {
        results.add(VocabularyProgressModel.fromJson(json).toEntity());
      }

      return Right(results);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
