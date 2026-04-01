# Cards Right Panel Widgets — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 5 card-specific widgets to the right info panel on the Card Collection screen — collection progress, rarity showcase, duplicate counter, top collectors (class leaderboard), and exclusive card owner.

**Architecture:** Widgets 1-3 derive data client-side from existing `userCardsProvider` / `cardCatalogProvider`. Widgets 4-5 require new Supabase RPCs with the standard `Repository → UseCase → Provider` chain. All widgets follow the existing panel card pattern (white container, 16px padding, rounded corners, Nunito typography).

**Tech Stack:** Flutter/Riverpod, Supabase RPC (plpgsql), CachedNetworkImage, Google Fonts

**Spec:** `docs/superpowers/specs/2026-04-01-cards-right-panel-widgets-design.md`

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `supabase/migrations/20260401000001_card_panel_rpcs.sql` | Two RPCs: `get_class_top_collectors`, `get_exclusive_cards` |
| `lib/presentation/widgets/cards/collection_progress_card.dart` | Widget 1: overall + rarity breakdown progress |
| `lib/presentation/widgets/cards/rarity_showcase_card.dart` | Widget 2: top 3 rarest owned cards |
| `lib/presentation/widgets/cards/duplicate_counter_card.dart` | Widget 3: duplicate stats + most duplicated card |
| `lib/presentation/widgets/cards/top_collectors_card.dart` | Widget 4: class top 3 + user rank |
| `lib/presentation/widgets/cards/rarest_card_owner_card.dart` | Widget 5: cards only user owns in class |
| `lib/domain/usecases/card/get_class_top_collectors_usecase.dart` | UseCase for top collectors RPC |
| `lib/domain/usecases/card/get_exclusive_cards_usecase.dart` | UseCase for exclusive cards RPC |

### Modified Files

| File | Change |
|------|--------|
| `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | Add 2 RPC name constants |
| `lib/domain/repositories/card_repository.dart` | Add 2 abstract methods |
| `lib/data/repositories/supabase/supabase_card_repository.dart` | Implement 2 repository methods |
| `lib/presentation/providers/usecase_providers.dart` | Register 2 new UseCase providers |
| `lib/presentation/providers/card_provider.dart` | Add 2 new FutureProviders + 1 computed provider |
| `lib/presentation/widgets/shell/right_info_panel.dart` | Wire 5 widgets into cards route section |

---

## Task 1: Database — Create RPCs

**Files:**
- Create: `supabase/migrations/20260401000001_card_panel_rpcs.sql`

- [ ] **Step 1: Create migration file with both RPCs**

```sql
-- Card panel sidebar RPCs

-- 1. Top collectors in the caller's class (top 3 + caller rank)
CREATE OR REPLACE FUNCTION get_class_top_collectors(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_class_id UUID;
  v_top3 JSONB;
  v_caller JSONB;
BEGIN
  SELECT class_id INTO v_class_id
  FROM profiles WHERE id = p_user_id;

  IF v_class_id IS NULL THEN
    RETURN jsonb_build_object('top3', '[]'::jsonb, 'caller', NULL);
  END IF;

  WITH ranked AS (
    SELECT
      p.id AS user_id,
      p.first_name,
      COUNT(DISTINCT uc.card_id) AS unique_cards,
      ROW_NUMBER() OVER (ORDER BY COUNT(DISTINCT uc.card_id) DESC, p.first_name) AS rank
    FROM profiles p
    LEFT JOIN user_cards uc ON uc.user_id = p.id
    WHERE p.class_id = v_class_id
      AND p.role = 'student'
    GROUP BY p.id, p.first_name
  ),
  top3 AS (
    SELECT * FROM ranked WHERE rank <= 3
  ),
  caller AS (
    SELECT * FROM ranked WHERE user_id = p_user_id
  )
  SELECT
    (SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'user_id', user_id, 'first_name', first_name,
      'unique_cards', unique_cards, 'rank', rank
    )), '[]'::jsonb) FROM top3),
    (SELECT jsonb_build_object(
      'user_id', user_id, 'first_name', first_name,
      'unique_cards', unique_cards, 'rank', rank
    ) FROM caller)
  INTO v_top3, v_caller;

  RETURN jsonb_build_object('top3', v_top3, 'caller', v_caller);
END;
$$;

