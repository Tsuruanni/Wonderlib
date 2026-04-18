import 'package:flutter/material.dart';

import '../../../app/text_styles.dart';
import '../../../app/theme.dart';
import 'tile_themes.dart';

/// Separator between map tiles showing unit name.
/// Rendered as a standalone widget between tiles (not inside a tile).
class UnitDivider extends StatelessWidget {
  const UnitDivider({
    super.key,
    required this.unitIndex,
    required this.unitName,
    this.unitIcon,
    this.isLocked = false,
  });

  final int unitIndex;
  final String unitName;
  final String? unitIcon;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kDividerHeight,
      child: OverflowBox(
        maxWidth: kTileWidth,
        minWidth: kTileWidth,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            children: [
              const Expanded(child: Divider(color: AppColors.neutral, thickness: 2)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${unitIcon ?? ''} UNIT ${unitIndex + 1}  $unitName'.trim(),
                  style: AppTextStyles.button(color: isLocked ? AppColors.neutralText : AppColors.black).copyWith(fontSize: 14, letterSpacing: 0.5),
                ),
              ),
              const Expanded(child: Divider(color: AppColors.neutral, thickness: 2)),
            ],
          ),
        ),
      ),
    );
  }
}
