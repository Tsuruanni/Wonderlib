import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/card.dart';
import '../../domain/usecases/card/trade_duplicate_cards_usecase.dart';
import 'auth_provider.dart';
import 'card_provider.dart';
import 'usecase_providers.dart';

/// Trade cost per source rarity
const tradeRequirements = {
  CardRarity.common: (count: 7, target: 'rare'),
  CardRarity.rare: (count: 7, target: 'epic'),
  CardRarity.epic: (count: 7, target: 'legendary'),
};

/// Whether user has enough duplicates for any trade
final canTradeProvider = Provider<bool>((ref) {
  final userCards = ref.watch(userCardsProvider).valueOrNull ?? [];
  for (final entry in tradeRequirements.entries) {
    final rarity = entry.key;
    final required = entry.value.count;
    final available = userCards
        .where((uc) => uc.card.rarity == rarity && uc.quantity > 1)
        .fold<int>(0, (sum, uc) => sum + uc.quantity - 1);
    if (available >= required) return true;
  }
  return false;
});

/// Available duplicate count per rarity (for tab enable/disable)
final tradeableDuplicateCountProvider =
    Provider<Map<CardRarity, int>>((ref) {
  final userCards = ref.watch(userCardsProvider).valueOrNull ?? [];
  return {
    for (final rarity in [CardRarity.common, CardRarity.rare, CardRarity.epic])
      rarity: userCards
          .where((uc) => uc.card.rarity == rarity && uc.quantity > 1)
          .fold<int>(0, (sum, uc) => sum + uc.quantity - 1),
  };
});

/// Cards for trade grid: all cards of a rarity, with tradeable info
final tradeGridCardsProvider =
    Provider.family<List<UserCard>, CardRarity>((ref, rarity) {
  final userCards = ref.watch(userCardsProvider).valueOrNull ?? [];
  return userCards
      .where((uc) => uc.card.rarity == rarity)
      .toList()
    ..sort((a, b) => b.quantity.compareTo(a.quantity));
});

// ============================================
// TRADE SELECTION STATE
// ============================================

class TradeSelectionState {
  const TradeSelectionState({
    this.selectedCards = const {},
    this.phase = TradePhase.selecting,
    this.result,
    this.error,
  });

  final Map<String, int> selectedCards;
  final TradePhase phase;
  final TradeResult? result;
  final String? error;

  int get totalSelected =>
      selectedCards.values.fold<int>(0, (sum, v) => sum + v);

  TradeSelectionState copyWith({
    Map<String, int>? selectedCards,
    TradePhase? phase,
    TradeResult? result,
    String? error,
  }) {
    return TradeSelectionState(
      selectedCards: selectedCards ?? this.selectedCards,
      phase: phase ?? this.phase,
      result: result ?? this.result,
      error: error,
    );
  }
}

enum TradePhase { selecting, trading, reveal }

final tradeSelectionProvider = StateNotifierProvider.autoDispose<
    TradeSelectionController, TradeSelectionState>(
  (ref) => TradeSelectionController(ref),
);

class TradeSelectionController extends StateNotifier<TradeSelectionState> {
  TradeSelectionController(this._ref) : super(const TradeSelectionState());

  final Ref _ref;

  void addCard(String cardId, {required int maxAvailable}) {
    final current = state.selectedCards[cardId] ?? 0;
    if (current >= maxAvailable) return;
    state = state.copyWith(
      selectedCards: {...state.selectedCards, cardId: current + 1},
    );
  }

  void removeCard(String cardId) {
    final current = state.selectedCards[cardId] ?? 0;
    if (current <= 0) return;
    final updated = {...state.selectedCards};
    if (current == 1) {
      updated.remove(cardId);
    } else {
      updated[cardId] = current - 1;
    }
    state = state.copyWith(selectedCards: updated);
  }

  void clearSelection() {
    state = const TradeSelectionState();
  }

  Future<void> executeTrade(CardRarity sourceRarity) async {
    if (state.phase != TradePhase.selecting) return;

    final req = tradeRequirements[sourceRarity];
    if (req == null || state.totalSelected != req.count) return;

    state = state.copyWith(phase: TradePhase.trading, error: null);

    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = state.copyWith(
        phase: TradePhase.selecting,
        error: 'Not logged in',
      );
      return;
    }

    final useCase = _ref.read(tradeDuplicateCardsUseCaseProvider);
    final idempotencyKey = const Uuid().v4();

    final result = await useCase(TradeDuplicateCardsParams(
      userId: userId,
      cardQuantities: state.selectedCards,
      targetRarity: req.target,
      idempotencyKey: idempotencyKey,
    ),);

    result.fold(
      (failure) {
        state = state.copyWith(
          phase: TradePhase.selecting,
          error: failure.message,
        );
      },
      (tradeResult) {
        state = state.copyWith(
          phase: TradePhase.reveal,
          result: tradeResult,
        );
        _ref.invalidate(userCardsProvider);
        _ref.invalidate(userCardStatsProvider);
        _ref.invalidate(classTopCollectorsProvider);
        _ref.invalidate(exclusiveCardsProvider);
      },
    );
  }

  void resetAfterReveal() {
    state = const TradeSelectionState();
  }
}