-- 2. Cards only the caller owns in their class (up to 2, rarest first)
CREATE OR REPLACE FUNCTION get_exclusive_cards(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_class_id UUID;
  v_result JSONB;
BEGIN
  SELECT class_id INTO v_class_id
  FROM profiles WHERE id = p_user_id;

  IF v_class_id IS NULL THEN
    RETURN '[]'::jsonb;
  END IF;

  WITH class_card_owners AS (
    SELECT uc.card_id, COUNT(DISTINCT uc.user_id) AS owner_count
    FROM user_cards uc
    JOIN profiles p ON p.id = uc.user_id
    WHERE p.class_id = v_class_id
      AND p.role = 'student'
    GROUP BY uc.card_id
  ),
  exclusive AS (
    SELECT mc.id, mc.name, mc.category, mc.rarity, mc.power, mc.image_url, mc.card_no
    FROM class_card_owners cco
    JOIN myth_cards mc ON mc.id = cco.card_id
    JOIN user_cards uc ON uc.card_id = cco.card_id AND uc.user_id = p_user_id
    WHERE cco.owner_count = 1
    ORDER BY
      CASE mc.rarity
        WHEN 'legendary' THEN 1
        WHEN 'epic' THEN 2
        WHEN 'rare' THEN 3
        WHEN 'common' THEN 4
      END,
      mc.power DESC
    LIMIT 2
  )
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', id,
    'name', name,
    'category', category,
    'rarity', rarity,
    'power', power,
    'image_url', image_url,
    'card_no', card_no
  )), '[]'::jsonb) INTO v_result
  FROM exclusive;

  RETURN v_result;
END;
$$;
```

- [ ] **Step 2: Dry-run the migration**

Run: `supabase db push --dry-run`
Expected: Migration listed, no errors.

- [ ] **Step 3: Push the migration**

Run: `supabase db push`
Expected: Migration applied successfully.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260401000001_card_panel_rpcs.sql
git commit -m "feat(db): add get_class_top_collectors and get_exclusive_cards RPCs"
```

---

## Task 2: Shared Package — Register RPC Names

**Files:**
- Modify: `packages/owlio_shared/lib/src/constants/rpc_functions.dart`

- [ ] **Step 1: Add RPC constants under the Cards section**

Find the existing Cards section (after `static const openCardPack`), add two new entries:

```dart
  // Cards
  static const buyCardPack = 'buy_card_pack';
  static const openCardPack = 'open_card_pack';
  static const getClassTopCollectors = 'get_class_top_collectors';
  static const getExclusiveCards = 'get_exclusive_cards';
```

- [ ] **Step 2: Commit**

```bash
git add packages/owlio_shared/lib/src/constants/rpc_functions.dart
git commit -m "feat(shared): add card panel RPC constants"
```

---

## Task 3: Domain Layer — Repository Interface + UseCases

**Files:**
- Modify: `lib/domain/repositories/card_repository.dart`
- Create: `lib/domain/usecases/card/get_class_top_collectors_usecase.dart`
- Create: `lib/domain/usecases/card/get_exclusive_cards_usecase.dart`

- [ ] **Step 1: Add new entities to card.dart**

Add these classes at the end of `lib/domain/entities/card.dart`:

```dart
/// A ranked student in the class card leaderboard
class TopCollectorEntry extends Equatable {
  const TopCollectorEntry({
    required this.userId,
    required this.firstName,
    required this.uniqueCards,
    required this.rank,
  });

  final String userId;
  final String firstName;
  final int uniqueCards;
  final int rank;

  @override
  List<Object?> get props => [userId, firstName, uniqueCards, rank];
}

/// Result of get_class_top_collectors RPC
class TopCollectorsResult extends Equatable {
  const TopCollectorsResult({
    required this.top3,
    this.caller,
  });

  final List<TopCollectorEntry> top3;
  final TopCollectorEntry? caller;

  @override
  List<Object?> get props => [top3, caller];
}
```

- [ ] **Step 2: Add abstract methods to CardRepository**

Add before the closing `}` in `lib/domain/repositories/card_repository.dart`:

```dart
  /// Get top 3 card collectors in user's class + caller's rank
  Future<Either<Failure, TopCollectorsResult>> getClassTopCollectors(String userId);

  /// Get cards only this user owns in their class (up to 2)
  Future<Either<Failure, List<MythCard>>> getExclusiveCards(String userId);
```

- [ ] **Step 3: Create GetClassTopCollectorsUseCase**

Create `lib/domain/usecases/card/get_class_top_collectors_usecase.dart`:

```dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/card.dart';
import '../../repositories/card_repository.dart';
import '../usecase.dart';

class GetClassTopCollectorsParams {
  const GetClassTopCollectorsParams({required this.userId});
  final String userId;
}

class GetClassTopCollectorsUseCase
    implements UseCase<TopCollectorsResult, GetClassTopCollectorsParams> {
  const GetClassTopCollectorsUseCase(this._repository);
  final CardRepository _repository;

  @override
  Future<Either<Failure, TopCollectorsResult>> call(
      GetClassTopCollectorsParams params) {
    return _repository.getClassTopCollectors(params.userId);
  }
}
```

- [ ] **Step 4: Create GetExclusiveCardsUseCase**

Create `lib/domain/usecases/card/get_exclusive_cards_usecase.dart`:

```dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/card.dart';
import '../../repositories/card_repository.dart';
import '../usecase.dart';

class GetExclusiveCardsParams {
  const GetExclusiveCardsParams({required this.userId});
  final String userId;
}

class GetExclusiveCardsUseCase
    implements UseCase<List<MythCard>, GetExclusiveCardsParams> {
  const GetExclusiveCardsUseCase(this._repository);
  final CardRepository _repository;

  @override
  Future<Either<Failure, List<MythCard>> > call(GetExclusiveCardsParams params) {
    return _repository.getExclusiveCards(params.userId);
  }
}
```

- [ ] **Step 5: Verify compilation**

Run: `dart analyze lib/domain/usecases/card/ lib/domain/repositories/card_repository.dart lib/domain/entities/card.dart`
Expected: No errors (warnings from other files are OK since repository implementation is not yet updated).

- [ ] **Step 6: Commit**

```bash
git add lib/domain/entities/card.dart lib/domain/repositories/card_repository.dart lib/domain/usecases/card/get_class_top_collectors_usecase.dart lib/domain/usecases/card/get_exclusive_cards_usecase.dart
git commit -m "feat(domain): add TopCollectorsResult entity, repository methods, and UseCases for card panel"
```

---

## Task 4: Data Layer — Repository Implementation

**Files:**
- Modify: `lib/data/repositories/supabase/supabase_card_repository.dart`

- [ ] **Step 1: Add getClassTopCollectors implementation**

Add before the closing `}` of `SupabaseCardRepository`:

```dart
  @override
  Future<Either<Failure, TopCollectorsResult>> getClassTopCollectors(
      String userId) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.getClassTopCollectors,
        params: {'p_user_id': userId},
      );

      final json = response as Map<String, dynamic>;

      TopCollectorEntry parseEntry(Map<String, dynamic> e) {
        return TopCollectorEntry(
          userId: e['user_id'] as String,
          firstName: e['first_name'] as String,
          uniqueCards: (e['unique_cards'] as num).toInt(),
          rank: (e['rank'] as num).toInt(),
        );
      }

      final top3 = (json['top3'] as List)
          .map((e) => parseEntry(e as Map<String, dynamic>))
          .toList();
      final callerJson = json['caller'] as Map<String, dynamic>?;

      return Right(TopCollectorsResult(
        top3: top3,
        caller: callerJson != null ? parseEntry(callerJson) : null,
      ));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
```

- [ ] **Step 2: Add getExclusiveCards implementation**

Add right after `getClassTopCollectors`:

```dart
  @override
  Future<Either<Failure, List<MythCard>>> getExclusiveCards(
      String userId) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.getExclusiveCards,
        params: {'p_user_id': userId},
      );

      final cards = (response as List)
          .map((json) => MythCard(
                id: json['id'] as String,
                cardNo: json['card_no'] as String,
                name: json['name'] as String,
                category: CardCategory.fromDbValue(json['category'] as String),
                rarity: CardRarity.fromDbValue(json['rarity'] as String),
                power: (json['power'] as num).toInt(),
                imageUrl: json['image_url'] as String?,
                createdAt: DateTime.now(), // not returned by RPC, display-only
              ))
          .toList();
      return Right(cards);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
```

- [ ] **Step 3: Verify compilation**

Run: `dart analyze lib/data/repositories/supabase/supabase_card_repository.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/data/repositories/supabase/supabase_card_repository.dart
git commit -m "feat(data): implement getClassTopCollectors and getExclusiveCards in Supabase repository"
```

---

## Task 5: Providers — Register UseCases + Add New Providers

