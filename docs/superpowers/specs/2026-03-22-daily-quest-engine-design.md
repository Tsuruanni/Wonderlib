# Daily Quest Engine — Design Spec

**Date:** 2026-03-22
**Scope:** Phase 1 — DB-driven quest engine (DB + main app). Admin dashboard is Phase 2 (separate spec).

---

## Problem

The current daily quest system is hardcoded: 3 fixed quests with compile-time constants, no DB quest definitions, no admin control, timezone inconsistency between quests, and no per-quest rewards. Changing quest goals requires an app update.

---

## Design

### DB Schema

#### New table: `daily_quests` — quest definitions

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID PK DEFAULT gen_random_uuid() | |
| `quest_type` | VARCHAR(50) NOT NULL | `daily_review`, `read_words`, `correct_answers` |
| `title` | VARCHAR(200) NOT NULL | Display name |
| `icon` | VARCHAR(10) | Emoji icon |
| `goal_value` | INTEGER NOT NULL | Target (1, 100, 5) |
| `reward_type` | VARCHAR(50) NOT NULL | `xp`, `coins`, `card_pack` |
| `reward_amount` | INTEGER NOT NULL DEFAULT 0 | Reward quantity |
| `is_active` | BOOLEAN DEFAULT true | Admin toggle |
| `sort_order` | INTEGER DEFAULT 0 | Display order |
| `created_at` | TIMESTAMPTZ DEFAULT NOW() | |

UNIQUE: `(quest_type)` — one definition per type.

RLS: SELECT for all authenticated users. INSERT/UPDATE/DELETE for admins only.

Seed data (replaces hardcoded `DailyGoalConfig`):
```sql
INSERT INTO daily_quests (quest_type, title, icon, goal_value, reward_type, reward_amount, sort_order) VALUES
  ('daily_review', 'Review daily vocab', '📖', 1, 'xp', 20, 1),
  ('read_words', 'Read 100 words', '📚', 100, 'coins', 10, 2),
  ('correct_answers', 'Answer 5 questions', '✅', 5, 'xp', 15, 3);
```

#### New table: `daily_quest_completions` — per-quest completion records

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID PK DEFAULT gen_random_uuid() | |
| `user_id` | UUID NOT NULL FK → profiles ON DELETE CASCADE | |
| `quest_id` | UUID NOT NULL FK → daily_quests ON DELETE CASCADE | |
| `completion_date` | DATE NOT NULL | Istanbul timezone date |
| `reward_claimed` | BOOLEAN DEFAULT false | Whether reward was collected |
| `created_at` | TIMESTAMPTZ DEFAULT NOW() | |

UNIQUE: `(user_id, quest_id, completion_date)` — one completion per quest per day.

RLS: SELECT own rows. INSERT/UPDATE via RPC only.

#### New table: `daily_quest_bonus_claims` — all-quests-complete bonus

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID PK DEFAULT gen_random_uuid() | |
| `user_id` | UUID NOT NULL FK → profiles ON DELETE CASCADE | |
| `claim_date` | DATE NOT NULL | Istanbul timezone date |
| `created_at` | TIMESTAMPTZ DEFAULT NOW() | |

UNIQUE: `(user_id, claim_date)` — one bonus per day. Replaces `daily_quest_pack_claims`.

RLS: SELECT own rows. INSERT via RPC only.

### Timezone

All "today" calculations use Istanbul timezone (UTC+3):

```sql
-- Istanbul today helper (used in all RPCs)
(NOW() AT TIME ZONE 'Europe/Istanbul')::DATE
```

DB timestamps remain UTC. Only date comparisons use Istanbul offset.

Istanbul midnight in UTC: `date_trunc('day', NOW() AT TIME ZONE 'Europe/Istanbul') AT TIME ZONE 'Europe/Istanbul'` — returns UTC timestamp of Istanbul midnight.

### RPC: `get_daily_quest_progress`

Single RPC returns all quest definitions + today's progress for a user:

```sql
CREATE FUNCTION get_daily_quest_progress(p_user_id UUID)
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
  reward_claimed BOOLEAN
)
```

Logic per `quest_type`:
- `daily_review`: `current_value = 1` if EXISTS `daily_review_sessions WHERE user_id AND session_date = istanbul_today`, else `0`
- `read_words`: `current_value = COALESCE(SUM(chapters.word_count), 0)` from `daily_chapter_reads WHERE read_date = istanbul_today`
- `correct_answers`: `current_value = COUNT(*)` from `inline_activity_results WHERE user_id AND is_correct = true AND answered_at >= istanbul_today_start_utc`

`is_completed`: `current_value >= goal_value`
`reward_claimed`: EXISTS in `daily_quest_completions WHERE quest_id AND user_id AND completion_date = istanbul_today`

Only returns `is_active = true` quests, ordered by `sort_order`.

### RPC: `claim_quest_reward`

```sql
CREATE FUNCTION claim_quest_reward(p_user_id UUID, p_quest_id UUID)
RETURNS JSONB
```

Logic:
1. Lock profiles row `FOR UPDATE`
2. Verify quest exists and is_active
3. Verify quest is completed (re-check progress)
4. Check not already claimed today (UNIQUE constraint)
5. INSERT into `daily_quest_completions` (completion_date = istanbul_today, reward_claimed = true)
6. Award reward based on `reward_type`:
   - `xp` → call `award_xp_transaction(p_user_id, reward_amount, 'daily_quest', quest_id, quest_title)`
   - `coins` → INSERT into `coin_logs` + UPDATE `profiles.coins`
   - `card_pack` → UPDATE `profiles.unopened_packs += reward_amount`
