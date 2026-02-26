import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/badge.dart';
import '../../../domain/entities/leaderboard_entry.dart';
import '../../providers/student_profile_popup_provider.dart';

/// Shows a student profile popup centered on screen.
void showStudentProfileDialog(BuildContext context, LeaderboardEntry entry) {
  showDialog(
    context: context,
    builder: (_) => StudentProfileDialog(entry: entry),
  );
}

class StudentProfileDialog extends ConsumerWidget {
  const StudentProfileDialog({super.key, required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extraAsync = ref.watch(studentProfileExtraProvider(entry.userId));

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.neutral, width: 2),
          boxShadow: [
            const BoxShadow(
              color: AppColors.neutral,
              offset: Offset(0, 6),
              blurRadius: 0,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.neutral,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // --- Instant section (from LeaderboardEntry) ---

            // Avatar
            _buildAvatar(),
            const SizedBox(height: 12),

            // Name
            Text(
              entry.fullName,
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.black,
              ),
            ),

            // Class name
            if (entry.className != null) ...[
              const SizedBox(height: 2),
              Text(
                entry.className!,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: AppColors.neutralText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 8),

            // League tier badge
            _buildTierBadge(),
            const SizedBox(height: 16),

            // Divider
            Container(height: 2, color: AppColors.neutral),
            const SizedBox(height: 16),

            // XP + Level row
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.bolt_rounded,
                    value: '${entry.totalXp}',
                    label: 'Total XP',
                    color: AppColors.waspDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatItem(
                    icon: Icons.star_rounded,
                    value: 'Lv. ${entry.level}',
                    label: entry.leagueTier.label,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Level progress bar
            _buildLevelProgress(),
            const SizedBox(height: 16),

            // Divider
            Container(height: 2, color: AppColors.neutral),
            const SizedBox(height: 16),

            // --- Async section (streak + cards) ---
            extraAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Could not load details',
                  style: GoogleFonts.nunito(
                    color: AppColors.neutralText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              data: (extra) => Column(
                children: [
                  // Streak row
                  Row(
                    children: [
                      Expanded(
                        child: _StatItem(
                          icon: Icons.local_fire_department_rounded,
                          value: '${extra.user.currentStreak}',
                          label: 'Day Streak',
                          color: AppColors.streakOrange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatItem(
                          icon: Icons.local_fire_department_rounded,
                          value: '${extra.user.longestStreak}',
                          label: 'Best Streak',
                          color: AppColors.streakOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Card collection
                  _buildCardSection(extra.cardStats.totalUniqueCards,
                      extra.cardStats.totalPacksOpened),

                  // Achievements
                  if (extra.badges.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildBadgesSection(extra.badges),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Close button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.neutral,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.neutralText,
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final tierColor = _getTierColor(entry.leagueTier);
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: tierColor, width: 3),
      ),
      child: ClipOval(
        child: entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty
            ? Image.network(
                entry.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildInitials(),
              )
            : _buildInitials(),
      ),
    );
  }

  Widget _buildInitials() {
    return Container(
      color: AppColors.secondary.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          entry.initials,
          style: GoogleFonts.nunito(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppColors.secondary,
          ),
        ),
      ),
    );
  }

  Widget _buildTierBadge() {
    final tierColor = _getTierColor(entry.leagueTier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: tierColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tierColor, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_rounded, size: 16, color: tierColor),
          const SizedBox(width: 6),
          Text(
            entry.leagueTier.label,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: tierColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelProgress() {
    final xpInLevel = entry.totalXp - _xpForLevel(entry.level);
    final xpNeeded = _xpForLevel(entry.level + 1) - _xpForLevel(entry.level);
    final progress = xpNeeded > 0 ? (xpInLevel / xpNeeded).clamp(0.0, 1.0) : 1.0;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.neutral.withValues(alpha: 0.3),
            color: _getTierColor(entry.leagueTier),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Level ${entry.level} — ${(progress * 100).toInt()}% to next level',
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.neutralText,
          ),
        ),
      ],
    );
  }

  Widget _buildCardSection(int uniqueCards, int packsOpened) {
    const totalCards = AppConstants.totalCardCount;
    final progress = uniqueCards / totalCards;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardEpic.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.cardEpic.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.collections_bookmark_rounded,
                  size: 20, color: AppColors.cardEpic),
              const SizedBox(width: 8),
              Text(
                'Card Collection',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.black,
                ),
              ),
              const Spacer(),
              Text(
                '$uniqueCards / $totalCards',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: AppColors.cardEpic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.neutral.withValues(alpha: 0.3),
              color: AppColors.cardEpic,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$packsOpened packs opened',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.neutralText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesSection(List<UserBadge> badges) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Achievements',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.black,
                ),
              ),
              const Spacer(),
              Text(
                '${badges.length}',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: badges.map((b) => _BadgeChip(badge: b)).toList(),
          ),
        ],
      ),
    );
  }

  /// XP threshold for a given level: level * (level + 1) * 50
  /// But we compute backwards: threshold(n) = n * (n-1) * 50
  /// Actually: level n starts at n*(n-1)*50 XP
  static int _xpForLevel(int level) {
    if (level <= 1) return 0;
    return (level - 1) * level * 50;
  }

  static Color _getTierColor(LeagueTier tier) {
    return switch (tier) {
      LeagueTier.diamond => const Color(0xFF00BFFF),
      LeagueTier.platinum => const Color(0xFFE5E4E2),
      LeagueTier.gold => const Color(0xFFFFD700),
      LeagueTier.silver => const Color(0xFFC0C0C0),
      LeagueTier.bronze => const Color(0xFFCD7F32),
    };
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: AppColors.black,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: AppColors.neutralText,
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

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge});

  final UserBadge badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: badge.badge.description,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.neutral, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(badge.badge.icon ?? '🏆', style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              badge.badge.name,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
