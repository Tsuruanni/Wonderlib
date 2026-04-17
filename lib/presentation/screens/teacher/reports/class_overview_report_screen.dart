import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/extensions/context_extensions.dart';
import '../../../../domain/repositories/teacher_repository.dart';
import '../../../providers/teacher_provider.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/playful_card.dart';
import '../../../widgets/common/asset_icon.dart';
import '../../../widgets/common/responsive_layout.dart';
import '../class_detail_screen.dart';

class ClassOverviewReportScreen extends ConsumerWidget {
  const ClassOverviewReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(currentTeacherClassesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Overview'),
        centerTitle: false,
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
                  ],
                ),
              );
            }

            // Calculate totals
            final totalStudents = classes.fold<int>(0, (sum, c) => sum + c.studentCount);
            final totalActive = classes.fold<int>(0, (sum, c) => sum + c.activeLast30d);
            final totalReadingTime = classes.fold<int>(0, (sum, c) => sum + c.totalReadingTime);
            final totalBooks = classes.fold<int>(0, (sum, c) => sum + c.completedBooks);
            final topLevel = classes.fold<int>(
              0,
              (maxLv, c) => c.maxLevel > maxLv ? c.maxLevel : maxLv,
            );

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary stats — same shape as Class Students stats bar.
                PlayfulCard(
                  margin: EdgeInsets.zero,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      if (totalStudents > 0)
                        _SummaryStat(
                          value: '$totalActive/$totalStudents',
                          label: 'Active (30d)',
                          assetPath: AppIcons.fire,
                        ),
                      if (topLevel > 0)
                        _SummaryStat(
                          value: 'Lv $topLevel',
                          label: 'Top Level',
                          assetPath: AppIcons.trophy,
                        ),
                      if (totalBooks > 0)
                        _SummaryStat(
                          value: '$totalBooks',
                          label: 'Books Read',
                          assetPath: AppIcons.library,
                        ),
                      if (totalReadingTime > 0)
                        _SummaryStat(
                          value: TimeFormatter.formatReadingTime(totalReadingTime),
                          label: 'Reading Time',
                          assetPath: AppIcons.schedule,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Class Performance',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 12),

                // Enriched class cards
                ResponsiveWrap(
                  minItemWidth: 340,
                  children: classes
                      .map(
                        (classItem) => _EnrichedClassCard(
                          classItem: classItem,
                          onTap: () => context.push(
                            AppRoutes.teacherClassDetailPath(classItem.id),
                            extra: ClassDetailMode.report,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.value,
    required this.label,
    required this.assetPath,
  });

  final String value;
  final String label;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          assetPath,
          width: 32,
          height: 32,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.neutralText,
          ),
        ),
      ],
    );
  }
}

class _EnrichedClassCard extends StatelessWidget {
  const _EnrichedClassCard({
    required this.classItem,
    required this.onTap,
  });

  final TeacherClass classItem;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PlayfulCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: grade badge + name + progress
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    classItem.grade.toString(),
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classItem.name,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${classItem.studentCount} students',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: AppColors.neutralText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Stat chips row (0-value chips are hidden to reduce noise)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (classItem.avgXp >= 1)
                _MetricChip(
                  icon: Icons.star,
                  label: '${classItem.avgXp.toStringAsFixed(0)} avg XP',
                  color: Colors.amber,
                ),
              if (classItem.booksPerStudent >= 0.05)
                _MetricChip(
                  icon: Icons.menu_book,
                  label: '${classItem.booksPerStudent.toStringAsFixed(1)} books/student',
                  color: Colors.blue,
                ),
              if (classItem.totalReadingTime > 0)
                _MetricChip(
                  icon: Icons.access_time,
                  label: TimeFormatter.formatReadingTime(classItem.totalReadingTime),
                  color: Colors.purple,
                ),
              if (classItem.studentCount > 0)
                () {
                  // Red only when majority (>50%) of the class is inactive.
                  final inactiveRatio = classItem.inactiveLast30d / classItem.studentCount;
                  final isMostlyInactive = inactiveRatio > 0.5;
                  return _MetricChip(
                    icon: isMostlyInactive ? Icons.warning_amber : Icons.check_circle,
                    label: '${classItem.activeLast30d}/${classItem.studentCount} active (30d)',
                    color: isMostlyInactive ? Colors.red : Colors.green,
                  );
                }(),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}


