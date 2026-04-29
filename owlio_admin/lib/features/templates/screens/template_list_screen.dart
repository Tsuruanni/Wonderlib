import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';

// ============================================
// TEMPLATE PROVIDERS
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
// ASSIGNMENT PROVIDERS
// ============================================

final allAssignmentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.scopeLearningPaths)
      .select(
        'id, name, template_id, sort_order, grade, class_id, school_id, '
        'sequential_lock, books_exempt_from_lock, created_at, '
        'schools(id, name), '
        'classes(id, name, grade), '
        'scope_learning_path_units(id, '
        '  vocabulary_units(name), '
        '  scope_unit_items(id, item_type)'
        ')',
      )
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

// ============================================
// SCREEN
// ============================================

class LearningPathsScreen extends ConsumerStatefulWidget {
  const LearningPathsScreen({super.key});

  @override
  ConsumerState<LearningPathsScreen> createState() =>
      _LearningPathsScreenState();
}

class _LearningPathsScreenState extends ConsumerState<LearningPathsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Öğrenme Yolları'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: _buildActions(context),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Şablonlar'),
            Tab(text: 'Atamalar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _TemplatesTab(),
          _AssignmentsTab(),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    if (_tabController.index == 0) {
      return [
        FilledButton.icon(
          onPressed: () => context.go('/templates/new'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Yeni Şablon'),
        ),
        const SizedBox(width: 16),
      ];
    } else {
      return [
        FilledButton.icon(
          onPressed: () => context.go('/learning-path-assignments/new'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Yeni Atama Yap'),
        ),
        const SizedBox(width: 16),
      ];
    }
  }
}

// ============================================
// TAB 0: ŞABLONLAR
// ============================================

class _TemplatesTab extends ConsumerWidget {
  const _TemplatesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(templatesProvider);

    return templatesAsync.when(
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
              onClone: () => _cloneTemplate(context, ref, template),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteTemplate(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> template,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Şablonu Sil'),
        content: Text(
          '"${template['name']}" şablonunu silmek istediğinize emin misiniz? '
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
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

  Future<void> _cloneTemplate(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> template,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Şablonu Klonla'),
        content: Text(
          '"${template['name']}" şablonu tüm üniteleri ve item\'larıyla '
          'birlikte kopyalanacak. Kopya, "(Kopya)" eki ile yeni bir '
          'şablon olarak oluşturulacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Klonla'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      final sourceId = template['id'] as String;

      // 1. Fetch source template row
      final source = await supabase
          .from(DbTables.learningPathTemplates)
          .select()
          .eq('id', sourceId)
          .single();

      // 2. Insert clone with new id, suffixed name
      final newId = const Uuid().v4();
      final cloneRow = Map<String, dynamic>.from(source);
      cloneRow['id'] = newId;
      cloneRow['name'] = '${source['name']} (Kopya)';
      cloneRow.remove('created_at');
      cloneRow.remove('updated_at');
      await supabase.from(DbTables.learningPathTemplates).insert(cloneRow);

      // 3. Fetch source units, insert clones, remember id mapping
      final sourceUnits = await supabase
          .from(DbTables.learningPathTemplateUnits)
          .select()
          .eq('template_id', sourceId);

      final unitIdMap = <String, String>{}; // old → new
      if (sourceUnits.isNotEmpty) {
        final newUnitRows = <Map<String, dynamic>>[];
        for (final u in sourceUnits) {
          final newUnitId = const Uuid().v4();
          unitIdMap[u['id'] as String] = newUnitId;
          final unitClone = Map<String, dynamic>.from(u);
          unitClone['id'] = newUnitId;
          unitClone['template_id'] = newId;
          unitClone.remove('created_at');
          unitClone.remove('updated_at');
          newUnitRows.add(unitClone);
        }
        await supabase
            .from(DbTables.learningPathTemplateUnits)
            .insert(newUnitRows);

        // 4. Fetch source items for those units, re-point to cloned units
        final sourceItems = await supabase
            .from(DbTables.learningPathTemplateItems)
            .select()
            .inFilter('template_unit_id', unitIdMap.keys.toList());

        if (sourceItems.isNotEmpty) {
          final newItemRows = sourceItems.map((it) {
            final clone = Map<String, dynamic>.from(it);
            clone['id'] = const Uuid().v4();
            clone['template_unit_id'] =
                unitIdMap[it['template_unit_id'] as String];
            clone.remove('created_at');
            clone.remove('updated_at');
            return clone;
          }).toList();
          await supabase
              .from(DbTables.learningPathTemplateItems)
              .insert(newItemRows);
        }
      }

      ref.invalidate(templatesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şablon klonlandı')),
        );
        context.go('/templates/$newId');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Klonlama başarısız: $e')),
        );
      }
    }
  }
}

// ============================================
// TAB 1: ATAMALAR
// ============================================

class _AssignmentsTab extends ConsumerWidget {
  const _AssignmentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(allAssignmentsProvider);

    return assignmentsAsync.when(
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

        // Group by school
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
                              fontSize: 12, color: Colors.grey.shade700),
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
                      onDelete: () =>
                          _deleteAssignment(context, ref, a),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
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

    if (confirmed != true || !context.mounted) return;

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
// SHARED WIDGETS
// ============================================

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.onTap,
    required this.onDelete,
    required this.onClone,
  });

  final Map<String, dynamic> template;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onClone;

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
        if (item['item_type'] == 'word_list') wordListCount++;
        else if (item['item_type'] == 'book') bookCount++;
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
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 14),
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
                              color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.content_copy_outlined),
                tooltip: 'Klonla',
                onPressed: onClone,
              ),
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

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.assignment,
    required this.onDelete,
  });

  final Map<String, dynamic> assignment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final grade = assignment['grade'] as int?;
    final classData = assignment['classes'] as Map<String, dynamic>?;
    final classId = assignment['class_id'] as String?;

    String scopeLabel;
    Color scopeColor;

    if (classId != null && classData != null) {
      final className = classData['name'] as String? ?? '';
      final classGrade = classData['grade'] as int?;
      scopeLabel = '$className (${classGrade ?? '?'}. Sınıf)';
      scopeColor = Colors.purple;
    } else if (grade != null) {
      scopeLabel = '$grade. Sınıf';
      scopeColor = Colors.teal;
    } else {
      scopeLabel = 'Tüm Okul';
      scopeColor = Colors.blue;
    }

    final units = List<Map<String, dynamic>>.from(
      assignment['scope_learning_path_units'] ?? [],
    );
    int wordListCount = 0;
    int bookCount = 0;
    for (final unit in units) {
      final items = List<Map<String, dynamic>>.from(
        unit['scope_unit_items'] ?? [],
      );
      for (final item in items) {
        if (item['item_type'] == 'word_list') wordListCount++;
        else if (item['item_type'] == 'book') bookCount++;
      }
    }

    final name = assignment['name'] as String? ?? '';
    final sequentialLock = assignment['sequential_lock'] as bool? ?? true;
    final createdAt = _formatDate(assignment['created_at'] as String?);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: scopeColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: scopeColor.withAlpha(80)),
                        ),
                        child: Text(
                          scopeLabel,
                          style: TextStyle(
                            color: scopeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _StatBadge(
                        label:
                            '${units.length} ünite · $wordListCount liste · $bookCount kitap',
                      ),
                      const Spacer(),
                      if (sequentialLock)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(Icons.lock_outline,
                              size: 16, color: Colors.orange.shade700),
                        ),
                      Text(createdAt,
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Düzenle',
              onPressed: () {
                final schoolId = assignment['school_id'] as String?;
                final grade = assignment['grade'] as int?;
                final classId = assignment['class_id'] as String?;

                var url =
                    '/learning-path-assignments/new?schoolId=$schoolId';
                if (classId != null) {
                  url += '&classId=$classId';
                } else if (grade != null) {
                  url += '&grade=$grade';
                }
                context.go(url);
              },
            ),
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
    return '$day/$month/${dt.year}';
  } catch (_) {
    return '-';
  }
}
