import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../app/theme.dart';
import '../../../data/models/avatar/equipped_avatar_model.dart';
import '../../../domain/entities/leaderboard_entry.dart';
import '../../../domain/entities/league_status.dart';
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

    // Listen for league join transition (not joined → joined)
    ref.listen<AsyncValue<LeagueStatus?>>(leagueStatusProvider, (prev, next) {
      final wasJoined = prev?.valueOrNull?.joined ?? false;
      final isJoined = next.valueOrNull?.joined ?? false;
      if (!wasJoined && isJoined) {
        final tier = next.valueOrNull?.tier ?? LeagueTier.bronze;
        _showLeagueJoinedDialog(context, tier);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const SafeArea(bottom: false, child: TopNavbar()),

          // Header with scope toggle
          _LeaderboardHeader(
            scope: scope,
            onScopeChanged: (s) {
              ref.read(leaderboardScopeProvider.notifier).state = s;
              if (s == LeaderboardScope.leagueScope) {
                ref.invalidate(leagueStatusProvider);
                ref.invalidate(leagueGroupEntriesProvider);
              }
            },
          ),

          // Tier badges + league info (league mode only, when joined)
          if (scope == LeaderboardScope.leagueScope)
            displayAsync.whenOrNull(
              data: (state) => state.isLeagueJoined
                  ? _TierBadgeHeader(status: state.leagueStatus)
                  : null,
            ) ?? const SizedBox.shrink(),

          // Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(leaderboardDisplayProvider);
                if (scope == LeaderboardScope.leagueScope) {
                  ref.invalidate(leagueStatusProvider);
                  ref.invalidate(leagueGroupEntriesProvider);
                } else {
                  ref.invalidate(totalLeaderboardEntriesProvider);
                  ref.invalidate(currentUserTotalPositionProvider);
                }
              },
              child: displayAsync.when(
                loading: () => const SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                      height: 300,
                      child: Center(child: CircularProgressIndicator())),
                ),
                error: (e, _) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ErrorStateWidget(
                    message: 'Could not load leaderboard',
                    onRetry: () => ref.invalidate(leaderboardDisplayProvider),
                  ),
                ),
                data: (state) {
                  if (state.isLeagueMode && !state.isLeagueJoined) {
                    return _NotJoinedCard(status: state.leagueStatus);
                  }
                  if (state.isEmpty) return _buildEmptyState();
                  return _LeaderboardList(
                    state: state,
                    showClassName: scope != LeaderboardScope.classScope,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLeagueJoinedDialog(BuildContext context, LeagueTier tier) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _TierShield._tierColor(tier).withValues(alpha: 0.15),
                ),
                child: Icon(
                  Icons.shield_rounded,
                  size: 40,
                  color: _TierShield._tierColor(tier),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome to ${tier.label} League!',
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You\'re now competing with 30 rivals.\nEarn XP to climb the ranks and get promoted!',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutralText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.waspDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'LET\'S GO!',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
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

// ─────────────────────────────────────────────
// Header with scope toggle
// ─────────────────────────────────────────────

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

// ─────────────────────────────────────────────
// Duolingo-style tier badge header
// ─────────────────────────────────────────────

class _TierBadgeHeader extends StatelessWidget {
  const _TierBadgeHeader({this.status});

  final LeagueStatus? status;

  @override
  Widget build(BuildContext context) {
    final currentTier = status?.tier ?? LeagueTier.bronze;
    final now = DateTime.now();
    // Sunday 23:59 of current week
    final weekEnd = now
        .subtract(Duration(days: now.weekday - 1))
        .add(const Duration(days: 6));
    final daysLeft = weekEnd.difference(now).inDays + 1;
    final zoneSize = leagueZoneSize(30);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Column(
        children: [
          // Tier shield row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: LeagueTier.values.map((tier) {
              final isCurrent = tier == currentTier;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _TierShield(tier: tier, isCurrent: isCurrent),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Tier name
          Text(
            '${currentTier.label} League',
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 4),

          // Promotion info
          Text(
            'Top $zoneSize advance to the next league',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.neutralText,
            ),
          ),
          const SizedBox(height: 2),

          // Countdown
          Text(
            '$daysLeft days',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierShield extends StatelessWidget {
  const _TierShield({required this.tier, required this.isCurrent});

  final LeagueTier tier;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final size = isCurrent ? 44.0 : 28.0;
    final color = _tierColor(tier);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isCurrent ? color : AppColors.neutral,
        shape: BoxShape.circle,
        border: Border.all(
          color: isCurrent ? color.withValues(alpha: 0.8) : AppColors.neutral,
          width: 2,
        ),
        boxShadow: isCurrent
            ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)]
            : null,
      ),
      child: Icon(
        Icons.shield_rounded,
        size: isCurrent ? 24 : 14,
        color: isCurrent ? Colors.white : AppColors.neutralDark,
      ),
    );
  }

  static Color _tierColor(LeagueTier tier) {
    return switch (tier) {
      LeagueTier.bronze => const Color(0xFFCD7F32),
      LeagueTier.silver => const Color(0xFFC0C0C0),
      LeagueTier.gold => const Color(0xFFFFD700),
      LeagueTier.platinum => const Color(0xFFE5E4E2),
      LeagueTier.diamond => const Color(0xFF00BFFF),
    };
  }
}

// ─────────────────────────────────────────────
// Flat leaderboard list (Duolingo style)
// ─────────────────────────────────────────────

class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({
    required this.state,
    required this.showClassName,
  });

  final LeaderboardDisplayState state;
  final bool showClassName;

  int? _effectiveRankChange(LeaderboardEntry entry, LeaderboardDisplayState s) {
    if (entry.isBot) return null;
    if (entry.rankChange == null) return null;
    final currentGroupId = s.leagueStatus?.groupId;
    if (currentGroupId != null &&
        entry.previousGroupId != null &&
        entry.previousGroupId != currentGroupId) {
      return null;
    }
    return entry.rankChange;
  }

  @override
  Widget build(BuildContext context) {
    final isLeague = state.isLeagueMode;
    final zoneSize = isLeague ? leagueZoneSize(state.totalCount) : 0;
    final totalEntries = state.totalCount;
    final isBronze = state.leagueStatus?.tier == LeagueTier.bronze;
    final showDemotionZone = isLeague && !isBronze && totalEntries > zoneSize * 2;
    final demotionStart = totalEntries - zoneSize;

    // Build list items
    final items = <Widget>[];

    // Class/School tabs: podium for top 3
    if (!isLeague && state.entries.length >= 3) {
      items.add(_PodiumSection(
        entries: state.entries.take(3).toList(),
        currentUserId: state.currentUserId,
        useWeeklyXp: false,
        onEntryTap: (entry) => showStudentProfileDialog(context, entry),
      ));
    }

    // Determine start index (skip top 3 if podium shown)
    final startIndex = (!isLeague && state.entries.length >= 3) ? 3 : 0;

    for (var i = startIndex; i < state.entries.length; i++) {
      final entry = state.entries[i];
      final isCurrentUser = state.isCurrentUser(entry.userId);

      // Inject promotion zone separator after rank = zoneSize
      if (isLeague && i > 0 &&
          state.entries[i - 1].rank <= zoneSize &&
          entry.rank > zoneSize) {
        items.add(_ZoneSeparator(
          text: 'PROMOTION ZONE',
          color: const Color(0xFF4CAF50),
          icon: Icons.arrow_upward_rounded,
        ));
      }

      // Inject demotion zone separator before rank > demotionStart
      if (showDemotionZone && i > 0 &&
          state.entries[i - 1].rank <= demotionStart &&
          entry.rank > demotionStart) {
        items.add(_ZoneSeparator(
          text: 'DEMOTION ZONE',
          color: const Color(0xFFE53935),
          icon: Icons.arrow_downward_rounded,
        ));
      }

      items.add(_buildEntryCard(context, entry, isCurrentUser: isCurrentUser));
    }

    // If current user is outside the list, add separator + their row
    if (state.currentUserEntry != null) {
      items.add(_buildListSeparator());
      items.add(
          _buildEntryCard(context, state.currentUserEntry!, isCurrentUser: true));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      children: items,
    );
  }

  Widget _buildEntryCard(BuildContext context, LeaderboardEntry entry,
      {required bool isCurrentUser}) {
    final isLeague = state.isLeagueMode;

    // League mode: no frames (Duolingo style). Class/School: framed cards.
    final bool frameless = isLeague;

    Color cardColor;
    Color? borderColor;
    double borderWidth;

    if (isCurrentUser) {
      cardColor = AppColors.secondaryBackground;
      borderColor = frameless ? null : AppColors.secondary;
      borderWidth = frameless ? 0 : 2;
    } else {
      cardColor = frameless ? Colors.transparent : AppColors.white;
      borderColor = frameless ? null : AppColors.neutral;
      borderWidth = frameless ? 0 : 1.5;
    }

    return GestureDetector(
      onTap: entry.isBot
          ? null
          : () => showStudentProfileDialog(context, entry),
      child: Container(
        margin: EdgeInsets.only(bottom: frameless ? 0 : 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: frameless
            ? BoxDecoration(
                color: isCurrentUser ? cardColor : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              )
            : BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor!, width: borderWidth),
              ),
        child: Row(
          children: [
            // Rank (colored circle for top 3)
            _RankBadge(rank: entry.rank),

            // Rank change indicator (league mode only)
            if (isLeague) ...[
              const SizedBox(width: 4),
              _RankChangeIndicator(
                  rankChange: _effectiveRankChange(entry, state)),
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

            // Same-school indicator
            if (state.isLeagueMode && entry.isSameSchool && !entry.isBot) ...[
              const Icon(Icons.school_rounded,
                  size: 14, color: AppColors.secondary),
              const SizedBox(width: 6),
            ],

            // League tier badge (hidden in league mode)
            if (!isLeague) ...[
              _TierBadge(tier: entry.leagueTier),
              const SizedBox(width: 8),
            ],

            // XP
            _XpBadge(xp: isLeague ? entry.weeklyXp : entry.totalXp),
          ],
        ),
      ),
    );
  }

  Widget _buildListSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Row(
        children: [
          const Icon(Icons.more_vert, color: AppColors.neutralDark, size: 20),
          Expanded(child: Container(height: 1, color: AppColors.neutral)),
          const Icon(Icons.more_vert, color: AppColors.neutralDark, size: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Rank badge (colored circle for top 3)
// ─────────────────────────────────────────────

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    if (rank <= 3) {
      return Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _rankColor(rank),
        ),
        child: Center(
          child: Text(
            '$rank',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 30,
      child: Center(
        child: Text(
          '$rank',
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.neutralText,
          ),
        ),
      ),
    );
  }

  Color _rankColor(int rank) {
    return switch (rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => AppColors.neutral,
    };
  }
}

// ─────────────────────────────────────────────
// Zone separator (promotion / demotion line)
// ─────────────────────────────────────────────

class _ZoneSeparator extends StatelessWidget {
  const _ZoneSeparator({
    required this.text,
    required this.color,
    required this.icon,
  });

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Container(height: 2, color: color.withValues(alpha: 0.3))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  text,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(icon, size: 14, color: color),
              ],
            ),
          ),
          Expanded(child: Container(height: 2, color: color.withValues(alpha: 0.3))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Rank change indicator (↑↓)
// ─────────────────────────────────────────────

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

// ─────────────────────────────────────────────
// Avatar
// ─────────────────────────────────────────────

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
    if (avatarEquippedCache != null) {
      final equippedAvatar =
          EquippedAvatarModel.fromJson(avatarEquippedCache).toEntity();
      if (equippedAvatar.isNotEmpty) {
        return AvatarWidget(
          avatar: equippedAvatar,
          size: size,
          fallbackInitials: initials,
          showBorder: true,
        );
      }
    }

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

// ─────────────────────────────────────────────
// Tier badge (class/school tabs)
// ─────────────────────────────────────────────

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
        border: Border.all(color: _Avatar._tierColor(tier), width: 1.5),
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

// ─────────────────────────────────────────────
// XP badge
// ─────────────────────────────────────────────

class _XpBadge extends StatelessWidget {
  const _XpBadge({required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$xp XP',
      style: GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: AppColors.neutralText,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Podium (Class/School tabs only)
// ─────────────────────────────────────────────

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
          Text(medal, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          _Avatar(
            avatarUrl: entry.avatarUrl,
            initials: entry.initials,
            leagueTier: entry.leagueTier,
            avatarEquippedCache: entry.avatarEquippedCache,
            size: 48,
          ),
          const SizedBox(height: 6),
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
          Text(
            '${useWeeklyXp ? entry.weeklyXp : entry.totalXp} XP',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.waspDark,
            ),
          ),
          const SizedBox(height: 6),
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
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => AppColors.neutral,
    };
  }
}

// ─────────────────────────────────────────────
// Not joined card (< 20 XP threshold)
// ─────────────────────────────────────────────

class _NotJoinedCard extends StatelessWidget {
  const _NotJoinedCard({this.status});
  final LeagueStatus? status;

  @override
  Widget build(BuildContext context) {
    final xp = status?.currentWeeklyXp ?? 0;
    final progress = (xp / 20).clamp(0.0, 1.0);
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.neutral, width: 2),
          boxShadow: const [
            BoxShadow(
                color: AppColors.neutral,
                offset: Offset(0, 4),
                blurRadius: 0),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded,
                size: 48, color: AppColors.waspDark),
            const SizedBox(height: 16),
            Text(
              'Join this week\'s league!',
              style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.black),
            ),
            const SizedBox(height: 8),
            Text(
              'Earn 20 XP to start competing.',
              style: GoogleFonts.nunito(
                  color: AppColors.neutralText, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: AppColors.neutral,
                color: AppColors.waspDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$xp / 20 XP',
              style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800, color: AppColors.waspDark),
            ),
          ],
        ),
      ),
    );
  }
}
