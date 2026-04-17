# Monthly Quest Integration — Design

**Date:** 2026-04-16
**Status:** Design (brainstorm complete, awaiting implementation plan)
**Author:** Brainstorm session — Tsuruanni + Claude

## Problem

The app already has `_MonthlyQuestCard` and `_MonthlyBadgesCard` widgets in two locations (`quests_screen.dart` and `right_info_panel.dart`) — both rendering a hardcoded "Complete 20 quests / 0 / 20" placeholder with no backend. There is no monthly quest table, RPC, provider, usecase, or admin surface. This design specifies end-to-end integration: database schema, server-side progress calculation, Flutter clean-architecture layers, admin panel tabbed management, badge reward coupling, and rollout sequence.

## Key Decisions (Brainstorm Outcomes)

1. **Single large monthly challenge** (not multiple simultaneous monthly quests). Data model stays flexible for multi-quest, but v1 seeds exactly one.
2. **Admin-selectable `quest_type`** — same CASE-dispatch pattern as daily quest; admin picks which activity type the monthly challenge tracks.
3. **Implicit progress calculation** — RPC scans activity tables (reading, vocab, daily_quest_completions, etc.) on each call. No explicit counter table.
4. **Calendar-month reset** — period boundaries align to Istanbul TZ month start (`YYYY-MM` period_key). All students share the same window.
5. **Optional badge reward via `monthly_quests.badge_id` nullable FK** — reuses existing badges table; admin can leave NULL for no badge, or link a fresh "April 2026 Champion" badge per month.
6. **Reward types: xp / coins / card_pack** — same enum as daily quest (no new types).
7. **Admin UI: tabbed view** — daily and monthly share one `/quests` screen with two tabs.

## Data Model

### Tables

**`monthly_quests`** (admin-managed quest definitions):

| Column | Type | Constraint | Notes |
|--------|------|------------|-------|
| `id` | UUID | PK, gen_random_uuid() | |
| `quest_type` | VARCHAR(50) | UNIQUE, NOT NULL | Drives RPC CASE dispatch |
| `title` | VARCHAR(200) | NOT NULL | Displayed to student |
| `icon` | VARCHAR(10) | | Emoji icon |
| `goal_value` | INTEGER | NOT NULL, CHECK (> 0) | Target count |
| `reward_type` | VARCHAR(50) | CHECK IN ('xp','coins','card_pack') | |
| `reward_amount` | INTEGER | NOT NULL DEFAULT 0 | |
| `badge_id` | UUID | NULL, FK → badges(id) ON DELETE SET NULL | Optional extra reward |
| `is_active` | BOOLEAN | DEFAULT true | Admin toggle |
| `sort_order` | INTEGER | DEFAULT 0 | Display ordering |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | |

**`monthly_quest_completions`** (per-user, per-period completion records):

| Column | Type | Constraint | Notes |
|--------|------|------------|-------|
| `id` | UUID | PK | |
| `user_id` | UUID | FK → profiles(id) ON DELETE CASCADE | |
| `quest_id` | UUID | FK → monthly_quests(id) ON DELETE CASCADE | |
| `period_key` | VARCHAR(7) | NOT NULL | "YYYY-MM" format (e.g. "2026-04") |
| `completed_at` | TIMESTAMPTZ | DEFAULT NOW() | |

`UNIQUE(user_id, quest_id, period_key)` — idempotency + double-reward guard.
Index: `idx_mqc_user_period` on `(user_id, period_key)`.

> No `monthly_quest_bonus_claims` equivalent — there is no "all-complete bonus pack" concept in monthly (decision 1a: single quest per month means no aggregate bonus). YAGNI.

### RLS Policies

| Table | SELECT | INSERT/UPDATE/DELETE |
|-------|--------|---------------------|
| `monthly_quests` | All authenticated (`USING (true)`) | Admin role only (`FOR ALL` with admin check) |
| `monthly_quest_completions` | Own rows (`user_id = auth.uid()`) | Blocked — only SECURITY DEFINER RPCs |

### Shared Constants

```dart
// packages/owlio_shared/lib/src/constants/tables.dart
static const String monthlyQuests = 'monthly_quests';
static const String monthlyQuestCompletions = 'monthly_quest_completions';

// packages/owlio_shared/lib/src/constants/rpc_functions.dart
static const String getMonthlyQuestProgress = 'get_monthly_quest_progress';
```

