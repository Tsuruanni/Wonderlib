import 'dart:math';

import 'package:flutter/material.dart';

import '../../../domain/entities/activity.dart';
import '../../providers/reader_provider.dart';
import '../common/xp_badge.dart';
import '../common/activity_card.dart';
import '../common/animated_game_button.dart';
import '../common/feedback_animation.dart';
import 'inline_activity_sound_mixin.dart';

/// Matching activity widget (tap-to-match pairs) - Duolingo style
class InlineMatchingActivity extends StatefulWidget {
  const InlineMatchingActivity({
    super.key,
    required this.activity,
    required this.settings,
    required this.onAnswer,
    this.isCompleted = false,
    this.wasCorrect,
  });

  final InlineActivity activity;
  final ReaderSettings settings;
  final void Function(bool isCorrect, List<String> wordsLearned) onAnswer;
  final bool isCompleted;
  final bool? wasCorrect;

  @override
  State<InlineMatchingActivity> createState() => _InlineMatchingActivityState();
}

class _InlineMatchingActivityState extends State<InlineMatchingActivity>
    with InlineActivitySoundMixin {
  /// Shuffled right-side items (computed once in initState)
  late List<String> _shuffledRightItems;

  /// Currently selected left item (null = nothing selected)
  String? _selectedLeft;

  /// Currently selected right item (null = nothing selected)
  String? _selectedRight;

  /// Successfully matched pairs: left → right
  final Map<String, String> _matchedPairs = {};

  /// Track wrong attempt for brief red flash
  String? _wrongLeft;
  String? _wrongRight;

  /// Mistake counter for strict scoring
  int _mistakeCount = 0;

  /// Final state
  bool _isFinished = false;
  bool? _isCorrect;
  bool _showXPAnimation = false;

  MatchingContent get content => widget.activity.content as MatchingContent;

  @override
  void initState() {
    super.initState();
    initSoundPlayer();

    // Shuffle right items once
    _shuffledRightItems = content.pairs.map((p) => p.right).toList()
      ..shuffle(Random());

    if (widget.isCompleted) {
      _isFinished = true;
      _isCorrect = widget.wasCorrect;
      // Show all pairs matched
      for (final pair in content.pairs) {
        _matchedPairs[pair.left] = pair.right;
      }
    }
  }

  @override
  void dispose() {
    disposeSoundPlayer();
    super.dispose();
  }

  /// Get the correct right value for a left item
  String? _getCorrectRight(String left) {
    for (final pair in content.pairs) {
      if (pair.left == left) return pair.right;
    }
    return null;
  }

  void _onTapLeft(String left) {
    if (_isFinished || widget.isCompleted) return;
    if (_matchedPairs.containsKey(left)) return; // Already matched

    setState(() {
      _selectedLeft = left;
      _wrongLeft = null;
      _wrongRight = null;
    });

    // If right is already selected, try to match
    if (_selectedRight != null) {
      _tryMatch();
    }
  }

  void _onTapRight(String right) {
    if (_isFinished || widget.isCompleted) return;
    if (_matchedPairs.containsValue(right)) return; // Already matched

    setState(() {
      _selectedRight = right;
      _wrongLeft = null;
      _wrongRight = null;
    });

    // If left is already selected, try to match
    if (_selectedLeft != null) {
      _tryMatch();
    }
  }

  void _tryMatch() {
    final left = _selectedLeft!;
    final right = _selectedRight!;
    final correctRight = _getCorrectRight(left);

    if (right == correctRight) {
      // Correct match
      playSound(true);
      setState(() {
        _matchedPairs[left] = right;
        _selectedLeft = null;
        _selectedRight = null;
      });

      // Check if all matched
      if (_matchedPairs.length == content.pairs.length) {
        _onAllMatched();
      }
    } else {
      // Wrong match
      playSound(false);
      _mistakeCount++;
      setState(() {
        _wrongLeft = left;
        _wrongRight = right;
        _selectedLeft = null;
        _selectedRight = null;
      });

      // Reset wrong indicators after 500ms
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _wrongLeft = null;
            _wrongRight = null;
          });
        }
      });
    }
  }

  void _onAllMatched() {
    final isCorrect = _mistakeCount == 0;

    setState(() {
      _isFinished = true;
      _isCorrect = isCorrect;
      if (isCorrect) {
        _showXPAnimation = true;
      }
    });

    // Call onAnswer after delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        widget.onAnswer(
          isCorrect,
          widget.activity.vocabularyWords,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool finished = _isFinished || widget.isCompleted;
    final bool? correct = _isCorrect ?? widget.wasCorrect;

    ActivityCardVariant cardVariant = ActivityCardVariant.neutral;
    if (finished && correct != null) {
      cardVariant =
          correct ? ActivityCardVariant.correct : ActivityCardVariant.wrong;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ActivityCard(
          variant: cardVariant,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Instruction
              Text(
                content.instruction,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: widget.settings.fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  height: 1.4,
                  fontFamily: 'Nunito',
                ),
              ),

              const SizedBox(height: 16),

              // Two-column layout
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column
                  Expanded(
                    child: Column(
                      children: content.pairs.map((pair) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildLeftButton(pair.left),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Right column (shuffled)
                  Expanded(
                    child: Column(
                      children: _shuffledRightItems.map((right) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildRightButton(right),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),

              // Match counter
              if (!finished) ...[
                const SizedBox(height: 12),
                Text(
                  '${_matchedPairs.length} of ${content.pairs.length} matched',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                    letterSpacing: 1,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Feedback Overlay
        if (finished && correct != null)
          Positioned.fill(
            child: Center(
              child: FeedbackAnimation(
                isCorrect: correct,
              ),
            ),
          ),

        // XP Animation
        if (_showXPAnimation)
          Positioned(
            top: 10,
            right: 0,
            child: XPBadge(
              xp: widget.activity.xpReward,
              onComplete: () {
                if (mounted) {
                  setState(() => _showXPAnimation = false);
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _buildLeftButton(String left) {
    final isMatched = _matchedPairs.containsKey(left);
    final isSelected = _selectedLeft == left;
    final isWrong = _wrongLeft == left;

    GameButtonVariant variant;

    if (isMatched) {
      variant = GameButtonVariant.success;
    } else if (isWrong) {
      variant = GameButtonVariant.danger;
    } else if (isSelected) {
      variant = GameButtonVariant.secondary;
    } else {
      variant = GameButtonVariant.neutral;
    }

    return AnimatedGameButton(
      label: left,
      onPressed:
          (isMatched || _isFinished || widget.isCompleted)
              ? null
              : () => _onTapLeft(left),
      variant: variant,
      fullWidth: true,
      height: 40,
      borderRadius: 12,
      textStyle: TextStyle(
        color: _getButtonTextColor(variant),
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    );
  }

  Widget _buildRightButton(String right) {
    final isMatched = _matchedPairs.containsValue(right);
    final isSelected = _selectedRight == right;
    final isWrong = _wrongRight == right;

    GameButtonVariant variant;

    if (isMatched) {
      variant = GameButtonVariant.success;
    } else if (isWrong) {
      variant = GameButtonVariant.danger;
    } else if (isSelected) {
      variant = GameButtonVariant.secondary;
    } else {
      variant = GameButtonVariant.neutral;
    }

    return AnimatedGameButton(
      label: right,
      onPressed:
          (isMatched || _isFinished || widget.isCompleted)
              ? null
              : () => _onTapRight(right),
      variant: variant,
      fullWidth: true,
      height: 40,
      borderRadius: 12,
      textStyle: TextStyle(
        color: _getButtonTextColor(variant),
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    );
  }

  Color _getButtonTextColor(GameButtonVariant variant) {
    switch (variant) {
      case GameButtonVariant.neutral:
      case GameButtonVariant.outline:
        return Colors.black87;
      default:
        return Colors.white;
    }
  }
}
