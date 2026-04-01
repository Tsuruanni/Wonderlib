import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/card.dart';
import '../../domain/usecases/card/buy_pack_usecase.dart';
import '../../domain/usecases/card/get_user_cards_usecase.dart';
import '../../domain/usecases/card/get_user_card_stats_usecase.dart';
import '../../domain/usecases/card/open_pack_usecase.dart';
import '../../domain/usecases/card/get_class_top_collectors_usecase.dart';
import '../../domain/usecases/card/get_exclusive_cards_usecase.dart';
import '../../domain/usecases/usecase.dart';
import 'auth_provider.dart';
import 'usecase_providers.dart';
import 'user_provider.dart';

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

/// User's coin balance — derived from userControllerProvider (single source of truth)
final userCoinsProvider = Provider<int>((ref) {
  final user = ref.watch(userControllerProvider).valueOrNull;
  return user?.coins ?? 0;
});

/// User's unopened pack count — derived from userControllerProvider (single source of truth)
final unopenedPacksProvider = Provider<int>((ref) {
  final user = ref.watch(userControllerProvider).valueOrNull;
  return user?.unopenedPacks ?? 0;
});

// ============================================
// COMPUTED PROVIDERS
// ============================================

/// Set of card IDs the user owns — for quick owned/locked checks
final ownedCardIdsProvider = Provider<Set<String>>((ref) {
  final userCards = ref.watch(userCardsProvider).valueOrNull ?? [];
  return userCards.map((uc) => uc.cardId).toSet();
});

/// Cards grouped by category, sorted by owned status + rarity + cardNo.
/// Extracted from CardCollectionScreen.build() for memoization.
final sortedCollectionByCategoryProvider =
    Provider<Map<CardCategory, List<MythCard>>>((ref) {
  final catalog = ref.watch(cardCatalogProvider).valueOrNull ?? [];
  final ownedIds = ref.watch(ownedCardIdsProvider);

  final grouped = <CardCategory, List<MythCard>>{};
  for (final card in catalog) {
    grouped.putIfAbsent(card.category, () => []).add(card);
  }

  // Sort each category: owned first, then by rarity, then card number
  for (final category in grouped.keys) {
    grouped[category]!.sort((a, b) {
      final aOwned = ownedIds.contains(a.id);
      final bOwned = ownedIds.contains(b.id);

      if (aOwned && !bOwned) return -1;
      if (!aOwned && bOwned) return 1;

      if (aOwned && bOwned) {
        final rarityCompare = b.rarity.index.compareTo(a.rarity.index);
        if (rarityCompare != 0) return rarityCompare;
      } else if (!aOwned && !bOwned) {
        final rarityCompare = a.rarity.index.compareTo(b.rarity.index);
        if (rarityCompare != 0) return rarityCompare;
      }

      return a.cardNo.compareTo(b.cardNo);
    });
  }

  return grouped;
});

/// Per-category owned card count for progress display.
final categoryProgressProvider = Provider<Map<CardCategory, int>>((ref) {
  final userCards = ref.watch(userCardsProvider).valueOrNull ?? [];
  final progress = <CardCategory, int>{};
  for (final uc in userCards) {
    final cat = uc.card.category;
    progress[cat] = (progress[cat] ?? 0) + 1;
  }
  return progress;
});

// ============================================
// CARD PANEL SIDEBAR PROVIDERS
// ============================================

/// Rarity breakdown: count of owned cards per rarity vs total in catalog
final rarityBreakdownProvider =
    Provider<Map<CardRarity, ({int owned, int total})>>((ref) {
  final userCards = ref.watch(userCardsProvider).valueOrNull ?? [];
  final catalog = ref.watch(cardCatalogProvider).valueOrNull ?? [];

  final owned = <CardRarity, int>{};
  for (final uc in userCards) {
    final r = uc.card.rarity;
    owned[r] = (owned[r] ?? 0) + 1;
  }

  final total = <CardRarity, int>{};
  for (final c in catalog) {
    total[c.rarity] = (total[c.rarity] ?? 0) + 1;
  }

  return {
    for (final r in CardRarity.values)
      r: (owned: owned[r] ?? 0, total: total[r] ?? 0),
  };
});

/// Top 3 card collectors in user's class + caller rank
final classTopCollectorsProvider =
    FutureProvider<TopCollectorsResult>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return const TopCollectorsResult(top3: []);
  }

  final useCase = ref.watch(getClassTopCollectorsUseCaseProvider);
  final result =
      await useCase(GetClassTopCollectorsParams(userId: userId));
  return result.fold(
    (failure) {
      debugPrint('classTopCollectorsProvider error: ${failure.message}');
      return const TopCollectorsResult(top3: []);
    },
    (data) => data,
  );
});

