import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/supabase_client.dart';
import '../../users/screens/user_list_screen.dart';

/// Filter providers
final curriculumSchoolFilterProvider = StateProvider<String?>((ref) => null);
final curriculumGradeFilterProvider = StateProvider<int?>((ref) => null);

/// Provider for loading curriculum assignments (grouped by school+scope)
final curriculumAssignmentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final schoolFilter = ref.watch(curriculumSchoolFilterProvider);
  final gradeFilter = ref.watch(curriculumGradeFilterProvider);

  var query = supabase
      .from(DbTables.unitCurriculumAssignments)
      .select('id, unit_id, school_id, grade, class_id, created_at, '
          'vocabulary_units(id, name, sort_order, color, icon), '
          'schools(id, name), '
          'classes(id, name, grade)');

  if (schoolFilter != null) {
    query = query.eq('school_id', schoolFilter);
  }
  if (gradeFilter != null) {
    query = query.eq('grade', gradeFilter);
  }

  final response = await query.order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

class CurriculumListScreen extends ConsumerWidget {
  const CurriculumListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(curriculumAssignmentsProvider);
    final schoolsAsync = ref.watch(allSchoolsProvider);
    final schoolFilter = ref.watch(curriculumSchoolFilterProvider);
    final gradeFilter = ref.watch(curriculumGradeFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ünite Atamaları'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/curriculum/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Yeni Atama'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                // School filter
                SizedBox(
                  width: 200,
                  child: schoolsAsync.when(
                    data: (schools) => DropdownButtonFormField<String?>(
                      value: schoolFilter,
                      decoration: const InputDecoration(
                        labelText: 'Okul',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Tüm Okullar')),
                        ...schools.map(
                          (school) => DropdownMenuItem(
                            value: school['id'] as String,
                            child: Text(school['name'] as String),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        ref.read(curriculumSchoolFilterProvider.notifier).state =
                            value;
                      },
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Okullar yüklenirken hata'),
                  ),
                ),
                const SizedBox(width: 16),

                // Grade filter
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<int?>(
                    value: gradeFilter,
                    decoration: const InputDecoration(
                      labelText: 'Sınıf',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Tümü')),
                      for (int i = 1; i <= 12; i++)
                        DropdownMenuItem(value: i, child: Text('$i. Sınıf')),
                    ],
                    onChanged: (value) {
                      ref.read(curriculumGradeFilterProvider.notifier).state =
                          value;
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Clear filters
                if (schoolFilter != null || gradeFilter != null)
                  TextButton.icon(
                    onPressed: () {
                      ref.read(curriculumSchoolFilterProvider.notifier).state =
                          null;
                      ref.read(curriculumGradeFilterProvider.notifier).state =
                          null;
                    },
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Temizle'),
                  ),
              ],
            ),
          ),

          // Assignments table
          Expanded(
            child: assignmentsAsync.when(
              data: (assignments) {
                if (assignments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ünite ataması bulunamadı',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => context.go('/curriculum/new'),
                          icon: const Icon(Icons.add),
                          label: const Text('İlk atamanızı oluşturun'),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2), // Unit
                      1: FlexColumnWidth(1.5), // School
                      2: FlexColumnWidth(1.5), // Scope
                      3: FlexColumnWidth(1.5), // Date
                      4: FixedColumnWidth(50), // Arrow
                    },
                    border: TableBorder.all(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    children: [
                      // Header
                      TableRow(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Ünite',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Okul',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Kapsam',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Oluşturulma',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          SizedBox(),
                        ],
                      ),
                      // Data rows
                      ...assignments.map((a) {
                        final unit =
                            a['vocabulary_units'] as Map<String, dynamic>?;
                        final school =
                            a['schools'] as Map<String, dynamic>?;
                        final cls =
                            a['classes'] as Map<String, dynamic>?;
                        final grade = a['grade'] as int?;
                        final createdAt = a['created_at'] as String?;

                        String scope;
                        if (cls != null) {
                          scope = 'Sınıf: ${cls['name']}';
                        } else if (grade != null) {
                          scope = '$grade. Sınıf';
                        } else {
                          scope = 'Tüm Okul';
                        }

                        return TableRow(
                          children: [
                            InkWell(
                              onTap: () =>
                                  context.go('/curriculum/${a['id']}'),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    if (unit?['icon'] != null) ...[
                                      Text(unit!['icon'],
                                          style: const TextStyle(fontSize: 18)),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: Text(
                                        unit?['name'] ?? 'Bilinmeyen Ünite',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF4F46E5),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(school?['name'] ?? ''),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: _ScopeBadge(scope: scope),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                createdAt != null
                                    ? _formatDate(createdAt)
                                    : '',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () =>
                                  context.go('/curriculum/${a['id']}'),
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(Icons.chevron_right,
                                    color: Colors.grey),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Colors.red.shade400),
                    const SizedBox(height: 16),
                    Text('Hata: $error'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () =>
                          ref.invalidate(curriculumAssignmentsProvider),
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(String isoDate) {
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return isoDate;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

class _ScopeBadge extends StatelessWidget {
  const _ScopeBadge({required this.scope});

  final String scope;

  @override
  Widget build(BuildContext context) {
    Color color;
    if (scope.startsWith('Sınıf')) {
      color = Colors.purple;
    } else if (scope.contains('Sınıf')) {
      color = Colors.blue;
    } else {
      color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        scope,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
