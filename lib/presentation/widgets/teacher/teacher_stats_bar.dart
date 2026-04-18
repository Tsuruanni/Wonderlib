import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../common/asset_icon.dart';
import '../common/playful_card.dart';

/// Shared stats bar used in both Class Overview and Class Students.
/// Guarantees identical ordering / icons / formatting so teachers see
/// the same "shape" of data on both surfaces.
class TeacherStatsBar extends StatelessWidget {
  const TeacherStatsBar({
    super.key,
    required this.activeCount,
    required this.totalStudents,
    required this.topLevel,
    required this.booksRead,
    required this.wordbankSize,
  });

  final int activeCount;
  final int totalStudents;
  final int topLevel;
  final int booksRead;
  final int wordbankSize;

  @override
  Widget build(BuildContext context) {
    return PlayfulCard(
      margin: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          if (totalStudents > 0)
            _TeacherStat(
              assetPath: AppIcons.fire,
              value: '$activeCount/$totalStudents',
              label: 'Active (30d)',
            ),
          if (topLevel > 0)
            _TeacherStat(
              assetPath: AppIcons.trophy,
              value: 'Lv $topLevel',
              label: 'Top Level',
            ),
          if (booksRead > 0)
            _TeacherStat(
              assetPath: AppIcons.book,
              value: '$booksRead',
              label: 'Books Read',
            ),
          if (wordbankSize > 0)
            _TeacherStat(
              assetPath: AppIcons.vocabulary,
              value: '$wordbankSize',
              label: 'Words in Wordbank',
            ),
        ],
      ),
    );
  }
}

class _TeacherStat extends StatelessWidget {
  const _TeacherStat({
    required this.assetPath,
    required this.value,
    required this.label,
  });

  final String assetPath;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AssetIcon(assetPath, size: 32),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.neutralText,
          ),
        ),
      ],
    );
  }
}
