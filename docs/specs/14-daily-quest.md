# Daily Quest

## Audit

### Findings

| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Architecture | `DailyQuestList` widget directly calls `claimDailyBonusUseCaseProvider` instead of going through a controller provider — violates Widget → Provider → UseCase rule | Medium | Fixed |
| 2 | Dead Code | `CardRepository.claimDailyQuestPack()` and `hasDailyQuestPackBeenClaimed()` — legacy methods replaced by `DailyQuestRepository` equivalents, never called from presentation layer | Medium | Fixed |
| 3 | Dead Code | `RpcFunctions.claimDailyQuestPack` and `RpcFunctions.hasDailyQuestPackClaimed` — orphaned shared constants only referenced by dead code in Finding #2 | Medium | Fixed |
| 4 | Dead Code | `DbTables.dailyQuestPackClaims` — orphaned constant, replaced by `DbTables.dailyQuestBonusClaims` | Medium | Fixed |
| 5 | Edge Case | `SupabaseDailyQuestRepository.hasDailyBonusClaimed` uses `DateTime.now().toUtc()` instead of `AppClock.now()` — breaks debug date offset; also client-side UTC date may diverge from server's `app_current_date()` in edge hours | Medium | Fixed |
| 6 | UX | Both providers silently swallow errors (`return []` / `return false`) — quest section disappears on network failure with no retry or error indication | Low | Deferred |
| 7 | Code Quality | `DailyBonusResult` does not extend `Equatable`, unlike `DailyQuest` and `DailyQuestProgress` in the same file | Low | Deferred |
| 8 | Code Quality | `DailyQuestProgressModel` has `fromJson`/`toEntity` but no `toJson` — incomplete model contract (read-only data, so low impact) | Low | Deferred |
| 9 | Code Quality | `_parseRewardType` silently defaults to `QuestRewardType.xp` for unknown type strings — no warning logged | Low | Deferred |
| 10 | Code Quality | Reward text/color logic duplicated between `daily_quest_list.dart` (`_QuestRow._rewardText/_rewardColor`) and `quest_completion_dialog.dart` (`_QuestRewardRow._rewardTextAndColor`) | Low | Deferred |
| 11 | Database | No `CHECK (reward_amount > 0)` constraint on `daily_quests.reward_amount` — UI enforces min=1 but DB does not | Low | Deferred |
| 12 | Database | Bonus pack awarded by `claim_daily_bonus` has no audit log entry in `coin_logs` or `pack_purchases` — the `daily_quest_bonus_claims` table records the claim but not the pack award itself | Low | Deferred |
| 13 | Cross-System | Quest XP rewards go through `award_xp_transaction` which does NOT call `check_and_award_badges` — a student crossing a badge XP threshold via quest rewards alone won't receive the badge until their next vocab/review session | Low | Deferred |
| 14 | Docs | `features.md` Flow 4 (line ~300) references `RpcFunctions.claimDailyQuestPack` but actual implementation uses `RpcFunctions.claimDailyBonus` | Low | Fixed |

### Checklist Result

