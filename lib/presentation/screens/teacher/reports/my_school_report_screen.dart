import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../../providers/teacher_provider.dart';
import '../../../widgets/common/playful_card.dart';
import '../../../widgets/common/responsive_layout.dart';

/// Teacher report: aggregate stats for the caller's own school compared to
/// platform-wide averages. Previously lived inside Class Overview; promoted
/// to its own report page.
class MySchoolReportScreen extends ConsumerWidget {
  const MySchoolReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(schoolSummaryProvider);
    final globalAsync = ref.watch(globalAveragesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My School'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(schoolSummaryProvider);
          ref.invalidate(globalAveragesProvider);
        },
        child: summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Error loading school data')),
          data: (summary) {
            if (summary == null) {
              return const Center(child: Text('No school data available'));
            }
            final global = globalAsync.valueOrNull;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ResponsiveConstraint(
                  maxWidth: 900,
                  child: PlayfulCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.school_rounded,
                                color: AppColors.secondary),
                            const SizedBox(width: 8),
                            Text(
                              'School vs Platform',
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
                        if (summary.totalStudents > 0 &&
                            summary.totalBooksRead > 0)
                          _SummaryRow(
                            label: 'Books Read / Student',
                            mine:
                                (summary.totalBooksRead / summary.totalStudents)
                                    .toStringAsFixed(1),
                            benchmark:
                                global?.avgBooksRead.toStringAsFixed(1),
                            mineVal: summary.totalBooksRead /
                                summary.totalStudents,
                            benchmarkVal: global?.avgBooksRead,
                          ),
                        if (summary.totalStudents > 0)
                          _SummaryRow(
                            label: 'Active (30d)',
                            mine:
                                '${summary.activeLast30d}/${summary.totalStudents}',
                            benchmark: null,
                            mineVal: null,
                            benchmarkVal: null,
                          ),
                      ],
                    ),
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
