import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'vocab_question_container.dart';
import 'vocab_question_image.dart';
import '../../../../domain/entities/vocabulary_session.dart';

/// Word wheel: circular letter layout with drag-to-connect gesture.
/// User drags between letters arranged in a circle to spell the word.
class VocabWordWheelQuestion extends StatefulWidget {
  const VocabWordWheelQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  final SessionQuestion question;
  final void Function(String answer) onAnswer;

  @override
  State<VocabWordWheelQuestion> createState() => _VocabWordWheelQuestionState();
}

class _VocabWordWheelQuestionState extends State<VocabWordWheelQuestion> {
  final List<int> _selectedIndices = [];
  bool _answered = false;
  bool _isDragging = false;
  Offset? _currentDragPosition;

  // Letter positions (computed in layout)
  final Map<int, Offset> _letterCenters = {};

  List<String> get letters => widget.question.scrambledLetters ?? [];
  String get correctWord => widget.question.correctAnswer;

  static const double _circleRadius = 110.0;
  static const double _tileRadius = 28.0;
  static const double _hitRadius = 38.0;

  void _onPanStart(DragStartDetails details) {
    if (_answered) return;
    final hit = _hitTest(details.localPosition);
    if (hit != null) {
      setState(() {
        _isDragging = true;
        _selectedIndices.clear();
        _selectedIndices.add(hit);
        _currentDragPosition = details.localPosition;
      });
      HapticFeedback.selectionClick();
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging || _answered) return;
    setState(() => _currentDragPosition = details.localPosition);

    final hit = _hitTest(details.localPosition);
    if (hit != null && !_selectedIndices.contains(hit)) {
      setState(() => _selectedIndices.add(hit));
      HapticFeedback.selectionClick();
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging || _answered) return;
    setState(() {
      _isDragging = false;
      _currentDragPosition = null;
    });

    // Submit only if all letters connected, otherwise reset
    if (_selectedIndices.length == letters.length) {
      _submit();
    } else {
      setState(() => _selectedIndices.clear());
    }
  }

  int? _hitTest(Offset position) {
    for (final entry in _letterCenters.entries) {
      if (_selectedIndices.contains(entry.key)) continue;
      final distance = (position - entry.value).distance;
      if (distance < _hitRadius) return entry.key;
    }
    return null;
  }

  void _tapLetter(int index) {
    if (_answered) return;

    if (_selectedIndices.contains(index)) {
      // Tap on already selected: remove it and everything after
      final pos = _selectedIndices.indexOf(index);
      setState(() => _selectedIndices.removeRange(pos, _selectedIndices.length));
      HapticFeedback.lightImpact();
      return;
    }

    setState(() => _selectedIndices.add(index));
    HapticFeedback.selectionClick();

    if (_selectedIndices.length == letters.length) {
      _submit();
    }
  }

  void _removeLetter(int slotIndex) {
    if (_answered || slotIndex >= _selectedIndices.length) return;
    setState(
        () => _selectedIndices.removeRange(slotIndex, _selectedIndices.length));
    HapticFeedback.lightImpact();
  }

