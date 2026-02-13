import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../domain/entities/book_quiz.dart';
import '../../../../app/theme.dart';

/// Multiple choice question widget with 4 radio-button style options.
///
/// Options shown as 3D tappable cards.
class BookQuizMultipleChoice extends StatelessWidget {
  const BookQuizMultipleChoice({
    super.key,
    required this.content,
    required this.onAnswer,
    this.selectedAnswer,
  });

  final MultipleChoiceContent content;
  final void Function(String selectedOption) onAnswer;
  final String? selectedAnswer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24), // Parent handles padding
      child: Column(
        children: List.generate(content.options.length, (index) {
          final option = content.options[index];
          final isSelected = selectedAnswer == option;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OptionCard3D(
              label: option,
              index: index,
              isSelected: isSelected,
              onTap: () {
                if (!isSelected) {
                   onAnswer(option);
                }
              },
            ),
          ).animate().fadeIn(
                duration: 300.ms,
                delay: (50 * index).ms,
              ).slideX(
                begin: 0.05,
                end: 0,
                duration: 300.ms,
                delay: (50 * index).ms,
              );
        }),
      ),
    );
  }
}

class _OptionCard3D extends StatefulWidget {
  const _OptionCard3D({
    required this.label,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_OptionCard3D> createState() => _OptionCard3DState();
}

class _OptionCard3DState extends State<_OptionCard3D> {
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

  /// Maps index 0-3 to letters A-D.
  String get _letterPrefix => String.fromCharCode(65 + widget.index);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Colors
    final Color faceColor = widget.isSelected
        ? Color.alphaBlend(AppColors.primary.withValues(alpha: 0.1), Colors.white)
        : Colors.white;
    final Color sideColor = widget.isSelected ? AppColors.primary : const Color(0xFFE5E7EB);
    final Color borderColor = widget.isSelected ? AppColors.primary : const Color(0xFFE5E7EB);
    final Color textColor = widget.isSelected ? AppColors.primary : const Color(0xFF4B5563);

    // 3D Depth
    const double depth = 4.0;
    final double currentDepth = _isPressed ? 0.0 : depth;
    final double marginTop = _isPressed ? depth : 0.0;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: SizedBox(
        height: 64 + depth, // Base height + depth space
        child: Stack(
          children: [
            // Bottom (Side) Layer
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              top: depth,
              child: Container(
                decoration: BoxDecoration(
                  color: sideColor,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            // Top (Face) Layer
            AnimatedPositioned(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              top: marginTop,
              bottom: currentDepth,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: faceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: borderColor,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    // Prefix Circle
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: widget.isSelected ? AppColors.primary : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.isSelected ? AppColors.primary : const Color(0xFFD1D5DB),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _letterPrefix,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: widget.isSelected ? Colors.white : const Color(0xFF9CA3AF),
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Option Text
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w600,
                          color: textColor,
                          fontFamily: 'Nunito',
                        ),
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
