# Admin Quest Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an admin dashboard screen to manage daily quest parameters (goals, rewards, active status) with inline completion stats.

**Architecture:** Single new screen in admin panel (`/quests`) with card-per-quest layout. Stats provided by a new Supabase RPC. No main app changes.

**Tech Stack:** Flutter (admin panel), Supabase RPC (PostgreSQL), owlio_shared constants.

**Spec:** `docs/superpowers/specs/2026-03-23-admin-quest-dashboard-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `supabase/migrations/20260323000004_quest_admin_stats_rpc.sql` | Stats RPC |
| Modify | `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | Add `getQuestCompletionStats` constant |
| Create | `owlio_admin/lib/features/quests/screens/quest_list_screen.dart` | Providers + quest list UI + inline edit + stats |
| Modify | `owlio_admin/lib/core/router.dart` | Add `/quests` route |
| Modify | `owlio_admin/lib/features/dashboard/screens/dashboard_screen.dart` | Add "Daily Quests" card + stat |

---

## Task 1: Stats RPC Migration

**Files:**
- Create: `supabase/migrations/20260323000004_quest_admin_stats_rpc.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Quest completion stats for admin dashboard
CREATE OR REPLACE FUNCTION get_quest_completion_stats()
RETURNS TABLE(
    quest_id UUID,
    today_completed INT,
    today_total_users INT,
    avg_daily_7d NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_students INT;
BEGIN
    -- Admin-only check
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin') THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    -- Count total students once
    SELECT COUNT(*)::INT INTO v_total_students
    FROM profiles WHERE role = 'student';

    RETURN QUERY
    SELECT
        dq.id AS quest_id,
        COALESCE(tc.cnt, 0)::INT AS today_completed,
        v_total_students AS today_total_users,
        COALESCE(avg7.avg_completions, 0) AS avg_daily_7d
    FROM daily_quests dq
    LEFT JOIN (
        -- Today's completions per quest
        SELECT dqc.quest_id AS qid, COUNT(*)::INT AS cnt
        FROM daily_quest_completions dqc
        WHERE dqc.completion_date = CURRENT_DATE
        GROUP BY dqc.quest_id
    ) tc ON tc.qid = dq.id
    LEFT JOIN (
        -- 7-day average completions per quest
        SELECT
            sub.qid,
            (SUM(sub.daily_cnt)::NUMERIC / 7) AS avg_completions
        FROM (
            SELECT dqc.quest_id AS qid, dqc.completion_date, COUNT(*) AS daily_cnt
            FROM daily_quest_completions dqc
            WHERE dqc.completion_date >= CURRENT_DATE - 6
            GROUP BY dqc.quest_id, dqc.completion_date
        ) sub
        GROUP BY sub.qid
    ) avg7 ON avg7.qid = dq.id
    ORDER BY dq.sort_order;
END;
$$;
```

- [ ] **Step 2: Dry-run the migration**

Run: `supabase db push --dry-run`
Expected: Shows the new migration as pending, no errors.

- [ ] **Step 3: Push the migration**

Run: `supabase db push`
Expected: Migration applied successfully.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260323000004_quest_admin_stats_rpc.sql
git commit -m "feat(db): add get_quest_completion_stats RPC for admin dashboard"
```

---

## Task 2: Shared Package — Add RPC Constant

**Files:**
- Modify: `packages/owlio_shared/lib/src/constants/rpc_functions.dart`

Note: `DbTables.dailyQuests` already exists at line 55 of `tables.dart` — no change needed there.

- [ ] **Step 1: Add the constant**

In `rpc_functions.dart`, add after the `claimDailyBonus` line (line 29):

```dart
  static const getQuestCompletionStats = 'get_quest_completion_stats';
