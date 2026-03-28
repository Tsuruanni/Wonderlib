import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/avatar.dart';

abstract class AvatarRepository {
  Future<Either<Failure, List<AvatarBase>>> getAvatarBases();
  Future<Either<Failure, void>> setAvatarBase(String baseId);
  Future<Either<Failure, List<AvatarItem>>> getAvatarItems();
  Future<Either<Failure, List<UserAvatarItem>>> getUserAvatarItems(String userId);
  Future<Either<Failure, BuyAvatarItemResult>> buyAvatarItem(String itemId);
  Future<Either<Failure, void>> equipAvatarItem(String itemId);
  Future<Either<Failure, void>> unequipAvatarItem(String itemId);
}