  void _submit() {
    if (_answered) return;
    setState(() => _answered = true);
    final answer = _selectedIndices.map((i) => letters[i]).join();
    widget.onAnswer(answer);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Connect the letters',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 12),

          VocabQuestionContainer(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              children: [
                // Show image if available, otherwise fall back to TR meaning
                if (widget.question.imageUrl != null) ...[
                  VocabQuestionImage(
                      imageUrl: widget.question.imageUrl, size: 140),
                ] else ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.question.targetMeaning,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.tertiary,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Answer Slots
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 8,
                  children: List.generate(letters.length, (index) {
                    final isFilled = index < _selectedIndices.length;
                    final char =
                        isFilled ? letters[_selectedIndices[index]] : '';

                    return GestureDetector(
                      onTap: isFilled ? () => _removeLetter(index) : null,
                      child: _LetterSlot(
                        char: char,
                        isFilled: isFilled,
                        status: _answered
                            ? (_selectedIndices
                                        .map((i) => letters[i])
                                        .join()
                                        .toLowerCase() ==
                                    correctWord.toLowerCase()
                                ? _SlotStatus.correct
                                : _SlotStatus.incorrect)
                            : _SlotStatus.neutral,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Circular letter wheel with drag
          Center(
            child: SizedBox(
              width: (_circleRadius + _tileRadius) * 2 + 16,
              height: (_circleRadius + _tileRadius) * 2 + 16,
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: CustomPaint(
                  painter: _ConnectionLinePainter(
                    selectedIndices: _selectedIndices,
                    letterCenters: _letterCenters,
                    currentDragPosition:
                        _isDragging ? _currentDragPosition : null,
                    lineColor: theme.colorScheme.primary.withValues(alpha: 0.4),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final center = Offset(
                        constraints.maxWidth / 2,
                        constraints.maxHeight / 2,
                      );

                      _letterCenters.clear();
                      final angleStep = 2 * pi / letters.length;
                      const startAngle = -pi / 2;

                      return Stack(
                        children: [
                          // Background circle
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme
                                    .colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                                border: Border.all(
                                  color: theme.colorScheme.outline
                                      .withValues(alpha: 0.1),
                                ),
                              ),
                            ),
                          ),
                          // Letters
                          ...List.generate(letters.length, (i) {
                            final angle = startAngle + angleStep * i;
                            final pos = Offset(
                              center.dx + _circleRadius * cos(angle),
                              center.dy + _circleRadius * sin(angle),
                            );
                            _letterCenters[i] = pos;

                            final isSelected = _selectedIndices.contains(i);

                            return Positioned(
                              left: pos.dx - _tileRadius,
                              top: pos.dy - _tileRadius,
                              child: _CircleLetterTile(
                                char: letters[i],
                                isSelected: isSelected,
                                onTap: () => _tapLetter(i),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ============================================
// CONNECTION LINE PAINTER
// ============================================

class _ConnectionLinePainter extends CustomPainter {
  _ConnectionLinePainter({
    required this.selectedIndices,
    required this.letterCenters,
    this.currentDragPosition,
    required this.lineColor,
  });

  final List<int> selectedIndices;
  final Map<int, Offset> letterCenters;
  final Offset? currentDragPosition;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (selectedIndices.isEmpty || letterCenters.isEmpty) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final firstCenter = letterCenters[selectedIndices.first];
    if (firstCenter == null) return;
    path.moveTo(firstCenter.dx, firstCenter.dy);

    for (var i = 1; i < selectedIndices.length; i++) {
      final center = letterCenters[selectedIndices[i]];
      if (center != null) {
        path.lineTo(center.dx, center.dy);
      }
    }

    if (currentDragPosition != null) {
      path.lineTo(currentDragPosition!.dx, currentDragPosition!.dy);
    }

    canvas.drawPath(path, paint);

    // Draw dots at each selected letter center
    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    for (final index in selectedIndices) {
      final center = letterCenters[index];
      if (center != null) {
        canvas.drawCircle(center, 5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_ConnectionLinePainter oldDelegate) => true;
}

// ============================================
// WIDGETS
// ============================================

enum _SlotStatus { neutral, correct, incorrect }

class _LetterSlot extends StatelessWidget {
  const _LetterSlot({
    required this.char,
    required this.isFilled,
    required this.status,
  });

  final String char;
  final bool isFilled;
  final _SlotStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color borderColor = theme.colorScheme.outline.withValues(alpha: 0.3);
    Color bgColor =
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    Color textColor = theme.colorScheme.onSurface;

    if (status == _SlotStatus.correct) {
      borderColor = Colors.green;
      bgColor = Colors.green.withValues(alpha: 0.2);
      textColor = Colors.green.shade800;
    } else if (status == _SlotStatus.incorrect) {
      borderColor = Colors.red;
      bgColor = Colors.red.withValues(alpha: 0.2);
      textColor = Colors.red.shade800;
    } else if (isFilled) {
      borderColor = theme.colorScheme.primary;
      bgColor = theme.colorScheme.surface;
      textColor = theme.colorScheme.onSurface;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: isFilled || status != _SlotStatus.neutral ? 2 : 1,
        ),
        boxShadow: isFilled
            ? [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ]
            : [],
      ),
      child: isFilled
          ? Text(
              char.toUpperCase(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack)
          : Container(
              width: 8,
              height: 2,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
    );
  }
}

class _CircleLetterTile extends StatelessWidget {
  const _CircleLetterTile({
    required this.char,
    required this.isSelected,
    required this.onTap,
  });

  final String char;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.3)
                  : theme.colorScheme.shadow.withValues(alpha: 0.1),
              offset: const Offset(0, 3),
              blurRadius: isSelected ? 8 : 4,
            ),
          ],
        ),
        child: Text(
          char.toUpperCase(),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
