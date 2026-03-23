import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/utils/app_clock.dart';

class StreakStatusDialog extends StatelessWidget {
  const StreakStatusDialog({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    required this.streakFreezeCount,
    required this.streakFreezeMax,
    required this.streakFreezePrice,
    required this.userCoins,
    this.onBuyFreeze,
  });

  final int currentStreak;
  final int longestStreak;
  final int streakFreezeCount;
  final int streakFreezeMax;
  final int streakFreezePrice;
  final int userCoins;
  final VoidCallback? onBuyFreeze;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle for aesthetics (optional, Duolingo has it sometimes on bottom sheets)
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.neutral,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Text(
              'Current Streak',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.neutralText,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 12),

            // Big Streak Counter with Fire Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '$currentStreak',
                  style: GoogleFonts.nunito(
                    fontSize: 80,
                    fontWeight: FontWeight.w900,
                    color: AppColors.black,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.streakOrange,
                  size: 64,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Weekly Days Row
            _buildWeekRow(),

            const SizedBox(height: 24),

            // Longest Streak Info
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.neutral.withOpacity(0.5), width: 2),
                ),
              ),
              child: Text(
                'Longest Streak: $longestStreak days',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralText,
                ),
              ),
            ),

            // Streak Freeze Section
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.ac_unit, color: Colors.blue.shade400, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Streak Freezes: $streakFreezeCount/$streakFreezeMax',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutralText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (streakFreezeCount < streakFreezeMax)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: userCoins >= streakFreezePrice ? onBuyFreeze : null,
                  icon: const Icon(Icons.ac_unit, size: 18),
                  label: Text('Buy Freeze ($streakFreezePrice coins)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade600,
                    side: BorderSide(color: Colors.blue.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (streakFreezeCount >= streakFreezeMax)
              Text(
                'Max freezes reached',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            const SizedBox(height: 16),

            // Close Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.streakOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  shadowColor: const Color(0xFFCC4100), // Darker orange shadow
                ).copyWith(
                  elevation: WidgetStateProperty.all(0),
                  side: WidgetStateProperty.resolveWith((states) {
                     if (states.contains(WidgetState.pressed)) {
                       return const BorderSide(color: Colors.transparent);
                     }
                     return const BorderSide(
                       color: Color(0xFFCC4100), // Darker orange border/shadow effect
                       width: 0, 
                     );
                  }),
                ),
                child: Container(
                   child: Text(
                    'Close',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekRow() {
    final today = AppClock.today();

    // Find Monday of this week
    final monday = today.subtract(Duration(days: today.weekday - 1));

    final weekDays = List.generate(7, (index) {
      return monday.add(Duration(days: index));
    });

    // Streak window: last N days ending at today are "active" (login days)
    // currentStreak includes today, so streak days = today, today-1, ..., today-(streak-1)
    final streakDays = <DateTime>{};
    for (int i = 0; i < currentStreak; i++) {
      streakDays.add(today.subtract(Duration(days: i)));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: weekDays.map((date) {
        final isFuture = date.isAfter(today);
        final isToday = date == today;
        final isStreakDay = streakDays.contains(date);

        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final label = dayNames[date.weekday - 1];

        // Color: streak day = orange, future = faded, missed = grey
        Color iconColor;
        if (isStreakDay) {
          iconColor = AppColors.streakOrange;
        } else if (isFuture) {
          iconColor = AppColors.neutral.withValues(alpha: 0.2);
        } else {
          iconColor = AppColors.neutral.withValues(alpha: 0.5);
        }

        return Column(
          children: [
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isToday ? AppColors.streakOrange : AppColors.neutralText,
              ),
            ),
            const SizedBox(height: 4),
            if (isToday)
              Icon(Icons.arrow_drop_down, color: AppColors.streakOrange, size: 16)
            else
              const SizedBox(height: 16),
            Icon(Icons.local_fire_department_rounded, color: iconColor, size: 32),
          ],
        );
      }).toList(),
    );
  }
}
