import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';


import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../providers/user_provider.dart';
import 'streak_sheet.dart';

class TopNavbar extends ConsumerWidget {
  const TopNavbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hide on wide screens — stats move to RightInfoPanel
    final isWide = MediaQuery.sizeOf(context).width >= 1000;
    if (isWide) return const SizedBox.shrink();

    final userAsync = ref.watch(userControllerProvider);
    final user = userAsync.valueOrNull;
    // Pre-warm loginDatesProvider so calendar data is ready when fire icon is tapped
    ref.watch(loginDatesProvider);

    final streak = user?.currentStreak ?? 0;
    final coins = user?.coins ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.primary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Language direction (EN → TR)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🇬🇧', style: TextStyle(fontSize: 18)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 14,
                ),
              ),
              const Text('🇹🇷', style: TextStyle(fontSize: 18)),
            ],
          ),

          _buildNavDivider(),

          // Streak
          GestureDetector(
            onTap: () {
              if (user != null) showStreakSheet(context);
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
