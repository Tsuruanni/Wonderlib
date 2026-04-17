import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/utils/app_clock.dart';
import '../../../domain/entities/student_assignment.dart';
import '../../providers/student_assignment_provider.dart';
import '../../utils/app_icons.dart';
import '../../widgets/common/app_progress_bar.dart';
import '../../widgets/common/top_navbar.dart';

class StudentAssignmentsScreen extends ConsumerWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(assignmentSyncProvider);
    final assignmentsAsync = ref.watch(studentAssignmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const TopNavbar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(studentAssignmentsProvider);
                },
                child: assignmentsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => _buildError(ref),
                  data: (assignments) {
                    if (assignments.isEmpty) return _buildEmpty();

                    final active = assignments
                        .where((a) =>
                            a.status == StudentAssignmentStatus.pending ||
                            a.status == StudentAssignmentStatus.inProgress)
                        .toList();
                    final overdue = assignments
                        .where((a) =>
                            a.status == StudentAssignmentStatus.overdue)
                        .toList();
                    final completed = assignments
                        .where((a) =>
                            a.status == StudentAssignmentStatus.completed)
                        .toList();

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Page title
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Text(
                            'My Assignments',
                            style: GoogleFonts.nunito(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.black,
                            ),
                          ),
                        ),

                        if (active.isNotEmpty) ...[
                          _SectionHeader(
                            title: 'To Do',
                            count: active.length,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(height: 8),
                          ...active.map((a) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _AssignmentCard(assignment: a),
                              )),
                          const SizedBox(height: 20),
                        ],

                        if (overdue.isNotEmpty) ...[
                          _SectionHeader(
                            title: 'Overdue',
                            count: overdue.length,
                            color: AppColors.danger,
                          ),
                          const SizedBox(height: 8),
                          ...overdue.map((a) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _AssignmentCard(assignment: a),
                              )),
                          const SizedBox(height: 20),
                        ],

                        if (completed.isNotEmpty) ...[
                          _SectionHeader(
                            title: 'Completed',
                            count: completed.length,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 8),
                          ...completed.map((a) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _AssignmentCard(assignment: a),
                              )),
                        ],
                        const SizedBox(height: 40),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined,
                size: 48, color: AppColors.neutralText.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No assignments yet',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.neutralText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your teacher will assign tasks here!',
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: AppColors.neutralText.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, color: AppColors.neutralText, size: 40),
          const SizedBox(height: 8),
          Text(
            'Could not load assignments',
            style: GoogleFonts.nunito(
              color: AppColors.neutralText,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => ref.invalidate(studentAssignmentsProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ─────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Assignment Card ────────────────────────────────

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.assignment});
  final StudentAssignment assignment;

  Color get _typeColor {
    return switch (assignment.type) {
      StudentAssignmentType.book => AppColors.gemBlue,
      StudentAssignmentType.vocabulary => AppColors.secondary,
      StudentAssignmentType.unit => AppColors.streakOrange,
    };
  }

  Widget _typeIconWidget({double size = 24}) {
    return switch (assignment.type) {
      StudentAssignmentType.book => AppIcons.book(size: size),
      StudentAssignmentType.vocabulary => AppIcons.vocabulary(size: size),
      StudentAssignmentType.unit => Icon(Icons.route_rounded, size: size),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = assignment.status == StudentAssignmentStatus.completed;
    final isOverdue = assignment.status == StudentAssignmentStatus.overdue;
    final progress = (assignment.progress / 100).clamp(0.0, 1.0);

    final daysLeft = assignment.dueDate.difference(AppClock.now()).inDays;
    final String dueText;
    if (isCompleted) {
      dueText = 'Completed';
    } else if (daysLeft < 0) {
      dueText = 'Overdue';
    } else if (daysLeft == 0) {
      dueText = 'Due today';
    } else if (daysLeft == 1) {
      dueText = '1 day left';
    } else {
      dueText = '$daysLeft days left';
    }

    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.studentAssignmentDetailPath(assignment.assignmentId),
      ),
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
            // Type icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : _typeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: isCompleted
                  ? Icon(Icons.check_rounded, size: 24, color: AppColors.primary)
                  : _typeIconWidget(size: 24),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assignment.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isCompleted
                          ? AppColors.neutralText
                          : AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Due text
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOverdue
                              ? AppColors.danger.withValues(alpha: 0.1)
                              : isCompleted
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : AppColors.neutral.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          dueText,
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isOverdue
                                ? AppColors.danger
                                : isCompleted
                                    ? AppColors.primary
                                    : AppColors.neutralText,
                          ),
                        ),
                      ),
                      if (assignment.teacherName != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.person_rounded,
                            size: 13, color: AppColors.neutralText),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            assignment.teacherName!,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.neutralText,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Progress bar
                  if (!isCompleted && progress > 0) ...[
                    const SizedBox(height: 8),
                    AppProgressBar(
                      progress: progress,
                      fillColor: _typeColor,
                      fillShadow: _typeColor.withValues(alpha: 0.6),
                      backgroundColor: AppColors.neutral,
                      height: 6,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Score or chevron
            if (isCompleted && assignment.score != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _scoreColor(assignment.score!)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${assignment.score!.toStringAsFixed(0)}%',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _scoreColor(assignment.score!),
                  ),
                ),
              )
            else
              AppIcons.arrowRight(size: 22),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 80) return AppColors.primary;
    if (score >= 60) return AppColors.streakOrange;
    return AppColors.danger;
  }
}
