import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/daily_quest.dart';
import '../../../core/utils/app_clock.dart';
import '../../../domain/entities/student_assignment.dart';
import '../../providers/badge_provider.dart';
import '../../providers/daily_review_provider.dart';
import '../../providers/card_provider.dart';
import '../../providers/daily_quest_provider.dart';
import '../../providers/monthly_quest_provider.dart';
import '../../providers/student_assignment_provider.dart';
import '../../providers/reader_provider.dart';
import '../../providers/system_settings_provider.dart';
import '../../providers/leaderboard_provider.dart';
import '../../providers/user_provider.dart';
import '../cards/collection_progress_card.dart';
import '../cards/rarity_showcase_card.dart';
import '../cards/top_collectors_card.dart';
import '../cards/trade_button_card.dart';
import '../common/app_progress_bar.dart';
import '../common/streak_sheet.dart';
import '../../utils/app_icons.dart';
import '../../utils/monthly_tier_info.dart';

/// Right info panel shown on wide screens (≥1000px).
/// Contains stats bar, league card, and daily quests — like Duolingo's web layout.
class RightInfoPanel extends ConsumerWidget {
  const RightInfoPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final isReader = location.startsWith('/reader') ||
        location.startsWith('/quiz');
    final showPackCard = location.startsWith(AppRoutes.cards);
    final isVocab = location.startsWith(AppRoutes.vocabulary);
    final isQuests = location.startsWith(AppRoutes.quests);
    final isLeaderboard = location.startsWith(AppRoutes.leaderboard);

    return SizedBox(
      width: 330,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _StatsBar(),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  if (isVocab) ...[
                    const _DailyReviewCard(),
                    const SizedBox(height: 16),
                  ],
                  if (showPackCard) ...[
                    const _OpenPackCard(),
                    const SizedBox(height: 12),
                    const TradeButtonCard(),
                    const SizedBox(height: 16),
                    const CollectionProgressCard(),
                    const SizedBox(height: 16),
                    const TopCollectorsCard(),
                    const SizedBox(height: 16),
                    const RarityShowcaseCard(),
                    const SizedBox(height: 16),
                  ] else if (isReader) ...[
                    const _ReaderSettingsCard(),
                    const SizedBox(height: 16),
                  ] else if (isQuests) ...[
                    const _MonthlyQuestSidebarCard(),
                  ] else ...[
                    if (isLeaderboard) const _LastWeekCard(),
                    const _LeagueCard(),
                    const SizedBox(height: 16),
                    const _TeacherQuestsCard(),
                    const SizedBox(height: 16),
                    const _DailyQuestsCard(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats Bar (streak, coins) ───

class _StatsBar extends ConsumerWidget {
  const _StatsBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userControllerProvider).valueOrNull;
    final streak = ref.watch(displayStreakProvider);
    final coins = user?.coins ?? 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Streak
        GestureDetector(
          onTap: () {
            if (user != null) showStreakSheet(context);
          },
          child: _StatChip(
            assetPath: 'assets/icons/fire_menu_bar_256.png',
            value: streak,
          ),
        ),
        const SizedBox(width: 12),
        // Coins
        _StatChip(
          assetPath: 'assets/icons/gem_outline_256.png',
          value: coins,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    this.icon,
    this.iconColor,
    this.assetPath,
    required this.value,
  });

  final IconData? icon;
  final Color? iconColor;
  final String? assetPath;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (assetPath != null)
          Image.asset(assetPath!, width: 24, height: 24, filterQuality: FilterQuality.high)
        else
          Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 4),
        Text(
          value.toString(),
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
      ],
    );
  }
}

// ─── Last Week Result Card ───

class _LastWeekCard extends ConsumerWidget {
  const _LastWeekCard();

