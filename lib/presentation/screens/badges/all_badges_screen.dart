import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/achievement_group.dart';
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

          final items = <_BadgeListItem>[
            _BadgeListItem.header(earnedCount: earnedCount, totalCount: totalCount),
          ];
          AchievementSuperGroup? lastSection;
          for (final g in groups) {
            if (g.superGroup != lastSection) {
              items.add(_BadgeListItem.section(superGroup: g.superGroup));
              lastSection = g.superGroup;
            }
            items.add(_BadgeListItem.row(group: g));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: items.length,
            itemBuilder: (context, index) => items[index].build(context),
          );
        },
      ),
    );
  }
}

/// Internal model used to flatten the list (header + section labels + rows)
/// into a single ListView.builder stream.
class _BadgeListItem {
  const _BadgeListItem._({
    this.earnedCount,
    this.totalCount,
    this.superGroup,
    this.group,
  });

  factory _BadgeListItem.header({
    required int earnedCount,
    required int totalCount,
  }) => _BadgeListItem._(earnedCount: earnedCount, totalCount: totalCount);

  factory _BadgeListItem.section({required AchievementSuperGroup superGroup}) =>
      _BadgeListItem._(superGroup: superGroup);

  factory _BadgeListItem.row({required AchievementGroup group}) =>
      _BadgeListItem._(group: group);

  final int? earnedCount;
  final int? totalCount;
  final AchievementSuperGroup? superGroup;
  final AchievementGroup? group;

  Widget build(BuildContext context) {
    if (group != null) {
      return AchievementGroupRow(group: group!);
    }
    if (superGroup != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          _sectionLabel(superGroup!),
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 1.2,
            color: AppColors.gray700,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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

  static String _sectionLabel(AchievementSuperGroup g) {
    switch (g) {
      case AchievementSuperGroup.achievements:
        return 'ACHIEVEMENTS';
      case AchievementSuperGroup.cardCollection:
        return 'CARD COLLECTION';
    }
  }
}
