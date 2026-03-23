import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';


import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/system_settings.dart';
import '../../providers/system_settings_provider.dart';
import '../../providers/user_provider.dart';
import 'streak_status_dialog.dart';

class TopNavbar extends ConsumerWidget {
  const TopNavbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userControllerProvider);
    final user = userAsync.valueOrNull;
    final settings = ref.watch(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();

    final streak = user?.currentStreak ?? 0;
    final coins = user?.coins ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.primary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: UK Flag
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 16, color: const Color(0xFF012169)),
                Container(width: 8, height: 16, color: Colors.white),
                Container(width: 8, height: 16, color: const Color(0xFFC8102E)),
              ],
            ),
          ),

          _buildNavDivider(),

          // Streak
          GestureDetector(
            onTap: () {
              if (user != null) {
                showDialog(
                  context: context,
                  builder: (context) => StreakStatusDialog(
                    currentStreak: user.currentStreak,
                    longestStreak: user.longestStreak,
                    streakFreezeCount: user.streakFreezeCount,
                    streakFreezeMax: settings.streakFreezeMax,
                    streakFreezePrice: settings.streakFreezePrice,
                    userCoins: user.coins,
                    onBuyFreeze: () {
                      Navigator.of(context).pop();
                      ref.read(userControllerProvider.notifier).buyStreakFreeze();
                    },
                  ),
                );
              }
            },
            child: _buildNavStat(
              icon: Icons.local_fire_department,
              value: streak,
              iconColor: AppColors.streakOrange,
            ),
          ),

          _buildNavDivider(),

          // Coins (Globally replaced XP)
          _buildNavStat(
            icon: Icons.monetization_on_rounded, // Coin icon
            value: coins,
            iconColor: AppColors.cardLegendary, // Gold color for coins
          ),

  // ... (rest of file)

          _buildNavDivider(),

          // Right: Profile Button
          GestureDetector(
            onTap: () => context.push(AppRoutes.profile),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      user?.initials ?? '?',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        height: 24,
        width: 2,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _buildNavStat({
    required IconData icon,
    required int value,
    required Color iconColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.3), size: 28),
            Icon(icon, color: iconColor, size: 24),
          ],
        ),
        const SizedBox(width: 4),
        Text(
          value.toString(),
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
