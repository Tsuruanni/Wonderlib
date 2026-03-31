import 'package:flutter/material.dart';

import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/content/content_block.dart';
import '../../providers/reader_provider.dart';

/// Text widget with word-level audio highlighting (karaoke-style).
/// Highlights the currently playing word in yellow.
/// Vocabulary words are underlined and tappable for definitions.
/// Auto-scrolls to keep the active word visible during playback.
class ReaderWordHighlight extends StatefulWidget {
  const ReaderWordHighlight({
    super.key,
    required this.text,
    required this.wordTimings,
    required this.settings,
    this.activeWordIndex,
    this.vocabulary = const [],
    this.onVocabularyTap,
    this.onWordTap,
    this.isFollowingScroll = false,
    this.prefixWidgets = const [],
  });

  final String text;
  final List<WordTiming> wordTimings;
  final ReaderSettings settings;
  final int? activeWordIndex;
  final List<ChapterVocabulary> vocabulary;
  final void Function(ChapterVocabulary vocab, Offset position)? onVocabularyTap;

  /// Callback when any word (not just vocabulary) is tapped.
  /// Used for word-tap popup feature (shows definition and TTS pronunciation).
  final void Function(String word, Offset position)? onWordTap;

  /// Whether to auto-scroll to the active word.
  /// Enabled when user presses play, disabled on activity completion.
  final bool isFollowingScroll;

  /// Widgets to show inline at the start of the text (e.g., play button, drop cap)
  final List<Widget> prefixWidgets;

  @override
  State<ReaderWordHighlight> createState() => _ReaderWordHighlightState();
}

class _ReaderWordHighlightState extends State<ReaderWordHighlight> {
  final Map<int, GlobalKey> _wordKeys = {};
  int? _previousActiveIndex;

  @override
  void didUpdateWidget(covariant ReaderWordHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-scroll when active word changes (only if follow mode is enabled)
    if (widget.isFollowingScroll &&
        widget.activeWordIndex != _previousActiveIndex &&
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
    // Build prefix widget spans
    final prefixSpans = _buildPrefixSpans();

    if (widget.wordTimings.isEmpty) {
      // No word timings - check if we need tappable words
      if (widget.onWordTap != null) {
        // Make words tappable even without audio sync
        return RichText(
          text: TextSpan(
            style: _baseTextStyle,
            children: [...prefixSpans, ..._buildSimpleWordSpans()],
          ),
        );
      }
      // Fallback: no timings and no tap handler, render plain text with prefix
      if (prefixSpans.isNotEmpty) {
        return RichText(
          text: TextSpan(
            style: _baseTextStyle,
            children: [...prefixSpans, TextSpan(text: widget.text)],
          ),
        );
      }
      return SelectableText(
        widget.text,
        style: _baseTextStyle,
      );
    }

    return RichText(
      text: TextSpan(
        style: _baseTextStyle,
        children: [...prefixSpans, ..._buildWordSpans(context)],
      ),
    );
  }

  /// Build WidgetSpans for prefix widgets (play button, drop cap, etc.)
  List<InlineSpan> _buildPrefixSpans() {
    final spans = <InlineSpan>[];
    for (final prefixWidget in widget.prefixWidgets) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: prefixWidget,
          ),
        ),
      );
    }
    return spans;
  }

  /// Build tappable word spans when no word timings available.
  /// Splits text by whitespace and makes each word tappable.
  List<InlineSpan> _buildSimpleWordSpans() {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\S+)(\s*)');
    final matches = pattern.allMatches(widget.text);

    for (final match in matches) {
      final word = match.group(1) ?? '';
      final space = match.group(2) ?? '';

      if (word.isNotEmpty) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTapUp: (details) {
                widget.onWordTap?.call(word, details.globalPosition);
              },
              child: Text(
                word,
                style: _baseTextStyle,
              ),
            ),
          ),
        );
      }

      if (space.isNotEmpty) {
        spans.add(TextSpan(text: space));
      }
    }

    return spans;
  }

  TextStyle get _baseTextStyle => widget.settings.font.textStyle(
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

      // Find the word in text starting from currentIndex
      // This makes rendering robust to index errors in word_timings data
      final wordStart = widget.text.indexOf(timing.word, currentIndex);
      if (wordStart == -1) {
        // Word not found at expected position, skip this timing
        continue;
      }

      // Add text before this word (spaces, punctuation)
      if (wordStart > currentIndex) {
        spans.add(
          TextSpan(
            text: widget.text.substring(currentIndex, wordStart),
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

      // Use actual word position instead of potentially incorrect endIndex
      currentIndex = wordStart + timing.word.length;
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
    final container = Container(
      key: _wordKeys[index],
      decoration: isActive
          ? BoxDecoration(
              color: Colors.yellow.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            )
          : null,
      child: Text(
        word,
        style: widget.settings.font.textStyle(
          fontSize: widget.settings.fontSize,
          height: widget.settings.lineHeight,
          color: widget.settings.theme.text,
          fontWeight: null,
        ),
      ),
    );

    // Wrap in GestureDetector if onWordTap is provided
    if (widget.onWordTap != null) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTapUp: (details) {
            widget.onWordTap?.call(word, details.globalPosition);
          },
          child: container,
        ),
      );
    }

    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: container,
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
          // Prefer onWordTap for new word-tap popup, fallback to onVocabularyTap
          if (widget.onWordTap != null) {
            widget.onWordTap?.call(word, details.globalPosition);
          } else {
            widget.onVocabularyTap?.call(vocab, details.globalPosition);
          }
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
            style: widget.settings.font.textStyle(
              fontSize: widget.settings.fontSize,
              height: widget.settings.lineHeight,
              color: widget.settings.theme.text,
              fontWeight: null,
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
