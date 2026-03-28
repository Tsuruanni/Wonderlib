import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../app/theme.dart';
import '../../../data/models/avatar/equipped_avatar_model.dart';
import '../../../domain/entities/leaderboard_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leaderboard_provider.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/student_profile_dialog.dart';
import '../../widgets/common/error_state_widget.dart';
import '../../widgets/common/top_navbar.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(leaderboardScopeProvider);
    final displayAsync = ref.watch(leaderboardDisplayProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const SafeArea(bottom: false, child: TopNavbar()),

          // Header with scope toggle
          _LeaderboardHeader(
            scope: scope,
            onScopeChanged: (s) =>
                ref.read(leaderboardScopeProvider.notifier).state = s,
          ),

          // Weekly indicator + zone banner for league mode
          if (scope == LeaderboardScope.leagueScope) ...[
            const _WeeklyIndicator(),
            displayAsync.whenOrNull(
              data: (state) => _ZonePreviewBanner(state: state),
            ) ?? const SizedBox.shrink(),
          ],

          // Content
          Expanded(
            child: displayAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorStateWidget(
                message: 'Could not load leaderboard',
                onRetry: () => ref.invalidate(leaderboardDisplayProvider),
              ),
              data: (state) {
                if (state.isEmpty) return _buildEmptyState();
                return _LeaderboardList(
                  state: state,
                  showClassName:
                      scope != LeaderboardScope.classScope,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_outlined,
              color: AppColors.neutralDark, size: 64),
          const SizedBox(height: 16),
          Text(
            'No students yet',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.neutralText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start reading to earn XP and climb the ranks!',
            style: GoogleFonts.nunito(
              color: AppColors.neutralText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardHeader extends StatelessWidget {
  const _LeaderboardHeader({
    required this.scope,
    required this.onScopeChanged,
  });

  final LeaderboardScope scope;
  final ValueChanged<LeaderboardScope> onScopeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded,
              color: AppColors.waspDark, size: 26),
          const SizedBox(width: 10),
          Text(
            'Leaderboard',
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.black,
            ),
          ),
          const Spacer(),
          // Scope toggle
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.neutral, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ToggleButton(
                  label: 'League',
                  isActive: scope == LeaderboardScope.leagueScope,
                  onTap: () => onScopeChanged(LeaderboardScope.leagueScope),
                ),
                _ToggleButton(
                  label: 'Class',
                  isActive: scope == LeaderboardScope.classScope,
                  onTap: () => onScopeChanged(LeaderboardScope.classScope),
                ),
                _ToggleButton(
                  label: 'School',
                  isActive: scope == LeaderboardScope.schoolScope,
                  onTap: () => onScopeChanged(LeaderboardScope.schoolScope),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.waspDark : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isActive ? Colors.white : AppColors.neutralText,
          ),
        ),
      ),
    );
  }
}

class _WeeklyIndicator extends ConsumerWidget {
  const _WeeklyIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    // Monday of current week
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    // Sunday of current week
    final weekEnd = weekStart.add(const Duration(days: 6));
    final dateFormat = DateFormat('MMM d');

