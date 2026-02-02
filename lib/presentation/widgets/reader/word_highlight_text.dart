import 'package:flutter/material.dart';

import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/content/content_block.dart';
import '../../providers/reader_provider.dart';

/// Text widget with word-level audio highlighting (karaoke-style).
/// Highlights the currently playing word in yellow.
/// Vocabulary words are underlined and tappable for definitions.
/// Auto-scrolls to keep the active word visible during playback.
class WordHighlightText extends StatefulWidget {
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
  State<WordHighlightText> createState() => _WordHighlightTextState();
}

class _WordHighlightTextState extends State<WordHighlightText> {
  final Map<int, GlobalKey> _wordKeys = {};
  int? _previousActiveIndex;

  @override
  void didUpdateWidget(covariant WordHighlightText oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-scroll when active word changes
    if (widget.activeWordIndex != _previousActiveIndex &&
        widget.activeWordIndex != null) {
      _previousActiveIndex = widget.activeWordIndex;
      _scrollToActiveWord();
    }
  }

  void _scrollToActiveWord() {
    final key = _wordKeys[widget.activeWordIndex];
    final context = key?.currentContext;
    if (context == null) return;

    // Use a slight delay to ensure the widget is laid out
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentContext = key?.currentContext;
      if (!mounted || currentContext == null) return;

      Scrollable.ensureVisible(
        currentContext,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: 0.4, // Keep active word slightly above center
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.wordTimings.isEmpty) {
      // Fallback: no timings, render plain text
      return SelectableText(
        widget.text,
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
        fontSize: widget.settings.fontSize,
        height: widget.settings.lineHeight,
        color: widget.settings.theme.text,
      );

  List<InlineSpan> _buildWordSpans(BuildContext context) {
    final spans = <InlineSpan>[];
    final vocabMap = _buildVocabMap();
    int currentIndex = 0;

    for (int i = 0; i < widget.wordTimings.length; i++) {
      final timing = widget.wordTimings[i];

      // Add text before this word (spaces, punctuation)
      if (timing.startIndex > currentIndex) {
        spans.add(
          TextSpan(
            text: widget.text.substring(currentIndex, timing.startIndex),
          ),
        );
      }

      // Build the word span
      final isActive = i == widget.activeWordIndex;
      final vocabMatch = vocabMap[timing.word.toLowerCase()];

      // Generate GlobalKey for this word (for auto-scroll)
      _wordKeys.putIfAbsent(i, () => GlobalKey());

      if (vocabMatch != null && widget.onVocabularyTap != null) {
        // Vocabulary word - tappable with potential audio highlight
        spans.add(
          _buildVocabularyWordSpan(
            context,
            i,
            timing.word,
            vocabMatch,
            isActive,
          ),
        );
      } else {
        // Regular word - use WidgetSpan for scroll support
        spans.add(_buildRegularWordSpan(i, timing.word, isActive));
      }

      currentIndex = timing.endIndex;
    }

    // Add remaining text after last word
    if (currentIndex < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(currentIndex)));
    }

    return spans;
  }

  Map<String, ChapterVocabulary> _buildVocabMap() {
    final map = <String, ChapterVocabulary>{};
    for (final vocab in widget.vocabulary) {
      map[vocab.word.toLowerCase()] = vocab;
    }
    return map;
  }

  WidgetSpan _buildRegularWordSpan(int index, String word, bool isActive) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Container(
        key: _wordKeys[index],
        decoration: isActive
            ? BoxDecoration(
                color: Colors.yellow.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              )
            : null,
        child: Text(
          word,
          style: TextStyle(
            fontSize: widget.settings.fontSize,
            height: widget.settings.lineHeight,
            color: widget.settings.theme.text,
            fontWeight: isActive ? FontWeight.bold : null,
          ),
        ),
      ),
    );
  }

  WidgetSpan _buildVocabularyWordSpan(
    BuildContext context,
    int index,
    String word,
    ChapterVocabulary vocab,
    bool isActive,
  ) {
    final vocabHighlightColor = widget.settings.theme == ReaderTheme.dark
        ? const Color(0xFF4F46E5).withValues(alpha: 0.3)
        : const Color(0xFF4F46E5).withValues(alpha: 0.15);

    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: GestureDetector(
        key: _wordKeys[index],
        onTapUp: (details) {
          widget.onVocabularyTap?.call(vocab, details.globalPosition);
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
              fontSize: widget.settings.fontSize,
              height: widget.settings.lineHeight,
              color: widget.settings.theme.text,
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
}
