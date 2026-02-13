import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../domain/entities/book_quiz.dart';
import '../../../../app/theme.dart';

/// Fill-in-the-blank question widget.
///
/// Shows sentence with blank (___) visually highlighted,
/// and a TextField below for the user's answer.
class BookQuizFillBlank extends StatefulWidget {
  const BookQuizFillBlank({
    super.key,
    required this.content,
    required this.onAnswer,
    this.currentAnswer,
  });

  final FillBlankContent content;
  final void Function(String text) onAnswer;
  final String? currentAnswer;

  @override
  State<BookQuizFillBlank> createState() => _BookQuizFillBlankState();
}

class _BookQuizFillBlankState extends State<BookQuizFillBlank> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentAnswer ?? '');
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(BookQuizFillBlank oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync controller if currentAnswer changed externally (e.g., navigating back)
    if (widget.currentAnswer != oldWidget.currentAnswer &&
        widget.currentAnswer != _controller.text) {
      _controller.text = widget.currentAnswer ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sentence with highlighted blank
          _buildSentenceWithBlank(context),
          const SizedBox(height: 24),
          // Answer text field
          _buildAnswerField(context),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildSentenceWithBlank(BuildContext context) {
    final sentence = widget.content.sentence;
    const blankPlaceholder = '___';

    // Split around the blank placeholder
    final parts = sentence.split(blankPlaceholder);

    // 3D Container look
    const double depth = 4;

    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
            // Bottom Layer
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              top: depth,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            // Top Layer
            Container(
              margin: const EdgeInsets.only(bottom: depth),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 2,
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                    style: const TextStyle(
                        height: 1.6,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B5563),
                        fontFamily: 'Nunito',
                    ),
                    children: _buildTextSpans(parts),
                    ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<InlineSpan> _buildTextSpans(List<String> parts) {
    final spans = <InlineSpan>[];

    // Find the blank index (it's between parts)
    // If parts = ["The quick ", " fox"], blank is at index 1 of resulting span list roughly.

    for (var i = 0; i < parts.length; i++) {
        // Add text part
        if (parts[i].isNotEmpty) {
            spans.add(TextSpan(text: parts[i]));
        }

        // Add blank indicator between parts (not after last)
        if (i < parts.length - 1) {
            final hasAnswer = _controller.text.isNotEmpty;

            // Inline widget for the blank
            spans.add(
            WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Container(
                constraints: const BoxConstraints(minWidth: 100),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: hasAnswer
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                        bottom: BorderSide(
                            color: hasAnswer
                                ? AppColors.primary
                                : const Color(0xFFD1D5DB),
                            width: 3,
                        ),
                    ),
                ),
                child: Text(
                    hasAnswer ? _controller.text : '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: hasAnswer ? AppColors.primary : Colors.transparent,
                        fontFamily: 'Nunito',
                    ),
                ),
                ),
            ),
            );
        }
    }

    return spans;
  }

  Widget _buildAnswerField(BuildContext context) {
    const double depth = 4;
    final bool isFocused = _focusNode.hasFocus;

    return SizedBox(
        height: 64 + depth,
        child: Stack(
            children: [
                // Bottom Layer
                Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    top: depth,
                    child: Container(
                        decoration: BoxDecoration(
                            color: isFocused ? AppColors.primary : const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(16),
                        ),
                    ),
                ),
                // Top Layer
                AnimatedPositioned(
                    duration: const Duration(milliseconds: 100),
                    top: isFocused ? depth : 0,
                    bottom: isFocused ? 0 : depth,
                    left: 0,
                    right: 0,
                    child: Container(
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: isFocused ? AppColors.primary : const Color(0xFFE5E7EB),
                                width: 2,
                            ),
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            textCapitalization: TextCapitalization.sentences,
                            autocorrect: false,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Nunito',
                                color: Color(0xFF374151),
                            ),
                            decoration: InputDecoration(
                                hintText: 'Type your answer here...',
                                hintStyle: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontWeight: FontWeight.w600,
                                ),
                                border: InputBorder.none,
                                icon: Icon(
                                    Icons.edit_rounded,
                                    color: isFocused ? AppColors.primary : const Color(0xFF9CA3AF),
                                ),
                                suffixIcon: _controller.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                            Icons.clear_rounded,
                                            color: Color(0xFF9CA3AF),
                                        ),
                                        onPressed: () {
                                            _controller.clear();
                                            widget.onAnswer('');
                                            setState(() {});
                                        },
                                    )
                                    : null,
                            ),
                            onChanged: (value) {
                                widget.onAnswer(value.trim());
                                setState(() {}); // Rebuild to update blank display
                            },
                            onSubmitted: (value) {
                                widget.onAnswer(value.trim());
                            },
                        ),
                    ),
                ),
            ],
        ),
    );
  }
}
