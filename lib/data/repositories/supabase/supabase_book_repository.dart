import 'package:dartz/dartz.dart';
import 'package:owlio_shared/owlio_shared.dart';
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
      var query = _supabase.from(DbTables.books).select().eq('status', BookStatus.published.dbValue);

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
          await _supabase.from(DbTables.books).select().eq('id', id).single();

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
  Future<Either<Failure, List<Book>>> getBooksByIds(List<String> ids) async {
    if (ids.isEmpty) return const Right([]);
    try {
      final response = await _supabase
          .from(DbTables.books)
          .select()
          .inFilter('id', ids)
          .eq('status', BookStatus.published.dbValue);

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
  Future<Either<Failure, List<Book>>> searchBooks(String query) async {
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
          .from(DbTables.books)
          .select()
          .eq('status', BookStatus.published.dbValue)
          .or('title.ilike.%$escapedQuery%,description.ilike.%$escapedQuery%')
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
          .from(DbTables.readingProgress)
          .select('book_id')
          .eq('user_id', userId);

      final readBookIds = (progressResponse as List)
          .map((p) => p['book_id'] as String)
          .toList();

      var query = _supabase.from(DbTables.books).select().eq('status', BookStatus.published.dbValue);

      // Exclude books already being read (single filter instead of N loops)
      if (readBookIds.isNotEmpty) {
        query = query.not('id', 'in_', readBookIds);
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
          .from(DbTables.chapters)
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
          .from(DbTables.chapters)
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
          .from(DbTables.readingProgress)
          .select()
          .eq('user_id', userId)
          .eq('book_id', bookId)
          .maybeSingle();

      if (response == null) {
        // Create new progress using upsert to avoid race conditions
        final now = DateTime.now().toIso8601String();
        final inserted = await _supabase
            .from(DbTables.readingProgress)
            .upsert({
              'user_id': userId,
              'book_id': bookId,
              'current_page': 0,
              'is_completed': false,
              'completion_percentage': 0,
              'total_reading_time': 0,
              'completed_chapter_ids': <String>[],
              'started_at': now,
              'updated_at': now,
            }, onConflict: 'user_id,book_id')
            .select()
            .single();
        return Right(_mapToReadingProgress(inserted));
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

      data['started_at'] = progress.startedAt.toIso8601String();

      final response = await _supabase
          .from(DbTables.readingProgress)
          .upsert(data, onConflict: 'user_id,book_id')
          .select()
          .single();

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
          .from(DbTables.readingProgress)
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
          .from(DbTables.readingProgress)
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
          .from(DbTables.books)
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
      // 1. Get current progress
      final progressResult = await getReadingProgress(
        userId: userId,
        bookId: bookId,
      );

      return progressResult.fold(
        (failure) => Left(failure),
        (progress) async {
          // 2. Add chapter to completed list if not already there
          final completedChapters = List<String>.from(progress.completedChapterIds);
          if (!completedChapters.contains(chapterId)) {
            completedChapters.add(chapterId);
          }

          // 3. Recalculate completion percentage
          final chaptersResult = await getChapters(bookId);

          return chaptersResult.fold(
            (failure) => Left(failure),
            (chapters) async {
              final totalChapters = chapters.length;
              final completedCount = completedChapters.length;
              final percentage = totalChapters > 0
                  ? (completedCount / totalChapters) * 100
                  : 0.0;

              // 4. Update reading_progress (do NOT set is_completed — UseCase handles that)
              final updatedProgress = progress.copyWith(
                completedChapterIds: completedChapters,
                completionPercentage: percentage,
                updatedAt: DateTime.now(),
              );

              final result = await updateReadingProgress(updatedProgress);

              // 5. Log for daily tracking (fire-and-forget)
              _logDailyChapterRead(userId, chapterId);

              return result;
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
          .from(DbTables.inlineActivities)
          .select()
          .eq('chapter_id', chapterId)
          .order('after_paragraph_index', ascending: true);

      final activities = (response as List)
          .map((json) => _mapToInlineActivity(json as Map<String, dynamic>))
          .whereType<InlineActivity>()
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
    List<String> wordsLearned = const [],
  }) async {
    try {
      await _supabase.from(DbTables.inlineActivityResults).insert({
        'user_id': userId,
        'inline_activity_id': activityId,
        'is_correct': isCorrect,
        'xp_earned': xpEarned,
        'answered_at': DateTime.now().toIso8601String(),
        'words_learned': wordsLearned,
      });

      return const Right(true);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        return const Right(false);
      }
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, bool>>> getCompletedInlineActivities({
    required String userId,
    required String chapterId,
  }) async {
    try {
      final activitiesResponse = await _supabase
          .from(DbTables.inlineActivities)
          .select('id')
          .eq('chapter_id', chapterId);

      final activityIds = (activitiesResponse as List)
          .map((a) => a['id'] as String)
          .toList();

      if (activityIds.isEmpty) {
        return const Right({});
      }

      final resultsResponse = await _supabase
          .from(DbTables.inlineActivityResults)
          .select('inline_activity_id, is_correct')
          .eq('user_id', userId)
          .inFilter('inline_activity_id', activityIds);

      final completedMap = <String, bool>{};
      for (final r in resultsResponse as List) {
        completedMap[r['inline_activity_id'] as String] = r['is_correct'] as bool? ?? true;
      }

      return Right(completedMap);
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
      await _supabase.from(DbTables.readingProgress).upsert(
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
          .from(DbTables.readingProgress)
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
      final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
      final response = await _supabase
          .from(DbTables.dailyChapterReads)
          .select('id')
          .eq('user_id', userId)
          .eq('read_date', today)
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
          .from(DbTables.inlineActivityResults)
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
      final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD

      // Get chapters read today with their word counts via join
      final response = await _supabase
          .from(DbTables.dailyChapterReads)
          .select('chapters(word_count)')
          .eq('user_id', userId)
          .eq('read_date', today);

      int totalWords = 0;
      for (final row in response as List) {
        final chapterData = row['chapters'] as Map<String, dynamic>?;
        totalWords += (chapterData?['word_count'] as int?) ?? 0;
      }

      return Right(totalWords);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Logs chapter read for daily tracking. Fire-and-forget - failures are swallowed.
  Future<void> _logDailyChapterRead(String userId, String chapterId) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
      await _supabase.from(DbTables.dailyChapterReads).upsert(
        {
          'user_id': userId,
          'chapter_id': chapterId,
          'read_date': today,
        },
        onConflict: 'user_id,chapter_id,read_date',
      );
    } catch (_) {
      // Non-critical - swallow errors. Don't block chapter completion.
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

  InlineActivity? _mapToInlineActivity(Map<String, dynamic> data) {
    return InlineActivityModel.fromJson(data)?.toEntity();
  }
}
