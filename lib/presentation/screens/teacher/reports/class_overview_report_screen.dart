import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/extensions/context_extensions.dart';
import '../../../../domain/repositories/teacher_repository.dart';
import '../../../providers/teacher_provider.dart';
import '../../../utils/class_ranking_metric.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/playful_card.dart';
import '../../../widgets/common/responsive_layout.dart';
import '../class_detail_screen.dart';

class ClassOverviewReportScreen extends ConsumerStatefulWidget {
  const ClassOverviewReportScreen({super.key});

  @override
  ConsumerState<ClassOverviewReportScreen> createState() =>
      _ClassOverviewReportScreenState();
}

class _ClassOverviewReportScreenState
    extends ConsumerState<ClassOverviewReportScreen> {
  ClassRankingMetric _selectedMetric = ClassRankingMetric.avgXp;

  @override
  Widget build(BuildContext context) {
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
            final highestStreak = classes.fold<double>(0, (max, c) => c.avgStreak > max ? c.avgStreak : max);
            final avgXp = totalStudents > 0
                ? classes.fold<double>(0, (sum, c) => sum + c.avgXp * c.studentCount) / totalStudents
                : 0.0;

            final sortedClasses = [...classes]
              ..sort((a, b) {
                final aVal = _selectedMetric.selector(a);
                final bVal = _selectedMetric.selector(b);
                return bVal.compareTo(aVal); // descending — best first
              });

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // My School summary with global benchmark
                const ResponsiveConstraint(
                  maxWidth: 900,
                  child: _SchoolSummaryCard(),
                ),

                // Summary stats (0-value stats hidden to reduce noise)
                ResponsiveConstraint(
                  maxWidth: 900,
                  child: PlayfulCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        if (totalStudents > 0)
                          _SummaryStat(value: '$totalActive/$totalStudents', label: 'Active (30d)', icon: Icons.people, color: Colors.green),
                        if (avgXp >= 1)
                          _SummaryStat(value: avgXp.toStringAsFixed(0), label: 'Avg XP', icon: Icons.star, color: Colors.amber),
                        if (totalReadingTime > 0)
                          _SummaryStat(value: TimeFormatter.formatReadingTime(totalReadingTime), label: 'Total Reading', icon: Icons.access_time, color: Colors.blue),
                        if (highestStreak >= 0.05)
                          _SummaryStat(value: highestStreak.toStringAsFixed(1), label: 'Highest Streak', icon: Icons.local_fire_department, color: Colors.orange),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Class Performance',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.black,
                      ),
                    ),
                    DropdownButton<ClassRankingMetric>(
                      value: _selectedMetric,
                      underline: const SizedBox.shrink(),
                      items: ClassRankingMetric.values.map((m) {
                        return DropdownMenuItem(
                          value: m,
                          child: Text(
                            'Sort: ${m.label}',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (m) {
                        if (m != null) {
                          setState(() => _selectedMetric = m);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Enriched class cards
                ResponsiveWrap(
                  minItemWidth: 340,
                  children: sortedClasses.indexed
                      .map(
                        (entry) {
                          final (index, classItem) = entry;
                          return _EnrichedClassCard(
                            classItem: classItem,
                            rank: sortedClasses.length >= 3 ? index + 1 : null,
                            onTap: () => context.push(
                              AppRoutes.teacherClassDetailPath(classItem.id),
                              extra: ClassDetailMode.report,
                            ),
                          );
                        },
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
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
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
    this.rank,
  });

  final TeacherClass classItem;
  final VoidCallback onTap;
  final int? rank;

  Color? _podiumColor() {
    return switch (rank) {
      1 => const Color(0xFFFFD700), // gold
      2 => const Color(0xFFC0C0C0), // silver
      3 => const Color(0xFFCD7F32), // bronze
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final podiumColor = _podiumColor();
    final card = PlayfulCard(
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
    if (podiumColor == null) return card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          top: -6,
          left: -6,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: podiumColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ],
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

class _SchoolSummaryCard extends ConsumerWidget {
  const _SchoolSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(schoolSummaryProvider);
    final globalAsync = ref.watch(globalAveragesProvider);

    return summaryAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) {
        if (summary == null) return const SizedBox.shrink();
        final global = globalAsync.valueOrNull;
        return PlayfulCard(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.school_rounded, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Text(
                    'My School',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (summary.avgXp >= 1)
                _SummaryRow(
                  label: 'Avg XP',
                  mine: summary.avgXp.toStringAsFixed(0),
                  benchmark: global?.avgXp.toStringAsFixed(0),
                  mineVal: summary.avgXp,
                  benchmarkVal: global?.avgXp,
                ),
              if (summary.avgStreak >= 0.05)
                _SummaryRow(
                  label: 'Avg Streak',
                  mine: summary.avgStreak.toStringAsFixed(1),
                  benchmark: global?.avgStreak.toStringAsFixed(1),
                  mineVal: summary.avgStreak,
                  benchmarkVal: global?.avgStreak,
                ),
              if (summary.totalStudents > 0 && summary.totalBooksRead > 0)
                _SummaryRow(
                  label: 'Books Read / Student',
                  mine: (summary.totalBooksRead / summary.totalStudents)
                      .toStringAsFixed(1),
                  benchmark: global?.avgBooksRead.toStringAsFixed(1),
                  mineVal: summary.totalBooksRead / summary.totalStudents,
                  benchmarkVal: global?.avgBooksRead,
                ),
              if (summary.totalStudents > 0)
                _SummaryRow(
                  label: 'Active (30d)',
                  mine: '${summary.activeLast30d}/${summary.totalStudents}',
                  benchmark: null,
                  mineVal: null,
                  benchmarkVal: null,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.mine,
    required this.benchmark,
    required this.mineVal,
    required this.benchmarkVal,
  });

  final String label;
  final String mine;
  final String? benchmark;
  final double? mineVal;
  final double? benchmarkVal;

  Color _compareColor() {
    if (mineVal == null || benchmarkVal == null) return AppColors.neutralText;
    if (mineVal! > benchmarkVal!) return Colors.green.shade600;
    return AppColors.neutralText;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.black,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              mine,
              textAlign: TextAlign.right,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _compareColor(),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              benchmark == null ? '' : 'global: $benchmark',
              textAlign: TextAlign.right,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.neutralText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