  /// Derive the old tier from result + new tier
  LeagueTier? _oldTier(String result, LeagueTier newTier) {
    if (result == 'promoted') return newTier.previousTier;
    if (result == 'demoted' || result == 'inactive_demoted') return newTier.nextTier;
    return newTier; // stayed
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(leagueStatusProvider).valueOrNull;
    if (status == null || !status.hasLastWeekData) return const SizedBox.shrink();

    final rank = status.lastWeekRank!;
    final result = status.lastWeekResult ?? 'stayed';
    final newTier = status.lastWeekTier ?? LeagueTier.bronze;
    final oldTier = _oldTier(result, newTier);

    final Color resultColor;
    final String resultText;

    switch (result) {
      case 'promoted':
        resultColor = const Color(0xFF4CAF50);
        resultText = 'Promoted to ${newTier.label} from ${oldTier?.label ?? ''}!';
      case 'demoted':
        resultColor = const Color(0xFFE53935);
        resultText = 'Demoted to ${newTier.label} from ${oldTier?.label ?? ''}';
      case 'inactive_demoted':
        resultColor = const Color(0xFFFF9800);
        resultText = 'Inactive — moved to ${newTier.label}';
      default:
        resultColor = AppColors.neutralText;
        resultText = 'Stayed in ${newTier.label}';
    }

    // Show the tier the student competed in (old tier for promoted/demoted, same for stayed)
    final displayTier = (result == 'promoted' || result == 'demoted') ? oldTier ?? newTier : newTier;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neutral, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last Week',
              style: GoogleFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // Tier icon (the league they competed in)
                Image.asset(
                  _LeagueCard._tierAsset(displayTier),
                  width: 40,
                  height: 40,
                  filterQuality: FilterQuality.high,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Result text with icon
                      Text(
                        resultText,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: resultColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Rank
                      Text(
                        'Finished #$rank',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutralText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── League Card ───

class _LeagueCard extends ConsumerWidget {
  const _LeagueCard();

  Color _tierColor(LeagueTier tier) {
    switch (tier) {
      case LeagueTier.bronze:
        return const Color(0xFFCD7F32);
      case LeagueTier.silver:
        return const Color(0xFFC0C0C0);
      case LeagueTier.gold:
        return AppColors.cardLegendary;
      case LeagueTier.platinum:
        return const Color(0xFF6DD3CE);
      case LeagueTier.diamond:
        return AppColors.secondary;
    }
  }

  static String _tierAsset(LeagueTier tier) {
    return switch (tier) {
      LeagueTier.bronze => 'assets/icons/rank-bronze-1_large.png',
      LeagueTier.silver => 'assets/icons/rank-silver-2_large.png',
      LeagueTier.gold => 'assets/icons/rank-gold-3_large.png',
      LeagueTier.platinum => 'assets/icons/rank-platinum-5_large.png',
      LeagueTier.diamond => 'assets/icons/rank-diamond-7_large.png',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userControllerProvider).valueOrNull;
    final tier = user?.leagueTier ?? LeagueTier.bronze;
    final color = _tierColor(tier);
    final statusAsync = ref.watch(leagueStatusProvider);
    final status = statusAsync.valueOrNull;
    final classRank = ref.watch(userClassRankProvider).valueOrNull;
    final schoolRank = ref.watch(userSchoolRankProvider).valueOrNull;

    // Days left until Sunday
    final now = DateTime.now().toUtc();
    final weekEnd = now
        .subtract(Duration(days: now.weekday - 1))
        .add(const Duration(days: 6));
    final daysLeft = weekEnd.difference(now).inDays + 1;

    return GestureDetector(
      onTap: () => context.go(AppRoutes.leaderboard),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neutral, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${tier.label} League',
                  style: GoogleFonts.nunito(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                  ),
                ),
                Text(
                  'VIEW STATS',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Tier rank icon
                Image.asset(
                  _tierAsset(tier),
                  width: 44,
                  height: 44,
                  filterQuality: FilterQuality.high,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rank or join status
                      if (status != null && status.joined && status.rank != null)
                        Text(
                          "You're ranked #${status.rank}",
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.black,
                          ),
                        )
                      else if (status != null && !status.joined)
                        Text(
                          'Earn ${20 - status.currentWeeklyXp} more XP to join',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.neutralText,
                          ),
                        )
                      else
                        Text(
                          "This week's league is active",
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: AppColors.neutralText,
                          ),
                        ),
                      // Days left
                      Text(
                        '$daysLeft days left',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Class & School rankings
            if (classRank != null || schoolRank != null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: AppColors.neutral),
              ),
              if (classRank != null)
                _RankRow(
                  icon: Icons.groups_rounded,
                  label: 'Class Rank',
                  rank: classRank,
                ),
              if (classRank != null && schoolRank != null)
                const SizedBox(height: 6),
              if (schoolRank != null)
                _RankRow(
                  icon: Icons.school_rounded,
                  label: 'School Rank',
                  rank: schoolRank,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.icon,
    required this.label,
    required this.rank,
  });

  final IconData icon;
  final String label;
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.neutralText),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.neutralText,
          ),
        ),
        const Spacer(),
        Text(
          '#$rank',
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
      ],
    );
  }
}

