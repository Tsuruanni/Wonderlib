import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/text_styles.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/extensions/context_extensions.dart';
import '../../../../domain/repositories/teacher_repository.dart';
import '../../../providers/teacher_provider.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/playful_card.dart';
import '../../../widgets/common/asset_icon.dart';
import '../../../widgets/common/responsive_layout.dart';
import '../../../widgets/teacher/teacher_stats_bar.dart';
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
            final totalBooks = classes.fold<int>(0, (sum, c) => sum + c.completedBooks);
            final totalWordbank = classes.fold<int>(0, (sum, c) => sum + c.totalVocabWords);
            final topLevel = classes.fold<int>(
              0,
              (maxLv, c) => c.maxLevel > maxLv ? c.maxLevel : maxLv,
            );

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary stats — shared widget with Class Students.
                TeacherStatsBar(
                  activeCount: totalActive,
                  totalStudents: totalStudents,
                  topLevel: topLevel,
                  booksRead: totalBooks,
                  wordbankSize: totalWordbank,
                ),

                const SizedBox(height: 24),

                Text(
                  'Class Performance',
                  style: AppTextStyles.titleMedium(color: AppColors.black).copyWith(fontSize: 16, fontWeight: FontWeight.w800),
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
                    style: AppTextStyles.titleMedium(color: AppColors.secondary).copyWith(fontSize: 18, fontWeight: FontWeight.w800),
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
                      style: AppTextStyles.titleMedium().copyWith(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${classItem.studentCount} students',
                      style: AppTextStyles.caption(color: AppColors.neutralText),
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
              if (classItem.maxLevel > 0)
                _MetricChip(
                  assetPath: AppIcons.trophy,
                  label: 'Top Lv ${classItem.maxLevel}',
                  color: Colors.amber,
                ),
              if (classItem.completedBooks > 0)
                _MetricChip(
                  assetPath: AppIcons.book,
                  label: '${classItem.completedBooks} books read',
                  color: Colors.blue,
                ),
              if (classItem.totalVocabWords > 0)
                _MetricChip(
                  assetPath: AppIcons.vocabulary,
                  label: '${classItem.totalVocabWords} words in wordbank',
                  color: Colors.teal,
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
    this.icon,
    this.assetPath,
    required this.label,
    required this.color,
  });

  final IconData? icon;
  final String? assetPath;
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
          if (assetPath != null)
            AssetIcon(assetPath!, size: 14)
          else if (icon != null)
            Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption(color: color).copyWith(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}