**Files:**
- Modify: `lib/presentation/providers/usecase_providers.dart`
- Modify: `lib/presentation/providers/card_provider.dart`

- [ ] **Step 1: Register UseCases in usecase_providers.dart**

Add the imports at the top:

```dart
import '../../domain/usecases/card/get_class_top_collectors_usecase.dart';
import '../../domain/usecases/card/get_exclusive_cards_usecase.dart';
```

Add after `buyPackUseCaseProvider` in the CARD USE CASES section:

```dart
final getClassTopCollectorsUseCaseProvider = Provider((ref) {
  return GetClassTopCollectorsUseCase(ref.watch(cardRepositoryProvider));
});

final getExclusiveCardsUseCaseProvider = Provider((ref) {
  return GetExclusiveCardsUseCase(ref.watch(cardRepositoryProvider));
});
```

- [ ] **Step 2: Add new providers in card_provider.dart**

Add the imports at the top of `card_provider.dart`:

```dart
import '../../domain/usecases/card/get_class_top_collectors_usecase.dart';
import '../../domain/usecases/card/get_exclusive_cards_usecase.dart';
```

Add after `categoryProgressProvider` (before the `// PACK OPENING CONTROLLER` comment):

```dart
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
```

- [ ] **Step 3: Verify compilation**

Run: `dart analyze lib/presentation/providers/card_provider.dart lib/presentation/providers/usecase_providers.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/providers/usecase_providers.dart lib/presentation/providers/card_provider.dart
git commit -m "feat(providers): add rarityBreakdown, classTopCollectors, exclusiveCards providers"
```

---

## Task 6: Widget 1 — Collection Progress Card

**Files:**
- Create: `lib/presentation/widgets/cards/collection_progress_card.dart`

- [ ] **Step 1: Create the widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import '../../providers/card_provider.dart';

class CollectionProgressCard extends ConsumerWidget {
  const CollectionProgressCard({super.key});

