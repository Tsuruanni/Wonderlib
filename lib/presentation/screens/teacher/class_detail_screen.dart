import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/utils/extensions/context_extensions.dart';
import '../../../domain/repositories/teacher_repository.dart';
import '../../../domain/usecases/teacher/bulk_move_students_usecase.dart';
import '../../providers/teacher_provider.dart';
import '../../providers/usecase_providers.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/error_state_widget.dart';

enum ClassDetailMode { management, report }

class ClassDetailScreen extends ConsumerStatefulWidget {
  const ClassDetailScreen({
    super.key,
    required this.classId,
    this.mode = ClassDetailMode.management,
  });

  final String classId;
  final ClassDetailMode mode;

  @override
  ConsumerState<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends ConsumerState<ClassDetailScreen> {
  bool _isSelectMode = false;
  final Set<String> _selectedStudentIds = {};

  void _toggleSelectMode() {
    setState(() {
      _isSelectMode = !_isSelectMode;
      if (!_isSelectMode) _selectedStudentIds.clear();
    });
  }

  void _toggleStudentSelection(String studentId) {
    setState(() {
      if (_selectedStudentIds.contains(studentId)) {
        _selectedStudentIds.remove(studentId);
      } else {
        _selectedStudentIds.add(studentId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(classStudentsProvider(widget.classId));
    final isManagement = widget.mode == ClassDetailMode.management;

    return Scaffold(
      appBar: AppBar(
        title: Text(isManagement ? 'Class Management' : 'Class Students'),
        actions: [
          if (isManagement)
            _isSelectMode
                ? TextButton.icon(
                    onPressed: _toggleSelectMode,
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  )
                : TextButton.icon(
                    onPressed: _toggleSelectMode,
                    icon: const Icon(Icons.checklist),
                    label: const Text('Select'),
                  ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(classStudentsProvider(widget.classId));
        },
        child: studentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ErrorStateWidget(
            message: 'Error loading students',
            onRetry: () => ref.invalidate(classStudentsProvider(widget.classId)),
          ),
          data: (students) {
            if (students.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.person_off_outlined,
                title: 'No students in this class',
                subtitle: 'Students will appear here once enrolled',
              );
            }

            return Stack(
              children: [
                Column(
                  children: [
                    // Stats bar only in report mode
                    if (!isManagement) _ClassStatsBar(students: students),

                    // Student list
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          _isSelectMode ? 80 : 16,
                        ),
                        itemCount: students.length,
                        itemBuilder: (context, index) {
                          final student = students[index];
                          if (isManagement) {
                            return _ManagementStudentCard(
                              student: student,
                              isSelectMode: _isSelectMode,
                              isSelected:
                                  _selectedStudentIds.contains(student.id),
                              onToggleSelect: () =>
                                  _toggleStudentSelection(student.id),
                              onTap: () =>
                                  _showStudentInfoSheet(context, student),
                            );
                          } else {
                            return _ReportStudentCard(
                              student: student,
                              classId: widget.classId,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),

                // Floating move bar (select mode only)
                if (_isSelectMode && _selectedStudentIds.isNotEmpty)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _MoveBar(
                      selectedCount: _selectedStudentIds.length,
                      onMoveTo: () => _showMoveToSheet(context),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showStudentInfoSheet(BuildContext context, StudentSummary student) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: context.colorScheme.primaryContainer,
                    child: Text(
                      student.firstName.isNotEmpty
                          ? student.firstName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: context.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.fullName,
                          style: context.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (student.studentNumber != null)
                          Text(
                            'Student #: ${student.studentNumber}',
                            style: context.textTheme.bodySmall
                                ?.copyWith(color: context.colorScheme.outline),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Lv ${student.level}',
                      style: context.textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              // Email
              if (student.email != null)
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email'),
                  subtitle: Text(student.email!),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: student.email!));
                      Navigator.pop(context);
                      showAppSnackBar(this.context, 'Email copied');
                    },
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              // Password
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Password'),
                subtitle: Text(
                  student.passwordPlain ?? 'Not available',
                  style: student.passwordPlain == null
                      ? TextStyle(color: this.context.colorScheme.outline, fontStyle: FontStyle.italic)
                      : null,
                ),
                trailing: student.passwordPlain != null
                    ? IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: student.passwordPlain!),
                          );
                          Navigator.pop(context);
                          showAppSnackBar(this.context, 'Password copied');
                        },
                      )
                    : null,
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(),
              // Move to class
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Move to Another Class'),
                trailing: const Icon(Icons.chevron_right, size: 18),
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.pop(context);
                  _showSingleStudentMoveSheet(this.context, student);
                },
              ),
              // View Profile
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('View Full Profile'),
                trailing: const Icon(Icons.chevron_right, size: 18),
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.pop(context);
                  this.context.push(
                    AppRoutes.teacherStudentDetailPath(
                      widget.classId,
                      student.id,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showSingleStudentMoveSheet(BuildContext context, StudentSummary student) {
    final classesAsync = ref.read(currentTeacherClassesProvider);

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Move ${student.fullName} to...',
                style: context.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            ...classesAsync.when(
              loading: () => [
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ],
              error: (_, __) => [
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Error loading classes'),
                  ),
                ),
              ],
              data: (classes) => classes
                  .where((c) => c.id != widget.classId)
                  .map(
                    (targetClass) => ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        child: Text(
                          '${targetClass.grade ?? ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      title: Text(targetClass.name),
                      subtitle: Text('${targetClass.studentCount} students'),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final useCase = ref.read(bulkMoveStudentsUseCaseProvider);
                        final result = await useCase(
                          BulkMoveStudentsParams(
                            studentIds: [student.id],
                            targetClassId: targetClass.id,
                          ),
                        );

                        if (!context.mounted) return;

                        result.fold(
                          (failure) {
                            showAppSnackBar(context, 'Error: ${failure.message}', type: SnackBarType.error);
                          },
                          (_) {
                            showAppSnackBar(context, '${student.fullName} moved to ${targetClass.name}', type: SnackBarType.success);
                            ref.invalidate(classStudentsProvider(widget.classId));
                            ref.invalidate(currentTeacherClassesProvider);
                          },
                        );
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showMoveToSheet(BuildContext context) {
    final classesAsync = ref.read(currentTeacherClassesProvider);

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Move ${_selectedStudentIds.length} students to...',
                style: context.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            ...classesAsync.when(
              loading: () => [
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ],
              error: (_, __) => [
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Error loading classes'),
                  ),
                ),
              ],
              data: (classes) => classes
                  .where((c) => c.id != widget.classId)
                  .map(
                    (targetClass) => ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        child: Text(
                          '${targetClass.grade ?? ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      title: Text(targetClass.name),
                      subtitle: Text('${targetClass.studentCount} students'),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await _bulkMoveStudents(
                          this.context,
                          targetClass.id,
                          targetClass.name,
                        );
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _bulkMoveStudents(
    BuildContext context,
    String targetClassId,
    String targetClassName,
  ) async {
    final useCase = ref.read(bulkMoveStudentsUseCaseProvider);
    final result = await useCase(
      BulkMoveStudentsParams(
        studentIds: _selectedStudentIds.toList(),
        targetClassId: targetClassId,
      ),
    );

    if (!context.mounted) return;

    result.fold(
      (failure) {
        showAppSnackBar(
          context,
          'Error: ${failure.message}',
          type: SnackBarType.error,
        );
      },
      (_) {
        showAppSnackBar(
          context,
          '${_selectedStudentIds.length} students moved to $targetClassName',
          type: SnackBarType.success,
        );
        setState(() {
          _isSelectMode = false;
          _selectedStudentIds.clear();
        });
        ref.invalidate(classStudentsProvider(widget.classId));
        ref.invalidate(currentTeacherClassesProvider);
      },
    );
  }
}

// =============================================
// PRIVATE WIDGETS
// =============================================

class _ManagementStudentCard extends StatelessWidget {
  const _ManagementStudentCard({
    required this.student,
    required this.isSelectMode,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onTap,
  });

  final StudentSummary student;
  final bool isSelectMode;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: isSelectMode ? onToggleSelect : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (isSelectMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onToggleSelect(),
                ),
              if (!isSelectMode)
                CircleAvatar(
                  radius: 20,
                  backgroundColor: context.colorScheme.primaryContainer,
                  child: Text(
                    student.firstName.isNotEmpty
                        ? student.firstName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: context.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: context.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (student.studentNumber != null)
                      Text(
                        'Student #: ${student.studentNumber}',
                        style: context.textTheme.bodySmall
                            ?.copyWith(color: context.colorScheme.outline),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Lv ${student.level}',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportStudentCard extends StatelessWidget {
  const _ReportStudentCard({required this.student, required this.classId});

  final StudentSummary student;
  final String classId;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () =>
            context.push(AppRoutes.teacherStudentDetailPath(classId, student.id)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: context.colorScheme.primaryContainer,
                child: Text(
                  student.firstName.isNotEmpty
                      ? student.firstName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: context.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: context.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _MiniStat(
                          icon: Icons.star,
                          value: '${student.xp}',
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 12),
                        _MiniStat(
                          icon: Icons.local_fire_department,
                          value: '${student.currentStreak}',
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        _MiniStat(
                          icon: Icons.book,
                          value: '${student.booksRead}',
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: context.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Lv ${student.level}',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoveBar extends StatelessWidget {
  const _MoveBar({required this.selectedCount, required this.onMoveTo});

  final int selectedCount;
  final VoidCallback onMoveTo;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: context.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(
              '$selectedCount selected',
              style: context.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: onMoveTo,
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('Move to...'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassStatsBar extends StatelessWidget {
  const _ClassStatsBar({required this.students});

  final List<StudentSummary> students;

  @override
  Widget build(BuildContext context) {
    final totalXP = students.fold<int>(0, (sum, s) => sum + s.xp);
    final avgProgress = students.isEmpty
        ? 0.0
        : students.fold<double>(0, (sum, s) => sum + s.avgProgress) /
            students.length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: context.colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.people,
            value: '${students.length}',
            label: 'Students',
          ),
          _StatItem(
            icon: Icons.star,
            value: '$totalXP',
            label: 'Total XP',
          ),
          _StatItem(
            icon: Icons.trending_up,
            value: '${avgProgress.toStringAsFixed(0)}%',
            label: 'Avg Progress',
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: context.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text(
          value,
          style: context.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
