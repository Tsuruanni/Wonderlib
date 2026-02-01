import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/badge.dart';
import '../../repositories/badge_repository.dart';
import '../usecase.dart';

class GetAllBadgesUseCase implements UseCase<List<Badge>, NoParams> {

  const GetAllBadgesUseCase(this._repository);
  final BadgeRepository _repository;

  @override
  Future<Either<Failure, List<Badge>>> call(NoParams params) {
    return _repository.getAllBadges();
  }
}
