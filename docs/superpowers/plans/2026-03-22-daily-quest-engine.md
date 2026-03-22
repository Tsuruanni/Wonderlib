# Daily Quest Engine — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hardcoded 3-quest daily goal system with a DB-driven quest engine featuring auto-completion, per-quest rewards, and a quest completion popup.

**Architecture:** New DB tables (`daily_quests`, `daily_quest_completions`, `daily_quest_bonus_claims`) with 2 RPCs (`get_daily_quest_progress`, `claim_daily_bonus`). The progress RPC auto-completes quests and awards per-quest rewards. Clean Architecture: Entity → Repository → UseCase → Provider → Widget. Old daily_goal system is fully replaced and deleted.

**Tech Stack:** Flutter, Riverpod, Supabase (PostgreSQL RPCs), owlio_shared constants, dartz (Either)

**Spec:** `docs/superpowers/specs/2026-03-22-daily-quest-engine-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `supabase/migrations/20260322000003_daily_quest_engine.sql` | Create | Tables, RLS, RPCs, seed data |
| `packages/owlio_shared/lib/src/constants/tables.dart` | Modify | Add 3 table constants |
| `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | Modify | Add 2 RPC constants |
| `lib/domain/entities/daily_quest.dart` | Create | Entity + enum |
| `lib/domain/repositories/daily_quest_repository.dart` | Create | Repository interface |
| `lib/domain/usecases/daily_quest/get_daily_quest_progress_usecase.dart` | Create | UseCase |
| `lib/domain/usecases/daily_quest/claim_daily_bonus_usecase.dart` | Create | UseCase |
| `lib/domain/usecases/daily_quest/has_daily_bonus_claimed_usecase.dart` | Create | UseCase |
| `lib/data/models/daily_quest/daily_quest_progress_model.dart` | Create | JSON → Entity |
| `lib/data/repositories/supabase/supabase_daily_quest_repository.dart` | Create | Supabase RPCs |
| `lib/presentation/providers/daily_quest_provider.dart` | Create | Riverpod providers |
| `lib/presentation/widgets/home/daily_quest_widget.dart` | Create | Widget wrapper + popup trigger |
| `lib/presentation/widgets/home/daily_quest_list.dart` | Create | Quest list UI |
| `lib/presentation/widgets/home/quest_completion_dialog.dart` | Create | Popup dialog |
| `lib/presentation/providers/repository_providers.dart` | Modify | Register new repo |
| `lib/presentation/providers/usecase_providers.dart` | Modify | Register new use cases |
| `lib/presentation/screens/home/home_screen.dart` | Modify | Swap widget import |
| `lib/presentation/providers/book_provider.dart` | Modify | Update invalidations, remove old providers |
| `lib/presentation/providers/reader_provider.dart` | Modify | Update invalidation |
| `lib/presentation/screens/vocabulary/daily_review_screen.dart` | Modify | Update invalidation |
| `lib/presentation/providers/daily_goal_provider.dart` | Delete | Replaced |
| `lib/presentation/widgets/home/daily_goal_widget.dart` | Delete | Replaced |
| `lib/presentation/widgets/home/daily_tasks_list.dart` | Delete | Replaced |

---

## Task 1: Database Migration

**Files:**
- Create: `supabase/migrations/20260322000003_daily_quest_engine.sql`

- [ ] **Step 1: Create migration file**

