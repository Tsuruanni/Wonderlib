import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/entities/user.dart' as domain;
import '../../../domain/repositories/teacher_repository.dart';

class SupabaseTeacherRepository implements TeacherRepository {
  SupabaseTeacherRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, TeacherStats>> getTeacherStats(String teacherId) async {
    try {
      debugPrint('getTeacherStats: fetching for teacherId=$teacherId');

      // Get teacher's school
      final teacherData = await _supabase
          .from('profiles')
          .select('school_id')
          .eq('id', teacherId)
          .single();

      final schoolId = teacherData['school_id'] as String?;
      debugPrint('getTeacherStats: schoolId=$schoolId');

      if (schoolId == null) {
        debugPrint('getTeacherStats: schoolId is null');
        return const Right(TeacherStats(
          totalStudents: 0,
          totalClasses: 0,
          activeAssignments: 0,
          avgProgress: 0,
        ));
      }

      // Count students in school
      final studentsResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('school_id', schoolId)
          .eq('role', 'student');
      final totalStudents = (studentsResponse as List).length;

      // Count classes in school
      final classesResponse = await _supabase
          .from('classes')
          .select('id')
          .eq('school_id', schoolId);
      final totalClasses = (classesResponse as List).length;

      // Count active assignments by this teacher
      final now = DateTime.now().toIso8601String();
      final assignmentsResponse = await _supabase
          .from('assignments')
          .select('id')
          .eq('teacher_id', teacherId)
          .gte('due_date', now);
      final activeAssignments = (assignmentsResponse as List).length;

      // Calculate average progress (from reading_progress)
      double avgProgress = 0;
      if (totalStudents > 0) {
        final studentIds = (studentsResponse as List)
            .map((s) => s['id'] as String)
            .toList();

        if (studentIds.isNotEmpty) {
          final progressResponse = await _supabase
              .from('reading_progress')
              .select('completion_percentage')
              .inFilter('user_id', studentIds);

          final progressList = progressResponse as List;
          if (progressList.isNotEmpty) {
            final total = progressList.fold<double>(
              0,
              (sum, p) => sum + ((p['completion_percentage'] as num?)?.toDouble() ?? 0),
            );
            avgProgress = total / progressList.length;
          }
        }
      }

      debugPrint('getTeacherStats: result = students:$totalStudents, classes:$totalClasses, assignments:$activeAssignments, progress:$avgProgress');

      return Right(TeacherStats(
        totalStudents: totalStudents,
        totalClasses: totalClasses,
        activeAssignments: activeAssignments,
        avgProgress: avgProgress,
      ));
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
      final response = await _supabase
          .from('classes')
          .select()
          .eq('school_id', schoolId)
          .order('name', ascending: true);

      final classes = <TeacherClass>[];

      for (final classData in response as List) {
        final classId = classData['id'] as String;

        // Count students in this class
        final studentsResponse = await _supabase
            .from('profiles')
            .select('id')
            .eq('class_id', classId)
            .eq('role', 'student');
        final studentCount = (studentsResponse as List).length;

        // Calculate average progress for class
        double avgProgress = 0;
        if (studentCount > 0) {
          final studentIds = (studentsResponse as List)
              .map((s) => s['id'] as String)
              .toList();

          final progressResponse = await _supabase
              .from('reading_progress')
              .select('completion_percentage')
              .inFilter('user_id', studentIds);

          final progressList = progressResponse as List;
          if (progressList.isNotEmpty) {
            final total = progressList.fold<double>(
              0,
              (sum, p) => sum + ((p['completion_percentage'] as num?)?.toDouble() ?? 0),
            );
            avgProgress = total / progressList.length;
          }
        }

        classes.add(TeacherClass(
          id: classId,
          name: classData['name'] as String,
          grade: classData['grade'] as int?,
          academicYear: classData['academic_year'] as String?,
          studentCount: studentCount,
          avgProgress: avgProgress,
          createdAt: classData['created_at'] != null
              ? DateTime.parse(classData['created_at'] as String)
              : null,
        ));
      }

      return Right(classes);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<StudentSummary>>> getClassStudents(String classId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('class_id', classId)
          .eq('role', 'student')
          .order('first_name', ascending: true);

      final students = <StudentSummary>[];

      for (final studentData in response as List) {
        final studentId = studentData['id'] as String;

        // Count completed books
        final booksResponse = await _supabase
            .from('reading_progress')
            .select('id')
            .eq('user_id', studentId)
            .eq('is_completed', true);
        final booksRead = (booksResponse as List).length;

        // Calculate average progress
        final progressResponse = await _supabase
            .from('reading_progress')
            .select('completion_percentage')
            .eq('user_id', studentId);

        double avgProgress = 0;
        final progressList = progressResponse as List;
        if (progressList.isNotEmpty) {
          final total = progressList.fold<double>(
            0,
            (sum, p) => sum + ((p['completion_percentage'] as num?)?.toDouble() ?? 0),
          );
          avgProgress = total / progressList.length;
        }

        students.add(StudentSummary(
          id: studentId,
          firstName: studentData['first_name'] as String,
          lastName: studentData['last_name'] as String,
          avatarUrl: studentData['avatar_url'] as String?,
          xp: (studentData['xp'] as int?) ?? 0,
          level: (studentData['level'] as int?) ?? 1,
          currentStreak: (studentData['current_streak'] as int?) ?? 0,
          booksRead: booksRead,
          avgProgress: avgProgress,
        ));
      }

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

      return Right(_mapToUser(response));
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
      final response = await _supabase
          .from('reading_progress')
          .select('''
            *,
            books:book_id (
              id,
              title,
              cover_url
            )
          ''')
          .eq('user_id', studentId)
          .order('updated_at', ascending: false);

      final progressList = <StudentBookProgress>[];

      for (final data in response as List) {
        final bookData = data['books'] as Map<String, dynamic>?;
        if (bookData == null) continue;

        // Get chapter count for this book
        final chaptersResponse = await _supabase
            .from('chapters')
            .select('id')
            .eq('book_id', bookData['id'] as String);
        final totalChapters = (chaptersResponse as List).length;

        final completedChapterIds = data['completed_chapter_ids'] as List?;
        final completedChapters = completedChapterIds?.length ?? 0;

        progressList.add(StudentBookProgress(
          bookId: bookData['id'] as String,
          bookTitle: bookData['title'] as String,
          bookCoverUrl: bookData['cover_url'] as String?,
          completionPercentage:
              (data['completion_percentage'] as num?)?.toDouble() ?? 0,
          totalReadingTime: (data['total_reading_time'] as int?) ?? 0,
          completedChapters: completedChapters,
          totalChapters: totalChapters,
          lastReadAt: data['updated_at'] != null
              ? DateTime.parse(data['updated_at'] as String)
              : null,
        ));
      }

      return Right(progressList);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  domain.User _mapToUser(Map<String, dynamic> data) {
    return domain.User(
      id: data['id'] as String,
      schoolId: data['school_id'] as String? ?? '',
      classId: data['class_id'] as String?,
      role: _parseRole(data['role'] as String?),
      studentNumber: data['student_number'] as String?,
      firstName: data['first_name'] as String,
      lastName: data['last_name'] as String,
      email: data['email'] as String?,
      avatarUrl: data['avatar_url'] as String?,
      xp: (data['xp'] as int?) ?? 0,
      level: (data['level'] as int?) ?? 1,
      currentStreak: (data['current_streak'] as int?) ?? 0,
      longestStreak: (data['longest_streak'] as int?) ?? 0,
      lastActivityDate: data['last_activity_date'] != null
          ? DateTime.parse(data['last_activity_date'] as String)
          : null,
      settings: (data['settings'] as Map<String, dynamic>?) ?? {},
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : DateTime.now(),
      updatedAt: data['updated_at'] != null
          ? DateTime.parse(data['updated_at'] as String)
          : DateTime.now(),
    );
  }

  UserRole _parseRole(String? role) {
    switch (role) {
      case 'teacher':
        return UserRole.teacher;
      case 'head':
        return UserRole.head;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.student;
    }
  }

  // =============================================
  // ASSIGNMENT METHODS
  // =============================================

  @override
  Future<Either<Failure, List<Assignment>>> getAssignments(String teacherId) async {
    try {
      final response = await _supabase
          .from('assignments')
          .select('''
            *,
            classes:class_id (name)
          ''')
          .eq('teacher_id', teacherId)
          .order('due_date', ascending: true);

      final assignments = <Assignment>[];

      for (final data in response as List) {
        final assignmentId = data['id'] as String;

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

        final classData = data['classes'] as Map<String, dynamic>?;

        assignments.add(Assignment(
          id: assignmentId,
          teacherId: data['teacher_id'] as String,
          classId: data['class_id'] as String?,
          className: classData?['name'] as String?,
          type: AssignmentType.fromString(data['type'] as String),
          title: data['title'] as String,
          description: data['description'] as String?,
          contentConfig: (data['content_config'] as Map<String, dynamic>?) ?? {},
          startDate: DateTime.parse(data['start_date'] as String),
          dueDate: DateTime.parse(data['due_date'] as String),
          createdAt: DateTime.parse(data['created_at'] as String),
          totalStudents: totalStudents,
          completedStudents: completedStudents,
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

      final classData = response['classes'] as Map<String, dynamic>?;

      return Right(Assignment(
        id: assignmentId,
        teacherId: response['teacher_id'] as String,
        classId: response['class_id'] as String?,
        className: classData?['name'] as String?,
        type: AssignmentType.fromString(response['type'] as String),
        title: response['title'] as String,
        description: response['description'] as String?,
        contentConfig: (response['content_config'] as Map<String, dynamic>?) ?? {},
        startDate: DateTime.parse(response['start_date'] as String),
        dueDate: DateTime.parse(response['due_date'] as String),
        createdAt: DateTime.parse(response['created_at'] as String),
        totalStudents: totalStudents,
        completedStudents: completedStudents,
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

        final firstName = profileData['first_name'] as String? ?? '';
        final lastName = profileData['last_name'] as String? ?? '';

        students.add(AssignmentStudent(
          id: data['id'] as String,
          studentId: data['student_id'] as String,
          studentName: '$firstName $lastName'.trim(),
          avatarUrl: profileData['avatar_url'] as String?,
          status: AssignmentStatus.fromString(data['status'] as String? ?? 'pending'),
          progress: (data['progress'] as num?)?.toDouble() ?? 0,
          score: (data['score'] as num?)?.toDouble(),
          startedAt: data['started_at'] != null
              ? DateTime.parse(data['started_at'] as String)
              : null,
          completedAt: data['completed_at'] != null
              ? DateTime.parse(data['completed_at'] as String)
              : null,
        ));
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
        }).toList();

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
}