## RPC: `get_monthly_quest_progress(p_user_id UUID)`

**Mode:** `LANGUAGE plpgsql SECURITY DEFINER`

**Returns:** TABLE with columns:
```
quest_id UUID, quest_type VARCHAR, title VARCHAR, icon VARCHAR,
goal_value INT, current_value INT, is_completed BOOLEAN,
reward_type VARCHAR, reward_amount INT, reward_awarded BOOLEAN,
newly_completed BOOLEAN, period_key VARCHAR, days_left INT,
badge_id UUID, badge_awarded BOOLEAN
```

**Algorithm:**

```
1. Auth: IF auth.uid() != p_user_id THEN RAISE 'unauthorized'.
2. Compute period:
     v_period_key  = to_char(NOW() AT TIME ZONE 'Europe/Istanbul', 'YYYY-MM')
     v_month_start = date_trunc('month', NOW() AT TIME ZONE 'Europe/Istanbul')
                       AT TIME ZONE 'Europe/Istanbul'
     v_month_end   = v_month_start + INTERVAL '1 month'
     v_days_left   = (v_month_end::date - 1) - (NOW() AT TIME ZONE 'Europe/Istanbul')::date
3. FOR v_quest IN SELECT ... FROM monthly_quests WHERE is_active ORDER BY sort_order:
     CASE v_quest.quest_type:
       'complete_daily_quests' →
         SELECT COUNT(*) FROM daily_quest_completions
         WHERE user_id = p_user_id
           AND completion_date >= v_month_start::date
           AND completion_date <  v_month_end::date
       'read_chapters' →
         SELECT COUNT(DISTINCT chapter_id) FROM daily_chapter_reads
         WHERE user_id = p_user_id AND read_date BETWEEN boundaries
       'read_words' →
         SELECT COALESCE(SUM(ch.word_count),0)
         FROM daily_chapter_reads dcr JOIN chapters ch ON ch.id = dcr.chapter_id
         WHERE dcr.user_id = p_user_id AND dcr.read_date BETWEEN boundaries
       'vocab_sessions' →
         SELECT COUNT(*) FROM vocabulary_sessions
         WHERE user_id = p_user_id AND completed_at BETWEEN v_month_start AND v_month_end
       'correct_answers' →
         SELECT COUNT(*) FROM inline_activity_results
         WHERE user_id = p_user_id AND is_correct = true
           AND answered_at BETWEEN v_month_start AND v_month_end
       'daily_reviews' →
         SELECT COUNT(DISTINCT session_date) FROM daily_review_sessions
         WHERE user_id = p_user_id AND session_date BETWEEN boundaries
       ELSE v_current := 0
     END CASE

     v_completed       := (v_current >= v_quest.goal_value)
     v_already_awarded := EXISTS(SELECT 1 FROM monthly_quest_completions
                                 WHERE user_id = p_user_id
                                   AND quest_id = v_quest.id
                                   AND period_key = v_period_key)
     v_newly           := false
     v_badge_awarded   := false

     IF v_completed AND NOT v_already_awarded THEN
       INSERT INTO monthly_quest_completions (user_id, quest_id, period_key)
       VALUES (p_user_id, v_quest.id, v_period_key)
       ON CONFLICT DO NOTHING;

       -- Primary reward
       CASE v_quest.reward_type
         WHEN 'xp'        THEN PERFORM award_xp_transaction(
                                 p_user_id, v_quest.reward_amount,
                                 'monthly_quest', v_quest.id, v_quest.title);
         WHEN 'coins'     THEN PERFORM award_coins_transaction(
                                 p_user_id, v_quest.reward_amount,
                                 'monthly_quest', v_quest.id, v_quest.title);
         WHEN 'card_pack' THEN UPDATE profiles
                                 SET unopened_packs = unopened_packs + v_quest.reward_amount
                                 WHERE id = p_user_id;
       END CASE;

       -- Optional badge reward
       IF v_quest.badge_id IS NOT NULL THEN
         INSERT INTO user_badges (user_id, badge_id)
         VALUES (p_user_id, v_quest.badge_id)
         ON CONFLICT DO NOTHING;
         GET DIAGNOSTICS v_badge_rows = ROW_COUNT;
         IF v_badge_rows > 0 THEN
           v_badge_awarded := true;
           -- Badge's own xp_reward (if any)
           SELECT xp_reward, name INTO v_badge_xp, v_badge_name
             FROM badges WHERE id = v_quest.badge_id;
           IF v_badge_xp > 0 THEN
             PERFORM award_xp_transaction(
               p_user_id, v_badge_xp, 'badge', v_quest.badge_id, v_badge_name);
           END IF;
         END IF;
       END IF;

       v_newly           := true;
       v_already_awarded := true;
     END IF;

     -- Return row
     RETURN NEXT row_values;
   END LOOP;
```

