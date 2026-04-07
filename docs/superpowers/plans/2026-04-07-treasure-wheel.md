# Treasure Wheel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform learning path treasure nodes into a Spin the Wheel experience that awards coins or card packs via a server-side atomic RPC.

**Architecture:** Single atomic RPC (`spin_treasure_wheel`) handles weighted random selection + reward + node completion. Flutter `CustomPainter` wheel renders dynamically from admin-configured slices. Clean Architecture layers: Entity → Model → Repository → UseCase → Provider → Screen.

**Tech Stack:** Flutter (CustomPainter, AnimationController), Riverpod StateNotifier, Supabase RPC (plpgsql), go_router navigation.

**Spec:** `docs/superpowers/specs/2026-04-07-treasure-wheel-design.md`

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `supabase/migrations/20260408000001_treasure_wheel.sql` | Table + RPC + RLS |
| `packages/owlio_shared/lib/src/constants/tables.dart` | Add `treasureWheelSlices` constant |
| `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | Add `spinTreasureWheel` constant |
| `lib/domain/entities/treasure_wheel.dart` | `TreasureWheelSlice` + `TreasureSpinResult` entities |
| `lib/domain/repositories/treasure_repository.dart` | Abstract repository interface |
| `lib/domain/usecases/treasure/get_wheel_slices_usecase.dart` | Fetch active slices |
| `lib/domain/usecases/treasure/spin_treasure_wheel_usecase.dart` | Execute spin |
| `lib/data/models/treasure/treasure_wheel_slice_model.dart` | Slice JSON ↔ Entity |
| `lib/data/models/treasure/treasure_spin_result_model.dart` | Spin result JSON ↔ Entity |
| `lib/data/repositories/supabase/supabase_treasure_repository.dart` | Supabase implementation |
| `lib/presentation/providers/treasure_wheel_provider.dart` | State management |
| `lib/presentation/screens/treasure/treasure_wheel_screen.dart` | Full screen with wheel + reward |
| `lib/presentation/widgets/treasure/treasure_wheel_painter.dart` | CustomPainter for the wheel |
| `owlio_admin/lib/features/treasure_wheel/screens/treasure_wheel_config_screen.dart` | Admin CRUD |

### Modified Files

| File | Change |
|------|--------|
| `packages/owlio_shared/lib/src/constants/tables.dart:82` | Add `treasureWheelSlices` |
| `packages/owlio_shared/lib/src/constants/rpc_functions.dart:81` | Add `spinTreasureWheel` |
| `lib/presentation/providers/repository_providers.dart:164` | Add `treasureRepositoryProvider` |
| `lib/presentation/providers/usecase_providers.dart:775` | Add treasure usecase providers |
| `lib/app/router.dart:77` | Add treasure wheel route |
| `lib/presentation/widgets/learning_path/learning_path.dart:232-240` | Change treasure onTap to navigate |
| `lib/presentation/screens/vocabulary/fullscreen_unit_detail_screen.dart:309-318` | Change treasure onTap to navigate |
| `owlio_admin/lib/core/router.dart:366` | Add treasure wheel admin route |
| `owlio_admin/lib/features/dashboard/screens/dashboard_screen.dart:215` | Add dashboard card |

---

## Task 1: Database Migration — Table + RPC + RLS

**Files:**
- Create: `supabase/migrations/20260408000001_treasure_wheel.sql`

- [ ] **Step 1: Write the migration SQL**

```sql
-- =============================================
-- TREASURE WHEEL: Table + RPC + RLS
-- Spec: docs/superpowers/specs/2026-04-07-treasure-wheel-design.md
-- =============================================

-- ===== 1. TABLE =====

