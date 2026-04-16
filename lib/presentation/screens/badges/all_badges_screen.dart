import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../providers/badge_progress_provider.dart';
import '../../widgets/badges/achievement_group_row.dart';

/// Duolingo-style screen listing every achievement track grouped by condition type.
/// Each row shows current level, progress toward the next tier, and description.
class AllBadgesScreen extends ConsumerWidget {
  const AllBadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(achievementGroupsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Achievements',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: AppColors.neutralText,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.profile);
            }
          },
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load achievements.\n$e',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(color: AppColors.gray600),
            ),
          ),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Text(
                'No achievements yet.',
                style: GoogleFonts.nunito(fontSize: 16, color: AppColors.gray600),
              ),
            );
          }
          final earnedCount =
              groups.fold<int>(0, (sum, g) => sum + g.currentLevel);
          final totalCount =
              groups.fold<int>(0, (sum, g) => sum + g.maxLevel);

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: groups.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Text(
                    '$earnedCount / $totalCount earned',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.gray600,
                    ),
                  ),
                );
              }
              return AchievementGroupRow(group: groups[index - 1]);
            },
          );
        },
      ),
    );
  }
}
