import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/utils/extensions/context_extensions.dart';
import '../../../domain/entities/student_unit_progress_item.dart';
import '../../../domain/repositories/teacher_repository.dart';
import '../../../domain/usecases/assignment/delete_assignment_usecase.dart';
import '../../providers/teacher_provider.dart';
import '../../providers/usecase_providers.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/common/error_state_widget.dart';
import '../../widgets/common/playful_card.dart';
import '../../widgets/common/responsive_layout.dart';
import '../../widgets/common/stat_item.dart';

class AssignmentDetailScreen extends ConsumerWidget {
  const AssignmentDetailScreen({
    super.key,
    required this.assignmentId,
  });

  final String assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentAsync = ref.watch(assignmentDetailProvider(assignmentId));
    final studentsAsync = ref.watch(assignmentStudentsProvider(assignmentId));

    return Scaffold(
      body: assignmentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ErrorStateWidget(
          message: 'Error loading assignment',
          onRetry: () {
            ref.invalidate(assignmentDetailProvider(assignmentId));
            ref.invalidate(assignmentStudentsProvider(assignmentId));
          },
        ),
        data: (assignment) {
          if (assignment == null) {
            return const Center(child: Text('Assignment not found'));
          }

          return CustomScrollView(
            slivers: [
              // App bar with assignment info
              _AssignmentAppBar(assignment: assignment),

              // Stats bar (full width)
              SliverToBoxAdapter(
                child: _StatsBar(assignment: assignment),
              ),

              // Unit content (if unit assignment)
              if (assignment.type == AssignmentType.unit && assignment.scopeLpUnitId != null)
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: _UnitContentSection(
                        classId: assignment.classId,
                        scopeLpUnitId: assignment.scopeLpUnitId!,
                      ),
                    ),
                  ),
                ),

              // Section header
              SliverToBoxAdapter(
                child: ResponsiveConstraint(
                  maxWidth: 900,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(
                          'Student Progress',
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            ref.invalidate(assignmentStudentsProvider(assignmentId));
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Student list
              studentsAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SliverToBoxAdapter(
                  child: Center(child: Text('Error loading students')),
                ),
                data: (students) {
                  if (students.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 48,
                              color: context.colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No students assigned',
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: context.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Sort: highest progress first, then alphabetically by name
                  final sorted = [...students]..sort((a, b) {
                    final progressCmp = b.progress.compareTo(a.progress);
                    if (progressCmp != 0) return progressCmp;
                    return a.studentName.toLowerCase().compareTo(
                      b.studentName.toLowerCase(),
                    );
                  });

                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ResponsiveWrap(
                        minItemWidth: 280,
                        children: sorted
                            .map(
                              (student) => _StudentProgressCard(
                                student: student,
                                assignment: assignment,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  );
                },
              ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 32),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AssignmentAppBar extends ConsumerWidget {
  const _AssignmentAppBar({required this.assignment});

  final Assignment assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('MMM d, y');

    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'delete') {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Assignment?'),
                  content: const Text(
                    'This will permanently delete the assignment and all student progress. This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(
                        foregroundColor: context.colorScheme.error,
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if ((confirmed ?? false) && context.mounted) {
                // Delete assignment
                final useCase = ref.read(deleteAssignmentUseCaseProvider);
                final result = await useCase(DeleteAssignmentParams(assignmentId: assignment.id));

                result.fold(
                  (failure) {
                    if (context.mounted) {
                      showAppSnackBar(context, 'Error: ${failure.message}', type: SnackBarType.error);
                    }
                  },
                  (_) {
                    if (context.mounted) {
                      ref.invalidate(teacherAssignmentsProvider);
                      ref.invalidate(teacherStatsProvider);
                      showAppSnackBar(context, 'Assignment deleted');
                      context.pop();
                    }
                  },
                );
              }
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AssignmentColors.getTypeColor(assignment.type),
                AssignmentColors.getTypeColor(assignment.type).withValues(alpha: 0.7),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Align(
              alignment: AlignmentDirectional.bottomStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AssignmentColors.getTypeIcon(assignment.type),
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          assignment.type.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    assignment.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (assignment.className != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      assignment.className!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Due date
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Due: ${dateFormat.format(assignment.dueDate)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                      if (assignment.isOverdue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'OVERDUE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
            ),
          ),
        ),
      ),
    );
  }

}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.assignment});

  final Assignment assignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: context.colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          StatItem(
            value: '${assignment.totalStudents}',
            label: 'Students',
            icon: Icons.people,
            color: Colors.blue,
          ),
          StatItem(
            value: '${assignment.completedStudents}',
            label: 'Completed',
            icon: Icons.check_circle,
            color: Colors.green,
          ),
          StatItem(
            value: '${assignment.completionRate.toStringAsFixed(0)}%',
            label: 'Progress',
            icon: Icons.trending_up,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }
}

class _StudentProgressCard extends StatelessWidget {
  const _StudentProgressCard({
    required this.student,
    required this.assignment,
  });

  final AssignmentStudent student;
  final Assignment assignment;

  @override
  Widget build(BuildContext context) {
    return PlayfulCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      onTap: assignment.type == AssignmentType.unit
          ? () => _showStudentDetail(context)
          : null,
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: context.colorScheme.primaryContainer,
            backgroundImage: student.avatarUrl != null
                ? NetworkImage(student.avatarUrl!)
                : null,
            child: student.avatarUrl == null
                ? Text(
                    student.studentName.isNotEmpty
                        ? student.studentName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: context.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Name and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.studentName,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      AssignmentColors.getStatusIcon(student.status),
                      size: 14,
                      color: AssignmentColors.getStatusColor(student.status),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      student.status.displayName,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: AssignmentColors.getStatusColor(student.status),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Progress
          SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: student.progress / 100,
                  strokeWidth: 4,
                  backgroundColor: context.colorScheme.surfaceContainerHighest,
                  color: AssignmentColors.getStatusColor(student.status),
                ),
                Text(
                  '${student.progress.toStringAsFixed(0)}%',
                  style: context.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Score (if completed)
          if (student.score != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ScoreColors.getScoreColor(student.score!).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${student.score!.toStringAsFixed(0)}%',
                style: context.textTheme.labelMedium?.copyWith(
                  color: ScoreColors.getScoreColor(student.score!),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showStudentDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => _StudentUnitDetailSheet(
          scrollController: scrollController,
          student: student,
          assignmentId: assignment.id,
        ),
      ),
    );
  }
}

class _StudentUnitDetailSheet extends ConsumerWidget {
  const _StudentUnitDetailSheet({
    required this.scrollController,
    required this.student,
    required this.assignmentId,
  });

  final ScrollController scrollController;
  final AssignmentStudent student;
  final String assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(
      studentUnitProgressProvider((
        assignmentId: assignmentId,
        studentId: student.studentId,
      ),),
    );

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: context.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: context.colorScheme.primaryContainer,
                backgroundImage: student.avatarUrl != null
                    ? NetworkImage(student.avatarUrl!)
                    : null,
                child: student.avatarUrl == null
                    ? Text(
                        student.studentName.isNotEmpty
                            ? student.studentName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: context.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.studentName,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${student.progress.toStringAsFixed(0)}% completed',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: AssignmentColors.getStatusColor(student.status),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                AssignmentColors.getStatusIcon(student.status),
                color: AssignmentColors.getStatusColor(student.status),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: progressAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (items) => ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _StudentUnitItemCard(item: items[index]);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _StudentUnitItemCard extends StatelessWidget {
  const _StudentUnitItemCard({required this.item});

  final StudentUnitProgressItem item;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String title;
    final Color color;
    final List<Widget> details = [];

    switch (item.itemType) {
      case LearningPathItemType.wordList:
        icon = Icons.abc;
        title = item.wordListName ?? 'Word List';
        color = Colors.purple;

        if (item.totalSessions != null && item.totalSessions! > 0) {
          details.add(_DetailRow(
            label: 'Sessions',
            value: item.totalSessions.toString(),
          ),);
          if (item.bestAccuracy != null) {
            details.add(_DetailRow(
              label: 'Best Accuracy',
              value: '${item.bestAccuracy!.toStringAsFixed(0)}%',
              valueColor: ScoreColors.getScoreColor(item.bestAccuracy!),
            ),);
          }
          if (item.bestScore != null) {
            details.add(_DetailRow(
              label: 'Best Score',
              value: item.bestScore!.toStringAsFixed(0),
            ),);
          }
        } else {
          details.add(Text(
            item.isWordListCompleted ?? false
                ? 'Completed (no session data)'
                : 'Not started yet',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.outline,
            ),
          ),);
        }

        if (item.wordCount != null) {
          details.insert(0, _DetailRow(
            label: 'Words',
            value: item.wordCount.toString(),
          ),);
        }

      case LearningPathItemType.book:
        icon = Icons.menu_book;
        title = item.bookTitle ?? 'Book';
        color = Colors.blue;
        final totalChapters = item.totalChapters ?? 0;
        final completedChapters = item.completedChapters ?? 0;

        details.add(_DetailRow(
          label: 'Chapters',
          value: '$completedChapters / $totalChapters',
          valueColor: item.isBookCompleted ?? false ? Colors.green : null,
        ),);

      case LearningPathItemType.game:
        icon = Icons.sports_esports;
        title = 'Game';
        color = Colors.grey;
        details.add(Text(
          'Not graded',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.outline,
          ),
        ),);

      case LearningPathItemType.treasure:
        icon = Icons.card_giftcard;
        title = 'Treasure';
        color = Colors.grey;
        details.add(Text(
          'Not graded',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.outline,
          ),
        ),);
    }

    return PlayfulCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (item.isTracked ? color : Colors.grey).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: item.isTracked ? color : Colors.grey, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: item.isTracked ? null : context.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 4),
                ...details,
              ],
            ),
          ),
          if (item.isTracked)
            Icon(
              item.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
              color: item.isCompleted ? Colors.green : context.colorScheme.outline,
              size: 20,
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.outline,
            ),
          ),
          Text(
            value,
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitContentSection extends ConsumerWidget {
  const _UnitContentSection({
    required this.classId,
    required this.scopeLpUnitId,
  });

  final String? classId;
  final String scopeLpUnitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (classId == null) return const SizedBox.shrink();

    final unitsAsync = ref.watch(classLearningPathUnitsProvider(classId!));

    return unitsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (units) {
        final unit = units.where((u) => u.scopeLpUnitId == scopeLpUnitId).firstOrNull;
        if (unit == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unit Content',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              PlayfulCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(12),
                child: Column(
                    children: unit.items.map((item) {
                      final IconData icon;
                      final String label;
                      final String detail;
                      final bool isTracked;

                      switch (item.itemType) {
                        case LearningPathItemType.wordList:
                          icon = Icons.abc;
                          label = item.wordListName ?? 'Word List';
                          detail = '${item.words?.length ?? 0} words';
                          isTracked = true;
                        case LearningPathItemType.book:
                          icon = Icons.menu_book;
                          label = item.bookTitle ?? 'Book';
                          detail = '${item.bookChapterCount ?? 0} chapters';
                          isTracked = true;
                        case LearningPathItemType.game:
                          icon = Icons.sports_esports;
                          label = 'Game';
                          detail = 'Not graded';
                          isTracked = false;
                        case LearningPathItemType.treasure:
                          icon = Icons.card_giftcard;
                          label = 'Treasure';
                          detail = 'Not graded';
                          isTracked = false;
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            dense: true,
                            leading: Icon(icon, size: 20, color: isTracked ? null : context.colorScheme.outline),
                            title: Text(
                              label,
                              style: TextStyle(
                                color: isTracked ? null : context.colorScheme.outline,
                              ),
                            ),
                            trailing: Text(
                                    detail,
                                    style: context.textTheme.bodySmall?.copyWith(
                                      color: context.colorScheme.outline,
                                    ),
                                  ),
                          ),
                          if (item.itemType == LearningPathItemType.wordList && item.words != null && item.words!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: item.words!.map((word) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: context.colorScheme.primaryContainer.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    word,
                                    style: context.textTheme.labelSmall?.copyWith(
                                      color: context.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),).toList(),
                              ),
                            ),
                        ],
                      );
                    }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
