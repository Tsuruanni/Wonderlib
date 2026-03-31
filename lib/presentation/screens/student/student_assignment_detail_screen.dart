import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/utils/app_clock.dart';
import '../../../domain/entities/student_assignment.dart';
import '../../../domain/entities/unit_assignment_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_assignment_provider.dart'
    show
        studentAssignmentControllerProvider,
        studentAssignmentDetailProvider,
        unitAssignmentItemsProvider;
import '../../utils/ui_helpers.dart';
import '../../widgets/common/top_navbar.dart';

class StudentAssignmentDetailScreen extends ConsumerWidget {
  const StudentAssignmentDetailScreen({
    super.key,
    required this.assignmentId,
  });

  final String assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentAsync =
        ref.watch(studentAssignmentDetailProvider(assignmentId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const TopNavbar(),
            Expanded(
              child: assignmentAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off,
                          color: AppColors.neutralText, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        'Could not load assignment',
                        style: GoogleFonts.nunito(
                          color: AppColors.neutralText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(
                            studentAssignmentDetailProvider(assignmentId)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (assignment) {
                  if (assignment == null) {
                    return Center(
                      child: Text(
                        'Assignment not found',
                        style: GoogleFonts.nunito(
                          color: AppColors.neutralText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }
                  return _DetailContent(assignment: assignment);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Detail Content ─────────────────────────────────

class _DetailContent extends ConsumerWidget {
  const _DetailContent({required this.assignment});
  final StudentAssignment assignment;

  Color get _typeColor {
    return switch (assignment.type) {
      StudentAssignmentType.book => AppColors.gemBlue,
      StudentAssignmentType.vocabulary => AppColors.secondary,
      StudentAssignmentType.unit => AppColors.streakOrange,
    };
  }

  IconData get _typeIcon {
    return switch (assignment.type) {
      StudentAssignmentType.book => Icons.auto_stories_rounded,
      StudentAssignmentType.vocabulary => Icons.abc_rounded,
      StudentAssignmentType.unit => Icons.route_rounded,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompleted = assignment.status == StudentAssignmentStatus.completed;
    final isOverdue = assignment.status == StudentAssignmentStatus.overdue;
    final progress = (assignment.progress / 100).clamp(0.0, 1.0);
    final daysLeft = assignment.dueDate.difference(AppClock.now()).inDays;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back + breadcrumb
              GestureDetector(
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    context.go(AppRoutes.studentAssignments);
                  }
                },
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back_rounded,
                        size: 20, color: AppColors.neutralText),
                    const SizedBox(width: 6),
                    Text(
                      'Back to Assignments',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutralText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ─── Header Card ──────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _typeColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _typeColor.withValues(alpha: 0.4),
                      offset: const Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_typeIcon, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            assignment.type.displayName,
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Title
                    Text(
                      assignment.title,
                      style: GoogleFonts.nunito(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    if (assignment.teacherName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'From ${assignment.teacherName}',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── Status + Progress Row ────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.neutral, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.neutral,
                      offset: Offset(0, 3),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Status pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_statusIcon,
                                  size: 14, color: _statusColor),
                              const SizedBox(width: 4),
                              Text(
                                assignment.status.displayName,
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Progress percentage
                        Text(
                          '${assignment.progress.toStringAsFixed(0)}%',
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.neutral,
                        color: isCompleted ? AppColors.primary : _typeColor,
                        minHeight: 10,
                      ),
                    ),
                    // Score row
                    if (isCompleted && assignment.score != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Score',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.neutralText,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _scoreColor(assignment.score!)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${assignment.score!.toStringAsFixed(0)}%',
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: _scoreColor(assignment.score!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── Due Date + Info Row ──────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.neutral, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.neutral,
                      offset: Offset(0, 3),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 20,
                      color: isOverdue
                          ? AppColors.danger
                          : AppColors.neutralText,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Due Date',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.neutralText,
                            ),
                          ),
                          Text(
                            DateFormat('EEEE, MMMM d, y')
                                .format(assignment.dueDate),
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isOverdue
                                  ? AppColors.danger
                                  : AppColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOverdue
                              ? AppColors.danger.withValues(alpha: 0.1)
                              : AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isOverdue
                              ? 'Overdue'
                              : daysLeft == 0
                                  ? 'Due today'
                                  : '$daysLeft days left',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isOverdue
                                ? AppColors.danger
                                : AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ─── Description ──────────────────────
              if (assignment.description != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.neutral, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.neutral,
                        offset: Offset(0, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instructions',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        assignment.description!,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: AppColors.neutralText,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ─── What to Do ───────────────────────
              const SizedBox(height: 20),
              Text(
                'What to Do',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 12),

              if (assignment.type == StudentAssignmentType.book)
                _ActionCard(
                  icon: Icons.auto_stories_rounded,
                  title: 'Read assigned book',
                  subtitle: 'Complete all chapters',
                  color: AppColors.gemBlue,
                  onTap: assignment.bookId != null
                      ? () => _startContent(context, ref,
                          bookId: assignment.bookId)
                      : null,
                ),

              if (assignment.type == StudentAssignmentType.vocabulary)
                _ActionCard(
                  icon: Icons.abc_rounded,
                  title: 'Complete vocabulary practice',
                  subtitle: 'Learn and review words',
                  color: AppColors.secondary,
                  onTap: assignment.wordListId != null
                      ? () => _startContent(context, ref,
                          wordListId: assignment.wordListId)
                      : null,
                ),

              if (assignment.type == StudentAssignmentType.unit)
                _UnitItemsList(assignment: assignment),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Color get _statusColor {
    return switch (assignment.status) {
      StudentAssignmentStatus.pending => AppColors.neutralText,
      StudentAssignmentStatus.inProgress => AppColors.secondary,
      StudentAssignmentStatus.completed => AppColors.primary,
      StudentAssignmentStatus.overdue => AppColors.danger,
      StudentAssignmentStatus.withdrawn => AppColors.neutralText,
    };
  }

  IconData get _statusIcon {
    return switch (assignment.status) {
      StudentAssignmentStatus.pending => Icons.schedule_rounded,
      StudentAssignmentStatus.inProgress => Icons.play_arrow_rounded,
      StudentAssignmentStatus.completed => Icons.check_circle_rounded,
      StudentAssignmentStatus.overdue => Icons.warning_rounded,
      StudentAssignmentStatus.withdrawn => Icons.block_rounded,
    };
  }

  Color _scoreColor(double score) {
    if (score >= 80) return AppColors.primary;
    if (score >= 60) return AppColors.streakOrange;
    return AppColors.danger;
  }

  void _startContent(
    BuildContext context,
    WidgetRef ref, {
    String? bookId,
    String? wordListId,
  }) async {
    if (assignment.status == StudentAssignmentStatus.pending) {
      await ref
          .read(studentAssignmentControllerProvider.notifier)
          .startAssignment(assignment.assignmentId);
    }

    if (!context.mounted) return;

    if (bookId != null) {
      context.go(AppRoutes.bookDetailPath(bookId));
    } else if (wordListId != null) {
      context.go(AppRoutes.vocabularyListPath(wordListId));
    }
  }
}

// ─── Action Card ────────────────────────────────────

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neutral, width: 2),
          boxShadow: const [
            BoxShadow(
              color: AppColors.neutral,
              offset: Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: AppColors.neutralText,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.neutralText, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─── Unit Items List ────────────────────────────────

class _UnitItemsList extends ConsumerWidget {
  const _UnitItemsList({required this.assignment});
  final StudentAssignment assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null || assignment.scopeLpUnitId == null) {
      return const SizedBox.shrink();
    }

    final itemsAsync = ref.watch(
      unitAssignmentItemsProvider(
        (scopeLpUnitId: assignment.scopeLpUnitId!, studentId: userId),
      ),
    );

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Text(
        'Error loading unit items',
        style: GoogleFonts.nunito(color: AppColors.neutralText),
      ),
      data: (items) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.neutral, width: 2),
            boxShadow: const [
              BoxShadow(
                color: AppColors.neutral,
                offset: Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.neutral.withValues(alpha: 0.6),
                    ),
                  _UnitItemRow(
                    item: items[i],
                    assignment: assignment,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UnitItemRow extends ConsumerWidget {
  const _UnitItemRow({required this.item, required this.assignment});
  final UnitAssignmentItem item;
  final StudentAssignment assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = LearningPathItemDisplay.getIcon(item.itemType);
    final color = LearningPathItemDisplay.getColor(item.itemType);
    final bool isTracked = item.isTracked;
    final bool isCompleted = item.isCompleted;

    final String title;
    final String subtitle;
    VoidCallback? onTap;

    switch (item.itemType) {
      case LearningPathItemType.wordList:
        title = item.wordListName ?? 'Word List';
        subtitle = '${item.wordCount ?? 0} words';
        if (item.wordListId != null) {
          onTap = () => _start(context, ref, wordListId: item.wordListId);
        }
      case LearningPathItemType.book:
        title = item.bookTitle ?? 'Book';
        subtitle =
            '${item.completedChapters ?? 0}/${item.totalChapters ?? 0} chapters';
        if (item.bookId != null) {
          onTap = () => _start(context, ref, bookId: item.bookId);
        }
      case LearningPathItemType.game:
        title = 'Game';
        subtitle = 'Not graded';
      case LearningPathItemType.treasure:
        title = 'Treasure';
        subtitle = 'Not graded';
    }

    return GestureDetector(
      onTap: isTracked ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (isTracked ? color : AppColors.neutral)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isTracked ? color : AppColors.neutralText,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isTracked
                          ? AppColors.black
                          : AppColors.neutralText,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: AppColors.neutralText,
                    ),
                  ),
                ],
              ),
            ),
            if (isTracked)
              Icon(
                isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: isCompleted ? AppColors.primary : color,
                size: 22,
              )
            else
              Text(
                'not graded',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutralText,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _start(
    BuildContext context,
    WidgetRef ref, {
    String? wordListId,
    String? bookId,
  }) async {
    if (assignment.status == StudentAssignmentStatus.pending) {
      await ref
          .read(studentAssignmentControllerProvider.notifier)
          .startAssignment(assignment.assignmentId);
    }

    if (!context.mounted) return;

    if (wordListId != null) {
      context.go(AppRoutes.vocabularyListPath(wordListId));
    } else if (bookId != null) {
      context.go(AppRoutes.bookDetailPath(bookId));
    }
  }
}
