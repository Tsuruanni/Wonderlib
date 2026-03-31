import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/tile_theme.dart';
import '../../repositories/tile_theme_repository.dart';
import '../usecase.dart';

class GetTileThemesUseCase implements UseCase<List<TileThemeEntity>, NoParams> {
  const GetTileThemesUseCase(this._repository);

  final TileThemeRepository _repository;

  @override
  Future<Either<Failure, List<TileThemeEntity>>> call(NoParams params) {
    return _repository.getTileThemes();
  }
}
