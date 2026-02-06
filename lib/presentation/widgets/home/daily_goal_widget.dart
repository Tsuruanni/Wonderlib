import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:readeng/app/theme.dart';
import 'package:readeng/presentation/providers/daily_goal_provider.dart';
import 'package:readeng/presentation/widgets/home/daily_tasks_list.dart';
import 'package:shimmer/shimmer.dart';

/// Main daily goal widget combining streak display and tasks list
class DailyGoalWidget extends ConsumerWidget {
  const DailyGoalWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyGoalAsync = ref.watch(dailyGoalProvider);

    return dailyGoalAsync.when(
      loading: () => _buildLoadingSkeleton(),
      error: (_, __) => _buildErrorState(),
      data: (state) => _buildContent(state),
    );
  }

  Widget _buildContent(DailyGoalState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      child: DailyTasksList(state: state),
    );
  }

  Widget _buildLoadingSkeleton() {
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
      child: Shimmer.fromColors(
        baseColor: AppColors.neutral,
        highlightColor: AppColors.white,
        child: Column(
          children: [
            // Header skeleton
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 100,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content skeleton
            Row(
              children: [
                // Left skeleton
                Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),

                // Right skeleton
                Expanded(
                  child: Column(
                    children: List.generate(
                      3,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