/// Cards only the current user owns in their class
final exclusiveCardsProvider = FutureProvider<List<MythCard>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final useCase = ref.watch(getExclusiveCardsUseCaseProvider);
  final result = await useCase(GetExclusiveCardsParams(userId: userId));
  return result.fold(
    (failure) {
      debugPrint('exclusiveCardsProvider error: ${failure.message}');
      return [];
    },
    (cards) => cards,
  );
});

// ============================================
// PACK OPENING CONTROLLER
// ============================================

/// Pack opening state machine
enum PackOpeningPhase { idle, opening, buying, glowing, revealing, complete }

class PackOpeningState {
  const PackOpeningState({
    this.phase = PackOpeningPhase.idle,
    this.packResult,
    this.revealedIndices = const {},
    this.error,
    this.buySuccess = false,
    this.sessionId = 0,
  });

  final PackOpeningPhase phase;
  final PackResult? packResult;
  final Set<int> revealedIndices;
  final String? error;
  final bool buySuccess;
  final int sessionId;

  bool get allRevealed =>
      packResult != null && revealedIndices.length >= packResult!.cards.length;

  PackOpeningState copyWith({
    PackOpeningPhase? phase,
    PackResult? packResult,
    Set<int>? revealedIndices,
    String? error,
    bool? buySuccess,
    int? sessionId,
  }) {
    return PackOpeningState(
      phase: phase ?? this.phase,
      packResult: packResult ?? this.packResult,
      revealedIndices: revealedIndices ?? this.revealedIndices,
      error: error,
      buySuccess: buySuccess ?? this.buySuccess,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

class PackOpeningController extends StateNotifier<PackOpeningState> {
  PackOpeningController(this._ref) : super(const PackOpeningState());

  final Ref _ref;

  /// Buy a pack: deduct coins, add to inventory (does NOT open)
  Future<void> buyPack({required int cost}) async {
    if (state.phase != PackOpeningPhase.idle) return;

    state = state.copyWith(phase: PackOpeningPhase.buying, error: null, buySuccess: false);

    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = state.copyWith(
        phase: PackOpeningPhase.idle,
        error: 'Not logged in',
      );
      return;
    }

    final useCase = _ref.read(buyPackUseCaseProvider);
    final idempotencyKey = const Uuid().v4();
    final result = await useCase(BuyPackParams(userId: userId, cost: cost, idempotencyKey: idempotencyKey));

    result.fold(
      (failure) {
        state = state.copyWith(
          phase: PackOpeningPhase.idle,
          error: failure.message,
        );
      },
      (buyResult) {
        // Refresh user data to update coin/pack counts
        _ref.read(userControllerProvider.notifier).refreshProfileOnly();
        state = state.copyWith(
          phase: PackOpeningPhase.idle,
          buySuccess: true,
        );
      },
    );
  }

  /// Open a pack from inventory: consumes 1 pack, rolls 3 cards.
  /// Shows opening animation while RPC runs, then goes to revealing.
  Future<void> openPack() async {
    if (state.phase != PackOpeningPhase.idle) return;

    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = state.copyWith(
        phase: PackOpeningPhase.idle,
        error: 'Not logged in',
      );
      return;
    }

    state = state.copyWith(
      phase: PackOpeningPhase.opening,
      error: null,
      buySuccess: false,
    );

    final useCase = _ref.read(openPackUseCaseProvider);
    final result = await useCase(OpenPackParams(userId: userId));

    result.fold(
      (failure) {
        state = state.copyWith(
          phase: PackOpeningPhase.idle,
          error: failure.message,
        );
      },
      (packResult) {
        // Stay in opening phase — screen will transition to revealing
        // once Rive preload is also complete.
        state = state.copyWith(
          phase: PackOpeningPhase.opening,
          packResult: packResult,
        );
      },
    );
  }

  /// Transition to revealing when preload is complete.
  void forceReveal() {
    if (state.phase != PackOpeningPhase.opening || state.packResult == null) {
      return;
    }
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
    state = PackOpeningState(sessionId: state.sessionId + 1);
    _ref.invalidate(userCardsProvider);
    _ref.invalidate(userCardStatsProvider);
    _ref.read(userControllerProvider.notifier).refreshProfileOnly();
  }
}

final packOpeningControllerProvider =
    StateNotifierProvider.autoDispose<PackOpeningController, PackOpeningState>((ref) {
  return PackOpeningController(ref);
});
