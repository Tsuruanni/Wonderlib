import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/streak_result.dart';

class StreakEventDialog extends StatelessWidget {
  const StreakEventDialog({super.key, required this.result});

  final StreakResult result;

  @override
  Widget build(BuildContext context) {
    // Priority: milestone > freeze-saved > streak-broken
    if (result.milestoneBonusXp > 0) {
      return _buildMilestoneDialog(context);
    } else if (result.freezeUsed && !result.streakBroken) {
      return _buildFreezeSavedDialog(context);
    } else if (result.streakBroken && result.previousStreak >= 3) {
      return _buildStreakBrokenDialog(context);
    }
    return const SizedBox.shrink();
  }

  Widget _buildMilestoneDialog(BuildContext context) {
    return _buildDialog(
      context,
      icon: Icons.local_fire_department_rounded,
      iconColor: AppColors.streakOrange,
      title: '${result.newStreak}-Day Streak!',
      subtitle: '+${result.milestoneBonusXp} XP earned!',
      subtitleColor: AppColors.streakOrange,
    );
  }

  Widget _buildFreezeSavedDialog(BuildContext context) {
    return _buildDialog(
      context,
      icon: Icons.ac_unit,
      iconColor: Colors.blue.shade400,
      title: 'Streak Freeze Saved You!',
      subtitle: 'Your ${result.newStreak}-day streak is safe.\n${result.freezesRemaining} freeze${result.freezesRemaining == 1 ? '' : 's'} left.',
      subtitleColor: Colors.blue.shade600,
    );
  }

  Widget _buildStreakBrokenDialog(BuildContext context) {
    final prev = result.previousStreak;

    // Tiered messages based on how long the broken streak was
    String title;
    String subtitle;

    if (prev <= 6) {
      title = 'Welcome Back!';
      subtitle = 'Start a new streak today.';
    } else if (prev <= 9) {
      title = 'Your $prev-day streak ended';
      subtitle = 'You can build it again!';
    } else if (prev <= 20) {
      title = 'Your $prev-day streak was broken';
      subtitle = "Don't give up!";
    } else {
      title = 'Your $prev-day streak was broken';
      subtitle = 'That was impressive — you can do it again!';
    }

    // Add freeze info if partial freeze was consumed
    if (result.freezesConsumed > 0) {
      subtitle += '\n\nYour ${result.freezesConsumed} freeze${result.freezesConsumed == 1 ? '' : 's'} covered ${result.freezesConsumed} day${result.freezesConsumed == 1 ? '' : 's'}, but you were away too long.';
    }

    return _buildDialog(
      context,
      icon: Icons.local_fire_department_rounded,
      iconColor: Colors.grey.shade400,
      title: title,
      subtitle: subtitle,
      subtitleColor: Colors.grey.shade600,
    );
  }

  Widget _buildDialog(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color subtitleColor,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(32),
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
            Icon(icon, color: iconColor, size: 72),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.nunito(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: subtitleColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'OK',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