```sql
-- =============================================
-- Daily Quest Engine
-- =============================================

-- 1. Quest definitions table
CREATE TABLE daily_quests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quest_type VARCHAR(50) NOT NULL UNIQUE,
    title VARCHAR(200) NOT NULL,
    icon VARCHAR(10),
    goal_value INTEGER NOT NULL,
    reward_type VARCHAR(50) NOT NULL CHECK (reward_type IN ('xp', 'coins', 'card_pack')),
    reward_amount INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE daily_quests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read quests"
    ON daily_quests FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins can manage quests"
    ON daily_quests FOR ALL USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- Seed data
INSERT INTO daily_quests (quest_type, title, icon, goal_value, reward_type, reward_amount, sort_order) VALUES
    ('daily_review', 'Review daily vocab', '📖', 1, 'xp', 20, 1),
    ('read_words', 'Read 100 words', '📚', 100, 'coins', 10, 2),
    ('correct_answers', 'Answer 5 questions', '✅', 5, 'xp', 15, 3);

-- 2. Quest completion records
CREATE TABLE daily_quest_completions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    quest_id UUID NOT NULL REFERENCES daily_quests(id) ON DELETE CASCADE,
    completion_date DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, quest_id, completion_date)
);

CREATE INDEX idx_quest_completions_user_date ON daily_quest_completions(user_id, completion_date);

ALTER TABLE daily_quest_completions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own quest completions"
    ON daily_quest_completions FOR SELECT USING (user_id = auth.uid());

-- INSERT only via SECURITY DEFINER RPCs

-- 3. Daily bonus claims (replaces daily_quest_pack_claims going forward)
CREATE TABLE daily_quest_bonus_claims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    claim_date DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, claim_date)
);

ALTER TABLE daily_quest_bonus_claims ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own bonus claims"
    ON daily_quest_bonus_claims FOR SELECT USING (user_id = auth.uid());

-- 4. RPC: get_daily_quest_progress
CREATE OR REPLACE FUNCTION get_daily_quest_progress(p_user_id UUID)
RETURNS TABLE(
    quest_id UUID,
    quest_type VARCHAR,
    title VARCHAR,
    icon VARCHAR,
    goal_value INT,
    current_value INT,
    is_completed BOOLEAN,
    reward_type VARCHAR,
    reward_amount INT,
    reward_awarded BOOLEAN,
    newly_completed BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_today DATE := CURRENT_DATE;
    v_istanbul_start TIMESTAMPTZ := date_trunc('day', NOW() AT TIME ZONE 'Europe/Istanbul') AT TIME ZONE 'Europe/Istanbul';
    v_quest RECORD;
    v_current INT;
    v_completed BOOLEAN;
    v_already_awarded BOOLEAN;
    v_newly BOOLEAN;
BEGIN
    -- Auth check
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    FOR v_quest IN
        SELECT dq.id, dq.quest_type, dq.title, dq.icon, dq.goal_value, dq.reward_type, dq.reward_amount
        FROM daily_quests dq
        WHERE dq.is_active = true
        ORDER BY dq.sort_order
    LOOP
        -- Calculate current_value per quest type
        CASE v_quest.quest_type
            WHEN 'daily_review' THEN
                SELECT CASE WHEN EXISTS(
                    SELECT 1 FROM daily_review_sessions
                    WHERE user_id = p_user_id AND session_date = v_today
                ) THEN 1 ELSE 0 END INTO v_current;

            WHEN 'read_words' THEN
                SELECT COALESCE(SUM(COALESCE(ch.word_count, 0)), 0)
                INTO v_current
                FROM daily_chapter_reads dcr
                JOIN chapters ch ON ch.id = dcr.chapter_id
                WHERE dcr.user_id = p_user_id AND dcr.read_date = v_today;

            WHEN 'correct_answers' THEN
                SELECT COUNT(*)::INT
                INTO v_current
                FROM inline_activity_results
                WHERE user_id = p_user_id
                  AND is_correct = true
                  AND answered_at >= v_istanbul_start;

            ELSE
                v_current := 0;
        END CASE;

        v_completed := v_current >= v_quest.goal_value;

        -- Check if already awarded
        SELECT EXISTS(
            SELECT 1 FROM daily_quest_completions
            WHERE user_id = p_user_id AND quest_id = v_quest.id AND completion_date = v_today
        ) INTO v_already_awarded;

        v_newly := false;

        -- Auto-complete and award if newly completed
        IF v_completed AND NOT v_already_awarded THEN
            INSERT INTO daily_quest_completions (user_id, quest_id, completion_date)
            VALUES (p_user_id, v_quest.id, v_today)
            ON CONFLICT DO NOTHING;

            -- Award reward
            CASE v_quest.reward_type
                WHEN 'xp' THEN
                    PERFORM award_xp_transaction(
                        p_user_id, v_quest.reward_amount, 'daily_quest',
                        v_quest.id, v_quest.title
                    );
                WHEN 'coins' THEN
                    PERFORM award_coins_transaction(
                        p_user_id, v_quest.reward_amount, 'daily_quest',
                        v_quest.id, v_quest.title
                    );
                WHEN 'card_pack' THEN
                    UPDATE profiles SET unopened_packs = unopened_packs + v_quest.reward_amount
                    WHERE id = p_user_id;
                ELSE NULL;
            END CASE;

            v_newly := true;
            v_already_awarded := true;
        END IF;

        quest_id := v_quest.id;
        quest_type := v_quest.quest_type;
        title := v_quest.title;
        icon := v_quest.icon;
        goal_value := v_quest.goal_value;
        current_value := v_current;
        is_completed := v_completed;
        reward_type := v_quest.reward_type;
        reward_amount := v_quest.reward_amount;
        reward_awarded := v_already_awarded;
        newly_completed := v_newly;
        RETURN NEXT;
    END LOOP;
END;
$$;

-- 5. RPC: claim_daily_bonus
CREATE OR REPLACE FUNCTION claim_daily_bonus(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_today DATE := CURRENT_DATE;
    v_active_count INT;
    v_completed_count INT;
    v_new_packs INT;
BEGIN
    -- Auth check
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    -- Lock user row
    PERFORM id FROM profiles WHERE id = p_user_id FOR UPDATE;

    -- Count active quests
    SELECT COUNT(*) INTO v_active_count FROM daily_quests WHERE is_active = true;

    -- Count completed quests today
    SELECT COUNT(*) INTO v_completed_count
    FROM daily_quest_completions dqc
    JOIN daily_quests dq ON dq.id = dqc.quest_id
    WHERE dqc.user_id = p_user_id
      AND dqc.completion_date = v_today
      AND dq.is_active = true;

    IF v_completed_count < v_active_count THEN
        RAISE EXCEPTION 'Not all quests completed';
    END IF;

    -- Check already claimed
    IF EXISTS(SELECT 1 FROM daily_quest_bonus_claims WHERE user_id = p_user_id AND claim_date = v_today) THEN
        RAISE EXCEPTION 'Bonus already claimed today';
    END IF;

    -- Claim
    INSERT INTO daily_quest_bonus_claims (user_id, claim_date) VALUES (p_user_id, v_today);

    -- Award pack
    UPDATE profiles SET unopened_packs = unopened_packs + 1 WHERE id = p_user_id
    RETURNING unopened_packs INTO v_new_packs;

    RETURN jsonb_build_object('success', true, 'unopened_packs', v_new_packs);
END;
$$;
```

