import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/reader_constants.dart';
import '../../../domain/entities/chapter.dart';
import '../../providers/reader_provider.dart';
import '../activities/common/activity_card.dart';
import '../activities/common/animated_game_button.dart';
import '../common/xp_badge.dart'; // Import XPBadge

/// Widget shown when chapter is complete.
/// Displays celebration and next steps.
class ChapterCompletionCard extends StatefulWidget {
  const ChapterCompletionCard({
    super.key,
    required this.hasNextChapter,
    required this.nextChapter,
    required this.settings,
    required this.sessionXP,
    required this.onNextChapter,
    required this.onBackToBook,
  });

  final bool hasNextChapter;
  final Chapter? nextChapter;
  final ReaderSettings settings;
  final int sessionXP;
  final VoidCallback onNextChapter;
  final VoidCallback onBackToBook;

  @override
  State<ChapterCompletionCard> createState() => _ChapterCompletionCardState();
}

class _ChapterCompletionCardState extends State<ChapterCompletionCard> {
  bool _showXPAnimation = false;

  @override
  void initState() {
    super.initState();
    // Trigger XP animation if we have XP to show
    if (widget.sessionXP > 0) {
      // Delay slightly for effect
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _showXPAnimation = true;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main Card
        ActivityCard(
          variant: ActivityCardVariant.neutral,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.hasNextChapter && widget.nextChapter != null)
                  _buildNextChapterContent()
                else
                  _buildBookCompleteContent(),
              ],
            ),
          ),
        ),

        // XP Animation Overlay
        if (_showXPAnimation)
          Positioned(
            top: -20, // Float above the card
            right: 0,
            left: 0,
            child: Center(
              child: XPBadge(
                xp: widget.sessionXP,
                onComplete: () {
                   if (mounted) {
                     setState(() => _showXPAnimation = false);
                   }
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNextChapterContent() {
    return Column(
      children: [
        const Icon(
          Icons.auto_stories_rounded,
          size: 48,
          color: ReaderConstants.nextChapterButtonColor,
        ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
        
        const SizedBox(height: 16),
        
        const Text(
          'Chapter Completed!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          'Ready for the next one?',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: AnimatedGameButton(
            label: 'Continue',
            onPressed: widget.onNextChapter,
            variant: GameButtonVariant.primary,
            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: AnimatedGameButton(
            label: 'Back to Book',
            onPressed: widget.onBackToBook,
            variant: GameButtonVariant.neutral,
          ),
        ),
      ],
    );
  }

  Widget _buildBookCompleteContent() {
    return Column(
      children: [
        // Trophy Icon
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.emoji_events_rounded, // Trophy
            size: 64,
            color: Colors.amber,
          ).animate().scale(
            duration: 600.ms, 
            curve: Curves.elasticOut,
            begin: const Offset(0.5, 0.5),
          ).shimmer(delay: 500.ms, duration: 1000.ms),
        ),

        const SizedBox(height: 20),

        const Text(
          'Book Completed!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

        const SizedBox(height: 8),

        Text(
          'You finished the whole book!',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ).animate().fadeIn(delay: 300.ms),

        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          child: AnimatedGameButton(
            label: 'Finish',
            onPressed: widget.onBackToBook,
            variant: GameButtonVariant.success, // Green for completion
            icon: const Icon(Icons.check_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
