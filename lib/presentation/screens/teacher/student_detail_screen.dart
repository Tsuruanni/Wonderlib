import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../app/router.dart';

import '../../../app/theme.dart';
import '../../../core/utils/extensions/context_extensions.dart';
import '../../../domain/entities/system_settings.dart';
import '../../providers/system_settings_provider.dart';
import '../../../core/utils/level_helper.dart';
import '../../../data/models/avatar/equipped_avatar_model.dart';
import '../../../domain/entities/avatar.dart';
import '../../../domain/entities/badge.dart';
import '../../../domain/entities/card.dart';
import '../../../domain/entities/user.dart' as domain;
import '../../../domain/entities/vocabulary.dart';
import '../../../domain/repositories/teacher_repository.dart';
import '../../../domain/entities/book_quiz.dart';
import '../../providers/book_quiz_provider.dart';
import '../../providers/teacher_provider.dart';
import '../../widgets/common/asset_icon.dart';
import '../../../domain/entities/achievement_group.dart';
import '../../providers/card_provider.dart';
import '../../widgets/badges/achievement_group_row.dart';
import '../../widgets/cards/locked_card_widget.dart';
import '../../widgets/cards/myth_card_widget.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/common/error_state_widget.dart';
import '../../widgets/common/app_progress_bar.dart';
import '../../widgets/common/playful_card.dart';