// ─── Teacher Quests Card ───

class _TeacherQuestsCard extends ConsumerWidget {
  const _TeacherQuestsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(activeAssignmentsProvider);
    final assignments = assignmentsAsync.valueOrNull ?? [];

    // Don't render the card at all while loading or if empty
    if (assignmentsAsync.isLoading || assignments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quests from Your Teacher',
            style: GoogleFonts.nunito(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < assignments.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _TeacherQuestRow(assignment: assignments[i]),
          ],
        ],
      ),
    );
  }
}

class _TeacherQuestRow extends StatelessWidget {
  const _TeacherQuestRow({required this.assignment});
  final StudentAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final progress = (assignment.progress / 100).clamp(0.0, 1.0);

    final Color iconColor;
    switch (assignment.type) {
      case StudentAssignmentType.book:
        iconColor = AppColors.gemBlue;
      case StudentAssignmentType.vocabulary:
        iconColor = AppColors.secondary;
      case StudentAssignmentType.unit:
        iconColor = AppColors.streakOrange;
    }

    final daysLeft = assignment.dueDate.difference(AppClock.now()).inDays;
    final String dueText;
    if (daysLeft < 0) {
      dueText = 'Overdue';
    } else if (daysLeft == 0) {
      dueText = 'Due today';
    } else if (daysLeft == 1) {
      dueText = '1 day left';
    } else {
      dueText = '$daysLeft days left';
    }

    final Color dueColor;
    if (daysLeft < 0) {
      dueColor = AppColors.danger;
    } else if (daysLeft <= 2) {
      dueColor = AppColors.streakOrange;
    } else {
      dueColor = AppColors.neutralText;
    }

    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.studentAssignmentDetailPath(assignment.assignmentId),
      ),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Image.asset(
            'assets/icons/clipboard_256.png',
            width: 32,
            height: 32,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 4),
                AppProgressBar(
                  progress: progress,
                  height: 8,
                  fillColor: iconColor,
                  fillShadow: iconColor.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: dueColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              dueText,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: dueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Daily Quests Card ───

class _DailyQuestsCard extends ConsumerWidget {
  const _DailyQuestsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questsAsync = ref.watch(dailyQuestProgressProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral, width: 2),
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Quests',
          style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: 12),
        questsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, __) => Text(
            'Could not load quests',
            style: GoogleFonts.nunito(color: AppColors.neutralText),
          ),
          data: (quests) {
            if (quests.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No quests available today',
                  style: GoogleFonts.nunito(color: AppColors.neutralText),
                ),
              );
            }
            final allDone = quests.every((q) => q.isCompleted);
            return Column(
              children: [
                if (allDone) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        AppIcons.check(size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'All quests complete!',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                for (int i = 0; i < quests.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _SidebarQuestRow(progress: quests[i]),
                ],
              ],
            );
          },
        ),
      ],
      ),
    );
  }
}

class _SidebarQuestRow extends StatelessWidget {
  const _SidebarQuestRow({required this.progress});

  final DailyQuestProgress progress;

  ({Color base, Color shadow}) _rewardColors(QuestRewardType rewardType) {
    return switch (rewardType) {
      QuestRewardType.coins => (base: AppColors.wasp, shadow: AppColors.waspDark),
      QuestRewardType.cardPack =>
        (base: AppColors.gemBlue, shadow: const Color(0xFF1899D6)),
    };
  }

