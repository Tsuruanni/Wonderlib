import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/achievement_group.dart';

/// Duolingo-style achievement row: colored "button" tile on the left with the
/// emoji and (optional) LEVEL label, title + progress + description on the right.
/// Maxed groups get a gold gradient treatment to make completion feel rewarding.
class AchievementGroupRow extends StatelessWidget {
  const AchievementGroupRow({super.key, required this.group});

  final AchievementGroup group;

  /// Stable category-based color (NOT hash-based). MAX state overrides to gold.
  ({Color base, Color shadow}) _tileColors() {
    if (group.isMaxed) {
      return (base: AppColors.wasp, shadow: AppColors.waspDark);
    }

    // Myth categories — each gets its own thematic color.
    if (group.groupKey.startsWith('myth_category_completed:')) {
      final slug = group.groupKey.substring('myth_category_completed:'.length);
      switch (slug) {
        case 'turkish_myths':
          return (base: AppColors.danger, shadow: AppColors.dangerDark);
        case 'ancient_greece':
          return (base: AppColors.secondary, shadow: AppColors.secondaryDark);
        case 'viking_ice_lands':
          return (base: AppColors.gemBlue, shadow: AppColors.secondaryDark);
        case 'egyptian_deserts':
          return (base: AppColors.wasp, shadow: AppColors.waspDark);
        case 'far_east':
          return (base: AppColors.primary, shadow: AppColors.primaryDark);
        case 'medieval_magic':
          return (base: AppColors.cardEpic, shadow: AppColors.cardEpicDark);
        case 'legendary_weapons':
          return (base: AppColors.cardCommon, shadow: AppColors.cardCommonDark);
        case 'dark_creatures':
          return (base: AppColors.backgroundDark, shadow: Colors.black);
        default:
          return (base: AppColors.cardEpic, shadow: AppColors.cardEpicDark);
      }
    }

    // Other groups — fixed color per condition_type.
    switch (group.groupKey) {
      case 'xp_total':
        return (base: AppColors.primary, shadow: AppColors.primaryDark);
      case 'streak_days':
        return (base: AppColors.streakOrange, shadow: AppColors.dangerDark);
      case 'books_completed':
        return (base: AppColors.secondary, shadow: AppColors.secondaryDark);
      case 'vocabulary_learned':
        return (base: AppColors.cardEpic, shadow: AppColors.cardEpicDark);
      case 'perfect_scores':
        return (base: AppColors.wasp, shadow: AppColors.waspDark);
      case 'level_completed':
        return (base: AppColors.wasp, shadow: AppColors.waspDark);
      case 'cards_collected':
        return (base: AppColors.cardEpic, shadow: AppColors.cardEpicDark);
      case 'league_tier_reached':
        return (base: AppColors.wasp, shadow: AppColors.waspDark);
      default:
        return (base: AppColors.cardCommon, shadow: AppColors.cardCommonDark);
    }
  }

  /// Renders the icon as Image.asset when it starts with 'assets/', otherwise as
  /// a Text emoji. Asset images are sized larger to feel comparable visually to
  /// the emoji text size.
  static Widget _buildIconContent(
    String icon, {
    required double emojiSize,
    required double imageSize,
  }) {
    if (icon.startsWith('assets/')) {
      return Image.asset(
        icon,
        width: imageSize,
        height: imageSize,
        fit: BoxFit.contain,
      );
    }
    return Text(icon, style: TextStyle(fontSize: emojiSize));
  }

  @override
  Widget build(BuildContext context) {
    final colors = _tileColors();
    final showLevelLabel = group.maxLevel >= 3;
    final progressLabel = group.isMaxed
        ? 'MAX'
        : '${group.currentValue}/${group.targetValue}';
    const fillColor = AppColors.wasp;
    const fillShadow = Color(0xFFE0A800);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Button-like tile with bottom shadow for "tactile" feel
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colors.base,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow,
                  offset: const Offset(0, 4),
                  blurRadius: 0,
                ),
              ],
              border: Border.all(color: colors.shadow, width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIconContent(
                  group.displayIcon,
                  emojiSize: (showLevelLabel && (group.isMaxed || group.currentLevel >= 1))
                      ? 30
                      : 38,
                  imageSize: (showLevelLabel && (group.isMaxed || group.currentLevel >= 1))
                      ? 44
                      : 56,
                ),
                if (showLevelLabel && (group.isMaxed || group.currentLevel >= 1)) ...[
                  const SizedBox(height: 2),
                  Text(
                    group.isMaxed ? 'MAX' : 'LEVEL ${group.currentLevel}',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right column: title + progress + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.displayTitle,
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: AppColors.black,
                        ),
                      ),
                    ),
                    Text(
                      progressLabel,
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: group.isMaxed ? AppColors.waspDark : AppColors.gray500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _ProgressBar(
                  progress: group.progress,
                  fillColor: fillColor,
                  fillShadow: fillShadow,
                ),
                if (group.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    group.description,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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

/// Custom progress bar with rounded ends, slight shadow on the fill, and
/// a 12px height to feel chunky/tactile like Duolingo's bars.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.progress,
    required this.fillColor,
    required this.fillShadow,
  });

  final double progress;
  final Color fillColor;
  final Color fillShadow;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: AppColors.gray200,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(999),
                border: Border(
                  bottom: BorderSide(color: fillShadow, width: 3),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
