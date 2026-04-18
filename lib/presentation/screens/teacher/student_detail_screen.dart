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
import '../../widgets/cards/myth_card_widget.dart';
import '../../widgets/common/league_tier_badge.dart';
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
              child: LayoutBuilder(
                builder: (context, outer) {
                  final wide = outer.maxWidth >= 1100;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: header + streak calendar
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _StudentHeader(user: student),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: _StudentStreakCalendar(
                                studentId: studentId,
                                createdAt: student.createdAt,
                                currentStreak: student.currentStreak,
                                longestStreak: student.longestStreak,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _StudentHeader(user: student),
                        const SizedBox(height: 16),
                        _StudentStreakCalendar(
                          studentId: studentId,
                          createdAt: student.createdAt,
                          currentStreak: student.currentStreak,
                          longestStreak: student.longestStreak,
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Reading Progress (full width)
                      _buildReadingSection(
                          context, progressAsync, quizResultsAsync),
                      const SizedBox(height: 24),

                      // Vocabulary (full width)
                      _buildVocabSection(
                          context, vocabStatsAsync, wordListProgressAsync),
                      const SizedBox(height: 24),

                      // Achievements + Card Collection — side by side
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child:
                                  _StudentAchievementsSection(studentId: studentId),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child:
                                  _StudentCardCollection(studentId: studentId),
                            ),
                          ],
                        )
                      else ...[
                        _StudentAchievementsSection(studentId: studentId),
                        const SizedBox(height: 24),
                        _StudentCardCollection(studentId: studentId),
                      ],
                      const SizedBox(height: 32),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReadingSection(
    BuildContext context,
    AsyncValue<List<StudentBookProgress>> progressAsync,
    AsyncValue<List<StudentQuizProgress>> quizResultsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        progressAsync.when(
          loading: () => _SectionTitle(
              title: 'Reading Progress',
              assetPath: AppIcons.book,
              color: Colors.blue),
          error: (_, __) => _SectionTitle(
              title: 'Reading Progress',
              assetPath: AppIcons.book,
              color: Colors.blue),
          data: (list) {
            final started =
                list.where((p) => p.completionPercentage > 0).length;
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
            final filtered = progressList
                .where((p) => p.completionPercentage > 0)
                .toList()
              ..sort((a, b) {
                final aDone = a.isCompleted ? 1 : 0;
                final bDone = b.isCompleted ? 1 : 0;
                if (aDone != bDone) return aDone - bDone;
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
      ],
    );
  }

  Widget _buildVocabSection(
    BuildContext context,
    AsyncValue<StudentVocabStats> vocabStatsAsync,
    AsyncValue<List<StudentWordListProgress>> wordListProgressAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
            title: 'Vocabulary Progress',
            assetPath: AppIcons.vocabulary,
            color: Colors.purple),
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
      ],
    );
  }
}

// ─────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────

class _StudentHeader extends ConsumerWidget {
  const _StudentHeader({required this.user});
  final domain.User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classRank =
        ref.watch(teacherStudentClassRankProvider(user.id)).valueOrNull;
    final schoolRank =
        ref.watch(teacherStudentSchoolRankProvider(user.id)).valueOrNull;

    // Class total: walk the teacher's classes list and match studentId.
    final classesAsync = ref.watch(currentTeacherClassesProvider);
    int? classTotal;
    if (user.classId != null) {
      final list = classesAsync.valueOrNull ?? const [];
      for (final c in list) {
        if (c.id == user.classId) {
          classTotal = c.studentCount;
          break;
        }
      }
    }
    // School total via the My School summary.
    final schoolTotal =
        ref.watch(schoolSummaryProvider).valueOrNull?.totalStudents;