  Widget _buildRewardCluster(DailyQuest quest, bool isCompleted) {
    final colors = isCompleted
        ? (base: AppColors.wasp, shadow: AppColors.waspDark)
        : _rewardColors(quest.rewardType);
    final icon = isCompleted
        ? AppIcons.check(size: 26)
        : switch (quest.rewardType) {
            QuestRewardType.coins => AppIcons.gem(size: 26),
            QuestRewardType.cardPack => AppIcons.card(size: 26),
          };
    final tile = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: colors.shadow, offset: const Offset(0, 3), blurRadius: 0),
        ],
        border: Border.all(color: colors.shadow, width: 2),
      ),
      child: Center(child: icon),
    );
    if (isCompleted) return tile;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        tile,
        const SizedBox(width: 4),
        Text(
          '×${quest.rewardAmount}',
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: colors.shadow,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final quest = progress.quest;
    final isCompleted = progress.isCompleted;
    final ratio = quest.goalValue > 0
        ? (progress.currentValue / quest.goalValue).clamp(0.0, 1.0)
        : 0.0;
    final rewardColors = isCompleted
        ? (base: AppColors.wasp, shadow: AppColors.waspDark)
        : _rewardColors(quest.rewardType);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                quest.title,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isCompleted ? AppColors.neutralText : AppColors.black,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              AppProgressBar(
                progress: ratio,
                height: 18,
                fillColor: rewardColors.base,
                fillShadow: rewardColors.shadow,
                overlayText: '${progress.currentValue} / ${quest.goalValue}',
                overlayTextStyle: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: ratio > 0.5 ? Colors.white : AppColors.gray600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _buildRewardCluster(quest, isCompleted),
      ],
    );
  }
}

// ─── Daily Review Card (Learning Path sidebar) ───

class _DailyReviewCard extends ConsumerWidget {
  const _DailyReviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySession = ref.watch(todayReviewSessionProvider).valueOrNull;
    final dueWords = ref.watch(dailyReviewWordsProvider).valueOrNull ?? [];

    // Already completed today
    if (todaySession != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryShadow,
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: AppIcons.check(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review Complete!',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '+${todaySession.xpEarned} XP earned',
                    style: GoogleFonts.nunito(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Enough words to start a review
    if (dueWords.length >= minDailyReviewCount) {
      return GestureDetector(
        onTap: () => context.push(AppRoutes.vocabularyDailyReview),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.streakOrange,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: const Color(0xFFC76A00), offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AppIcons.xp(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Review',
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${dueWords.length} words ready!',
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: AppColors.streakOrange, size: 20),
              ),
            ],
          ),
        ),
      );
    }

    // Not enough words — hide
    return const SizedBox.shrink();
  }
}

// ─── Open Pack Card ───

