import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/avatar/equipped_avatar_model.dart';
import '../../domain/entities/avatar.dart';
import '../../domain/usecases/avatar/buy_avatar_item_usecase.dart';
import '../../domain/usecases/avatar/equip_avatar_item_usecase.dart';
import '../../domain/usecases/avatar/get_user_avatar_items_usecase.dart';
import '../../domain/usecases/avatar/set_avatar_base_usecase.dart';
import '../../domain/usecases/avatar/unequip_avatar_item_usecase.dart';
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

/// Controller for avatar mutations (setBase, equip, unequip, buy).
/// Keeps business logic out of screens — mirrors PackOpeningController pattern.
class AvatarController extends StateNotifier<AsyncValue<void>> {
  AvatarController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  bool get isMutating => state is AsyncLoading;

  Future<String?> setBase(String baseId) async {
    if (isMutating) return null;
    state = const AsyncValue.loading();
    final useCase = _ref.read(setAvatarBaseUseCaseProvider);
    final result = await useCase(SetAvatarBaseParams(baseId: baseId));
    return result.fold(
      (failure) {
        state = const AsyncValue.data(null);
        return 'Failed to set base: ${failure.message}';
      },
      (_) {
        _ref.invalidate(userAvatarItemsProvider);
        _ref.read(userControllerProvider.notifier).refreshProfileOnly();
        state = const AsyncValue.data(null);
        return null;
      },
    );
  }

  Future<String?> equipItem(String itemId) async {
    if (isMutating) return null;
    state = const AsyncValue.loading();
    final useCase = _ref.read(equipAvatarItemUseCaseProvider);
    final result = await useCase(EquipAvatarItemParams(itemId: itemId));
    return result.fold(
      (failure) {
        state = const AsyncValue.data(null);
        return 'Failed to equip: ${failure.message}';
      },
      (_) {
        _ref.invalidate(userAvatarItemsProvider);
        _ref.read(userControllerProvider.notifier).refreshProfileOnly();
        state = const AsyncValue.data(null);
        return null;
      },
    );
  }

  Future<String?> unequipItem(String itemId) async {
    if (isMutating) return null;
    state = const AsyncValue.loading();
    final useCase = _ref.read(unequipAvatarItemUseCaseProvider);
    final result = await useCase(UnequipAvatarItemParams(itemId: itemId));
    return result.fold(
      (failure) {
        state = const AsyncValue.data(null);
        return 'Failed to unequip: ${failure.message}';
      },
      (_) {
        _ref.invalidate(userAvatarItemsProvider);
        _ref.read(userControllerProvider.notifier).refreshProfileOnly();
        state = const AsyncValue.data(null);
        return null;
      },
    );
  }

  Future<String?> buyItem(String itemId) async {
    if (isMutating) return null;
    state = const AsyncValue.loading();
    final useCase = _ref.read(buyAvatarItemUseCaseProvider);
    final result = await useCase(BuyAvatarItemParams(itemId: itemId));
    return result.fold(
      (failure) {
        state = const AsyncValue.data(null);
        return 'Purchase failed: ${failure.message}';
      },
      (buyResult) {
        _ref.invalidate(userAvatarItemsProvider);
        _ref.read(userControllerProvider.notifier).refreshProfileOnly();
        state = const AsyncValue.data(null);
        return null;
      },
    );
  }
}

final avatarControllerProvider =
    StateNotifierProvider.autoDispose<AvatarController, AsyncValue<void>>((ref) {
  return AvatarController(ref);
});
