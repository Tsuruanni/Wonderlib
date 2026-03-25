import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/avatar/equipped_avatar_model.dart';
import '../../domain/entities/avatar.dart';
import '../../domain/usecases/avatar/get_user_avatar_items_usecase.dart';
import '../../domain/usecases/usecase.dart';
import 'usecase_providers.dart';
import 'user_provider.dart';

/// All avatar base animals (cached)
final avatarBasesProvider = FutureProvider<List<AvatarBase>>((ref) async {
  final useCase = ref.watch(getAvatarBasesUseCaseProvider);
  final result = await useCase(const NoParams());
  return result.fold(
    (failure) {
      debugPrint('avatarBasesProvider: ${failure.message}');
      return [];
    },
    (bases) => bases,
  );
});

/// All shop items
final avatarShopProvider = FutureProvider<List<AvatarItem>>((ref) async {
  final useCase = ref.watch(getAvatarItemsUseCaseProvider);
  final result = await useCase(const NoParams());
  return result.fold(
    (failure) {
      debugPrint('avatarShopProvider: ${failure.message}');
      return [];
    },
    (items) => items,
  );
});

/// Current user's owned items
final userAvatarItemsProvider = FutureProvider<List<UserAvatarItem>>((ref) async {
  final user = ref.watch(userControllerProvider).valueOrNull;
  if (user == null) return [];
  final useCase = ref.watch(getUserAvatarItemsUseCaseProvider);
  final result = await useCase(GetUserAvatarItemsParams(userId: user.id));
  return result.fold(
    (failure) {
      debugPrint('userAvatarItemsProvider: ${failure.message}');
      return [];
    },
    (items) => items,
  );
});

/// Current user's equipped avatar (derived from profile cache — no extra query)
final equippedAvatarProvider = Provider<EquippedAvatar>((ref) {
  final user = ref.watch(userControllerProvider).valueOrNull;
  if (user?.avatarEquippedCache == null) return const EquippedAvatar();
  return EquippedAvatarModel.fromJson(user!.avatarEquippedCache).toEntity();
});

/// Owned item IDs for quick lookup
final ownedAvatarItemIdsProvider = Provider<Set<String>>((ref) {
  final items = ref.watch(userAvatarItemsProvider).valueOrNull ?? [];
  return items.map((i) => i.item.id).toSet();
});

/// Items grouped by category
final avatarItemsByCategoryProvider = Provider<Map<String, List<AvatarItem>>>((ref) {
  final items = ref.watch(avatarShopProvider).valueOrNull ?? [];
  final grouped = <String, List<AvatarItem>>{};
  for (final item in items) {
    grouped.putIfAbsent(item.category.name, () => []).add(item);
  }
  return grouped;
});
