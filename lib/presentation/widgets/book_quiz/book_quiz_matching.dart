import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../domain/entities/book_quiz.dart';
import '../../../../app/theme.dart';

/// Two-column tap-to-match widget for quiz matching questions.
///
/// User taps a left item, then a right item to create a pair.
/// Matched pairs shown with a shared color.
class BookQuizMatching extends StatefulWidget {
  const BookQuizMatching({
    super.key,
    required this.content,
    required this.onAnswer,
    this.currentPairs,
  });

  final QuizMatchingContent content;
  final void Function(Map<int, int> pairs) onAnswer;
  final Map<int, int>? currentPairs;

  @override
  State<BookQuizMatching> createState() => _BookQuizMatchingState();
}

class _BookQuizMatchingState extends State<BookQuizMatching> {
  /// Currently matched pairs: left index -> right index.
  late Map<int, int> _pairs;

  /// Currently selected left index (null = nothing selected).
  int? _selectedLeft;

  /// Currently selected right index (null = nothing selected).
  int? _selectedRight;

  /// Colors assigned to matched pairs.
  static const List<Color> _pairColors = [
    Color(0xFF58CC02), // Green
    Color(0xFF1CB0F6), // Blue
    Color(0xFFFFC800), // Gold
    Color(0xFFFF4B4B), // Red
    Color(0xFF9B59B6), // Purple
    Color(0xFFFF9600), // Orange
    Color(0xFF2ECC71), // Emerald
    Color(0xFFE91E63), // Pink
  ];

  @override
  void initState() {
    super.initState();
    _pairs = widget.currentPairs != null
        ? Map<int, int>.from(widget.currentPairs!)
        : {};
  }

  @override
  void didUpdateWidget(BookQuizMatching oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPairs != oldWidget.currentPairs &&
        widget.currentPairs != null) {
      _pairs = Map<int, int>.from(widget.currentPairs!);
    }
  }

  Color _getMatchColor(int pairIndex) {
    return _pairColors[pairIndex % _pairColors.length];
  }

  /// Returns the color for a matched left item, or null if not matched.
  Color? _getLeftMatchColor(int leftIndex) {
    if (!_pairs.containsKey(leftIndex)) return null;
    final pairOrder = _pairs.keys.toList().indexOf(leftIndex);
    return _getMatchColor(pairOrder);
  }

  /// Returns the color for a matched right item, or null if not matched.
  Color? _getRightMatchColor(int rightIndex) {
    final entry = _pairs.entries
        .where((e) => e.value == rightIndex)
        .firstOrNull;
    if (entry == null) return null;
    final pairOrder = _pairs.keys.toList().indexOf(entry.key);
    return _getMatchColor(pairOrder);
  }

  void _onTapLeft(int leftIndex) {
    // If already matched, unselect the pair
    if (_pairs.containsKey(leftIndex)) {
      HapticFeedback.lightImpact();
      setState(() {
        _pairs.remove(leftIndex);
        _selectedLeft = null;
        _selectedRight = null;
      });
      widget.onAnswer(Map<int, int>.from(_pairs));
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _selectedLeft = leftIndex;
    });

    if (_selectedRight != null) {
      _tryMatch();
    }
  }

  void _onTapRight(int rightIndex) {
    // If already matched, unselect the pair
    final matchedLeft = _pairs.entries
        .where((e) => e.value == rightIndex)
        .firstOrNull
        ?.key;
    if (matchedLeft != null) {
      HapticFeedback.lightImpact();
      setState(() {
        _pairs.remove(matchedLeft);
        _selectedLeft = null;
        _selectedRight = null;
      });
      widget.onAnswer(Map<int, int>.from(_pairs));
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _selectedRight = rightIndex;
    });

    if (_selectedLeft != null) {
      _tryMatch();
    }
  }

  void _tryMatch() {
    final left = _selectedLeft!;
    final right = _selectedRight!;

    HapticFeedback.mediumImpact();
    setState(() {
      _pairs[left] = right;
      _selectedLeft = null;
      _selectedRight = null;
    });

    widget.onAnswer(Map<int, int>.from(_pairs));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Instruction removed per user request
          /*
          Row(
            children: [
              Icon(
                Icons.touch_app_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 6),
              Text(
                'Tap to match pairs',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          */
          // Two columns
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column
              Expanded(
                child: Column(
                  children: List.generate(
                    widget.content.leftItems.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MatchItem3D(
                        text: widget.content.leftItems[index],
                        isSelected: _selectedLeft == index,
                        matchColor: _getLeftMatchColor(index),
                        onTap: () => _onTapLeft(index),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Right column
              Expanded(
                child: Column(
                  children: List.generate(
                    widget.content.rightItems.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MatchItem3D(
                        text: widget.content.rightItems[index],
                        isSelected: _selectedRight == index,
                        matchColor: _getRightMatchColor(index),
                        onTap: () => _onTapRight(index),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Match counter removed per user request
          /*
          const SizedBox(height: 8),
          Text(
            '${_pairs.length} of ${widget.content.leftItems.length} matched',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
              letterSpacing: 1,
            ),
          ),
          */
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _MatchItem3D extends StatefulWidget {
  const _MatchItem3D({
    required this.text,
    required this.isSelected,
    required this.matchColor,
    required this.onTap,
  });

  final String text;
  final bool isSelected;
  final Color? matchColor;
  final VoidCallback onTap;

  @override
  State<_MatchItem3D> createState() => _MatchItem3DState();
}

class _MatchItem3DState extends State<_MatchItem3D> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    HapticFeedback.lightImpact();
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool isMatched = widget.matchColor != null;
    final bool isActive = widget.isSelected || isMatched;

    // Theme colors
    final primaryColor = widget.matchColor ?? AppColors.primary;

    final Color faceColor = isActive
        ? Color.alphaBlend(primaryColor.withValues(alpha: 0.1), Colors.white)
        : Colors.white;
    final Color sideColor = isActive ? primaryColor : const Color(0xFFE5E7EB);
    final Color borderColor = isActive ? primaryColor : const Color(0xFFE5E7EB);
    final Color textColor = isActive ? primaryColor : const Color(0xFF4B5563);

    const double depth = 4.0;
    final double currentDepth = _isPressed ? 0.0 : depth;
    final double marginTop = _isPressed ? depth : 0.0;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: SizedBox(
        height: 56 + depth, // Intrinsic height might be better but fixed is safer for now
        child: Stack(
          children: [
            // Bottom layer
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              top: depth,
              child: Container(
                decoration: BoxDecoration(
                  color: sideColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            // Top layer
            AnimatedPositioned(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              top: marginTop,
              bottom: currentDepth,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: faceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderColor,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    widget.text,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: textColor,
                      fontFamily: 'Nunito',
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
