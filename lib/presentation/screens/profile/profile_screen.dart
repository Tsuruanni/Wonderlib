import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/utils/extensions/context_extensions.dart';
import '../../../domain/entities/badge.dart';
import '../../../domain/entities/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/badge_provider.dart';
import '../../providers/teacher_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common/game_button.dart';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: AppColors.primary),
            onPressed: () {
              // TODO: Navigate to settings
            },
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Start with entrance animation for the profile header
                Column(
                  children: [
                    // Avatar with Level Badge
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.neutral, width: 4),
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                            child: Text(
                              user.initials,
                              style: GoogleFonts.nunito(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.white, width: 2),
                          ),
                          child: Text(
                            'LVL ${user.level}',
                            style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Name and Username
                    Text(
                      user.fullName,
                      style: GoogleFonts.nunito(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.black,
                      ),
                    ),
                    Text(
                      '@${(user.email ?? '').split('@')[0]}', // Mock handle
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        color: AppColors.neutralText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Text(
                      'Joined ${DateTime.now().year}', // Mock join date
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: AppColors.neutralText,
                      ),
                    ),
                  ],
                ).animate().fadeIn().moveY(begin: 10, end: 0),

                const SizedBox(height: 32),
                const Divider(thickness: 2, color: AppColors.neutral),
                const SizedBox(height: 32),

                // Stats Section
                if (user.role.isStudent)
                  _StudentStatsGrid(user: user).animate().fadeIn(delay: 200.ms)
                else
                  const _TeacherStatsCard(),
                
                const SizedBox(height: 32),

                // Badges Section
                if (user.role.isStudent)
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         'Achievements',
                         style: GoogleFonts.nunito(
                           fontSize: 20,
                           fontWeight: FontWeight.w800,
                           color: AppColors.black,
                         ),
                       ),
                       const SizedBox(height: 16),
                       const _BadgesSection(),
                     ],
                   ).animate().fadeIn(delay: 400.ms),

                const SizedBox(height: 48),

                // Sign Out
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
          );
        },
      ),
    );
  }
}

class _StudentStatsGrid extends StatelessWidget {
  final User user;
  const _StudentStatsGrid({required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
           'Statistics',
           style: GoogleFonts.nunito(
             fontSize: 20,
             fontWeight: FontWeight.w800,
             color: AppColors.black,
           ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatBox(
                icon: Icons.local_fire_department_rounded,
                value: '${user.currentStreak}',
                label: 'Day Streak',
                color: AppColors.streakOrange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatBox(
                icon: Icons.electric_bolt_rounded, 
                value: '${user.xp}',
                label: 'Total XP',
                color: AppColors.wasp,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatBox(
                icon: Icons.stars_rounded, // Use a filled icon
                value: user.userLevel.title,
                label: 'Current League',
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatBox(
                icon: Icons.emoji_events_rounded,
                value: '0', 
                label: 'Top 3 Finishes',
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral, width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.black,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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

class _TeacherStatsCard extends ConsumerWidget {
  const _TeacherStatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Teacher stats layout (could be improved later)
    return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text("Teacher Stats Placeholder")));
  }
}

class _BadgesSection extends ConsumerWidget {
  const _BadgesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(userBadgesProvider);

    return badgesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Text('Failed to load badges'),
      data: (badges) {
        if (badges.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border(
                bottom: BorderSide(color: AppColors.neutral, width: 4), 
                top: BorderSide(color: AppColors.neutral, width: 2), 
                left: BorderSide(color: AppColors.neutral, width: 2), 
                right: BorderSide(color: AppColors.neutral, width: 2),
              ), 
              // ^ Manual box border to match game button style roughly
            ),
            child: Column(
              children: [
                Icon(Icons.emoji_events_outlined, size: 48, color: AppColors.neutralText),
                 Text(
                   'No badges yet',
                   style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16),
                 ),
                 Text('Complete lessons to earn them!', style: GoogleFonts.nunito(color: AppColors.neutralText)),
              ],
            ),
          );
        }
        
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: badges.map((b) => _BadgeItem(badge: b)).toList(),
        );
      },
    );
  }
}

class _BadgeItem extends StatelessWidget {
  final UserBadge badge;
  const _BadgeItem({required this.badge});

  @override
  Widget build(BuildContext context) {
      // Mocking badge visual
      return Container(
        width: 100,
        height: 120,
        decoration: BoxDecoration(
           color: AppColors.white,
           borderRadius: BorderRadius.circular(16),
           border: Border.all(color: AppColors.neutral, width: 2),
           boxShadow: [
             BoxShadow(color: AppColors.neutral, offset: Offset(0, 4))
           ]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Text(badge.badge.icon ?? '🏆', style: const TextStyle(fontSize: 40)),
             const SizedBox(height: 8),
             Text(
               badge.badge.name,
               textAlign: TextAlign.center,
               style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 12),
               maxLines: 2,
             ),
          ],
        ),
      );
  }
}
