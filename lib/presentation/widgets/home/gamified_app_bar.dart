import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';

class GamifiedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int streak;
  final int gems;
  final VoidCallback? onProfileTap;

  const GamifiedAppBar({
    super.key,
    required this.streak,
    required this.gems,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      titleSpacing: 16,
      automaticallyImplyLeading: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: Container(color: AppColors.neutral, height: 2),
      ),
      title: Row(
        children: [
          // Language Flag (Static for now, implies English)
          _FlagIcon(),
          const Spacer(),
          
          // Stats
          _StatBadge(
            icon: Icons.local_fire_department_rounded,
            value: streak.toString(),
            color: AppColors.streakOrange,
          ),
          const SizedBox(width: 12),
          _StatBadge(
            icon: Icons.diamond_rounded,
            value: gems.toString(),
            color: AppColors.gemBlue,
          ),
          const SizedBox(width: 12),
          _StatBadge(
            icon: Icons.favorite_rounded,
            value: '5', // Infinite hearts for now? Or mock 5
            color: AppColors.danger,
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 2);
}

class _FlagIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutral, width: 2),
      ),
      alignment: Alignment.center,
      child: const Text('🇺🇸', style: TextStyle(fontSize: 20)),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _StatBadge({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
      ],
    );
  }
}
