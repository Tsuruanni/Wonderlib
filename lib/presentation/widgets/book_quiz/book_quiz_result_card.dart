import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../domain/entities/book_quiz.dart';
import '../../../../app/theme.dart';
import '../common/animated_game_button.dart';

/// Displays the quiz result after submission.
///
/// Shows score percentage with circular progress, pass/fail message,
/// attempt number, and action buttons.
class BookQuizResultCard extends StatelessWidget {
  const BookQuizResultCard({
    super.key,
    required this.result,
    required this.passingScore,
    required this.onRetake,
    required this.onFinish,
  });

  final BookQuizResult result;
  final double passingScore;
  final VoidCallback onRetake;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPassing = result.isPassing;
    final scorePercent = result.percentage;

    final statusColor = isPassing
        ? const Color(0xFF58CC02) // Green
        : const Color(0xFFFF4B4B); // Red

    const double depth = 6;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Stack(
        children: [
            // Bottom 3D Layer
            Positioned(
              top: depth,
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            // Top Card Layer
            Container(
              margin: const EdgeInsets.only(bottom: depth),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                    // Status icon
                    _buildStatusIcon(isPassing, statusColor),
                    const SizedBox(height: 24),
                    // Circular progress with score
                    _buildScoreCircle(context, scorePercent, statusColor),
                    const SizedBox(height: 24),
                    // Pass/Fail message
                    _buildStatusMessage(context, isPassing, statusColor),
                    const SizedBox(height: 8),
                    // Score details
                    _buildScoreDetails(context, colorScheme),
                    const SizedBox(height: 6),
                    // Attempt number
                    _buildAttemptInfo(context, colorScheme),
                    // Passing threshold info if failed
                    if (!isPassing) ...[
                        const SizedBox(height: 16),
                        _buildPassingThreshold(context, passingScore),
                    ],
                    const SizedBox(height: 32),
                    // Action buttons
                    _buildActionButtons(isPassing),
                ].animate(interval: 100.ms).fadeIn().slideY(begin: 0.2, end: 0),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(bool isPassing, Color statusColor) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(
            color: statusColor.withValues(alpha: 0.3),
            width: 3,
        ),
      ),
      child: Icon(
        isPassing ? Icons.emoji_events_rounded : Icons.refresh_rounded,
        size: 48,
        color: statusColor,
      ),
    ).animate().scale(
        duration: 600.ms,
        curve: Curves.elasticOut,
    );
  }

  Widget _buildScoreCircle(
      BuildContext context, double scorePercent, Color statusColor,) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: 140,
            height: 140,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 12,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFFF3F4F6),
              ),
            ),
          ),
          // Progress circle
          SizedBox(
            width: 140,
            height: 140,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: scorePercent / 100),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: 12,
                  strokeCap: StrokeCap.round,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                );
              },
            ),
          ),
          // Percentage text
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: scorePercent),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return Text(
                '${value.round()}%',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: statusColor,
                  fontFamily: 'Nunito',
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMessage(
      BuildContext context, bool isPassing, Color statusColor,) {
    return Text(
      isPassing ? 'Awesome!' : 'Don\'t give up!',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        color: statusColor,
        fontFamily: 'Nunito',
        height: 1.0,
      ),
    );
  }

  Widget _buildScoreDetails(BuildContext context, ColorScheme colorScheme) {
    return Text(
      'You scored ${result.score.round()} out of ${result.maxScore.round()}',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF6B7280),
        fontFamily: 'Nunito',
      ),
    );
  }

  Widget _buildAttemptInfo(BuildContext context, ColorScheme colorScheme) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
        'ATTEMPT #${result.attemptNumber}',
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF9CA3AF),
            fontFamily: 'Nunito',
            letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildPassingThreshold(BuildContext context, double passingScore) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFECDD3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_rounded,
            size: 20,
            color: const Color(0xFFE11D48),
          ),
          const SizedBox(width: 8),
          Text(
            'Hit ${passingScore.round()}% to pass',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFE11D48),
              fontFamily: 'Nunito',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isPassing) {
    return Column(
      children: [
        // Retake button (always shown)
        AnimatedGameButton(
          label: isPassing ? 'Retake Quiz' : 'Try Again',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: onRetake,
          variant:
              isPassing ? GameButtonVariant.neutral : GameButtonVariant.primary,
          fullWidth: true,
          height: 56,
        ),
        const SizedBox(height: 16),
        // Finish button
        AnimatedGameButton(
          label: isPassing ? 'Complete' : 'Exit Quiz',
          icon: Icon(
            isPassing ? Icons.check_rounded : Icons.arrow_back_rounded,
          ),
          onPressed: onFinish,
          variant:
              isPassing ? GameButtonVariant.success : GameButtonVariant.neutral,
          fullWidth: true,
          height: 56,
        ),
      ],
    );
  }
}
