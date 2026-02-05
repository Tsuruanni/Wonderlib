import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/activity.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/repositories/book_repository.dart';
import '../../models/activity/inline_activity_model.dart';
import '../../models/book/book_model.dart';
import '../../models/book/chapter_model.dart';
import '../../models/book/reading_progress_model.dart';

class SupabaseBookRepository implements BookRepository {
  SupabaseBookRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, List<Book>>> getBooks({
    String? level,
    String? genre,
    String? ageGroup,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      var query = _supabase.from('books').select().eq('status', 'published');

      if (level != null) query = query.eq('level', level);
      if (genre != null) query = query.eq('genre', genre);
      if (ageGroup != null) query = query.eq('age_group', ageGroup);

      final offset = (page - 1) * pageSize;
      final response = await query
          .range(offset, offset + pageSize - 1)
          .order('created_at', ascending: false);

      final books =
          (response as List).map((json) => _mapToBook(json)).toList();

      return Right(books);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Book>> getBookById(String id) async {
    try {
      final response =
          await _supabase.from('books').select().eq('id', id).single();

      return Right(_mapToBook(response));
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return const Left(NotFoundFailure('Book not found'));
      }
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Book>>> searchBooks(String query) async {
    try {
      final response = await _supabase
          .from('books')
          .select()
          .eq('status', 'published')
          .or('title.ilike.%$query%,description.ilike.%$query%')
          .limit(20);

      final books =
          (response as List).map((json) => _mapToBook(json)).toList();

      return Right(books);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Book>>> getRecommendedBooks(String userId) async {
    try {
      // Get books the user hasn't started reading
      final progressResponse = await _supabase
          .from('reading_progress')
          .select('book_id')
          .eq('user_id', userId);

      final readBookIds = (progressResponse as List)
          .map((p) => p['book_id'] as String)
          .toList();

      var query = _supabase.from('books').select().eq('status', 'published');

      // Exclude books already being read (single filter instead of N loops)
      if (readBookIds.isNotEmpty) {
        query = query.not('id', 'in', '(${readBookIds.join(',')})');
      }

      final response = await query.limit(6).order('created_at', ascending: false);

      final books =
          (response as List).map((json) => _mapToBook(json)).toList();

      return Right(books);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Chapter>>> getChapters(String bookId) async {
    try {
      final response = await _supabase
          .from('chapters')
          .select()
          .eq('book_id', bookId)
          .order('order_index', ascending: true);

      final chapters =
          (response as List).map((json) => _mapToChapter(json)).toList();

      return Right(chapters);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Chapter>> getChapterById(String chapterId) async {
    try {
      final response = await _supabase
          .from('chapters')
          .select()
          .eq('id', chapterId)
          .single();

      return Right(_mapToChapter(response));
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return const Left(NotFoundFailure('Chapter not found'));
      }
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ReadingProgress>> getReadingProgress({
    required String userId,
    required String bookId,
  }) async {
    try {
      final response = await _supabase
          .from('reading_progress')
          .select()
          .eq('user_id', userId)
          .eq('book_id', bookId)
          .maybeSingle();

      if (response == null) {
        // Create new progress if doesn't exist
        final now = DateTime.now();
        final newProgress = ReadingProgress(
          id: 'new-${now.millisecondsSinceEpoch}',
          userId: userId,
          bookId: bookId,
          startedAt: now,
          updatedAt: now,
        );
        return Right(newProgress);
      }

      return Right(_mapToReadingProgress(response));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ReadingProgress>> updateReadingProgress(
    ReadingProgress progress,
  ) async {
    try {
      final data = {
        'user_id': progress.userId,
        'book_id': progress.bookId,
        'chapter_id': progress.chapterId,
        'current_page': progress.currentPage,
        'is_completed': progress.isCompleted,
        'completion_percentage': progress.completionPercentage,
        'total_reading_time': progress.totalReadingTime,
        'completed_chapter_ids': progress.completedChapterIds,
        'completed_at': progress.completedAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Check if progress exists
      final existing = await _supabase
          .from('reading_progress')
          .select('id')
          .eq('user_id', progress.userId)
          .eq('book_id', progress.bookId)
          .maybeSingle();

      Map<String, dynamic> response;

      if (existing != null) {
        // Update existing
        response = await _supabase
            .from('reading_progress')
            .update(data)
            .eq('id', existing['id'])
            .select()
            .single();
      } else {
        // Insert new
        data['started_at'] = progress.startedAt.toIso8601String();
        response =
            await _supabase.from('reading_progress').insert(data).select().single();
      }

      return Right(_mapToReadingProgress(response));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ReadingProgress>>> getUserReadingHistory(
    String userId,
  ) async {
    try {
      final response = await _supabase
          .from('reading_progress')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      final progressList = (response as List)
          .map((json) => _mapToReadingProgress(json))
          .toList();

      return Right(progressList);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Book>>> getContinueReading(String userId) async {
    try {
      // Get in-progress reading (not completed)
      final progressResponse = await _supabase
          .from('reading_progress')
          .select('book_id')
          .eq('user_id', userId)
          .eq('is_completed', false)
          .order('updated_at', ascending: false)
          .limit(5);

      final bookIds = (progressResponse as List)
          .map((p) => p['book_id'] as String)
          .toList();

      if (bookIds.isEmpty) {
        return const Right([]);
      }

      final booksResponse = await _supabase
          .from('books')
          .select()
          .inFilter('id', bookIds);

      final books =
          (booksResponse as List).map((json) => _mapToBook(json)).toList();

      // Sort by the order in bookIds (most recently updated first)
      books.sort((a, b) {
        final aIndex = bookIds.indexOf(a.id);
        final bIndex = bookIds.indexOf(b.id);
        return aIndex.compareTo(bIndex);
      });

      return Right(books);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ReadingProgress>> markChapterComplete({
    required String userId,
    required String bookId,
    required String chapterId,
  }) async {
    try {
      // Get current progress
      final progressResult = await getReadingProgress(
        userId: userId,
        bookId: bookId,
      );

      return progressResult.fold(
        (failure) => Left(failure),
        (progress) async {
          // Add chapter to completed list if not already there
          final completedChapters = List<String>.from(progress.completedChapterIds);
          if (!completedChapters.contains(chapterId)) {
            completedChapters.add(chapterId);
          }

          // Get total chapters to calculate completion percentage
          final chaptersResult = await getChapters(bookId);

          return chaptersResult.fold(
            (failure) => Left(failure),
            (chapters) async {
              final totalChapters = chapters.length;
              final completedCount = completedChapters.length;
              final percentage = totalChapters > 0
                  ? (completedCount / totalChapters) * 100
                  : 0.0;
              final isCompleted = completedCount >= totalChapters;

              final updatedProgress = progress.copyWith(
                completedChapterIds: completedChapters,
                completionPercentage: percentage,
                isCompleted: isCompleted,
                completedAt: isCompleted ? DateTime.now() : null,
                updatedAt: DateTime.now(),
              );

              return updateReadingProgress(updatedProgress);
            },
          );
        },
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<InlineActivity>>> getInlineActivities(
    String chapterId,
  ) async {
    try {
      final response = await _supabase
          .from('inline_activities')
          .select()
          .eq('chapter_id', chapterId)
          .order('after_paragraph_index', ascending: true);

      final activities = (response as List)
          .map((json) => _mapToInlineActivity(json))
          .toList();

      return Right(activities);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> saveInlineActivityResult({
    required String userId,
    required String activityId,
    required bool isCorrect,
    required int xpEarned,
  }) async {
    try {
      // Check if already exists - prevents duplicate XP
      final existing = await _supabase
          .from('inline_activity_results')
          .select('id')
          .eq('user_id', userId)
          .eq('inline_activity_id', activityId)
          .maybeSingle();

      if (existing != null) {
        return const Right(false); // Already completed - no XP should be awarded
      }

      // Insert new result
      await _supabase.from('inline_activity_results').insert({
        'user_id': userId,
        'inline_activity_id': activityId,
        'is_correct': isCorrect,
        'xp_earned': xpEarned,
        'answered_at': DateTime.now().toIso8601String(),
      });

      return const Right(true); // New completion - XP can be awarded
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getCompletedInlineActivities({
    required String userId,
    required String chapterId,
  }) async {
    try {
      // Get activity IDs for this chapter
      final activitiesResponse = await _supabase
          .from('inline_activities')
          .select('id')
          .eq('chapter_id', chapterId);

      final activityIds = (activitiesResponse as List)
          .map((a) => a['id'] as String)
          .toList();

      if (activityIds.isEmpty) {
        return const Right([]);
      }

      // Get completed activities for this user
      final resultsResponse = await _supabase
          .from('inline_activity_results')
          .select('inline_activity_id')
          .eq('user_id', userId)
          .inFilter('inline_activity_id', activityIds);

      final completedIds = (resultsResponse as List)
          .map((r) => r['inline_activity_id'] as String)
          .toList();

      return Right(completedIds);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateCurrentChapter({
    required String userId,
    required String bookId,
    required String chapterId,
  }) async {
    try {
      await _supabase.from('reading_progress').upsert(
        {
          'user_id': userId,
          'book_id': bookId,
          'chapter_id': chapterId,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,book_id',
      );
      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Set<String>>> getCompletedBookIds(String userId) async {
    try {
      final response = await _supabase
          .from('reading_progress')
          .select('book_id')
          .eq('user_id', userId)
          .eq('is_completed', true);

      final bookIds = (response as List)
          .map((row) => row['book_id'] as String)
          .toSet();

      return Right(bookIds);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> hasReadToday(String userId) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

      final response = await _supabase
          .from('reading_progress')
          .select('id')
          .eq('user_id', userId)
          .gte('updated_at', todayStart)
          .limit(1);

      return Right((response as List).isNotEmpty);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> getCorrectAnswersTodayCount(String userId) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

      final response = await _supabase
          .from('inline_activity_results')
          .select('id')
          .eq('user_id', userId)
          .eq('is_correct', true)
          .gte('answered_at', todayStart);

      return Right((response as List).length);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> getWordsReadTodayCount(String userId) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

      // Get reading progress updated today
      final progressResponse = await _supabase
          .from('reading_progress')
          .select('completed_chapter_ids')
          .eq('user_id', userId)
          .gte('updated_at', todayStart);

      // Collect all chapter IDs from today's progress
      final chapterIds = <String>[];
      for (final row in progressResponse as List) {
        final ids = (row['completed_chapter_ids'] as List?)?.cast<String>() ?? [];
        chapterIds.addAll(ids);
      }

      if (chapterIds.isEmpty) return const Right(0);

      // Get word counts from chapters
      final chaptersResponse = await _supabase
          .from('chapters')
          .select('word_count')
          .inFilter('id', chapterIds);

      int totalWords = 0;
      for (final row in chaptersResponse as List) {
        totalWords += (row['word_count'] as int?) ?? 0;
      }

      return Right(totalWords);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ============================================
  // MAPPING FUNCTIONS (using Model layer)
  // ============================================

  Book _mapToBook(Map<String, dynamic> data) {
    return BookModel.fromJson(data).toEntity();
  }

  Chapter _mapToChapter(Map<String, dynamic> data) {
    return ChapterModel.fromJson(data).toEntity();
  }

  ReadingProgress _mapToReadingProgress(Map<String, dynamic> data) {
    return ReadingProgressModel.fromJson(data).toEntity();
  }

  InlineActivity _mapToInlineActivity(Map<String, dynamic> data) {
    return InlineActivityModel.fromJson(data).toEntity();
  }
}
