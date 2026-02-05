import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class CreateAssignmentParams {

  const CreateAssignmentParams({
    required this.teacherId,
    this.classId,
    this.studentIds,
    required this.type,
    required this.title,
    this.description,
    this.bookId,
    this.wordListId,
    this.lockLibrary = false,
    required this.startDate,
    required this.dueDate,
  });
  final String teacherId;
  final String? classId;
  final List<String>? studentIds;
  final AssignmentType type;
  final String title;
  final String? description;
  final String? bookId;
  final String? wordListId;
  final bool lockLibrary;
  final DateTime startDate;
  final DateTime dueDate;
}

/// Creates a new assignment with validation
class CreateAssignmentUseCase
    implements UseCase<Assignment, CreateAssignmentParams> {

  const CreateAssignmentUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, Assignment>> call(CreateAssignmentParams params) {
    // Validate based on assignment type
    if (params.type == AssignmentType.book && params.bookId == null) {
      return Future.value(
        const Left(ValidationFailure('Book is required for book assignments')),
      );
    }

    if (params.type == AssignmentType.vocabulary && params.wordListId == null) {
      return Future.value(
        const Left(
          ValidationFailure('Word list is required for vocabulary assignments'),
        ),
      );
    }

    // Build content config based on type
    final contentConfig = <String, dynamic>{};
    if (params.type == AssignmentType.book) {
      contentConfig['bookId'] = params.bookId;
      contentConfig['lockLibrary'] = params.lockLibrary;
    } else if (params.type == AssignmentType.vocabulary) {
      contentConfig['wordListId'] = params.wordListId;
    }

    final data = CreateAssignmentData(
      classId: params.classId,
      studentIds: params.studentIds,
      type: params.type,
      title: params.title,
      description: params.description,
      contentConfig: contentConfig,
      startDate: params.startDate,
      dueDate: params.dueDate,
    );

    return _repository.createAssignment(params.teacherId, data);
  }
}
