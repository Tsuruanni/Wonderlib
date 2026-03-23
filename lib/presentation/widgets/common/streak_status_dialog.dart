import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/utils/app_clock.dart';

class StreakStatusDialog extends StatelessWidget {
  const StreakStatusDialog({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    required this.activeDates,
    required this.streakFreezeCount,
    required this.streakFreezeMax,
    required this.streakFreezePrice,
    required this.userCoins,
    this.onBuyFreeze,
  });

  final int currentStreak;
  final int longestStreak;
  final List<DateTime> activeDates;
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

    // Normalize active dates to avoid time mismatch
    final normalizedActiveDates = activeDates.map((d) => DateTime(d.year, d.month, d.day)).toSet();

    // Infer frozen days: past days with no activity but within streak window.
    // If the streak is longer than the active days this week, the gap days were frozen.
    final pastDaysThisWeek = weekDays.where((d) => !d.isAfter(today)).toList();
    final activePastDays = pastDaysThisWeek.where((d) => normalizedActiveDates.contains(d)).length;
    final inactivePastDays = pastDaysThisWeek.length - activePastDays;
    // If streak >= past days count, inactive past days must be frozen
    final hasFrozenDays = currentStreak >= pastDaysThisWeek.length && inactivePastDays > 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: weekDays.map((date) {
        final isFuture = date.isAfter(today);
        final isActive = normalizedActiveDates.contains(DateTime(date.year, date.month, date.day));
        final isFrozen = !isFuture && !isActive && hasFrozenDays;

        // English day names
        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final label = dayNames[date.weekday - 1];

        // Determine icon and color
        IconData icon;
        Color iconColor;
        if (isActive) {
          icon = Icons.local_fire_department_rounded;
          iconColor = AppColors.streakOrange;
        } else if (isFrozen) {
          icon = Icons.ac_unit;
          iconColor = Colors.blue.shade400;
        } else if (isFuture) {
          icon = Icons.local_fire_department_rounded;
          iconColor = AppColors.neutral.withValues(alpha: 0.2);
        } else {
          icon = Icons.local_fire_department_rounded;
          iconColor = AppColors.neutral.withValues(alpha: 0.5);
        }

        return Column(
          children: [
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.neutralText,
              ),
            ),
            const SizedBox(height: 8),
            Icon(icon, color: iconColor, size: 32),
          ],
        );
      }).toList(),
    );
  }
}
