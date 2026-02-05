import 'dart:math';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/user.dart' as domain;
import '../../../domain/repositories/teacher_repository.dart';
import '../../models/assignment/assignment_model.dart';
import '../../models/assignment/assignment_student_model.dart';
import '../../models/teacher/student_book_progress_model.dart';
import '../../models/teacher/student_summary_model.dart';
import '../../models/teacher/teacher_class_model.dart';
import '../../models/teacher/teacher_stats_model.dart';
import '../../models/user/user_model.dart';

class SupabaseTeacherRepository implements TeacherRepository {
  SupabaseTeacherRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, TeacherStats>> getTeacherStats(String teacherId) async {
    try {
      debugPrint('getTeacherStats: fetching for teacherId=$teacherId');

      // Use RPC function to get all stats in single query (eliminates N+1)
      final response = await _supabase.rpc(
        'get_teacher_stats',
        params: {'p_teacher_id': teacherId},
      );

      final data = (response as List).firstOrNull;
      if (data == null) {
        debugPrint('getTeacherStats: no data returned');
        return const Right(TeacherStats(
          totalStudents: 0,
          totalClasses: 0,
          activeAssignments: 0,
          avgProgress: 0,
        ),);
      }

      final stats = TeacherStatsModel.fromJson(data).toEntity();

      debugPrint('getTeacherStats: result = students:${stats.totalStudents}, classes:${stats.totalClasses}, assignments:${stats.activeAssignments}, progress:${stats.avgProgress}');

      return Right(stats);
    } on PostgrestException catch (e) {
      debugPrint('getTeacherStats: PostgrestException = ${e.message}');
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<TeacherClass>>> getClasses(String schoolId) async {
    try {
      debugPrint('getClasses: fetching for schoolId=$schoolId');

      // Use RPC function to get all class stats in single query (eliminates N+1)
      final response = await _supabase.rpc(
        'get_classes_with_stats',
        params: {'p_school_id': schoolId},
      );

      debugPrint('getClasses: response = $response');

      final classes = (response as List)
          .map((data) => TeacherClassModel.fromJson(data).toEntity())
          .toList();

      debugPrint('getClasses: returning ${classes.length} classes');
      return Right(classes);
    } on PostgrestException catch (e) {
      debugPrint('getClasses: PostgrestException = ${e.message}');
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      debugPrint('getClasses: Exception = $e');
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<StudentSummary>>> getClassStudents(String classId) async {
    try {
      // Use RPC function that includes avg_progress (eliminates N+1)
      final response = await _supabase.rpc(
        'get_students_in_class',
        params: {'p_class_id': classId},
      );

      final students = (response as List)
          .map((data) => StudentSummaryModel.fromJson(data).toEntity())
          .toList();

      return Right(students);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, domain.User>> getStudentDetail(String studentId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', studentId)
          .single();

      return Right(UserModel.fromJson(response).toEntity());
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return const Left(NotFoundFailure('Student not found'));
      }
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<StudentBookProgress>>> getStudentProgress(
    String studentId,
  ) async {
    try {
      // Use RPC function that includes chapter counts (eliminates N+1)
      final response = await _supabase.rpc(
        'get_student_progress_with_books',
        params: {'p_student_id': studentId},
      );

      final progressList = (response as List)
          .map((data) => StudentBookProgressModel.fromJson(data).toEntity())
          .toList();

      return Right(progressList);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // =============================================
  // ASSIGNMENT METHODS
  // =============================================

  @override
  Future<Either<Failure, List<Assignment>>> getAssignments(String teacherId) async {
    try {
      // Use RPC function that includes student stats (eliminates N+1)
      final response = await _supabase.rpc(
        'get_assignments_with_stats',
        params: {'p_teacher_id': teacherId},
      );

      final assignments = (response as List)
          .map((data) => AssignmentModel.fromJson(data).toEntity())
          .toList();

      return Right(assignments);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Assignment>> getAssignmentDetail(String assignmentId) async {
    try {
      final response = await _supabase
          .from('assignments')
          .select('''
            *,
            classes:class_id (name)
          ''')
          .eq('id', assignmentId)
          .single();

      // Get student counts
      final studentsResponse = await _supabase
          .from('assignment_students')
          .select('status')
          .eq('assignment_id', assignmentId);

      final studentsList = studentsResponse as List;
      final totalStudents = studentsList.length;
      final completedStudents = studentsList
          .where((s) => s['status'] == 'completed')
          .length;

      return Right(AssignmentModel.fromJson(
        response,
        totalStudents: totalStudents,
        completedStudents: completedStudents,
      ).toEntity(),);
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
  Future<Either<Failure, List<AssignmentStudent>>> getAssignmentStudents(
    String assignmentId,
  ) async {
    try {
      final response = await _supabase
          .from('assignment_students')
          .select('''
            *,
            profiles:student_id (
              first_name,
              last_name,
              avatar_url
            )
          ''')
          .eq('assignment_id', assignmentId)
          .order('status', ascending: true);

      final students = <AssignmentStudent>[];

      for (final data in response as List) {
        final profileData = data['profiles'] as Map<String, dynamic>?;
        if (profileData == null) continue;

        students.add(AssignmentStudentModel.fromJson(data).toEntity());
      }

      return Right(students);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Assignment>> createAssignment(
    String teacherId,
    CreateAssignmentData data,
  ) async {
    try {
      // Create the assignment
      final assignmentResponse = await _supabase
          .from('assignments')
          .insert({
            'teacher_id': teacherId,
            'class_id': data.classId,
            'type': data.type.name,
            'title': data.title,
            'description': data.description,
            'content_config': data.contentConfig,
            'start_date': data.startDate.toIso8601String(),
            'due_date': data.dueDate.toIso8601String(),
          })
          .select()
          .single();

      final assignmentId = assignmentResponse['id'] as String;

      // Get students to assign
      List<String> studentIds = [];

      if (data.studentIds != null && data.studentIds!.isNotEmpty) {
        // Specific students selected
        studentIds = data.studentIds!;
      } else if (data.classId != null) {
        // All students in the class
        final studentsResponse = await _supabase
            .from('profiles')
            .select('id')
            .eq('class_id', data.classId!)
            .eq('role', 'student');

        studentIds = (studentsResponse as List)
            .map((s) => s['id'] as String)
            .toList();
      }

      // Create assignment_students entries
      if (studentIds.isNotEmpty) {
        final assignmentStudents = studentIds.map((studentId) => {
          'assignment_id': assignmentId,
          'student_id': studentId,
          'status': 'pending',
          'progress': 0,
        },).toList();

        await _supabase.from('assignment_students').insert(assignmentStudents);
      }

      // Return the created assignment
      return getAssignmentDetail(assignmentId);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAssignment(String assignmentId) async {
    try {
      await _supabase
          .from('assignments')
          .delete()
          .eq('id', assignmentId);

      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // =============================================
  // CLASS MANAGEMENT METHODS
  // =============================================

  @override
  Future<Either<Failure, String>> createClass({
    required String schoolId,
    required String name,
    String? description,
  }) async {
    try {
      final response = await _supabase.from('classes').insert({
        'school_id': schoolId,
        'name': name,
        'description': description,
      }).select('id').single();

      return Right(response['id'] as String);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateStudentClass({
    required String studentId,
    required String newClassId,
  }) async {
    try {
      await _supabase.from('profiles').update({
        'class_id': newClassId,
      }).eq('id', studentId);

      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // =============================================
  // PASSWORD MANAGEMENT METHODS
  // =============================================

  @override
  Future<Either<Failure, void>> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> resetStudentPassword(String studentId) async {
    try {
      // Generate random password
      final newPassword = _generateRandomPassword();

      // Call edge function to set password
      final response = await _supabase.functions.invoke(
        'reset-student-password',
        body: {'studentId': studentId, 'newPassword': newPassword},
      );

      if (response.status != 200) {
        final error = response.data?['error'] as String? ?? 'Failed to reset password';
        return Left(ServerFailure(error));
      }

      return Right(newPassword);
    } on FunctionException catch (e) {
      return Left(ServerFailure(e.details?.toString() ?? e.toString()));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  String _generateRandomPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(10, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
