import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';

/// Base use case interface
/// Type = return type, Params = input parameters
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

/// Use when no parameters needed
class NoParams {
  const NoParams();
}
