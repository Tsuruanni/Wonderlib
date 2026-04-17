import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

/// Gets platform-wide student averages as benchmark data.
class GetGlobalAveragesUseCase implements UseCase<GlobalAverages, NoParams> {
  const GetGlobalAveragesUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, GlobalAverages>> call(NoParams params) {
    return _repository.getGlobalAverages();
  }
}
