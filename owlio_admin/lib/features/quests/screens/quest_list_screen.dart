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
