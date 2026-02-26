import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:owlio/app/theme.dart';
import 'package:owlio/presentation/providers/daily_goal_provider.dart';
import 'package:owlio/presentation/providers/student_assignment_provider.dart';
import 'package:owlio/presentation/widgets/home/daily_tasks_list.dart';
import 'package:shimmer/shimmer.dart';

/// Main daily goal widget combining quest cards and assignment cards
class DailyGoalWidget extends ConsumerWidget {
  const DailyGoalWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyGoalAsync = ref.watch(dailyGoalProvider);
    final assignmentsAsync = ref.watch(activeAssignmentsProvider);

    return dailyGoalAsync.when(
      loading: () => _buildLoadingSkeleton(),
      error: (_, __) => _buildErrorState(),
      data: (state) {
        final assignments = assignmentsAsync.valueOrNull ?? [];
        return DailyTasksList(
          state: state,
          assignments: assignments,
        );
      },
    );
  }

  Widget _buildLoadingSkeleton() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neutral, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral,
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: AppColors.neutral,
        highlightColor: AppColors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            children: [
              // Header skeleton
              Container(
                width: 180,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              const SizedBox(height: 14),
              // 3 row skeletons
              ...List.generate(3, (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 120,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neutral, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral,
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: AppColors.danger,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Could not load daily goals',
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: AppColors.neutralText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