    // Show tier name from current user
    final userAsync = ref.watch(currentUserProvider);
    final tierLabel = userAsync.whenOrNull(
      data: (user) => user?.leagueTier.label,
    ) ?? 'League';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCC80), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today_rounded,
              color: Color(0xFFF57C00), size: 16),
          const SizedBox(width: 8),
          Text(
            '$tierLabel League  •  ${dateFormat.format(weekStart)} – ${dateFormat.format(weekEnd)}',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFF57C00),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZonePreviewBanner extends StatelessWidget {
  const _ZonePreviewBanner({required this.state});

  final LeaderboardDisplayState state;

  @override
  Widget build(BuildContext context) {
    // Find current user's rank
    final userEntry = state.entries
        .where((e) => state.isCurrentUser(e.userId))
        .firstOrNull;
    final rank = userEntry?.rank ?? state.currentUserEntry?.rank;
    if (rank == null || state.entries.isEmpty) return const SizedBox.shrink();

    final totalEntries = state.leagueTotalCount ?? state.totalCount;
    final zoneSize = leagueZoneSize(totalEntries);

    if (rank <= zoneSize) {
      return _buildBanner(
        icon: Icons.arrow_upward_rounded,
        text: "You're in the promotion zone! Keep it up!",
        bgColor: const Color(0xFFE8F5E9),
        borderColor: const Color(0xFF66BB6A),
        textColor: const Color(0xFF2E7D32),
      );
    }

    if (totalEntries > zoneSize * 2 && rank > totalEntries - zoneSize) {
      return _buildBanner(
        icon: Icons.warning_amber_rounded,
        text: 'Danger zone — earn more XP to stay safe!',
        bgColor: const Color(0xFFFCE4EC),
        borderColor: const Color(0xFFEF5350),
        textColor: const Color(0xFFC62828),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBanner({
    required IconData icon,
    required String text,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({
    required this.state,
    required this.showClassName,
  });

  final LeaderboardDisplayState state;
  final bool showClassName;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: state.entries.length + (state.currentUserEntry != null ? 2 : 0),
      itemBuilder: (context, index) {
        // If current user is outside the list, show separator + their row at end
        if (state.currentUserEntry != null) {
          if (index == state.entries.length) {
            return _buildSeparator();
          }
          if (index == state.entries.length + 1) {
            return _buildEntryCard(
              context,
              state.currentUserEntry!,
              isCurrentUser: true,
            );
          }
        }

        final entry = state.entries[index];
        final isCurrentUser = state.isCurrentUser(entry.userId);

        // Top 3 podium for first item
        if (index == 0 && state.entries.length >= 3) {
          return _PodiumSection(
            entries: state.entries.take(3).toList(),
            currentUserId: state.currentUserId,
            useWeeklyXp: state.isLeagueMode,
            onEntryTap: (entry) =>
                showStudentProfileDialog(context, entry),
          );
        }
        // Skip indices 1 and 2 since they're part of the podium
        if (index == 1 || index == 2) return const SizedBox.shrink();

        return _buildEntryCard(context, entry, isCurrentUser: isCurrentUser);
      },
    );
  }

  Widget _buildEntryCard(BuildContext context, LeaderboardEntry entry,
      {required bool isCurrentUser}) {
    final isLeague = state.isLeagueMode;

    // Zone coloring for league mode
    Color cardColor;
    Color borderColor;
    double borderWidth;

    if (isCurrentUser) {
      cardColor = AppColors.secondaryBackground;
      borderColor = AppColors.secondary;
      borderWidth = 2;
    } else if (isLeague) {
      final totalEntries = state.leagueTotalCount ?? state.totalCount;
      final zoneSize = leagueZoneSize(totalEntries);
      if (entry.rank <= zoneSize) {
        // Promote zone
        cardColor = const Color(0xFFE8F5E9);
        borderColor = const Color(0xFF66BB6A);
        borderWidth = 1.5;
      } else if (totalEntries > zoneSize * 2 && entry.rank > totalEntries - zoneSize) {
        // Demote zone
        cardColor = const Color(0xFFFCE4EC);
        borderColor = const Color(0xFFEF5350);
        borderWidth = 1.5;
      } else {
        cardColor = AppColors.white;
        borderColor = AppColors.neutral;
        borderWidth = 1.5;
      }
    } else {
      cardColor = AppColors.white;
      borderColor = AppColors.neutral;
      borderWidth = 1.5;
    }

    return GestureDetector(
      onTap: () => showStudentProfileDialog(context, entry),
      child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 32,
            child: Center(
              child: Text(
                '${entry.rank}',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.neutralText,
                ),
              ),
            ),
          ),

          // Rank change indicator (league mode only)
          if (isLeague) ...[
            const SizedBox(width: 2),
            _RankChangeIndicator(rankChange: entry.rankChange),
          ],
          const SizedBox(width: 10),

          // Avatar
          _Avatar(
            avatarUrl: entry.avatarUrl,
            initials: entry.initials,
            leagueTier: entry.leagueTier,
            avatarEquippedCache: entry.avatarEquippedCache,
          ),
          const SizedBox(width: 12),

          // Name + class
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser
                      ? '${entry.fullName} (You)'
                      : entry.fullName,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight:
                        isCurrentUser ? FontWeight.w900 : FontWeight.w700,
                    color: AppColors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showClassName && entry.className != null)
                  Text(
                    entry.className!,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      color: AppColors.neutralText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),

          // League tier badge (hidden in league mode — all same tier)
          if (!isLeague) ...[
            _TierBadge(tier: entry.leagueTier),
            const SizedBox(width: 8),
          ],

          // XP (weekly in league mode, total otherwise)
          _XpBadge(xp: isLeague ? entry.weeklyXp : entry.totalXp),
        ],
      ),
      ),
    );
  }

  Widget _buildSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Row(
        children: [
          const Icon(Icons.more_vert, color: AppColors.neutralDark, size: 20),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.neutral,
            ),
          ),
          const Icon(Icons.more_vert, color: AppColors.neutralDark, size: 20),
        ],
      ),
    );
  }
}

/// Top 3 podium section with medal styling.
class _PodiumSection extends StatelessWidget {
  const _PodiumSection({
    required this.entries,
    required this.currentUserId,
    this.useWeeklyXp = false,
    this.onEntryTap,
  });

  final List<LeaderboardEntry> entries;
  final String currentUserId;
  final bool useWeeklyXp;
  final ValueChanged<LeaderboardEntry>? onEntryTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.waspBackground.withValues(alpha: 0.5),
            AppColors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neutral, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.neutral,
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place (left)
          if (entries.length > 1)
            Expanded(
              child: _PodiumEntry(
                entry: entries[1],
                medal: '🥈',
                height: 80,
                isCurrentUser: entries[1].userId == currentUserId,
                useWeeklyXp: useWeeklyXp,
                onTap: onEntryTap != null
                    ? () => onEntryTap!(entries[1])
                    : null,
              ),
            ),

