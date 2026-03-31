import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/supabase_client.dart';
import 'assignment_list_screen.dart';

/// Provider for loading a single assignment with students
final assignmentDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, assignmentId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.assignments)
      .select(
          '*, assignment_students(*, profiles(first_name, last_name, email)), '
          'profiles!assignments_teacher_id_fkey(first_name, last_name), '
          'classes(name)')
      .eq('id', assignmentId)
      .maybeSingle();
  return response;
});

class AssignmentDetailScreen extends ConsumerWidget {
  const AssignmentDetailScreen({super.key, required this.assignmentId});

  final String assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(assignmentDetailProvider(assignmentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ödev Detayları'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/assignments'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: Colors.red,
            onPressed: () => _handleDelete(context, ref),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: detailAsync.when(
        data: (assignment) {
          if (assignment == null) {
            return const Center(child: Text('Ödev bulunamadı'));
          }
          return _buildContent(context, assignment);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
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
                    ref.invalidate(assignmentDetailProvider(assignmentId)),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, Map<String, dynamic> assignment) {
    final title = assignment['title'] as String? ?? 'Başlıksız';
    final description = assignment['description'] as String?;
    final type =
        AssignmentType.fromDbValue(assignment['type'] as String? ?? 'book');
    final teacherData = assignment['profiles'] as Map<String, dynamic>?;
    final teacherName = teacherData != null
        ? '${teacherData['first_name'] ?? ''} ${teacherData['last_name'] ?? ''}'
            .trim()
        : 'Bilinmiyor';
    final classData = assignment['classes'] as Map<String, dynamic>?;
    final className = classData?['name'] as String?;
    final startDate = DateTime.tryParse(assignment['start_date'] ?? '');
    final dueDate = DateTime.tryParse(assignment['due_date'] ?? '');
    final students = (assignment['assignment_students'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bu ödev ana uygulamada bir öğretmen tarafından oluşturulmuştur. '
                    'Bu görünüm salt okunurdur.',
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Assignment metadata
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          if (description != null && description.isNotEmpty) ...[
            Text(description,
                style: TextStyle(
                    fontSize: 14, color: Colors.grey.shade700)),
            const SizedBox(height: 16),
          ],

          // Metadata chips
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _InfoChip(
                  icon: Icons.category,
                  label: type.displayName,
                  color: _typeColor(type)),
              _InfoChip(
                  icon: Icons.person,
                  label: teacherName,
                  color: Colors.indigo),
              if (className != null)
                _InfoChip(
                    icon: Icons.class_,
                    label: className,
                    color: Colors.teal),
              _InfoChip(
                  icon: Icons.play_arrow,
                  label: _formatDate(startDate),
                  color: Colors.green),
              _InfoChip(
                  icon: Icons.flag,
                  label: _formatDate(dueDate),
                  color: dueDate != null &&
                          dueDate.isBefore(DateTime.now())
                      ? Colors.red
                      : Colors.orange),
            ],
          ),
          const SizedBox(height: 32),

          // Students table
          Text(
            'Öğrenciler (${students.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          if (students.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Atanmış öğrenci yok',
                  style: TextStyle(
                      fontSize: 16, color: Colors.grey.shade500),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: DataTable(
                headingRowColor: WidgetStateColor.resolveWith(
                    (_) => Colors.grey.shade100),
                columns: const [
                  DataColumn(label: Text('Öğrenci')),
                  DataColumn(label: Text('Durum')),
                  DataColumn(
                      label: Text('İlerleme'),
                      numeric: true),
                  DataColumn(
                      label: Text('Puan'), numeric: true),
                  DataColumn(label: Text('Başlangıç')),
                  DataColumn(label: Text('Tamamlanma')),
                ],
                rows: students.map((student) {
                  final profile =
                      student['profiles'] as Map<String, dynamic>?;
                  final name = profile != null
                      ? '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'
                          .trim()
                      : 'Bilinmiyor';
                  final email =
                      profile?['email'] as String? ?? '';
                  final status = AssignmentStatus.fromDbValue(
                      student['status'] as String? ?? 'pending');
                  final progress =
                      (student['progress'] as num?)?.toDouble() ?? 0;
                  final score =
                      (student['score'] as num?)?.toDouble();
                  final startedAt =
                      DateTime.tryParse(student['started_at'] ?? '');
                  final completedAt =
                      DateTime.tryParse(student['completed_at'] ?? '');

                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                            Text(email,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                      DataCell(_StatusChip(status: status)),
                      DataCell(Text('${progress.toStringAsFixed(0)}%')),
                      DataCell(Text(
                          score != null ? score.toStringAsFixed(1) : '-')),
                      DataCell(Text(_formatDate(startedAt))),
                      DataCell(Text(_formatDate(completedAt))),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ödevi Sil'),
        content: const Text(
          'Bu ödevi silmek istediğinizden emin misiniz? '
          'Bu ödeve ait tüm öğrenci ilerlemesi de silinecektir. '
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from(DbTables.assignments)
          .delete()
          .eq('id', assignmentId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ödev silindi')),
        );
        ref.invalidate(teacherAssignmentsProvider);
        context.go('/assignments');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
      case AssignmentType.unit:
        return Colors.orange;
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style:
                TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AssignmentStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 11,
          color: _color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color get _color {
    switch (status) {
      case AssignmentStatus.pending:
        return Colors.grey;
      case AssignmentStatus.inProgress:
        return Colors.blue;
      case AssignmentStatus.completed:
        return Colors.green;
      case AssignmentStatus.overdue:
        return Colors.red;
      case AssignmentStatus.withdrawn:
        return Colors.orange;
    }
  }
}
