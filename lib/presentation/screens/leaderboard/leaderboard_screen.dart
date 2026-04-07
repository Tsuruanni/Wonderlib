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
import '../../widgets/common/notification_card.dart';
import '../../widgets/common/notification_overlay_manager.dart';
import '../../widgets/common/top_navbar.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  bool _joinDialogShown = false;

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(leaderboardScopeProvider);
    final displayAsync = ref.watch(leaderboardDisplayProvider);

    // Listen for league join transition (not-joined → joined)
    // Uses NotificationOverlayManager (same system as level-up, badge, streak notifications)
    ref.listen<AsyncValue<LeagueStatus?>>(leagueStatusProvider, (prev, next) {
      if (_joinDialogShown) return;
      final prevData = prev?.valueOrNull;
      final nextData = next.valueOrNull;
      if (prevData != null && !prevData.joined && nextData != null && nextData.joined) {
        _joinDialogShown = true;
        final tier = nextData.tier;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final overlay = Overlay.of(context, rootOverlay: true);
          NotificationOverlayManager.instance.show(
            overlay: overlay,
            type: NotificationType.leagueChange,
            data: tier,
            cardBuilder: (dismiss) => NotificationCard.leagueJoined(
              tier: tier,
              onDismiss: dismiss,
            ),
          );
        });
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
                      child: Center(child: CircularProgressIndicator()),),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_outlined,
              color: AppColors.neutralDark, size: 64,),
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
              color: AppColors.waspDark, size: 26,),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Leaderboard',
              style: GoogleFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          DecoratedBox(
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
    final size = isCurrent ? 84.0 : 28.0;

    return Image.asset(
      _tierAsset(tier),
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
    );
  }
}

// ─────────────────────────────────────────────
// Flat leaderboard list (Duolingo style)
// ─────────────────────────────────────────────

