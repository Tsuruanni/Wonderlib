import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../core/utils/app_clock.dart';
import '../../../domain/entities/student_assignment.dart';
import '../../../domain/repositories/student_assignment_repository.dart';
import '../../models/assignment/student_assignment_model.dart';

class SupabaseStudentAssignmentRepository implements StudentAssignmentRepository {
  SupabaseStudentAssignmentRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, List<StudentAssignment>>> getStudentAssignments(
    String studentId,
  ) async {
    debugPrint('🔍 getStudentAssignments called with studentId: $studentId');
    try {
      final response = await _supabase
          .from(DbTables.assignmentStudents)
          .select('''
            *,
            assignments:assignment_id (
              id,
              title,
              description,
              type,
              content_config,
              start_date,
              due_date,
              teacher_id,
              class_id,
              profiles:teacher_id (first_name, last_name),
              classes:class_id (name)
            )
          ''')
          .eq('student_id', studentId)
          .order('created_at', ascending: false);

      debugPrint('🔍 getStudentAssignments response count: ${(response as List).length}');
      final assignments = <StudentAssignment>[];

      for (final data in response as List) {
        final assignmentData = data['assignments'] as Map<String, dynamic>?;
        if (assignmentData == null) {
          debugPrint('Skipping assignment_student with missing assignment data: ${data['id']}');
          continue;
        }

        try {
          assignments.add(StudentAssignmentModel.fromJson(data).toEntity());
        } catch (e) {
          debugPrint('Error parsing assignment: $e');
          continue;
        }
      }

      return Right(assignments);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<StudentAssignment>>> getActiveAssignments(
    String studentId,
  ) async {
    final result = await getStudentAssignments(studentId);

    return result.map((assignments) {
      final now = DateTime.now();
      return assignments.where((a) {
        // Skip completed assignments
        if (a.status == StudentAssignmentStatus.completed) return false;

        // Skip assignments that haven't started yet
        if (now.isBefore(a.startDate)) return false;

        // Hide overdue assignments that are more than 3 days past due
        if (a.status == StudentAssignmentStatus.overdue) {
          final daysPastDue = now.difference(a.dueDate).inDays;
          if (daysPastDue > 3) return false;
        }

        return true;
      }).toList();
    });
  }

  @override
  Future<Either<Failure, StudentAssignment>> getAssignmentDetail(
    String studentId,
    String assignmentId,
  ) async {
    try {
      final response = await _supabase
          .from(DbTables.assignmentStudents)
          .select('''
            *,
            assignments:assignment_id (
              id,
              title,
              description,
              type,
              content_config,
              start_date,
              due_date,
              teacher_id,
              class_id,
              profiles:teacher_id (first_name, last_name),
              classes:class_id (name)
            )
          ''')
          .eq('student_id', studentId)
          .eq('assignment_id', assignmentId)
          .single();

      final assignmentData = response['assignments'] as Map<String, dynamic>?;
      if (assignmentData == null) {
        return const Left(NotFoundFailure('Assignment not found'));
      }

      return Right(StudentAssignmentModel.fromJson(response).toEntity());
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return const Left(NotFoundFailure('Assignment not found'));
      }
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> startAssignment(
    String studentId,
    String assignmentId,
  ) async {
    try {
      await _supabase
          .from(DbTables.assignmentStudents)
          .update({
            'status': AssignmentStatus.inProgress.dbValue,
            'started_at': AppClock.now().toIso8601String(),
          })
          .eq('student_id', studentId)
          .eq('assignment_id', assignmentId);

      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateAssignmentProgress(
    String studentId,
    String assignmentId,
    double progress,
  ) async {
    try {
      final updateData = <String, dynamic>{
        'progress': progress,
      };

      // If progress > 0 and status is pending, update to in_progress
      final currentData = await _supabase
          .from(DbTables.assignmentStudents)
          .select('status, started_at')
          .eq('student_id', studentId)
          .eq('assignment_id', assignmentId)
          .single();

      if (currentData['status'] == AssignmentStatus.pending.dbValue && progress > 0) {
        updateData['status'] = AssignmentStatus.inProgress.dbValue;
        if (currentData['started_at'] == null) {
          updateData['started_at'] = AppClock.now().toIso8601String();
        }
      }

      await _supabase
          .from(DbTables.assignmentStudents)
          .update(updateData)
          .eq('student_id', studentId)
          .eq('assignment_id', assignmentId);

      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> completeAssignment(
    String studentId,
    String assignmentId,
    double? score,
  ) async {
    try {
      await _supabase
          .from(DbTables.assignmentStudents)
          .update({
            'status': AssignmentStatus.completed.dbValue,
            'progress': 100,
            'score': score,
            'completed_at': AppClock.now().toIso8601String(),
          })
          .eq('student_id', studentId)
          .eq('assignment_id', assignmentId);

      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
