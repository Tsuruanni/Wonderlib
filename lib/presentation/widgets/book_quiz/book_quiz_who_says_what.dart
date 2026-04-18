import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../domain/entities/book_quiz.dart';
import '../../../app/text_styles.dart';
import '../../../../app/theme.dart';
import 'book_quiz_matching.dart' show kQuizPairColors;

/// Character-to-quote matching widget themed for "Who Says What?" questions.
///
/// Characters on the left with person icon, quotes on the right with quote icon.
/// Same tap-to-match mechanic as [BookQuizMatching].
class BookQuizWhoSaysWhat extends StatefulWidget {
  const BookQuizWhoSaysWhat({
    super.key,
    required this.content,
    required this.onAnswer,
    this.currentPairs,
  });

  final WhoSaysWhatContent content;
  final void Function(Map<int, int> pairs) onAnswer;
  final Map<int, int>? currentPairs;

  @override
  State<BookQuizWhoSaysWhat> createState() => _BookQuizWhoSaysWhatState();
}

class _BookQuizWhoSaysWhatState extends State<BookQuizWhoSaysWhat> {
  /// Matched pairs: character index -> quote index.
  late Map<int, int> _pairs;

  /// Currently selected character index.
  int? _selectedCharacter;

  /// Currently selected quote index.
  int? _selectedQuote;

  @override
  void initState() {
    super.initState();
    _pairs = widget.currentPairs != null
        ? Map<int, int>.from(widget.currentPairs!)
        : {};
  }

