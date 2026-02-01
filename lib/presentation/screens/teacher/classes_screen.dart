import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/extensions/context_extensions.dart';
import '../../../domain/repositories/teacher_repository.dart';
import '../../../domain/usecases/teacher/create_class_usecase.dart';
import '../../providers/auth_provider.dart';
import '../../providers/teacher_provider.dart';
import '../../providers/usecase_providers.dart';

class ClassesScreen extends ConsumerWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(currentTeacherClassesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Classes'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateClassDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Class'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentTeacherClassesProvider);
        },
        child: classesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: context.colorScheme.error),
                const SizedBox(height: 16),
                Text('Error loading classes', style: context.textTheme.bodyLarge),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(currentTeacherClassesProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (classes) {
            if (classes.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.groups_outlined,
                      size: 64,
                      color: context.colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No classes found',
                      style: context.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Classes from your school will appear here',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: classes.length,
              itemBuilder: (context, index) {
                final classItem = classes[index];
                return _ClassCard(
                  classItem: classItem,
                  onTap: () {
                    // Navigate to class detail (nested under /teacher/classes/:classId)
                    context.push('/teacher/classes/${classItem.id}');
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showCreateClassDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create New Class'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Class Name *',
                  hintText: 'e.g., 5A, Grade 7',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a class name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'e.g., Morning English class',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              Navigator.pop(dialogContext);
              await _createClass(
                context,
                ref,
                nameController.text.trim(),
                descController.text.trim().isEmpty ? null : descController.text.trim(),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createClass(
    BuildContext context,
    WidgetRef ref,
    String name,
    String? description,
  ) async {
    // Get teacher's school ID
    final user = ref.read(authStateChangesProvider).valueOrNull;
    if (user == null || user.schoolId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Could not determine school')),
      );
      return;
    }

    final useCase = ref.read(createClassUseCaseProvider);
    final result = await useCase(CreateClassParams(
      schoolId: user.schoolId,
      name: name,
      description: description,
    ),);

    if (!context.mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${failure.message}'),
            backgroundColor: context.colorScheme.error,
          ),
        );
      },
      (classId) {
        ref.invalidate(currentTeacherClassesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Class "$name" created'),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.classItem,
    required this.onTap,
  });

  final TeacherClass classItem;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Class icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: context.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    classItem.grade?.toString() ?? '?',
                    style: context.textTheme.headlineSmall?.copyWith(
                      color: context.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Class info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classItem.name,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 16,
                          color: context.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${classItem.studentCount} students',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (classItem.academicYear != null) ...[
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: context.colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            classItem.academicYear!,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colorScheme.outline,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Progress indicator
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${classItem.avgProgress.toStringAsFixed(0)}%',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _getProgressColor(classItem.avgProgress),
                    ),
                  ),
                  Text(
                    'avg progress',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.outline,
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: context.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 70) return Colors.green;
    if (progress >= 40) return Colors.orange;
    return Colors.red;
  }
}
