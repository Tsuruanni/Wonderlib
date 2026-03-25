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
import '../../../domain/entities/badge.dart';
import '../../../domain/entities/daily_review_session.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/vocabulary.dart';
import '../../../domain/usecases/auth/refresh_current_user_usecase.dart';
import '../../../domain/usecases/teacher/send_password_reset_email_usecase.dart';
import '../../../domain/usecases/teacher/update_teacher_profile_usecase.dart';
import '../../../domain/usecases/usecase.dart';
import '../../providers/auth_provider.dart';
import '../../providers/badge_provider.dart';
import '../../providers/card_provider.dart';
import '../../providers/daily_review_provider.dart';
import '../../providers/profile_context_provider.dart';
import '../../providers/usecase_providers.dart';
import '../../utils/ui_helpers.dart';
import '../../providers/user_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../providers/avatar_provider.dart';
import '../../widgets/cards/myth_card_widget.dart';
import '../../widgets/common/avatar_widget.dart';
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
            return _TeacherProfileBody(user: user);
          }
          return _StudentProfileBody(user: user);
        },
      ),
    );
  }

}

class _TeacherProfileBody extends ConsumerWidget {
  const _TeacherProfileBody({required this.user});
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileContext = ref.watch(profileContextProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _TeacherHeader(
            user: user,
            schoolName: profileContext.valueOrNull?.schoolName,
          ),
          const SizedBox(height: 24),
          _PersonalInfoCard(user: user),
          const SizedBox(height: 16),
          _PasswordCard(email: user.email),
          const SizedBox(height: 24),
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
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _TeacherHeader extends StatelessWidget {
  const _TeacherHeader({required this.user, this.schoolName});
  final User user;
  final String? schoolName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: _getRoleColor(user.role),
          child: Text(
            user.initials,
            style: GoogleFonts.nunito(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          user.fullName,
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
        if (user.email != null) ...[
          const SizedBox(height: 4),
          Text(
            user.email!,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: AppColors.neutralText,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _getRoleColor(user.role).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _getRoleDisplayName(user.role),
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _getRoleColor(user.role),
            ),
          ),
        ),
        if (schoolName != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.school_outlined, size: 16, color: AppColors.neutralText),
              const SizedBox(width: 4),
              Text(
                schoolName!,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: AppColors.neutralText,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.teacher:
        return Colors.blue;
      case UserRole.head:
        return Colors.purple;
      case UserRole.admin:
        return Colors.amber.shade700;
      default:
        return Colors.grey;
    }
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.head:
        return 'Head Teacher';
      case UserRole.admin:
        return 'Admin';
      default:
        return role.name;
    }
  }
}

class _PersonalInfoCard extends ConsumerWidget {
  const _PersonalInfoCard({required this.user});
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Personal Information',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
          ),
          _InfoTile(
            icon: Icons.person_outline,
            label: 'First Name',
            value: user.firstName,
            onTap: () => _editField(context, ref, 'First Name', user.firstName, isFirstName: true),
          ),
          _InfoTile(
            icon: Icons.person_outline,
            label: 'Last Name',
            value: user.lastName,
            onTap: () => _editField(context, ref, 'Last Name', user.lastName, isFirstName: false),
          ),
          _InfoTile(
            icon: Icons.email_outlined,
            label: 'Email',
            value: user.email ?? '—',
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _editField(
    BuildContext context,
    WidgetRef ref,
    String fieldName,
    String currentValue, {
    required bool isFirstName,
  }) async {
    final controller = TextEditingController(text: currentValue);
    final formKey = GlobalKey<FormState>();

    final newValue = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $fieldName'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: fieldName,
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '$fieldName cannot be empty';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newValue == null || newValue == currentValue) return;
    if (!context.mounted) return;

    final firstName = isFirstName ? newValue : user.firstName;
    final lastName = isFirstName ? user.lastName : newValue;

    final useCase = ref.read(updateTeacherProfileUseCaseProvider);
    final result = await useCase(UpdateTeacherProfileParams(
      firstName: firstName,
      lastName: lastName,
    ));

    if (!context.mounted) return;

    result.fold(
      (failure) {
        showAppSnackBar(context, 'Error: ${failure.message}', type: SnackBarType.error);
      },
      (_) async {
        showAppSnackBar(context, '$fieldName updated', type: SnackBarType.success);
        final refreshUseCase = ref.read(refreshCurrentUserUseCaseProvider);
        await refreshUseCase(const NoParams());
      },
    );
  }
}

