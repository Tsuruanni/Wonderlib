import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/monthly_quest.dart';
import '../../repositories/monthly_quest_repository.dart';
import '../usecase.dart';

class GetMonthlyQuestProgressUseCase
    implements UseCase<List<MonthlyQuestProgress>, GetMonthlyQuestProgressParams> {
  const GetMonthlyQuestProgressUseCase(this._repository);

  final MonthlyQuestRepository _repository;

  @override
  Future<Either<Failure, List<MonthlyQuestProgress>>> call(
    GetMonthlyQuestProgressParams params,
  ) {
    return _repository.getMonthlyQuestProgress(params.userId);
  }
}

class GetMonthlyQuestProgressParams {
  const GetMonthlyQuestProgressParams({required this.userId});

  final String userId;
}