class StudentDetailScreen extends ConsumerWidget {
  const StudentDetailScreen({
    super.key,
    required this.studentId,
  });

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(studentDetailProvider(studentId));
    final progressAsync = ref.watch(studentProgressProvider(studentId));
    final vocabStatsAsync = ref.watch(studentVocabStatsProvider(studentId));
    final quizResultsAsync = ref.watch(studentQuizResultsProvider(studentId));
    final wordListProgressAsync =
        ref.watch(studentWordListProgressProvider(studentId));
    final badgesAsync = ref.watch(teacherStudentBadgesProvider(studentId));
    final cardsAsync = ref.watch(teacherStudentCardsProvider(studentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profile'),
        centerTitle: false,
      ),
      body: studentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ErrorStateWidget(
          message: 'Error loading student',
          onRetry: () {
            ref.invalidate(studentDetailProvider(studentId));
            ref.invalidate(studentProgressProvider(studentId));
            ref.invalidate(studentVocabStatsProvider(studentId));
            ref.invalidate(studentWordListProgressProvider(studentId));
          },
        ),
        data: (student) {
          if (student == null) {
            return const Center(child: Text('Student not found'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(studentDetailProvider(studentId));
              ref.invalidate(studentProgressProvider(studentId));
              ref.invalidate(studentVocabStatsProvider(studentId));
              ref.invalidate(studentWordListProgressProvider(studentId));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header (avatar + name + level/XP/streak chips)
                  _StudentHeader(user: student),
                  const SizedBox(height: 24),

                  // 3. Reading Progress (horizontal)
                  progressAsync.when(
                    loading: () => _SectionTitle(title: 'Reading Progress', assetPath: AppIcons.book, color: Colors.blue),
                    error: (_, __) => _SectionTitle(title: 'Reading Progress', assetPath: AppIcons.book, color: Colors.blue),
                    data: (list) {
                      final started = list.where((p) => p.completionPercentage > 0).length;
                      final finished = list.where((p) => p.isCompleted).length;
                      final reading = started - finished;
                      String? subtitle;
                      if (started > 0) {
                        final parts = <String>[];
                        if (reading > 0) parts.add('$reading still reading');
                        if (finished > 0) parts.add('$finished finished');
                        subtitle = parts.join(' · ');
                      }
                      return _SectionTitle(
                        title: 'Reading Progress',
                        assetPath: AppIcons.book,
                        color: Colors.blue,
                        trailing: subtitle,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  progressAsync.when(
                    loading: () => const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => const Text('Error loading progress'),
                    data: (progressList) {
                      // In-progress books first, completed after.
                      final filtered = progressList
                          .where((p) => p.completionPercentage > 0)
                          .toList()
                        ..sort((a, b) {
                          final aDone = a.isCompleted ? 1 : 0;
                          final bDone = b.isCompleted ? 1 : 0;
                          if (aDone != bDone) return aDone - bDone;
                          // Within each group, most recent first.
                          final aTs = a.lastReadAt;
                          final bTs = b.lastReadAt;
                          if (aTs == null && bTs == null) return 0;
                          if (aTs == null) return 1;
                          if (bTs == null) return -1;
                          return bTs.compareTo(aTs);
                        });
                      if (filtered.isEmpty) {
                        return _EmptySection(
                          assetPath: AppIcons.library,
                          message: 'No reading activity yet',
                        );
                      }
                      // Join quiz results by bookId so each card can show
                      // its own quiz score inline.
                      final quizByBookId = <String, StudentQuizProgress>{};
                      final quizResults = quizResultsAsync.valueOrNull;
                      if (quizResults != null) {
                        for (final q in quizResults) {
                          quizByBookId[q.bookId] = q;
                        }
                      }
                      return SizedBox(
                        height: 315,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 16),
                          itemBuilder: (context, index) {
                            final p = filtered[index];
                            return _HorizontalBookCard(
                              progress: p,
                              quiz: quizByBookId[p.bookId],
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // 4. Vocabulary Progress (stats + word lists in one panel)
                  _SectionTitle(title: 'Vocabulary Progress', assetPath: AppIcons.vocabulary, color: Colors.purple),
                  const SizedBox(height: 12),
                  vocabStatsAsync.when(
                    loading: () => const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => const Text('Error loading stats'),
                    data: (stats) => _VocabStatsCard(
                      stats: stats,
                      wordListsAsync: wordListProgressAsync,
                      onViewWordbank: () {
                        showAppSnackBar(
                          context,
                          'Wordbank view coming soon',
                          type: SnackBarType.info,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 7. Achievements (Duolingo-style tracks with progress bars)
                  _StudentAchievementsSection(studentId: studentId),

                  // 8. Card Collection — same myth-category layout as /cards
                  _StudentCardCollection(studentId: studentId),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────

class _StudentHeader extends StatelessWidget {
  const _StudentHeader({required this.user});
  final domain.User user;

  @override
  Widget build(BuildContext context) {
    return PlayfulCard(
      child: Row(
        children: [
          // Avatar
          AvatarWidget(
            avatar: user.avatarEquippedCache != null
                ? EquippedAvatarModel.fromJson(user.avatarEquippedCache!).toEntity()
                : const EquippedAvatar(),
            size: 64,
            fallbackInitials: user.initials,
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                  ),
                ),
                if (user.studentNumber != null)
                  Text(
                    'Student #${user.studentNumber}',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: AppColors.neutralText,
                    ),
                  ),
                const SizedBox(height: 6),
                // Stats chips
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _LevelChip(level: user.level),
                    _StatChip(
                      assetPath: AppIcons.xp,
                      value: '${user.xp} XP',
                      color: AppColors.waspDark,
                    ),
                    _StatChip(
                      assetPath: AppIcons.fire,
                      value: user.currentStreak == 1
                          ? '1 day streak'
                          : '${user.currentStreak} day streak',
                      color: Colors.orange,
                    ),
                    _StatChip(
                      assetPath: AppIcons.trophy,
                      value: user.longestStreak == 1
                          ? 'best: 1 day'
                          : 'best: ${user.longestStreak} days',
                      color: Colors.purple,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    this.icon,
    this.assetPath,
    required this.value,
    required this.color,
  });

  final IconData? icon;
  final String? assetPath;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
            value,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LEVEL CHIP (embedded in StudentHeader alongside streak chips)
// ─────────────────────────────────────────────

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.wasp.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.wasp, width: 1.5),
      ),
      child: Text(
        'Lv $level',
        style: GoogleFonts.nunito(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          color: AppColors.waspDark,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// INLINE QUIZ PILL (inside a reading progress book card)
// ─────────────────────────────────────────────

class _StudentAchievementsSection extends ConsumerWidget {
  const _StudentAchievementsSection({required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(studentAchievementGroupsProvider(studentId));
    return groupsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (groups) {
        if (groups.isEmpty) return const SizedBox.shrink();
        final earnedCount = groups.fold<int>(0, (s, g) => s + g.currentLevel);
        final totalCount = groups.fold<int>(0, (s, g) => s + g.maxLevel);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              title: 'Achievements',
              assetPath: AppIcons.trophy,
              color: Colors.amber,
              trailing: '$earnedCount / $totalCount earned',
            ),
            const SizedBox(height: 12),
            for (final g in groups) AchievementGroupRow(group: g),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

class _BadgeGroupHeader extends StatelessWidget {
  const _BadgeGroupHeader({required this.conditionType, required this.count});
  final BadgeConditionType conditionType;
  final int count;

  String _label() {
    switch (conditionType) {
      case BadgeConditionType.xpTotal:
        return 'XP';
      case BadgeConditionType.streakDays:
        return 'Streak';
      case BadgeConditionType.booksCompleted:
        return 'Books Read';
      case BadgeConditionType.vocabularyLearned:
        return 'Vocabulary';
      case BadgeConditionType.levelCompleted:
        return 'Levels';
      case BadgeConditionType.cardsCollected:
        return 'Cards';
      case BadgeConditionType.mythCategoryCompleted:
        return 'Myth Categories';
      case BadgeConditionType.leagueTierReached:
        return 'League';
      case BadgeConditionType.monthlyQuestCompleted:
        return 'Monthly Quests';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Text(
            _label().toUpperCase(),
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.neutralText,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.wasp.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.waspDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CefrBadge extends StatelessWidget {
  const _CefrBadge({required this.level});
  final String level;

  Color _bgColor() {
    final l = level.toUpperCase();
    if (l.startsWith('A1')) return const Color(0xFF58CC02);
    if (l.startsWith('A2')) return const Color(0xFF1CB0F6);
    if (l.startsWith('B1')) return const Color(0xFFFFC800);
    if (l.startsWith('B2')) return const Color(0xFFFF9600);
    if (l.startsWith('C1')) return const Color(0xFFCE82FF);
    if (l.startsWith('C2')) return const Color(0xFFFF4B4B);
    return AppColors.neutralDark;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _bgColor(),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        level.toUpperCase(),
        style: GoogleFonts.nunito(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _QuizScoreLine extends StatelessWidget {
  const _QuizScoreLine({required this.quiz});
  final StudentQuizProgress quiz;

  @override
  Widget build(BuildContext context) {
    final pct = quiz.bestPercentage.round();
    final color = quiz.isPassing
        ? Colors.green.shade700
        : (quiz.bestPercentage >= 50 ? Colors.orange.shade700 : Colors.red.shade700);
    return Row(
      children: [
        const AssetIcon(AppIcons.quiz, size: 14),
        const SizedBox(width: 4),
        Text(
          'Quiz score: $pct%',
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// SECTION TITLE
// ─────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.icon,
    this.assetPath,
    required this.color,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final String? assetPath;
  final Color color;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (assetPath != null)
          AssetIcon(assetPath!, size: 24)
        else
          Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          Text(
            trailing!,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.neutralText,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────
// HORIZONTAL BOOK CARD
// ─────────────────────────────────────────────

class _HorizontalBookCard extends StatelessWidget {
  const _HorizontalBookCard({required this.progress, this.quiz});
  final StudentBookProgress progress;
  final StudentQuizProgress? quiz;

  @override
  Widget build(BuildContext context) {
    final pctColor = ScoreColors.getProgressColor(progress.completionPercentage);
    return InkWell(
      onTap: () => context.push(AppRoutes.teacherBookDetailPath(progress.bookId)),
      borderRadius: BorderRadius.circular(14),
      child: Container(
      width: 170,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral, width: 2),
        boxShadow: const [
          BoxShadow(color: AppColors.neutral, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large hero cover — fills the card width, tall portrait ratio
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 3 / 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAE2D2),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                      topLeft: Radius.circular(2),
                      bottomLeft: Radius.circular(2),
                    ),
                    border: Border.all(color: AppColors.neutral, width: 1),
                    image: progress.bookCoverUrl != null
                        ? DecorationImage(
                            image: NetworkImage(progress.bookCoverUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 4,
                        offset: const Offset(1, 2),
                      ),
                    ],
                  ),
                  child: progress.bookCoverUrl == null
                      ? const Center(child: AssetIcon(AppIcons.book, size: 56))
                      : null,
                ),
              ),
              // Left-edge "spine" shade
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(2),
                      bottomLeft: Radius.circular(2),
                    ),
                  ),
                ),
              ),
              // CEFR level badge (top-right corner of cover)
              if (progress.bookLevel != null && progress.bookLevel!.isNotEmpty)
                Positioned(
                  top: 6,
                  right: 6,
                  child: _CefrBadge(level: progress.bookLevel!),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Title
          Text(
            progress.bookTitle,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // Progress bar + %
          Row(
            children: [
              Expanded(
                child: AppProgressBar(
                  progress: progress.completionPercentage / 100,
                  fillColor: pctColor,
                  fillShadow: pctColor.withValues(alpha: 0.6),
                  backgroundColor: AppColors.neutral.withValues(alpha: 0.3),
                  height: 6,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${progress.completionPercentage.toStringAsFixed(0)}%',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: pctColor,
                ),
              ),
            ],
          ),
          // Quiz score (below, readable — no longer overlaid on cover)
          if (quiz != null) ...[
            const SizedBox(height: 4),
            _QuizScoreLine(quiz: quiz!),
          ],
        ],
      ),
    ),
    );
  }
}

// ─────────────────────────────────────────────
// VOCAB STATS CARD
// ─────────────────────────────────────────────

class _VocabStatsCard extends StatelessWidget {
  const _VocabStatsCard({
    required this.stats,
    required this.wordListsAsync,
    required this.onViewWordbank,
  });
  final StudentVocabStats stats;
  final AsyncValue<List<StudentWordListProgress>> wordListsAsync;
  final VoidCallback onViewWordbank;

  @override
  Widget build(BuildContext context) {
    final lists = wordListsAsync.valueOrNull ?? const [];

    final iconBox = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const AssetIcon(AppIcons.vocabulary, size: 28),
    );

    final heroText = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.black,
            height: 1.1,
          ),
          children: [
            TextSpan(text: '${stats.totalWords} '),
            TextSpan(
              text: 'words in wordbank',
              style: GoogleFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.neutralText,
              ),
            ),
          ],
        ),
      ),
    );

    // Breakdown — mastery status counts add up to totalWords.
    final breakdown = <Widget>[
      _VocabInline(
        value: '${stats.newCount}',
        label: 'New',
        color: Colors.blueGrey.shade600,
      ),
      _VocabInline(
        value: '${stats.learningCount}',
        label: 'Learning',
        color: Colors.orange.shade700,
      ),
      _VocabInline(
        value: '${stats.reviewingCount}',
        label: 'Reviewing',
        color: Colors.blue.shade700,
      ),
      _VocabInline(
        value: '${stats.masteredCount}',
        label: 'Mastered',
        color: Colors.green.shade700,
      ),
    ];

    final viewButton = TextButton.icon(
      onPressed: onViewWordbank,
      icon: const Icon(Icons.chevron_right),
      label: const Text('View'),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryDark,
        textStyle: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return PlayfulCard(
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // Wide: one row. Narrow: hero row + breakdown row below.
              final wide = constraints.maxWidth >= 640;
              if (wide) {
                return Row(
                  children: [
                    iconBox,
                    const SizedBox(width: 12),
                    heroText,
                    const SizedBox(width: 14),
                    Container(width: 1, height: 36, color: AppColors.neutral),
                    const SizedBox(width: 14),
                    for (var i = 0; i < breakdown.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      breakdown[i],
                    ],
                    const Spacer(),
                    viewButton,
                  ],
                );
              }
              // Narrow: hero on top, breakdown wraps below.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      iconBox,
                      const SizedBox(width: 12),
                      Expanded(child: heroText),
                      viewButton,
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    children: breakdown,
                  ),
                ],
              );
            },
          ),
          // Word Lists subsection (same panel, not a separate section)
          if (lists.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: AppColors.neutral),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Word Lists (${lists.length})',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neutralText,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: lists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _HorizontalWordListCard(progress: lists[index]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VocabInline extends StatelessWidget {
  const _VocabInline({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
            height: 1.1,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.neutralText,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// HORIZONTAL WORD LIST CARD
// ─────────────────────────────────────────────

class _HorizontalWordListCard extends ConsumerWidget {
  const _HorizontalWordListCard({required this.progress});
  final StudentWordListProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();
    final color = VocabularyColors.getCategoryColor(progress.wordListCategory);
    final wordsAsync = ref.watch(wordListWordsProvider(progress.wordListId));

    return PlayfulCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const AssetIcon(AppIcons.clipboard, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    progress.wordListName,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (progress.isComplete)
                  const AssetIcon(AppIcons.checkMark, size: 18),
              ],
            ),
            const SizedBox(height: 6),
            // Word chips — intrinsic height, keeps stars/accuracy right below
            wordsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (words) {
                final typedWords = words.cast<VocabularyWord>();
                if (typedWords.isEmpty) return const SizedBox.shrink();
                return Wrap(
                  spacing: 4,
                  runSpacing: 3,
                  children: typedWords.take(8).map((w) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      w.word,
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),).toList(),
                );
              },
            ),
            if (progress.bestAccuracy != null) const SizedBox(height: 6),
            if (progress.bestAccuracy != null)
              Row(
                children: [
                  ...List.generate(
                    3,
                    (i) {
                      final stars = progress.starCountWith(star3: settings.starRating3, star2: settings.starRating2, star1: settings.starRating1);
                      return Icon(
                        i < stars ? Icons.star : Icons.star_border,
                        size: 14,
                        color: i < stars
                            ? Colors.amber
                            : AppColors.neutralDark,
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${progress.bestAccuracy!.toStringAsFixed(0)}%',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _getAccuracyColor(progress.bestAccuracy!),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return Colors.green;
    if (accuracy >= 70) return Colors.blue;
    if (accuracy >= 50) return Colors.orange;
    return Colors.red;
  }
}

// ─────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────

class _EmptySection extends StatelessWidget {
  const _EmptySection({this.icon, this.assetPath, required this.message});
  final IconData? icon;
  final String? assetPath;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (assetPath != null)
            AssetIcon(assetPath!, size: 28)
          else
            Icon(icon, size: 24, color: AppColors.neutralDark),
          const SizedBox(width: 8),
          Text(
            message,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: AppColors.neutralText,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BADGE CARD
// ─────────────────────────────────────────────

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge});
  final UserBadge badge;

  @override
  Widget build(BuildContext context) {
    return PlayfulCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(10),
      borderColor: Colors.amber.withValues(alpha: 0.3),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge.badge.icon ?? '🏆',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    badge.badge.name,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              badge.badge.description ?? '',
              style: GoogleFonts.nunito(
                fontSize: 10,
                color: AppColors.neutralText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// COLLECTION CARD
// ─────────────────────────────────────────────

/// Student card collection — mirrors the /cards screen layout:
/// one section per myth category with a 4-column grid of owned + locked cards.
class _StudentCardCollection extends ConsumerWidget {
  const _StudentCardCollection({required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(cardCatalogProvider);
    final userCardsDyn = ref.watch(teacherStudentCardsProvider(studentId));
    return catalogAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (catalog) {
        final userCards = (userCardsDyn.valueOrNull ?? const [])
            .cast<UserCard>();
        if (userCards.isEmpty) return const SizedBox.shrink();

        final ownedIds = {for (final uc in userCards) uc.cardId};
        final totalOwned = userCards.length;
        final totalCards = catalog.length;

        // Group catalog by category
        final byCategory = <CardCategory, List<MythCard>>{};
        for (final c in catalog) {
          byCategory.putIfAbsent(c.category, () => []).add(c);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              title: 'Card Collection',
              assetPath: AppIcons.card,
              color: AppColors.cardEpic,
              trailing: '$totalOwned / $totalCards',
            ),
            const SizedBox(height: 8),
            for (final category in CardCategory.values)
              if (byCategory[category]?.isNotEmpty ?? false)
                _StudentCategoryGrid(
                  category: category,
                  cards: byCategory[category]!,
                  ownedIds: ownedIds,
                  userCards: userCards,
                ),
          ],
        );
      },
    );
  }
}

class _StudentCategoryGrid extends StatelessWidget {
  const _StudentCategoryGrid({
    required this.category,
    required this.cards,
    required this.ownedIds,
    required this.userCards,
  });

  final CardCategory category;
  final List<MythCard> cards;
  final Set<String> ownedIds;
  final List<UserCard> userCards;

  @override
  Widget build(BuildContext context) {
    final ownedCount = cards.where((c) => ownedIds.contains(c.id)).length;
    final categoryColor = CardColors.getCategoryColor(category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(category.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category.label,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$ownedCount / ${cards.length}',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: categoryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 4-column card grid
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 500 ? 4 : 3;
              const gap = 10.0;
              final cardWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              final cardHeight = cardWidth * 1.5; // portrait trading card
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final card in cards)
                    SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: _buildCardItem(card),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCardItem(MythCard card) {
    final isOwned = ownedIds.contains(card.id);
    if (isOwned) {
      final uc = userCards.firstWhere((u) => u.cardId == card.id);
      return MythCardWidget(
        card: card,
        quantity: uc.quantity,
        onTap: () {},
      );
    }
    return LockedCardWidget(card: card, onTap: () {});
  }
}
