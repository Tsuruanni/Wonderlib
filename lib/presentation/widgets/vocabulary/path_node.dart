import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/word_list.dart';
import '../../providers/vocabulary_provider.dart';

/// A single node on the learning path representing one word list.
/// Shows a circle with progress ring, icon, and label below.
class PathNode extends StatelessWidget {
  const PathNode({
    super.key,
    required this.wordListWithProgress,
    required this.unitColor,
  });

  final WordListWithProgress wordListWithProgress;
  final Color unitColor;

  @override
  Widget build(BuildContext context) {
    final wordList = wordListWithProgress.wordList;
    final isComplete = wordListWithProgress.isComplete;
    final isStarted = wordListWithProgress.isStarted;
    final progress = wordListWithProgress.progressPercentage;

    final nodeColor = isComplete
        ? AppColors.wasp
        : isStarted
            ? unitColor
            : AppColors.neutral;

    return GestureDetector(
      onTap: () => context.push('/vocabulary/list/${wordList.id}'),
      child: SizedBox(
        width: 88,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circle with progress ring
            SizedBox(
              width: 68,
              height: 68,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Progress ring
                  SizedBox(
                    width: 68,
                    height: 68,
                    child: CircularProgressIndicator(
                      value: isComplete ? 1.0 : progress,
                      strokeWidth: 5,
                      strokeCap: ui.StrokeCap.round,
                      backgroundColor: AppColors.neutral,
                      valueColor: AlwaysStoppedAnimation<Color>(nodeColor),
                    ),
                  ),
                  // Inner circle
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isComplete
                          ? AppColors.wasp
                          : isStarted
                              ? unitColor
                              : AppColors.white,
                      border: !isStarted
                          ? Border.all(color: AppColors.neutral, width: 2)
                          : null,
                      boxShadow: isStarted
                          ? [
                              BoxShadow(
                                color: nodeColor.withValues(alpha: 0.3),
                                offset: const Offset(0, 3),
                                blurRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: isComplete
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 26,
                            )
                          : Text(
                              wordList.category.icon,
                              style: TextStyle(
                                fontSize: 22,
                                color: isStarted ? null : AppColors.neutralText,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Label
            Text(
              wordList.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isStarted ? AppColors.black : AppColors.neutralText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
