import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/supabase_client.dart';

/// Provider for loading all teacher-created assignments
final teacherAssignmentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.assignments)
      .select(
          '*, profiles!assignments_teacher_id_fkey(first_name, last_name), classes(name)')
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

/// Filter by assignment type
final assignmentTypeFilterProvider =
    StateProvider<AssignmentType?>((ref) => null);

class AssignmentListScreen extends ConsumerWidget {
  const AssignmentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider);
    final typeFilter = ref.watch(assignmentTypeFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ödevler'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Column(
        children: [
          // Filter bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<AssignmentType?>(
                    value: typeFilter,
                    decoration: const InputDecoration(
                      labelText: 'Tür',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Tüm Türler'),
                      ),
                      ...AssignmentType.values.map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.displayName),
                          )),
                    ],
                    onChanged: (value) {
                      ref.read(assignmentTypeFilterProvider.notifier).state =
                          value;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                if (typeFilter != null)
                  TextButton.icon(
                    onPressed: () {
                      ref.read(assignmentTypeFilterProvider.notifier).state =
                          null;
                    },
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Temizle'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // List
          Expanded(
            child: assignmentsAsync.when(
              data: (assignments) {
                final filtered = typeFilter != null
                    ? assignments
                        .where(
                            (a) => a['type'] == typeFilter.dbValue)
                        .toList()
                    : assignments;

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Ödev bulunamadı',
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ödevler ana uygulamada öğretmenler tarafından oluşturulur.',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _AssignmentCard(
                      assignment: filtered[index],
                      onTap: () => context
                          .go('/assignments/${filtered[index]['id']}'),
                    );
                  },
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
                          ref.invalidate(teacherAssignmentsProvider),
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
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.assignment, required this.onTap});

  final Map<String, dynamic> assignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = assignment['title'] as String? ?? 'Başlıksız';
    final type =
        AssignmentType.fromDbValue(assignment['type'] as String? ?? 'book');
    final teacherData =
        assignment['profiles'] as Map<String, dynamic>?;
    final teacherName = teacherData != null
        ? '${teacherData['first_name'] ?? ''} ${teacherData['last_name'] ?? ''}'
            .trim()
        : 'Bilinmiyor';
    final classData = assignment['classes'] as Map<String, dynamic>?;
    final className = classData?['name'] as String? ?? 'Sınıf yok';
    final startDate = DateTime.tryParse(assignment['start_date'] ?? '');
    final dueDate = DateTime.tryParse(assignment['due_date'] ?? '');
    final isOverdue =
        dueDate != null && dueDate.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Type icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _typeColor(type).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _typeIcon(type),
                  color: _typeColor(type),
                ),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _TypeChip(type: type),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          teacherName,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.class_outlined,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          className,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatDate(startDate)} – ${_formatDate(dueDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isOverdue
                                ? Colors.red.shade600
                                : Colors.grey.shade600,
                          ),
                        ),
                        if (isOverdue) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Süresi Geçmiş',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static Color _typeColor(AssignmentType type) {
    switch (type) {
      case AssignmentType.book:
        return Colors.blue;
      case AssignmentType.vocabulary:
        return Colors.green;
      case AssignmentType.mixed:
        return Colors.orange;
    }
  }

  static IconData _typeIcon(AssignmentType type) {
    switch (type) {
      case AssignmentType.book:
        return Icons.menu_book;
      case AssignmentType.vocabulary:
        return Icons.abc;
      case AssignmentType.mixed:
        return Icons.dashboard;
    }
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final AssignmentType type;

  @override
  Widget build(BuildContext context) {
    final color = _AssignmentCard._typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.displayName,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
