import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readeng_shared/readeng_shared.dart';

import '../../../core/supabase_client.dart';
import '../../users/screens/user_list_screen.dart';

/// Provider for class school filter
final classSchoolFilterProvider = StateProvider<String?>((ref) => null);

/// Provider for loading all classes with filters
final classesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final schoolFilter = ref.watch(classSchoolFilterProvider);

  var query = supabase.from(DbTables.classes).select('*, schools(name), profiles(count)');

  if (schoolFilter != null) {
    query = query.eq('school_id', schoolFilter);
  }

  final response = await query.order('name');
  return List<Map<String, dynamic>>.from(response);
});

class ClassListScreen extends ConsumerWidget {
  const ClassListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classesProvider);
    final schoolsAsync = ref.watch(allSchoolsProvider);
    final selectedSchool = ref.watch(classSchoolFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/classes/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Class'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Filter
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
                Expanded(
                  child: schoolsAsync.when(
                    data: (schools) => DropdownButtonFormField<String?>(
                      value: selectedSchool,
                      decoration: const InputDecoration(
                        labelText: 'School',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Schools'),
                        ),
                        ...schools.map((school) => DropdownMenuItem(
                              value: school['id'] as String,
                              child: Text(school['name'] as String),
                            )),
                      ],
                      onChanged: (value) {
                        ref.read(classSchoolFilterProvider.notifier).state = value;
                      },
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 16),

                // Clear filter
                if (selectedSchool != null)
                  TextButton.icon(
                    onPressed: () {
                      ref.read(classSchoolFilterProvider.notifier).state = null;
                    },
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear'),
                  ),
              ],
            ),
          ),

          // Classes list
          Expanded(
            child: classesAsync.when(
              data: (classes) {
                if (classes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.class_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No classes yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => context.go('/classes/new'),
                          icon: const Icon(Icons.add),
                          label: const Text('Create your first class'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: classes.length,
                  itemBuilder: (context, index) {
                    final classItem = classes[index];
                    final studentCount = classItem['profiles']?[0]?['count'] ?? 0;

                    return _ClassCard(
                      classItem: classItem,
                      studentCount: studentCount,
                      onTap: () => context.go('/classes/${classItem['id']}'),
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
                      onPressed: () => ref.invalidate(classesProvider),
                      child: const Text('Retry'),
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

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.classItem,
    required this.studentCount,
    required this.onTap,
  });

  final Map<String, dynamic> classItem;
  final int studentCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final schoolName = classItem['schools']?['name'] as String? ?? 'No School';
    final grade = classItem['grade'] as int?;
    final academicYear = classItem['academic_year'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Class icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.class_,
                  color: Colors.teal,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),

              // Class info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      classItem['name'] as String? ?? 'Unnamed Class',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // School
                    Text(
                      schoolName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _Chip(
                          label: '$studentCount students',
                          color: Colors.blue,
                        ),
                        if (grade != null)
                          _Chip(
                            label: 'Grade $grade',
                            color: Colors.purple,
                          ),
                        if (academicYear != null)
                          _Chip(
                            label: academicYear,
                            color: Colors.grey,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