          // 1st place (center, tallest)
          Expanded(
            child: _PodiumEntry(
              entry: entries[0],
              medal: '🥇',
              height: 110,
              isCurrentUser: entries[0].userId == currentUserId,
              useWeeklyXp: useWeeklyXp,
              onTap: onEntryTap != null
                  ? () => onEntryTap!(entries[0])
                  : null,
            ),
          ),

          // 3rd place (right)
          if (entries.length > 2)
            Expanded(
              child: _PodiumEntry(
                entry: entries[2],
                medal: '🥉',
                height: 60,
                isCurrentUser: entries[2].userId == currentUserId,
                useWeeklyXp: useWeeklyXp,
                onTap: onEntryTap != null
                    ? () => onEntryTap!(entries[2])
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _PodiumEntry extends StatelessWidget {
  const _PodiumEntry({
    required this.entry,
    required this.medal,
    required this.height,
    required this.isCurrentUser,
    this.useWeeklyXp = false,
    this.onTap,
  });

  final LeaderboardEntry entry;
  final String medal;
  final double height;
  final bool isCurrentUser;
  final bool useWeeklyXp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Medal
        Text(medal, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),

        // Avatar
        _Avatar(
          avatarUrl: entry.avatarUrl,
          initials: entry.initials,
          leagueTier: entry.leagueTier,
          avatarEquippedCache: entry.avatarEquippedCache,
          size: 48,
        ),
        const SizedBox(height: 6),

        // Name
        Text(
          isCurrentUser ? 'You' : entry.firstName,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: isCurrentUser ? FontWeight.w900 : FontWeight.w700,
            color: isCurrentUser ? AppColors.secondary : AppColors.black,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        // XP
        Text(
          '${useWeeklyXp ? entry.weeklyXp : entry.totalXp} XP',
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.waspDark,
          ),
        ),

        const SizedBox(height: 6),

        // Podium block
        Container(
          height: height,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: _podiumColor(entry.rank),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Center(
            child: Text(
              '${entry.rank}',
              style: GoogleFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }

  Color _podiumColor(int rank) {
    return switch (rank) {
      1 => const Color(0xFFFFD700), // Gold
      2 => const Color(0xFFC0C0C0), // Silver
      3 => const Color(0xFFCD7F32), // Bronze
      _ => AppColors.neutral,
    };
  }
}

class _RankChangeIndicator extends StatelessWidget {
  const _RankChangeIndicator({required this.rankChange});

  final int? rankChange;

  @override
  Widget build(BuildContext context) {
    if (rankChange == null || rankChange == 0) {
      return SizedBox(
        width: 22,
        child: Center(
          child: Text(
            '–',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.neutralText,
            ),
          ),
        ),
      );
    }

    final isUp = rankChange! > 0;
    return SizedBox(
      width: 22,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
            color: isUp ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
            size: 18,
          ),
          Text(
            '${rankChange!.abs()}',
            style: GoogleFonts.nunito(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: isUp ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.avatarUrl,
    required this.initials,
    required this.leagueTier,
    this.avatarEquippedCache,
    this.size = 40,
  });

  final String? avatarUrl;
  final String initials;
  final LeagueTier leagueTier;
  final Map<String, dynamic>? avatarEquippedCache;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Use AvatarWidget when equipped avatar data is available
    if (avatarEquippedCache != null) {
      final equippedAvatar = EquippedAvatarModel.fromJson(avatarEquippedCache).toEntity();
      if (equippedAvatar.isNotEmpty) {
        return AvatarWidget(
          avatar: equippedAvatar,
          size: size,
          fallbackInitials: initials,
          showBorder: true,
        );
      }
    }

    // Fallback: old rendering with tier border
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _tierColor(leagueTier), width: 2.5),
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? Image.network(
                avatarUrl!,
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
          initials,
          style: GoogleFonts.nunito(
            fontSize: size * 0.35,
            fontWeight: FontWeight.w900,
            color: AppColors.secondary,
          ),
        ),
      ),
    );
  }

  static Color _tierColor(LeagueTier tier) {
    return switch (tier) {
      LeagueTier.diamond => const Color(0xFF00BFFF),
      LeagueTier.platinum => const Color(0xFFE5E4E2),
      LeagueTier.gold => const Color(0xFFFFD700),
      LeagueTier.silver => const Color(0xFFC0C0C0),
      LeagueTier.bronze => const Color(0xFFCD7F32),
    };
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier});

  final LeagueTier tier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: _Avatar._tierColor(tier).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _Avatar._tierColor(tier),
          width: 1.5,
        ),
      ),
      child: Text(
        tier.label,
        style: GoogleFonts.nunito(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: _Avatar._tierColor(tier).withValues(alpha: 1),
        ),
      ),
    );
  }
}

class _XpBadge extends StatelessWidget {
  const _XpBadge({required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.waspBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.wasp, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: AppColors.waspDark, size: 14),
          const SizedBox(width: 2),
          Text(
            '$xp',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.waspDark,
            ),
          ),
        ],
      ),
    );
  }
}
