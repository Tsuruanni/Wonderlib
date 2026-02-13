import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'vocab_question_container.dart';
import 'vocab_question_image.dart';
import '../../../../domain/entities/vocabulary_session.dart';

/// Spelling question: Turkish meaning given, type the English word
class VocabSpellingQuestion extends StatefulWidget {
  const VocabSpellingQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  final SessionQuestion question;
  final void Function(String answer) onAnswer;

  @override
  State<VocabSpellingQuestion> createState() => _VocabSpellingQuestionState();
}

class _VocabSpellingQuestionState extends State<VocabSpellingQuestion> {
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Type the English word',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 12),

          VocabQuestionContainer(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
            child: Column(
              children: [
                VocabQuestionImage(imageUrl: widget.question.imageUrl),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    widget.question.targetMeaning,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Text input
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: !_answered,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2
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

          const SizedBox(height: 20),

          // Submit button
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