  static const _rarityColors = {
    CardRarity.common: AppColors.cardCommon,
    CardRarity.rare: AppColors.cardRare,
    CardRarity.epic: AppColors.cardEpic,
    CardRarity.legendary: AppColors.cardLegendary,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userCards = ref.watch(userCardsProvider).valueOrNull ?? [];
    final catalog = ref.watch(cardCatalogProvider).valueOrNull ?? [];
    final breakdown = ref.watch(rarityBreakdownProvider);

    final owned = userCards.length;
    final total = catalog.length;
    final progress = total > 0 ? owned / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Collection',
            style: GoogleFonts.nunito(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 12),

          // Main progress
          Row(
            children: [
              Text(
                '$owned',
                style: GoogleFonts.nunito(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.black,
                ),
              ),
              Text(
                ' / $total',
                style: GoogleFonts.nunito(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.neutralDark,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.neutral,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),

          // Rarity breakdown
          for (final rarity in CardRarity.values) ...[
            _buildRarityRow(rarity, breakdown[rarity]!),
            if (rarity != CardRarity.legendary) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildRarityRow(CardRarity rarity, ({int owned, int total}) data) {
    final color = _rarityColors[rarity]!;
    final progress = data.total > 0 ? data.owned / data.total : 0.0;

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            rarity.label,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.neutralText,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.neutral,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            '${data.owned}/${data.total}',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.neutralText,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

Run: `dart analyze lib/presentation/widgets/cards/collection_progress_card.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/cards/collection_progress_card.dart
git commit -m "feat(ui): add CollectionProgressCard widget for right panel"
```

---

## Task 7: Widget 2 — Rarity Showcase Card

**Files:**
- Create: `lib/presentation/widgets/cards/rarity_showcase_card.dart`

- [ ] **Step 1: Create the widget**

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import '../../providers/card_provider.dart';

class RarityShowcaseCard extends ConsumerWidget {
  const RarityShowcaseCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userCards = ref.watch(userCardsProvider).valueOrNull ?? [];
    if (userCards.isEmpty) return const SizedBox.shrink();

    // Sort by rarity desc, then power desc — pick top 3
    final sorted = [...userCards]
      ..sort((a, b) {
        final rarityCompare = b.card.rarity.index.compareTo(a.card.rarity.index);
        if (rarityCompare != 0) return rarityCompare;
        return b.card.power.compareTo(a.card.power);
      });
    final top3 = sorted.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rarest Cards',
            style: GoogleFonts.nunito(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (int i = 0; i < top3.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _buildCardPreview(top3[i].card)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardPreview(MythCard card) {
    final rarityColor = Color(card.rarity.colorHex);

    return Column(
      children: [
        Container(
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: rarityColor, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: card.imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: card.imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => Container(color: rarityColor.withValues(alpha: 0.2)),
                  errorWidget: (context, url, error) => Container(color: rarityColor.withValues(alpha: 0.2)),
                )
              : Container(color: rarityColor.withValues(alpha: 0.2)),
        ),
        const SizedBox(height: 4),
        Text(
          card.name,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          '⚡ ${card.power}',
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: rarityColor,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

Run: `dart analyze lib/presentation/widgets/cards/rarity_showcase_card.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/cards/rarity_showcase_card.dart
git commit -m "feat(ui): add RarityShowcaseCard widget for right panel"
```

---

## Task 8: Widget 3 — Duplicate Counter Card

**Files:**
- Create: `lib/presentation/widgets/cards/duplicate_counter_card.dart`

- [ ] **Step 1: Create the widget**

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import '../../providers/card_provider.dart';

class DuplicateCounterCard extends ConsumerWidget {
  const DuplicateCounterCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userCards = ref.watch(userCardsProvider).valueOrNull ?? [];

    final duplicates = userCards.where((c) => c.quantity > 1).toList();
    final totalExtra =
        duplicates.fold<int>(0, (sum, c) => sum + c.quantity - 1);

    // Find most duplicated card
    UserCard? mostDuplicated;
    if (duplicates.isNotEmpty) {
      mostDuplicated = duplicates.reduce(
          (a, b) => a.quantity >= b.quantity ? a : b);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Duplicates',
            style: GoogleFonts.nunito(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 12),
          if (totalExtra == 0)
            Text(
              'No duplicates yet',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.neutralText,
              ),
            )
          else ...[
            Row(
              children: [
                Text(
                  '$totalExtra',
                  style: GoogleFonts.nunito(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'extra cards',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutralText,
                  ),
                ),
              ],
            ),
            if (mostDuplicated != null) ...[
              const SizedBox(height: 12),
              _buildMostDuplicated(mostDuplicated),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMostDuplicated(UserCard uc) {
    final rarityColor = Color(uc.card.rarity.colorHex);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: rarityColor, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: uc.card.imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: uc.card.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: rarityColor.withValues(alpha: 0.2)),
                  errorWidget: (context, url, error) =>
                      Container(color: rarityColor.withValues(alpha: 0.2)),
                )
              : Container(color: rarityColor.withValues(alpha: 0.2)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            uc.card.name,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: rarityColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'x${uc.quantity}',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: rarityColor,
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

Run: `dart analyze lib/presentation/widgets/cards/duplicate_counter_card.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/cards/duplicate_counter_card.dart
git commit -m "feat(ui): add DuplicateCounterCard widget for right panel"
```

---

## Task 9: Widget 4 — Top Collectors Card

**Files:**
- Create: `lib/presentation/widgets/cards/top_collectors_card.dart`

- [ ] **Step 1: Create the widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/card_provider.dart';

class TopCollectorsCard extends ConsumerWidget {
  const TopCollectorsCard({super.key});

  static const _medalIcons = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(classTopCollectorsProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (result) {
        if (result.top3.isEmpty) return const SizedBox.shrink();

        final userId = ref.watch(currentUserIdProvider);
        final callerInTop3 =
            result.top3.any((e) => e.userId == userId);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.neutral, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top Collectors',
                style: GoogleFonts.nunito(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 12),

              // Top 3 rows
              for (final entry in result.top3) ...[
                _buildRow(
                  entry,
                  isCurrentUser: entry.userId == userId,
                ),
                if (entry != result.top3.last ||
                    (!callerInTop3 && result.caller != null))
                  const SizedBox(height: 8),
              ],

              // Caller row if not in top 3
              if (!callerInTop3 && result.caller != null) ...[
                const Divider(height: 16),
                _buildRow(
                  result.caller!,
                  isCurrentUser: true,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow(TopCollectorEntry entry, {required bool isCurrentUser}) {
    final medal = entry.rank <= 3 ? _medalIcons[entry.rank - 1] : null;

    return Row(
      children: [
        SizedBox(
          width: 28,
          child: medal != null
              ? Text(medal, style: const TextStyle(fontSize: 18))
              : Text(
                  '#${entry.rank}',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutralText,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            entry.firstName,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: isCurrentUser ? FontWeight.w800 : FontWeight.w600,
              color: isCurrentUser ? AppColors.secondary : AppColors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '${entry.uniqueCards} cards',
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.neutralText,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

Run: `dart analyze lib/presentation/widgets/cards/top_collectors_card.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/cards/top_collectors_card.dart
git commit -m "feat(ui): add TopCollectorsCard widget for right panel"
```

---

## Task 10: Widget 5 — Rarest Card Owner Card

**Files:**
- Create: `lib/presentation/widgets/cards/rarest_card_owner_card.dart`

- [ ] **Step 1: Create the widget**

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import '../../providers/card_provider.dart';

class RarestCardOwnerCard extends ConsumerWidget {
  const RarestCardOwnerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(exclusiveCardsProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (cards) {
        if (cards.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.neutral, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Only You Have',
                style: GoogleFonts.nunito(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _buildExclusiveRow(cards[i]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildExclusiveRow(MythCard card) {
    final rarityColor = Color(card.rarity.colorHex);

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: rarityColor, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: card.imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: card.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: rarityColor.withValues(alpha: 0.2)),
                  errorWidget: (context, url, error) =>
                      Container(color: rarityColor.withValues(alpha: 0.2)),
                )
              : Container(color: rarityColor.withValues(alpha: 0.2)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.name,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Only owner in class',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: rarityColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

Run: `dart analyze lib/presentation/widgets/cards/rarest_card_owner_card.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/cards/rarest_card_owner_card.dart
git commit -m "feat(ui): add RarestCardOwnerCard widget for right panel"
```

---

## Task 11: Wire Widgets into Right Info Panel

**Files:**
- Modify: `lib/presentation/widgets/shell/right_info_panel.dart`

- [ ] **Step 1: Add imports at top of right_info_panel.dart**

```dart
import '../cards/collection_progress_card.dart';
import '../cards/rarity_showcase_card.dart';
import '../cards/duplicate_counter_card.dart';
import '../cards/top_collectors_card.dart';
import '../cards/rarest_card_owner_card.dart';
```

- [ ] **Step 2: Replace the cards section in the Column**

Find (around line 52-55):

```dart
                  if (showPackCard) ...[
                    const _OpenPackCard(),
                    const SizedBox(height: 16),
                  ],
```

Replace with:

```dart
                  if (showPackCard) ...[
                    const _OpenPackCard(),
                    const SizedBox(height: 16),
                    const CollectionProgressCard(),
                    const SizedBox(height: 16),
                    const RarityShowcaseCard(),
                    const SizedBox(height: 16),
                    const TopCollectorsCard(),
                    const SizedBox(height: 16),
                    const RarestCardOwnerCard(),
                    const SizedBox(height: 16),
                    const DuplicateCounterCard(),
                    const SizedBox(height: 16),
                  ],
```

- [ ] **Step 3: Verify compilation**

Run: `dart analyze lib/presentation/widgets/shell/right_info_panel.dart`
Expected: No errors.

- [ ] **Step 4: Manual test**

Run the app and navigate to `/cards`. Verify:
1. All 5 widgets appear below the "Buy Booster Pack" card
2. Collection Progress shows correct X/96 count and rarity bars
3. Rarest Cards shows top 3 cards with images
4. Top Collectors shows class ranking (or is hidden if no class)
5. Only You Have shows exclusive cards (or is hidden if none)
6. Duplicates shows correct count (or "No duplicates yet")

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/shell/right_info_panel.dart
git commit -m "feat(ui): wire 5 card widgets into right info panel"
```

---

## Task Summary

| Task | Description | Dependencies |
|------|-------------|-------------|
| 1 | Database RPCs | None |
| 2 | RPC constants in shared package | None |
| 3 | Domain layer (entities, repository interface, UseCases) | None |
| 4 | Data layer (repository implementation) | Tasks 1, 2, 3 |
| 5 | Providers (UseCase registration + new providers) | Tasks 3, 4 |
| 6 | Widget 1: Collection Progress | Task 5 |
| 7 | Widget 2: Rarity Showcase | Task 5 |
| 8 | Widget 3: Duplicate Counter | Task 5 |
| 9 | Widget 4: Top Collectors | Task 5 |
| 10 | Widget 5: Rarest Card Owner | Task 5 |
| 11 | Wire all widgets into panel | Tasks 6-10 |

Tasks 1-3 can run in parallel. Tasks 6-10 can run in parallel after Task 5.
