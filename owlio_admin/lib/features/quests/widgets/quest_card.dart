import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Generic quest card used by both Daily and Monthly tabs.
///
/// [showTierBadges] true for monthly, [showStats] true for daily.
/// [tierBadges] is the pre-filtered list of badges whose
/// `condition_type='monthly_quest_completed'` AND
/// `condition_param=quest.id`, sorted by `condition_value` ascending.
class QuestCard extends StatefulWidget {
  const QuestCard({
    required this.quest,
    required this.stats,
    required this.onUpdate,
    required this.savingFields,
    required this.questId,
    required this.showTierBadges,
    required this.showStats,
    this.tierBadges = const [],
    super.key,
  });

  final Map<String, dynamic> quest;
  final Map<String, dynamic>? stats;
  final void Function(Map<String, dynamic> fields) onUpdate;
  final Set<String> savingFields;
  final String questId;
  final bool showTierBadges;
  final bool showStats;
  final List<Map<String, dynamic>> tierBadges;

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
    _titleController = TextEditingController(
      text: widget.quest['title'] as String? ?? '',
    );
    _iconController = TextEditingController(
      text: widget.quest['icon'] as String? ?? '',
    );
    _goalController = TextEditingController(
      text: (widget.quest['goal_value'] as int?)?.toString() ?? '1',
    );
    _rewardAmountController = TextEditingController(
      text: (widget.quest['reward_amount'] as int?)?.toString() ?? '0',
    );
    _sortOrderController = TextEditingController(
      text: (widget.quest['sort_order'] as int?)?.toString() ?? '0',
    );
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
              labelStyle:
                  TextStyle(fontSize: 12, color: Colors.grey.shade700),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                _buildNumberField(
                  label: 'Goal',
                  controller: _goalController,
                  fieldName: 'goal_value',
                  minValue: 1,
                ),
                _buildRewardTypeDropdown(rewardType),
                _buildNumberField(
                  label: 'Amount',
                  controller: _rewardAmountController,
                  fieldName: 'reward_amount',
                  minValue: 1,
                ),
                _buildNumberField(
                  label: 'Order',
                  controller: _sortOrderController,
                  fieldName: 'sort_order',
                  minValue: 0,
                ),
              ],
            ),
            if (widget.showTierBadges) ...[
              const SizedBox(height: 16),
              Divider(color: Colors.grey.shade200),
              const SizedBox(height: 8),
              _buildTierBadgesSection(),
            ],
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
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
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
                controller.text =
                    (widget.quest[fieldName] as int?)?.toString() ?? '$minValue';
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
        Text(
          'Reward',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
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

  Widget _buildTierBadgesSection() {
    final badges = [...widget.tierBadges]..sort((a, b) =>
        ((a['condition_value'] as int?) ?? 0)
            .compareTo((b['condition_value'] as int?) ?? 0),);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.military_tech, size: 16, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(
              'Milestone Badges',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => context.go('/badges/new'),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New tier badge'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (badges.isEmpty)
          Text(
            'No milestone badges yet. Create one in the Badges screen with '
            'condition type "Aylık Görev Tamamlama" and select this quest.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: badges
                .map((b) => _buildTierChip(b))
                .toList(growable: false),
          ),
      ],
    );
  }

  Widget _buildTierChip(Map<String, dynamic> badge) {
    final count = (badge['condition_value'] as int?) ?? 0;
    final name = (badge['name'] as String?) ?? '';
    final icon = (badge['icon'] as String?) ?? '🏅';
    final xp = (badge['xp_reward'] as int?) ?? 0;
    final id = badge['id'] as String;

    return InkWell(
      onTap: () => context.go('/badges/$id'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          border: Border.all(color: Colors.amber.shade200),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              '$count× · $name',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (xp > 0) ...[
              const SizedBox(width: 6),
              Text(
                '+$xp XP',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
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
