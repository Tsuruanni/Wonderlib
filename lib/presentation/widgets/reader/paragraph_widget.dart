import 'package:flutter/material.dart';

import '../../../domain/entities/chapter.dart';
import '../../providers/reader_provider.dart';

/// Renders a single paragraph with vocabulary highlighting
class ParagraphWidget extends StatelessWidget {
  const ParagraphWidget({
    super.key,
    required this.content,
    required this.vocabulary,
    required this.settings,
    required this.onVocabularyTap,
  });

  final String content;
  final List<ChapterVocabulary> vocabulary;
  final ReaderSettings settings;
  final void Function(ChapterVocabulary vocab, Offset position) onVocabularyTap;

  @override
  Widget build(BuildContext context) {
    final spans = _buildContentSpans(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SelectableText.rich(
        TextSpan(children: spans),
        style: TextStyle(
          fontSize: settings.fontSize,
          height: settings.lineHeight,
          color: settings.theme.text,
        ),
      ),
    );
  }

  List<InlineSpan> _buildContentSpans(BuildContext context) {
    if (!settings.showVocabularyHighlights || vocabulary.isEmpty) {
      return [TextSpan(text: content)];
    }

    // Create a map of words to their vocabulary entries
    final vocabMap = <String, ChapterVocabulary>{};
    for (final vocab in vocabulary) {
      vocabMap[vocab.word.toLowerCase()] = vocab;
    }

    final spans = <InlineSpan>[];
    final pattern = RegExp(
      r'\b(' + vocabulary.map((v) => RegExp.escape(v.word)).join('|') + r')\b',
      caseSensitive: false,
    );

    var lastEnd = 0;
    for (final match in pattern.allMatches(content)) {
      // Add text before match
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }

      // Find vocabulary entry
      final matchedWord = match.group(0)!;
      final vocab = vocabMap[matchedWord.toLowerCase()];

      if (vocab != null) {
        spans.add(_buildVocabularySpan(context, vocab, matchedWord));
      } else {
        spans.add(TextSpan(text: matchedWord));
      }

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }

    return spans.isEmpty ? [TextSpan(text: content)] : spans;
  }

  WidgetSpan _buildVocabularySpan(
    BuildContext context,
    ChapterVocabulary vocab,
    String displayText,
  ) {
    final highlightColor = settings.theme == ReaderTheme.dark
        ? const Color(0xFF4F46E5).withValues(alpha: 0.3)
        : const Color(0xFF4F46E5).withValues(alpha: 0.15);

    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: GestureDetector(
        onTapUp: (details) {
          onVocabularyTap(vocab, details.globalPosition);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: highlightColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            displayText,
            style: TextStyle(
              fontSize: settings.fontSize,
              height: settings.lineHeight,
              color: settings.theme.text,
              decoration: TextDecoration.underline,
              decorationColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
              decorationStyle: TextDecorationStyle.dotted,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Translate all" button for paragraph translation
class TranslateButton extends StatelessWidget {
  const TranslateButton({
    super.key,
    required this.onPressed,
    required this.settings,
  });

  final VoidCallback onPressed;
  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFE53E3E),
          side: const BorderSide(color: Color(0xFFE53E3E)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: const Text(
          'Translate all',
          style: TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}
