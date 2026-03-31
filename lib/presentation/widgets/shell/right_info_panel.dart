import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/daily_quest.dart';
import '../../../domain/entities/system_settings.dart';
import '../../providers/daily_review_provider.dart';
import '../../providers/card_provider.dart';
import '../../providers/daily_quest_provider.dart';
import '../../providers/reader_provider.dart';
import '../../providers/system_settings_provider.dart';
import '../../providers/user_provider.dart';
import '../common/streak_status_dialog.dart';

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
                    const SizedBox(height: 16),
                  ],
                  if (isReader) ...[
                    const _ReaderSettingsCard(),
                    const SizedBox(height: 16),
                  ],
                  if (isQuests) ...[
                    const _MonthlyQuestSidebarCard(),
                    const SizedBox(height: 16),
                    const _MonthlyBadgesSidebarCard(),
                  ] else ...[
                    const _LeagueCard(),
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
    final settings = ref.watch(systemSettingsProvider).valueOrNull ??
        SystemSettings.defaults();
    final calendarDaysAsync = ref.watch(loginDatesProvider);

    final streak = user?.currentStreak ?? 0;
    final coins = user?.coins ?? 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Streak
        GestureDetector(
          onTap: () {
            if (user != null) {
              final calendarDays = calendarDaysAsync.valueOrNull ?? {};
              showDialog(
                context: context,
                builder: (context) => StreakStatusDialog(
                  currentStreak: user.currentStreak,
                  longestStreak: user.longestStreak,
                  calendarDays: calendarDays,
                  streakFreezeCount: user.streakFreezeCount,
                  streakFreezeMax: settings.streakFreezeMax,
                  streakFreezePrice: settings.streakFreezePrice,
                  userCoins: user.coins,
                ),
              );
            }
          },
          child: _StatChip(
            icon: Icons.local_fire_department,
            iconColor: AppColors.streakOrange,
            value: streak,
          ),
        ),
        const SizedBox(width: 12),
        // Coins
        _StatChip(
          icon: Icons.monetization_on_rounded,
          iconColor: AppColors.cardLegendary,
          value: coins,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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

  IconData _tierIcon(LeagueTier tier) {
    switch (tier) {
      case LeagueTier.bronze:
        return Icons.shield_outlined;
      case LeagueTier.silver:
        return Icons.shield_rounded;
      case LeagueTier.gold:
        return Icons.emoji_events_rounded;
      case LeagueTier.platinum:
        return Icons.workspace_premium_rounded;
      case LeagueTier.diamond:
        return Icons.diamond_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userControllerProvider).valueOrNull;
    final tier = user?.leagueTier ?? LeagueTier.bronze;
    final color = _tierColor(tier);

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
                  'VIEW LEAGUE',
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_tierIcon(tier), color: color, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "This week's leaderboard is active",
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: AppColors.neutralText,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Quests',
                style: GoogleFonts.nunito(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                ),
              ),
              Text(
                'VIEW ALL',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondary,
                ),
              ),
            ],
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
              return Column(
                children: [
                  for (int i = 0; i < quests.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _QuestRow(progress: quests[i]),
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

class _QuestRow extends StatelessWidget {
  const _QuestRow({required this.progress});

  final DailyQuestProgress progress;

  IconData _questIcon(String questType) {
    switch (questType) {
      case 'earn_xp':
        return Icons.bolt_rounded;
      case 'spend_time':
        return Icons.timer_rounded;
      case 'earn_combo_xp':
        return Icons.bolt_rounded;
      case 'complete_chapters':
        return Icons.menu_book_rounded;
      case 'review_words':
        return Icons.translate_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  Color _questColor(String questType) {
    switch (questType) {
      case 'earn_xp':
        return AppColors.cardLegendary;
      case 'spend_time':
        return AppColors.secondary;
      case 'earn_combo_xp':
        return AppColors.cardLegendary;
      case 'complete_chapters':
        return AppColors.primary;
      case 'review_words':
        return AppColors.cardEpic;
      default:
        return AppColors.neutralText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final quest = progress.quest;
    final ratio = quest.goalValue > 0
        ? (progress.currentValue / quest.goalValue).clamp(0.0, 1.0)
        : 0.0;
    final color = _questColor(quest.questType);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(_questIcon(quest.questType), color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                quest.title,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  backgroundColor: AppColors.neutral,
                  color: progress.isCompleted ? AppColors.primary : color,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${progress.currentValue} / ${quest.goalValue}',
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
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
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
                child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
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
    final packCost = ref.watch(systemSettingsProvider).valueOrNull?.packCost ?? 100;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.packOpening),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF6B4CFE), Color(0xFFD355FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasPacks ? 'PACKS AVAILABLE' : 'GET NEW CARDS',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.8),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasPacks ? 'Open Pack ($packs)' : 'Buy Booster Pack',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: hasPacks
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.style_rounded, color: AppColors.cardEpic, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '$packs',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.cardEpic,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on_rounded, color: AppColors.wasp, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '$packCost',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.black,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
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

class _MonthlyQuestSidebarCard extends StatelessWidget {
  const _MonthlyQuestSidebarCard();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthName = DateFormat('MMMM').format(now);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final daysLeft = lastDay.difference(now).inDays;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.streakOrange,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC76A00),
            offset: const Offset(0, 3),
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
              Icon(Icons.access_time_rounded,
                  size: 13, color: Colors.white.withValues(alpha: 0.8)),
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
                  'Complete 20 quests',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    color: Colors.white,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '0 / 20',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.8),
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

// ─── Monthly Badges Sidebar Card (Quests route) ───

class _MonthlyBadgesSidebarCard extends StatelessWidget {
  const _MonthlyBadgesSidebarCard();

  @override
  Widget build(BuildContext context) {
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
            'MONTHLY BADGES',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: AppColors.neutralText,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Earn your first badge!',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Complete each month's challenge to earn exclusive badges",
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: AppColors.neutralText,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.streakOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.military_tech_rounded,
                size: 36,
                color: AppColors.streakOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
