import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'vocab_question_container.dart';
import 'vocab_question_image.dart';
import '../../../../domain/entities/vocabulary_session.dart';

/// Sentence gap-fill: "I bought a red ___ from the market" -> type the missing word
class VocabSentenceGapQuestion extends StatefulWidget {
  const VocabSentenceGapQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  final SessionQuestion question;
  final void Function(String answer) onAnswer;

  @override
  State<VocabSentenceGapQuestion> createState() => _VocabSentenceGapQuestionState();
}

class _VocabSentenceGapQuestionState extends State<VocabSentenceGapQuestion> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (_answered || _controller.text.trim().isEmpty) return;
    setState(() => _answered = true);
    HapticFeedback.lightImpact();
    widget.onAnswer(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sentence = widget.question.sentence ?? '___';
    final parts = sentence.split('___');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Fill in the blank',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 12),

          VocabQuestionContainer(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                VocabQuestionImage(imageUrl: widget.question.imageUrl),
                const SizedBox(height: 12),
                Text(
                  widget.question.targetMeaning,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Sentence Display
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: theme.textTheme.headlineSmall?.copyWith(
                      height: 1.5,
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      if (parts.isNotEmpty) TextSpan(text: parts[0]),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 80),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: theme.colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            _controller.text.isEmpty ? '     ' : _controller.text,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      if (parts.length > 1) TextSpan(text: parts[1]),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Input Area
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: !_answered,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: 'Type answer...',
              hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            ),
            onSubmitted: (_) => _submit(),
          ),

          const SizedBox(height: 16),

          if (!_answered)
            FilledButton(
              onPressed: _controller.text.trim().isNotEmpty ? _submit : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Check Answer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
