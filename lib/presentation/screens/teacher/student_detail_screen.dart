import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../app/theme.dart';
import '../../../core/utils/extensions/context_extensions.dart';
import '../../../core/utils/level_helper.dart';
import '../../../data/models/avatar/equipped_avatar_model.dart';
import '../../../domain/entities/avatar.dart';
import '../../../domain/entities/badge.dart';
import '../../../domain/entities/card.dart';
import '../../../domain/entities/user.dart' as domain;
import '../../../domain/entities/vocabulary.dart';
import '../../../domain/repositories/teacher_repository.dart';
import '../../providers/book_quiz_provider.dart';
import '../../providers/teacher_provider.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/common/error_state_widget.dart';
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
                  // 1. Header + Level side by side on wide, stacked on narrow
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 500) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _StudentHeader(user: student)),
                            const SizedBox(width: 16),
                            Expanded(child: _LevelXpCard(user: student)),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          _StudentHeader(user: student),
                          const SizedBox(height: 16),
                          _LevelXpCard(user: student),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // 3. Reading Progress (horizontal)
                  _SectionTitle(title: 'Reading Progress', icon: Icons.menu_book, color: Colors.blue),
                  const SizedBox(height: 12),
                  progressAsync.when(
                    loading: () => const SizedBox(
                      height: 160,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => const Text('Error loading progress'),
                    data: (progressList) {
                      final filtered = progressList
                          .where((p) => p.completionPercentage > 0)
                          .toList();
                      if (filtered.isEmpty) {
                        return _EmptySection(
                          icon: Icons.menu_book_outlined,
                          message: 'No reading activity yet',
                        );
                      }
                      return SizedBox(
                        height: 160,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) =>
                              _HorizontalBookCard(progress: filtered[index]),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // 4. Quiz Results
                  _SectionTitle(title: 'Quiz Results', icon: Icons.quiz, color: Colors.green),
                  const SizedBox(height: 12),
                  _QuizResultsSection(studentId: studentId),
                  const SizedBox(height: 24),

                  // 5. Vocabulary Progress
                  _SectionTitle(title: 'Vocabulary Progress', icon: Icons.abc, color: Colors.purple),
                  const SizedBox(height: 12),
                  vocabStatsAsync.when(
                    loading: () => const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => const Text('Error loading stats'),
                    data: (stats) => _VocabStatsCard(stats: stats),
                  ),
                  const SizedBox(height: 16),

                  // 6. Word Lists (horizontal)
                  wordListProgressAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (lists) {
                      if (lists.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(
                            title: 'Word Lists (${lists.length})',
                            icon: Icons.list_alt,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 150,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: lists.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) =>
                                  _HorizontalWordListCard(
                                      progress: lists[index]),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // 7. Badges
                  badgesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (badges) {
                      final typedBadges = badges.cast<UserBadge>();
                      if (typedBadges.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(
                            title: 'Badges (${typedBadges.length})',
                            icon: Icons.military_tech,
                            color: Colors.amber,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 90,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: typedBadges.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) =>
                                  _BadgeCard(badge: typedBadges[index]),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),

                  // 8. Card Collection
                  cardsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (cards) {
                      final typedCards = cards.cast<UserCard>();
                      if (typedCards.isEmpty) return const SizedBox.shrink();
                      // Sort by rarity descending
                      final sorted = [...typedCards]
                        ..sort((a, b) =>
                            b.card.rarity.index.compareTo(a.card.rarity.index));
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(
                            title: 'Card Collection (${sorted.length})',
                            icon: Icons.collections_bookmark,
                            color: AppColors.cardEpic,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 110,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: sorted.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) =>
                                  _CollectionCard(userCard: sorted[index]),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

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
                    _StatChip(
                      icon: Icons.local_fire_department,
                      value: '${user.currentStreak}',
                      color: Colors.orange,
                    ),
                    _StatChip(
                      icon: Icons.emoji_events,
                      value: '${user.longestStreak} best',
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
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
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
// LEVEL & XP (copied style from student profile)
// ─────────────────────────────────────────────

class _LevelXpCard extends StatelessWidget {
  const _LevelXpCard({required this.user});
  final domain.User user;

  @override
  Widget build(BuildContext context) {
    final progress = LevelHelper.progress(user.xp, user.level);
    final xpIn = LevelHelper.xpInCurrentLevel(user.xp, user.level);
    final xpNeeded = LevelHelper.xpToNextLevel(user.level);

    return PlayfulCard(
      borderColor: AppColors.wasp.withValues(alpha: 0.3),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.wasp.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.wasp, width: 2),
                ),
                child: Text(
                  'LVL ${user.level}',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: AppColors.waspDark,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, size: 18, color: AppColors.wasp),
                  const SizedBox(width: 4),
                  Text(
                    '${user.xp} XP',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.neutral.withValues(alpha: 0.3),
              color: AppColors.wasp,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$xpIn / $xpNeeded XP to next level',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.neutralText,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SECTION TITLE
// ─────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
      ],
    );
  }
}

// ─────────────────────────────────────────────
// HORIZONTAL BOOK CARD
// ─────────────────────────────────────────────

class _HorizontalBookCard extends StatelessWidget {
  const _HorizontalBookCard({required this.progress});
  final StudentBookProgress progress;

  @override
  Widget build(BuildContext context) {
    return PlayfulCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Book cover
                Container(
                  width: 40,
                  height: 56,
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                    image: progress.bookCoverUrl != null
                        ? DecorationImage(
                            image: NetworkImage(progress.bookCoverUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: progress.bookCoverUrl == null
                      ? const Icon(Icons.book, size: 20)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        progress.bookTitle,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${progress.completedChapters}/${progress.totalChapters} chapters',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: AppColors.neutralText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.completionPercentage / 100,
                backgroundColor: AppColors.neutral.withValues(alpha: 0.3),
                color: ScoreColors.getProgressColor(progress.completionPercentage),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${progress.completionPercentage.toStringAsFixed(0)}%',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: ScoreColors.getProgressColor(progress.completionPercentage),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 12, color: AppColors.neutralText),
                    const SizedBox(width: 2),
                    Text(
                      TimeFormatter.formatReadingTime(progress.totalReadingTime),
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: AppColors.neutralText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
  const _VocabStatsCard({required this.stats});
  final StudentVocabStats stats;

  @override
  Widget build(BuildContext context) {
    return PlayfulCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _VocabStat(value: '${stats.totalWords}', label: 'Words', icon: Icons.abc, color: Colors.blue),
          _VocabStat(value: '${stats.masteredCount}', label: 'Mastered', icon: Icons.check_circle, color: Colors.green),
          _VocabStat(value: '${stats.learningCount}', label: 'Learning', icon: Icons.school, color: Colors.orange),
          _VocabStat(value: '${stats.totalSessions}', label: 'Sessions', icon: Icons.replay, color: Colors.purple),
        ],
      ),
    );
  }
}

class _VocabStat extends StatelessWidget {
  const _VocabStat({
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

// ─────────────────────────────────────────────
// HORIZONTAL WORD LIST CARD
// ─────────────────────────────────────────────

class _HorizontalWordListCard extends ConsumerWidget {
  const _HorizontalWordListCard({required this.progress});
  final StudentWordListProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = VocabularyColors.getCategoryColor(
      WordListCategory.fromDbValue(progress.wordListCategory),
    );
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
                  child: Icon(Icons.list_alt, color: color, size: 18),
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
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
              ],
            ),
            const SizedBox(height: 6),
            // Word chips
            wordsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (words) {
                final typedWords = words.cast<VocabularyWord>();
                if (typedWords.isEmpty) return const SizedBox.shrink();
                return Expanded(
                  child: Wrap(
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
                  ),
                );
              },
            ),
            if (progress.bestAccuracy != null)
              Row(
                children: [
                  ...List.generate(
                    3,
                    (i) => Icon(
                      i < progress.starCount ? Icons.star : Icons.star_border,
                      size: 14,
                      color: i < progress.starCount
                          ? Colors.amber
                          : AppColors.neutralDark,
                    ),
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
// QUIZ RESULTS (horizontal)
// ─────────────────────────────────────────────

class _QuizResultsSection extends ConsumerWidget {
  const _QuizResultsSection({required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizResultsAsync = ref.watch(studentQuizResultsProvider(studentId));

    return quizResultsAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Text('Error loading quiz results'),
      data: (results) {
        if (results.isEmpty) {
          return _EmptySection(
            icon: Icons.quiz_outlined,
            message: 'No quiz attempts yet',
          );
        }

        return SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final result = results[index];
              final scoreColor = result.isPassing
                  ? Colors.green
                  : (result.bestPercentage >= 50 ? Colors.orange : Colors.red);

              return PlayfulCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: 180,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: scoreColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          result.isPassing
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: scoreColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              result.bookTitle,
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${result.bestPercentage.round()}% • ${result.totalAttempts} tries',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: scoreColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.userCard});
  final UserCard userCard;

  @override
  Widget build(BuildContext context) {
    final rarityColor = _getRarityColor(userCard.card.rarity);

    return PlayfulCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(10),
      borderColor: rarityColor.withValues(alpha: 0.4),
      child: SizedBox(
        width: 100,
        child: Column(
          children: [
            // Card image or icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: rarityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                image: userCard.card.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(userCard.card.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: userCard.card.imageUrl == null
                  ? Icon(Icons.collections_bookmark, color: rarityColor, size: 24)
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              userCard.card.name,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              userCard.card.rarity.name.toUpperCase(),
              style: GoogleFonts.nunito(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: rarityColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRarityColor(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.common:
        return AppColors.cardCommon;
      case CardRarity.rare:
        return AppColors.cardRare;
      case CardRarity.epic:
        return AppColors.cardEpic;
      case CardRarity.legendary:
        return AppColors.cardLegendary;
    }
  }
}
