import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/repositories/student_assignment_repository.dart';

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
          .from('assignment_students')
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
        if (assignmentData == null) continue;

        final teacherData = assignmentData['profiles'] as Map<String, dynamic>?;
        final classData = assignmentData['classes'] as Map<String, dynamic>?;

        String? teacherName;
        if (teacherData != null) {
          final firstName = teacherData['first_name'] as String? ?? '';
          final lastName = teacherData['last_name'] as String? ?? '';
          teacherName = '$firstName $lastName'.trim();
        }

        // Check if overdue
        final dueDate = DateTime.parse(assignmentData['due_date'] as String);
        final statusStr = data['status'] as String? ?? 'pending';
        var status = StudentAssignmentStatus.fromString(statusStr);

        // Auto-update status to overdue if past due date and not completed
        if (status != StudentAssignmentStatus.completed &&
            DateTime.now().isAfter(dueDate)) {
          status = StudentAssignmentStatus.overdue;
        }

        assignments.add(StudentAssignment(
          id: data['id'] as String,
          assignmentId: assignmentData['id'] as String,
          title: assignmentData['title'] as String,
          description: assignmentData['description'] as String?,
          type: StudentAssignmentType.fromString(assignmentData['type'] as String),
          status: status,
          progress: (data['progress'] as num?)?.toDouble() ?? 0,
          score: (data['score'] as num?)?.toDouble(),
          teacherName: teacherName,
          className: classData?['name'] as String?,
          startDate: DateTime.parse(assignmentData['start_date'] as String),
          dueDate: dueDate,
          startedAt: data['started_at'] != null
              ? DateTime.parse(data['started_at'] as String)
              : null,
          completedAt: data['completed_at'] != null
              ? DateTime.parse(data['completed_at'] as String)
              : null,
          contentConfig: (assignmentData['content_config'] as Map<String, dynamic>?) ?? {},
        ));
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
      return assignments.where((a) {
        // Active = not completed and within date range (or overdue)
        return a.status != StudentAssignmentStatus.completed &&
            DateTime.now().isAfter(a.startDate);
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
          .from('assignment_students')
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

      final teacherData = assignmentData['profiles'] as Map<String, dynamic>?;
      final classData = assignmentData['classes'] as Map<String, dynamic>?;

      String? teacherName;
      if (teacherData != null) {
        final firstName = teacherData['first_name'] as String? ?? '';
        final lastName = teacherData['last_name'] as String? ?? '';
        teacherName = '$firstName $lastName'.trim();
      }

      final dueDate = DateTime.parse(assignmentData['due_date'] as String);
      final statusStr = response['status'] as String? ?? 'pending';
      var status = StudentAssignmentStatus.fromString(statusStr);

      if (status != StudentAssignmentStatus.completed &&
          DateTime.now().isAfter(dueDate)) {
        status = StudentAssignmentStatus.overdue;
      }

      return Right(StudentAssignment(
        id: response['id'] as String,
        assignmentId: assignmentData['id'] as String,
        title: assignmentData['title'] as String,
        description: assignmentData['description'] as String?,
        type: StudentAssignmentType.fromString(assignmentData['type'] as String),
        status: status,
        progress: (response['progress'] as num?)?.toDouble() ?? 0,
        score: (response['score'] as num?)?.toDouble(),
        teacherName: teacherName,
        className: classData?['name'] as String?,
        startDate: DateTime.parse(assignmentData['start_date'] as String),
        dueDate: dueDate,
        startedAt: response['started_at'] != null
            ? DateTime.parse(response['started_at'] as String)
            : null,
        completedAt: response['completed_at'] != null
            ? DateTime.parse(response['completed_at'] as String)
            : null,
        contentConfig: (assignmentData['content_config'] as Map<String, dynamic>?) ?? {},
      ));
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
          .from('assignment_students')
          .update({
            'status': 'in_progress',
            'started_at': DateTime.now().toIso8601String(),
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
          .from('assignment_students')
          .select('status, started_at')
          .eq('student_id', studentId)
          .eq('assignment_id', assignmentId)
          .single();

      if (currentData['status'] == 'pending' && progress > 0) {
        updateData['status'] = 'in_progress';
        if (currentData['started_at'] == null) {
          updateData['started_at'] = DateTime.now().toIso8601String();
        }
      }

      await _supabase
          .from('assignment_students')
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
          .from('assignment_students')
          .update({
            'status': 'completed',
            'progress': 100,
            'score': score,
            'completed_at': DateTime.now().toIso8601String(),
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
