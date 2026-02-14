import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readeng_shared/readeng_shared.dart';

import '../../../core/supabase_client.dart';
import '../../units/screens/unit_list_screen.dart' show unitsProvider;
import '../../users/screens/user_list_screen.dart' show allSchoolsProvider;

// ============================================
// PROVIDERS
// ============================================

final unitBookAssignmentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final unitFilter = ref.watch(_unitFilterProvider);
  final schoolFilter = ref.watch(_schoolFilterProvider);

  var query = supabase.from(DbTables.unitBookAssignments).select(
    'id, unit_id, book_id, school_id, grade, class_id, order_in_unit, created_at, '
    'vocabulary_units(id, name, sort_order, color, icon), '
    'books(id, title, level, cover_url), '
    'schools(id, name), '
    'classes(id, name, grade)',
  );

  if (unitFilter != null) {
    query = query.eq('unit_id', unitFilter);
  }
  if (schoolFilter != null) {
    query = query.eq('school_id', schoolFilter);
  }

  final response =
      await query.order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

final _unitFilterProvider = StateProvider<String?>((ref) => null);
final _schoolFilterProvider = StateProvider<String?>((ref) => null);

// ============================================
// SCREEN
// ============================================

class UnitBooksListScreen extends ConsumerWidget {
  const UnitBooksListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(unitBookAssignmentsProvider);
    final unitsAsync = ref.watch(unitsProvider);
    final schoolsAsync = ref.watch(allSchoolsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unit Book Assignments'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/unit-books/new'),
            icon: const Icon(Icons.add),
            label: const Text('New Assignment'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters
            Row(
              children: [
                // Unit filter
                SizedBox(
                  width: 200,
                  child: unitsAsync.when(
                    data: (units) => DropdownButtonFormField<String?>(
                      key: ValueKey(
                        'unit_${ref.watch(_unitFilterProvider)}',
                      ),
                      initialValue: ref.watch(_unitFilterProvider),
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Units'),
                        ),
                        ...units.map(
                          (u) => DropdownMenuItem(
                            value: u['id'] as String,
                            child: Text(u['name'] as String? ?? ''),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          ref.read(_unitFilterProvider.notifier).state = v,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Error loading units'),
                  ),
                ),
                const SizedBox(width: 16),
                // School filter
                SizedBox(
                  width: 200,
                  child: schoolsAsync.when(
                    data: (schools) => DropdownButtonFormField<String?>(
                      key: ValueKey(
                        'school_${ref.watch(_schoolFilterProvider)}',
                      ),
                      initialValue: ref.watch(_schoolFilterProvider),
                      decoration: const InputDecoration(
                        labelText: 'School',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Schools'),
                        ),
                        ...schools.map(
                          (s) => DropdownMenuItem(
                            value: s['id'] as String,
                            child: Text(s['name'] as String? ?? ''),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          ref.read(_schoolFilterProvider.notifier).state = v,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Error loading schools'),
                  ),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () {
                    ref.read(_unitFilterProvider.notifier).state = null;
                    ref.read(_schoolFilterProvider.notifier).state = null;
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Table
            Expanded(
              child: assignmentsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (assignments) {
                  if (assignments.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.menu_book,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text('No book assignments yet'),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => context.go('/unit-books/new'),
                            icon: const Icon(Icons.add),
                            label: const Text('Create First Assignment'),
                          ),
                        ],
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    child: SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Unit')),
                          DataColumn(label: Text('Book')),
                          DataColumn(label: Text('Level')),
                          DataColumn(label: Text('School')),
                          DataColumn(label: Text('Scope')),
                          DataColumn(label: Text('Order')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: assignments.map((a) {
                          final unitData =
                              a['vocabulary_units'] as Map<String, dynamic>?;
                          final bookData =
                              a['books'] as Map<String, dynamic>?;
                          final schoolData =
                              a['schools'] as Map<String, dynamic>?;
                          final classData =
                              a['classes'] as Map<String, dynamic>?;

                          // Scope display
                          String scope;
                          Color scopeColor;
                          if (a['class_id'] != null && classData != null) {
                            scope = 'Class: ${classData['name']}';
                            scopeColor = Colors.purple;
                          } else if (a['grade'] != null) {
                            scope = 'Grade ${a['grade']}';
                            scopeColor = Colors.blue;
                          } else {
                            scope = 'All School';
                            scopeColor = Colors.green;
                          }

                          return DataRow(
                            cells: [
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: _parseColor(
                                        unitData?['color'] as String?,
                                      ),
                                      child: Text(
                                        unitData?['icon'] as String? ?? '',
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(unitData?['name'] as String? ?? ''),
                                  ],
                                ),
                              ),
                              DataCell(
                                Text(bookData?['title'] as String? ?? ''),
                              ),
                              DataCell(
                                Text(bookData?['level'] as String? ?? '-'),
                              ),
                              DataCell(
                                Text(schoolData?['name'] as String? ?? ''),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scopeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    scope,
                                    style: TextStyle(
                                      color: scopeColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text('${a['order_in_unit']}')),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  color: Colors.red,
                                  onPressed: () =>
                                      _deleteAssignment(context, ref, a),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAssignment(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> assignment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Assignment'),
        content: const Text('Remove this book from the unit assignment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from(DbTables.unitBookAssignments)
          .delete()
          .eq('id', assignment['id'] as String);

      ref.invalidate(unitBookAssignmentsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

Color _parseColor(String? hex) {
  if (hex == null || hex.length < 7) return const Color(0xFF58CC02);
  try {
    return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
  } catch (_) {
    return const Color(0xFF58CC02);
  }
}
