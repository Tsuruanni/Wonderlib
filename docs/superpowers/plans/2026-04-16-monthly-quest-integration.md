# Monthly Quest Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the `_MonthlyQuestCard` / `_MonthlyBadgesCard` UI placeholders to a real backend — admin-managed monthly challenges with calendar-month reset, implicit progress counting, optional badge reward, and tabbed admin management.

**Architecture:** Mirror the existing daily quest pipeline end-to-end: new `monthly_quests` + `monthly_quest_completions` tables, `get_monthly_quest_progress` SECURITY DEFINER RPC with Istanbul-TZ calendar windows, Flutter clean-arch layers (entity → repository → usecase → provider → widget), and a tabbed admin UI that adds a badge-picker dropdown.

**Tech Stack:** Flutter 3.x (Dart), Supabase (Postgres + RLS + SECURITY DEFINER RPC), Riverpod, `dartz` Either, `owlio_shared` package for table/RPC constants.

**Reference spec:** `docs/superpowers/specs/2026-04-16-monthly-quest-integration-design.md`

**Testing note:** The existing daily quest pipeline has no unit tests (no `test/unit/daily_quest/` directory). We match codebase conventions — domain/data layers ship without unit tests; verification is via `dart analyze` + manual E2E smoke on `fresh@demo.com`. This is explicitly aligned with the codebase's current test posture, not aspirational TDD.

---

## File Structure

### New Files
| Path | Responsibility |
|------|----------------|
| `supabase/migrations/20260416000001_monthly_quest_engine.sql` | Tables, RLS, RPC, seed |
| `lib/domain/entities/monthly_quest.dart` | `MonthlyQuest`, `MonthlyQuestProgress` (reuses `QuestRewardType` from `daily_quest.dart`) |
| `lib/domain/repositories/monthly_quest_repository.dart` | Repository interface |
| `lib/domain/usecases/monthly_quest/get_monthly_quest_progress_usecase.dart` | UseCase + Params |
| `lib/data/models/monthly_quest/monthly_quest_progress_model.dart` | JSON deserializer + `toEntity()` |
| `lib/data/repositories/supabase/supabase_monthly_quest_repository.dart` | Calls RPC, maps failures |
| `lib/presentation/providers/monthly_quest_provider.dart` | `monthlyQuestProgressProvider` FutureProvider |
| `owlio_admin/lib/features/quests/screens/tabs/daily_quests_tab.dart` | Extracted from current quest_list_screen |
| `owlio_admin/lib/features/quests/screens/tabs/monthly_quests_tab.dart` | New tab with badge-picker |
| `owlio_admin/lib/features/quests/widgets/quest_card.dart` | Shared card widget (replaces `_QuestCard`) |

### Modified Files
| Path | What changes |
|------|-------------|
| `packages/owlio_shared/lib/src/constants/tables.dart` | Add `monthlyQuests`, `monthlyQuestCompletions` |
| `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | Add `getMonthlyQuestProgress` |
| `lib/presentation/providers/repository_providers.dart:~156` | Register `monthlyQuestRepositoryProvider` |
| `lib/presentation/providers/usecase_providers.dart:~728` | Register `getMonthlyQuestProgressUseCaseProvider` |
| `lib/presentation/screens/quests/quests_screen.dart:337-478, 692-769` | Convert 2 widgets to `ConsumerWidget`, wire provider |
| `lib/presentation/widgets/shell/right_info_panel.dart:1355-1531` | Convert 2 sidebar widgets to `ConsumerWidget`, wire provider |
| `lib/presentation/providers/book_provider.dart:198` | Add monthly invalidation |
| `lib/presentation/providers/reader_provider.dart:479` | Add monthly invalidation |
| `lib/presentation/providers/vocabulary_provider.dart:1033` | Add monthly invalidation |
| `lib/presentation/screens/vocabulary/daily_review_screen.dart:147` | Add monthly invalidation |
| `lib/presentation/providers/daily_quest_provider.dart:45-54` | Add monthly invalidation in microtask |
| `lib/presentation/widgets/common/notification_listener.dart:76` | Keep-alive watch for monthly provider |
| `owlio_admin/lib/features/quests/screens/quest_list_screen.dart` | Tabbed refactor |

---

## Phase 1 — Database

### Task 1.1: Write the migration file

**Files:**
- Create: `supabase/migrations/20260416000001_monthly_quest_engine.sql`

- [ ] **Step 1: Create migration file with tables, RLS, RPC, seed**

```sql
-- =============================================
-- Monthly Quest Engine
-- Mirrors daily quest architecture with calendar-month periods (Istanbul TZ).
-- =============================================

-- 1. Quest definitions table
CREATE TABLE monthly_quests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quest_type VARCHAR(50) NOT NULL UNIQUE,
    title VARCHAR(200) NOT NULL,
    icon VARCHAR(10),
    goal_value INTEGER NOT NULL CHECK (goal_value > 0),
    reward_type VARCHAR(50) NOT NULL CHECK (reward_type IN ('xp', 'coins', 'card_pack')),
    reward_amount INTEGER NOT NULL DEFAULT 0,
    badge_id UUID REFERENCES badges(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE monthly_quests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read monthly quests"
    ON monthly_quests FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins can manage monthly quests"
    ON monthly_quests FOR ALL USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- Seed: matches UI placeholder "Complete 20 quests"
INSERT INTO monthly_quests (quest_type, title, icon, goal_value, reward_type, reward_amount, sort_order)
VALUES ('complete_daily_quests', 'Complete 20 daily quests this month', '🏆', 20, 'card_pack', 1, 1);

-- 2. Per-user, per-period completion records
CREATE TABLE monthly_quest_completions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    quest_id UUID NOT NULL REFERENCES monthly_quests(id) ON DELETE CASCADE,
    period_key VARCHAR(7) NOT NULL,
    completed_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, quest_id, period_key)
);

CREATE INDEX idx_mqc_user_period ON monthly_quest_completions(user_id, period_key);

ALTER TABLE monthly_quest_completions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own monthly quest completions"
    ON monthly_quest_completions FOR SELECT USING (user_id = auth.uid());

-- 3. RPC: get_monthly_quest_progress
CREATE OR REPLACE FUNCTION get_monthly_quest_progress(p_user_id UUID)
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
    newly_completed BOOLEAN,
    period_key VARCHAR,
    days_left INT,
    badge_id UUID,
    badge_awarded BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_period_key  VARCHAR(7);
    v_month_start TIMESTAMPTZ;
    v_month_end   TIMESTAMPTZ;
    v_days_left   INT;
    v_quest RECORD;
    v_current INT;
    v_completed BOOLEAN;
    v_already_awarded BOOLEAN;
    v_newly BOOLEAN;
    v_badge_awarded BOOLEAN;
    v_badge_rows INT;
    v_badge_xp INT;
    v_badge_name VARCHAR;
