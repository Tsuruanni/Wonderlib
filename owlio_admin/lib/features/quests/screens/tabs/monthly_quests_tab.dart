import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../../core/supabase_client.dart';
import '../../widgets/quest_card.dart';

final monthlyQuestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.monthlyQuests)
      .select()
      .order('sort_order', ascending: true);
  return List<Map<String, dynamic>>.from(response);
});

/// All tier badges (condition_type='monthly_quest_completed'), grouped by
/// their `condition_param` (the quest id). Enables per-quest tier preview
/// in the QuestCard without a roundtrip per card.
final tierBadgesByQuestProvider =
    FutureProvider<Map<String, List<Map<String, dynamic>>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.badges)
      .select('id, name, icon, condition_param, condition_value, xp_reward, is_active')
      .eq('condition_type', 'monthly_quest_completed')
      .order('condition_value', ascending: true);

  final rows = List<Map<String, dynamic>>.from(response);
  final map = <String, List<Map<String, dynamic>>>{};
  for (final row in rows) {
    final questId = row['condition_param'] as String?;
    if (questId == null) continue;
    (map[questId] ??= <Map<String, dynamic>>[]).add(row);
  }
  return map;
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

  Future<void> _updateQuest(
      String questId, Map<String, dynamic> fields,) async {
    final fieldKey = '$questId-${fields.keys.first}';
    if (_savingFields.contains(fieldKey)) return;

    setState(() => _savingFields.add(fieldKey));

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from(DbTables.monthlyQuests)
          .update(fields)
          .eq('id', questId);

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
      if (mounted) {
        setState(() => _savingFields.remove(fieldKey));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final questsAsync = ref.watch(monthlyQuestsProvider);
    final tierBadgesAsync = ref.watch(tierBadgesByQuestProvider);

    return questsAsync.when(
      data: (quests) {
        final tierBadges = tierBadgesAsync.valueOrNull ?? const {};
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month,
                        color: Colors.purple.shade700,),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Monthly quests reset at the start of each calendar month. '
                        'Tier badges (1×, 3×, 5× …) are defined on the Badges screen — '
                        'pick "Aylık Görev Tamamlama" as condition type.',
                        style: TextStyle(color: Colors.purple.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (quests.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      'No monthly quests yet.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              else
                ...quests.map(
                  (quest) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: QuestCard(
                      quest: quest,
                      stats: null,
                      onUpdate: (fields) =>
                          _updateQuest(quest['id'] as String, fields),
                      savingFields: _savingFields,
                      questId: quest['id'] as String,
                      showTierBadges: true,
                      showStats: false,
                      tierBadges: tierBadges[quest['id'] as String] ?? const [],
                    ),
                  ),
                ),
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
                ref.invalidate(tierBadgesByQuestProvider);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
