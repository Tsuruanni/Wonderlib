import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/tile_theme.dart';

abstract class TileThemeRepository {
  Future<Either<Failure, List<TileThemeEntity>>> getTileThemes();
}
