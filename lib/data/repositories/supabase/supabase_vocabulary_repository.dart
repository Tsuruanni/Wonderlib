import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/vocabulary.dart';
import '../../../domain/repositories/vocabulary_repository.dart';

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
          (response as List).map((json) => _mapToVocabularyWord(json)).toList();

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

      return Right(_mapToVocabularyWord(response));
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
          (response as List).map((json) => _mapToVocabularyWord(json)).toList();

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
          .map((json) => _mapToVocabularyProgress(json))
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

      return Right(_mapToVocabularyProgress(response));
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
        'status': _statusToString(progress.status),
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

      return Right(_mapToVocabularyProgress(response));
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
          .map((json) => _mapToVocabularyWord(json))
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
        // Exclude already started words
        for (final wordId in existingWordIds) {
          query = query.neq('id', wordId);
        }
      }

      final wordsResponse = await query.limit(limit).order('level');

      final words = (wordsResponse as List)
          .map((json) => _mapToVocabularyWord(json))
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
            break;
          case 'learning':
            learningCount++;
            break;
          case 'reviewing':
            reviewingCount++;
            break;
          case 'mastered':
            masteredCount++;
            break;
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

  // ============================================
  // MAPPING FUNCTIONS
  // ============================================

  VocabularyWord _mapToVocabularyWord(Map<String, dynamic> data) {
    final examplesJson = data['example_sentences'] as List<dynamic>?;
    final examples =
        examplesJson?.map((e) => e as String).toList() ?? [];

    final categoriesJson = data['categories'] as List<dynamic>?;
    final categories =
        categoriesJson?.map((c) => c as String).toList() ?? [];

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

  VocabularyProgress _mapToVocabularyProgress(Map<String, dynamic> data) {
    return VocabularyProgress(
      id: data['id'] as String,
      userId: data['user_id'] as String,
      wordId: data['word_id'] as String,
      status: _parseStatus(data['status'] as String?),
      easeFactor: (data['ease_factor'] as num?)?.toDouble() ?? 2.5,
      intervalDays: data['interval_days'] as int? ?? 0,
      repetitions: data['repetitions'] as int? ?? 0,
      nextReviewAt: data['next_review_at'] != null
          ? DateTime.parse(data['next_review_at'] as String)
          : null,
      lastReviewedAt: data['last_reviewed_at'] != null
          ? DateTime.parse(data['last_reviewed_at'] as String)
          : null,
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }

  VocabularyStatus _parseStatus(String? status) {
    switch (status) {
      case 'new_word':
        return VocabularyStatus.newWord;
      case 'learning':
        return VocabularyStatus.learning;
      case 'reviewing':
        return VocabularyStatus.reviewing;
      case 'mastered':
        return VocabularyStatus.mastered;
      default:
        return VocabularyStatus.newWord;
    }
  }

  String _statusToString(VocabularyStatus status) {
    switch (status) {
      case VocabularyStatus.newWord:
        return 'new_word';
      case VocabularyStatus.learning:
        return 'learning';
      case VocabularyStatus.reviewing:
        return 'reviewing';
      case VocabularyStatus.mastered:
        return 'mastered';
    }
  }
}
