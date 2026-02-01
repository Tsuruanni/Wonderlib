import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:readeng/core/errors/failures.dart';
import 'package:readeng/domain/repositories/teacher_repository.dart';
import 'package:readeng/domain/usecases/assignment/create_assignment_usecase.dart';
import 'package:readeng/domain/usecases/assignment/delete_assignment_usecase.dart';
import 'package:readeng/domain/usecases/assignment/get_assignment_detail_usecase.dart';
import 'package:readeng/domain/usecases/assignment/get_assignment_students_usecase.dart';
import 'package:readeng/domain/usecases/assignment/get_assignments_usecase.dart';

import '../../../../fixtures/teacher_fixtures.dart';

import 'assignment_usecases_test.mocks.dart';

@GenerateMocks([TeacherRepository])
void main() {
  late MockTeacherRepository mockRepository;

  setUp(() {
    mockRepository = MockTeacherRepository();
  });

  // ============================================
  // GetAssignmentsUseCase Tests
  // ============================================
  group('GetAssignmentsUseCase', () {
    late GetAssignmentsUseCase useCase;

    setUp(() {
      useCase = GetAssignmentsUseCase(mockRepository);
    });

    test('shouldReturnAssignments_whenRepositorySucceeds', () async {
      // Arrange
      final assignments = AssignmentFixtures.assignmentList();
      when(mockRepository.getAssignments('teacher-123'))
          .thenAnswer((_) async => Right(assignments));

      // Act
      final result = await useCase(
        const GetAssignmentsParams(teacherId: 'teacher-123'),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (list) {
          expect(list.length, 3);
          expect(list[0].title, 'Read Chapter 1-3');
          expect(list[1].type, AssignmentType.vocabulary);
        },
      );
      verify(mockRepository.getAssignments('teacher-123')).called(1);
    });

    test('shouldReturnEmptyList_whenNoAssignmentsExist', () async {
      // Arrange
      when(mockRepository.getAssignments('new-teacher'))
          .thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(
        const GetAssignmentsParams(teacherId: 'new-teacher'),
      );

      // Assert
      expect(result, const Right(<Assignment>[]));
    });

    test('shouldReturnFailure_whenRepositoryFails', () async {
      // Arrange
      when(mockRepository.getAssignments('teacher-123'))
          .thenAnswer((_) async => const Left(ServerFailure('Server error')));

      // Act
      final result = await useCase(
        const GetAssignmentsParams(teacherId: 'teacher-123'),
      );

      // Assert
      expect(result, const Left(ServerFailure('Server error')));
    });
  });

  // ============================================
  // GetAssignmentDetailUseCase Tests
  // ============================================
  group('GetAssignmentDetailUseCase', () {
    late GetAssignmentDetailUseCase useCase;

    setUp(() {
      useCase = GetAssignmentDetailUseCase(mockRepository);
    });

    test('shouldReturnAssignmentDetail_whenRepositorySucceeds', () async {
      // Arrange
      final assignment = AssignmentFixtures.validAssignment();
      when(mockRepository.getAssignmentDetail('assignment-123'))
          .thenAnswer((_) async => Right(assignment));

      // Act
      final result = await useCase(
        const GetAssignmentDetailParams(assignmentId: 'assignment-123'),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (detail) {
          expect(detail.id, 'assignment-123');
          expect(detail.title, 'Read Chapter 1-3');
          expect(detail.type, AssignmentType.book);
          expect(detail.totalStudents, 30);
        },
      );
      verify(mockRepository.getAssignmentDetail('assignment-123')).called(1);
    });

    test('shouldReturnFailure_whenAssignmentNotFound', () async {
      // Arrange
      when(mockRepository.getAssignmentDetail('invalid-id'))
          .thenAnswer((_) async => const Left(NotFoundFailure('Assignment not found')));

      // Act
      final result = await useCase(
        const GetAssignmentDetailParams(assignmentId: 'invalid-id'),
      );

      // Assert
      expect(result, const Left(NotFoundFailure('Assignment not found')));
    });
  });

  // ============================================
  // GetAssignmentStudentsUseCase Tests
  // ============================================
  group('GetAssignmentStudentsUseCase', () {
    late GetAssignmentStudentsUseCase useCase;

    setUp(() {
      useCase = GetAssignmentStudentsUseCase(mockRepository);
    });

    test('shouldReturnStudentProgress_whenRepositorySucceeds', () async {
      // Arrange
      final students = AssignmentStudentFixtures.studentList();
      when(mockRepository.getAssignmentStudents('assignment-123'))
          .thenAnswer((_) async => Right(students));

      // Act
      final result = await useCase(
        const GetAssignmentStudentsParams(assignmentId: 'assignment-123'),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (list) {
          expect(list.length, 4);
          expect(list[0].status, AssignmentStatus.pending);
          expect(list[1].status, AssignmentStatus.inProgress);
          expect(list[2].status, AssignmentStatus.completed);
          expect(list[3].status, AssignmentStatus.overdue);
        },
      );
      verify(mockRepository.getAssignmentStudents('assignment-123')).called(1);
    });

    test('shouldReturnEmptyList_whenNoStudentsAssigned', () async {
      // Arrange
      when(mockRepository.getAssignmentStudents('empty-assignment'))
          .thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase(
        const GetAssignmentStudentsParams(assignmentId: 'empty-assignment'),
      );

      // Assert
      expect(result, const Right(<AssignmentStudent>[]));
    });

    test('shouldReturnFailure_whenAssignmentNotFound', () async {
      // Arrange
      when(mockRepository.getAssignmentStudents('invalid-id'))
          .thenAnswer((_) async => const Left(NotFoundFailure('Assignment not found')));

      // Act
      final result = await useCase(
        const GetAssignmentStudentsParams(assignmentId: 'invalid-id'),
      );

      // Assert
      expect(result, const Left(NotFoundFailure('Assignment not found')));
    });
  });

  // ============================================
  // CreateAssignmentUseCase Tests
  // ============================================
  group('CreateAssignmentUseCase', () {
    late CreateAssignmentUseCase useCase;

    setUp(() {
      useCase = CreateAssignmentUseCase(mockRepository);
    });

    test('shouldReturnCreatedAssignment_whenBookAssignmentValid', () async {
      // Arrange
      final createdAssignment = AssignmentFixtures.validAssignment();
      when(mockRepository.createAssignment(
        'teacher-123',
        any,
      )).thenAnswer((_) async => Right(createdAssignment));

      // Act
      final result = await useCase(
        CreateAssignmentParams(
          teacherId: 'teacher-123',
          classId: 'class-789',
          type: AssignmentType.book,
          title: 'Read Chapter 1-3',
          description: 'Complete chapters 1-3',
          bookId: 'book-123',
          startDate: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 14)),
        ),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (assignment) {
          expect(assignment.id, 'assignment-123');
          expect(assignment.type, AssignmentType.book);
        },
      );
      verify(mockRepository.createAssignment('teacher-123', any)).called(1);
    });

    test('shouldReturnCreatedAssignment_whenVocabularyAssignmentValid', () async {
      // Arrange
      final createdAssignment = AssignmentFixtures.vocabularyAssignment();
      when(mockRepository.createAssignment(
        'teacher-123',
        any,
      )).thenAnswer((_) async => Right(createdAssignment));

      // Act
      final result = await useCase(
        CreateAssignmentParams(
          teacherId: 'teacher-123',
          classId: 'class-789',
          type: AssignmentType.vocabulary,
          title: 'Learn Unit 5 Words',
          wordListId: 'list-123',
          startDate: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 7)),
        ),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (assignment) {
          expect(assignment.type, AssignmentType.vocabulary);
        },
      );
    });

    test('shouldReturnValidationFailure_whenBookAssignmentWithoutBookId', () async {
      // Act
      final result = await useCase(
        CreateAssignmentParams(
          teacherId: 'teacher-123',
          classId: 'class-789',
          type: AssignmentType.book,
          title: 'Read Chapter 1-3',
          // bookId is missing
          startDate: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 14)),
        ),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect((failure as ValidationFailure).message, 'Book is required for book assignments');
        },
        (assignment) => fail('Expected failure'),
      );
      verifyNever(mockRepository.createAssignment(any, any));
    });

    test('shouldReturnValidationFailure_whenVocabularyAssignmentWithoutWordListId', () async {
      // Act
      final result = await useCase(
        CreateAssignmentParams(
          teacherId: 'teacher-123',
          classId: 'class-789',
          type: AssignmentType.vocabulary,
          title: 'Learn Unit 5 Words',
          // wordListId is missing
          startDate: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 7)),
        ),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ValidationFailure>());
          expect(
            (failure as ValidationFailure).message,
            'Word list is required for vocabulary assignments',
          );
        },
        (assignment) => fail('Expected failure'),
      );
      verifyNever(mockRepository.createAssignment(any, any));
    });

    test('shouldCreateIndividualAssignment_whenStudentIdsProvided', () async {
      // Arrange
      final createdAssignment = AssignmentFixtures.validAssignment();
      when(mockRepository.createAssignment(
        'teacher-123',
        any,
      )).thenAnswer((_) async => Right(createdAssignment));

      // Act
      final result = await useCase(
        CreateAssignmentParams(
          teacherId: 'teacher-123',
          studentIds: const ['student-1', 'student-2', 'student-3'],
          type: AssignmentType.book,
          title: 'Individual Assignment',
          bookId: 'book-123',
          startDate: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 10)),
        ),
      );

      // Assert
      expect(result.isRight(), true);
      verify(mockRepository.createAssignment('teacher-123', any)).called(1);
    });

    test('shouldReturnFailure_whenRepositoryFails', () async {
      // Arrange
      when(mockRepository.createAssignment(
        'teacher-123',
        any,
      )).thenAnswer((_) async => const Left(ServerFailure('Failed to create')));

      // Act
      final result = await useCase(
        CreateAssignmentParams(
          teacherId: 'teacher-123',
          classId: 'class-789',
          type: AssignmentType.book,
          title: 'Read Chapter 1-3',
          bookId: 'book-123',
          startDate: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 14)),
        ),
      );

      // Assert
      expect(result, const Left(ServerFailure('Failed to create')));
    });
  });

  // ============================================
  // DeleteAssignmentUseCase Tests
  // ============================================
  group('DeleteAssignmentUseCase', () {
    late DeleteAssignmentUseCase useCase;

    setUp(() {
      useCase = DeleteAssignmentUseCase(mockRepository);
    });

    test('shouldReturnSuccess_whenDeletedSuccessfully', () async {
      // Arrange
      when(mockRepository.deleteAssignment('assignment-123'))
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(
        const DeleteAssignmentParams(assignmentId: 'assignment-123'),
      );

      // Assert
      expect(result.isRight(), true);
      verify(mockRepository.deleteAssignment('assignment-123')).called(1);
    });

    test('shouldReturnFailure_whenAssignmentNotFound', () async {
      // Arrange
      when(mockRepository.deleteAssignment('invalid-id'))
          .thenAnswer((_) async => const Left(NotFoundFailure('Assignment not found')));

      // Act
      final result = await useCase(
        const DeleteAssignmentParams(assignmentId: 'invalid-id'),
      );

      // Assert
      expect(result, const Left(NotFoundFailure('Assignment not found')));
    });

    test('shouldReturnFailure_whenServerError', () async {
      // Arrange
      when(mockRepository.deleteAssignment('assignment-123'))
          .thenAnswer((_) async => const Left(ServerFailure('Database error')));

      // Act
      final result = await useCase(
        const DeleteAssignmentParams(assignmentId: 'assignment-123'),
      );

      // Assert
      expect(result, const Left(ServerFailure('Database error')));
    });
  });
}
