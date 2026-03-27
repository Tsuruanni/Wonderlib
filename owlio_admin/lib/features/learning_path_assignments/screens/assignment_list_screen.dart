import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/supabase_client.dart';
import '../../templates/screens/template_list_screen.dart' show allAssignmentsProvider;

// ============================================
// SCREEN
// ============================================

class LpAssignmentListScreen extends ConsumerWidget {
  const LpAssignmentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(allAssignmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Öğrenme Yolu Atamaları'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/learning-path-assignments/new'),
            icon: const Icon(Icons.add),
            label: const Text('Yeni Atama Yap'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: assignmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hata: $e'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(allAssignmentsProvider),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
        data: (assignments) {
          if (assignments.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_tree_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('Henüz öğrenme yolu ataması yapılmamış'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () =>
                        context.go('/learning-path-assignments/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('İlk Atamayı Yap'),
                  ),
                ],
              ),
            );
          }

          // Group assignments by school
          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final a in assignments) {
            final school = a['schools'] as Map<String, dynamic>? ?? {};
            final schoolName = school['name'] as String? ?? 'Bilinmeyen Okul';
            grouped.putIfAbsent(schoolName, () => []).add(a);
          }

          final schoolNames = grouped.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: schoolNames.length,
            itemBuilder: (context, schoolIndex) {
              final schoolName = schoolNames[schoolIndex];
              final schoolAssignments = grouped[schoolName]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (schoolIndex > 0) const SizedBox(height: 24),
                  // School header
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(Icons.school, color: Colors.grey.shade700),
                        const SizedBox(width: 8),
                        Text(
                          schoolName,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${schoolAssignments.length} atama',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...schoolAssignments.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _AssignmentCard(
                        assignment: a,
                        onDelete: () => _deleteAssignment(context, ref, a),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _deleteAssignment(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> assignment,
  ) async {
    final name = assignment['name'] as String? ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Atamayı Sil'),
        content: Text(
          '"$name" ataması ve tüm içeriği kalıcı olarak silinecektir. '
          'Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from(DbTables.scopeLearningPaths)
          .delete()
          .eq('id', assignment['id'] as String);
      ref.invalidate(allAssignmentsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$name" silindi')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ============================================
// WIDGETS
// ============================================

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.assignment,
    required this.onDelete,
  });

  final Map<String, dynamic> assignment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    // Scope info
    final grade = assignment['grade'] as int?;
    final classData = assignment['classes'] as Map<String, dynamic>?;
    final classId = assignment['class_id'] as String?;

    String scopeLabel;
    IconData scopeIcon;
    Color scopeColor;

    if (classId != null && classData != null) {
      final className = classData['name'] as String? ?? '';
      final classGrade = classData['grade'] as int?;
      scopeLabel = '$className (${classGrade ?? '?'}. Sınıf)';
      scopeIcon = Icons.groups;
      scopeColor = Colors.purple;
    } else if (grade != null) {
      scopeLabel = '$grade. Sınıf';
      scopeIcon = Icons.class_;
      scopeColor = Colors.teal;
    } else {
      scopeLabel = 'Tüm Okul';
      scopeIcon = Icons.school;
      scopeColor = Colors.blue;
    }

    // Stats
    final units = List<Map<String, dynamic>>.from(
      assignment['scope_learning_path_units'] ?? [],
    );
    int wordListCount = 0;
    int bookCount = 0;
    int gameCount = 0;
    int treasureCount = 0;
    for (final unit in units) {
      final items = List<Map<String, dynamic>>.from(
        unit['scope_unit_items'] ?? [],
      );
      for (final item in items) {
        switch (item['item_type'] as String?) {
          case 'word_list':
            wordListCount++;
            break;
          case 'book':
            bookCount++;
            break;
          case 'game':
            gameCount++;
            break;
          case 'treasure':
            treasureCount++;
            break;
        }
      }
    }

    final name = assignment['name'] as String? ?? '';
    final templateId = assignment['template_id'] as String?;
    final sequentialLock = assignment['sequential_lock'] as bool? ?? true;
    final createdAt = _formatDate(assignment['created_at'] as String?);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Scope indicator
            Container(
              width: 4,
              height: 60,
              decoration: BoxDecoration(
                color: scopeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + scope badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      _ScopeBadge(
                        icon: scopeIcon,
                        label: scopeLabel,
                        color: scopeColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Stats row
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.folder_outlined,
                        label: '${units.length} ünite',
                      ),
                      const SizedBox(width: 8),
                      if (wordListCount > 0) ...[
                        _StatChip(
                          icon: Icons.list_alt,
                          label: '$wordListCount kelime listesi',
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (bookCount > 0) ...[
                        _StatChip(
                          icon: Icons.menu_book,
                          label: '$bookCount kitap',
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (gameCount > 0) ...[
                        _StatChip(
                          icon: Icons.sports_esports,
                          label: '$gameCount oyun',
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (treasureCount > 0) ...[
                        _StatChip(
                          icon: Icons.diamond_outlined,
                          label: '$treasureCount hazine',
                        ),
                        const SizedBox(width: 8),
                      ],
                      const Spacer(),
                      if (sequentialLock)
                        Tooltip(
                          message: 'Sıralı ilerleme aktif',
                          child: Icon(Icons.lock_outline,
                              size: 16, color: Colors.orange.shade700),
                        ),
                      if (templateId != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Tooltip(
                            message: 'Şablondan oluşturuldu',
                            child: Icon(Icons.description_outlined,
                                size: 16, color: Colors.grey.shade500),
                          ),
                        ),
                      const SizedBox(width: 8),
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
          ],
        ),
      ),
    );
  }
}

class _ScopeBadge extends StatelessWidget {
  const _ScopeBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
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
