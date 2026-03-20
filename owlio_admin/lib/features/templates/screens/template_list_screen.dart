import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/supabase_client.dart';

// ============================================
// PROVIDERS
// ============================================

final templatesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.learningPathTemplates)
      .select('id, name, description, created_at, '
          'learning_path_template_units(id, '
          'learning_path_template_items(id, item_type))')
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

// ============================================
// SCREEN
// ============================================

class TemplateListScreen extends ConsumerWidget {
  const TemplateListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(templatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Öğrenme Yolu Şablonları'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/templates/new'),
            icon: const Icon(Icons.add),
            label: const Text('Yeni Şablon'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hata: $e'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(templatesProvider),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
        data: (templates) {
          if (templates.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('Henüz şablon yok'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.go('/templates/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('İlk Şablonu Oluştur'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final template = templates[index];
              return _TemplateCard(
                template: template,
                onTap: () => context.go('/templates/${template['id']}'),
                onDelete: () => _deleteTemplate(context, ref, template),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _deleteTemplate(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> template,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Şablonu Sil'),
        content: Text(
          '"${template['name']}" şablonunu silmek istediğinize emin misiniz? '
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final supabase = ref.read(supabaseClientProvider);
    await supabase
        .from(DbTables.learningPathTemplates)
        .delete()
        .eq('id', template['id'] as String);
    ref.invalidate(templatesProvider);
  }
}

// ============================================
// WIDGETS
// ============================================

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.onTap,
    required this.onDelete,
  });

  final Map<String, dynamic> template;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final units = List<Map<String, dynamic>>.from(
      template['learning_path_template_units'] ?? [],
    );
    int wordListCount = 0;
    int bookCount = 0;
    for (final unit in units) {
      final items = List<Map<String, dynamic>>.from(
        unit['learning_path_template_items'] ?? [],
      );
      for (final item in items) {
        if (item['item_type'] == 'word_list') {
          wordListCount++;
        } else if (item['item_type'] == 'book') {
          bookCount++;
        }
      }
    }

    final description = template['description'] as String?;
    final createdAt = _formatDate(template['created_at'] as String?);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template['name'] as String? ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _StatBadge(
                          label:
                              '${units.length} ünite · $wordListCount kelime listesi · $bookCount kitap',
                        ),
                        const Spacer(),
                        Text(
                          createdAt,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Sil',
                onPressed: onDelete,
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.blue.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

String _formatDate(String? isoDate) {
  if (isoDate == null) return '-';
  try {
    final dt = DateTime.parse(isoDate);
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    return '$day/$month/$year';
  } catch (_) {
    return '-';
  }
}
