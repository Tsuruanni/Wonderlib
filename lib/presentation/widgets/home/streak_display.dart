import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:readeng/app/theme.dart';

/// Displays the current streak with animated fire icon
class StreakDisplay extends StatelessWidget {
  final int streakDays;

  const StreakDisplay({
    super.key,
    required this.streakDays,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Number + Fire icon in a row
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '$streakDays',
              style: GoogleFonts.nunito(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: streakDays > 0 ? AppColors.streakOrange : AppColors.neutralText,
              ),
            ),
            const SizedBox(width: 2),
            _buildFireIcon(),
          ],
        ),
        // "day streak" label
        Text(
          streakDays == 1 ? 'day streak' : 'days streak',
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.neutralText,
          ),
        ),
      ],
    );
  }

  Widget _buildFireIcon() {
    if (streakDays == 0) {
      return const Icon(
        Icons.local_fire_department_rounded,
        size: 28,
        color: AppColors.neutral,
      );
    }

    return Icon(
      Icons.local_fire_department_rounded,
      size: 28,
      color: AppColors.streakOrange,
    )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scaleXY(
          begin: 1.0,
          end: 1.12,
          duration: 700.ms,
          curve: Curves.easeInOut,
        )
        .shimmer(
          duration: 1200.ms,
          color: Colors.orange.withValues(alpha: 0.4),
        );
  }
}
