import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/supabase_client.dart';
import '../../../core/utils/badge_helpers.dart';

/// Provider for loading all badges
final badgesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.badges)
      .select()
      .order('name');

  return List<Map<String, dynamic>>.from(response);
});

class BadgeListScreen extends ConsumerWidget {
  const BadgeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(badgesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rozetler'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/badges/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Yeni Rozet'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: badgesAsync.when(
        data: (badges) {
          if (badges.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz rozet yok',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => context.go('/badges/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('İlk rozetinizi oluşturun'),
                  ),
                ],
              ),
            );
          }

          // Group by condition_type. For myth_category_completed, sub-group by
          // condition_param (each category is its own visual group).
          final groups = <String, List<Map<String, dynamic>>>{};
          for (final b in badges) {
            final type = b['condition_type'] as String? ?? '';
            final param = b['condition_param'] as String?;
            final key = type == 'myth_category_completed' && param != null
                ? 'myth_category_completed:$param'
                : type;
            (groups[key] ??= []).add(b);
          }

          // Stable display order — Achievements first, then Card Collection.
          final orderedKeys = badgeGroupOrderedKeys;

          // Sort group keys: ordered list first, then anything else alphabetically.
          final sortedKeys = <String>[];
          for (final k in orderedKeys) {
            if (groups.containsKey(k)) sortedKeys.add(k);
          }
          for (final k in groups.keys) {
            if (!sortedKeys.contains(k)) sortedKeys.add(k);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final key in sortedKeys) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, top: 8),
                    child: Text(
                      getBadgeGroupHeaderLabel(key),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final badge in groups[key]!)
                        SizedBox(
                          width: 240,
                          height: 150,
                          child: _BadgeCard(
                            badge: badge,
                            onTap: () => context.go('/badges/${badge['id']}'),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
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
              Text('Hata: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(badgesProvider),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({
    required this.badge,
    required this.onTap,
  });

  final Map<String, dynamic> badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = badge['icon'] as String? ?? '🏆';
    final name = badge['name'] as String? ?? 'İsimsiz Rozet';
    final description = badge['description'] as String? ?? '';
    final conditionType = badge['condition_type'] as String? ?? '';
    final conditionValue = badge['condition_value'] as int? ?? 0;
    final xpReward = badge['xp_reward'] as int? ?? 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: icon.startsWith('assets/')
                      ? Image.asset(
                          icon,
                          width: 36,
                          height: 36,
                          fit: BoxFit.contain,
                        )
                      : Text(
                          icon,
                          style: const TextStyle(fontSize: 24),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Name
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Description
              Expanded(
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Condition & XP
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _Chip(
                    label: getConditionLabel(conditionType, conditionValue),
                    color: Colors.blue,
                  ),
                  _Chip(
                    label: '+$xpReward XP',
                    color: Colors.purple,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

