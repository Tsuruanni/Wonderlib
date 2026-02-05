import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:readeng/core/errors/failures.dart';
import 'package:readeng/domain/repositories/teacher_repository.dart';
import 'package:readeng/domain/usecases/teacher/change_student_class_usecase.dart';
import 'package:readeng/domain/usecases/teacher/create_class_usecase.dart';
import 'package:readeng/domain/usecases/teacher/get_class_students_usecase.dart';
import 'package:readeng/domain/usecases/teacher/get_classes_usecase.dart';
import 'package:readeng/domain/usecases/teacher/get_student_detail_usecase.dart';
import 'package:readeng/domain/usecases/teacher/get_student_progress_usecase.dart';
import 'package:readeng/domain/usecases/teacher/get_teacher_stats_usecase.dart';
import 'package:readeng/domain/usecases/teacher/reset_student_password_usecase.dart';
import 'package:readeng/domain/usecases/teacher/send_password_reset_email_usecase.dart';

import '../../../../fixtures/teacher_fixtures.dart';
import '../../../../fixtures/user_fixtures.dart';

import 'teacher_usecases_test.mocks.dart';

@GenerateMocks([TeacherRepository])
void main() {
  late MockTeacherRepository mockRepository;

  setUp(() {
    mockRepository = MockTeacherRepository();
  });

  // ============================================
  // GetTeacherStatsUseCase Tests
  // ============================================
  group('GetTeacherStatsUseCase', () {
    late GetTeacherStatsUseCase useCase;

    setUp(() {
      useCase = GetTeacherStatsUseCase(mockRepository);
    });

    test('shouldReturnTeacherStats_whenRepositorySucceeds', () async {
      // Arrange
      final stats = TeacherStatsFixtures.validStats();
      when(mockRepository.getTeacherStats('teacher-123'))
          .thenAnswer((_) async => Right(stats));

      // Act
      final result = await useCase(
        const GetTeacherStatsParams(teacherId: 'teacher-123'),
      );

      // Assert
      expect(result, Right(stats));
      verify(mockRepository.getTeacherStats('teacher-123')).called(1);
    });

    test('shouldReturnEmptyStats_whenTeacherHasNoData', () async {
      // Arrange
      final emptyStats = TeacherStatsFixtures.emptyStats();
      when(mockRepository.getTeacherStats('new-teacher'))
          .thenAnswer((_) async => Right(emptyStats));

      // Act
      final result = await useCase(
        const GetTeacherStatsParams(teacherId: 'new-teacher'),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (stats) {
          expect(stats.totalStudents, 0);
          expect(stats.totalClasses, 0);
          expect(stats.activeAssignments, 0);
          expect(stats.avgProgress, 0.0);
        },
      );
    });

    test('shouldReturnFailure_whenRepositoryFails', () async {
      // Arrange
      when(mockRepository.getTeacherStats('teacher-123'))
          .thenAnswer((_) async => const Left(ServerFailure('Server error')));

      // Act
      final result = await useCase(
        const GetTeacherStatsParams(teacherId: 'teacher-123'),
      );

      // Assert
      expect(result, const Left(ServerFailure('Server error')));
    });
  });

  // ============================================
  // GetClassesUseCase Tests
  // ============================================
  group('GetClassesUseCase', () {
    late GetClassesUseCase useCase;

    setUp(() {
      useCase = GetClassesUseCase(mockRepository);
    });

    test('shouldReturnClasses_whenRepositorySucceeds', () async {
      // Arrange
      final classes = TeacherClassFixtures.classList();
      when(mockRepository.getClasses('school-456'))
          .thenAnswer((_) async => Right(classes));

      // Act
      final result = await useCase(
        const GetClassesParams(schoolId: 'school-456'),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (resultClasses) => expect(resultClasses.length, 3),
      );
      verify(mockRepository.getClasses('school-456')).called(1);
    });

    test('shouldReturnEmptyList_whenNoClassesExist', () async {
      // Arrange
      when(mockRepository.getClasses('empty-school'))
          .thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(
        const GetClassesParams(schoolId: 'empty-school'),
      );

      // Assert
      expect(result, const Right(<TeacherClass>[]));
    });

    test('shouldReturnFailure_whenRepositoryFails', () async {
      // Arrange
      when(mockRepository.getClasses('school-456'))
          .thenAnswer((_) async => const Left(ServerFailure('Database error')));

      // Act
      final result = await useCase(
        const GetClassesParams(schoolId: 'school-456'),
      );

      // Assert
      expect(result, const Left(ServerFailure('Database error')));
    });
  });

  // ============================================
  // GetClassStudentsUseCase Tests
  // ============================================
  group('GetClassStudentsUseCase', () {
    late GetClassStudentsUseCase useCase;

    setUp(() {
      useCase = GetClassStudentsUseCase(mockRepository);
    });

    test('shouldReturnStudents_whenRepositorySucceeds', () async {
      // Arrange
      final students = StudentSummaryFixtures.studentList();
      when(mockRepository.getClassStudents('class-789'))
          .thenAnswer((_) async => Right(students));

      // Act
      final result = await useCase(
        const GetClassStudentsParams(classId: 'class-789'),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (resultStudents) => expect(resultStudents.length, 3),
      );
      verify(mockRepository.getClassStudents('class-789')).called(1);
    });

    test('shouldReturnEmptyList_whenClassHasNoStudents', () async {
      // Arrange
      when(mockRepository.getClassStudents('empty-class'))
          .thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(
        const GetClassStudentsParams(classId: 'empty-class'),
      );

      // Assert
      expect(result, const Right(<StudentSummary>[]));
    });

    test('shouldReturnFailure_whenRepositoryFails', () async {
      // Arrange
      when(mockRepository.getClassStudents('class-789'))
          .thenAnswer((_) async => const Left(NotFoundFailure('Class not found')));

      // Act
      final result = await useCase(
        const GetClassStudentsParams(classId: 'class-789'),
      );

      // Assert
      expect(result, const Left(NotFoundFailure('Class not found')));
    });
  });

  // ============================================
  // GetStudentDetailUseCase Tests
  // ============================================
  group('GetStudentDetailUseCase', () {
    late GetStudentDetailUseCase useCase;

    setUp(() {
      useCase = GetStudentDetailUseCase(mockRepository);
    });

    test('shouldReturnStudentDetail_whenRepositorySucceeds', () async {
      // Arrange
      final student = UserFixtures.validStudentUser();
      when(mockRepository.getStudentDetail('student-123'))
          .thenAnswer((_) async => Right(student));

      // Act
      final result = await useCase(
        const GetStudentDetailParams(studentId: 'student-123'),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (user) {
          expect(user.id, 'user-123');
          expect(user.firstName, 'John');
          expect(user.lastName, 'Doe');
        },
      );
      verify(mockRepository.getStudentDetail('student-123')).called(1);
    });

    test('shouldReturnFailure_whenStudentNotFound', () async {
      // Arrange
      when(mockRepository.getStudentDetail('invalid-id'))
          .thenAnswer((_) async => const Left(NotFoundFailure('Student not found')));

      // Act
      final result = await useCase(
        const GetStudentDetailParams(studentId: 'invalid-id'),
      );

      // Assert
      expect(result, const Left(NotFoundFailure('Student not found')));
    });
  });

  // ============================================
  // GetStudentProgressUseCase Tests
  // ============================================
  group('GetStudentProgressUseCase', () {
    late GetStudentProgressUseCase useCase;

    setUp(() {
      useCase = GetStudentProgressUseCase(mockRepository);
    });

    test('shouldReturnStudentProgress_whenRepositorySucceeds', () async {
      // Arrange
      final progressList = StudentBookProgressFixtures.progressList();
      when(mockRepository.getStudentProgress('student-123'))
          .thenAnswer((_) async => Right(progressList));

      // Act
      final result = await useCase(
        const GetStudentProgressParams(studentId: 'student-123'),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (progress) {
          expect(progress.length, 3);
          expect(progress[0].bookTitle, 'The Great Adventure');
          expect(progress[1].completionPercentage, 100.0);
        },
      );
      verify(mockRepository.getStudentProgress('student-123')).called(1);
    });

    test('shouldReturnEmptyList_whenStudentHasNoProgress', () async {
      // Arrange
      when(mockRepository.getStudentProgress('new-student'))
          .thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(
        const GetStudentProgressParams(studentId: 'new-student'),
      );

      // Assert
      expect(result, const Right(<StudentBookProgress>[]));
    });

    test('shouldReturnFailure_whenRepositoryFails', () async {
      // Arrange
      when(mockRepository.getStudentProgress('student-123'))
          .thenAnswer((_) async => const Left(ServerFailure('Server error')));

      // Act
      final result = await useCase(
        const GetStudentProgressParams(studentId: 'student-123'),
      );

      // Assert
      expect(result, const Left(ServerFailure('Server error')));
    });
  });

  // ============================================
  // CreateClassUseCase Tests
  // ============================================
  group('CreateClassUseCase', () {
    late CreateClassUseCase useCase;

    setUp(() {
      useCase = CreateClassUseCase(mockRepository);
    });

    test('shouldReturnClassId_whenCreatedSuccessfully', () async {
      // Arrange
      when(mockRepository.createClass(
        schoolId: 'school-456',
        name: '8-B',
        description: 'Grade 8 Section B',
      )).thenAnswer((_) async => const Right('new-class-id'));

      // Act
      final result = await useCase(
        const CreateClassParams(
          schoolId: 'school-456',
          name: '8-B',
          description: 'Grade 8 Section B',
        ),
      );

      // Assert
      expect(result, const Right('new-class-id'));
      verify(mockRepository.createClass(
        schoolId: 'school-456',
        name: '8-B',
        description: 'Grade 8 Section B',
      )).called(1);
    });

    test('shouldCreateWithoutDescription_whenNotProvided', () async {
      // Arrange
      when(mockRepository.createClass(
        schoolId: 'school-456',
        name: '9-A',
        description: null,
      )).thenAnswer((_) async => const Right('class-no-desc'));

      // Act
      final result = await useCase(
        const CreateClassParams(
          schoolId: 'school-456',
          name: '9-A',
        ),
      );

      // Assert
      expect(result, const Right('class-no-desc'));
    });

    test('shouldReturnFailure_whenRepositoryFails', () async {
      // Arrange
      when(mockRepository.createClass(
        schoolId: 'school-456',
        name: '8-B',
        description: null,
      )).thenAnswer((_) async => const Left(ServerFailure('Failed to create')));

      // Act
      final result = await useCase(
        const CreateClassParams(
          schoolId: 'school-456',
          name: '8-B',
        ),
      );

      // Assert
      expect(result, const Left(ServerFailure('Failed to create')));
    });
  });

  // ============================================
  // ChangeStudentClassUseCase Tests
  // ============================================
  group('ChangeStudentClassUseCase', () {
    late ChangeStudentClassUseCase useCase;

    setUp(() {
      useCase = ChangeStudentClassUseCase(mockRepository);
    });

    test('shouldReturnSuccess_whenClassChangedSuccessfully', () async {
      // Arrange
      when(mockRepository.updateStudentClass(
        studentId: 'student-123',
        newClassId: 'class-new',
      )).thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(
        const ChangeStudentClassParams(
          studentId: 'student-123',
          newClassId: 'class-new',
        ),
      );

      // Assert
      expect(result.isRight(), true);
      verify(mockRepository.updateStudentClass(
        studentId: 'student-123',
        newClassId: 'class-new',
      )).called(1);
    });

    test('shouldReturnFailure_whenStudentNotFound', () async {
      // Arrange
      when(mockRepository.updateStudentClass(
        studentId: 'invalid-student',
        newClassId: 'class-new',
      )).thenAnswer((_) async => const Left(NotFoundFailure('Student not found')));

      // Act
      final result = await useCase(
        const ChangeStudentClassParams(
          studentId: 'invalid-student',
          newClassId: 'class-new',
        ),
      );

      // Assert
      expect(result, const Left(NotFoundFailure('Student not found')));
    });

    test('shouldReturnFailure_whenClassNotFound', () async {
      // Arrange
      when(mockRepository.updateStudentClass(
        studentId: 'student-123',
        newClassId: 'invalid-class',
      )).thenAnswer((_) async => const Left(NotFoundFailure('Class not found')));

      // Act
      final result = await useCase(
        const ChangeStudentClassParams(
          studentId: 'student-123',
          newClassId: 'invalid-class',
        ),
      );

      // Assert
      expect(result, const Left(NotFoundFailure('Class not found')));
    });
  });

  // ============================================
  // ResetStudentPasswordUseCase Tests
  // ============================================
  group('ResetStudentPasswordUseCase', () {
    late ResetStudentPasswordUseCase useCase;

    setUp(() {
      useCase = ResetStudentPasswordUseCase(mockRepository);
    });

    test('shouldReturnNewPassword_whenResetSuccessfully', () async {
      // Arrange
      when(mockRepository.resetStudentPassword('student-123'))
          .thenAnswer((_) async => const Right('NewPass123!'));

      // Act
      final result = await useCase(
        const ResetStudentPasswordParams(studentId: 'student-123'),
      );

      // Assert
      expect(result, const Right('NewPass123!'));
      verify(mockRepository.resetStudentPassword('student-123')).called(1);
    });

    test('shouldReturnFailure_whenStudentNotFound', () async {
      // Arrange
      when(mockRepository.resetStudentPassword('invalid-student'))
          .thenAnswer((_) async => const Left(NotFoundFailure('Student not found')));

      // Act
      final result = await useCase(
        const ResetStudentPasswordParams(studentId: 'invalid-student'),
      );

      // Assert
      expect(result, const Left(NotFoundFailure('Student not found')));
    });

    test('shouldReturnFailure_whenServerError', () async {
      // Arrange
      when(mockRepository.resetStudentPassword('student-123'))
          .thenAnswer((_) async => const Left(ServerFailure('Auth service unavailable')));

      // Act
      final result = await useCase(
        const ResetStudentPasswordParams(studentId: 'student-123'),
      );

      // Assert
      expect(result, const Left(ServerFailure('Auth service unavailable')));
    });
  });

  // ============================================
  // SendPasswordResetEmailUseCase Tests
  // ============================================
  group('SendPasswordResetEmailUseCase', () {
    late SendPasswordResetEmailUseCase useCase;

    setUp(() {
      useCase = SendPasswordResetEmailUseCase(mockRepository);
    });

    test('shouldReturnSuccess_whenEmailSentSuccessfully', () async {
      // Arrange
      when(mockRepository.sendPasswordResetEmail('student@example.com'))
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(
        const SendPasswordResetEmailParams(email: 'student@example.com'),
      );

      // Assert
      expect(result.isRight(), true);
      verify(mockRepository.sendPasswordResetEmail('student@example.com')).called(1);
    });

    test('shouldReturnFailure_whenEmailNotFound', () async {
      // Arrange
      when(mockRepository.sendPasswordResetEmail('unknown@example.com'))
          .thenAnswer((_) async => const Left(NotFoundFailure('Email not found')));

      // Act
      final result = await useCase(
        const SendPasswordResetEmailParams(email: 'unknown@example.com'),
      );

      // Assert
      expect(result, const Left(NotFoundFailure('Email not found')));
    });

    test('shouldReturnFailure_whenEmailServiceFails', () async {
      // Arrange
      when(mockRepository.sendPasswordResetEmail('student@example.com'))
          .thenAnswer((_) async => const Left(ServerFailure('Email service unavailable')));

      // Act
      final result = await useCase(
        const SendPasswordResetEmailParams(email: 'student@example.com'),
      );

      // Assert
      expect(result, const Left(ServerFailure('Email service unavailable')));
    });
  });
}