- Architecture Compliance: PASS (#1 fixed — DailyQuestController extracted)
- Code Quality: 4 deferred (#7–#10 — cosmetic / minor consistency)
- Dead Code: PASS (#2–#4 fixed — legacy card-repository methods and shared constants removed)
- Database & Security: 2 deferred (#11–#12 — minor constraint gap, missing audit log)
- Edge Cases & UX: PASS (#5 fixed — AppClock.now(); #6 deferred — cosmetic)
- Performance: PASS
- Cross-System Integrity: 1 deferred (#13 — badge check gap)

---

## Overview

Daily Quests are a set of daily goals that encourage students to engage with different learning activities each day. The admin configures quest definitions (type, goal, reward); the server-side RPC calculates progress implicitly by counting activity records for the current day. When a quest threshold is crossed, the reward (XP, coins, or card pack) is auto-awarded server-side. When all active quests are complete, a bonus card pack becomes claimable. There is no teacher surface for this feature.

## Data Model

### Tables

**`daily_quests`** (quest definitions, admin-managed):

| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| `id` | UUID | PK, gen_random_uuid() | |
| `quest_type` | VARCHAR(50) | UNIQUE, NOT NULL | Drives RPC CASE dispatch |
| `title` | VARCHAR(200) | NOT NULL | Displayed to student |
| `icon` | VARCHAR(10) | | Emoji icon |
| `goal_value` | INTEGER | NOT NULL | Target count to complete |
| `reward_type` | VARCHAR(50) | CHECK IN ('xp','coins','card_pack') | |
| `reward_amount` | INTEGER | DEFAULT 0 | |
| `is_active` | BOOLEAN | DEFAULT true | Admin toggle |
| `sort_order` | INTEGER | DEFAULT 0 | Display ordering |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | |

**`daily_quest_completions`** (per-quest completion records):

| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| `id` | UUID | PK | |
| `user_id` | UUID | FK → profiles ON DELETE CASCADE | |
| `quest_id` | UUID | FK → daily_quests ON DELETE CASCADE | |
| `completion_date` | DATE | | Istanbul calendar day |
| `reward_awarded` | BOOLEAN | DEFAULT false | Set true after reward issuance |
| `created_at` | TIMESTAMPTZ | | |

UNIQUE(user_id, quest_id, completion_date) — idempotency guard.
Index: `idx_quest_completions_user_date` on (user_id, completion_date).

**`daily_quest_bonus_claims`** (all-quests-complete bonus):

| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| `id` | UUID | PK | |
| `user_id` | UUID | FK → profiles ON DELETE CASCADE | |
| `claim_date` | DATE | | |
| `created_at` | TIMESTAMPTZ | | |

UNIQUE(user_id, claim_date) — one bonus claim per day.

### Key Relationships

- Quest progress is **implicit** — the RPC queries existing activity tables (`daily_chapter_reads`, `vocabulary_sessions`, `daily_review_sessions`), not a progress accumulator.
- `daily_quest_completions` records which quests were completed on which day; also guards against double-reward.
- `daily_quest_bonus_claims` records daily bonus pack claims; UNIQUE constraint prevents double-claim.
- Rewards route through existing functions: `award_xp_transaction` for XP, `award_coins_transaction` for coins, direct `profiles.unopened_packs` update for card packs.

### RLS Policies

| Table | SELECT | INSERT/UPDATE/DELETE |
|-------|--------|---------------------|
| `daily_quests` | All authenticated | Admin role only (FOR ALL + USING) |
| `daily_quest_completions` | Own rows (`user_id = auth.uid()`) | Blocked — SECURITY DEFINER RPCs only |
| `daily_quest_bonus_claims` | Own rows (`user_id = auth.uid()`) | Blocked — SECURITY DEFINER RPCs only |

## Surfaces

### Admin

**Screen:** `owlio_admin/lib/features/quests/screens/quest_list_screen.dart`

Admin can:
- Toggle `is_active` on/off per quest (Switch widget)
- Edit `title`, `icon`, `goal_value`, `reward_amount`, `sort_order` inline
- Change `reward_type` via dropdown (XP / Coins / Card Pack)
- View per-quest stats: today's completions, total students, 7-day average (via `get_quest_completion_stats` RPC)

Admin cannot:
- Create new quest definitions (requires migration or direct SQL)
- Delete quest definitions
- Change `quest_type` (read-only chip — changing it without updating RPC CASE logic would break progress)

Dashboard integration: active quest count shown as a stat tile on the admin dashboard.

### Student

**Embedded in Home Screen** — no dedicated quest screen. `DailyQuestWidget` renders directly in the home scroll column.

**User flow:**
1. Student opens home screen → `dailyQuestProgressProvider` fires `get_daily_quest_progress` RPC
2. RPC counts today's activities per quest type, auto-awards rewards for newly completed quests
3. Flutter renders quest rows with progress bars (current/goal)
4. If any quest was `newly_completed`, `QuestCompletionDialog` auto-shows with reward details
5. When all active quests are complete, a bonus row appears with "Claim Reward!" button
6. Student taps claim → `claim_daily_bonus` RPC → awards +1 card pack → UI updates optimistically

**Key screens/widgets:**
- `DailyQuestWidget` — orchestrator: watches providers, triggers completion dialog
- `DailyQuestList` — renders assignment rows + quest rows + bonus row
- `QuestCompletionDialog` — celebratory popup for newly completed quests

### Teacher

N/A — teachers have no visibility into daily quest progress or completion.

## Business Rules

1. **Progress is implicit** — the server counts activity records for the current calendar day. No explicit "complete quest" event exists.
2. **Reward auto-award** — when `get_daily_quest_progress` detects a completed quest that hasn't been rewarded yet, it awards the reward immediately within the same RPC call. The `newly_completed` flag in the response triggers the client-side dialog.
3. **Idempotency** — `ON CONFLICT DO NOTHING` on `daily_quest_completions` INSERT + pre-check with `SELECT EXISTS` prevents double-awarding even if the RPC runs multiple times.
4. **Daily reset** — no cron job; quests reset naturally because all queries are scoped to `v_today = app_current_date()`.
5. **Bonus pack** — when all active quests are complete, student can manually claim a bonus card pack (+1 to `profiles.unopened_packs`). Claiming is a separate user action, not auto-awarded.
6. **`daily_review` auto-complete** — if a student has fewer than 10 vocabulary words due for review (`next_review_at <= NOW()` and `status != 'mastered'`), the `daily_review` quest auto-completes (sets `v_current = 1`). This means fresh students with no vocabulary will always pass this quest.
7. **Retroactive progress** — because progress counts from existing activity tables, activities completed before a quest is activated mid-day still count.
8. **Quest type dispatch** — the RPC uses a `CASE` statement on `quest_type` to route to the correct counting query. Adding a new quest type requires updating the RPC, not just inserting a DB row.

### Current Quest Configuration (Seed Data)

| Quest Type | Title | Goal | Reward |
|------------|-------|------|--------|
| `daily_review` | Complete Daily Review | 1 session | 20 XP |
| `read_chapters` | Read Chapters | 2 chapters | 10 coins |
| `vocab_session` | Practice Vocabulary | 1 session | 15 XP |

### Reward Types

| Type | Mechanism | Audit Logged |
|------|-----------|-------------|
| `xp` | `award_xp_transaction()` → `xp_logs` + `coin_logs` (XP=coins 1:1) | Yes |
| `coins` | `award_coins_transaction()` → `coin_logs` | Yes |
| `card_pack` | Direct `UPDATE profiles SET unopened_packs += N` | No (Finding #12) |

## Cross-System Interactions

### Reward Chains

```
Quest completed (server-side, inside get_daily_quest_progress)
  → IF reward_type = 'xp':
    → award_xp_transaction(amount, 'daily_quest', quest_id, title)
      → xp_logs INSERT + coin_logs INSERT (1:1 co-award)
      → profiles.xp_total += amount, profiles.coins += amount
      → (badge check NOT called — Finding #13)
  → IF reward_type = 'coins':
    → award_coins_transaction(amount, 'daily_quest', quest_id, title)
      → coin_logs INSERT
      → profiles.coins += amount
  → IF reward_type = 'card_pack':
    → profiles.unopened_packs += amount (no audit log — Finding #12)
  → daily_quest_completions INSERT (ON CONFLICT DO NOTHING)

All quests complete + user claims bonus:
  → claim_daily_bonus RPC
    → daily_quest_bonus_claims INSERT (UNIQUE constraint idempotency)
    → profiles.unopened_packs += 1 (no audit log)
```

### Provider Invalidation Map

`dailyQuestProgressProvider` is invalidated from:

| Trigger | File | Line |
|---------|------|------|
| Chapter completion | `book_provider.dart` | ~210 |
| Inline activity completion | `reader_provider.dart` | ~419 |
| Vocabulary session save | `vocabulary_provider.dart` | ~995 |
| Daily review completion | `daily_review_screen.dart` | ~130 |
| Bonus claimed | `daily_quest_list.dart` | ~61 |

`dailyBonusClaimedProvider` is only invalidated after bonus claim (`daily_quest_list.dart:62`).

### What Daily Quest Does NOT Trigger

- **Streak** — streak updates only on app open (`_updateStreakIfNeeded()`), not on quest completion
- **Badge checks** — `award_xp_transaction` does not call `check_and_award_badges` (unlike `complete_vocabulary_session`)
- **Assignment progress** — quests are independent of the assignment system

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| No active quests | RPC returns empty list; quest section renders empty; bonus row still appears (locked) |
| Activities done before quests activated mid-day | Retroactive — count from existing activity records at query time |
| Network failure on quest load | Provider returns `[]`; entire quest widget renders `SizedBox.shrink()` — no error/retry UI |
| Bonus claim fails (network/already claimed) | `ServerFailure` shown as SnackBar; optimistic `_justClaimed` state may diverge briefly |
| Debug date offset active | `hasDailyBonusClaimed` uses `DateTime.now()` instead of `AppClock.now()` — claim check ignores offset (Finding #5) |
| Student has zero due vocabulary words | `daily_review` quest auto-completes — student passes without doing a session |
| Multiple rapid provider invalidations | `ON CONFLICT DO NOTHING` on completions prevents double-reward; RPC is safe |

### Timezone Note

`app_current_date()` returns `CURRENT_DATE + debug_offset`, which is UTC-based. The `vocab_session` quest type uses Istanbul midnight (`v_istanbul_start`) for its time window, creating a subtle inconsistency: `read_chapters` uses UTC midnight while `vocab_session` uses Istanbul midnight. This rarely matters in practice (Istanbul is UTC+3, so the 3-hour gap is overnight).

## Test Scenarios

- [ ] Happy path: complete all 3 quests through normal activities, verify auto-reward + dialog
- [ ] Empty state: disable all quests in admin → student sees empty quest section
- [ ] Error state: disconnect network → quest widget disappears silently (current behavior)
- [ ] Bonus claim: complete all quests → claim button appears → tap → pack awarded → button becomes "Claimed"
- [ ] Double-claim prevention: claim bonus → force re-render → claim button stays disabled
- [ ] Partial progress: complete 1 of 3 quests → only that quest shows checkmark + reward dialog
- [ ] Retroactive progress: read 2 chapters → admin activates `read_chapters` quest → quest shows completed immediately
- [ ] `daily_review` auto-complete: fresh student (0 vocab) → `daily_review` quest shows complete
- [ ] Admin toggle: deactivate a quest → student no longer sees it → bonus threshold adjusts
- [ ] Admin edit: change `goal_value` → student sees updated target
- [ ] Cross-system XP: complete a quest with XP reward → verify XP/coins both increase on profile
- [ ] Cross-system coins: complete a quest with coin reward → verify `coin_logs` entry exists

## Key Files

### Domain Layer
- `lib/domain/entities/daily_quest.dart` — `DailyQuest`, `DailyQuestProgress`, `DailyBonusResult`, `QuestRewardType`
- `lib/domain/repositories/daily_quest_repository.dart` — repository interface
- `lib/domain/usecases/daily_quest/` — 3 use cases (get progress, claim bonus, check claimed)

### Data Layer
- `lib/data/repositories/supabase/supabase_daily_quest_repository.dart` — RPC calls + direct table query
- `lib/data/models/daily_quest/daily_quest_progress_model.dart` — JSON deserialization

### Presentation Layer
- `lib/presentation/providers/daily_quest_provider.dart` — `dailyQuestProgressProvider`, `dailyBonusClaimedProvider`
- `lib/presentation/widgets/home/daily_quest_widget.dart` — orchestrator (watches + triggers dialog)
- `lib/presentation/widgets/home/daily_quest_list.dart` — quest card rendering + claim action
- `lib/presentation/widgets/home/quest_completion_dialog.dart` — completion popup

### Admin Panel
- `owlio_admin/lib/features/quests/screens/quest_list_screen.dart` — quest management UI

### Database
- `supabase/migrations/20260322000003_daily_quest_engine.sql` — tables, RLS, seed data, original RPCs
- `supabase/migrations/20260325000005_daily_review_min_10_words.sql` — latest RPC versions

### Shared Constants
- `packages/owlio_shared/lib/src/constants/tables.dart` — `dailyQuests`, `dailyQuestCompletions`, `dailyQuestBonusClaims`
- `packages/owlio_shared/lib/src/constants/rpc_functions.dart` — `getDailyQuestProgress`, `claimDailyBonus`, `getQuestCompletionStats`

## Known Issues & Tech Debt

1. ~~**Legacy dead code** (Findings #2–#4)~~ — Fixed: removed dead methods from CardRepository, orphaned RpcFunctions and DbTables constants.
2. ~~**`hasDailyBonusClaimed` timezone bug** (Finding #5)~~ — Fixed: replaced `DateTime.now()` with `AppClock.now()`.
3. ~~**Widget-level UseCase call** (Finding #1)~~ — Fixed: extracted `DailyQuestController` notifier.
4. **No badge check on quest XP** (Finding #13): `award_xp_transaction` does not call `check_and_award_badges`. Students earning XP only via quests won't trigger badge evaluation.
5. **Bonus pack unaudited** (Finding #12): The bonus pack from `claim_daily_bonus` bypasses `pack_purchases` and `coin_logs` — no audit trail for this award.
6. **No create/delete quest in admin**: New quest types require a migration. If product needs change, an admin CRUD flow should be added (noting that `quest_type` changes also require RPC updates).
7. **Legacy DB table**: `daily_quest_pack_claims` table and its two RPCs (`claim_daily_quest_pack`, `has_daily_quest_pack_claimed`) still exist in the database but are no longer called from app code. Can be dropped in a future migration.