7. Return `{ success: true, reward_type, reward_amount }`

### RPC: `claim_daily_bonus`

```sql
CREATE FUNCTION claim_daily_bonus(p_user_id UUID)
RETURNS JSONB
```

Logic:
1. Verify ALL active quests are completed and reward_claimed today
2. Check not already claimed today (UNIQUE on `daily_quest_bonus_claims`)
3. INSERT into `daily_quest_bonus_claims`
4. UPDATE `profiles.unopened_packs += 1`
5. Return `{ success: true, unopened_packs: N }`

### Clean Architecture

**Domain:**

```
lib/domain/entities/daily_quest.dart
  - DailyQuest (id, questType, title, icon, goalValue, rewardType, rewardAmount)
  - DailyQuestProgress (quest: DailyQuest, currentValue, isCompleted, rewardClaimed)
  - QuestRewardType enum (xp, coins, cardPack)

lib/domain/repositories/daily_quest_repository.dart
  - getDailyQuestProgress(userId) → Either<Failure, List<DailyQuestProgress>>
  - claimQuestReward(userId, questId) → Either<Failure, QuestRewardResult>
  - claimDailyBonus(userId) → Either<Failure, DailyBonusResult>
  - hasDailyBonusClaimed(userId) → Either<Failure, bool>

lib/domain/usecases/daily_quest/
  - GetDailyQuestProgressUseCase
  - ClaimQuestRewardUseCase
  - ClaimDailyBonusUseCase
  - HasDailyBonusClaimedUseCase
```

**Data:**

```
lib/data/models/daily_quest/daily_quest_model.dart
  - DailyQuestProgressModel.fromJson → DailyQuestProgress entity

lib/data/repositories/supabase/supabase_daily_quest_repository.dart
  - Calls RPCs: get_daily_quest_progress, claim_quest_reward, claim_daily_bonus
  - has_daily_quest_pack_claimed RPC reused as has_daily_bonus_claimed
```

**Presentation:**

```
lib/presentation/providers/daily_quest_provider.dart
  - dailyQuestProgressProvider (FutureProvider, calls GetDailyQuestProgressUseCase)
  - dailyBonusClaimedProvider (FutureProvider, calls HasDailyBonusClaimedUseCase)

lib/presentation/widgets/home/daily_quest_widget.dart (replaces daily_goal_widget.dart)
  - Loading/error wrapper

lib/presentation/widgets/home/daily_quest_list.dart (replaces daily_tasks_list.dart)
  - Renders quest rows from provider data
  - Each quest row: icon, title, progress bar, reward badge, claim button
  - Bonus row at bottom: locked/claimable/claimed states
  - Teacher assignments still rendered above quests
```

### Files to Delete

| File | Reason |
|------|--------|
| `lib/presentation/providers/daily_goal_provider.dart` | Replaced by daily_quest_provider.dart |
| `lib/presentation/widgets/home/daily_goal_widget.dart` | Replaced by daily_quest_widget.dart |
| `lib/presentation/widgets/home/daily_tasks_list.dart` | Replaced by daily_quest_list.dart |
| `lib/domain/usecases/card/claim_daily_quest_pack_usecase.dart` | Replaced by claim_daily_bonus |
| `lib/domain/usecases/card/has_daily_quest_pack_claimed_usecase.dart` | Replaced by has_daily_bonus_claimed |

### Files to Modify

| File | Change |
|------|--------|
| `lib/presentation/screens/home/home_screen.dart` | Import new widget |
| `lib/presentation/providers/usecase_providers.dart` | Register new use case providers |
| `lib/presentation/providers/repository_providers.dart` | Register new repository provider |
| `lib/presentation/providers/book_provider.dart` | Invalidate dailyQuestProgressProvider instead of old providers |
| `lib/presentation/providers/daily_review_provider.dart` | Invalidate dailyQuestProgressProvider |
| `lib/presentation/providers/reader_provider.dart` | Invalidate dailyQuestProgressProvider |
| `packages/owlio_shared/lib/src/constants/tables.dart` | Add new table constants |
| `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | Add new RPC constants |

### Backward Compatibility

- `daily_quest_pack_claims` table is NOT dropped (data preservation). New `daily_quest_bonus_claims` is used going forward.
- `claim_daily_quest_pack` RPC kept but deprecated. New code uses `claim_daily_bonus`.
- `has_daily_quest_pack_claimed` RPC reused internally by new system for backward compat check.

### Invalidation Triggers (unchanged locations, new provider name)

| Event | Location | New Invalidation |
|-------|----------|-----------------|
| Chapter read complete | `book_provider.dart` | `dailyQuestProgressProvider` |
| Correct activity answer | `reader_provider.dart` | `dailyQuestProgressProvider` |
| Daily review complete | `daily_review_provider.dart` | `dailyQuestProgressProvider` |
| Quest reward claimed | `daily_quest_list.dart` | `dailyQuestProgressProvider` + `userControllerProvider` |
| Bonus claimed | `daily_quest_list.dart` | `dailyQuestProgressProvider` + `dailyBonusClaimedProvider` + `userControllerProvider` |

---

## Out of Scope (Phase 2 — Admin Dashboard)

- Admin CRUD for daily_quests (view/edit goals, rewards, active status)
- Quest completion statistics (how many users complete which quest daily)
- Quest analytics dashboard