### Source String Conventions (audit trail)

| Reward | `source` | `ref_type` / `ref_id` |
|--------|----------|-----------------------|
| Monthly quest XP / coins | `'monthly_quest'` | `quest_id` |
| Badge's own XP (when badge auto-awarded) | `'badge'` | `badge_id` |
| Monthly quest card_pack | — (not audit-logged; mirrors daily bonus pack) | — |

### Seed Data (first migration)

```sql
INSERT INTO monthly_quests (quest_type, title, icon, goal_value, reward_type, reward_amount, sort_order)
VALUES ('complete_daily_quests', 'Complete 20 daily quests this month', '🏆', 20, 'card_pack', 1, 1);
```

Matches the existing UI placeholder ("Complete 20 quests") verbatim. `badge_id` NULL on seed; admin adds a badge via admin panel after deploy.

## Reward Chain & Cross-System Integration

### Provider Invalidation Map

`monthlyQuestProgressProvider` is invalidated at the same points as `dailyQuestProgressProvider`, plus one new point:

| Trigger | File (approx line) | Daily | Monthly |
|---------|--------------------|-------|---------|
| Chapter completion | `book_provider.dart:~210` | yes | **add** |
| Inline activity done | `reader_provider.dart:~419` | yes | **add** |
| Vocabulary session save | `vocabulary_provider.dart:~995` | yes | **add** |
| Daily review completion | `daily_review_screen.dart:~130` | yes | **add** |
| Daily quest newly completed | `daily_quest_provider.dart` — inside the existing `Future.microtask` block that fires `questCompletionEventProvider` when `newlyCompleted` is detected | — | **add (new)** |
| Daily bonus claim | `daily_quest_list.dart:~61` | yes | skip (daily bonus doesn't affect monthly) |

**Why the new tie-in:** `quest_type = 'complete_daily_quests'` counts rows from `daily_quest_completions`. Without invalidating monthly when a daily quest gets completed, the monthly counter would only update on next app open.

### Atomicity

All reward side-effects (completion INSERT, XP/coin transaction, pack increment, badge INSERT, badge XP) happen inside a single PL/pgSQL RPC invocation and thus a single DB transaction. Any error rolls back the entire chain, so the next RPC call retries cleanly.

## Flutter Architecture

### Layer Map

**Domain:**
```
lib/domain/entities/monthly_quest.dart
  ├─ class MonthlyQuest(id, questType, title, icon, goalValue,
  │                     rewardType, rewardAmount, badgeId?)
  └─ class MonthlyQuestProgress(quest, currentValue, isCompleted,
                                rewardAwarded, newlyCompleted,
                                periodKey, daysLeft, badgeAwarded)
  // Reuses QuestRewardType enum from daily_quest.dart (import ... show QuestRewardType)

lib/domain/repositories/monthly_quest_repository.dart
  └─ abstract getProgress({required String userId})
       → Future<Either<Failure, List<MonthlyQuestProgress>>>

lib/domain/usecases/monthly_quest/get_monthly_quest_progress_usecase.dart
  └─ UseCase<List<MonthlyQuestProgress>, GetMonthlyQuestProgressParams>
```

**Data:**
```
lib/data/models/monthly_quest/monthly_quest_progress_model.dart
  └─ fromJson + toEntity (read-only, no toJson — mirrors daily)

lib/data/repositories/supabase/supabase_monthly_quest_repository.dart
  └─ SupabaseMonthlyQuestRepository implements MonthlyQuestRepository
     - supabase.rpc(RpcFunctions.getMonthlyQuestProgress, params: {'p_user_id': userId})
     - try/catch → Either<ServerFailure, ...>
```

**Presentation:**
```
lib/presentation/providers/repository_providers.dart
  └─ ADD: monthlyQuestRepositoryProvider

lib/presentation/providers/usecase_providers.dart
  └─ ADD: getMonthlyQuestProgressUseCaseProvider

lib/presentation/providers/monthly_quest_provider.dart  [NEW]
  └─ final monthlyQuestProgressProvider = FutureProvider<List<MonthlyQuestProgress>>
     (no StateNotifier controller needed — monthly has no user-initiated mutation)
```

### Widget Wiring

**Modify existing widgets** (no new widgets):

- `lib/presentation/screens/quests/quests_screen.dart`:
  - `_MonthlyQuestCard`: `StatelessWidget` → `ConsumerWidget`; watch `monthlyQuestProgressProvider`; render real data (goal, current, days_left, title). Empty state when no active quest.
  - `_MonthlyBadgesCard`: `StatelessWidget` → `ConsumerWidget`; read the same provider (no extra fetch); if first-quest's `badgeId` present, show badge name/icon + earned state; else show existing "Earn your first badge!" placeholder.
- `lib/presentation/widgets/shell/right_info_panel.dart`:
  - `_MonthlyQuestSidebarCard`: same wiring, compact sidebar variant.
  - `_MonthlyBadgesSidebarCard`: same wiring, compact sidebar variant.

**No shared helper extraction in v1.** Inline per-widget progress math; refactor only if duplication spreads beyond these 2+2 widgets.

### RPC Response JSON Schema

```json
{
  "quest_id": "uuid",
  "quest_type": "complete_daily_quests",
  "title": "Complete 20 daily quests this month",
  "icon": "🏆",
  "goal_value": 20,
  "current_value": 7,
  "is_completed": false,
  "reward_type": "card_pack",
  "reward_amount": 1,
  "reward_awarded": false,
  "newly_completed": false,
  "period_key": "2026-04",
  "days_left": 14,
  "badge_id": null,
  "badge_awarded": false
}
```

## Admin Panel Changes

### Tabbed Refactor

`owlio_admin/lib/features/quests/screens/quest_list_screen.dart`:
- Becomes tabbed: `TabController` with two tabs — "Daily Quests" / "Monthly Quests".
- Extract existing daily-quest body → `_DailyQuestsTab`.
- New `_MonthlyQuestsTab` — 95% identical to daily tab, with differences:

| Field | Daily | Monthly |
|-------|-------|---------|
| Provider | `questsProvider` | `monthlyQuestsProvider` (new) |
| Table | `DbTables.dailyQuests` | `DbTables.monthlyQuests` |
| Stats RPC | `getQuestCompletionStats` | **not shown in v1** |
| Editable fields | title, icon, goal, reward_type, reward_amount, sort_order, is_active | same + **`badge_id` dropdown** |
| Info banner | "Changes take effect immediately" | adds "Monthly quests reset on the 1st of each month (Istanbul TZ)" |

### Badge Dropdown Component

New `_MonthlyQuestsTab` provider:
```dart
final activeBadgesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  return List<Map<String, dynamic>>.from(
    await supabase
      .from(DbTables.badges)
      .select('id, name, icon')
      .eq('is_active', true)
      .order('name'),
  );
});
```

Dropdown UI in monthly quest card:
```dart
DropdownButton<String?>(
  value: quest['badge_id'] as String?,
  items: [
    const DropdownMenuItem(value: null, child: Text('— No badge —')),
    for (final b in badges)
      DropdownMenuItem(
        value: b['id'] as String,
        child: Row([Text(b['icon']), Text(b['name'])]),
      ),
  ],
  onChanged: (v) => onUpdate({'badge_id': v}),
)
```

### Card Extraction

Extract `_QuestCard` to `owlio_admin/lib/features/quests/widgets/quest_card.dart` as reusable `QuestCard` widget with parameters:
- `tableName` (String) — which table to UPDATE
- `showBadgePicker` (bool) — true for monthly, false for daily
- `showStats` (bool) — true for daily, false for monthly

Same update-field / save-state logic is shared.

### What's NOT Changed

- Routing: `/quests` URL unchanged; tabs are internal.
- Dashboard "active quest count" tile: kept daily-only in v1. Monthly tile deferred.
- No create / delete flow for monthly quests in v1 (same constraint as daily — `quest_type` is RPC-dispatched; new types require migration).

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| No active monthly quest | RPC returns empty list; widget shows empty state |
| Quest activated mid-month | Retroactive count — month-to-date activities count immediately |
| Admin lowers `goal_value` mid-month | Students already past the new threshold auto-award on next provider fetch |
| Admin raises `goal_value` mid-month | Already-completed students keep their reward (UNIQUE constraint protects); others progress toward new target |
| Admin changes `badge_id` mid-month | Students who already completed got the old badge; future completers get the new one. No retroactive badge swap |
| Debug date offset active | RPC uses plain `NOW() AT TIME ZONE 'Europe/Istanbul'`; debug offset via `app_now()` is ignored (matches CLAUDE.md TIMESTAMPTZ guidance) |
| Month rollover (Istanbul TZ) | `period_key` flips from "YYYY-MM" to next; uncompleted progress from previous month is abandoned (new calendar window) |
| RPC network failure | Provider returns `[]`; widget renders `SizedBox.shrink()` (same silent-fail pattern as daily quest Finding #6) |
| `badge_id` points to deleted badge | `ON DELETE SET NULL` kicks in → quest continues without badge reward |
| Concurrent RPC calls | UNIQUE on `monthly_quest_completions` + `ON CONFLICT DO NOTHING` → single reward even on races |
| `badge_id` NULL | Primary reward only; no badge INSERT attempted |
| User already has the linked badge | `ON CONFLICT DO NOTHING` → `badge_awarded=false`; no double badge-XP |

## Test Scenarios

- [ ] Happy path: seed quest active, student completes 20 daily quests within the month → card_pack auto-awarded, `newly_completed=true` on that RPC call
- [ ] Retroactive: student has 10 daily-quest completions, admin activates monthly mid-month with goal 5 → quest immediately shows completed, reward fires
- [ ] Month rollover: complete quest on April 30 (Istanbul) → `period_key="2026-04"`. On May 1 Istanbul, `period_key="2026-05"`, quest re-fetchable, counter starts at 0
- [ ] Double-reward prevention: call RPC 10 times after completion → only first run returns `newly_completed=true`, rest `false`
- [ ] Admin lowers goal mid-month: student at 7/20, admin sets goal to 5 → next RPC fetch marks complete, awards reward
- [ ] Badge optional: seed quest has `badge_id=NULL` → card_pack awarded, `badge_awarded=false`, no `user_badges` insert
- [ ] Badge xp_reward chain: seed quest (reward_type=card_pack) + linked badge with `xp_reward=50` → on completion, pack + badge + 50 XP fire. `xp_logs` contains exactly one row with `source='badge'`. No `source='monthly_quest'` row (because the quest's own reward is card_pack, not xp). If the quest were reward_type=xp, two distinct xp_logs rows would appear: one `monthly_quest`, one `badge`
- [ ] Invalidation cascade: student completes a daily quest → daily controller invalidates monthly provider → monthly counter increments
- [ ] Empty state: admin deactivates all monthly quests → UI shows empty state (both main screen and sidebar)
- [ ] Concurrent RPC: 2 parallel `get_monthly_quest_progress` calls after crossing threshold → exactly one `monthly_quest_completions` row, one reward
- [ ] Admin tab switch: Daily tab ↔ Monthly tab → each refreshes independently, no cross-contamination
- [ ] Admin badge picker: assign badge to quest → next student completion awards the new badge; change picker to NULL → next completion gets no badge; change to different badge → subsequent completers get the new badge
- [ ] Deleted badge: admin hard-deletes a badge referenced by a monthly quest → `badge_id` becomes NULL, quest continues functioning

## Rollout Sequence

**Phase 1 — Database (backwards-compatible, UI untouched):**
1. Write migration `supabase/migrations/20260416XXXXXX_monthly_quest_engine.sql`:
   - `monthly_quests` table + RLS + CHECK constraints
   - `monthly_quest_completions` table + RLS + UNIQUE + index
   - `get_monthly_quest_progress` RPC
   - Seed row for `complete_daily_quests` quest
2. `supabase db push --dry-run` → review → `supabase db push`
3. Manual smoke: call RPC with test user via SQL editor, verify return shape

**Phase 2 — Shared package:**
1. Add `monthlyQuests`, `monthlyQuestCompletions` to `tables.dart`
2. Add `getMonthlyQuestProgress` to `rpc_functions.dart`
3. `flutter pub get` in both mobile and admin projects

**Phase 3 — Mobile app:**
1. Domain layer (entity, repository interface, usecase)
2. Data layer (model, Supabase repository impl)
3. Presentation layer (provider, usecase provider registration, repository provider registration)
4. Widget wiring: convert `_MonthlyQuestCard` and `_MonthlyBadgesCard` (both screen + sidebar variants) from `StatelessWidget` to `ConsumerWidget`
5. Add `monthlyQuestProgressProvider.invalidate()` at the 5 existing daily-invalidation sites + 1 new (daily quest controller/provider)
6. `dart analyze lib/` → zero issues
7. Manual smoke on test user `fresh@demo.com`

**Phase 4 — Admin panel:**
1. Refactor `quest_list_screen.dart` into tabbed view
2. Extract shared `QuestCard` widget
3. Add `_MonthlyQuestsTab` + `monthlyQuestsProvider` + `activeBadgesProvider`
4. Manual smoke: edit quest, toggle active, assign badge

**Phase 5 — Verification:**
1. E2E happy path: `fresh@demo.com` completes 20 daily quests across the month → receives card pack + (if badge assigned via admin) badge
2. Admin `/quests` Monthly tab: edit fields, pick badge, verify changes reflect in mobile app after invalidation
3. `dart analyze` clean across root project, `owlio_admin/`, and `packages/owlio_shared/`

## Known Limitations / Accepted Tech Debt

| # | Limitation | Rationale |
|---|------------|-----------|
| 1 | Monthly quest XP doesn't trigger `check_and_award_badges` | Mirrors daily quest Finding #13; out of scope |
| 2 | `card_pack` reward has no `coin_logs` / `pack_purchases` audit entry | Mirrors daily bonus pack Finding #12 |
| 3 | No admin stats panel for monthly (completion %, avg progress) | v2 scope; needs different metrics than daily |
| 4 | No admin CREATE/DELETE for monthly quests | `quest_type` is RPC-dispatched — new types require migration + RPC update |
| 5 | Error state UI is silent `SizedBox.shrink()` | Mirrors daily quest Finding #6 |

## Key Files

### New Files
- `supabase/migrations/20260416XXXXXX_monthly_quest_engine.sql`
- `lib/domain/entities/monthly_quest.dart`
- `lib/domain/repositories/monthly_quest_repository.dart`
- `lib/domain/usecases/monthly_quest/get_monthly_quest_progress_usecase.dart`
- `lib/data/models/monthly_quest/monthly_quest_progress_model.dart`
- `lib/data/repositories/supabase/supabase_monthly_quest_repository.dart`
- `lib/presentation/providers/monthly_quest_provider.dart`
- `owlio_admin/lib/features/quests/widgets/quest_card.dart` (extracted)

### Modified Files
- `packages/owlio_shared/lib/src/constants/tables.dart`
- `packages/owlio_shared/lib/src/constants/rpc_functions.dart`
- `lib/presentation/providers/repository_providers.dart`
- `lib/presentation/providers/usecase_providers.dart`
- `lib/presentation/screens/quests/quests_screen.dart` (convert 2 widgets to `ConsumerWidget`)
- `lib/presentation/widgets/shell/right_info_panel.dart` (convert 2 widgets to `ConsumerWidget`)
- `lib/presentation/providers/book_provider.dart` (monthly invalidation)
- `lib/presentation/providers/reader_provider.dart` (monthly invalidation)
- `lib/presentation/providers/vocabulary_provider.dart` (monthly invalidation)
- `lib/presentation/screens/review/daily_review_screen.dart` (monthly invalidation)
- `lib/presentation/providers/daily_quest_provider.dart` (monthly invalidation on daily newly_completed)
- `owlio_admin/lib/features/quests/screens/quest_list_screen.dart` (tabbed refactor)