String _tierAsset(LeagueTier tier) {
  return switch (tier) {
    LeagueTier.bronze => 'assets/icons/rank-bronze-1_large.png',
    LeagueTier.silver => 'assets/icons/rank-silver-2_large.png',
    LeagueTier.gold => 'assets/icons/rank-gold-3_large.png',
    LeagueTier.platinum => 'assets/icons/rank-platinum-5_large.png',
    LeagueTier.diamond => 'assets/icons/rank-diamond-7_large.png',
  };
}

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
      ),);
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
        items.add(const _ZoneSeparator(
          text: 'PROMOTION ZONE',
          color: Color(0xFF4CAF50),
          icon: Icons.arrow_upward_rounded,
        ),);
      }

      // Inject demotion zone separator before rank > demotionStart
      if (showDemotionZone && i > 0 &&
          state.entries[i - 1].rank <= demotionStart &&
          entry.rank > demotionStart) {
        items.add(const _ZoneSeparator(
          text: 'DEMOTION ZONE',
          color: Color(0xFFE53935),
          icon: Icons.arrow_downward_rounded,
        ),);
      }

      items.add(_buildEntryCard(context, entry, isCurrentUser: isCurrentUser));
    }

    // If current user is outside the list, add separator + their row
    if (state.currentUserEntry != null) {
      items.add(_buildListSeparator());
      items.add(
          _buildEntryCard(context, state.currentUserEntry!, isCurrentUser: true),);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      children: items,
    );
  }

  Widget _buildEntryCard(BuildContext context, LeaderboardEntry entry,
      {required bool isCurrentUser,}) {
    final isLeague = state.isLeagueMode;

    final cardColor =
        isCurrentUser ? AppColors.secondaryBackground : Colors.transparent;

    return GestureDetector(
      onTap: entry.isBot
          ? null
          : () => showStudentProfileDialog(context, entry),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isCurrentUser ? cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Rank (colored circle for top 3)
            _RankBadge(rank: entry.rank),

            // Rank change indicator (league mode only)
            if (isLeague) ...[
              const SizedBox(width: 4),
              _RankChangeIndicator(
                  rankChange: _effectiveRankChange(entry, state),),
            ],
            const SizedBox(width: 10),

            // Avatar
            _Avatar(
              avatarUrl: entry.avatarUrl,
              initials: entry.initials,
              leagueTier: entry.leagueTier,
              avatarEquippedCache: entry.avatarEquippedCache,
            ),
            const SizedBox(width: 8),

            // League tier icon (between avatar and name — class/school only)
            if (!isLeague) ...[
              _TierBadge(tier: entry.leagueTier),
              const SizedBox(width: 8),
            ],

            // Name + class + same-school indicator
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
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
                      ),
                      if (state.isLeagueMode && entry.isSameSchool && !entry.isBot) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.school_rounded,
                            size: 14, color: AppColors.secondary,),
                      ],
                    ],
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

            // XP with icon
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
                Flexible(
                  child: Text(
                    text,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: color,
                      letterSpacing: 1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
      return const SizedBox(width: 22);
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
    return ColoredBox(
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
    return Image.asset(
      _tierAsset(tier),
      width: 24,
      height: 24,
      filterQuality: FilterQuality.high,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$xp',
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.neutralText,
          ),
        ),
        const SizedBox(width: 4),
        Image.asset('assets/icons/xp_green_outline.png', width: 18, height: 18, filterQuality: FilterQuality.high),
      ],
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
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFFFFF3E0),
            Color(0xFFFFF8F0),
            Color(0xFFFFFFFF),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 1st place — left, biggest
          Expanded(
            child: _PodiumEntry(
              entry: entries[0],
              medal: '🥇',
              avatarSize: 80,
              isCurrentUser: entries[0].userId == currentUserId,
              useWeeklyXp: useWeeklyXp,
              onTap: onEntryTap != null
                  ? () => onEntryTap!(entries[0])
                  : null,
            ),
          ),
          // 2nd place — middle, medium
          if (entries.length > 1)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _PodiumEntry(
                  entry: entries[1],
                  medal: '🥈',
                  avatarSize: 60,
                  isCurrentUser: entries[1].userId == currentUserId,
                  useWeeklyXp: useWeeklyXp,
                  onTap: onEntryTap != null
                      ? () => onEntryTap!(entries[1])
                      : null,
                ),
              ),
            ),
          // 3rd place — right, smallest
          if (entries.length > 2)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 32),
                child: _PodiumEntry(
                  entry: entries[2],
                  medal: '🥉',
                  avatarSize: 44,
                  isCurrentUser: entries[2].userId == currentUserId,
                  useWeeklyXp: useWeeklyXp,
                  onTap: onEntryTap != null
                      ? () => onEntryTap!(entries[2])
                      : null,
                ),
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
    required this.avatarSize,
    required this.isCurrentUser,
    this.useWeeklyXp = false,
    this.onTap,
  });

  final LeaderboardEntry entry;
  final String medal;
  final double avatarSize;
  final bool isCurrentUser;
  final bool useWeeklyXp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final xp = useWeeklyXp ? entry.weeklyXp : entry.totalXp;
    final isFirst = avatarSize > 60;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rank number (left) + content block (avatar, name, xp) centered
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Rank number — separate block, vertically centered
              Text(
                '${entry.rank}',
                style: GoogleFonts.nunito(
                  fontSize: isFirst ? 28 : 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(width: 6),
              // Content block: avatar + name + xp
              // Constrain width to prevent overflow with long names
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isFirst ? 110 : 90),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar with tier badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _Avatar(
                          avatarUrl: entry.avatarUrl,
                          initials: entry.initials,
                          leagueTier: entry.leagueTier,
                          avatarEquippedCache: entry.avatarEquippedCache,
                          size: avatarSize,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Image.asset(
                            _tierAsset(entry.leagueTier),
                            width: isFirst ? 24.0 : 18.0,
                            height: isFirst ? 24.0 : 18.0,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Name
                    Text(
                      isCurrentUser ? '${entry.fullName} (You)' : entry.fullName,
                      style: GoogleFonts.nunito(
                        fontSize: isFirst ? 14 : 12,
                        fontWeight: FontWeight.w900,
                        color: isCurrentUser ? AppColors.secondary : AppColors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    // XP
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$xp',
                          style: GoogleFonts.nunito(
                            fontSize: isFirst ? 13 : 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.neutralText,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Image.asset(
                          'assets/icons/xp_green_outline.png',
                          width: isFirst ? 16.0 : 14.0,
                          height: isFirst ? 16.0 : 14.0,
                          filterQuality: FilterQuality.high,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
                blurRadius: 0,),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded,
                size: 48, color: AppColors.waspDark,),
            const SizedBox(height: 16),
            Text(
              'Join this week\'s league!',
              style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.black,),
            ),
            const SizedBox(height: 8),
            Text(
              'Earn 20 XP to start competing.',
              style: GoogleFonts.nunito(
                  color: AppColors.neutralText, fontWeight: FontWeight.w600,),
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
                  fontWeight: FontWeight.w800, color: AppColors.waspDark,),
            ),
          ],
        ),
      ),
    );
  }
}
