import 'package:dartz/dartz.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/daily_review_session.dart';
import '../../../domain/entities/vocabulary.dart';
import '../../../domain/repositories/vocabulary_repository.dart';
import '../../models/vocabulary/daily_review_session_model.dart';
import '../../models/vocabulary/node_completion_model.dart';
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
      var query = _supabase.from(DbTables.vocabularyWords).select();

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
          await _supabase.from(DbTables.vocabularyWords).select().eq('id', id).single();

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
  Future<Either<Failure, List<VocabularyWord>>> getWordsByIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const Right([]);
    try {
      final response = await _supabase
          .from(DbTables.vocabularyWords)
          .select()
          .inFilter('id', ids);

      final words = (response as List)
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
  Future<Either<Failure, List<VocabularyWord>>> searchWords(
    String query,
  ) async {
    try {
      // Escape special PostgREST filter characters to prevent injection
      final escapedQuery = query
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_')
          .replaceAll(',', '')
          .replaceAll('(', '')
          .replaceAll(')', '');
      final response = await _supabase
          .from(DbTables.vocabularyWords)
          .select()
          .or('word.ilike.%$escapedQuery%,meaning_tr.ilike.%$escapedQuery%')
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
          .from(DbTables.vocabularyProgress)
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
          .from(DbTables.vocabularyProgress)
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
  Future<Either<Failure, List<VocabularyProgress>>> getWordProgressBatch({
    required String userId,
    required List<String> wordIds,
  }) async {
    if (wordIds.isEmpty) return const Right([]);
    try {
      final response = await _supabase
          .from(DbTables.vocabularyProgress)
          .select()
          .eq('user_id', userId)
          .inFilter('word_id', wordIds);

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

      data['created_at'] = progress.createdAt.toIso8601String();

      final response = await _supabase
          .from(DbTables.vocabularyProgress)
          .upsert(data, onConflict: 'user_id,word_id')
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
  Future<Either<Failure, List<VocabularyWord>>> getDueForReview(
    String userId,
  ) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.getDueReviewWords,
        params: {'p_user_id': userId, 'p_limit': 30},
      );

      final words = (response as List)
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
          .from(DbTables.vocabularyProgress)
          .select('word_id')
          .eq('user_id', userId);

      final existingWordIds = (progressResponse as List)
          .map((p) => p['word_id'] as String)
          .toList();

      // Get words user hasn't started
      var query = _supabase.from(DbTables.vocabularyWords).select();

      if (existingWordIds.isNotEmpty) {
        // Exclude already started words (single query instead of N queries)
        query = query.not('id', 'in_', existingWordIds);
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
          .from(DbTables.vocabularyProgress)
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

      // Get due for review count (includes mastered words)
      final now = DateTime.now().toIso8601String();
      final dueResponse = await _supabase
          .from(DbTables.vocabularyProgress)
          .select('id')
          .eq('user_id', userId)
          .lte('next_review_at', now);

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
    bool immediate = false,
  }) async {
    try {
      // Check if progress already exists
      final existing = await _supabase
          .from(DbTables.vocabularyProgress)
          .select()
          .eq('user_id', userId)
          .eq('word_id', wordId)
          .maybeSingle();

      if (existing != null) {
        if (immediate) {
          // User explicitly said "I didn't know this" — reset SM-2 progress
          // so the word re-enters the learning cycle, even if it was mastered.
          final now = DateTime.now();
          final updated = await _supabase
              .from(DbTables.vocabularyProgress)
              .update({
                'next_review_at': now.toIso8601String(),
                'status': 'learning',
                'repetitions': 0,
                'interval_days': 1,
                'ease_factor': 2.5,
              })
              .eq('user_id', userId)
              .eq('word_id', wordId)
              .select()
              .single();
          return Right(VocabularyProgressModel.fromJson(updated).toEntity());
        }
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
        'next_review_at': immediate
            ? now.toIso8601String()
            : now.add(const Duration(days: 1)).toIso8601String(),
        'last_reviewed_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      };

      final response = await _supabase
          .from(DbTables.vocabularyProgress)
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
          .from(DbTables.vocabularyWords)
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
          .from(DbTables.vocabularyWords)
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
          .from(DbTables.dailyReviewSessions)
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
        RpcFunctions.completeDailyReview,
        params: {
          'p_user_id': userId,
          'p_words_reviewed': wordsReviewed,
          'p_correct_count': correctCount,
          'p_incorrect_count': incorrectCount,
        },
      );

      // RPC returns array with single row
      final rows = response as List;
      if (rows.isEmpty) {
        return const Left(ServerFailure('Daily review completion returned empty response'));
      }
      final data = rows.first as Map<String, dynamic>;
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
    bool immediate = false,
  }) async {
    try {
      if (wordIds.isEmpty) {
        return const Right([]);
      }

      final now = DateTime.now();
      final results = <VocabularyProgress>[];

      // Get existing progress to avoid duplicates
      final existingResponse = await _supabase
          .from(DbTables.vocabularyProgress)
          .select('word_id')
          .eq('user_id', userId)
          .inFilter('word_id', wordIds);

      final existingWordIds = (existingResponse as List)
          .map((e) => e['word_id'] as String)
          .toSet();

      // If immediate, reset existing words so they re-enter learning cycle
      if (immediate && existingWordIds.isNotEmpty) {
        await _supabase
            .from(DbTables.vocabularyProgress)
            .update({
              'next_review_at': now.toIso8601String(),
              'status': 'learning',
              'repetitions': 0,
              'interval_days': 1,
              'ease_factor': 2.5,
            })
            .eq('user_id', userId)
            .inFilter('word_id', existingWordIds.toList());
      }

      // Filter to only new words for insertion
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
                'next_review_at': immediate
                    ? now.toIso8601String()
                    : now.add(const Duration(days: 1)).toIso8601String(),
                'last_reviewed_at': now.toIso8601String(),
                'created_at': now.toIso8601String(),
              })
          .toList();

      final response = await _supabase
          .from(DbTables.vocabularyProgress)
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

  @override
  Future<Either<Failure, int>> getWordsLearnedTodayCount(String userId) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

      final response = await _supabase
          .from(DbTables.vocabularyProgress)
          .select('id')
          .eq('user_id', userId)
          .gte('created_at', todayStart);

      return Right((response as List).length);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> getWordsLearnedFromListsTodayCount(String userId) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

      // 1. Get today's learned word IDs (small set - typically <50)
      final todayProgress = await _supabase
          .from(DbTables.vocabularyProgress)
          .select('word_id')
          .eq('user_id', userId)
          .gte('created_at', todayStart);

      final todayWordIds = (todayProgress as List)
          .map((r) => r['word_id'] as String)
          .toList();

      if (todayWordIds.isEmpty) return const Right(0);

      // 2. Check which of today's words belong to any word list
      final listMatches = await _supabase
          .from(DbTables.wordListItems)
          .select('word_id')
          .inFilter('word_id', todayWordIds);

      // Use Set to count unique words (a word may appear in multiple lists)
      final uniqueListWordIds = (listMatches as List)
          .map((r) => r['word_id'] as String)
          .toSet();

      return Right(uniqueListWordIds.length);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ============================================================
  // Path Node Completion Methods
  // ============================================================

  @override
  Future<Either<Failure, List<NodeCompletion>>> getNodeCompletions(
    String userId,
  ) async {
    try {
      final response = await _supabase
          .from(DbTables.userNodeCompletions)
          .select()
          .eq('user_id', userId);

      final completions = (response as List)
          .map((json) =>
              NodeCompletionModel.fromJson(json as Map<String, dynamic>)
                  .toEntity())
          .toList();

      return Right(completions);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> completeNode({
    required String userId,
    required String unitId,
    required String nodeType,
  }) async {
    try {
      await _supabase.from(DbTables.userNodeCompletions).upsert(
        {
          'user_id': userId,
          'unit_id': unitId,
          'node_type': nodeType,
        },
        onConflict: 'user_id,unit_id,node_type',
      );

      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveDailyReviewPosition({
    required String userId,
    required int pathPosition,
  }) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await _supabase
          .from(DbTables.dailyReviewSessions)
          .update({'path_position': pathPosition})
          .eq('user_id', userId)
          .eq('session_date', today);
      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