```

- [ ] **Step 2: Verify**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze packages/owlio_shared/`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add packages/owlio_shared/lib/src/constants/rpc_functions.dart
git commit -m "feat(shared): add getQuestCompletionStats RPC constant"
```

---

## Task 3: Quest List Screen

**Files:**
- Create: `owlio_admin/lib/features/quests/screens/quest_list_screen.dart`

**Reference patterns:**
- Provider pattern: `owlio_admin/lib/features/badges/screens/badge_list_screen.dart` (lines 9-17, `badgesProvider`)
- Update + invalidate pattern: `owlio_admin/lib/features/settings/screens/settings_screen.dart` (lines 79-118, `_updateSetting`)
- Card layout: `owlio_admin/lib/features/dashboard/screens/dashboard_screen.dart` (lines 216-293, `_DashboardCard`)

- [ ] **Step 1: Create the directory**

Run: `mkdir -p /Users/wonderelt/Desktop/Owlio/owlio_admin/lib/features/quests/screens`

- [ ] **Step 2: Write the quest list screen**

Create `quest_list_screen.dart` with these components:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/supabase_client.dart';

// ============================================
// PROVIDERS
// ============================================

/// Fetches all quest definitions ordered by sort_order
final questsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.dailyQuests)
      .select()
      .order('sort_order');
  return List<Map<String, dynamic>>.from(response);
});

/// Fetches quest completion stats (admin-only RPC)
final questStatsProvider =
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

// ============================================
// SCREEN
// ============================================

class QuestListScreen extends ConsumerStatefulWidget {
  const QuestListScreen({super.key});

  @override
  ConsumerState<QuestListScreen> createState() => _QuestListScreenState();
}

class _QuestListScreenState extends ConsumerState<QuestListScreen> {
  final Set<String> _savingFields = {};

  Future<void> _updateQuest(
      String questId, Map<String, dynamic> fields) async {
    final fieldKey = '$questId-${fields.keys.first}';
    if (_savingFields.contains(fieldKey)) return;

    setState(() => _savingFields.add(fieldKey));

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from(DbTables.dailyQuests)
          .update(fields)
          .eq('id', questId);

      if (mounted) {
        ref.invalidate(questsProvider);
        ref.invalidate(questStatsProvider);
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
      if (mounted) {
        setState(() => _savingFields.remove(fieldKey));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final questsAsync = ref.watch(questsProvider);
    final statsAsync = ref.watch(questStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Quests'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              ref.invalidate(questsProvider);
              ref.invalidate(questStatsProvider);
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: questsAsync.when(
        data: (quests) {
          final stats = statsAsync.valueOrNull ?? {};
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Changes take effect immediately for all users.',
                          style: TextStyle(color: Colors.orange.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Quest cards
                ...quests.map((quest) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _QuestCard(
                        quest: quest,
                        stats: stats[quest['id'] as String],
                        onUpdate: (fields) =>
                            _updateQuest(quest['id'] as String, fields),
                        savingFields: _savingFields,
                        questId: quest['id'] as String,
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
                  ref.invalidate(questsProvider);
                  ref.invalidate(questStatsProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// QUEST CARD
// ============================================

class _QuestCard extends StatefulWidget {
  const _QuestCard({
    required this.quest,
    required this.stats,
    required this.onUpdate,
    required this.savingFields,
    required this.questId,
  });

  final Map<String, dynamic> quest;
  final Map<String, dynamic>? stats;
  final void Function(Map<String, dynamic> fields) onUpdate;
  final Set<String> savingFields;
  final String questId;

  @override
  State<_QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends State<_QuestCard> {
  late TextEditingController _titleController;
  late TextEditingController _iconController;
  late TextEditingController _goalController;
  late TextEditingController _rewardAmountController;
  late TextEditingController _sortOrderController;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.quest['title'] as String? ?? '');
    _iconController =
        TextEditingController(text: widget.quest['icon'] as String? ?? '');
    _goalController = TextEditingController(
        text: (widget.quest['goal_value'] as int?)?.toString() ?? '1');
    _rewardAmountController = TextEditingController(
        text: (widget.quest['reward_amount'] as int?)?.toString() ?? '0');
    _sortOrderController = TextEditingController(
        text: (widget.quest['sort_order'] as int?)?.toString() ?? '0');
  }

  @override
  void didUpdateWidget(covariant _QuestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controllers if data changed externally (after provider refresh)
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
      _rewardAmountController.text =
          (q['reward_amount'] as int?)?.toString() ?? '0';
    }
    if (!widget.savingFields.contains('${widget.questId}-sort_order')) {
      _sortOrderController.text =
          (q['sort_order'] as int?)?.toString() ?? '0';
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
            // Header: icon + title + active toggle
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
                    onSubmitted: (v) =>
                        widget.onUpdate({'icon': v}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
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
                  onChanged: (v) =>
                      widget.onUpdate({'is_active': v}),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Quest type chip (read-only)
            Chip(
              label: Text(questType),
              backgroundColor: Colors.grey.shade100,
              labelStyle: TextStyle(
                  fontSize: 12, color: Colors.grey.shade700),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(height: 16),

            // Editable fields row
            Row(
              children: [
                // Goal value
                _buildNumberField(
                  label: 'Goal',
                  controller: _goalController,
                  fieldName: 'goal_value',
                  minValue: 1,
                ),
                const SizedBox(width: 24),

                // Reward type dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reward',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    DropdownButton<String>(
                      value: rewardType,
                      isDense: true,
                      items: const [
                        DropdownMenuItem(value: 'xp', child: Text('XP')),
                        DropdownMenuItem(
                            value: 'coins', child: Text('Coins')),
                        DropdownMenuItem(
                            value: 'card_pack', child: Text('Card Pack')),
                      ],
                      onChanged: (v) {
                        if (v != null && v != rewardType) {
                          widget.onUpdate({'reward_type': v});
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(width: 16),

                // Reward amount
                _buildNumberField(
                  label: 'Amount',
                  controller: _rewardAmountController,
                  fieldName: 'reward_amount',
                  minValue: 1,
                ),
                const SizedBox(width: 24),

                // Sort order
                _buildNumberField(
                  label: 'Order',
                  controller: _sortOrderController,
                  fieldName: 'sort_order',
                  minValue: 0,
                ),
              ],
            ),

            // Stats section
            if (stats != null) ...[
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
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        SizedBox(
          width: 80,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onSubmitted: (v) {
              final parsed = int.tryParse(v);
              if (parsed != null && parsed >= minValue) {
                widget.onUpdate({fieldName: parsed});
              } else {
                // Reset to current value
                controller.text =
                    (widget.quest[fieldName] as int?)?.toString() ?? '$minValue';
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> stats) {
    final todayCompleted = stats['today_completed'] as int? ?? 0;
    final totalUsers = stats['today_total_users'] as int? ?? 0;
    final pct =
        totalUsers > 0 ? (todayCompleted / totalUsers * 100).round() : 0;
    final avg7d = stats['avg_daily_7d'];
    final avgFormatted = avg7d is num ? avg7d.toStringAsFixed(1) : '0.0';

    return Row(
      children: [
        Icon(Icons.bar_chart, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text(
          'Today: $todayCompleted/$totalUsers students ($pct%)',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 24),
        Text(
          'Last 7 days: $avgFormatted/day avg',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Verify**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze owlio_admin/lib/features/quests/`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add owlio_admin/lib/features/quests/
