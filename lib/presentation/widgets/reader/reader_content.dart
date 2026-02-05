import 'package:flutter/material.dart';

import '../../../domain/entities/chapter.dart';
import '../../providers/reader_provider.dart';

/// Renders chapter content with vocabulary highlighting
/// Vocabulary words are tappable and highlighted with a background color
class ReaderContent extends StatelessWidget {
  const ReaderContent({
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

    return SelectableText.rich(
      TextSpan(children: spans),
      style: TextStyle(
        fontSize: settings.fontSize,
        height: settings.lineHeight,
        color: settings.theme.text,
      ),
    );
  }

  List<InlineSpan> _buildContentSpans(BuildContext context) {
    if (!settings.showVocabularyHighlights || vocabulary.isEmpty) {
      return [TextSpan(text: content)];
    }

    // Filter vocabulary that has valid position markers
    final positionedVocab = vocabulary
        .where((v) => v.startIndex != null && v.endIndex != null)
        .toList()
      ..sort((a, b) => a.startIndex!.compareTo(b.startIndex!));

    if (positionedVocab.isEmpty) {
      // No positioned vocabulary, try to find words by matching
      return _buildSpansWithWordMatching(context);
    }

    return _buildSpansWithPositions(context, positionedVocab);
  }

  List<InlineSpan> _buildSpansWithPositions(
    BuildContext context,
    List<ChapterVocabulary> positionedVocab,
  ) {
    final spans = <InlineSpan>[];
    var currentIndex = 0;

    for (final vocab in positionedVocab) {
      final start = vocab.startIndex!;
      final end = vocab.endIndex!;

      // Validate indices
      if (start < currentIndex || end > content.length || start >= end) {
        continue;
      }

      // Add text before vocabulary word
      if (start > currentIndex) {
        spans.add(TextSpan(text: content.substring(currentIndex, start)));
      }

      // Add vocabulary word with highlighting
      spans.add(_buildVocabularySpan(
        context,
        vocab,
        content.substring(start, end),
      ),);

      currentIndex = end;
    }

    // Add remaining text
    if (currentIndex < content.length) {
      spans.add(TextSpan(text: content.substring(currentIndex)));
    }

    return spans;
  }

  List<InlineSpan> _buildSpansWithWordMatching(BuildContext context) {
    // Create a map of words to their vocabulary entries
    final vocabMap = <String, ChapterVocabulary>{};
    for (final vocab in vocabulary) {
      vocabMap[vocab.word.toLowerCase()] = vocab;
    }

    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\b(' + vocabulary.map((v) => RegExp.escape(v.word)).join('|') + r')\b', caseSensitive: false);

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