- [ ] **Step 2: Preview migration**

Run: `cd /Users/wonderelt/Desktop/Owlio && supabase db push --dry-run`

- [ ] **Step 3: Apply migration**

Run: `cd /Users/wonderelt/Desktop/Owlio && supabase db push`

- [ ] **Step 4: Verify seed data**

Test the RPC with curl or Supabase dashboard to confirm 3 quests are returned.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260322000003_daily_quest_engine.sql
git commit -m "feat(db): add daily quest engine tables, RPCs, and seed data"
```

---

## Task 2: Shared Package Constants

**Files:**
- Modify: `packages/owlio_shared/lib/src/constants/tables.dart`
- Modify: `packages/owlio_shared/lib/src/constants/rpc_functions.dart`

- [ ] **Step 1: Add table constants**

In `tables.dart`, add after `dailyQuestPackClaims`:
```dart
static const dailyQuests = 'daily_quests';
static const dailyQuestCompletions = 'daily_quest_completions';
static const dailyQuestBonusClaims = 'daily_quest_bonus_claims';
```

- [ ] **Step 2: Add RPC constants**

In `rpc_functions.dart`, add:
```dart
static const getDailyQuestProgress = 'get_daily_quest_progress';
static const claimDailyBonus = 'claim_daily_bonus';
```

- [ ] **Step 3: Commit**

```bash
git add packages/owlio_shared/
git commit -m "feat(shared): add daily quest table and RPC constants"
```

---

## Task 3: Domain Layer (Entity + Repository Interface + UseCases)

**Files:**
- Create: `lib/domain/entities/daily_quest.dart`
- Create: `lib/domain/repositories/daily_quest_repository.dart`
- Create: `lib/domain/usecases/daily_quest/get_daily_quest_progress_usecase.dart`
- Create: `lib/domain/usecases/daily_quest/claim_daily_bonus_usecase.dart`
- Create: `lib/domain/usecases/daily_quest/has_daily_bonus_claimed_usecase.dart`

- [ ] **Step 1: Create entity**

`lib/domain/entities/daily_quest.dart`:
```dart
import 'package:equatable/equatable.dart';

