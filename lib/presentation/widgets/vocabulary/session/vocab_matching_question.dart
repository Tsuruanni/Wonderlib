import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'vocab_question_container.dart';
import '../../../../domain/entities/vocabulary_session.dart';

/// Matching question: tap to match 4 words with 4 meanings
class VocabMatchingQuestion extends StatefulWidget {
  const VocabMatchingQuestion({
    super.key,
    required this.question,
    required this.onComplete,
  });

  final SessionQuestion question;
  final void Function({
    required int correctMatches,
    required int totalMatches,
    required List<String> correctWordIds,
    required List<String> incorrectWordIds,
  }) onComplete;

  @override
  State<VocabMatchingQuestion> createState() => _VocabMatchingQuestionState();
}

class _VocabMatchingQuestionState extends State<VocabMatchingQuestion> {
  late List<SessionMatchingPair> _pairs;
  late List<String> _shuffledWords;
  late List<String> _shuffledMeanings;

  String? _selectedWord;
  String? _selectedMeaning;
  final Map<String, String> _matched = {}; // word -> meaning
  final Set<String> _correctWords = {};
  final Set<String> _incorrectWordIds = {};

  // Transient error state
  String? _errorWord;
  String? _errorMeaning;

  bool _completed = false;
  late Stopwatch _stopwatch;
  Timer? _completionTimer;

  @override
  void initState() {
    super.initState();
    _pairs = widget.question.matchingPairs ?? [];
    _shuffledWords = _pairs.map((p) => p.word).toList()..shuffle();
    _shuffledMeanings = _pairs.map((p) => p.meaning).toList()..shuffle();
    _stopwatch = Stopwatch()..start();
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    super.dispose();
  }

  void _tapWord(String word) {
    if (_completed || _matched.containsKey(word)) return;
    // Clear error state on new tap
    if (_errorWord != null) {
      setState(() {
        _errorWord = null;
        _errorMeaning = null;
      });
    }

    setState(() {
      if (_selectedWord == word) {
        _selectedWord = null;
      } else {
        _selectedWord = word;
        if (_selectedMeaning != null) {
          _tryMatch();
        }
      }
    });
  }

  void _tapMeaning(String meaning) {
    if (_completed || _matched.containsValue(meaning)) return;
     // Clear error state on new tap
    if (_errorMeaning != null) {
      setState(() {
        _errorWord = null;
        _errorMeaning = null;
      });
    }

    setState(() {
      if (_selectedMeaning == meaning) {
        _selectedMeaning = null;
      } else {
        _selectedMeaning = meaning;
        if (_selectedWord != null) {
          _tryMatch();
        }
      }
    });
  }

  void _tryMatch() {
    if (_selectedWord == null || _selectedMeaning == null) return;

    final word = _selectedWord!;
    final meaning = _selectedMeaning!;

    // Check if this is a correct match
    final pairIndex = _pairs.indexWhere((p) => p.word == word);
    if (pairIndex == -1) return; // Safety: should never happen
    final pair = _pairs[pairIndex];
    final isCorrect = pair.meaning == meaning;

    if (isCorrect) {
      HapticFeedback.lightImpact();
      setState(() {
        _matched[word] = meaning;
        _correctWords.add(word);
        _selectedWord = null;
        _selectedMeaning = null;
      });
    } else {
      HapticFeedback.mediumImpact();
      _incorrectWordIds.add(pair.wordId);
      setState(() {
         // Set error state to trigger animations/red color
        _errorWord = word;
        _errorMeaning = meaning;
        _selectedWord = null;
        _selectedMeaning = null;
      });

      // Clear error after short delay
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && _errorWord == word) {
          setState(() {
            _errorWord = null;
            _errorMeaning = null;
          });
        }
      });
    }

    // Check if all matched
    if (_matched.length == _pairs.length) {
      _stopwatch.stop();
      setState(() => _completed = true);

      final correctWordIds = _pairs
          .where((p) => _correctWords.contains(p.word))
          .map((p) => p.wordId)
          .toList();

      _completionTimer = Timer(const Duration(milliseconds: 600), () {
        widget.onComplete(
          correctMatches: _correctWords.length,
          totalMatches: _pairs.length,
          correctWordIds: correctWordIds,
          incorrectWordIds: _incorrectWordIds.toList(),
        );
      });
    }
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
              'Tap pairs to match them',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),

          VocabQuestionContainer(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Words column
                Expanded(
                  child: Column(
                    children: _shuffledWords.map((word) {
                      final isMatched = _matched.containsKey(word);
                      final isSelected = _selectedWord == word;
                      final isError = _errorWord == word;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MatchTile(
                          text: word,
                          isSelected: isSelected,
                          isMatched: isMatched,
                          isError: isError,
                          onTap: () => _tapWord(word),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 16),
                // Meanings column
                Expanded(
                  child: Column(
                    children: _shuffledMeanings.map((meaning) {
                      final isMatched = _matched.containsValue(meaning);
                      final isSelected = _selectedMeaning == meaning;
                      final isError = _errorMeaning == meaning;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MatchTile(
                          text: meaning,
                          isSelected: isSelected,
                          isMatched: isMatched,
                          isError: isError,
                          onTap: () => _tapMeaning(meaning),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({
    required this.text,
    required this.isSelected,
    required this.isMatched,
    required this.isError,
    required this.onTap,
  });

  final String text;
  final bool isSelected;
  final bool isMatched;
  final bool isError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color bgColor = theme.colorScheme.surface;
    Color borderColor = theme.colorScheme.outline.withValues(alpha: 0.2);
    Color textColor = theme.colorScheme.onSurface;
    double borderWidth = 1.0;

    if (isMatched) {
      // Fade out matched items
      bgColor = Colors.transparent;
      borderColor = Colors.transparent;
      textColor = theme.colorScheme.onSurface.withValues(alpha: 0.2);
    } else if (isError) {
      bgColor = Colors.red.withValues(alpha: 0.1);
      borderColor = Colors.red;
      textColor = Colors.red.shade700;
      borderWidth = 2.0;
    } else if (isSelected) {
      bgColor = theme.colorScheme.primary.withValues(alpha: 0.1);
      borderColor = theme.colorScheme.primary;
      textColor = theme.colorScheme.primary;
      borderWidth = 2.0;
    }

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: isMatched || isError ? [] : [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isSelected || isError ? FontWeight.bold : FontWeight.w500,
            color: textColor,
          ),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    // Add Shake animation on error
    if (isError) {
      content = content.animate().shake(duration: 400.ms, hz: 4);
    }

    return GestureDetector(
      onTap: isMatched ? null : onTap,
      child: content,
    );
  }
}
