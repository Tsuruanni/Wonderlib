import 'package:dartz/dartz.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/book_quiz.dart';
import '../../../domain/repositories/book_quiz_repository.dart';
import '../../models/book_quiz/book_quiz_model.dart';
import '../../models/book_quiz/book_quiz_result_model.dart';
import '../../models/book_quiz/student_quiz_progress_model.dart';

class SupabaseBookQuizRepository implements BookQuizRepository {
  SupabaseBookQuizRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, BookQuiz?>> getQuizForBook(String bookId) async {
    try {
      final response = await _supabase
          .from(DbTables.bookQuizzes)
          .select('*, book_quiz_questions(*)')
          .eq('book_id', bookId)
          .maybeSingle();

      if (response == null) return const Right(null);

      return Right(BookQuizModel.fromJson(response).toEntity());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> bookHasQuiz(String bookId) async {
    try {
      final result = await _supabase.rpc(
        RpcFunctions.bookHasQuiz,
        params: {'p_book_id': bookId},
      );
      return Right(result == true);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BookQuizResult>> submitQuizResult(
    BookQuizResult result,
  ) async {
    try {
      // Insert result (attempt_number set by DB trigger)
      final model = BookQuizResultModel.fromEntity(result);
      final insertData = model.toInsertJson();

      final response = await _supabase
          .from(DbTables.bookQuizResults)
          .insert(insertData)
          .select()
          .single();

      final savedResult = BookQuizResultModel.fromJson(response).toEntity();

      return Right(savedResult);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BookQuizResult?>> getBestResult({
    required String userId,
    required String bookId,
  }) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.getBestBookQuizResult,
        params: {'p_user_id': userId, 'p_book_id': bookId},
      );

      if (response == null || (response is List && response.isEmpty)) {
        return const Right(null);
      }

      final data = response is List ? response.first : response;
      // RPC returns different column names, map to model format
      final mapped = <String, dynamic>{
        'id': data['result_id'],
        'user_id': userId,
        'quiz_id': data['quiz_id'],
        'book_id': bookId,
        'score': data['score'],
        'max_score': data['max_score'],
        'percentage': data['percentage'],
        'is_passing': data['is_passing'],
        'answers': <String, dynamic>{},
        'time_spent': data['time_spent'],
        'attempt_number': data['attempt_number'],
        'completed_at': data['completed_at'],
      };

      return Right(BookQuizResultModel.fromJson(mapped).toEntity());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<BookQuizResult>>> getUserQuizResults({
    required String userId,
    required String bookId,
  }) async {
    try {
      final response = await _supabase
          .from(DbTables.bookQuizResults)
          .select()
          .eq('user_id', userId)
          .eq('book_id', bookId)
          .order('completed_at', ascending: false);

      final results = (response as List)
          .map((json) =>
              BookQuizResultModel.fromJson(json as Map<String, dynamic>)
                  .toEntity())
          .toList();

      return Right(results);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<StudentQuizProgress>>> getStudentQuizResults(
    String studentId,
  ) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.getStudentQuizResults,
        params: {'p_student_id': studentId},
      );

      if (response == null) return const Right([]);

      final results = (response as List)
          .map((json) =>
              StudentQuizProgressModel.fromJson(json as Map<String, dynamic>)
                  .toEntity())
          .toList();

      return Right(results);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
