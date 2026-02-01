import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/extensions/context_extensions.dart';
import '../../../domain/repositories/teacher_repository.dart';
import '../../../domain/usecases/teacher/change_student_class_usecase.dart';
import '../../../domain/usecases/teacher/reset_student_password_usecase.dart';
import '../../providers/repository_providers.dart';
import '../../providers/teacher_provider.dart';
import '../../providers/usecase_providers.dart';

class ClassDetailScreen extends ConsumerWidget {
  const ClassDetailScreen({
    super.key,
    required this.classId,
  });

  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(classStudentsProvider(classId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Students'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(classStudentsProvider(classId));
        },
        child: studentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: context.colorScheme.error),
                const SizedBox(height: 16),
                Text('Error loading students', style: context.textTheme.bodyLarge),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(classStudentsProvider(classId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (students) {
            if (students.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_off_outlined,
                      size: 64,
                      color: context.colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No students in this class',
                      style: context.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Students will appear here once enrolled',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // Stats summary
                _ClassStatsBar(students: students),

                // Student list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      return _StudentCard(
                        student: student,
                        classId: classId,
                        onTap: () {
                          // Navigate to student detail (nested under class)
                          context.push('/teacher/classes/$classId/student/${student.id}');
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
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
        : students.fold<double>(0, (sum, s) => sum + s.avgProgress) / students.length;

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

class _StudentCard extends ConsumerWidget {
  const _StudentCard({
    required this.student,
    required this.classId,
    required this.onTap,
  });

  final StudentSummary student;
  final String classId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: context.colorScheme.primaryContainer,
                backgroundImage: student.avatarUrl != null
                    ? NetworkImage(student.avatarUrl!)
                    : null,
                child: student.avatarUrl == null
                    ? Text(
                        student.firstName.isNotEmpty
                            ? student.firstName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: context.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Name and stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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

              // Level badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

              // Actions menu
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showActionsSheet(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActionsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (student.studentNumber != null)
                        Text(
                          'Student #: ${student.studentNumber}',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Email
            ListTile(
              leading: const Icon(Icons.email),
              title: Text(student.email ?? 'No email'),
              subtitle: student.email != null
                  ? const Text('Tap to copy')
                  : null,
              onTap: student.email != null
                  ? () {
                      Clipboard.setData(ClipboardData(text: student.email!));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Email copied to clipboard')),
                      );
                    }
                  : null,
            ),

            // Send Password Reset Email
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Send Password Reset Email'),
              subtitle: const Text('Sends link to student\'s email'),
              enabled: student.email != null,
              onTap: () {
                Navigator.pop(context);
                _sendPasswordResetEmail(context, ref);
              },
            ),

            // Generate New Password
            ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text('Generate New Password'),
              subtitle: const Text('Creates and shows new password'),
              onTap: () {
                Navigator.pop(context);
                _generateNewPassword(context, ref);
              },
            ),

            // Change Class
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Change Class'),
              subtitle: const Text('Move student to different class'),
              onTap: () {
                Navigator.pop(context);
                _showChangeClassDialog(context, ref);
              },
            ),

            // View Profile
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('View Full Profile'),
              onTap: () {
                Navigator.pop(context);
                onTap();
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _sendPasswordResetEmail(BuildContext context, WidgetRef ref) async {
    if (student.email == null) return;

    final repo = ref.read(teacherRepositoryProvider);
    final result = await repo.sendPasswordResetEmail(student.email!);

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
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to ${student.email}'),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
  }

  Future<void> _generateNewPassword(BuildContext context, WidgetRef ref) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Generating new password...'),
          ],
        ),
      ),
    );

    final useCase = ref.read(resetStudentPasswordUseCaseProvider);
    final result = await useCase(ResetStudentPasswordParams(studentId: student.id));

    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${failure.message}'),
            backgroundColor: context.colorScheme.error,
          ),
        );
      },
      (newPassword) {
        // Show new password dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('New Password Generated'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Student: ${student.fullName}'),
                const SizedBox(height: 16),
                const Text('New Password:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          newPassword,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: newPassword));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password copied')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Please share this password with the student.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.outline,
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showChangeClassDialog(BuildContext context, WidgetRef ref) async {
    // Get teacher's school ID from current user
    final teacherProfile = await ref.read(currentTeacherProfileProvider.future);
    if (teacherProfile == null) return;

    if (!context.mounted) return;

    final classesAsync = await ref.read(teacherClassesProvider(teacherProfile.schoolId).future);

    if (!context.mounted) return;

    String? selectedClassId;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Class'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Moving: ${student.fullName}'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Select New Class',
                  border: OutlineInputBorder(),
                ),
                value: selectedClassId,
                items: classesAsync
                    .where((c) => c.id != classId) // Exclude current class
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => selectedClassId = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedClassId == null
                  ? null
                  : () async {
                      Navigator.pop(dialogContext);
                      await _changeClass(context, ref, selectedClassId!);
                    },
              child: const Text('Move'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeClass(BuildContext context, WidgetRef ref, String newClassId) async {
    final useCase = ref.read(changeStudentClassUseCaseProvider);
    final result = await useCase(ChangeStudentClassParams(
      studentId: student.id,
      newClassId: newClassId,
    ));

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
      (_) {
        // Refresh the class students list
        ref.invalidate(classStudentsProvider(classId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${student.fullName} moved to new class'),
            backgroundColor: Colors.green,
          ),
        );
      },
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
