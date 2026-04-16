import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/achievement_group.dart';

/// One row of the All Badges screen — Duolingo-style: colored icon tile with
/// LEVEL label on the left, title + progress bar + X/Y count + description right.
class AchievementGroupRow extends StatelessWidget {
  const AchievementGroupRow({super.key, required this.group});

  final AchievementGroup group;

  /// Cycle through the gamification palette based on the group key hash so
  /// rows visually differ even when all are partially complete.
  Color _tileColor() {
    const palette = [
      AppColors.danger,
      AppColors.primary,
      AppColors.wasp,
      AppColors.secondary,
      AppColors.streakOrange,
    ];
    final idx = group.groupKey.hashCode.abs() % palette.length;
    return palette[idx];
  }

  @override
  Widget build(BuildContext context) {
    final tileColor = _tileColor();
    final progress = group.progress;
    final progressLabel = group.isMaxed
        ? 'MAX'
        : '${group.currentValue}/${group.targetValue}';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.gray200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon tile with LEVEL label
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: tileColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(group.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 2),
                Text(
                  group.isMaxed ? 'MAX' : 'LEVEL ${group.currentLevel}',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Text + progress column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.title,
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.neutralText,
                        ),
                      ),
                    ),
                    Text(
                      progressLabel,
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.gray600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.gray200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      group.isMaxed ? AppColors.primary : AppColors.wasp,
                    ),
                  ),
                ),
                if (group.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    group.description,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: AppColors.gray600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
