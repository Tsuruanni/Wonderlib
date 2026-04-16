import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../../core/supabase_client.dart';
import '../../widgets/quest_card.dart';

final dailyQuestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.dailyQuests)
      .select()
      .order('sort_order', ascending: true);
  return List<Map<String, dynamic>>.from(response);
});

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

  Future<void> _updateQuest(
      String questId, Map<String, dynamic> fields,) async {
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
      if (mounted) {
        setState(() => _savingFields.remove(fieldKey));
      }
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
              ...quests.map(
                (quest) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: QuestCard(
                    quest: quest,
                    stats: stats[quest['id'] as String],
                    onUpdate: (fields) =>
                        _updateQuest(quest['id'] as String, fields),
                    savingFields: _savingFields,
                    questId: quest['id'] as String,
                    showTierBadges: false,
                    showStats: true,
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
}