git commit -m "feat(admin): add quest list screen with inline editing and stats"
```

---

## Task 4: Router — Add /quests Route

**Files:**
- Modify: `owlio_admin/lib/core/router.dart`

- [ ] **Step 1: Add import**

At the top of `router.dart`, after the existing imports (around line 31), add:

```dart
import '../features/quests/screens/quest_list_screen.dart';
```

- [ ] **Step 2: Add route**

After the `/recent-activity/:sectionKey` route (around line 79), add:

```dart
      GoRoute(
        path: '/quests',
        builder: (context, state) => const QuestListScreen(),
      ),
```

- [ ] **Step 3: Verify**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze owlio_admin/lib/core/router.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add owlio_admin/lib/core/router.dart
git commit -m "feat(admin): add /quests route"
```

---

## Task 5: Dashboard — Add Daily Quests Card

**Files:**
- Modify: `owlio_admin/lib/features/dashboard/screens/dashboard_screen.dart`

- [ ] **Step 1: Add quest count to dashboardStatsProvider**

In `dashboardStatsProvider`, add to the `Future.wait` list (after the `scopeLearningPaths` count, around line 26):

```dart
    supabase.from(DbTables.dailyQuests).select().eq('is_active', true).count(CountOption.exact),
```

And add to the return map (after `'assignments'`, around line 37):

```dart
    'quests': results[8].count,
```

- [ ] **Step 2: Add dashboard card**

In the `GridView.count` children list, after the "Son Etkinlikler" card and before the "Ayarlar" card (around line 194), add:

```dart
                  _DashboardCard(
                    icon: Icons.bolt,
                    title: 'Daily Quests',
                    description: 'Quest goals, rewards, and completion stats',
                    color: const Color(0xFFF97316),
                    stat: stats['quests'],
                    onTap: () => context.go('/quests'),
                  ),
```

- [ ] **Step 3: Verify**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze owlio_admin/lib/features/dashboard/`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add owlio_admin/lib/features/dashboard/screens/dashboard_screen.dart
git commit -m "feat(admin): add Daily Quests card to dashboard"
```

---

## Task 6: Final Verification

- [ ] **Step 1: Full analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze owlio_admin/`
Expected: No issues (or only pre-existing issues).

- [ ] **Step 2: Manual test**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && flutter run -d chrome`

Verify:
1. Dashboard shows "Daily Quests" card with active quest count
2. Clicking card navigates to `/quests`
3. 3 quest cards render with correct data
4. Edit goal_value → saves, SnackBar shows, value persists on refresh
5. Toggle is_active → saves immediately
6. Change reward_type dropdown → saves
7. Stats section shows today's completions and 7-day average
8. Refresh button reloads both quests and stats