enum QuestRewardType { xp, coins, cardPack }

class DailyQuest extends Equatable {
  final String id;
  final String questType;
  final String title;
  final String icon;
  final int goalValue;
  final QuestRewardType rewardType;
  final int rewardAmount;

  const DailyQuest({
    required this.id,
    required this.questType,
    required this.title,
    required this.icon,
    required this.goalValue,
    required this.rewardType,
    required this.rewardAmount,
  });

  @override
  List<Object?> get props => [id];
}

class DailyQuestProgress extends Equatable {
  final DailyQuest quest;
  final int currentValue;
  final bool isCompleted;
  final bool rewardAwarded;
  final bool newlyCompleted;

  const DailyQuestProgress({
    required this.quest,
    required this.currentValue,
    required this.isCompleted,
    required this.rewardAwarded,
    required this.newlyCompleted,
  });

  @override
  List<Object?> get props => [quest.id, currentValue, isCompleted, rewardAwarded, newlyCompleted];
}

class DailyBonusResult {
  final bool success;
  final int unopenedPacks;

  const DailyBonusResult({required this.success, required this.unopenedPacks});
}
```

- [ ] **Step 2: Create repository interface**

`lib/domain/repositories/daily_quest_repository.dart`:
```dart
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/daily_quest.dart';

abstract class DailyQuestRepository {
  Future<Either<Failure, List<DailyQuestProgress>>> getDailyQuestProgress(String userId);
  Future<Either<Failure, DailyBonusResult>> claimDailyBonus(String userId);
  Future<Either<Failure, bool>> hasDailyBonusClaimed(String userId);
}
```

- [ ] **Step 3: Create use cases**

3 files, each follows the UseCase base pattern from `lib/domain/usecases/usecase.dart`:

`get_daily_quest_progress_usecase.dart`:
```dart
import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../repositories/daily_quest_repository.dart';
import '../usecase.dart';
import '../../entities/daily_quest.dart';

class GetDailyQuestProgressUseCase implements UseCase<List<DailyQuestProgress>, GetDailyQuestProgressParams> {
  final DailyQuestRepository _repository;
  const GetDailyQuestProgressUseCase(this._repository);

  @override
  Future<Either<Failure, List<DailyQuestProgress>>> call(GetDailyQuestProgressParams params) {
    return _repository.getDailyQuestProgress(params.userId);
  }
}

class GetDailyQuestProgressParams {
  final String userId;
  const GetDailyQuestProgressParams({required this.userId});
}
```

`claim_daily_bonus_usecase.dart` and `has_daily_bonus_claimed_usecase.dart` follow the same pattern.

- [ ] **Step 4: Verify**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/domain/entities/daily_quest.dart lib/domain/repositories/daily_quest_repository.dart lib/domain/usecases/daily_quest/`

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/daily_quest.dart lib/domain/repositories/daily_quest_repository.dart lib/domain/usecases/daily_quest/
git commit -m "feat: add daily quest domain layer (entity, repository, use cases)"
```

---

## Task 4: Data Layer (Model + Repository Implementation)

**Files:**
- Create: `lib/data/models/daily_quest/daily_quest_progress_model.dart`
- Create: `lib/data/repositories/supabase/supabase_daily_quest_repository.dart`

- [ ] **Step 1: Create model**

`daily_quest_progress_model.dart`:
```dart
import '../../../domain/entities/daily_quest.dart';

class DailyQuestProgressModel {
  // ... fields matching RPC return columns

