import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:owlio_shared/owlio_shared.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions/context_extensions.dart';
import '../../../core/utils/level_helper.dart';
import '../../../domain/entities/badge.dart';
import '../../../domain/entities/daily_review_session.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/vocabulary.dart';
import '../../../domain/usecases/teacher/send_password_reset_email_usecase.dart';
import '../../../domain/usecases/teacher/update_teacher_profile_usecase.dart';
import '../../../core/utils/app_clock.dart';
import '../../providers/auth_provider.dart';
import '../../providers/badge_provider.dart';
import '../../providers/card_provider.dart';
import '../../providers/daily_review_provider.dart';
import '../../providers/profile_context_provider.dart';
import '../../providers/usecase_providers.dart';
import '../../utils/app_icons.dart';
import '../../utils/ui_helpers.dart';
import '../../providers/user_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../providers/avatar_provider.dart';
import '../../widgets/cards/myth_card_widget.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/game_button.dart';
import '../../widgets/common/playful_card.dart';
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
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $error'),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => ref.invalidate(userControllerProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name row
        Row(
          children: [
            Text(
              user.firstName,
              style: GoogleFonts.nunito(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              user.lastName,
              style: GoogleFonts.nunito(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Role badge + school
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _getRoleColor(user.role).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _getRoleColor(user.role).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _getRoleDisplayName(user.role),
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _getRoleColor(user.role),
                ),
              ),
            ),
            if (schoolName != null) ...[
              const SizedBox(width: 10),
              const Icon(Icons.school_outlined, size: 16, color: AppColors.neutralText),
              const SizedBox(width: 4),
              Text(
                schoolName!,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: AppColors.neutralText,
                ),
              ),
            ],
          ],
        ),
        if (user.email != null) ...[
          const SizedBox(height: 4),
          Text(
            user.email!,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: AppColors.neutralText,
            ),
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
    return PlayfulCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 12),
          // First + Last name side by side
          Row(
            children: [
              Expanded(
                child: _EditableField(
                  label: 'First Name',
                  value: user.firstName,
                  onTap: () => _editField(context, ref, 'First Name', user.firstName, isFirstName: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _EditableField(
                  label: 'Last Name',
                  value: user.lastName,
                  onTap: () => _editField(context, ref, 'Last Name', user.lastName, isFirstName: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Email (not editable)
          _EditableField(
            label: 'Email',
            value: user.email ?? '—',
          ),
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
        await ref.read(userControllerProvider.notifier).refreshProfileOnly();
      },
    );
  }
}

class _PasswordCard extends ConsumerWidget {
  const _PasswordCard({this.email});
  final String? email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlayfulCard(
      padding: EdgeInsets.zero,
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
        trailing: AppIcons.arrowRight(),
      ),
    );
  }
}

class _EditableField extends StatelessWidget {
  const _EditableField({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.neutral),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutralText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.edit_outlined, size: 16, color: AppColors.neutralText),
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
          // 1. Header (avatar + name + level bar)
          _ProfileHeader(user: user).animate().fadeIn().moveY(begin: 10, end: 0),
          const SizedBox(height: 24),

          // 2. Card Collection
          const _CardCollectionSection().animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 20),

          // 3. Recent Badges
          const _RecentBadgesSection().animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 20),

          // 4. Stats
          const _StatsSection().animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 20),

          // 5. Daily Review
          const _DailyReviewProfileCard().animate().fadeIn(delay: 400.ms),
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
    final progress = LevelHelper.progress(user.xp, user.level);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar — square, rounded rectangle
        GestureDetector(
          onTap: () => context.push(AppRoutes.avatarCustomize),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AvatarWidget(
                avatar: ref.watch(equippedAvatarProvider),
                size: 130,
                fallbackInitials: user.initials,
                borderRadius: 22,
              ),
              Positioned(
                bottom: 4,
                right: 4,
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
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Info column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                user.fullName,
                style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.black,
                ),
              ),
              if (user.username != null && user.username!.isNotEmpty)
                Text(
                  '@${user.username}',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: AppColors.neutralText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 8),
              if (profileContext != null) ...[
                _buildSchoolClass(profileContext),
                const SizedBox(height: 12),
              ],
              // League & Level cards
              Row(
                children: [
                  // League card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            _tierAsset(user.leagueTier),
                            width: 36,
                            height: 36,
                            filterQuality: FilterQuality.high,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.leagueTier.label,
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: AppColors.black,
                                  ),
                                ),
                                Text(
                                  'League',
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
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Level card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/icons/xp_green_outline.png',
                            width: 36,
                            height: 36,
                            filterQuality: FilterQuality.high,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Level ${user.level}',
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: AppColors.black,
                                  ),
                                ),
                                Text(
                                  '${user.xp} XP',
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
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSchoolClass(ProfileContext ctx) {
    final parts = <String>[];
    if (ctx.schoolName != null) parts.add(ctx.schoolName!);
    if (ctx.className != null) parts.add(ctx.className!);
    if (parts.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Icon(Icons.school_rounded, size: 16, color: AppColors.neutralText),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            parts.join(' • '),
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: AppColors.neutralText,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

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
        if (stats.totalUniqueCards == 0) return const SizedBox.shrink();

        const totalCards = AppConstants.totalCardCount;
        final progress = stats.totalUniqueCards / totalCards;

        final sortedCards = [...userCards]
          ..sort((a, b) => b.card.rarity.index.compareTo(a.card.rarity.index));
        final previewCards = sortedCards.take(5).toList();

        return PressableScale(
          onTap: () => context.go(AppRoutes.cards),
          child: Container(
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
                    AppIcons.arrowRight(size: 20),
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
                        context.go(AppRoutes.quests);
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
    final now = AppClock.now();
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistics',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: 14),
        // 2x2 grid
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: AppIcons.book(size: 22),
                value: '$booksCompleted',
                label: 'Books read',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icon(Icons.bookmark_rounded, size: 22, color: AppColors.secondary),
                value: '$chaptersCompleted',
                label: 'Chapters read',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: AppIcons.schedule(size: 22),
                value: _formatTime(readingTimeMin),
                label: 'Reading time',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PressableScale(
                onTap: () => context.push(AppRoutes.wordBank),
                child: _StatCard(
                  icon: Icon(Icons.translate_rounded, size: 22, color: AppColors.gemBlue),
                  value: '$learningWords',
                  label: 'New words',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
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
                AppIcons.arrowRight(size: 18),
              ],
            ),
          ),
        ),
      ],
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final Widget icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
              icon,
              const SizedBox(width: 8),
              Text(
                value,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: AppColors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w600,
              fontSize: 13,
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
            child: AppIcons.check(),
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
              child: AppIcons.xp(),
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
            AppIcons.arrowRight(),
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

String _tierAsset(LeagueTier tier) {
  return switch (tier) {
    LeagueTier.bronze => 'assets/icons/rank-bronze-1_large.png',
    LeagueTier.silver => 'assets/icons/rank-silver-2_large.png',
    LeagueTier.gold => 'assets/icons/rank-gold-3_large.png',
    LeagueTier.platinum => 'assets/icons/rank-platinum-5_large.png',
    LeagueTier.diamond => 'assets/icons/rank-diamond-7_large.png',
  };
}
