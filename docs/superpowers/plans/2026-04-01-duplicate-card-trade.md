# Duplicate Card Trade — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow players to trade duplicate cards of the same rarity for a random card of the next rarity tier (5 common→1 rare, 4 rare→1 epic, 3 epic→1 legendary).

**Architecture:** Single Supabase RPC handles validation, card deduction, weighted random selection (80% unowned / 20% any), upsert, and audit logging. Flutter side follows `Repository → UseCase → Provider → Screen` chain. Trade screen uses tabs for each rarity tier with manual card selection.

**Tech Stack:** Flutter/Riverpod, Supabase RPC (plpgsql), CachedNetworkImage, Google Fonts

**Spec:** `docs/superpowers/specs/2026-04-01-duplicate-card-trade-design.md`

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `supabase/migrations/20260401100001_duplicate_card_trade.sql` | Table `card_trade_logs` + RPC `trade_duplicate_cards` |
| `lib/domain/usecases/card/trade_duplicate_cards_usecase.dart` | UseCase |
| `lib/presentation/providers/card_trade_provider.dart` | Trade state management + tradeable cards provider |
| `lib/presentation/screens/cards/card_trade_screen.dart` | Trade screen UI (tabs, card grid, selection, reveal) |
| `lib/presentation/widgets/cards/trade_button_card.dart` | Right panel "Trade Duplicates" button |

### Modified Files

| File | Change |
|------|--------|
| `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | Add `tradeDuplicateCards` constant |
| `lib/domain/entities/card.dart` | Add `TradeResult` entity |
| `lib/domain/repositories/card_repository.dart` | Add `tradeDuplicateCards` method |
| `lib/data/repositories/supabase/supabase_card_repository.dart` | Implement trade RPC call |
| `lib/presentation/providers/usecase_providers.dart` | Register trade UseCase |
| `lib/presentation/widgets/shell/right_info_panel.dart` | Add trade button to cards route |
| `lib/app/router.dart` | Add trade screen route |

---

## Task 1: Database — Table + RPC

**Files:**
- Create: `supabase/migrations/20260401100001_duplicate_card_trade.sql`

- [ ] **Step 1: Create migration file**

```sql
-- Duplicate Card Trade System

-- 1. Audit log table
CREATE TABLE card_trade_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id),
    traded_rarity VARCHAR(20) NOT NULL,
    traded_cards JSONB NOT NULL,
    total_cards_traded INTEGER NOT NULL,
    received_card_id UUID NOT NULL REFERENCES myth_cards(id),
    received_rarity VARCHAR(20) NOT NULL,
    was_new_card BOOLEAN NOT NULL,
    idempotency_key UUID UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_card_trade_logs_user ON card_trade_logs(user_id);

ALTER TABLE card_trade_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own trade logs"
    ON card_trade_logs FOR SELECT
    USING (user_id = auth.uid());