  factory DailyQuestProgressModel.fromJson(Map<String, dynamic> json) {
    return DailyQuestProgressModel(
      questId: json['quest_id'] as String,
      questType: json['quest_type'] as String,
      title: json['title'] as String,
      icon: json['icon'] as String? ?? '🎯',
      goalValue: json['goal_value'] as int,
      currentValue: json['current_value'] as int,
      isCompleted: json['is_completed'] as bool,
      rewardType: json['reward_type'] as String,
      rewardAmount: json['reward_amount'] as int,
      rewardAwarded: json['reward_awarded'] as bool,
      newlyCompleted: json['newly_completed'] as bool? ?? false,
    );
  }

  DailyQuestProgress toEntity() {
    return DailyQuestProgress(
      quest: DailyQuest(
        id: questId,
        questType: questType,
        title: title,
        icon: icon,
        goalValue: goalValue,
        rewardType: _parseRewardType(rewardType),
        rewardAmount: rewardAmount,
      ),
      currentValue: currentValue,
      isCompleted: isCompleted,
      rewardAwarded: rewardAwarded,
      newlyCompleted: newlyCompleted,
    );
  }

  static QuestRewardType _parseRewardType(String type) {
    switch (type) {
      case 'xp': return QuestRewardType.xp;
      case 'coins': return QuestRewardType.coins;
      case 'card_pack': return QuestRewardType.cardPack;
      default: return QuestRewardType.xp;
    }
  }
}
```

- [ ] **Step 2: Create repository implementation**

`supabase_daily_quest_repository.dart`:
```dart
import 'package:dartz/dartz.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/entities/daily_quest.dart';
import '../../../domain/repositories/daily_quest_repository.dart';
import '../../models/daily_quest/daily_quest_progress_model.dart';

class SupabaseDailyQuestRepository implements DailyQuestRepository {
  final SupabaseClient _supabase;
  const SupabaseDailyQuestRepository(this._supabase);