  @override
  void didUpdateWidget(BookQuizWhoSaysWhat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPairs != oldWidget.currentPairs &&
        widget.currentPairs != null) {
      _pairs = Map<int, int>.from(widget.currentPairs!);
    }
  }

  Color _getMatchColor(int pairIndex) {
    return kQuizPairColors[pairIndex % kQuizPairColors.length];
  }

  Color? _getCharacterMatchColor(int charIndex) {
    if (!_pairs.containsKey(charIndex)) return null;
    final pairOrder = _pairs.keys.toList().indexOf(charIndex);
    return _getMatchColor(pairOrder);
  }

  Color? _getQuoteMatchColor(int quoteIndex) {
    final entry = _pairs.entries
        .where((e) => e.value == quoteIndex)
        .firstOrNull;
    if (entry == null) return null;
    final pairOrder = _pairs.keys.toList().indexOf(entry.key);
    return _getMatchColor(pairOrder);
  }

  void _onTapCharacter(int charIndex) {
    // Unmatch if already matched
    if (_pairs.containsKey(charIndex)) {
      HapticFeedback.lightImpact();
      setState(() {
        _pairs.remove(charIndex);
        _selectedCharacter = null;
        _selectedQuote = null;
      });
      widget.onAnswer(Map<int, int>.from(_pairs));
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _selectedCharacter = charIndex;
    });

    if (_selectedQuote != null) {
      _tryMatch();
    }
  }

  void _onTapQuote(int quoteIndex) {
    // Unmatch if already matched
    final matchedChar = _pairs.entries
        .where((e) => e.value == quoteIndex)
        .firstOrNull
        ?.key;
    if (matchedChar != null) {
      HapticFeedback.lightImpact();
      setState(() {
        _pairs.remove(matchedChar);
        _selectedCharacter = null;
        _selectedQuote = null;
      });
      widget.onAnswer(Map<int, int>.from(_pairs));
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _selectedQuote = quoteIndex;
    });

    if (_selectedCharacter != null) {
      _tryMatch();
    }
  }

  void _tryMatch() {
    final charIndex = _selectedCharacter!;
    final quoteIndex = _selectedQuote!;

    HapticFeedback.mediumImpact();
    setState(() {
      _pairs[charIndex] = quoteIndex;
      _selectedCharacter = null;
      _selectedQuote = null;
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
                Icons.record_voice_over_outlined,
                size: 18,
                color: colorScheme.outline,
              ),
              const SizedBox(width: 6),
              Text(
                'Match matching pairs',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.outline,
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
              // Characters column
              Expanded(
                child: Column(
                  children: List.generate(
                    widget.content.characters.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CharacterCard3D(
                        name: widget.content.characters[index],
                        isSelected: _selectedCharacter == index,
                        matchColor: _getCharacterMatchColor(index),
                        onTap: () => _onTapCharacter(index),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Quotes column
              Expanded(
                child: Column(
                  children: List.generate(
                    widget.content.quotes.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _QuoteCard3D(
                        quote: widget.content.quotes[index],
                        isSelected: _selectedQuote == index,
                        matchColor: _getQuoteMatchColor(index),
                        onTap: () => _onTapQuote(index),
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
            '${_pairs.length} of ${widget.content.characters.length} matched',
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

class _CharacterCard3D extends StatefulWidget {
  const _CharacterCard3D({
    required this.name,
    required this.isSelected,
    required this.matchColor,
    required this.onTap,
  });

  final String name;
  final bool isSelected;
  final Color? matchColor;
  final VoidCallback onTap;

  @override
  State<_CharacterCard3D> createState() => _CharacterCard3DState();
}

class _CharacterCard3DState extends State<_CharacterCard3D> {
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

    // Colors
    final primaryColor = widget.matchColor ?? AppColors.primary;

    final Color faceColor = isActive
        ? Color.alphaBlend(primaryColor.withValues(alpha: 0.1), Colors.white)
        : Colors.white;
    final Color sideColor = isActive ? primaryColor : AppColors.gray200;
    final Color borderColor = isActive ? primaryColor : AppColors.gray200;
    final Color textColor = isActive ? primaryColor : AppColors.gray600;

    const double depth = 4.0;
    final double currentDepth = _isPressed ? 0.0 : depth;
    final double marginTop = _isPressed ? depth : 0.0;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: SizedBox(
        height: 60 + depth,
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
                child: Row(
                  children: [
                    Icon(
                        Icons.person_rounded,
                        size: 18,
                        color: widget.isSelected ? primaryColor : AppColors.gray400,
                    ),
                    const SizedBox(width: 8),
                     Expanded(
                      child: Text(
                        widget.name,
                        style: AppTextStyles.bodySmall(color: textColor).copyWith(fontWeight: FontWeight.w700, height: 1.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteCard3D extends StatefulWidget {
  const _QuoteCard3D({
    required this.quote,
    required this.isSelected,
    required this.matchColor,
    required this.onTap,
  });

  final String quote;
  final bool isSelected;
  final Color? matchColor;
  final VoidCallback onTap;

  @override
  State<_QuoteCard3D> createState() => _QuoteCard3DState();
}

class _QuoteCard3DState extends State<_QuoteCard3D> {
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

    // Colors
    final primaryColor = widget.matchColor ?? AppColors.primary;

    final Color faceColor = isActive
        ? Color.alphaBlend(primaryColor.withValues(alpha: 0.1), Colors.white)
        : Colors.white;
    final Color sideColor = isActive ? primaryColor : AppColors.gray200;
    final Color borderColor = isActive ? primaryColor : AppColors.gray200;
    final Color textColor = isActive ? primaryColor : AppColors.gray600;

    const double depth = 4.0;
    final double currentDepth = _isPressed ? 0.0 : depth;
    final double marginTop = _isPressed ? depth : 0.0;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: SizedBox(
        height: 80 + depth, // Allow more space for quotes
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
                child: Row(
                  children: [
                    Icon(
                        Icons.format_quote_rounded,
                        size: 18,
                        color: widget.isSelected ? primaryColor : AppColors.gray400,
                    ),
                    const SizedBox(width: 8),
                     Expanded(
                      child: Text(
                        '"${widget.quote}"',
                        style: AppTextStyles.caption(color: textColor).copyWith(fontStyle: FontStyle.italic, height: 1.3),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