class _PasswordCard extends ConsumerWidget {
  const _PasswordCard({this.email});
  final String? email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.lock_outline),
        title: Text(
          'Change Password',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Send a password reset link to your email',
          style: GoogleFonts.nunito(fontSize: 12, color: AppColors.neutralText),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: email == null
            ? null
            : () async {
                final useCase = ref.read(sendPasswordResetEmailUseCaseProvider);
                final result = await useCase(SendPasswordResetEmailParams(email: email!));

                if (!context.mounted) return;

                result.fold(
                  (failure) {
                    showAppSnackBar(context, 'Error: ${failure.message}', type: SnackBarType.error);
                  },
                  (_) {
                    showAppSnackBar(context, 'Password reset link sent to $email', type: SnackBarType.success);
                  },
                );
              },
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.neutralText),
      title: Text(
        label,
        style: GoogleFonts.nunito(fontSize: 12, color: AppColors.neutralText),
      ),
      subtitle: Text(
        value,
        style: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.black,
        ),
      ),
      trailing: onTap != null
          ? Icon(Icons.edit_outlined, size: 18, color: AppColors.neutralText)
          : null,
      onTap: onTap,
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

          // 5. Stats (reading + vocab combined)
          const _StatsSection().animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 20),

          // 6. Daily Review
          const _DailyReviewProfileCard().animate().fadeIn(delay: 500.ms),
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
        // Avatar with edit button
        Stack(
          children: [
            AvatarWidget(
              avatar: ref.watch(equippedAvatarProvider),
              size: 100,
              fallbackInitials: user.initials,
            ),
            Positioned(
              bottom: -4,
              right: -4,
              child: GestureDetector(
                onTap: () => context.push(AppRoutes.avatarCustomize),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 2),
                  ),
                  child: const Icon(Icons.edit, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
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
    final userCards = ref.watch(userCardsProvider).valueOrNull ?? [];

    return statsAsync.when(
      loading: () => const SizedBox(height: 80),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        const totalCards = AppConstants.totalCardCount;
        final progress = stats.totalUniqueCards / totalCards;

        // Sort cards: legendary first, then epic, rare, common
        final sortedCards = [...userCards]
          ..sort((a, b) => b.card.rarity.index.compareTo(a.card.rarity.index));
        final previewCards = sortedCards.take(5).toList();

        return PressableScale(
          onTap: () => context.go(AppRoutes.cards),
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
                // Card preview row
                if (previewCards.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: previewCards.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => SizedBox(
                        width: 70,
                        height: 100,
                        child: FittedBox(
                          child: SizedBox(
                            width: 140,
                            height: 200,
                            child: MythCardWidget(
                              card: previewCards[i].card,
                              quantity: previewCards[i].quantity,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(userBadgesProvider);

    return badgesAsync.when(
      loading: () => const SizedBox(height: 80),
      error: (_, __) => const SizedBox.shrink(),
      data: (allBadges) {
        return Container(
          width: double.infinity,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Icon(Icons.emoji_events_rounded,
                      size: 22, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Badges',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.black,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${allBadges.length}',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (allBadges.isEmpty)
                // Empty state
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events_outlined,
                          size: 32, color: AppColors.neutralText),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Complete lessons to earn badges!',
                          style: GoogleFonts.nunito(
                            color: AppColors.neutralText,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                // Last 5 badges
                ...allBadges.take(5).map((b) => _BadgeRow(badge: b)),

                // "See All" button if more than 5
                if (allBadges.length > 5) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        _showAllBadgesSheet(context, allBadges);
                      },
                      child: Text(
                        'See All ${allBadges.length} Badges',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  void _showAllBadgesSheet(BuildContext context, List<UserBadge> badges) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.neutral,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'All Badges (${badges.length})',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: badges.length,
                  itemBuilder: (_, i) => _BadgeRow(badge: badges[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.badge});
  final UserBadge badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Badge icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                badge.badge.icon ?? '🏆',
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.badge.name,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.black,
                  ),
                ),
                if (badge.badge.description != null)
                  Text(
                    badge.badge.description!,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      color: AppColors.neutralText,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Earned date
          Text(
            _formatDate(badge.earnedAt),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StatsSection extends ConsumerWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userStatsProvider);
    final wordsAsync = ref.watch(learnedWordsWithDetailsProvider);

    final stats = statsAsync.valueOrNull ?? {};
    final words = wordsAsync.valueOrNull;

    final booksCompleted = stats['books_completed'] as int? ?? 0;
    final chaptersCompleted = stats['chapters_completed'] as int? ?? 0;
    final readingTimeMin = stats['total_reading_time'] as int? ?? 0;
    final learningWords = words?.where((w) {
      final s = w.progress?.status;
      return s == VocabularyStatus.learning || s == VocabularyStatus.reviewing;
    }).length ?? 0;

    if (statsAsync.isLoading && wordsAsync.isLoading) {
      return const SizedBox(height: 80);
    }

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded,
                  size: 22, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text(
                'Stats',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.menu_book_rounded,
                  value: '$booksCompleted',
                  label: 'Books Read',
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  icon: Icons.bookmark_rounded,
                  value: '$chaptersCompleted',
                  label: 'Chapters Read',
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  icon: Icons.schedule_rounded,
                  value: _formatTime(readingTimeMin),
                  label: 'Reading Time',
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  icon: Icons.translate_rounded,
                  value: '$learningWords',
                  label: 'New Words',
                  color: AppColors.streakOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Word Bank shortcut
          PressableScale(
            onTap: () => context.push(AppRoutes.wordBank),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.gemBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.library_books_rounded,
                      size: 18, color: AppColors.gemBlue),
                  const SizedBox(width: 8),
                  Text(
                    'My Word Bank',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.gemBlue,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.gemBlue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w900,
              fontSize: 16,
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
    );
  }
}

class _DailyReviewProfileCard extends ConsumerWidget {
  const _DailyReviewProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySession = ref.watch(todayReviewSessionProvider).valueOrNull;
    final dueWords = ref.watch(dailyReviewWordsProvider).valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.replay_rounded, size: 22, color: AppColors.streakOrange),
            const SizedBox(width: 8),
            Text(
              'Daily Vocabulary Review',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (todaySession != null)
          _buildCompletedCard(todaySession)
        else if (dueWords.length >= minDailyReviewCount)
          _buildReadyCard(context, dueWords.length)
        else
          _buildBuildingUpCard(dueWords.length),
      ],
    );
  }

  Widget _buildCompletedCard(DailyReviewSession session) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.check_circle_rounded,
                color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review Complete!',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '+${session.xpEarned} XP earned today',
                  style: GoogleFonts.nunito(
                    color: AppColors.neutralText,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyCard(BuildContext context, int wordCount) {
    return PressableScale(
      onTap: () => context.push(AppRoutes.vocabularyDailyReview),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.streakOrange.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.streakOrange.withValues(alpha: 0.3), width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.streakOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.bolt_rounded,
                  color: AppColors.streakOrange, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$wordCount words ready!',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.streakOrange,
                    ),
                  ),
                  Text(
                    'Tap to start your daily review',
                    style: GoogleFonts.nunito(
                      color: AppColors.neutralText,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.streakOrange),
          ],
        ),
      ),
    );
  }

  Widget _buildBuildingUpCard(int currentCount) {
    final progress = currentCount / minDailyReviewCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gemBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.gemBlue.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.gemBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.hourglass_top_rounded,
                color: AppColors.gemBlue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Words Building Up',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$currentCount/$minDailyReviewCount — keep learning to unlock review!',
                  style: GoogleFonts.nunito(
                    color: AppColors.neutralText,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppColors.gemBlue.withValues(alpha: 0.1),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.gemBlue),
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