  @override
  Future<Either<Failure, List<DailyQuestProgress>>> getDailyQuestProgress(String userId) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.getDailyQuestProgress,
        params: {'p_user_id': userId},
      );
      final list = (response as List)
          .map((json) => DailyQuestProgressModel.fromJson(json).toEntity())
          .toList();
      return Right(list);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, DailyBonusResult>> claimDailyBonus(String userId) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.claimDailyBonus,
        params: {'p_user_id': userId},
      );
      final data = response as Map<String, dynamic>;
      return Right(DailyBonusResult(
        success: data['success'] as bool? ?? false,
        unopenedPacks: data['unopened_packs'] as int? ?? 0,
      ));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> hasDailyBonusClaimed(String userId) async {
    try {
      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final response = await _supabase
          .from(DbTables.dailyQuestBonusClaims)
          .select('id')
          .eq('user_id', userId)
          .eq('claim_date', today)
          .maybeSingle();
      return Right(response != null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
```

- [ ] **Step 3: Verify**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/data/models/daily_quest/ lib/data/repositories/supabase/supabase_daily_quest_repository.dart`

- [ ] **Step 4: Commit**

```bash
git add lib/data/models/daily_quest/ lib/data/repositories/supabase/supabase_daily_quest_repository.dart
git commit -m "feat: add daily quest data layer (model, repository)"
```

---

## Task 5: Provider Registration

**Files:**
- Modify: `lib/presentation/providers/repository_providers.dart`
- Modify: `lib/presentation/providers/usecase_providers.dart`
- Create: `lib/presentation/providers/daily_quest_provider.dart`

- [ ] **Step 1: Register repository provider**

In `repository_providers.dart`, add:
```dart
final dailyQuestRepositoryProvider = Provider<DailyQuestRepository>((ref) {
  return SupabaseDailyQuestRepository(ref.watch(supabaseClientProvider));
});
```

- [ ] **Step 2: Register use case providers**

In `usecase_providers.dart`, add:
```dart
final getDailyQuestProgressUseCaseProvider = Provider((ref) =>
    GetDailyQuestProgressUseCase(ref.watch(dailyQuestRepositoryProvider)));

final claimDailyBonusUseCaseProvider = Provider((ref) =>
    ClaimDailyBonusUseCase(ref.watch(dailyQuestRepositoryProvider)));

final hasDailyBonusClaimedUseCaseProvider = Provider((ref) =>
    HasDailyBonusClaimedUseCase(ref.watch(dailyQuestRepositoryProvider)));
```

- [ ] **Step 3: Create quest providers**

`lib/presentation/providers/daily_quest_provider.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/daily_quest.dart';
import 'usecase_providers.dart';
import '../providers/repository_providers.dart';
// ... imports for use case params

final dailyQuestProgressProvider = FutureProvider<List<DailyQuestProgress>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final useCase = ref.watch(getDailyQuestProgressUseCaseProvider);
  final result = await useCase(GetDailyQuestProgressParams(userId: user.id));
  return result.fold((_) => [], (progress) => progress);
});

final dailyBonusClaimedProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  final useCase = ref.watch(hasDailyBonusClaimedUseCaseProvider);
  final result = await useCase(HasDailyBonusClaimedParams(userId: user.id));
  return result.fold((_) => false, (claimed) => claimed);
});
```

- [ ] **Step 4: Verify**

Run: `dart analyze lib/presentation/providers/daily_quest_provider.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/providers/daily_quest_provider.dart lib/presentation/providers/repository_providers.dart lib/presentation/providers/usecase_providers.dart
git commit -m "feat: register daily quest providers and use cases"
```

---

## Task 6: UI — Quest Completion Dialog

**Files:**
- Create: `lib/presentation/widgets/home/quest_completion_dialog.dart`

- [ ] **Step 1: Create dialog widget**

A dialog that shows quest icon + title + reward. Similar to level-up popup.

```dart
class QuestCompletionDialog extends StatelessWidget {
  const QuestCompletionDialog({
    super.key,
    required this.completedQuests,
    required this.allQuestsComplete,
  });

  final List<DailyQuestProgress> completedQuests;
  final bool allQuestsComplete;

  static void show(BuildContext context, {
    required List<DailyQuestProgress> completedQuests,
    required bool allQuestsComplete,
  }) {
    showDialog(
      context: context,
      builder: (_) => QuestCompletionDialog(
        completedQuests: completedQuests,
        allQuestsComplete: allQuestsComplete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Quest icon, title, reward for each newly completed quest
      // If allQuestsComplete: bonus message with gift icon
      // Dismiss button
    );
  }
}
```

Content per completed quest: `"${quest.icon} ${quest.title}"` + reward line based on type:
- `QuestRewardType.xp` → "+${amount} XP kazanıldı!"
- `QuestRewardType.coins` → "+${amount} coin kazanıldı!"
- `QuestRewardType.cardPack` → "+${amount} kart paketi kazanıldı!"

If `allQuestsComplete`: additional section with 🎁 "Tüm görevler tamamlandı! Bonus kart paketini al!"

- [ ] **Step 2: Verify**

Run: `dart analyze lib/presentation/widgets/home/quest_completion_dialog.dart`

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/home/quest_completion_dialog.dart
git commit -m "feat: add quest completion popup dialog"
```

---

## Task 7: UI — Daily Quest Widget + List (Replace Old System)

**Files:**
- Create: `lib/presentation/widgets/home/daily_quest_widget.dart`
- Create: `lib/presentation/widgets/home/daily_quest_list.dart`

- [ ] **Step 1: Create daily_quest_widget.dart**

Wrapper that watches `dailyQuestProgressProvider` + `dailyBonusClaimedProvider`, handles loading/error, and triggers popup via `ref.listen`:

```dart
class DailyQuestWidget extends ConsumerWidget {
  const DailyQuestWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(dailyQuestProgressProvider);
    final bonusClaimed = ref.watch(dailyBonusClaimedProvider).valueOrNull ?? false;

    // Listen for newly completed quests → show popup
    ref.listen<AsyncValue<List<DailyQuestProgress>>>(dailyQuestProgressProvider, (prev, next) {
      final prevData = prev?.valueOrNull ?? [];
      final nextData = next.valueOrNull ?? [];
      final newlyCompleted = nextData.where((q) => q.newlyCompleted).toList();
      if (newlyCompleted.isNotEmpty) {
        final allComplete = nextData.every((q) => q.isCompleted);
        QuestCompletionDialog.show(context,
          completedQuests: newlyCompleted,
          allQuestsComplete: allComplete && !bonusClaimed,
        );
      }
    });

    return progressAsync.when(
      data: (progress) => DailyQuestList(
        progress: progress,
        bonusClaimed: bonusClaimed,
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
```

- [ ] **Step 2: Create daily_quest_list.dart**

Renders quest rows + bonus row. Includes teacher assignments above (ported from old `daily_tasks_list.dart`).

Each quest row shows:
- `quest.icon` + `quest.title`
- Progress bar (`currentValue / goalValue`)
- Reward badge ("+20 XP" or "+10 🪙")
- Green checkmark if completed

Bonus row at bottom:
- Locked (not all done): 🔒 "Tüm görevleri tamamla → Kart Paketi"
- Claimable (all done, not claimed): 🎁 animated, "Ödülünü Al!" button → calls `ClaimDailyBonusUseCase`
- Claimed: ✅ "Bonus alındı! +1 paket"

- [ ] **Step 3: Verify**

Run: `dart analyze lib/presentation/widgets/home/daily_quest_widget.dart lib/presentation/widgets/home/daily_quest_list.dart`

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/widgets/home/daily_quest_widget.dart lib/presentation/widgets/home/daily_quest_list.dart
git commit -m "feat: add daily quest widget and list UI"
```

---

## Task 8: Wire Up + Clean Up Old System

**Files:**
- Modify: `lib/presentation/screens/home/home_screen.dart`
- Modify: `lib/presentation/providers/book_provider.dart`
- Modify: `lib/presentation/providers/reader_provider.dart`
- Modify: `lib/presentation/screens/vocabulary/daily_review_screen.dart`
- Delete: `lib/presentation/providers/daily_goal_provider.dart`
- Delete: `lib/presentation/widgets/home/daily_goal_widget.dart`
- Delete: `lib/presentation/widgets/home/daily_tasks_list.dart`

- [ ] **Step 1: Update home_screen.dart**

Change import from `daily_goal_widget.dart` to `daily_quest_widget.dart`.
Change `const DailyGoalWidget()` to `const DailyQuestWidget()`.

- [ ] **Step 2: Update book_provider.dart**

Remove `wordsReadTodayProvider` and `correctAnswersTodayProvider` definitions.
Replace `_ref.invalidate(wordsReadTodayProvider)` in chapter complete handler with `_ref.invalidate(dailyQuestProgressProvider)`.

- [ ] **Step 3: Update reader_provider.dart**

Replace `ref.invalidate(correctAnswersTodayProvider)` with `ref.invalidate(dailyQuestProgressProvider)`.

- [ ] **Step 4: Update daily_review_screen.dart**

Add `ref.invalidate(dailyQuestProgressProvider)` after review completion (alongside existing `todayReviewSessionProvider` invalidation).

- [ ] **Step 5: Delete old files**

```bash
rm lib/presentation/providers/daily_goal_provider.dart
rm lib/presentation/widgets/home/daily_goal_widget.dart
rm lib/presentation/widgets/home/daily_tasks_list.dart
```

- [ ] **Step 6: Remove old use case references**

Check if `claim_daily_quest_pack_usecase.dart` and `has_daily_quest_pack_claimed_usecase.dart` are still referenced. If the old `daily_tasks_list.dart` was the only consumer, they can be deleted. Check `usecase_providers.dart` for registrations and remove if no longer used.

- [ ] **Step 7: Full verify**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/`
Expected: No errors related to daily quest/goal. Pre-existing warnings OK.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: wire up daily quest engine, delete old daily goal system"
```

---

## Task 9: Integration Verification

- [ ] **Step 1: Run full analyzer**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/`

- [ ] **Step 2: Manual testing checklist**

1. **Home screen** — daily quest widget shows 3 quests from DB with progress bars
2. **Complete daily review** — quest 1 completes, popup shows "+20 XP kazanıldı!"
3. **Read a chapter** — quest 2 progress increases
4. **Answer activities** — quest 3 progress increases, popup on completion
5. **All quests complete** — bonus row becomes claimable, tap → pack awarded
6. **Reload home** — all states preserved (no double reward, no re-popup)
7. **Next day** — all quests reset to 0 progress
