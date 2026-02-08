import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/card.dart';
import '../../domain/usecases/card/get_user_cards_usecase.dart';
import '../../domain/usecases/card/get_user_card_stats_usecase.dart';
import '../../domain/usecases/card/open_pack_usecase.dart';
import '../../domain/usecases/usecase.dart';
import 'auth_provider.dart';
import 'usecase_providers.dart';

// ============================================
// DATA PROVIDERS
// ============================================

/// Full card catalog (all 96 cards) — cached across the session
final cardCatalogProvider = FutureProvider<List<MythCard>>((ref) async {
  final useCase = ref.watch(getAllCardsUseCaseProvider);
  final result = await useCase(const NoParams());
  return result.fold(
    (failure) {
      debugPrint('cardCatalogProvider error: ${failure.message}');
      return [];
    },
    (cards) => cards,
  );
});

/// Current user's owned cards
final userCardsProvider = FutureProvider<List<UserCard>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final useCase = ref.watch(getUserCardsUseCaseProvider);
  final result = await useCase(GetUserCardsParams(userId: userId));
  return result.fold(
    (failure) {
      debugPrint('userCardsProvider error: ${failure.message}');
      return [];
    },
    (cards) => cards,
  );
});

/// Current user's card stats (pity counter, total packs, unique count)
final userCardStatsProvider = FutureProvider<UserCardStats>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const UserCardStats(userId: '');

  final useCase = ref.watch(getUserCardStatsUseCaseProvider);
  final result = await useCase(GetUserCardStatsParams(userId: userId));
  return result.fold(
    (failure) {
      debugPrint('userCardStatsProvider error: ${failure.message}');
      return UserCardStats(userId: userId);
    },
    (stats) => stats,
  );
});

/// User's coin balance — derived from currentUserProvider
final userCoinsProvider = Provider<int>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  return user?.coins ?? 0;
});

// ============================================
// COMPUTED PROVIDERS
// ============================================

/// Card catalog grouped by category
final collectionByCategoryProvider =
    Provider<Map<CardCategory, List<MythCard>>>((ref) {
  final catalog = ref.watch(cardCatalogProvider).valueOrNull ?? [];
  final grouped = <CardCategory, List<MythCard>>{};
  for (final card in catalog) {
    grouped.putIfAbsent(card.category, () => []).add(card);
  }
  return grouped;
});

/// Set of card IDs the user owns — for quick owned/locked checks
final ownedCardIdsProvider = Provider<Set<String>>((ref) {
  final userCards = ref.watch(userCardsProvider).valueOrNull ?? [];
  return userCards.map((uc) => uc.cardId).toSet();
});

/// Collection progress: unique owned / total catalog
final collectionProgressProvider = Provider<double>((ref) {
  final owned = ref.watch(ownedCardIdsProvider).length;
  final catalog = ref.watch(cardCatalogProvider).valueOrNull ?? [];
  if (catalog.isEmpty) return 0.0;
  return owned / catalog.length;
});

/// Category filter state for collection screen
final selectedCategoryProvider = StateProvider<CardCategory?>((ref) => null);

/// Filtered catalog based on selected category
final filteredCatalogProvider = Provider<List<MythCard>>((ref) {
  final category = ref.watch(selectedCategoryProvider);
  final catalog = ref.watch(cardCatalogProvider).valueOrNull ?? [];
  if (category == null) return catalog;
  return catalog.where((c) => c.category == category).toList();
});

// ============================================
// PACK OPENING CONTROLLER
// ============================================

/// Pack opening state machine
enum PackOpeningPhase { idle, purchasing, glowing, revealing, complete }

class PackOpeningState {
  const PackOpeningState({
    this.phase = PackOpeningPhase.idle,
    this.packResult,
    this.revealedIndices = const {},
    this.error,
  });

  final PackOpeningPhase phase;
  final PackResult? packResult;
  final Set<int> revealedIndices;
  final String? error;

  bool get allRevealed =>
      packResult != null && revealedIndices.length >= packResult!.cards.length;

  PackOpeningState copyWith({
    PackOpeningPhase? phase,
    PackResult? packResult,
    Set<int>? revealedIndices,
    String? error,
  }) {
    return PackOpeningState(
      phase: phase ?? this.phase,
      packResult: packResult ?? this.packResult,
      revealedIndices: revealedIndices ?? this.revealedIndices,
      error: error,
    );
  }
}

class PackOpeningController extends StateNotifier<PackOpeningState> {
  PackOpeningController(this._ref) : super(const PackOpeningState());

  final Ref _ref;

  /// Purchase a pack: deduct coins, get 3 cards
  Future<void> purchasePack({int cost = 100}) async {
    if (state.phase != PackOpeningPhase.idle) return;

    state = state.copyWith(phase: PackOpeningPhase.purchasing, error: null);

    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = state.copyWith(
        phase: PackOpeningPhase.idle,
        error: 'Not logged in',
      );
      return;
    }

    final useCase = _ref.read(openPackUseCaseProvider);
    final result = await useCase(OpenPackParams(userId: userId, cost: cost));

    result.fold(
      (failure) {
        state = state.copyWith(
          phase: PackOpeningPhase.idle,
          error: failure.message,
        );
      },
      (packResult) {
        state = PackOpeningState(
          phase: PackOpeningPhase.glowing,
          packResult: packResult,
        );
      },
    );
  }

  /// Move from glow to reveal phase (after glow animation completes)
  void startRevealing() {
    if (state.phase != PackOpeningPhase.glowing) return;
    state = state.copyWith(phase: PackOpeningPhase.revealing);
  }

  /// Reveal a card at the given index
  void revealCard(int index) {
    if (state.phase != PackOpeningPhase.revealing) return;
    if (state.revealedIndices.contains(index)) return;

    final newRevealed = {...state.revealedIndices, index};
    final allDone =
        state.packResult != null &&
        newRevealed.length >= state.packResult!.cards.length;

    state = state.copyWith(
      revealedIndices: newRevealed,
      phase: allDone ? PackOpeningPhase.complete : PackOpeningPhase.revealing,
    );
  }

  /// Reset to idle — invalidates dependent providers for fresh data
  void reset() {
    state = const PackOpeningState();
    // Refresh collection data after pack opening
    _ref.invalidate(userCardsProvider);
    _ref.invalidate(userCardStatsProvider);
    _ref.invalidate(currentUserProvider);
  }
}

final packOpeningControllerProvider =
    StateNotifierProvider<PackOpeningController, PackOpeningState>((ref) {
  return PackOpeningController(ref);
});
