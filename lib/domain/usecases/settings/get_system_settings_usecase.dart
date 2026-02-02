import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/system_settings.dart';
import '../../repositories/system_settings_repository.dart';
import '../usecase.dart';

/// UseCase for fetching system settings
class GetSystemSettingsUseCase implements UseCase<SystemSettings, NoParams> {
  final SystemSettingsRepository _repository;

  const GetSystemSettingsUseCase(this._repository);

  @override
  Future<Either<Failure, SystemSettings>> call(NoParams params) {
    return _repository.getSettings();
  }
}
