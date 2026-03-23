# Admin Quest Dashboard — Design Spec

**Date:** 2026-03-23
**Scope:** Phase 2 of Daily Quest Engine — admin dashboard for quest management (admin panel + DB).
**Depends on:** Phase 1 spec (`2026-03-22-daily-quest-engine-design.md`), fully implemented.
**Note:** Phase 1 spec documents original quest types (`read_words`, `correct_answers`). These were replaced by `read_chapters` and `vocab_session` in migration `20260323000002`. Current active types: `daily_review`, `read_chapters`, `vocab_session`.

---

## Problem

Quest goals, rewards, and active status are stored in `daily_quests` but there is no admin UI to manage them. Changing quest parameters requires direct DB access. Admins also have no visibility into quest completion rates.

---

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Edit vs CRUD | Edit only (no create/delete) | New quest types require RPC changes (SQL migration). Admin value is tuning goals/rewards, not defining new mechanics. |
| Versioning | None — immediate effect | RPC evaluates `current_value >= goal_value` on every call. Simple and sufficient. |
| Stats depth | Summary inline (no analytics page) | Inline stats per quest ("too easy/hard?") is enough. PostHog handles deeper analytics. |
| Screen structure | Single dedicated screen, card-per-quest | 3 quests don't need list→detail. All visible and editable at once. |

---

## Design

### Screen Layout

**Route:** `/quests`

**Dashboard card:** "Daily Quests" card on dashboard grid. Icon: `Icons.bolt`, color: `#F97316`. Stat: active quest count. Links to `/quests`.

**Screen structure:**

```
AppBar: "Daily Quests" + Refresh button
Body (scrollable):
  Info banner — "Changes take effect immediately for all users."

  Quest Card (repeated per quest, full-width):
  ┌──────────────────────────────────────────────────────┐
  │ 📖 [title_________]              [Active ✓ toggle]   │
  │ Type: daily_review (read-only chip)                  │
  │                                                      │
  │ Goal: [1___]   Reward: [xp ▼] [20__]   Order: [1__] │
  │                                                      │
  │ ── Stats ──────────────────────────────────────────  │
  │ Today: 12/45 students completed (27%)                │
  │ Last 7 days: 8.3 completions/day avg                 │
  └──────────────────────────────────────────────────────┘
```

**Editable fields per quest:**
- `title` — text field
- `icon` — text field (emoji)
- `is_active` — toggle switch
- `goal_value` — number field (min: 1, client-side validation)
- `reward_type` — dropdown (xp / coins / card_pack). Values must match DB CHECK constraint on `daily_quests.reward_type`.
- `reward_amount` — number field (min: 1)
- `sort_order` — number field

**Read-only:** `quest_type` — shown as a chip/badge. Not editable because it's structurally tied to RPC logic.

**Save behavior:** Each field saves on submit/change (onFieldSubmitted for text/number, onChanged for dropdown/toggle). SnackBar confirms. Same pattern as Settings screen.

### Data & Provider

**`questsProvider`** — `FutureProvider<List<Map<String, dynamic>>>`. Fetches `daily_quests` ordered by `sort_order`. Same pattern as `badgesProvider`.

**`_updateQuest(questId, fields)`** — calls `supabase.from(DbTables.dailyQuests).update(fields).eq('id', questId)`, invalidates both `questsProvider` and `questStatsProvider` on success. Same pattern as `_updateSetting`.

**No new RPC for CRUD.** Admin RLS policy already grants full access to `daily_quests`.

### Completion Stats

**New RPC:** `get_quest_completion_stats()`

```sql
RETURNS TABLE(
  quest_id UUID,
  today_completed INT,
  today_total_users INT,
  avg_daily_7d NUMERIC
)
```

- Admin-only: checks `EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')`
- `today_completed`: COUNT of `daily_quest_completions` WHERE `completion_date = CURRENT_DATE` per quest_id
- `today_total_users`: COUNT of `profiles` WHERE `role = 'student'` (platform-wide, not per-school)
- `avg_daily_7d`: For each quest, average daily completion count over last 7 days (fixed 7-day denominator). Subquery groups `daily_quest_completions` by `(quest_id, completion_date)` for `completion_date >= CURRENT_DATE - 6`, then AVG per quest_id. Note: recently activated quests may show low averages due to days with zero completions.

**`questStatsProvider`** — separate `FutureProvider<Map<String, Map<String, dynamic>>>`. Calls RPC, converts result list to a map keyed by `quest_id` (String). Inner map contains `today_completed` (int), `today_total_users` (int), `avg_daily_7d` (num). Merged with `questsProvider` data in the UI.

**Display per quest card:**
```
Today: 12/45 students completed (27%)
Last 7 days: 8.3 completions/day avg
```

---

## Files

### New Files

| File | Purpose |
|------|---------|
| `owlio_admin/lib/features/quests/screens/quest_list_screen.dart` | Quest list screen — providers, card UI, inline edit, stats |
| `supabase/migrations/20260323000004_quest_admin_stats_rpc.sql` | `get_quest_completion_stats` RPC |

### Modified Files

| File | Change |
|------|--------|
| `owlio_admin/lib/core/router.dart` | Add `/quests` route import + GoRoute |
| `owlio_admin/lib/features/dashboard/screens/dashboard_screen.dart` | Add "Daily Quests" card to grid + `dailyQuests` count in `dashboardStatsProvider` |
| `packages/owlio_shared/lib/src/constants/tables.dart` | Already has `dailyQuests` — no change needed |
| `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | Add `static const getQuestCompletionStats = 'get_quest_completion_stats';` |

### No Changes

- Main app (`lib/`) — no changes needed
- Existing quest tables/RPCs — no schema changes

---

## Out of Scope

- Creating new quest types (requires migration)
- Deleting quests (deactivate via `is_active` toggle instead)
- Per-user quest completion drill-down
- Quest completion charts or trend visualizations
- Bonus claim configuration (fixed at 1 card pack for all-complete)
