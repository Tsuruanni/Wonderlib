import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../app/theme.dart';
import '../../../data/models/avatar/equipped_avatar_model.dart';
import '../../../domain/entities/card.dart';
import '../../../domain/entities/leaderboard_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/card_provider.dart';
import '../common/avatar_widget.dart';
import '../common/student_profile_dialog.dart';

class TopCollectorsCard extends ConsumerWidget {
  const TopCollectorsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(classTopCollectorsProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (result) {
        if (result.top3.isEmpty) return const SizedBox.shrink();

        final userId = ref.watch(currentUserIdProvider);
        final callerInTop3 = result.top3.any((e) => e.userId == userId);

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
                'Top Collectors',
                style: GoogleFonts.nunito(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < result.top3.length; i++) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Divider(height: 1, color: AppColors.neutral),
                  ),
                _TopCollectorRow(
                  entry: result.top3[i],
                  isCurrentUser: result.top3[i].userId == userId,
                ),
              ],
              if (!callerInTop3 && result.caller != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(height: 1, color: AppColors.neutral),
                ),
                _TopCollectorRow(
                  entry: result.caller!,
                  isCurrentUser: true,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TopCollectorRow extends StatelessWidget {
  const _TopCollectorRow({
    required this.entry,
    required this.isCurrentUser,
  });

  final TopCollectorEntry entry;
  final bool isCurrentUser;

  LeaderboardEntry _toLeaderboardEntry() {
    return LeaderboardEntry(
      userId: entry.userId,
      firstName: entry.firstName,
      lastName: entry.lastName,
      avatarUrl: entry.avatarUrl,
      avatarEquippedCache: entry.avatarEquippedCache,
      totalXp: entry.totalXp,
      weeklyXp: 0,
      level: entry.level,
      rank: entry.rank,
      leagueTier: LeagueTier.fromDbValue(entry.leagueTier),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leaderboardEntry = _toLeaderboardEntry();
    final equippedAvatar = entry.avatarEquippedCache != null
        ? EquippedAvatarModel.fromJson(entry.avatarEquippedCache).toEntity()
        : null;

    final rowContent = Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            '#${entry.rank}',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isCurrentUser
                  ? AppColors.secondary
                  : AppColors.neutralText,
            ),
          ),
        ),
        const SizedBox(width: 6),
        (equippedAvatar != null && equippedAvatar.isNotEmpty)
            ? AvatarWidget(
                avatar: equippedAvatar,
                size: 36,
                fallbackInitials: leaderboardEntry.initials,
                showBorder: false,
              )
            : _InitialsFallback(
                initials: leaderboardEntry.initials,
                size: 36,
              ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  isCurrentUser ? 'You' : entry.firstName,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight:
                        isCurrentUser ? FontWeight.w800 : FontWeight.w600,
                    color:
                        isCurrentUser ? AppColors.secondary : AppColors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCurrentUser) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'YOU',
                    style: GoogleFonts.nunito(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: AppColors.secondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          '${entry.uniqueCards}',
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isCurrentUser ? AppColors.secondary : AppColors.black,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'cards',
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.neutralText,
          ),
        ),
      ],
    );

    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: rowContent,
    );

    if (isCurrentUser) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: padded,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showStudentProfileDialog(context, leaderboardEntry),
      child: padded,
    );
  }
}

class _InitialsFallback extends StatelessWidget {
  const _InitialsFallback({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.neutral,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.nunito(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
          color: AppColors.neutralText,
        ),
      ),
    );
  }
}
