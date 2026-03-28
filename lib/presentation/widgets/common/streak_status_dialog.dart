import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/utils/app_clock.dart';
import '../../providers/user_provider.dart';

class StreakStatusDialog extends ConsumerStatefulWidget {
  const StreakStatusDialog({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    required this.calendarDays,
    required this.streakFreezeCount,
    required this.streakFreezeMax,
    required this.streakFreezePrice,
    required this.userCoins,
  });

  final int currentStreak;
  final int longestStreak;
  /// Map of date → is_freeze (true = freeze day, false = login day)
  final Map<DateTime, bool> calendarDays;
  final int streakFreezeCount;
  final int streakFreezeMax;
  final int streakFreezePrice;
  final int userCoins;

  @override
  ConsumerState<StreakStatusDialog> createState() => _StreakStatusDialogState();
}

class _StreakStatusDialogState extends ConsumerState<StreakStatusDialog> {
  bool _isLoading = false;

  Future<void> _handleBuyFreeze() async {
    setState(() => _isLoading = true);
    final error = await ref.read(userControllerProvider.notifier).buyStreakFreeze();
    if (!mounted) return;
    if (error != null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

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
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle for aesthetics
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
                  '${widget.currentStreak}',
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
                  top: BorderSide(color: AppColors.neutral.withValues(alpha: 0.5), width: 2),
                ),
              ),
              child: Text(
                'Longest Streak: ${widget.longestStreak} days',
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
                    'Streak Freezes: ${widget.streakFreezeCount}/${widget.streakFreezeMax}',
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
            if (widget.streakFreezeCount < widget.streakFreezeMax)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : (widget.userCoins >= widget.streakFreezePrice ? _handleBuyFreeze : null),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ac_unit, size: 18),
                  label: Text(
                    _isLoading ? 'Buying...' : 'Buy Freeze (${widget.streakFreezePrice} coins)',
                  ),
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
            if (widget.streakFreezeCount >= widget.streakFreezeMax)
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
                  shadowColor: const Color(0xFFCC4100),
                ).copyWith(
                  elevation: WidgetStateProperty.all(0),
                  side: WidgetStateProperty.resolveWith((states) {
                     if (states.contains(WidgetState.pressed)) {
                       return const BorderSide(color: Colors.transparent);
                     }
                     return const BorderSide(
                       color: Color(0xFFCC4100),
                       width: 0,
                     );
                  }),
                ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildWeekRow() {
    final today = AppClock.today();
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final weekDays = List.generate(7, (index) => monday.add(Duration(days: index)));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: weekDays.map((date) {
        final isFuture = date.isAfter(today);
        final isToday = date == today;
        final isFreeze = widget.calendarDays[date] == true;
        final isLogin = widget.calendarDays[date] == false;

        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final label = dayNames[date.weekday - 1];

        // Login → orange | Freeze → blue | Future → faded | Rest → grey
        Color iconColor;
        if (isLogin) {
          iconColor = AppColors.streakOrange;
        } else if (isFreeze) {
          iconColor = Colors.blue.shade400;
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
