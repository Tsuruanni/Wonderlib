import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../entities/daily_quest.dart';
import '../../repositories/daily_quest_repository.dart';
import '../usecase.dart';

class GetDailyQuestProgressUseCase
    implements UseCase<List<DailyQuestProgress>, GetDailyQuestProgressParams> {
  const GetDailyQuestProgressUseCase(this._repository);

  final DailyQuestRepository _repository;

  @override
  Future<Either<Failure, List<DailyQuestProgress>>> call(
    GetDailyQuestProgressParams params,
  ) {
    return _repository.getDailyQuestProgress(params.userId);
  }
}

class GetDailyQuestProgressParams {
  const GetDailyQuestProgressParams({required this.userId});

  final String userId;
}
