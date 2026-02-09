import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase_client.dart';

/// Provider for loading all badges
final badgesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('badges')
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
        title: const Text('Badges'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/badges/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Badge'),
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
                    'No badges yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => context.go('/badges/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create your first badge'),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: badges.length,
            itemBuilder: (context, index) {
              final badge = badges[index];
              return _BadgeCard(
                badge: badge,
                onTap: () => context.go('/badges/${badge['id']}'),
              );
            },
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
                onPressed: () => ref.invalidate(badgesProvider),
                child: const Text('Retry'),
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
    final name = badge['name'] as String? ?? 'Unnamed Badge';
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
                  child: Text(
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
                    label: _getConditionLabel(conditionType, conditionValue),
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

  String _getConditionLabel(String type, int value) {
    switch (type) {
      case 'xp_total':
        return '$value XP';
      case 'streak_days':
        return '$value days';
      case 'books_completed':
        return '$value books';
      case 'vocabulary_learned':
        return '$value words';
      case 'perfect_scores':
        return '$value perfect';
      default:
        return type;
    }
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
