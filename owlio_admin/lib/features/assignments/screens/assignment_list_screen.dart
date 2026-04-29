import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // CountOption

import '../../../core/supabase_client.dart';

/// Filter by assignment type
final assignmentTypeFilterProvider =
    StateProvider<AssignmentType?>((ref) => null);

/// Search query (matches title)
final assignmentSearchProvider = StateProvider<String>((ref) => '');

/// Current page index (0-based)
final assignmentPageProvider = StateProvider<int>((ref) => 0);

/// Loads teacher-created assignments with type filter, search, pagination.
/// Returns `{ data, total, page, pageSize }`.
final teacherAssignmentsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final typeFilter = ref.watch(assignmentTypeFilterProvider);
  final search = ref.watch(assignmentSearchProvider);
  final page = ref.watch(assignmentPageProvider);

  const pageSize = 50;
  final offset = page * pageSize;

  var query = supabase.from(DbTables.assignments).select(
      '*, profiles!assignments_teacher_id_fkey(first_name, last_name), classes(name)');
  var countQuery = supabase.from(DbTables.assignments).select();

  if (typeFilter != null) {
    query = query.eq('type', typeFilter.dbValue);
    countQuery = countQuery.eq('type', typeFilter.dbValue);
  }
  if (search.isNotEmpty) {
    final escaped = search.replaceAll(',', ' ');
    query = query.ilike('title', '%$escaped%');
    countQuery = countQuery.ilike('title', '%$escaped%');
  }

  final response = await query
      .order('created_at', ascending: false)
      .range(offset, offset + pageSize - 1);
  final countResult = await countQuery.count(CountOption.exact);

  return {
    'data': List<Map<String, dynamic>>.from(response),
    'total': countResult.count,
    'page': page,
    'pageSize': pageSize,
  };
});

class AssignmentListScreen extends ConsumerStatefulWidget {
  const AssignmentListScreen({super.key});

  @override
  ConsumerState<AssignmentListScreen> createState() =>
      _AssignmentListScreenState();
}

class _AssignmentListScreenState extends ConsumerState<AssignmentListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(assignmentSearchProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _resetPage() {
    ref.read(assignmentPageProvider.notifier).state = 0;
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final trimmed = value.trim();
      if (ref.read(assignmentSearchProvider) != trimmed) {
        ref.read(assignmentSearchProvider.notifier).state = trimmed;
        _resetPage();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider);
    final typeFilter = ref.watch(assignmentTypeFilterProvider);
    final currentPage = ref.watch(assignmentPageProvider);

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
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Başlık ara...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _debounce?.cancel();
                              _searchController.clear();
                              ref
                                  .read(assignmentSearchProvider.notifier)
                                  .state = '';
                              _resetPage();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: _onSearchChanged,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<AssignmentType?>(
                        value: typeFilter,
                        decoration: const InputDecoration(
                          labelText: 'Tür',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
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
                          ref
                              .read(assignmentTypeFilterProvider.notifier)
                              .state = value;
                          _resetPage();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (typeFilter != null ||
                        ref.read(assignmentSearchProvider).isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          ref
                              .read(assignmentTypeFilterProvider.notifier)
                              .state = null;
                          ref.read(assignmentSearchProvider.notifier).state =
                              '';
                          _searchController.clear();
                          _resetPage();
                        },
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Temizle'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: assignmentsAsync.when(
              data: (result) {
                final assignments =
                    result['data'] as List<Map<String, dynamic>>;
                final total = result['total'] as int;
                final pageSize = result['pageSize'] as int;
                final totalPages = total == 0 ? 1 : (total / pageSize).ceil();

                if (assignments.isEmpty) {
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

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$total ödevden ${assignments.length} tanesi',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          Text(
                            'Sayfa ${currentPage + 1} / $totalPages',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: assignments.length,
                        itemBuilder: (context, index) {
                          return _AssignmentCard(
                            assignment: assignments[index],
                            onTap: () => context.go(
                                '/assignments/${assignments[index]['id']}'),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: currentPage > 0
                                ? () => ref
                                    .read(assignmentPageProvider.notifier)
                                    .state = currentPage - 1
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          const SizedBox(width: 16),
                          Text('Sayfa ${currentPage + 1} / $totalPages'),
                          const SizedBox(width: 16),
                          IconButton(
                            onPressed: currentPage < totalPages - 1
                                ? () => ref
                                    .read(assignmentPageProvider.notifier)
                                    .state = currentPage + 1
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
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
      case AssignmentType.unit:
        return Colors.orange;
    }
  }

  static IconData _typeIcon(AssignmentType type) {
    switch (type) {
      case AssignmentType.book:
        return Icons.menu_book;
      case AssignmentType.vocabulary:
        return Icons.abc;
      case AssignmentType.unit:
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
