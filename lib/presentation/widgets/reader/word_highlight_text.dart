import 'package:flutter/material.dart';

import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/content/content_block.dart';
import '../../providers/reader_provider.dart';

/// Text widget with word-level audio highlighting (karaoke-style).
/// Highlights the currently playing word in yellow.
/// Vocabulary words are underlined and tappable for definitions.
class WordHighlightText extends StatelessWidget {
  const WordHighlightText({
    super.key,
    required this.text,
    required this.wordTimings,
    required this.settings,
    this.activeWordIndex,
    this.vocabulary = const [],
    this.onVocabularyTap,
  });

  final String text;
  final List<WordTiming> wordTimings;
  final ReaderSettings settings;
  final int? activeWordIndex;
  final List<ChapterVocabulary> vocabulary;
  final void Function(ChapterVocabulary vocab, Offset position)? onVocabularyTap;

  @override
  Widget build(BuildContext context) {
    if (wordTimings.isEmpty) {
      // Fallback: no timings, render plain text
      return SelectableText(
        text,
        style: _baseTextStyle,
      );
    }

    return RichText(
      text: TextSpan(
        style: _baseTextStyle,
        children: _buildWordSpans(context),
      ),
    );
  }

  TextStyle get _baseTextStyle => TextStyle(
        fontSize: settings.fontSize,
        height: settings.lineHeight,
        color: settings.theme.text,
      );

  List<InlineSpan> _buildWordSpans(BuildContext context) {
    final spans = <InlineSpan>[];
    final vocabMap = _buildVocabMap();
    int currentIndex = 0;

    for (int i = 0; i < wordTimings.length; i++) {
      final timing = wordTimings[i];

      // Add text before this word (spaces, punctuation)
      if (timing.startIndex > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, timing.startIndex),
          ),
        );
      }

      // Build the word span
      final isActive = i == activeWordIndex;
      final vocabMatch = vocabMap[timing.word.toLowerCase()];

      if (vocabMatch != null && onVocabularyTap != null) {
        // Vocabulary word - tappable with potential audio highlight
        spans.add(
          _buildVocabularyWordSpan(
            context,
            timing.word,
            vocabMatch,
            isActive,
          ),
        );
      } else {
        // Regular word - just audio highlight
        spans.add(_buildRegularWordSpan(timing.word, isActive));
      }

      currentIndex = timing.endIndex;
    }

    // Add remaining text after last word
    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex)));
    }

    return spans;
  }

  Map<String, ChapterVocabulary> _buildVocabMap() {
    final map = <String, ChapterVocabulary>{};
    for (final vocab in vocabulary) {
      map[vocab.word.toLowerCase()] = vocab;
    }
    return map;
  }

  TextSpan _buildRegularWordSpan(String word, bool isActive) {
    return TextSpan(
      text: word,
      style: isActive ? _highlightStyle : null,
    );
  }

  WidgetSpan _buildVocabularyWordSpan(
    BuildContext context,
    String word,
    ChapterVocabulary vocab,
    bool isActive,
  ) {
    final vocabHighlightColor = settings.theme == ReaderTheme.dark
        ? const Color(0xFF4F46E5).withValues(alpha: 0.3)
        : const Color(0xFF4F46E5).withValues(alpha: 0.15);

    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: GestureDetector(
        onTapUp: (details) {
          onVocabularyTap?.call(vocab, details.globalPosition);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            // Combine audio highlight (yellow) with vocab highlight (purple)
            color: isActive
                ? Colors.yellow.withValues(alpha: 0.5)
                : vocabHighlightColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            word,
            style: TextStyle(
              fontSize: settings.fontSize,
              height: settings.lineHeight,
              color: settings.theme.text,
              fontWeight: isActive ? FontWeight.bold : null,
              decoration: TextDecoration.underline,
              decorationColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
              decorationStyle: TextDecorationStyle.dotted,
            ),
          ),
        ),
      ),
    );
  }

  TextStyle get _highlightStyle => TextStyle(
        fontSize: settings.fontSize,
        height: settings.lineHeight,
        color: settings.theme.text,
        backgroundColor: Colors.yellow.withValues(alpha: 0.5),
        fontWeight: FontWeight.bold,
      );
}
