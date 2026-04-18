import 'dart:math';

import 'package:flutter/material.dart';

import '../../../domain/entities/activity.dart';
import '../../providers/reader_provider.dart';
import '../common/xp_badge.dart';
import '../common/activity_card.dart';
import '../common/animated_game_button.dart';
import '../common/feedback_animation.dart';
import 'inline_activity_sound_mixin.dart';
import '../../../app/text_styles.dart';

/// Matching activity widget (tap-to-match pairs) - Duolingo style
class InlineMatchingActivity extends StatefulWidget {
  const InlineMatchingActivity({
    super.key,
    required this.activity,
    required this.settings,
    required this.onAnswer,
    this.isCompleted = false,
    this.wasCorrect,
    this.xpValue = 25,
  });

  final InlineActivity activity;
  final ReaderSettings settings;
  final void Function(bool isCorrect, List<String> wordsLearned) onAnswer;
  final bool isCompleted;
  final bool? wasCorrect;
  final int xpValue;

  @override
  State<InlineMatchingActivity> createState() => _InlineMatchingActivityState();
}

class _InlineMatchingActivityState extends State<InlineMatchingActivity>
    with InlineActivitySoundMixin {
  /// Shuffled right-side items (computed once in initState)
  late List<String> _shuffledRightItems;

  /// Currently selected left index (null = nothing selected)
  int? _selectedLeft;

  /// Currently selected right index (null = nothing selected)
  int? _selectedRight;

  /// Successfully matched pairs: left index → right index
  final Map<int, int> _matchedPairs = {};

  /// Track wrong attempt for brief red flash
  int? _wrongLeft;
  int? _wrongRight;

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
      // Show all pairs matched using indices
      for (var i = 0; i < content.pairs.length; i++) {
        final rightIdx = _shuffledRightItems.indexOf(content.pairs[i].right);
        if (rightIdx >= 0) {
          _matchedPairs[i] = rightIdx;
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant InlineMatchingActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCompleted && !widget.isCompleted) {
      setState(() {
        _isFinished = false;
        _isCorrect = null;
        _matchedPairs.clear();
        _selectedLeft = null;
        _selectedRight = null;
        _wrongLeft = null;
        _wrongRight = null;
        _mistakeCount = 0;
        _showXPAnimation = false;
        _shuffledRightItems = content.pairs.map((p) => p.right).toList()
          ..shuffle(Random());
      });
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

  void _onTapLeft(int leftIndex) {
    if (_isFinished || widget.isCompleted) return;
    if (_matchedPairs.containsKey(leftIndex)) return;

    setState(() {
      _selectedLeft = leftIndex;
      _wrongLeft = null;
      _wrongRight = null;
    });

    if (_selectedRight != null) {
      _tryMatch();
    }
  }

  void _onTapRight(int rightIndex) {
    if (_isFinished || widget.isCompleted) return;
    if (_matchedPairs.containsValue(rightIndex)) return;

    setState(() {
      _selectedRight = rightIndex;
      _wrongLeft = null;
      _wrongRight = null;
    });

    if (_selectedLeft != null) {
      _tryMatch();
    }
  }

  void _tryMatch() {
    final leftIdx = _selectedLeft!;
    final rightIdx = _selectedRight!;
    final leftValue = content.pairs[leftIdx].left;
    final correctRight = _getCorrectRight(leftValue);
    final rightValue = _shuffledRightItems[rightIdx];

    if (rightValue == correctRight) {
      playSound(true);
      setState(() {
        _matchedPairs[leftIdx] = rightIdx;
        _selectedLeft = null;
        _selectedRight = null;
      });

      if (_matchedPairs.length == content.pairs.length) {
        _onAllMatched();
      }
    } else {
      playSound(false);
      _mistakeCount++;
      setState(() {
        _wrongLeft = leftIdx;
        _wrongRight = rightIdx;
        _selectedLeft = null;
        _selectedRight = null;
      });

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
                style: AppTextStyles.titleMedium(color: Colors.black87).copyWith(fontSize: widget.settings.fontSize, height: 1.4),
              ),

              const SizedBox(height: 16),

              // Two-column layout
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column
                  Expanded(
                    child: Column(
                      children: List.generate(content.pairs.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildLeftButton(index, content.pairs[index].left),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Right column (shuffled)
                  Expanded(
                    child: Column(
                      children: List.generate(_shuffledRightItems.length, (rightIndex) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildRightButton(rightIndex, _shuffledRightItems[rightIndex]),
                        );
                      }),
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
              xp: widget.xpValue,
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

  Widget _buildLeftButton(int index, String left) {
    final isMatched = _matchedPairs.containsKey(index);
    final isSelected = _selectedLeft == index;
    final isWrong = _wrongLeft == index;

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
              : () => _onTapLeft(index),
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

  Widget _buildRightButton(int rightIndex, String right) {
    final isMatched = _matchedPairs.containsValue(rightIndex);
    final isSelected = _selectedRight == rightIndex;
    final isWrong = _wrongRight == rightIndex;

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
              : () => _onTapRight(rightIndex),
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
