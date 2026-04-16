import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../common/app_progress_bar.dart';

class VocabSessionProgressBar extends StatelessWidget {
  const VocabSessionProgressBar({
    super.key,
    required this.progress,
    this.comboActive = false,
  });

  final double progress;
  final bool comboActive;

  @override
  Widget build(BuildContext context) {
    return AppProgressBar(
      progress: progress,
      height: 12,
      fillColor: comboActive ? AppColors.streakOrange : AppColors.primary,
      fillShadow: comboActive ? const Color(0xFFC76A00) : AppColors.primaryDark,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }
}