BEGIN
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    v_period_key  := to_char(NOW() AT TIME ZONE 'Europe/Istanbul', 'YYYY-MM');
    v_month_start := date_trunc('month', NOW() AT TIME ZONE 'Europe/Istanbul')
                       AT TIME ZONE 'Europe/Istanbul';
    v_month_end   := v_month_start + INTERVAL '1 month';
    v_days_left   := (v_month_end::date - 1) - (NOW() AT TIME ZONE 'Europe/Istanbul')::date;

    FOR v_quest IN
        SELECT mq.id, mq.quest_type, mq.title, mq.icon, mq.goal_value,
               mq.reward_type, mq.reward_amount, mq.badge_id
        FROM monthly_quests mq
        WHERE mq.is_active = true
        ORDER BY mq.sort_order
    LOOP
        CASE v_quest.quest_type
            WHEN 'complete_daily_quests' THEN
                SELECT COUNT(*)::INT INTO v_current
                FROM daily_quest_completions
                WHERE user_id = p_user_id
                  AND completion_date >= v_month_start::date
                  AND completion_date <  v_month_end::date;

            WHEN 'read_chapters' THEN
                SELECT COUNT(DISTINCT chapter_id)::INT INTO v_current
                FROM daily_chapter_reads
                WHERE user_id = p_user_id
                  AND read_date >= v_month_start::date
                  AND read_date <  v_month_end::date;

            WHEN 'read_words' THEN
                SELECT COALESCE(SUM(COALESCE(ch.word_count, 0)), 0)::INT INTO v_current
                FROM daily_chapter_reads dcr
                JOIN chapters ch ON ch.id = dcr.chapter_id
                WHERE dcr.user_id = p_user_id
                  AND dcr.read_date >= v_month_start::date
                  AND dcr.read_date <  v_month_end::date;

            WHEN 'vocab_sessions' THEN
                SELECT COUNT(*)::INT INTO v_current
                FROM vocabulary_sessions
                WHERE user_id = p_user_id
                  AND completed_at >= v_month_start
                  AND completed_at <  v_month_end;

            WHEN 'correct_answers' THEN
                SELECT COUNT(*)::INT INTO v_current
                FROM inline_activity_results
                WHERE user_id = p_user_id
                  AND is_correct = true
                  AND answered_at >= v_month_start
                  AND answered_at <  v_month_end;

            WHEN 'daily_reviews' THEN
                SELECT COUNT(DISTINCT session_date)::INT INTO v_current
                FROM daily_review_sessions
                WHERE user_id = p_user_id
                  AND session_date >= v_month_start::date
                  AND session_date <  v_month_end::date;

            ELSE
                v_current := 0;
        END CASE;

        v_completed := v_current >= v_quest.goal_value;
        v_newly := false;
        v_badge_awarded := false;

        SELECT EXISTS(
            SELECT 1 FROM monthly_quest_completions
            WHERE user_id = p_user_id
              AND quest_id = v_quest.id
              AND period_key = v_period_key
        ) INTO v_already_awarded;

        IF v_completed AND NOT v_already_awarded THEN
            INSERT INTO monthly_quest_completions (user_id, quest_id, period_key)
            VALUES (p_user_id, v_quest.id, v_period_key)
            ON CONFLICT DO NOTHING;

            -- Primary reward
            CASE v_quest.reward_type
                WHEN 'xp' THEN
                    PERFORM award_xp_transaction(
                        p_user_id, v_quest.reward_amount, 'monthly_quest',
                        v_quest.id, v_quest.title
                    );
                WHEN 'coins' THEN
                    PERFORM award_coins_transaction(
                        p_user_id, v_quest.reward_amount, 'monthly_quest',
                        v_quest.id, v_quest.title
                    );
                WHEN 'card_pack' THEN
                    UPDATE profiles
                    SET unopened_packs = unopened_packs + v_quest.reward_amount
                    WHERE id = p_user_id;
                ELSE NULL;
            END CASE;

            -- Optional badge reward
            IF v_quest.badge_id IS NOT NULL THEN
                INSERT INTO user_badges (user_id, badge_id)
                VALUES (p_user_id, v_quest.badge_id)
                ON CONFLICT DO NOTHING;
                GET DIAGNOSTICS v_badge_rows = ROW_COUNT;
                IF v_badge_rows > 0 THEN
                    v_badge_awarded := true;
                    SELECT b.xp_reward, b.name INTO v_badge_xp, v_badge_name
                    FROM badges b WHERE b.id = v_quest.badge_id;
                    IF v_badge_xp > 0 THEN
                        PERFORM award_xp_transaction(
                            p_user_id, v_badge_xp, 'badge',
                            v_quest.badge_id, v_badge_name
                        );
                    END IF;
                END IF;
            END IF;

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
        period_key := v_period_key;
        days_left := v_days_left;
        badge_id := v_quest.badge_id;
        badge_awarded := v_badge_awarded;
        RETURN NEXT;
    END LOOP;