-- 2. Trade RPC
CREATE OR REPLACE FUNCTION trade_duplicate_cards(
    p_user_id UUID,
    p_card_quantities JSONB,
    p_target_rarity VARCHAR(20),
    p_idempotency_key UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_source_rarity VARCHAR(20);
    v_required_count INTEGER;
    v_total_given INTEGER := 0;
    v_card_id UUID;
    v_amount INTEGER;
    v_current_qty INTEGER;
    v_selected_card RECORD;
    v_existing RECORD;
    v_is_new BOOLEAN;
    v_new_qty INTEGER;
    v_roll DOUBLE PRECISION;
BEGIN
    -- Auth check
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized: user mismatch';
    END IF;

    -- Idempotency check
    IF p_idempotency_key IS NOT NULL THEN
        SELECT ctl.received_card_id, ctl.was_new_card,
               mc.card_no, mc.name, mc.category, mc.category_icon,
               mc.rarity, mc.power, mc.special_skill, mc.description, mc.image_url
        INTO v_existing
        FROM card_trade_logs ctl
        JOIN myth_cards mc ON mc.id = ctl.received_card_id
        WHERE ctl.idempotency_key = p_idempotency_key;

        IF FOUND THEN
            RETURN jsonb_build_object(
                'received_card', jsonb_build_object(
                    'id', v_existing.received_card_id,
                    'card_no', v_existing.card_no,
                    'name', v_existing.name,
                    'category', v_existing.category,
                    'category_icon', v_existing.category_icon,
                    'rarity', v_existing.rarity,
                    'power', v_existing.power,
                    'special_skill', v_existing.special_skill,
                    'description', v_existing.description,
                    'image_url', v_existing.image_url
                ),
                'is_new', v_existing.was_new_card,
                'quantity', (SELECT quantity FROM user_cards WHERE user_id = p_user_id AND card_id = v_existing.received_card_id),
                'already_processed', true
            );
        END IF;
    END IF;

    -- Determine source rarity and required count
    CASE p_target_rarity
        WHEN 'rare' THEN v_source_rarity := 'common'; v_required_count := 5;
        WHEN 'epic' THEN v_source_rarity := 'rare'; v_required_count := 4;
        WHEN 'legendary' THEN v_source_rarity := 'epic'; v_required_count := 3;
        ELSE RAISE EXCEPTION 'Invalid target rarity: %', p_target_rarity;
    END CASE;

    -- Validate all given cards
    FOR v_card_id, v_amount IN
        SELECT (key)::UUID, (value)::INTEGER
        FROM jsonb_each_text(p_card_quantities)
    LOOP
        IF v_amount < 1 THEN
            RAISE EXCEPTION 'Invalid amount for card %', v_card_id;
        END IF;

        SELECT uc.quantity INTO v_current_qty
        FROM user_cards uc
        JOIN myth_cards mc ON mc.id = uc.card_id
        WHERE uc.user_id = p_user_id
          AND uc.card_id = v_card_id
          AND mc.rarity = v_source_rarity
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Card % not owned or wrong rarity', v_card_id;
        END IF;

        IF v_current_qty - v_amount < 1 THEN
            RAISE EXCEPTION 'Must keep at least 1 copy of card %', v_card_id;
        END IF;

        v_total_given := v_total_given + v_amount;
    END LOOP;

    IF v_total_given != v_required_count THEN
        RAISE EXCEPTION 'Expected % cards, got %', v_required_count, v_total_given;
    END IF;

    -- Deduct cards
    FOR v_card_id, v_amount IN
        SELECT (key)::UUID, (value)::INTEGER
        FROM jsonb_each_text(p_card_quantities)
    LOOP
        UPDATE user_cards
        SET quantity = quantity - v_amount, updated_at = NOW()
        WHERE user_id = p_user_id AND card_id = v_card_id;
    END LOOP;

    -- Select result card: 80% unowned, 20% any
    v_roll := random();

    IF v_roll < 0.80 THEN
        SELECT mc.* INTO v_selected_card
        FROM myth_cards mc
        WHERE mc.rarity = p_target_rarity
          AND mc.is_active = true
          AND NOT EXISTS (
              SELECT 1 FROM user_cards uc
              WHERE uc.user_id = p_user_id AND uc.card_id = mc.id
          )
        ORDER BY random()
        LIMIT 1;
    END IF;

    IF v_selected_card IS NULL THEN
        SELECT mc.* INTO v_selected_card
        FROM myth_cards mc
        WHERE mc.rarity = p_target_rarity
          AND mc.is_active = true
        ORDER BY random()
        LIMIT 1;
    END IF;

    -- Upsert received card
    SELECT quantity INTO v_new_qty
    FROM user_cards
    WHERE user_id = p_user_id AND card_id = v_selected_card.id;

    IF FOUND THEN
        v_is_new := FALSE;
        v_new_qty := v_new_qty + 1;
        UPDATE user_cards
        SET quantity = v_new_qty, updated_at = NOW()
        WHERE user_id = p_user_id AND card_id = v_selected_card.id;
    ELSE
        v_is_new := TRUE;
        v_new_qty := 1;
        INSERT INTO user_cards (user_id, card_id, quantity)
        VALUES (p_user_id, v_selected_card.id, 1);
    END IF;

    -- Update stats
    UPDATE user_card_stats
    SET total_unique_cards = (
            SELECT COUNT(*) FROM user_cards WHERE user_id = p_user_id
        ),
        updated_at = NOW()
    WHERE user_id = p_user_id;

    -- Log the trade
    INSERT INTO card_trade_logs (
        user_id, traded_rarity, traded_cards, total_cards_traded,
        received_card_id, received_rarity, was_new_card, idempotency_key
    ) VALUES (
        p_user_id, v_source_rarity, p_card_quantities, v_total_given,
        v_selected_card.id, p_target_rarity, v_is_new, p_idempotency_key
    );

    RETURN jsonb_build_object(
        'received_card', jsonb_build_object(
            'id', v_selected_card.id,
            'card_no', v_selected_card.card_no,
            'name', v_selected_card.name,
            'category', v_selected_card.category,
            'category_icon', v_selected_card.category_icon,
            'rarity', v_selected_card.rarity,
            'power', v_selected_card.power,
            'special_skill', v_selected_card.special_skill,
            'description', v_selected_card.description,
            'image_url', v_selected_card.image_url
        ),
        'is_new', v_is_new,
        'quantity', v_new_qty
    );
END;
$$;
```

- [ ] **Step 2: Dry-run**

Run: `supabase db push --dry-run`

- [ ] **Step 3: Push**

Run: `supabase db push`

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260401100001_duplicate_card_trade.sql
git commit -m "feat(db): add card_trade_logs table and trade_duplicate_cards RPC"
```

---

## Task 2: Shared + Domain + Data Layer

**Files:**
- Modify: `packages/owlio_shared/lib/src/constants/rpc_functions.dart`
- Modify: `lib/domain/entities/card.dart`
- Modify: `lib/domain/repositories/card_repository.dart`
- Create: `lib/domain/usecases/card/trade_duplicate_cards_usecase.dart`
- Modify: `lib/data/repositories/supabase/supabase_card_repository.dart`

- [ ] **Step 1: Add RPC constant**

In `packages/owlio_shared/lib/src/constants/rpc_functions.dart`, find the Cards section (after `getCardOwnersInClass`) and add:

```dart
  static const tradeDuplicateCards = 'trade_duplicate_cards';
```

- [ ] **Step 2: Add TradeResult entity**

Add at the end of `lib/domain/entities/card.dart`:

```dart
/// Result of a duplicate card trade
class TradeResult extends Equatable {
  const TradeResult({
    required this.receivedCard,
    required this.isNew,
    required this.quantity,
  });

  final MythCard receivedCard;
  final bool isNew;
  final int quantity;

  @override
  List<Object?> get props => [receivedCard, isNew, quantity];
}
```

- [ ] **Step 3: Add repository method**

Add to `lib/domain/repositories/card_repository.dart` before the closing `}`:

```dart
  /// Trade duplicate cards for a higher-rarity card
  Future<Either<Failure, TradeResult>> tradeDuplicateCards(
    String userId, {
    required Map<String, int> cardQuantities,
    required String targetRarity,
    String? idempotencyKey,
  });
```

- [ ] **Step 4: Create UseCase**

Create `lib/domain/usecases/card/trade_duplicate_cards_usecase.dart`:

```dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/card.dart';
import '../../repositories/card_repository.dart';
import '../usecase.dart';

class TradeDuplicateCardsParams {
  const TradeDuplicateCardsParams({
    required this.userId,
    required this.cardQuantities,
    required this.targetRarity,
    this.idempotencyKey,
  });
  final String userId;
  final Map<String, int> cardQuantities;
  final String targetRarity;
  final String? idempotencyKey;
}

class TradeDuplicateCardsUseCase
    implements UseCase<TradeResult, TradeDuplicateCardsParams> {
  const TradeDuplicateCardsUseCase(this._repository);
  final CardRepository _repository;

  @override
  Future<Either<Failure, TradeResult>> call(TradeDuplicateCardsParams params) {
    return _repository.tradeDuplicateCards(
      params.userId,
      cardQuantities: params.cardQuantities,
      targetRarity: params.targetRarity,
      idempotencyKey: params.idempotencyKey,
    );
  }
}
```

- [ ] **Step 5: Implement repository method**

Add to `lib/data/repositories/supabase/supabase_card_repository.dart` before the closing `}`:

```dart
  @override
  Future<Either<Failure, TradeResult>> tradeDuplicateCards(
    String userId, {
    required Map<String, int> cardQuantities,
    required String targetRarity,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.tradeDuplicateCards,
        params: {
          'p_user_id': userId,
          'p_card_quantities': cardQuantities,
          'p_target_rarity': targetRarity,
          if (idempotencyKey != null) 'p_idempotency_key': idempotencyKey,
        },
      );

      final json = response as Map<String, dynamic>;
      final cardJson = json['received_card'] as Map<String, dynamic>;

      final receivedCard = MythCard(
        id: cardJson['id'] as String,
        cardNo: cardJson['card_no'] as String,
        name: cardJson['name'] as String,
        category: CardCategory.fromDbValue(cardJson['category'] as String),
        rarity: CardRarity.fromDbValue(cardJson['rarity'] as String),
        power: (cardJson['power'] as num).toInt(),
        specialSkill: cardJson['special_skill'] as String?,
        description: cardJson['description'] as String?,
        categoryIcon: cardJson['category_icon'] as String?,
        imageUrl: cardJson['image_url'] as String?,
        createdAt: DateTime.utc(2000),
      );

      return Right(TradeResult(
        receivedCard: receivedCard,
        isNew: json['is_new'] as bool,
        quantity: (json['quantity'] as num).toInt(),
      ));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
```

- [ ] **Step 6: Verify**

Run: `dart analyze lib/domain/entities/card.dart lib/domain/repositories/card_repository.dart lib/domain/usecases/card/trade_duplicate_cards_usecase.dart lib/data/repositories/supabase/supabase_card_repository.dart`

- [ ] **Step 7: Commit**

```bash
git add packages/owlio_shared/lib/src/constants/rpc_functions.dart lib/domain/entities/card.dart lib/domain/repositories/card_repository.dart lib/domain/usecases/card/trade_duplicate_cards_usecase.dart lib/data/repositories/supabase/supabase_card_repository.dart
git commit -m "feat(domain): add TradeResult entity, repository method, UseCase for card trade"
```

---

## Task 3: Providers — UseCase Registration + Trade State

**Files:**
- Modify: `lib/presentation/providers/usecase_providers.dart`
- Create: `lib/presentation/providers/card_trade_provider.dart`

- [ ] **Step 1: Register UseCase**

In `lib/presentation/providers/usecase_providers.dart`, add import:

```dart
import '../../domain/usecases/card/trade_duplicate_cards_usecase.dart';
```

Add after `getExclusiveCardsUseCaseProvider` in the CARD USE CASES section:

```dart
final tradeDuplicateCardsUseCaseProvider = Provider((ref) {
  return TradeDuplicateCardsUseCase(ref.watch(cardRepositoryProvider));
});
```

- [ ] **Step 2: Create trade provider**

Create `lib/presentation/providers/card_trade_provider.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/card.dart';
import '../../domain/usecases/card/trade_duplicate_cards_usecase.dart';
import 'auth_provider.dart';
import 'card_provider.dart';
import 'usecase_providers.dart';

/// Trade cost per source rarity
const tradeRequirements = {
  CardRarity.common: (count: 5, target: 'rare'),
  CardRarity.rare: (count: 4, target: 'epic'),
  CardRarity.epic: (count: 3, target: 'legendary'),
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

  final Map<String, int> selectedCards; // cardId → amount selected
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

  /// Add one copy of a card to the selection
  void addCard(String cardId, {required int maxAvailable}) {
    final current = state.selectedCards[cardId] ?? 0;
    if (current >= maxAvailable) return;
    state = state.copyWith(
      selectedCards: {...state.selectedCards, cardId: current + 1},
    );
  }

  /// Remove one copy of a card from the selection
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

  /// Clear all selections
  void clearSelection() {
    state = const TradeSelectionState();
  }

  /// Execute the trade
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
    ));

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
        // Refresh card data
        _ref.invalidate(userCardsProvider);
        _ref.invalidate(userCardStatsProvider);
        _ref.invalidate(classTopCollectorsProvider);
        _ref.invalidate(exclusiveCardsProvider);
      },
    );
  }

  /// Reset after reveal to allow another trade
  void resetAfterReveal() {
    state = const TradeSelectionState();
  }
}
```

- [ ] **Step 3: Verify**

Run: `dart analyze lib/presentation/providers/card_trade_provider.dart lib/presentation/providers/usecase_providers.dart`

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/providers/usecase_providers.dart lib/presentation/providers/card_trade_provider.dart
git commit -m "feat(providers): add trade selection state, tradeable cards providers"
```

---

## Task 4: Trade Screen UI

**Files:**
- Create: `lib/presentation/screens/cards/card_trade_screen.dart`

- [ ] **Step 1: Create the trade screen**

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import '../../providers/card_provider.dart';
import '../../providers/card_trade_provider.dart';
import '../../widgets/cards/myth_card_widget.dart';

class CardTradeScreen extends ConsumerStatefulWidget {
  const CardTradeScreen({super.key});

  @override
  ConsumerState<CardTradeScreen> createState() => _CardTradeScreenState();
}

class _CardTradeScreenState extends ConsumerState<CardTradeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    (source: CardRarity.common, label: 'Common → Rare'),
    (source: CardRarity.rare, label: 'Rare → Epic'),
    (source: CardRarity.epic, label: 'Epic → Legendary'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(tradeSelectionProvider.notifier).clearSelection();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tradeState = ref.watch(tradeSelectionProvider);
    final dupCounts = ref.watch(tradeableDuplicateCountProvider);

    // Show reveal overlay
    if (tradeState.phase == TradePhase.reveal && tradeState.result != null) {
      return _TradeRevealOverlay(result: tradeState.result!);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Trade Duplicates',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            for (final tab in _tabs)
              Tab(
                child: Opacity(
                  opacity: (dupCounts[tab.source] ?? 0) >=
                          (tradeRequirements[tab.source]?.count ?? 99)
                      ? 1.0
                      : 0.4,
                  child: Text(tab.label),
                ),
              ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final tab in _tabs)
            _TradeTab(sourceRarity: tab.source),
        ],
      ),
    );
  }
}

class _TradeTab extends ConsumerWidget {
  const _TradeTab({required this.sourceRarity});
  final CardRarity sourceRarity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(tradeGridCardsProvider(sourceRarity));
    final tradeState = ref.watch(tradeSelectionProvider);
    final req = tradeRequirements[sourceRarity]!;
    final selected = tradeState.totalSelected;
    final isReady = selected == req.count;
    final isTrading = tradeState.phase == TradePhase.trading;

    // Check if user owns all cards of the target rarity
    final userCards = ref.watch(userCardsProvider).valueOrNull ?? [];
    final catalog = ref.watch(cardCatalogProvider).valueOrNull ?? [];
    final targetRarityTotal = catalog.where((c) => c.rarity.dbValue == req.target).length;
    final targetRarityOwned = userCards.where((uc) => uc.card.rarity.dbValue == req.target).length;
    final allTargetOwned = targetRarityTotal > 0 && targetRarityOwned >= targetRarityTotal;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Select ${req.count} ${sourceRarity.label.toLowerCase()} cards to trade for 1 ${req.target} card',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 12),
              // Progress indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$selected / ${req.count}',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isReady ? AppColors.primary : AppColors.neutralText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'selected',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutralText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Warning: all target rarity cards owned
        if (allTargetOwned)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.waspBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.wasp, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You own all ${req.target} cards — you\'ll get a duplicate',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.waspDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Error message
        if (tradeState.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              tradeState.error!,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ),

        // Card grid
        Expanded(
          child: cards.isEmpty
              ? Center(
                  child: Text(
                    'No ${sourceRarity.label.toLowerCase()} cards yet',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      color: AppColors.neutralText,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final uc = cards[index];
                    final maxTradeable = uc.quantity - 1;
                    final selectedCount =
                        tradeState.selectedCards[uc.cardId] ?? 0;
                    final isDisabled = maxTradeable <= 0;

                    return GestureDetector(
                      onTap: isDisabled || isTrading
                          ? null
                          : () {
                              final notifier =
                                  ref.read(tradeSelectionProvider.notifier);
                              if (selectedCount > 0 &&
                                  selectedCount >= maxTradeable) {
                                notifier.removeCard(uc.cardId);
                              } else if (selected < req.count) {
                                notifier.addCard(uc.cardId,
                                    maxAvailable: maxTradeable);
                              }
                            },
                      onLongPress: isDisabled || isTrading || selectedCount == 0
                          ? null
                          : () => ref
                              .read(tradeSelectionProvider.notifier)
                              .removeCard(uc.cardId),
                      child: Opacity(
                        opacity: isDisabled ? 0.4 : 1.0,
                        child: Stack(
                          children: [
                            MythCardWidget(card: uc.card),
                            // Selection overlay
                            if (selectedCount > 0)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppColors.primary,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            // Selection count badge
                            if (selectedCount > 0)
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '-$selectedCount',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            // Available badge (bottom-left for non-disabled)
                            if (!isDisabled && selectedCount == 0)
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'x${uc.quantity}',
                                    style: GoogleFonts.nunito(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            // Lock icon for disabled
                            if (isDisabled)
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.lock_rounded,
                                    size: 14,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Trade button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isReady && !isTrading
                  ? () => ref
                      .read(tradeSelectionProvider.notifier)
                      .executeTrade(sourceRarity)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.neutral,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: isTrading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Trade ${req.count} Cards',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TradeRevealOverlay extends ConsumerWidget {
  const _TradeRevealOverlay({required this.result});
  final TradeResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rarityColor = Color(result.receivedCard.rarity.colorHex);

    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (result.isNew)
                Text(
                  'NEW CARD!',
                  style: GoogleFonts.nunito(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: rarityColor,
                  ),
                )
              else
                Text(
                  'CARD RECEIVED',
                  style: GoogleFonts.nunito(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: MythCardWidget(
                  card: result.receivedCard,
                  showNewBadge: result.isNew,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                result.receivedCard.name,
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: rarityColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: rarityColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  result.receivedCard.rarity.label,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: rarityColor,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  ref.read(tradeSelectionProvider.notifier).resetAfterReveal();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Continue',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `dart analyze lib/presentation/screens/cards/card_trade_screen.dart`

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/cards/card_trade_screen.dart
git commit -m "feat(ui): add card trade screen with tabs, selection, and reveal"
```

---

## Task 5: Trade Button Widget + Panel + Route Integration

**Files:**
- Create: `lib/presentation/widgets/cards/trade_button_card.dart`
- Modify: `lib/presentation/widgets/shell/right_info_panel.dart`
- Modify: `lib/app/router.dart`

- [ ] **Step 1: Create trade button widget**

Create `lib/presentation/widgets/cards/trade_button_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../providers/card_trade_provider.dart';

class TradeButtonCard extends ConsumerWidget {
  const TradeButtonCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canTrade = ref.watch(canTradeProvider);
    if (!canTrade) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.push(AppRoutes.cardTrade),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trade Duplicates',
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),
                  Text(
                    'Upgrade your cards',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutralText,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.neutralDark),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Add to right panel**

In `lib/presentation/widgets/shell/right_info_panel.dart`, add import:

```dart
import '../cards/trade_button_card.dart';
```

Find the cards section (around line 55-63) and add the trade button after RarityShowcaseCard:

```dart
                  if (showPackCard) ...[
                    const _OpenPackCard(),
                    const SizedBox(height: 16),
                    const CollectionProgressCard(),
                    const SizedBox(height: 16),
                    const TopCollectorsCard(),
                    const SizedBox(height: 16),
                    const RarityShowcaseCard(),
                    const SizedBox(height: 16),
                    const TradeButtonCard(),
                    const SizedBox(height: 16),
                  ] else if (isReader) ...[
```

- [ ] **Step 3: Add route**

In `lib/app/router.dart`, add route constant after `packOpening`:

```dart
  static const cardTrade = '/cards/trade';
```

Add import at top:

```dart
import '../presentation/screens/cards/card_trade_screen.dart';
```

Add GoRoute after the packOpening route:

```dart
      // Card trade (full-screen)
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: AppRoutes.cardTrade,
        builder: (context, state) => const CardTradeScreen(),
      ),
```

- [ ] **Step 4: Verify**

Run: `dart analyze lib/presentation/widgets/cards/trade_button_card.dart lib/presentation/widgets/shell/right_info_panel.dart lib/app/router.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/cards/trade_button_card.dart lib/presentation/widgets/shell/right_info_panel.dart lib/app/router.dart
git commit -m "feat(ui): add trade button to panel + route integration"
```

---

## Task Summary

| Task | Description | Dependencies |
|------|-------------|-------------|
| 1 | Database: table + RPC | None |
| 2 | Domain + Data: entity, repository, UseCase, implementation | Task 1 (for push) |
| 3 | Providers: UseCase registration + trade state | Task 2 |
| 4 | Trade screen UI | Task 3 |
| 5 | Trade button widget + panel + route | Tasks 3, 4 |

Tasks 1-2 can overlap (domain doesn't need DB to compile). Tasks 4-5 can be done together after Task 3.
