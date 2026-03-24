import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions/context_extensions.dart';
import '../../../core/utils/level_helper.dart';
import '../../../domain/entities/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/card_provider.dart';
import '../../providers/profile_context_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common/game_button.dart';
import '../../widgets/common/pressable_scale.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'PROFILE',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            color: AppColors.neutralText,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }
          if (!user.role.isStudent) {
            return _buildTeacherFallback(context, ref);
          }
          return _StudentProfileBody(user: user);
        },
      ),
    );
  }

  Widget _buildTeacherFallback(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_rounded, size: 64, color: AppColors.neutralText),
            const SizedBox(height: 16),
            Text(
              'Teacher Profile',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 32),
            GameButton(
              label: 'SIGN OUT',
              onPressed: () async {
                final confirmed = await context.showConfirmDialog(
                  title: 'Sign Out',
                  message: 'Are you sure you want to sign out?',
                  confirmText: 'Sign Out',
                  isDestructive: true,
                );
                if (confirmed ?? false) {
                  await ref.read(authControllerProvider.notifier).signOut();
                }
              },
              variant: GameButtonVariant.outline,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentProfileBody extends ConsumerWidget {
  const _StudentProfileBody({required this.user});
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // 1. Header
          _ProfileHeader(user: user).animate().fadeIn().moveY(begin: 10, end: 0),
          const SizedBox(height: 24),

          // 2. Level & XP
          _LevelXpSection(user: user).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 20),

          // 3. Card Collection
          const _CardCollectionSection().animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 20),

          // 4. Recent Badges
          const _RecentBadgesSection().animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 20),

          // 5. Reading Stats
          const _ReadingStatsSection().animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 20),

          // 6. Vocabulary Stats
          const _VocabularyStatsSection().animate().fadeIn(delay: 500.ms),
          const SizedBox(height: 20),

          // 7. Daily Review
          const _DailyReviewProfileCard().animate().fadeIn(delay: 600.ms),
          const SizedBox(height: 32),

          // 8. Sign Out
          const _SignOutButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 1. HEADER
// ─────────────────────────────────────────────

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.user});
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileContext = ref.watch(profileContextProvider).valueOrNull;

    return Column(
      children: [
        // Avatar
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 3),
          ),
          child: ClipOval(
            child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                ? Image.network(
                    user.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildInitials(),
                  )
                : _buildInitials(),
          ),
        ),
        const SizedBox(height: 12),

        // Full Name
        Text(
          user.fullName,
          style: GoogleFonts.nunito(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.black,
          ),
        ),

        // Username
        if (user.username != null && user.username!.isNotEmpty)
          Text(
            '@${user.username}',
            style: GoogleFonts.nunito(
              fontSize: 15,
              color: AppColors.neutralText,
              fontWeight: FontWeight.w600,
            ),
          ),

        const SizedBox(height: 6),

        // School & Class
        if (profileContext != null) _buildSchoolClass(profileContext),
      ],
    );
  }

  Widget _buildInitials() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          user.initials,
          style: GoogleFonts.nunito(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildSchoolClass(ProfileContext ctx) {
    final parts = <String>[];
    if (ctx.schoolName != null) parts.add(ctx.schoolName!);
    if (ctx.className != null) parts.add(ctx.className!);
    if (parts.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.school_rounded, size: 16, color: AppColors.neutralText),
        const SizedBox(width: 4),
        Text(
          parts.join(' • '),
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: AppColors.neutralText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 2. LEVEL & XP
// ─────────────────────────────────────────────

class _LevelXpSection extends StatelessWidget {
  const _LevelXpSection({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final progress = LevelHelper.progress(user.xp, user.level);
    final xpIn = LevelHelper.xpInCurrentLevel(user.xp, user.level);
    final xpNeeded = LevelHelper.xpToNextLevel(user.level);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral, width: 2),
        boxShadow: [
          BoxShadow(color: AppColors.neutral, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Level badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.wasp.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.wasp, width: 2),
                ),
                child: Text(
                  'LVL ${user.level}',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: AppColors.waspDark,
                  ),
                ),
              ),
              const Spacer(),
              // XP count
              Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 20, color: AppColors.wasp),
                  const SizedBox(width: 4),
                  Text(
                    '${user.xp} XP',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.neutral.withValues(alpha: 0.3),
              color: AppColors.wasp,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Level ${user.level} — $xpIn / $xpNeeded XP to next level',
            style: GoogleFonts.nunito(
              fontSize: 12,
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
// PLACEHOLDER SECTIONS (implemented in next tasks)
// ─────────────────────────────────────────────

class _CardCollectionSection extends ConsumerWidget {
  const _CardCollectionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userCardStatsProvider);

    return statsAsync.when(
      loading: () => const SizedBox(height: 80),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        const totalCards = AppConstants.totalCardCount;
        final progress = stats.totalUniqueCards / totalCards;

        return PressableScale(
          onTap: () => context.push(AppRoutes.cards),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardEpic.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.cardEpic.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardEpic.withValues(alpha: 0.1),
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.collections_bookmark_rounded,
                        size: 22, color: AppColors.cardEpic),
                    const SizedBox(width: 8),
                    Text(
                      'Card Collection',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.black,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${stats.totalUniqueCards} / $totalCards',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: AppColors.cardEpic,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded,
                        size: 20, color: AppColors.cardEpic),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.neutral.withValues(alpha: 0.3),
                    color: AppColors.cardEpic,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${stats.totalPacksOpened} packs opened',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutralText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RecentBadgesSection extends ConsumerWidget {
  const _RecentBadgesSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) => const SizedBox.shrink();
}

class _ReadingStatsSection extends ConsumerWidget {
  const _ReadingStatsSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) => const SizedBox.shrink();
}

class _VocabularyStatsSection extends ConsumerWidget {
  const _VocabularyStatsSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) => const SizedBox.shrink();
}

class _DailyReviewProfileCard extends ConsumerWidget {
  const _DailyReviewProfileCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) => const SizedBox.shrink();
}

class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GameButton(
      label: 'SIGN OUT',
      onPressed: () async {
        final confirmed = await context.showConfirmDialog(
          title: 'Sign Out',
          message: 'Are you sure you want to sign out?',
          confirmText: 'Sign Out',
          isDestructive: true,
        );
        if (confirmed ?? false) {
          await ref.read(authControllerProvider.notifier).signOut();
        }
      },
      variant: GameButtonVariant.outline,
      fullWidth: true,
    );
  }
}
