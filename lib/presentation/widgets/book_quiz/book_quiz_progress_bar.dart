import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../common/app_progress_bar.dart';

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
    final double progress =
        totalQuestions > 0 ? (currentIndex + 1) / totalQuestions : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: AppProgressBar(
        progress: progress,
        height: 12,
        duration: const Duration(milliseconds: 500),
        curve: Curves.fastOutSlowIn,
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
  }
}