class _OpenPackCard extends ConsumerWidget {
  const _OpenPackCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packs = ref.watch(unopenedPacksProvider);
    final hasPacks = packs > 0;
    final packCost =
        ref.watch(systemSettingsProvider).valueOrNull?.packCost ?? 100;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF6B4CFE), Color(0xFF9B3FE8), Color(0xFFD355FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B4CFE).withValues(alpha: 0.4),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -15,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: sparkle icon + pack count or buy prompt
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.asset(
                        'assets/icons/card.png',
                        width: 24,
                        height: 24,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hasPacks ? '$packs Packs Available' : 'Booster Packs',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action buttons
                if (hasPacks)
                  // Open Packs button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.push(AppRoutes.packOpening),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF6B4CFE),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Open Packs',
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  )
                else
                  // Buy Pack button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.push(AppRoutes.packOpening),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF6B4CFE),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Buy Pack',
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Image.asset(
                            'assets/icons/gem_outline_256.png',
                            width: 16,
                            height: 16,
                            filterQuality: FilterQuality.high,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '$packCost',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardEpic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reader Settings Card ───

class _ReaderSettingsCard extends ConsumerWidget {
  const _ReaderSettingsCard();

  TextStyle _fontPreviewStyle(ReaderFont font) {
    switch (font) {
      case ReaderFont.nunito:
        return GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600);
      case ReaderFont.openSans:
        return GoogleFonts.openSans(fontSize: 14, fontWeight: FontWeight.w600);
      case ReaderFont.merriweather:
        return GoogleFonts.merriweather(fontSize: 14, fontWeight: FontWeight.w600);
      case ReaderFont.lora:
        return GoogleFonts.lora(fontSize: 14, fontWeight: FontWeight.w600);
      case ReaderFont.literata:
        return GoogleFonts.literata(fontSize: 14, fontWeight: FontWeight.w600);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reader Settings',
            style: GoogleFonts.nunito(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 14),

          // Font family dropdown (top setting)
          _SettingsRow(
            label: 'Font',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.neutral, width: 2),
              ),
              child: DropdownButton<ReaderFont>(
                value: settings.font,
                underline: const SizedBox.shrink(),
                isDense: true,
                borderRadius: BorderRadius.circular(12),
                icon: const Icon(Icons.expand_more_rounded, size: 20, color: AppColors.neutralText),
                items: ReaderFont.values.map((font) {
                  return DropdownMenuItem(
                    value: font,
                    child: Text(
                      font.displayName,
                      style: _fontPreviewStyle(font).copyWith(
                        color: AppColors.black,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (font) {
                  if (font != null) notifier.setFont(font);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Font size
          _SettingsRow(
            label: 'Font Size',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SettingsButton(
                  icon: Icons.remove_rounded,
                  onTap: () => notifier.setFontSize(settings.fontSize - 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '${settings.fontSize.toInt()}',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),
                ),
                _SettingsButton(
                  icon: Icons.add_rounded,
                  onTap: () => notifier.setFontSize(settings.fontSize + 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Line height
          _SettingsRow(
            label: 'Line Spacing',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SettingsButton(
                  icon: Icons.remove_rounded,
                  onTap: () => notifier.setLineHeight(settings.lineHeight - 0.1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    settings.lineHeight.toStringAsFixed(1),
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),
                ),
                _SettingsButton(
                  icon: Icons.add_rounded,
                  onTap: () => notifier.setLineHeight(settings.lineHeight + 0.1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Theme
          _SettingsRow(
            label: 'Theme',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final theme in ReaderTheme.values)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: GestureDetector(
                      onTap: () => notifier.setTheme(theme),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: theme.background,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: settings.theme == theme
                                ? AppColors.secondary
                                : AppColors.neutral,
                            width: 2,
                          ),
                        ),
                        // Mini lines for notebook theme preview
                        child: theme.hasLines
                            ? CustomPaint(
                                painter: _MiniNotebookPainter(
                                  lineColor: theme.lineColor,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.black,
          ),
        ),
        const Spacer(),
        child,
      ],
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.neutral, width: 2),
        ),
        child: Icon(icon, size: 18, color: AppColors.black),
      ),
    );
  }
}

/// Mini notebook line preview for theme circle button.
class _MiniNotebookPainter extends CustomPainter {
  _MiniNotebookPainter({required this.lineColor});

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.8;

    // Draw 3 horizontal lines inside the circle
    final spacing = size.height / 4;
    for (int i = 1; i <= 3; i++) {
      final y = spacing * i;
      canvas.drawLine(
        Offset(size.width * 0.2, y),
        Offset(size.width * 0.8, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MiniNotebookPainter oldDelegate) => false;
}

// ─── Monthly Quest Sidebar Card (Quests route) ───

class _MonthlyQuestSidebarCard extends ConsumerWidget {
  const _MonthlyQuestSidebarCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(monthlyQuestProgressProvider);
    final list = progressAsync.valueOrNull ?? const [];
    if (list.isEmpty) {
      return const SizedBox.shrink();
    }
    final progress = list.first;
    final now = DateTime.now();
    final monthName = DateFormat('MMMM').format(now);
    final daysLeft = progress.daysLeft;
    final fill = progress.quest.goalValue > 0
        ? (progress.currentValue / progress.quest.goalValue).clamp(0.0, 1.0)
        : 0.0;
    final tierInfo = monthlyTierInfo(
      ref.watch(allBadgesProvider).valueOrNull ?? const [],
      ref.watch(userBadgesProvider).valueOrNull ?? const [],
      progress.quest.id,
      progress.completionCount,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.streakOrange,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFC76A00),
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              monthName.toUpperCase(),
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$monthName Quest',
            style: GoogleFonts.nunito(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              AppIcons.schedule(size: 13),
              const SizedBox(width: 3),
              Text(
                '$daysLeft DAYS',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progress.quest.title,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                AppProgressBar(
                  progress: fill,
                  height: 8,
                  fillColor: Colors.white,
                  fillShadow: Colors.white.withValues(alpha: 0.5),
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${progress.currentValue} / ${progress.quest.goalValue}',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                if (tierInfo != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        tierInfo.allEarned
                            ? Icons.military_tech_rounded
                            : Icons.military_tech_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          tierInfo.label,
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
