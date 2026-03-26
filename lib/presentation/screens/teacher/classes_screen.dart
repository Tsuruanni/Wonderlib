import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/utils/extensions/context_extensions.dart';
import '../../../domain/repositories/teacher_repository.dart';
import '../../../domain/usecases/teacher/create_class_usecase.dart';
import '../../../domain/usecases/teacher/delete_class_usecase.dart';
import '../../../domain/usecases/teacher/update_class_usecase.dart';
import '../../providers/auth_provider.dart';
import '../../providers/teacher_provider.dart';
import '../../providers/usecase_providers.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/error_state_widget.dart';
import '../../widgets/common/playful_card.dart';
import '../../widgets/common/responsive_layout.dart';

class ClassesScreen extends ConsumerWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(currentTeacherClassesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Classes'),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_new_class',
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
          error: (_, __) => ErrorStateWidget(
            message: 'Error loading classes',
            onRetry: () => ref.invalidate(currentTeacherClassesProvider),
          ),
          data: (classes) {
            if (classes.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.groups_outlined,
                title: 'No classes found',
                subtitle: 'Classes from your school will appear here',
              );
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 20,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'This page is for managing your classes and students. ',
                                  style: context.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(
                                  text: 'You can edit class names, delete classes, move students between classes, '
                                      'and access student login credentials.\n\n',
                                  style: context.textTheme.bodySmall,
                                ),
                                TextSpan(
                                  text: 'To view student progress, performance summaries, or reading statistics, '
                                      'please use the ',
                                  style: context.textTheme.bodySmall,
                                ),
                                TextSpan(
                                  text: 'Reports',
                                  style: context.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.secondary,
                                  ),
                                ),
                                TextSpan(
                                  text: ' tab instead.',
                                  style: context.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ResponsiveWrap(
                minItemWidth: 300,
                children: classes
                    .map(
                      (classItem) => _ClassCard(
                        classItem: classItem,
                        onTap: () {
                          context.push(AppRoutes.teacherClassDetailPath(classItem.id));
                        },
                        onEdit: () => _showEditClassDialog(context, ref, classItem),
                        onDelete: () => _deleteClass(context, ref, classItem),
                      ),
                    )
                    .toList(),
              ),
                ],
              ),
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
    int? selectedGrade;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
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
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Grade *',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(12, (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text('Grade ${i + 1}'),
                  )),
                  validator: (value) => value == null ? 'Please select a grade' : null,
                  onChanged: (value) => setDialogState(() => selectedGrade = value),
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
                  selectedGrade!,
                  descController.text.trim().isEmpty ? null : descController.text.trim(),
                );
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createClass(
    BuildContext context,
    WidgetRef ref,
    String name,
    int grade,
    String? description,
  ) async {
    // Get teacher's school ID
    final user = ref.read(authStateChangesProvider).valueOrNull;
    if (user == null || user.schoolId.isEmpty) {
      showAppSnackBar(context, 'Error: Could not determine school', type: SnackBarType.error);
      return;
    }

    final useCase = ref.read(createClassUseCaseProvider);
    final result = await useCase(CreateClassParams(
      schoolId: user.schoolId,
      name: name,
      grade: grade,
      description: description,
    ),);

    if (!context.mounted) return;

    result.fold(
      (failure) {
        showAppSnackBar(context, 'Error: ${failure.message}', type: SnackBarType.error);
      },
      (classId) {
        ref.invalidate(currentTeacherClassesProvider);
        showAppSnackBar(context, 'Class "$name" created', type: SnackBarType.success);
      },
    );
  }

  void _showEditClassDialog(BuildContext context, WidgetRef ref, TeacherClass classItem) {
    final nameController = TextEditingController(text: classItem.name);
    final formKey = GlobalKey<FormState>();
    int? selectedGrade = classItem.grade;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit Class'),
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
                DropdownButtonFormField<int>(
                  value: selectedGrade,
                  decoration: const InputDecoration(
                    labelText: 'Grade *',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(12, (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text('Grade ${i + 1}'),
                  )),
                  validator: (value) => value == null ? 'Please select a grade' : null,
                  onChanged: (value) => setDialogState(() => selectedGrade = value),
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
                final name = nameController.text.trim();
                final useCase = ref.read(updateClassUseCaseProvider);
                final result = await useCase(
                  UpdateClassParams(
                    classId: classItem.id,
                    name: name,
                    grade: selectedGrade!,
                  ),
                );

                if (!context.mounted) return;

                result.fold(
                  (failure) {
                    showAppSnackBar(context, 'Error: ${failure.message}', type: SnackBarType.error);
                  },
                  (_) {
                    ref.invalidate(currentTeacherClassesProvider);
                    showAppSnackBar(context, 'Class updated', type: SnackBarType.success);
                  },
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteClass(BuildContext context, WidgetRef ref, TeacherClass classItem) async {
    final confirmed = await context.showConfirmDialog(
      title: 'Delete Class',
      message: 'Are you sure you want to delete "${classItem.name}"? This cannot be undone.',
      confirmText: 'Delete',
      isDestructive: true,
    );
    if (confirmed != true) return;

    final useCase = ref.read(deleteClassUseCaseProvider);
    final result = await useCase(DeleteClassParams(classId: classItem.id));

    if (!context.mounted) return;

    result.fold(
      (failure) {
        showAppSnackBar(context, 'Error: ${failure.message}', type: SnackBarType.error);
      },
      (_) {
        ref.invalidate(currentTeacherClassesProvider);
        showAppSnackBar(context, 'Class deleted', type: SnackBarType.success);
      },
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.classItem,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final TeacherClass classItem;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PlayfulCard(
      onTap: onTap,
      child: Row(
            children: [
              // Grade number avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    classItem.grade.toString(),
                    style: context.textTheme.headlineSmall?.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w800,
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.person,
                              size: 16,
                              color: AppColors.neutralText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${classItem.studentCount} students',
                              style: context.textTheme.bodySmall?.copyWith(
                                color: AppColors.neutralText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (classItem.academicYear != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: AppColors.neutralText,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                classItem.academicYear!,
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: AppColors.neutralText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Popup menu
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.neutralDark,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    enabled: classItem.studentCount == 0,
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outlined,
                        color: classItem.studentCount == 0 ? Colors.red : null,
                      ),
                      title: Text(
                        'Delete',
                        style: TextStyle(
                          color: classItem.studentCount == 0 ? Colors.red : null,
                        ),
                      ),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),

              const Icon(
                Icons.chevron_right,
                color: AppColors.neutralDark,
              ),
            ],
          ),
    );
  }
}