    return PlayfulCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Large square avatar
          SizedBox(
            width: 140,
            height: 140,
            child: AvatarWidget(
              avatar: user.avatarEquippedCache != null
                  ? EquippedAvatarModel.fromJson(user.avatarEquippedCache!)
                      .toEntity()
                  : const EquippedAvatar(),
              size: 140,
              fallbackInitials: user.initials,
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: GoogleFonts.nunito(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.black,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.studentNumber != null)
                  Text(
                    'Student #${user.studentNumber}',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: AppColors.neutralText,
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (classRank != null)
                      _StatChip(
                        icon: Icons.class_,
                        value: classTotal != null
                            ? 'Class rank: $classRank/$classTotal'
                            : 'Class rank: $classRank',
                        color: Colors.blue.shade700,
                      ),
                    if (schoolRank != null)
                      _StatChip(
                        icon: Icons.school_rounded,
                        value: schoolTotal != null
                            ? 'School rank: $schoolRank/$schoolTotal'
                            : 'School rank: $schoolRank',
                        color: Colors.green.shade700,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Level badge + league icon stack on the right
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LevelBadge(level: user.level),
              const SizedBox(height: 8),
              _LeagueIconBadge(tier: user.leagueTier),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact square league tile shown under the level badge — same footprint
/// as _LevelBadge so the pair forms a tidy column on the right edge.
class _LeagueIconBadge extends StatelessWidget {
  const _LeagueIconBadge({required this.tier});
  final LeagueTier tier;

  @override
  Widget build(BuildContext context) {
    final color = LeagueTierBadge.tierColor(tier);
    return Tooltip(
      message: '${tier.label} league',
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        ),
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          LeagueTierBadge.tierAsset(tier),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// Compact monthly activity calendar for a student, shown to the right
/// of the header on wide screens. Pulls monthly login dates via the
/// teacher-scoped provider. Navigate previous/next month with arrows.
class _StudentStreakCalendar extends ConsumerStatefulWidget {
  const _StudentStreakCalendar({
    required this.studentId,
    required this.createdAt,
    required this.currentStreak,
    required this.longestStreak,
  });

  final String studentId;
  final DateTime? createdAt;
  final int currentStreak;
  final int longestStreak;

  @override
  ConsumerState<_StudentStreakCalendar> createState() =>
      _StudentStreakCalendarState();
}

class _StudentStreakCalendarState
    extends ConsumerState<_StudentStreakCalendar> {
  late int _displayYear;
  late int _displayMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayYear = now.year;
    _displayMonth = now.month;
  }

  bool _canGoBack() {
    final created = widget.createdAt ?? DateTime(2024, 1, 1);
    return _displayYear > created.year ||
        (_displayYear == created.year && _displayMonth > created.month);
  }

  bool _canGoForward() {
    final now = DateTime.now();
    return _displayYear < now.year ||
        (_displayYear == now.year && _displayMonth < now.month);
  }

  void _prev() {
    if (!_canGoBack()) return;
    setState(() {
      _displayMonth--;
      if (_displayMonth < 1) {
        _displayMonth = 12;
        _displayYear--;
      }
    });
  }

  void _next() {
    if (!_canGoForward()) return;
    setState(() {
      _displayMonth++;
      if (_displayMonth > 12) {
        _displayMonth = 1;
        _displayYear++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final datesAsync = ref.watch(teacherStudentMonthlyLoginsProvider((
      studentId: widget.studentId,
      year: _displayYear,
      month: _displayMonth,
    )));
    final dates = datesAsync.valueOrNull ?? const <DateTime, bool>{};

    final firstOfMonth = DateTime(_displayYear, _displayMonth, 1);
    final daysInMonth =
        DateTime(_displayYear, _displayMonth + 1, 0).day;
    // Monday=1..Sunday=7 → leading blanks before day 1
    final leadingBlanks = (firstOfMonth.weekday - 1);
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final today = DateTime.now();
    final monthLabel = _monthLabel(_displayMonth);
    final activeCount = dates.length;

    return PlayfulCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: month nav + active count
          Row(
            children: [
              const AssetIcon(AppIcons.fire, size: 22),
              const SizedBox(width: 6),
              Text(
                'Student Activity',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                ),
              ),
              const Spacer(),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: _canGoBack() ? _prev : null,
                icon: const Icon(Icons.chevron_left, size: 20),
              ),
              Text(
                '$monthLabel $_displayYear',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neutralText,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: _canGoForward() ? _next : null,
                icon: const Icon(Icons.chevron_right, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$activeCount active ${activeCount == 1 ? 'day' : 'days'} this month',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutralText,
                  ),
                ),
              ),
              if (widget.longestStreak > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AssetIcon(AppIcons.fire, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      'Longest streak: ${widget.longestStreak} ${widget.longestStreak == 1 ? 'day' : 'days'}',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.streakOrange,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Weekday header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                SizedBox(
                  width: 30,
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.neutralText,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Day grid
          for (int row = 0; row < rows; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (int col = 0; col < 7; col++)
                    _buildDayCell(row, col, leadingBlanks, daysInMonth,
                        dates, today),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayCell(
    int row,
    int col,
    int leadingBlanks,
    int daysInMonth,
    Map<DateTime, bool> dates,
    DateTime today,
  ) {
    const size = 30.0;
    final index = row * 7 + col;
    final dayNum = index - leadingBlanks + 1;
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const SizedBox(width: size, height: size);
    }
    final date = DateTime(_displayYear, _displayMonth, dayNum);
    final key = DateTime(date.year, date.month, date.day);
    final isActive = dates.containsKey(key);
    final isFreeze = dates[key] == true;
    final isToday = key.year == today.year &&
        key.month == today.month &&
        key.day == today.day;

    // Login day (not freeze): solid orange circle + fire icon.
    if (isActive && !isFreeze) {
      return SizedBox(
        width: size,
        height: size,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.streakOrange,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(4),
          child: const AssetIcon(AppIcons.fire, size: 20),
        ),
      );
    }
    // Freeze day: solid blue circle + fire-blue icon.
    if (isFreeze) {
      return SizedBox(
        width: size,
        height: size,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.gemBlue,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(5),
          child: Image.asset(
            'assets/icons/fire_blue_256.png',
            width: 18,
            height: 18,
            fit: BoxFit.contain,
          ),
        ),
      );
    }
    // Today but not active: orange outline + day number.
    if (isToday) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.streakOrange, width: 2),
        ),
        child: Text(
          '$dayNum',
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.streakOrange,
          ),
        ),
      );
    }
    // Missed day.
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          '$dayNum',
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.gray400,
          ),
        ),
      ),
    );
  }

  String _monthLabel(int m) {
    const labels = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return labels[m - 1];
  }
}

/// Small pill showing the student's league tier.
/// Prominent level badge used next to the avatar on the student header.
class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.wasp.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.wasp, width: 2.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'LVL',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.waspDark,
              letterSpacing: 1.0,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$level',
            style: GoogleFonts.nunito(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.waspDark,
              height: 1.0,
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
// INLINE QUIZ PILL (inside a reading progress book card)
// ─────────────────────────────────────────────

class _StudentAchievementsSection extends ConsumerStatefulWidget {
  const _StudentAchievementsSection({required this.studentId});
  final String studentId;

  @override
  ConsumerState<_StudentAchievementsSection> createState() =>
      _StudentAchievementsSectionState();
}

class _StudentAchievementsSectionState
    extends ConsumerState<_StudentAchievementsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final groupsAsync =
        ref.watch(studentAchievementGroupsProvider(widget.studentId));
    return groupsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (allGroups) {
        if (allGroups.isEmpty) return const SizedBox.shrink();
        // Same preview rule as the student profile (up to 3 tracks).
        final preview = <AchievementGroup>[
          ...allGroups.where((g) => !g.isMaxed && g.currentLevel >= 1).take(3),
        ];
        if (preview.length < 3) {
          preview.addAll(allGroups
              .where((g) =>
                  !g.isMaxed && g.currentLevel == 0 && g.currentValue > 0)
              .take(3 - preview.length));
        }
        if (preview.length < 3) {
          preview.addAll(
              allGroups.where((g) => g.isMaxed).take(3 - preview.length));
        }

        final earnedCount =
            allGroups.fold<int>(0, (s, g) => s + g.currentLevel);
        final totalCount = allGroups.fold<int>(0, (s, g) => s + g.maxLevel);
        final shown = _expanded ? allGroups : preview;
        final hiddenCount = allGroups.length - preview.length;

        return PlayfulCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                title: 'Achievements',
                assetPath: AppIcons.trophy,
                color: Colors.amber,
                trailing: '$earnedCount / $totalCount earned',
              ),
              const SizedBox(height: 8),
              for (final g in shown) AchievementGroupRow(group: g),
              if (hiddenCount > 0)
                _ShowAllButton(
                  expanded: _expanded,
                  hiddenCount: hiddenCount,
                  onToggle: () => setState(() => _expanded = !_expanded),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ShowAllButton extends StatelessWidget {
  const _ShowAllButton({
    required this.expanded,
    required this.hiddenCount,
    required this.onToggle,
  });

  final bool expanded;
  final int hiddenCount;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextButton.icon(
        onPressed: onToggle,
        icon: Icon(
          expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          size: 18,
        ),
        label: Text(expanded ? 'Show less' : 'Show all ($hiddenCount more)'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          textStyle: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
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
class _StudentCardCollection extends ConsumerStatefulWidget {
  const _StudentCardCollection({required this.studentId});
  final String studentId;

  @override
  ConsumerState<_StudentCardCollection> createState() =>
      _StudentCardCollectionState();
}

class _StudentCardCollectionState
    extends ConsumerState<_StudentCardCollection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(cardCatalogProvider);
    final userCardsDyn = ref.watch(teacherStudentCardsProvider(widget.studentId));
    return catalogAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (catalog) {
        final userCards = (userCardsDyn.valueOrNull ?? const [])
            .cast<UserCard>();
        if (userCards.isEmpty) return const SizedBox.shrink();

        // Sort by rarity desc (legendary → common), break ties by name.
        final sorted = [...userCards]
          ..sort((a, b) {
            final rarityCmp =
                b.card.rarity.index.compareTo(a.card.rarity.index);
            if (rarityCmp != 0) return rarityCmp;
            return a.card.name.compareTo(b.card.name);
          });
        final totalOwned = userCards.length;
        final totalCards = catalog.length;
        const previewCount = 4;
        final shown = _expanded ? sorted : sorted.take(previewCount).toList();
        final hiddenCount = sorted.length - previewCount;

        return PlayfulCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                title: 'Card Collection',
                assetPath: AppIcons.card,
                color: AppColors.cardEpic,
                trailing: '$totalOwned / $totalCards',
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  // Always 4 columns so the preview shows one tight row.
                  const columns = 4;
                  const gap = 10.0;
                  final cardWidth =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  final cardHeight = cardWidth * 1.5;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final uc in shown)
                        SizedBox(
                          width: cardWidth,
                          height: cardHeight,
                          child: MythCardWidget(
                            card: uc.card,
                            quantity: uc.quantity,
                            onTap: () {},
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (hiddenCount > 0)
                _ShowAllButton(
                  expanded: _expanded,
                  hiddenCount: hiddenCount,
                  onToggle: () => setState(() => _expanded = !_expanded),
                ),
            ],
          ),
        );
      },
    );
  }
}