CREATE TABLE treasure_wheel_slices (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    label       TEXT NOT NULL,
    reward_type TEXT NOT NULL CHECK (reward_type IN ('coin', 'card_pack')),
    reward_amount INTEGER NOT NULL CHECK (reward_amount > 0),
    weight      INTEGER NOT NULL CHECK (weight > 0),
    color       TEXT NOT NULL,
    sort_order  INTEGER NOT NULL DEFAULT 0,
    is_active   BOOLEAN NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ===== 2. RLS =====

ALTER TABLE treasure_wheel_slices ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read (students need slices to render the wheel)
CREATE POLICY "Authenticated users can read wheel slices"
    ON treasure_wheel_slices FOR SELECT
    TO authenticated
    USING (true);

-- Only admins can modify
CREATE POLICY "Admins can insert wheel slices"
    ON treasure_wheel_slices FOR INSERT
    TO authenticated
    WITH CHECK (is_admin());

CREATE POLICY "Admins can update wheel slices"
    ON treasure_wheel_slices FOR UPDATE
    TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

CREATE POLICY "Admins can delete wheel slices"
    ON treasure_wheel_slices FOR DELETE
    TO authenticated
    USING (is_admin());

-- ===== 3. SEED DEFAULT SLICES =====

INSERT INTO treasure_wheel_slices (label, reward_type, reward_amount, weight, color, sort_order) VALUES
    ('10 Coins',     'coin',      10,  40, '#4CAF50', 0),
    ('25 Coins',     'coin',      25,  25, '#2196F3', 1),
    ('50 Coins',     'coin',      50,  15, '#9C27B0', 2),
    ('100 Coins',    'coin',     100,   7, '#FF9800', 3),
    ('1 Card Pack',  'card_pack',  1,  10, '#E91E63', 4),
    ('2 Card Packs', 'card_pack',  2,   3, '#F44336', 5);

-- ===== 4. RPC: spin_treasure_wheel =====

CREATE OR REPLACE FUNCTION spin_treasure_wheel(
    p_user_id UUID,
    p_unit_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_existing BOOLEAN;
    v_slices RECORD;
    v_total_weight INTEGER;
    v_roll DOUBLE PRECISION;
    v_cumulative INTEGER := 0;
    v_winning_slice RECORD;
    v_winning_index INTEGER := 0;
    v_current_index INTEGER := 0;
    v_all_cards JSONB := '[]'::JSONB;
    v_pack_result JSONB;
    v_i INTEGER;
BEGIN
    -- Auth check
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized: user mismatch';
    END IF;

    -- Duplicate check: already claimed this treasure?
    SELECT EXISTS(
        SELECT 1 FROM user_node_completions
        WHERE user_id = p_user_id
          AND unit_id = p_unit_id
          AND node_type = 'treasure'
    ) INTO v_existing;

    IF v_existing THEN
        RAISE EXCEPTION 'ALREADY_CLAIMED';
    END IF;

    -- Get total weight of active slices
    SELECT COALESCE(SUM(weight), 0) INTO v_total_weight
    FROM treasure_wheel_slices
    WHERE is_active = true;

    IF v_total_weight = 0 THEN
        RAISE EXCEPTION 'No active wheel slices configured';
    END IF;

    -- Weighted random selection
    v_roll := random() * v_total_weight;

    FOR v_slices IN
        SELECT id, label, reward_type, reward_amount, weight, color, sort_order
        FROM treasure_wheel_slices
        WHERE is_active = true
        ORDER BY sort_order
    LOOP
        v_cumulative := v_cumulative + v_slices.weight;
        IF v_roll <= v_cumulative THEN
            v_winning_slice := v_slices;
            v_winning_index := v_current_index;
            EXIT;
        END IF;
        v_current_index := v_current_index + 1;
    END LOOP;

    -- Fallback: if somehow no slice was selected (rounding), pick last
    IF v_winning_slice IS NULL THEN
        SELECT id, label, reward_type, reward_amount, weight, color, sort_order
        INTO v_winning_slice
        FROM treasure_wheel_slices
        WHERE is_active = true
        ORDER BY sort_order DESC
        LIMIT 1;
        v_winning_index := v_current_index;
    END IF;

    -- Award the reward
    IF v_winning_slice.reward_type = 'coin' THEN
        -- Award coins using existing function
        PERFORM award_coins_transaction(
            p_user_id,
            v_winning_slice.reward_amount,
            'treasure_wheel',
            p_unit_id::TEXT,
            v_winning_slice.label
        );

    ELSIF v_winning_slice.reward_type = 'card_pack' THEN
        -- Add packs to inventory, then open each one
        UPDATE profiles
        SET unopened_packs = unopened_packs + v_winning_slice.reward_amount,
            updated_at = NOW()
        WHERE id = p_user_id;

        -- Open each pack and collect cards
        FOR v_i IN 1..v_winning_slice.reward_amount LOOP
            v_pack_result := open_card_pack(p_user_id);
            v_all_cards := v_all_cards || (v_pack_result->'cards');
        END LOOP;
    END IF;

    -- Mark treasure as completed
    INSERT INTO user_node_completions (user_id, unit_id, node_type)
    VALUES (p_user_id, p_unit_id, 'treasure');

    -- Return result
    RETURN jsonb_build_object(
        'slice_index', v_winning_index,
        'slice_label', v_winning_slice.label,
        'reward_type', v_winning_slice.reward_type,
        'reward_amount', v_winning_slice.reward_amount,
        'cards', v_all_cards
    );
END;
$$;
```

- [ ] **Step 2: Dry-run the migration**

Run: `supabase db push --dry-run`
Expected: Preview shows CREATE TABLE, CREATE POLICY, CREATE FUNCTION — no errors.

- [ ] **Step 3: Push the migration**

Run: `supabase db push`
Expected: Migration applied successfully.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260408000001_treasure_wheel.sql
git commit -m "feat(db): add treasure_wheel_slices table and spin_treasure_wheel RPC"
```

---

## Task 2: Shared Package Constants

**Files:**
- Modify: `packages/owlio_shared/lib/src/constants/tables.dart:82`
- Modify: `packages/owlio_shared/lib/src/constants/rpc_functions.dart:81`

- [ ] **Step 1: Add table constant**

In `packages/owlio_shared/lib/src/constants/tables.dart`, add after the `tileThemes` line (line 82):

```dart
  // Treasure Wheel
  static const treasureWheelSlices = 'treasure_wheel_slices';
```

- [ ] **Step 2: Add RPC constant**

In `packages/owlio_shared/lib/src/constants/rpc_functions.dart`, add after the `unequipAvatarItem` line (line 81):

```dart
  // Treasure Wheel
  static const spinTreasureWheel = 'spin_treasure_wheel';
```

- [ ] **Step 3: Run pub get to verify**

Run: `cd /Users/wonderelt/Desktop/Owlio && flutter pub get`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add packages/owlio_shared/lib/src/constants/tables.dart packages/owlio_shared/lib/src/constants/rpc_functions.dart
git commit -m "feat(shared): add treasure wheel table and RPC constants"
```

---

## Task 3: Domain Layer — Entities + Repository Interface + UseCases

**Files:**
- Create: `lib/domain/entities/treasure_wheel.dart`
- Create: `lib/domain/repositories/treasure_repository.dart`
- Create: `lib/domain/usecases/treasure/get_wheel_slices_usecase.dart`
- Create: `lib/domain/usecases/treasure/spin_treasure_wheel_usecase.dart`

- [ ] **Step 1: Create entities**

Create `lib/domain/entities/treasure_wheel.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'card.dart';

/// A single slice on the treasure wheel (from admin config)
class TreasureWheelSlice extends Equatable {
  const TreasureWheelSlice({
    required this.id,
    required this.label,
    required this.rewardType,
    required this.rewardAmount,
    required this.weight,
    required this.color,
    required this.sortOrder,
  });

  final String id;
  final String label;
  final String rewardType; // 'coin' or 'card_pack'
  final int rewardAmount;
  final int weight;
  final String color; // hex color
  final int sortOrder;

  @override
  List<Object?> get props => [id, label, rewardType, rewardAmount, weight, color, sortOrder];
}

/// Result of spinning the treasure wheel
class TreasureSpinResult extends Equatable {
  const TreasureSpinResult({
    required this.sliceIndex,
    required this.sliceLabel,
    required this.rewardType,
    required this.rewardAmount,
    this.cards,
  });

  final int sliceIndex;
  final String sliceLabel;
  final String rewardType;
  final int rewardAmount;
  final List<PackCard>? cards; // populated only for card_pack rewards

  @override
  List<Object?> get props => [sliceIndex, sliceLabel, rewardType, rewardAmount, cards];
}
```

- [ ] **Step 2: Create repository interface**

Create `lib/domain/repositories/treasure_repository.dart`:

```dart
import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/treasure_wheel.dart';

abstract class TreasureRepository {
  /// Get all active wheel slices for rendering
  Future<Either<Failure, List<TreasureWheelSlice>>> getWheelSlices();

  /// Spin the wheel: weighted random selection + award + mark complete
  Future<Either<Failure, TreasureSpinResult>> spinWheel({
    required String userId,
    required String unitId,
  });
}
```

- [ ] **Step 3: Create GetWheelSlicesUseCase**

Create `lib/domain/usecases/treasure/get_wheel_slices_usecase.dart`:

```dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/treasure_wheel.dart';
import '../../repositories/treasure_repository.dart';
import '../usecase.dart';

class GetWheelSlicesUseCase implements UseCase<List<TreasureWheelSlice>, NoParams> {
  const GetWheelSlicesUseCase(this._repository);
  final TreasureRepository _repository;

  @override
  Future<Either<Failure, List<TreasureWheelSlice>>> call(NoParams params) {
    return _repository.getWheelSlices();
  }
}
```

- [ ] **Step 4: Create SpinTreasureWheelUseCase**

Create `lib/domain/usecases/treasure/spin_treasure_wheel_usecase.dart`:

```dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/treasure_wheel.dart';
import '../../repositories/treasure_repository.dart';
import '../usecase.dart';

class SpinTreasureWheelParams {
  const SpinTreasureWheelParams({required this.userId, required this.unitId});
  final String userId;
  final String unitId;
}

class SpinTreasureWheelUseCase implements UseCase<TreasureSpinResult, SpinTreasureWheelParams> {
  const SpinTreasureWheelUseCase(this._repository);
  final TreasureRepository _repository;

  @override
  Future<Either<Failure, TreasureSpinResult>> call(SpinTreasureWheelParams params) {
    return _repository.spinWheel(userId: params.userId, unitId: params.unitId);
  }
}
```

- [ ] **Step 5: Verify with dart analyze**

Run: `dart analyze lib/domain/entities/treasure_wheel.dart lib/domain/repositories/treasure_repository.dart lib/domain/usecases/treasure/`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/entities/treasure_wheel.dart lib/domain/repositories/treasure_repository.dart lib/domain/usecases/treasure/
git commit -m "feat: add treasure wheel domain layer (entities, repository, usecases)"
```

---

## Task 4: Data Layer — Models + Repository Implementation

**Files:**
- Create: `lib/data/models/treasure/treasure_wheel_slice_model.dart`
- Create: `lib/data/models/treasure/treasure_spin_result_model.dart`
- Create: `lib/data/repositories/supabase/supabase_treasure_repository.dart`

- [ ] **Step 1: Create TreasureWheelSliceModel**

Create `lib/data/models/treasure/treasure_wheel_slice_model.dart`:

```dart
import '../../../domain/entities/treasure_wheel.dart';

class TreasureWheelSliceModel {
  const TreasureWheelSliceModel({
    required this.id,
    required this.label,
    required this.rewardType,
    required this.rewardAmount,
    required this.weight,
    required this.color,
    required this.sortOrder,
  });

  factory TreasureWheelSliceModel.fromJson(Map<String, dynamic> json) {
    return TreasureWheelSliceModel(
      id: json['id'] as String,
      label: json['label'] as String,
      rewardType: json['reward_type'] as String,
      rewardAmount: (json['reward_amount'] as num).toInt(),
      weight: (json['weight'] as num).toInt(),
      color: json['color'] as String,
      sortOrder: (json['sort_order'] as num).toInt(),
    );
  }

  final String id;
  final String label;
  final String rewardType;
  final int rewardAmount;
  final int weight;
  final String color;
  final int sortOrder;

  TreasureWheelSlice toEntity() {
    return TreasureWheelSlice(
      id: id,
      label: label,
      rewardType: rewardType,
      rewardAmount: rewardAmount,
      weight: weight,
      color: color,
      sortOrder: sortOrder,
    );
  }
}
```

- [ ] **Step 2: Create TreasureSpinResultModel**

Create `lib/data/models/treasure/treasure_spin_result_model.dart`:

```dart
import '../../../domain/entities/card.dart';
import '../../../domain/entities/treasure_wheel.dart';
import '../card/myth_card_model.dart';

class TreasureSpinResultModel {
  const TreasureSpinResultModel({
    required this.sliceIndex,
    required this.sliceLabel,
    required this.rewardType,
    required this.rewardAmount,
    this.cards,
  });

  factory TreasureSpinResultModel.fromJson(Map<String, dynamic> json) {
    List<PackCard>? cards;
    final cardsJson = json['cards'];
    if (cardsJson != null && cardsJson is List && cardsJson.isNotEmpty) {
      cards = cardsJson.map((c) {
        final cardJson = c as Map<String, dynamic>;
        return PackCard(
          card: MythCardModel.fromJson({
            'id': cardJson['id'],
            'card_no': cardJson['card_no'] ?? '',
            'name': cardJson['name'] ?? '',
            'category': cardJson['category'] ?? '',
            'rarity': cardJson['rarity'] ?? 'common',
            'power': cardJson['power'] ?? 0,
            'special_skill': cardJson['special_skill'],
            'description': cardJson['description'],
            'category_icon': cardJson['category_icon'],
            'is_active': true,
            'image_url': cardJson['image_url'],
            'created_at': cardJson['created_at'] ?? DateTime.now().toIso8601String(),
          }).toEntity(),
          isNew: cardJson['is_new'] as bool? ?? false,
          currentQuantity: (cardJson['quantity'] as num?)?.toInt() ?? 1,
        );
      }).toList();
    }

    return TreasureSpinResultModel(
      sliceIndex: (json['slice_index'] as num).toInt(),
      sliceLabel: json['slice_label'] as String,
      rewardType: json['reward_type'] as String,
      rewardAmount: (json['reward_amount'] as num).toInt(),
      cards: cards,
    );
  }

  final int sliceIndex;
  final String sliceLabel;
  final String rewardType;
  final int rewardAmount;
  final List<PackCard>? cards;

  TreasureSpinResult toEntity() {
    return TreasureSpinResult(
      sliceIndex: sliceIndex,
      sliceLabel: sliceLabel,
      rewardType: rewardType,
      rewardAmount: rewardAmount,
      cards: cards,
    );
  }
}
```

- [ ] **Step 3: Create SupabaseTreasureRepository**

Create `lib/data/repositories/supabase/supabase_treasure_repository.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/treasure_wheel.dart';
import '../../../domain/repositories/treasure_repository.dart';
import '../../models/treasure/treasure_spin_result_model.dart';
import '../../models/treasure/treasure_wheel_slice_model.dart';

class SupabaseTreasureRepository implements TreasureRepository {
  SupabaseTreasureRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, List<TreasureWheelSlice>>> getWheelSlices() async {
    try {
      final response = await _supabase
          .from(DbTables.treasureWheelSlices)
          .select()
          .eq('is_active', true)
          .order('sort_order');

      final slices = (response as List)
          .map((json) => TreasureWheelSliceModel.fromJson(json).toEntity())
          .toList();

      return Right(slices);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, TreasureSpinResult>> spinWheel({
    required String userId,
    required String unitId,
  }) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.spinTreasureWheel,
        params: {
          'p_user_id': userId,
          'p_unit_id': unitId,
        },
      );

      final result = TreasureSpinResultModel.fromJson(response as Map<String, dynamic>);
      return Right(result.toEntity());
    } on PostgrestException catch (e) {
      if (e.message.contains('ALREADY_CLAIMED')) {
        return const Left(ServerFailure('Treasure already claimed', code: 'ALREADY_CLAIMED'));
      }
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
```

- [ ] **Step 4: Verify with dart analyze**

Run: `dart analyze lib/data/models/treasure/ lib/data/repositories/supabase/supabase_treasure_repository.dart`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/treasure/ lib/data/repositories/supabase/supabase_treasure_repository.dart
git commit -m "feat: add treasure wheel data layer (models, Supabase repository)"
```

---

## Task 5: Provider Registration

**Files:**
- Modify: `lib/presentation/providers/repository_providers.dart:164`
- Modify: `lib/presentation/providers/usecase_providers.dart:775`

- [ ] **Step 1: Register repository provider**

In `lib/presentation/providers/repository_providers.dart`, add import at top:

```dart
import '../../data/repositories/supabase/supabase_treasure_repository.dart';
import '../../domain/repositories/treasure_repository.dart';
```

Add after `tileThemeRepositoryProvider` (after line 164):

```dart
final treasureRepositoryProvider = Provider<TreasureRepository>((ref) {
  return SupabaseTreasureRepository();
});
```

- [ ] **Step 2: Register usecase providers**

In `lib/presentation/providers/usecase_providers.dart`, add imports at top:

```dart
import '../../domain/usecases/treasure/get_wheel_slices_usecase.dart';
import '../../domain/usecases/treasure/spin_treasure_wheel_usecase.dart';
```

Add at end of file (before the closing, after tile theme section):

```dart
// ============================================
// TREASURE WHEEL USE CASES
// ============================================

final getWheelSlicesUseCaseProvider = Provider((ref) {
  return GetWheelSlicesUseCase(ref.watch(treasureRepositoryProvider));
});

final spinTreasureWheelUseCaseProvider = Provider((ref) {
  return SpinTreasureWheelUseCase(ref.watch(treasureRepositoryProvider));
});
```

- [ ] **Step 3: Verify with dart analyze**

Run: `dart analyze lib/presentation/providers/repository_providers.dart lib/presentation/providers/usecase_providers.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/providers/repository_providers.dart lib/presentation/providers/usecase_providers.dart
git commit -m "feat: register treasure wheel repository and usecase providers"
```

---

## Task 6: Treasure Wheel Provider (State Management)

**Files:**
- Create: `lib/presentation/providers/treasure_wheel_provider.dart`

- [ ] **Step 1: Create the provider**

Create `lib/presentation/providers/treasure_wheel_provider.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/treasure_wheel.dart';
import '../../domain/usecases/treasure/spin_treasure_wheel_usecase.dart';
import '../../domain/usecases/usecase.dart';
import 'usecase_providers.dart';
import 'user_provider.dart';
import 'vocabulary_provider.dart';

enum TreasureWheelPhase {
  loading,
  ready,
  spinning,
  revealing,
  rewarded,
  completed,
  error,
}

class TreasureWheelState {
  const TreasureWheelState({
    this.phase = TreasureWheelPhase.loading,
    this.slices = const [],
    this.result,
    this.errorMessage,
  });

  final TreasureWheelPhase phase;
  final List<TreasureWheelSlice> slices;
  final TreasureSpinResult? result;
  final String? errorMessage;

  TreasureWheelState copyWith({
    TreasureWheelPhase? phase,
    List<TreasureWheelSlice>? slices,
    TreasureSpinResult? result,
    String? errorMessage,
  }) {
    return TreasureWheelState(
      phase: phase ?? this.phase,
      slices: slices ?? this.slices,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class TreasureWheelController extends StateNotifier<TreasureWheelState> {
  TreasureWheelController(this._ref) : super(const TreasureWheelState());

  final Ref _ref;

  Future<void> loadSlices() async {
    state = state.copyWith(phase: TreasureWheelPhase.loading);

    final useCase = _ref.read(getWheelSlicesUseCaseProvider);
    final result = await useCase(const NoParams());

    result.fold(
      (failure) {
        state = state.copyWith(
          phase: TreasureWheelPhase.error,
          errorMessage: failure.message,
        );
      },
      (slices) {
        if (slices.length < 2) {
          state = state.copyWith(
            phase: TreasureWheelPhase.error,
            errorMessage: 'No rewards available',
          );
          return;
        }
        state = state.copyWith(
          phase: TreasureWheelPhase.ready,
          slices: slices,
        );
      },
    );
  }

  Future<void> spin(String unitId) async {
    if (state.phase != TreasureWheelPhase.ready) return;

    state = state.copyWith(phase: TreasureWheelPhase.spinning);

    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = state.copyWith(
        phase: TreasureWheelPhase.error,
        errorMessage: 'Not logged in',
      );
      return;
    }

    final useCase = _ref.read(spinTreasureWheelUseCaseProvider);
    final result = await useCase(
      SpinTreasureWheelParams(userId: userId, unitId: unitId),
    );

    result.fold(
      (failure) {
        debugPrint('Treasure spin error: ${failure.message}');
        state = state.copyWith(
          phase: TreasureWheelPhase.error,
          errorMessage: failure.message,
        );
      },
      (spinResult) {
        state = state.copyWith(
          phase: TreasureWheelPhase.revealing,
          result: spinResult,
        );
      },
    );
  }

  void showReward() {
    state = state.copyWith(phase: TreasureWheelPhase.rewarded);
  }

  void complete() {
    _ref.invalidate(nodeCompletionsProvider);
    _ref.invalidate(currentUserProvider);
    state = state.copyWith(phase: TreasureWheelPhase.completed);
  }
}

final treasureWheelControllerProvider =
    StateNotifierProvider.autoDispose<TreasureWheelController, TreasureWheelState>(
  (ref) => TreasureWheelController(ref),
);
```

- [ ] **Step 2: Verify with dart analyze**

Run: `dart analyze lib/presentation/providers/treasure_wheel_provider.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/providers/treasure_wheel_provider.dart
git commit -m "feat: add treasure wheel state management provider"
```

---

## Task 7: Treasure Wheel CustomPainter

**Files:**
- Create: `lib/presentation/widgets/treasure/treasure_wheel_painter.dart`

- [ ] **Step 1: Create the wheel painter widget**

Create `lib/presentation/widgets/treasure/treasure_wheel_painter.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/entities/treasure_wheel.dart';

/// Parses a hex color string like '#FF9800' to a Color
Color _hexToColor(String hex) {
  hex = hex.replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

/// The spinning wheel widget with pointer
class TreasureWheelWidget extends StatefulWidget {
  const TreasureWheelWidget({
    super.key,
    required this.slices,
    this.targetSliceIndex,
    this.onSpinComplete,
  });

  final List<TreasureWheelSlice> slices;
  final int? targetSliceIndex;
  final VoidCallback? onSpinComplete;

  @override
  State<TreasureWheelWidget> createState() => TreasureWheelWidgetState();
}

class TreasureWheelWidgetState extends State<TreasureWheelWidget>
    with TickerProviderStateMixin {
  late AnimationController _idleController;
  late AnimationController _spinController;
  double _currentAngle = 0;
  bool _isIdleSpinning = false;

  @override
  void initState() {
    super.initState();
    // Idle spin: continuous fast rotation while waiting for RPC
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _idleController.addListener(() {
      if (_isIdleSpinning) {
        setState(() {
          _currentAngle += 0.15; // ~9 degrees per frame tick
        });
      }
    });

    // Final spin: decelerate to target
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
  }

  @override
  void dispose() {
    _idleController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  /// Start continuous fast rotation (called when Spin button is pressed)
  void startIdleSpin() {
    _isIdleSpinning = true;
    _idleController.repeat();
  }

  /// Stop idle spin and decelerate to land on the target slice
  void spinTo(int targetIndex) {
    // Stop idle rotation
    _isIdleSpinning = false;
    _idleController.stop();

    final sliceCount = widget.slices.length;
    final sliceAngle = 2 * math.pi / sliceCount;

    // The pointer is at the top (12 o'clock = -pi/2).
    // Target angle: negative rotation to bring target slice under pointer.
    final random = math.Random();
    final offsetInSlice = (random.nextDouble() * 0.6 + 0.2) * sliceAngle; // 20-80% of slice
    final targetAngle = -(targetIndex * sliceAngle + offsetInSlice);

    // Add 4 full rotations for dramatic deceleration from current position
    final totalRotation = targetAngle - _currentAngle + (4 * 2 * math.pi);

    final tween = Tween<double>(begin: 0, end: totalRotation);
    final curved = CurvedAnimation(parent: _spinController, curve: Curves.easeOutCubic);

    _spinController.reset();
    final animation = tween.animate(curved);

    final startAngle = _currentAngle;
    animation.addListener(() {
      setState(() {
        _currentAngle = startAngle + animation.value;
      });
    });

    _spinController.forward().then((_) {
      widget.onSpinComplete?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pointer triangle at top
        CustomPaint(
          size: const Size(30, 20),
          painter: _PointerPainter(),
        ),
        const SizedBox(height: 4),
        // Wheel
        SizedBox(
          width: 300,
          height: 300,
          child: Transform.rotate(
            angle: _currentAngle,
            child: CustomPaint(
              size: const Size(300, 300),
              painter: _WheelPainter(slices: widget.slices),
            ),
          ),
        ),
      ],
    );
  }
}

/// Draws the wheel slices
class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.slices});

  final List<TreasureWheelSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sliceAngle = 2 * math.pi / slices.length;

    for (int i = 0; i < slices.length; i++) {
      final startAngle = -math.pi / 2 + i * sliceAngle;
      final paint = Paint()
        ..color = _hexToColor(slices[i].color)
        ..style = PaintingStyle.fill;

      // Draw slice arc
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sliceAngle,
        true,
        paint,
      );

      // Draw border
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sliceAngle,
        true,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      // Draw label text
      final textAngle = startAngle + sliceAngle / 2;
      final textRadius = radius * 0.65;
      final textX = center.dx + textRadius * math.cos(textAngle);
      final textY = center.dy + textRadius * math.sin(textAngle);

      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(textAngle + math.pi / 2);

      final textPainter = TextPainter(
        text: TextSpan(
          text: slices[i].label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 2, color: Colors.black54)],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout(maxWidth: radius * 0.5);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }

    // Draw center circle
    canvas.drawCircle(
      center,
      20,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      center,
      20,
      Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) {
    return oldDelegate.slices != slices;
  }
}

/// Draws the pointer triangle above the wheel
class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(
      path,
      Paint()..color = Colors.red,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.red.shade900
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

- [ ] **Step 2: Verify with dart analyze**

Run: `dart analyze lib/presentation/widgets/treasure/treasure_wheel_painter.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/treasure/treasure_wheel_painter.dart
git commit -m "feat: add treasure wheel CustomPainter widget"
```

---

## Task 8: Treasure Wheel Screen

**Files:**
- Create: `lib/presentation/screens/treasure/treasure_wheel_screen.dart`

- [ ] **Step 1: Create the screen**

Create `lib/presentation/screens/treasure/treasure_wheel_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/treasure_wheel_provider.dart';
import '../../widgets/treasure/treasure_wheel_painter.dart';

class TreasureWheelScreen extends ConsumerStatefulWidget {
  const TreasureWheelScreen({super.key, required this.unitId});

  final String unitId;

  @override
  ConsumerState<TreasureWheelScreen> createState() => _TreasureWheelScreenState();
}

class _TreasureWheelScreenState extends ConsumerState<TreasureWheelScreen> {
  final _wheelKey = GlobalKey<TreasureWheelWidgetState>();

  @override
  void initState() {
    super.initState();
    // Load slices on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(treasureWheelControllerProvider.notifier).loadSlices();
    });
  }

  void _onSpin() {
    // Start wheel spinning immediately for visual feedback
    _wheelKey.currentState?.startIdleSpin();
    // Fire RPC in parallel
    final controller = ref.read(treasureWheelControllerProvider.notifier);
    controller.spin(widget.unitId);
  }

  void _onSpinAnimationComplete() {
    final state = ref.read(treasureWheelControllerProvider);
    if (state.phase == TreasureWheelPhase.revealing) {
      // Short delay before showing reward
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          ref.read(treasureWheelControllerProvider.notifier).showReward();
        }
      });
    }
  }

  void _onClaim() {
    ref.read(treasureWheelControllerProvider.notifier).complete();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(treasureWheelControllerProvider);

    // When RPC returns during spin, start the wheel animation to target
    ref.listen<TreasureWheelState>(treasureWheelControllerProvider, (prev, next) {
      if (prev?.phase == TreasureWheelPhase.spinning &&
          next.phase == TreasureWheelPhase.revealing &&
          next.result != null) {
        _wheelKey.currentState?.spinTo(next.result!.sliceIndex);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: state.phase == TreasureWheelPhase.spinning
            ? const SizedBox.shrink() // Prevent back during spin
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: _buildBody(state),
        ),
      ),
    );
  }

  Widget _buildBody(TreasureWheelState state) {
    switch (state.phase) {
      case TreasureWheelPhase.loading:
        return const CircularProgressIndicator(color: Colors.amber);

      case TreasureWheelPhase.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              state.errorMessage ?? 'Something went wrong',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        );

      case TreasureWheelPhase.ready:
      case TreasureWheelPhase.spinning:
      case TreasureWheelPhase.revealing:
        return _buildWheelView(state);

      case TreasureWheelPhase.rewarded:
      case TreasureWheelPhase.completed:
        return _buildRewardView(state);
    }
  }

  Widget _buildWheelView(TreasureWheelState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Spin to Win!',
          style: TextStyle(
            color: Colors.amber,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 32),
        TreasureWheelWidget(
          key: _wheelKey,
          slices: state.slices,
          onSpinComplete: _onSpinAnimationComplete,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: 200,
          height: 56,
          child: ElevatedButton(
            onPressed: state.phase == TreasureWheelPhase.ready ? _onSpin : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: state.phase == TreasureWheelPhase.spinning
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Text('SPIN'),
          ),
        ),
      ],
    );
  }

  Widget _buildRewardView(TreasureWheelState state) {
    final result = state.result!;
    final isCoin = result.rewardType == 'coin';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isCoin ? Icons.monetization_on : Icons.style,
          color: Colors.amber,
          size: 80,
        ),
        const SizedBox(height: 24),
        const Text(
          'Congratulations!',
          style: TextStyle(
            color: Colors.amber,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'You won ${result.sliceLabel}!',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        if (result.cards != null && result.cards!.isNotEmpty) ...[
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              itemCount: result.cards!.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final card = result.cards![index];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 70,
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber, width: 2),
                        color: Colors.white10,
                      ),
                      child: Center(
                        child: Text(
                          card.card.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (card.isNew)
                      const Text(
                        'NEW!',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: 200,
          height: 56,
          child: ElevatedButton(
            onPressed: _onClaim,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: const Text('CLAIM'),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify with dart analyze**

Run: `dart analyze lib/presentation/screens/treasure/treasure_wheel_screen.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/treasure/treasure_wheel_screen.dart
git commit -m "feat: add treasure wheel screen with spin and reward views"
```

---

## Task 9: Router + Navigation Integration

**Files:**
- Modify: `lib/app/router.dart:77`
- Modify: `lib/presentation/widgets/learning_path/learning_path.dart:232-240`
- Modify: `lib/presentation/screens/vocabulary/fullscreen_unit_detail_screen.dart:309-318`

- [ ] **Step 1: Add route constant and route**

In `lib/app/router.dart`, add route constant after `packOpening` (line 77):

```dart
  static const treasureWheel = '/treasure-wheel/:unitId';
  static String treasureWheelPath(String unitId) => '/treasure-wheel/$unitId';
```

Then add the GoRoute in the routes list (after the card trade route area). Find the appropriate location among the existing GoRoute entries and add:

```dart
      // Treasure Wheel
      GoRoute(
        path: '/treasure-wheel/:unitId',
        builder: (context, state) => TreasureWheelScreen(
          unitId: state.pathParameters['unitId']!,
        ),
      ),
```

Add the import at the top of the file:

```dart
import '../presentation/screens/treasure/treasure_wheel_screen.dart';
```

- [ ] **Step 2: Update learning_path.dart treasure tap**

In `lib/presentation/widgets/learning_path/learning_path.dart`, change lines 232-240 from:

```dart
      case PathTreasureItem():
        return MapTileNodeData(
          type: NodeType.treasure,
          state: state,
          label: 'Treasure',
          isFirstItem: isFirstItem,
          hasAssignment: unitAssigned,
          onTap: () => completePathNode(ref, unit.unit.id, 'treasure'),
        );
```

to:

```dart
      case PathTreasureItem():
        return MapTileNodeData(
          type: NodeType.treasure,
          state: state,
          label: 'Treasure',
          isFirstItem: isFirstItem,
          hasAssignment: unitAssigned,
          onTap: () => context.push(AppRoutes.treasureWheelPath(unit.unit.id)),
        );
```

Add the import at top if not already present:

```dart
import '../../../app/router.dart';
```

- [ ] **Step 3: Update fullscreen_unit_detail_screen.dart treasure tap**

In `lib/presentation/screens/vocabulary/fullscreen_unit_detail_screen.dart`, change lines 309-318 from:

```dart
      case PathTreasureItem():
        return MapTileNodeData(
          type: NodeType.treasure,
          state: state,
          label: 'Treasure',
          isFirstItem: isFirstItem,
          hasAssignment: unitAssigned,
          onTap: () =>
              completePathNode(ref, unitData.unit.id, 'treasure'),
        );
```

to:

```dart
      case PathTreasureItem():
        return MapTileNodeData(
          type: NodeType.treasure,
          state: state,
          label: 'Treasure',
          isFirstItem: isFirstItem,
          hasAssignment: unitAssigned,
          onTap: () => context.push(
              AppRoutes.treasureWheelPath(unitData.unit.id)),
        );
```

- [ ] **Step 4: Verify with dart analyze**

Run: `dart analyze lib/app/router.dart lib/presentation/widgets/learning_path/learning_path.dart lib/presentation/screens/vocabulary/fullscreen_unit_detail_screen.dart`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/app/router.dart lib/presentation/widgets/learning_path/learning_path.dart lib/presentation/screens/vocabulary/fullscreen_unit_detail_screen.dart
git commit -m "feat: wire treasure node tap to treasure wheel screen via go_router"
```

---

## Task 10: Admin Panel — Treasure Wheel Config Screen

**Files:**
- Create: `owlio_admin/lib/features/treasure_wheel/screens/treasure_wheel_config_screen.dart`
- Modify: `owlio_admin/lib/core/router.dart:366`
- Modify: `owlio_admin/lib/features/dashboard/screens/dashboard_screen.dart:215`

- [ ] **Step 1: Create the admin config screen**

Create `owlio_admin/lib/features/treasure_wheel/screens/treasure_wheel_config_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';

/// Provider to fetch and cache wheel slices
final _wheelSlicesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('treasure_wheel_slices')
      .select()
      .order('sort_order');
  return List<Map<String, dynamic>>.from(response);
});

class TreasureWheelConfigScreen extends ConsumerStatefulWidget {
  const TreasureWheelConfigScreen({super.key});

  @override
  ConsumerState<TreasureWheelConfigScreen> createState() => _TreasureWheelConfigScreenState();
}

class _TreasureWheelConfigScreenState extends ConsumerState<TreasureWheelConfigScreen> {
  @override
  Widget build(BuildContext context) {
    final slicesAsync = ref.watch(_wheelSlicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hazine Çarkı Ayarları'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Yeni Dilim Ekle',
            onPressed: () => _showSliceDialog(context),
          ),
        ],
      ),
      body: slicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (slices) {
          if (slices.isEmpty) {
            return const Center(
              child: Text('Henüz dilim eklenmemiş. Sağ üstteki + butonuna tıklayın.'),
            );
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: slices.length,
            onReorder: (oldIndex, newIndex) => _reorderSlice(slices, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final slice = slices[index];
              final color = _parseColor(slice['color'] as String? ?? '#999999');
              return Card(
                key: ValueKey(slice['id']),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: color),
                  title: Text(slice['label'] as String? ?? ''),
                  subtitle: Text(
                    '${slice['reward_type'] == 'coin' ? 'Coin' : 'Kart Paketi'}'
                    ' × ${slice['reward_amount']}'
                    '  |  Ağırlık: ${slice['weight']}'
                    '  |  ${(slice['is_active'] as bool? ?? true) ? 'Aktif' : 'Pasif'}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showSliceDialog(context, slice: slice),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteSlice(slice['id'] as String),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  Future<void> _reorderSlice(List<Map<String, dynamic>> slices, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final supabase = ref.read(supabaseClientProvider);

    // Update sort_order for affected slices
    final reordered = List<Map<String, dynamic>>.from(slices);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);

    for (int i = 0; i < reordered.length; i++) {
      await supabase
          .from('treasure_wheel_slices')
          .update({'sort_order': i})
          .eq('id', reordered[i]['id'] as String);
    }
    ref.invalidate(_wheelSlicesProvider);
  }

  Future<void> _deleteSlice(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dilimi Sil'),
        content: const Text('Bu dilimi silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final supabase = ref.read(supabaseClientProvider);
    await supabase.from('treasure_wheel_slices').delete().eq('id', id);
    ref.invalidate(_wheelSlicesProvider);
  }

  Future<void> _showSliceDialog(BuildContext context, {Map<String, dynamic>? slice}) async {
    final isEditing = slice != null;
    final labelCtrl = TextEditingController(text: slice?['label'] as String? ?? '');
    final amountCtrl = TextEditingController(text: '${slice?['reward_amount'] ?? 10}');
    final weightCtrl = TextEditingController(text: '${slice?['weight'] ?? 10}');
    final colorCtrl = TextEditingController(text: slice?['color'] as String? ?? '#4CAF50');
    var rewardType = slice?['reward_type'] as String? ?? 'coin';
    var isActive = slice?['is_active'] as bool? ?? true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Dilimi Düzenle' : 'Yeni Dilim'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Etiket (ör: 50 Coins)'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: rewardType,
                  decoration: const InputDecoration(labelText: 'Ödül Tipi'),
                  items: const [
                    DropdownMenuItem(value: 'coin', child: Text('Coin')),
                    DropdownMenuItem(value: 'card_pack', child: Text('Kart Paketi')),
                  ],
                  onChanged: (v) => setDialogState(() => rewardType = v!),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(labelText: 'Miktar'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: weightCtrl,
                  decoration: const InputDecoration(labelText: 'Ağırlık (olasılık)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: colorCtrl,
                  decoration: const InputDecoration(labelText: 'Renk (hex, ör: #FF9800)'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Aktif'),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isEditing ? 'Güncelle' : 'Ekle'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final supabase = ref.read(supabaseClientProvider);
    final data = {
      'label': labelCtrl.text,
      'reward_type': rewardType,
      'reward_amount': int.tryParse(amountCtrl.text) ?? 10,
      'weight': int.tryParse(weightCtrl.text) ?? 10,
      'color': colorCtrl.text,
      'is_active': isActive,
    };

    if (isEditing) {
      await supabase.from('treasure_wheel_slices').update(data).eq('id', slice!['id'] as String);
    } else {
      // Get next sort_order
      final existing = ref.read(_wheelSlicesProvider).valueOrNull ?? [];
      data['sort_order'] = existing.length;
      await supabase.from('treasure_wheel_slices').insert(data);
    }

    ref.invalidate(_wheelSlicesProvider);
  }
}
```

- [ ] **Step 2: Add admin route**

In `owlio_admin/lib/core/router.dart`, add the import at top:

```dart
import '../features/treasure_wheel/screens/treasure_wheel_config_screen.dart';
```

Add the route before the settings route (before line 358):

```dart
      // Treasure Wheel
      GoRoute(
        path: '/treasure-wheel',
        builder: (context, state) => const TreasureWheelConfigScreen(),
      ),
```

- [ ] **Step 3: Add dashboard card**

In `owlio_admin/lib/features/dashboard/screens/dashboard_screen.dart`, add a new `_DashboardCard` in the GridView children list (after the existing learning paths card around line 215):

```dart
                  _DashboardCard(
                    icon: Icons.casino,
                    title: 'Hazine Çarkı',
                    description: 'Çark dilimleri ve ödül ayarları',
                    color: const Color(0xFFFF9800),
                    onTap: () => context.go('/treasure-wheel'),
                  ),
```

- [ ] **Step 4: Verify with dart analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/features/treasure_wheel/ lib/core/router.dart lib/features/dashboard/screens/dashboard_screen.dart`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add owlio_admin/lib/features/treasure_wheel/ owlio_admin/lib/core/router.dart owlio_admin/lib/features/dashboard/screens/dashboard_screen.dart
git commit -m "feat(admin): add treasure wheel configuration screen (Hazine Çarkı)"
```

---

## Task 11: Full Integration Verify

**Files:** None (verification only)

- [ ] **Step 1: Run full dart analyze on main app**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/`
Expected: No issues found.

- [ ] **Step 2: Run full dart analyze on admin app**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/`
Expected: No issues found.

- [ ] **Step 3: Verify build compiles**

Run: `cd /Users/wonderelt/Desktop/Owlio && flutter build web --release 2>&1 | tail -5`
Expected: Build completes successfully.

- [ ] **Step 4: Manual test checklist**

Verify these scenarios manually:
1. Admin panel: navigate to Hazine Çarkı, verify 6 default slices are shown
2. Admin panel: edit a slice label, verify it saves
3. Admin panel: add a new slice, verify it appears
4. Admin panel: delete a slice, verify it's removed
5. Main app: navigate to learning path with treasure node
6. Main app: tap unlocked treasure node → treasure wheel screen opens
7. Main app: tap SPIN → wheel spins, RPC executes, wheel lands on winning slice
8. Main app: reward view shows with correct prize
9. Main app: tap CLAIM → returns to learning path, node shows as CLAIMED
10. Main app: tap same node again → node is already completed, doesn't open wheel