END;
$$;
```

- [ ] **Step 2: Dry-run the migration**

Run: `cd /Users/wonderelt/Desktop/Owlio && supabase db push --dry-run`
Expected: Output lists the new migration, no errors.

- [ ] **Step 3: Push the migration**

Run: `cd /Users/wonderelt/Desktop/Owlio && supabase db push`
Expected: Migration applied. Verify with `supabase migration list`.

- [ ] **Step 4: Smoke test the RPC with a test user**

Via Supabase SQL editor (logged in as `fresh@demo.com`, or use `SELECT auth.uid()` override if SQL-level):

```sql
-- As the user (replace UUID with fresh@demo.com's profile id):
SELECT * FROM get_monthly_quest_progress('<fresh_user_id>');
```

Expected: Returns 1 row — the seed quest — with `current_value=0` (assuming fresh user has no daily quest completions yet), `is_completed=false`, `period_key='2026-04'` (or current month), `days_left` = days remaining.

- [ ] **Step 5: Commit the migration**

```bash
cd /Users/wonderelt/Desktop/Owlio
git add supabase/migrations/20260416000001_monthly_quest_engine.sql
git commit -m "feat(db): monthly quest engine migration — tables, RLS, RPC, seed"
```

---

## Phase 2 — Shared Package

### Task 2.1: Add table constants

**Files:**
- Modify: `packages/owlio_shared/lib/src/constants/tables.dart`

- [ ] **Step 1: Find the daily_quests constants block**

Run: `grep -n "dailyQuest" packages/owlio_shared/lib/src/constants/tables.dart`
Expected: Finds `dailyQuests`, `dailyQuestCompletions`, `dailyQuestBonusClaims` constants.

- [ ] **Step 2: Add monthly constants right after the daily block**

Locate the line with `static const dailyQuestBonusClaims = 'daily_quest_bonus_claims';` and insert after it:

```dart
  static const monthlyQuests = 'monthly_quests';
  static const monthlyQuestCompletions = 'monthly_quest_completions';
```

- [ ] **Step 3: Verify shared package still analyzes clean**

Run: `cd /Users/wonderelt/Desktop/Owlio/packages/owlio_shared && dart analyze`
Expected: `No issues found!`

### Task 2.2: Add RPC constant

**Files:**
- Modify: `packages/owlio_shared/lib/src/constants/rpc_functions.dart`

- [ ] **Step 1: Find the quest RPC block**

Run: `grep -n "Quest\|quest" packages/owlio_shared/lib/src/constants/rpc_functions.dart`
Expected: Finds `getDailyQuestProgress`, `claimDailyBonus`, `getQuestCompletionStats`.

- [ ] **Step 2: Add monthly RPC constant in the same area**

After the quest-related RPC constants, add:

```dart
  static const getMonthlyQuestProgress = 'get_monthly_quest_progress';
```

- [ ] **Step 3: Verify analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio/packages/owlio_shared && dart analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
cd /Users/wonderelt/Desktop/Owlio
git add packages/owlio_shared/lib/src/constants/tables.dart packages/owlio_shared/lib/src/constants/rpc_functions.dart
git commit -m "feat(shared): add monthly quest table and RPC constants"
```

---

## Phase 3 — Mobile App: Domain Layer

### Task 3.1: Create MonthlyQuest + MonthlyQuestProgress entities

**Files:**
- Create: `lib/domain/entities/monthly_quest.dart`

- [ ] **Step 1: Create the entity file**

```dart
import 'package:equatable/equatable.dart';

import 'daily_quest.dart' show QuestRewardType;

export 'daily_quest.dart' show QuestRewardType;

class MonthlyQuest extends Equatable {
  const MonthlyQuest({
    required this.id,
    required this.questType,
    required this.title,
    required this.icon,
    required this.goalValue,
    required this.rewardType,
    required this.rewardAmount,
    required this.badgeId,
  });

  final String id;
  final String questType;
  final String title;
  final String icon;
  final int goalValue;
  final QuestRewardType rewardType;
  final int rewardAmount;
  final String? badgeId;

  @override
  List<Object?> get props => [id];
}

class MonthlyQuestProgress extends Equatable {
  const MonthlyQuestProgress({
    required this.quest,
    required this.currentValue,
    required this.isCompleted,
    required this.rewardAwarded,
    required this.newlyCompleted,
    required this.periodKey,
    required this.daysLeft,
    required this.badgeAwarded,
  });

  final MonthlyQuest quest;
  final int currentValue;
  final bool isCompleted;
  final bool rewardAwarded;
  final bool newlyCompleted;
  final String periodKey;
  final int daysLeft;
  final bool badgeAwarded;

  @override
  List<Object?> get props => [
        quest.id,
        currentValue,
        isCompleted,
        rewardAwarded,
        newlyCompleted,
        periodKey,
        daysLeft,
        badgeAwarded,
      ];
}
```

- [ ] **Step 2: Verify analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/domain/entities/monthly_quest.dart`
Expected: `No issues found!`

### Task 3.2: Create MonthlyQuestRepository interface

**Files:**
- Create: `lib/domain/repositories/monthly_quest_repository.dart`

- [ ] **Step 1: Create the interface**

```dart
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/monthly_quest.dart';

abstract class MonthlyQuestRepository {
  Future<Either<Failure, List<MonthlyQuestProgress>>> getMonthlyQuestProgress(String userId);
}
```

- [ ] **Step 2: Verify analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/domain/repositories/monthly_quest_repository.dart`
Expected: `No issues found!`

### Task 3.3: Create GetMonthlyQuestProgressUseCase

**Files:**
- Create: `lib/domain/usecases/monthly_quest/get_monthly_quest_progress_usecase.dart`

- [ ] **Step 1: Create directory and file**

First, verify the parent path exists:
Run: `ls lib/domain/usecases/`

Then create the file:

```dart
import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../entities/monthly_quest.dart';
import '../../repositories/monthly_quest_repository.dart';
import '../usecase.dart';

class GetMonthlyQuestProgressUseCase
    implements UseCase<List<MonthlyQuestProgress>, GetMonthlyQuestProgressParams> {
  const GetMonthlyQuestProgressUseCase(this._repository);

  final MonthlyQuestRepository _repository;

  @override
  Future<Either<Failure, List<MonthlyQuestProgress>>> call(
    GetMonthlyQuestProgressParams params,
  ) {
    return _repository.getMonthlyQuestProgress(params.userId);
  }
}

class GetMonthlyQuestProgressParams {
  const GetMonthlyQuestProgressParams({required this.userId});

  final String userId;
}
```

- [ ] **Step 2: Verify analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/domain/usecases/monthly_quest/`
Expected: `No issues found!`

- [ ] **Step 3: Commit domain layer**

```bash
cd /Users/wonderelt/Desktop/Owlio
git add lib/domain/entities/monthly_quest.dart lib/domain/repositories/monthly_quest_repository.dart lib/domain/usecases/monthly_quest/
git commit -m "feat(domain): monthly quest entity, repository interface, usecase"
```

---

## Phase 4 — Mobile App: Data Layer

### Task 4.1: Create MonthlyQuestProgressModel

**Files:**
- Create: `lib/data/models/monthly_quest/monthly_quest_progress_model.dart`

- [ ] **Step 1: Create the model file**

```dart
import '../../../domain/entities/monthly_quest.dart';

class MonthlyQuestProgressModel {
  const MonthlyQuestProgressModel({
    required this.questId,
    required this.questType,
    required this.title,
    required this.icon,
    required this.goalValue,
    required this.currentValue,
    required this.isCompleted,
    required this.rewardType,
    required this.rewardAmount,
    required this.rewardAwarded,
    required this.newlyCompleted,
    required this.periodKey,
    required this.daysLeft,
    required this.badgeId,
    required this.badgeAwarded,
  });

  factory MonthlyQuestProgressModel.fromJson(Map<String, dynamic> json) {
    return MonthlyQuestProgressModel(
      questId: json['quest_id'] as String,
      questType: json['quest_type'] as String,
      title: json['title'] as String,
      icon: json['icon'] as String? ?? '🏆',
      goalValue: json['goal_value'] as int,
      currentValue: json['current_value'] as int,
      isCompleted: json['is_completed'] as bool,
      rewardType: json['reward_type'] as String,
      rewardAmount: json['reward_amount'] as int,
      rewardAwarded: json['reward_awarded'] as bool,
      newlyCompleted: json['newly_completed'] as bool? ?? false,
      periodKey: json['period_key'] as String,
      daysLeft: json['days_left'] as int,
      badgeId: json['badge_id'] as String?,
      badgeAwarded: json['badge_awarded'] as bool? ?? false,
    );
  }

  final String questId;
  final String questType;
  final String title;
  final String icon;
  final int goalValue;
  final int currentValue;
  final bool isCompleted;
  final String rewardType;
  final int rewardAmount;
  final bool rewardAwarded;
  final bool newlyCompleted;
  final String periodKey;
  final int daysLeft;
  final String? badgeId;
  final bool badgeAwarded;

  MonthlyQuestProgress toEntity() {
    return MonthlyQuestProgress(
      quest: MonthlyQuest(
        id: questId,
        questType: questType,
        title: title,
        icon: icon,
        goalValue: goalValue,
        rewardType: _parseRewardType(rewardType),
        rewardAmount: rewardAmount,
        badgeId: badgeId,
      ),
      currentValue: currentValue,
      isCompleted: isCompleted,
      rewardAwarded: rewardAwarded,
      newlyCompleted: newlyCompleted,
      periodKey: periodKey,
      daysLeft: daysLeft,
      badgeAwarded: badgeAwarded,
    );
  }

  static QuestRewardType _parseRewardType(String type) {
    switch (type) {
      case 'xp':
        return QuestRewardType.xp;
      case 'coins':
        return QuestRewardType.coins;
      case 'card_pack':
        return QuestRewardType.cardPack;
      default:
        return QuestRewardType.xp;
    }
  }
}
```

- [ ] **Step 2: Verify analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/data/models/monthly_quest/`
Expected: `No issues found!`

### Task 4.2: Create SupabaseMonthlyQuestRepository

**Files:**
- Create: `lib/data/repositories/supabase/supabase_monthly_quest_repository.dart`

- [ ] **Step 1: Create the repository implementation**

```dart
import 'package:dartz/dartz.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/entities/monthly_quest.dart';
import '../../../domain/repositories/monthly_quest_repository.dart';
import '../../models/monthly_quest/monthly_quest_progress_model.dart';

class SupabaseMonthlyQuestRepository implements MonthlyQuestRepository {
  const SupabaseMonthlyQuestRepository(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, List<MonthlyQuestProgress>>> getMonthlyQuestProgress(
    String userId,
  ) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.getMonthlyQuestProgress,
        params: {'p_user_id': userId},
      );
      final list = (response as List)
          .map((json) => MonthlyQuestProgressModel.fromJson(json as Map<String, dynamic>).toEntity())
          .toList();
      return Right(list);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
```

- [ ] **Step 2: Verify analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/data/repositories/supabase/supabase_monthly_quest_repository.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit data layer**

```bash
cd /Users/wonderelt/Desktop/Owlio
git add lib/data/models/monthly_quest/ lib/data/repositories/supabase/supabase_monthly_quest_repository.dart
git commit -m "feat(data): monthly quest model + Supabase repository"
```

---

## Phase 5 — Mobile App: Presentation Providers

### Task 5.1: Register monthlyQuestRepositoryProvider

**Files:**
- Modify: `lib/presentation/providers/repository_providers.dart` (around line 156 where `dailyQuestRepositoryProvider` lives)

- [ ] **Step 1: Find the dailyQuestRepositoryProvider block**

Run: `grep -n "dailyQuestRepositoryProvider" lib/presentation/providers/repository_providers.dart`
Expected: Outputs the line where it's declared.

- [ ] **Step 2: Add imports at top of file (if not already present)**

Locate the imports block and ensure these exist; add missing ones alphabetically grouped with other data-layer/domain imports:

```dart
import '../../data/repositories/supabase/supabase_monthly_quest_repository.dart';
import '../../domain/repositories/monthly_quest_repository.dart';
```

- [ ] **Step 3: Add the provider right after dailyQuestRepositoryProvider**

Insert immediately after the `dailyQuestRepositoryProvider` block (look for its closing `});`):

```dart
final monthlyQuestRepositoryProvider = Provider<MonthlyQuestRepository>((ref) {
  return SupabaseMonthlyQuestRepository(Supabase.instance.client);
});
```

- [ ] **Step 4: Verify analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/providers/repository_providers.dart`
Expected: `No issues found!`

### Task 5.2: Register getMonthlyQuestProgressUseCaseProvider

**Files:**
- Modify: `lib/presentation/providers/usecase_providers.dart` (around line 728 where daily quest usecase providers live)

- [ ] **Step 1: Find the daily quest usecase block**

Run: `grep -n "DailyQuest\|daily_quest" lib/presentation/providers/usecase_providers.dart`
Expected: Finds import + 3 usecase provider declarations.

- [ ] **Step 2: Add import**

Add to the imports block:

```dart
import '../../domain/usecases/monthly_quest/get_monthly_quest_progress_usecase.dart';
```

- [ ] **Step 3: Add the usecase provider**

Insert right after `hasDailyBonusClaimedUseCaseProvider` (the last daily quest usecase provider):

```dart
final getMonthlyQuestProgressUseCaseProvider =
    Provider<GetMonthlyQuestProgressUseCase>((ref) {
  return GetMonthlyQuestProgressUseCase(ref.watch(monthlyQuestRepositoryProvider));
});
```

- [ ] **Step 4: Verify analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/providers/usecase_providers.dart`
Expected: `No issues found!`

### Task 5.3: Create monthlyQuestProgressProvider

**Files:**
- Create: `lib/presentation/providers/monthly_quest_provider.dart`

- [ ] **Step 1: Create the provider file**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/monthly_quest.dart';
import '../../domain/usecases/monthly_quest/get_monthly_quest_progress_usecase.dart';
import 'auth_provider.dart';
import 'usecase_providers.dart';

/// Provides monthly quest progress for the current user.
/// Returns list of MonthlyQuestProgress from server-side RPC.
/// Auto-awards rewards server-side on completion (same pattern as daily).
final monthlyQuestProgressProvider =
    FutureProvider<List<MonthlyQuestProgress>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final useCase = ref.watch(getMonthlyQuestProgressUseCaseProvider);
  final result = await useCase(GetMonthlyQuestProgressParams(userId: userId));
  return result.fold(
    (failure) {
      debugPrint('monthlyQuestProgressProvider error: ${failure.message}');
      return [];
    },
    (progress) => progress,
  );
});
```

- [ ] **Step 2: Verify analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/providers/monthly_quest_provider.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit presentation providers**

```bash
cd /Users/wonderelt/Desktop/Owlio
git add lib/presentation/providers/repository_providers.dart lib/presentation/providers/usecase_providers.dart lib/presentation/providers/monthly_quest_provider.dart
git commit -m "feat(presentation): register monthly quest providers"
```

---

## Phase 6 — Mobile App: Widget Wiring

### Task 6.1: Wire _MonthlyQuestCard in quests_screen.dart

**Files:**
- Modify: `lib/presentation/screens/quests/quests_screen.dart:337-478`

- [ ] **Step 1: Add provider import**

At the top of `quests_screen.dart`, add near the other provider imports (after `daily_quest_provider.dart`):

```dart
import '../../providers/monthly_quest_provider.dart';
```

- [ ] **Step 2: Replace _MonthlyQuestCard with ConsumerWidget**

Locate the class `_MonthlyQuestCard extends StatelessWidget` (starts at ~line 337). Replace the entire class definition (up to its closing `}` at ~line 478) with:

```dart
class _MonthlyQuestCard extends ConsumerWidget {
  const _MonthlyQuestCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(monthlyQuestProgressProvider);
    final list = progressAsync.valueOrNull ?? const [];
    if (list.isEmpty) {
      return const SizedBox.shrink();
    }
    final progress = list.first;
    final now = AppClock.now();
    final monthName = DateFormat('MMMM').format(now);
    final daysLeft = progress.daysLeft;
    final fill = progress.goalValue > 0
        ? (progress.currentValue / progress.goalValue).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.streakOrange,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFC76A00),
            offset: Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  monthName.toUpperCase(),
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcons.schedule(size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$daysLeft DAYS',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$monthName Quest',
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progress.quest.title,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 20,
                  child: Stack(
                    children: [
                      Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.neutral.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: fill,
                        child: Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.streakOrange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          '${progress.currentValue} / ${progress.goalValue}',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Verify analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/screens/quests/quests_screen.dart`
Expected: `No issues found!`

### Task 6.2: Wire _MonthlyBadgesCard in quests_screen.dart

**Files:**
- Modify: `lib/presentation/screens/quests/quests_screen.dart:692-769`

- [ ] **Step 1: Locate the _MonthlyBadgesCard class**

Run: `grep -n "class _MonthlyBadgesCard" lib/presentation/screens/quests/quests_screen.dart`
Expected: Outputs line ~692.

- [ ] **Step 2: Replace _MonthlyBadgesCard with ConsumerWidget**

Replace the entire class (from `class _MonthlyBadgesCard extends StatelessWidget` to its closing `}`) with:

```dart
class _MonthlyBadgesCard extends ConsumerWidget {
  const _MonthlyBadgesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(monthlyQuestProgressProvider);
    final list = progressAsync.valueOrNull ?? const [];
    final hasBadge = list.isNotEmpty && list.first.quest.badgeId != null;
    final earned = list.isNotEmpty && list.first.badgeAwarded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neutral, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.neutral,
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'MONTHLY BADGES',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.neutralText,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.streakOrange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasBadge && earned ? Icons.military_tech_rounded : Icons.lock_outline_rounded,
              size: 32,
              color: AppColors.streakOrange,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasBadge
                ? (earned ? 'Badge earned this month!' : 'Complete the monthly quest to earn your badge')
                : 'Earn your first badge!',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasBadge
                ? 'A special badge is attached to this month\'s quest.'
                : 'Complete monthly challenges to earn exclusive badges and rewards.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.neutralText,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Verify analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/screens/quests/quests_screen.dart`
Expected: `No issues found!`

### Task 6.3: Wire _MonthlyQuestSidebarCard in right_info_panel.dart

**Files:**
- Modify: `lib/presentation/widgets/shell/right_info_panel.dart:1353-1467`

- [ ] **Step 1: Add provider import**

At top of `right_info_panel.dart`, add:

```dart
import '../../providers/monthly_quest_provider.dart';
```

- [ ] **Step 2: Replace _MonthlyQuestSidebarCard**

Locate `class _MonthlyQuestSidebarCard extends StatelessWidget` and replace the entire class with:

```dart
class _MonthlyQuestSidebarCard extends ConsumerWidget {
  const _MonthlyQuestSidebarCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(monthlyQuestProgressProvider);
    final list = progressAsync.valueOrNull ?? const [];
    if (list.isEmpty) {
      return const SizedBox.shrink();
    }
    final progress = list.first;
    final now = DateTime.now();
    final monthName = DateFormat('MMMM').format(now);
    final daysLeft = progress.daysLeft;
    final fill = progress.goalValue > 0
        ? (progress.currentValue / progress.goalValue).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.streakOrange,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFC76A00),
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              monthName.toUpperCase(),
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$monthName Quest',
            style: GoogleFonts.nunito(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              AppIcons.schedule(size: 13),
              const SizedBox(width: 3),
              Text(
                '$daysLeft DAYS',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progress.quest.title,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fill,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    color: Colors.white,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${progress.currentValue} / ${progress.goalValue}',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Verify analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/widgets/shell/right_info_panel.dart`
Expected: `No issues found!`

### Task 6.4: Wire _MonthlyBadgesSidebarCard in right_info_panel.dart

**Files:**
- Modify: `lib/presentation/widgets/shell/right_info_panel.dart:1469-1531`

- [ ] **Step 1: Replace _MonthlyBadgesSidebarCard**

Replace the entire class `class _MonthlyBadgesSidebarCard extends StatelessWidget` with:

```dart
class _MonthlyBadgesSidebarCard extends ConsumerWidget {
  const _MonthlyBadgesSidebarCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(monthlyQuestProgressProvider);
    final list = progressAsync.valueOrNull ?? const [];
    final hasBadge = list.isNotEmpty && list.first.quest.badgeId != null;
    final earned = list.isNotEmpty && list.first.badgeAwarded;

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
            'MONTHLY BADGES',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: AppColors.neutralText,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasBadge
                ? (earned ? 'Badge earned!' : 'Badge awaits this month')
                : 'Earn your first badge!',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasBadge
                ? 'Complete the monthly quest to claim it.'
                : "Complete each month's challenge to earn exclusive badges",
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: AppColors.neutralText,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.streakOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasBadge && earned ? Icons.military_tech_rounded : Icons.lock_outline_rounded,
                size: 36,
                color: AppColors.streakOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/widgets/shell/right_info_panel.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit widget wiring**

```bash
cd /Users/wonderelt/Desktop/Owlio
git add lib/presentation/screens/quests/quests_screen.dart lib/presentation/widgets/shell/right_info_panel.dart
git commit -m "feat(ui): wire monthly quest + badge cards to provider"
```

---

## Phase 7 — Mobile App: Invalidation Integration

### Task 7.1: Invalidate monthly from book_provider (chapter completion)

**Files:**
- Modify: `lib/presentation/providers/book_provider.dart:198`

- [ ] **Step 1: Add provider import**

At the top of `book_provider.dart`, ensure the monthly provider is imported:

```dart
import 'monthly_quest_provider.dart';
```

- [ ] **Step 2: Add monthly invalidation right after daily invalidation**

Locate line 198:
```dart
      _ref.invalidate(dailyQuestProgressProvider); // Refresh daily quest
```

Add immediately after:
```dart
      _ref.invalidate(monthlyQuestProgressProvider); // Refresh monthly quest
```

- [ ] **Step 3: Verify analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/providers/book_provider.dart`
Expected: `No issues found!`

### Task 7.2: Invalidate monthly from reader_provider (inline activity)

**Files:**
- Modify: `lib/presentation/providers/reader_provider.dart:479`

- [ ] **Step 1: Add provider import**

```dart
import 'monthly_quest_provider.dart';
```

- [ ] **Step 2: Add invalidation right after line 479**

Locate:
```dart
    ref.invalidate(dailyQuestProgressProvider);
```

Add after:
```dart
    ref.invalidate(monthlyQuestProgressProvider);
```

- [ ] **Step 3: Verify analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/providers/reader_provider.dart`
Expected: `No issues found!`

### Task 7.3: Invalidate monthly from vocabulary_provider (session save)

**Files:**
- Modify: `lib/presentation/providers/vocabulary_provider.dart:1033`

- [ ] **Step 1: Add provider import**

```dart
import 'monthly_quest_provider.dart';
```

- [ ] **Step 2: Add invalidation right after line 1033**

Locate:
```dart
        _ref.invalidate(dailyQuestProgressProvider);
```

Add after:
```dart
        _ref.invalidate(monthlyQuestProgressProvider);
```

- [ ] **Step 3: Verify analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/providers/vocabulary_provider.dart`
Expected: `No issues found!`

### Task 7.4: Invalidate monthly from daily_review_screen

**Files:**
- Modify: `lib/presentation/screens/vocabulary/daily_review_screen.dart:147`

- [ ] **Step 1: Add provider import**

```dart
import '../../providers/monthly_quest_provider.dart';
```

- [ ] **Step 2: Add invalidation right after line 147**

Locate:
```dart
    ref.invalidate(dailyQuestProgressProvider); // Refresh daily quest
```

Add after:
```dart
    ref.invalidate(monthlyQuestProgressProvider); // Refresh monthly quest
```

- [ ] **Step 3: Verify analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/screens/vocabulary/daily_review_screen.dart`
Expected: `No issues found!`

### Task 7.5: Invalidate monthly from daily_quest_provider microtask

**Files:**
- Modify: `lib/presentation/providers/daily_quest_provider.dart:45-54` and `:108`

Context: When daily quests get newly completed, we must invalidate monthly so that `quest_type='complete_daily_quests'` counters stay in sync.

- [ ] **Step 1: Add monthly provider import**

At top of `daily_quest_provider.dart`, add:

```dart
import 'monthly_quest_provider.dart';
```

- [ ] **Step 2: Add invalidation inside the Future.microtask block (~line 45-54)**

Locate:
```dart
        Future.microtask(() {
          // Skip if an event is already pending (prevents duplicate on rapid invalidations).
          if (ref.read(questCompletionEventProvider) != null) return;
          ref.read(questCompletionEventProvider.notifier).state =
              QuestCompletionEvent(
            completedQuests: newlyCompleted,
            allQuestsComplete: allComplete,
          );
        });
```

Replace with:
```dart
        Future.microtask(() {
          // Skip if an event is already pending (prevents duplicate on rapid invalidations).
          if (ref.read(questCompletionEventProvider) != null) return;
          ref.read(questCompletionEventProvider.notifier).state =
              QuestCompletionEvent(
            completedQuests: newlyCompleted,
            allQuestsComplete: allComplete,
          );
          // Refresh monthly quest so 'complete_daily_quests' counter stays in sync.
          ref.invalidate(monthlyQuestProgressProvider);
        });
```

- [ ] **Step 3: Add invalidation inside DailyQuestController.claimBonus (~line 108)**

Locate:
```dart
      (_) {
        _ref.invalidate(dailyQuestProgressProvider);
        _ref.invalidate(dailyBonusClaimedProvider);
        _ref.read(userControllerProvider.notifier).refreshProfileOnly();
        state = const AsyncValue.data(null);
        return null;
      },
```

**Do NOT add a monthly invalidation here.** (Claiming the daily bonus pack does not affect the monthly counter — it's a separate concept. Per spec's invalidation map, daily bonus claim is explicitly skipped for monthly.)

Leave this block as-is. This step confirms no-change via review.

- [ ] **Step 4: Verify analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/providers/daily_quest_provider.dart`
Expected: `No issues found!`

### Task 7.6: Keep-alive monthly provider in notification_listener

**Files:**
- Modify: `lib/presentation/widgets/common/notification_listener.dart:76`

Context: The notification listener already keeps `dailyQuestProgressProvider` alive so invalidations fire the completion event even when the quest screen isn't visited. Do the same for monthly to keep provider alive for cross-screen updates.

- [ ] **Step 1: Add provider import**

```dart
import '../../providers/monthly_quest_provider.dart';
```

- [ ] **Step 2: Add keep-alive watch after line 76**

Locate:
```dart
        ref.watch(dailyQuestProgressProvider);
```

Add after:
```dart
        ref.watch(monthlyQuestProgressProvider);
```

- [ ] **Step 3: Verify analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/widgets/common/notification_listener.dart`
Expected: `No issues found!`

- [ ] **Step 4: Full analyze + commit**

```bash
cd /Users/wonderelt/Desktop/Owlio
dart analyze lib/
```
Expected: `No issues found!` across the whole `lib/`.

```bash
git add lib/presentation/providers/book_provider.dart \
        lib/presentation/providers/reader_provider.dart \
        lib/presentation/providers/vocabulary_provider.dart \
        lib/presentation/screens/vocabulary/daily_review_screen.dart \
        lib/presentation/providers/daily_quest_provider.dart \
        lib/presentation/widgets/common/notification_listener.dart
git commit -m "feat(invalidation): refresh monthly quest on activity events"
```

---

## Phase 8 — Admin Panel

### Task 8.1: Extract shared QuestCard widget

**Files:**
- Create: `owlio_admin/lib/features/quests/widgets/quest_card.dart`
- Modify: `owlio_admin/lib/features/quests/screens/quest_list_screen.dart` (remove `_QuestCard`, import the new one)

- [ ] **Step 1: Create `widgets/` directory and the QuestCard file**

```bash
mkdir -p /Users/wonderelt/Desktop/Owlio/owlio_admin/lib/features/quests/widgets
```

Then create `owlio_admin/lib/features/quests/widgets/quest_card.dart`:

```dart
import 'package:flutter/material.dart';

/// Generic quest card used by both Daily and Monthly tabs.
///
/// - [tableName]: table to UPDATE on field change
/// - [showBadgePicker]: if true, renders a badge-picker dropdown (monthly only)
/// - [showStats]: if true, renders the stats footer (daily only)
/// - [badges]: list of active badges (for monthly picker); ignored if showBadgePicker=false
class QuestCard extends StatefulWidget {
  const QuestCard({
    required this.quest,
    required this.stats,
    required this.onUpdate,
    required this.savingFields,
    required this.questId,
    required this.showBadgePicker,
    required this.showStats,
    this.badges = const [],
    super.key,
  });

  final Map<String, dynamic> quest;
  final Map<String, dynamic>? stats;
  final void Function(Map<String, dynamic> fields) onUpdate;
  final Set<String> savingFields;
  final String questId;
  final bool showBadgePicker;
  final bool showStats;
  final List<Map<String, dynamic>> badges;

  @override
  State<QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends State<QuestCard> {
  late TextEditingController _titleController;
  late TextEditingController _iconController;
  late TextEditingController _goalController;
  late TextEditingController _rewardAmountController;
  late TextEditingController _sortOrderController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.quest['title'] as String? ?? '');
    _iconController = TextEditingController(text: widget.quest['icon'] as String? ?? '');
    _goalController = TextEditingController(
        text: (widget.quest['goal_value'] as int?)?.toString() ?? '1');
    _rewardAmountController = TextEditingController(
        text: (widget.quest['reward_amount'] as int?)?.toString() ?? '0');
    _sortOrderController = TextEditingController(
        text: (widget.quest['sort_order'] as int?)?.toString() ?? '0');
  }

  @override
  void didUpdateWidget(covariant QuestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final q = widget.quest;
    if (!widget.savingFields.contains('${widget.questId}-title')) {
      _titleController.text = q['title'] as String? ?? '';
    }
    if (!widget.savingFields.contains('${widget.questId}-icon')) {
      _iconController.text = q['icon'] as String? ?? '';
    }
    if (!widget.savingFields.contains('${widget.questId}-goal_value')) {
      _goalController.text = (q['goal_value'] as int?)?.toString() ?? '1';
    }
    if (!widget.savingFields.contains('${widget.questId}-reward_amount')) {
      _rewardAmountController.text = (q['reward_amount'] as int?)?.toString() ?? '0';
    }
    if (!widget.savingFields.contains('${widget.questId}-sort_order')) {
      _sortOrderController.text = (q['sort_order'] as int?)?.toString() ?? '0';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _iconController.dispose();
    _goalController.dispose();
    _rewardAmountController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quest = widget.quest;
    final stats = widget.stats;
    final isActive = quest['is_active'] as bool? ?? true;
    final rewardType = quest['reward_type'] as String? ?? 'xp';
    final questType = quest['quest_type'] as String? ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 40,
                  child: TextField(
                    controller: _iconController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (v) => widget.onUpdate({'icon': v}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (v) {
                      if (v.isNotEmpty) widget.onUpdate({'title': v});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 13,
                    color: isActive ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Switch(
                  value: isActive,
                  onChanged: (v) => widget.onUpdate({'is_active': v}),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Chip(
              label: Text(questType),
              backgroundColor: Colors.grey.shade100,
              labelStyle: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                _buildNumberField(label: 'Goal', controller: _goalController, fieldName: 'goal_value', minValue: 1),
                _buildRewardTypeDropdown(rewardType),
                _buildNumberField(label: 'Amount', controller: _rewardAmountController, fieldName: 'reward_amount', minValue: 1),
                _buildNumberField(label: 'Order', controller: _sortOrderController, fieldName: 'sort_order', minValue: 0),
                if (widget.showBadgePicker) _buildBadgePicker(quest['badge_id'] as String?),
              ],
            ),
            if (widget.showStats && stats != null) ...[
              const SizedBox(height: 16),
              Divider(color: Colors.grey.shade200),
              const SizedBox(height: 8),
              _buildStatsRow(stats),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
    required String fieldName,
    required int minValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        SizedBox(
          width: 80,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onSubmitted: (v) {
              final parsed = int.tryParse(v);
              if (parsed != null && parsed >= minValue) {
                widget.onUpdate({fieldName: parsed});
              } else {
                controller.text = (widget.quest[fieldName] as int?)?.toString() ?? '$minValue';
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRewardTypeDropdown(String rewardType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reward', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        DropdownButton<String>(
          value: rewardType,
          isDense: true,
          items: const [
            DropdownMenuItem(value: 'xp', child: Text('XP')),
            DropdownMenuItem(value: 'coins', child: Text('Coins')),
            DropdownMenuItem(value: 'card_pack', child: Text('Card Pack')),
          ],
          onChanged: (v) {
            if (v != null && v != rewardType) {
              widget.onUpdate({'reward_type': v});
            }
          },
        ),
      ],
    );
  }

  Widget _buildBadgePicker(String? currentBadgeId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Badge', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        DropdownButton<String?>(
          value: currentBadgeId,
          isDense: true,
          hint: const Text('— No badge —'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('— No badge —')),
            for (final b in widget.badges)
              DropdownMenuItem<String?>(
                value: b['id'] as String,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text((b['icon'] as String?) ?? '🏅'),
                    const SizedBox(width: 6),
                    Text((b['name'] as String?) ?? ''),
                  ],
                ),
              ),
          ],
          onChanged: (v) => widget.onUpdate({'badge_id': v}),
        ),
      ],
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> stats) {
    final todayCompleted = stats['today_completed'] as int? ?? 0;
    final totalUsers = stats['today_total_users'] as int? ?? 0;
    final pct = totalUsers > 0 ? (todayCompleted / totalUsers * 100).round() : 0;
    final avg7d = stats['avg_daily_7d'];
    final avgFormatted = avg7d is num ? avg7d.toStringAsFixed(1) : '0.0';

    return Row(
      children: [
        Icon(Icons.bar_chart, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text('Today: $todayCompleted/$totalUsers students ($pct%)',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(width: 24),
        Text('Last 7 days: $avgFormatted/day avg',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/features/quests/widgets/quest_card.dart`
Expected: `No issues found!`

### Task 8.2: Create the two tab widgets and refactor quest_list_screen

**Files:**
- Create: `owlio_admin/lib/features/quests/screens/tabs/daily_quests_tab.dart`
- Create: `owlio_admin/lib/features/quests/screens/tabs/monthly_quests_tab.dart`
- Modify: `owlio_admin/lib/features/quests/screens/quest_list_screen.dart` (replace body with TabBar)

- [ ] **Step 1: Create `tabs/` directory**

```bash
mkdir -p /Users/wonderelt/Desktop/Owlio/owlio_admin/lib/features/quests/screens/tabs
```

- [ ] **Step 2: Create `daily_quests_tab.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../../core/supabase_client.dart';
import '../../widgets/quest_card.dart';

/// Provider: Daily quest definitions ordered by sort_order.
final dailyQuestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.dailyQuests)
      .select()
      .order('sort_order', ascending: true);
  return List<Map<String, dynamic>>.from(response);
});

/// Provider: Daily quest completion stats (admin-only RPC).
final dailyQuestStatsProvider =
    FutureProvider<Map<String, Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase.rpc(RpcFunctions.getQuestCompletionStats);
  final list = List<Map<String, dynamic>>.from(response);
  final map = <String, Map<String, dynamic>>{};
  for (final row in list) {
    map[row['quest_id'] as String] = row;
  }
  return map;
});

class DailyQuestsTab extends ConsumerStatefulWidget {
  const DailyQuestsTab({super.key});

  @override
  ConsumerState<DailyQuestsTab> createState() => _DailyQuestsTabState();
}

class _DailyQuestsTabState extends ConsumerState<DailyQuestsTab>
    with AutomaticKeepAliveClientMixin {
  final Set<String> _savingFields = {};

  @override
  bool get wantKeepAlive => true;

  Future<void> _update(String questId, Map<String, dynamic> fields) async {
    final fieldKey = '$questId-${fields.keys.first}';
    if (_savingFields.contains(fieldKey)) return;
    setState(() => _savingFields.add(fieldKey));

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from(DbTables.dailyQuests).update(fields).eq('id', questId);
      if (mounted) {
        ref.invalidate(dailyQuestsProvider);
        ref.invalidate(dailyQuestStatsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${fields.keys.first} updated'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            width: 200,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingFields.remove(fieldKey));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final questsAsync = ref.watch(dailyQuestsProvider);
    final statsAsync = ref.watch(dailyQuestStatsProvider);

    return questsAsync.when(
      data: (quests) {
        final stats = statsAsync.valueOrNull ?? {};
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoBanner('Changes take effect immediately for all users.', Colors.orange),
              const SizedBox(height: 24),
              ...quests.map((quest) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: QuestCard(
                      quest: quest,
                      stats: stats[quest['id'] as String],
                      onUpdate: (fields) => _update(quest['id'] as String, fields),
                      savingFields: _savingFields,
                      questId: quest['id'] as String,
                      showBadgePicker: false,
                      showStats: true,
                    ),
                  )),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                ref.invalidate(dailyQuestsProvider);
                ref.invalidate(dailyQuestStatsProvider);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBanner(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color.shade700),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: color.shade900))),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Create `monthly_quests_tab.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../../core/supabase_client.dart';
import '../../widgets/quest_card.dart';

/// Provider: Monthly quest definitions.
final monthlyQuestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.monthlyQuests)
      .select()
      .order('sort_order', ascending: true);
  return List<Map<String, dynamic>>.from(response);
});

/// Provider: Active badges for the badge-picker dropdown.
final activeBadgesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.badges)
      .select('id, name, icon')
      .eq('is_active', true)
      .order('name');
  return List<Map<String, dynamic>>.from(response);
});

class MonthlyQuestsTab extends ConsumerStatefulWidget {
  const MonthlyQuestsTab({super.key});

  @override
  ConsumerState<MonthlyQuestsTab> createState() => _MonthlyQuestsTabState();
}

class _MonthlyQuestsTabState extends ConsumerState<MonthlyQuestsTab>
    with AutomaticKeepAliveClientMixin {
  final Set<String> _savingFields = {};

  @override
  bool get wantKeepAlive => true;

  Future<void> _update(String questId, Map<String, dynamic> fields) async {
    final fieldKey = '$questId-${fields.keys.first}';
    if (_savingFields.contains(fieldKey)) return;
    setState(() => _savingFields.add(fieldKey));

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from(DbTables.monthlyQuests).update(fields).eq('id', questId);
      if (mounted) {
        ref.invalidate(monthlyQuestsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${fields.keys.first} updated'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            width: 200,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingFields.remove(fieldKey));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final questsAsync = ref.watch(monthlyQuestsProvider);
    final badgesAsync = ref.watch(activeBadgesProvider);

    return questsAsync.when(
      data: (quests) {
        final badges = badgesAsync.valueOrNull ?? const [];
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoBanner(
                'Monthly quests reset on the 1st of each month (Istanbul TZ). Badge assignment takes effect on next student completion.',
                Colors.orange,
              ),
              const SizedBox(height: 24),
              ...quests.map((quest) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: QuestCard(
                      quest: quest,
                      stats: null,
                      onUpdate: (fields) => _update(quest['id'] as String, fields),
                      savingFields: _savingFields,
                      questId: quest['id'] as String,
                      showBadgePicker: true,
                      showStats: false,
                      badges: badges,
                    ),
                  )),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                ref.invalidate(monthlyQuestsProvider);
                ref.invalidate(activeBadgesProvider);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBanner(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color.shade700),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: color.shade900))),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Rewrite `quest_list_screen.dart` as tabbed container**

Replace the ENTIRE content of `owlio_admin/lib/features/quests/screens/quest_list_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'tabs/daily_quests_tab.dart';
import 'tabs/monthly_quests_tab.dart';

class QuestListScreen extends ConsumerStatefulWidget {
  const QuestListScreen({super.key});

  @override
  ConsumerState<QuestListScreen> createState() => _QuestListScreenState();
}

class _QuestListScreenState extends ConsumerState<QuestListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quests'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              // Invalidate the provider for the currently selected tab.
              if (_tabController.index == 0) {
                ref.invalidate(dailyQuestsProvider);
                ref.invalidate(dailyQuestStatsProvider);
              } else {
                ref.invalidate(monthlyQuestsProvider);
                ref.invalidate(activeBadgesProvider);
              }
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Daily Quests'),
            Tab(text: 'Monthly Quests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          DailyQuestsTab(),
          MonthlyQuestsTab(),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Verify analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/`
Expected: `No issues found!` across the whole admin project.

- [ ] **Step 6: Commit admin panel changes**

```bash
cd /Users/wonderelt/Desktop/Owlio
git add owlio_admin/lib/features/quests/
git commit -m "feat(admin): tabbed quest screen with monthly tab + badge picker"
```

---

## Phase 9 — Verification

### Task 9.1: Full analyze across all projects

- [ ] **Step 1: Mobile analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/`
Expected: `No issues found!`

- [ ] **Step 2: Admin analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/`
Expected: `No issues found!`

- [ ] **Step 3: Shared package analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio/packages/owlio_shared && dart analyze`
Expected: `No issues found!`

### Task 9.2: Manual E2E smoke test

- [ ] **Step 1: Start the Flutter app**

Run: `cd /Users/wonderelt/Desktop/Owlio && flutter run -d chrome`

- [ ] **Step 2: Sign in as `fresh@demo.com` (password `Test1234`)**

Verify the Quests screen renders with:
- Monthly quest card shows the seed quest: "Complete 20 daily quests this month" 🏆
- Progress shows `0 / 20`
- `DAYS` count matches remaining days in current month
- Monthly Badges card shows "Earn your first badge!" (because `badge_id` is NULL on seed)

- [ ] **Step 3: Trigger a daily quest completion**

Complete one daily quest (e.g., read a chapter to trigger `read_chapters` on daily side). Then return to Quests screen.

Verify:
- Monthly card counter increments (e.g., `1 / 20`)
- Progress bar fills proportionally

- [ ] **Step 4: Verify the ≥1000px sidebar variant**

Resize browser to ≥1000px width. Verify `_MonthlyQuestSidebarCard` appears in the right panel with the same data.

- [ ] **Step 5: Admin-side smoke test**

Open admin panel in a second tab (`http://localhost:XXXX/admin` or the admin URL).

Sign in as `admin@demo.com`. Navigate to `/quests`.

Verify:
- Two tabs visible: "Daily Quests" and "Monthly Quests"
- Click "Monthly Quests" → see the seed quest
- Verify fields editable (title, goal, reward, sort_order)
- Verify Badge dropdown shows "— No badge —" and active badges from the badges table

- [ ] **Step 6: Assign a badge and verify**

In admin Monthly tab, pick any existing badge from the dropdown → update.

Return to student view, trigger completion (or restart app to force fetch). Verify:
- Monthly Badges card now shows the badge name/icon
- After completing the quest, badge appears as "earned"

- [ ] **Step 7: Final commit (no code changes, just marking verification complete)**

If all smoke checks pass, no further commits are needed. Document any regressions as follow-up tickets.

---

## Self-Review Checklist (internal — plan writer ran this, engineer may re-run)

**Spec coverage:**
- Data model (2 tables + RLS + seed) → Task 1.1 ✓
- RPC `get_monthly_quest_progress` → Task 1.1 ✓
- Shared constants → Tasks 2.1, 2.2 ✓
- Domain layer (3 files) → Tasks 3.1-3.3 ✓
- Data layer (2 files) → Tasks 4.1-4.2 ✓
- Presentation providers → Tasks 5.1-5.3 ✓
- Widget wiring (4 widgets) → Tasks 6.1-6.4 ✓
- Invalidation at 6 points → Tasks 7.1-7.6 ✓ (5 from spec + notification_listener keep-alive)
- Admin tabbed refactor → Tasks 8.1-8.2 ✓
- Verification → Tasks 9.1-9.2 ✓

**Placeholder scan:** All steps have concrete code, commands, or explicit "no-change confirmation" (Task 7.5 Step 3). No TBDs.

**Type consistency:** `QuestRewardType` reused from `daily_quest.dart` via `show`+`export`. `MonthlyQuest` / `MonthlyQuestProgress` shapes match model `fromJson` and entity constructor. `badge_id` is `String?` consistently in entity + model; `UUID?` in DB.

**Scope:** Fits one implementation cycle. Admin + mobile can be worked in parallel after Phase 2 completes; Phases 1-7 form a critical path.
