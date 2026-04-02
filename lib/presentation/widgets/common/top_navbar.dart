import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';


import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../providers/avatar_provider.dart';
import '../../providers/user_provider.dart';
import 'avatar_widget.dart';
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
    final streak = ref.watch(displayStreakProvider);
    final coins = user?.coins ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.neutral, width: 2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: UK flag
          Image.asset(
            'assets/icons/uk-flag.png',
            width: 32,
            height: 32,
            filterQuality: FilterQuality.high,
          ),

          // Streak
          GestureDetector(
            onTap: () {
              if (user != null) showStreakSheet(context);
            },
            child: _buildNavStat(
              assetPath: 'assets/icons/fire_menu_bar_256.png',
              value: streak,
            ),
          ),

          // Coins (Globally replaced XP)
          _buildNavStat(
            assetPath: 'assets/icons/gem_outline_256.png',
            value: coins,
          ),

          // Right: Profile avatar
          GestureDetector(
            onTap: () => context.push(AppRoutes.profile),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: AvatarWidget(
                avatar: ref.watch(equippedAvatarProvider),
                size: 32,
                fallbackInitials: user?.initials ?? '?',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavStat({
    IconData? icon,
    String? assetPath,
    required int value,
    Color? iconColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (assetPath != null)
          Image.asset(assetPath, width: 24, height: 24, filterQuality: FilterQuality.high)
        else
          Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 4),
        Text(
          value.toString(),
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
      ],
    );
  }
}
