import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import '../../utils/ui_helpers.dart';

/// Shows collection progress: "X/96 Cards" bar + category completion pills.
class CollectionProgressWidget extends StatelessWidget {
  const CollectionProgressWidget({
    super.key,
    required this.ownedCount,
    required this.totalCount,
    required this.categoryProgress,
  });

  final int ownedCount;
  final int totalCount;
  final Map<CardCategory, int> categoryProgress;

  @override
  Widget build(BuildContext context) {
    final progress = totalCount > 0 ? ownedCount / totalCount : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar with label
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$ownedCount / $totalCount Cards',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: AppColors.neutral,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getProgressColor(progress),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(progress * 100).toInt()}%',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _getProgressColor(progress),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Category completion pills
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: CardCategory.values.map((category) {
            final owned = categoryProgress[category] ?? 0;
            const perCategory = 12; // 12 cards per category
            final catColor = CardColors.getCategoryColor(category);
            final isComplete = owned >= perCategory;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isComplete
                    ? catColor.withValues(alpha: 0.15)
                    : AppColors.neutral.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isComplete
                      ? catColor.withValues(alpha: 0.4)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(category.icon, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    '$owned/$perCategory',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isComplete ? catColor : AppColors.neutralText,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 1.0) return AppColors.cardLegendary;
    if (progress >= 0.75) return AppColors.cardEpic;
    if (progress >= 0.5) return AppColors.cardRare;
    return AppColors.primary;
  }
}
