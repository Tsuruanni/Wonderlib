import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/theme.dart';

/// Horizontal progress bar showing question N of M.
///
/// Features a thick, rounded continuous bar.
class BookQuizProgressBar extends StatelessWidget {
  const BookQuizProgressBar({
    super.key,
    required this.currentIndex,
    required this.totalQuestions,
  });

  final int currentIndex;
  final int totalQuestions;

  @override
  Widget build(BuildContext context) {
    final double progress = totalQuestions > 0
        ? (currentIndex + 1) / totalQuestions
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress Bar
          Container(
            height: 16,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.gray200, // Grey-200
              borderRadius: BorderRadius.circular(12),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth * progress;
                return Stack(
                  children: [
                    // Fill
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.fastOutSlowIn,
                      width: width,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      // Shimmer/highlight effect
                       child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
  }
}
