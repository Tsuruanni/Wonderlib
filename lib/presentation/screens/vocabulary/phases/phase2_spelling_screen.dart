import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/extensions/context_extensions.dart';
import '../../../../domain/entities/vocabulary.dart';
import '../../../providers/vocabulary_provider.dart';

/// Phase 2: Spelling
/// Dictation exercise - listen and type the word
class Phase2SpellingScreen extends ConsumerStatefulWidget {
  final String listId;

  const Phase2SpellingScreen({super.key, required this.listId});

  @override
  ConsumerState<Phase2SpellingScreen> createState() => _Phase2SpellingScreenState();
}

class _Phase2SpellingScreenState extends ConsumerState<Phase2SpellingScreen> {
  int _currentIndex = 0;
  List<String> _userInput = [];
  bool _showResult = false;
  bool _isCorrect = false;
  int _correctCount = 0;
  int _incorrectCount = 0;
  bool _initialized = false;
  List<VocabularyWord> _words = [];

  late List<FocusNode> _focusNodes;
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _focusNodes = [];
    _controllers = [];
  }

  void _initializeInputFields(List<VocabularyWord> words) {
    if (words.isEmpty || _initialized) return;
    _words = words;
    _initialized = true;

    final wordLength = words[_currentIndex].word.length;
    _userInput = List.filled(wordLength, '');
    _focusNodes = List.generate(wordLength, (_) => FocusNode());
    _controllers = List.generate(wordLength, (_) => TextEditingController());
  }

  void _resetForNextWord() {
    if (_currentIndex >= _words.length) return;

    final wordLength = _words[_currentIndex].word.length;

    // Dispose old controllers and focus nodes
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }

    _userInput = List.filled(wordLength, '');
    _focusNodes = List.generate(wordLength, (_) => FocusNode());
    _controllers = List.generate(wordLength, (_) => TextEditingController());
    _showResult = false;
    _isCorrect = false;

    setState(() {});

    // Focus first field after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wordListAsync = ref.watch(wordListByIdProvider(widget.listId));
    final wordsAsync = ref.watch(wordsForListProvider(widget.listId));

    final wordList = wordListAsync.valueOrNull;
    final words = wordsAsync.valueOrNull ?? [];

    if (wordsAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Spelling')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (words.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Spelling')),
        body: const Center(child: Text('No words in this list')),
      );
    }

    // Initialize on first load
    if (!_initialized) {
      _initializeInputFields(words);
    }

    final currentWord = words[_currentIndex];
    final progress = (_currentIndex + 1) / words.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(wordList?.name ?? 'Spelling'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentIndex + 1}/${words.length}',
                style: context.textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: context.colorScheme.surfaceContainerHighest,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Score display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ScoreChip(
                        icon: Icons.check_circle,
                        count: _correctCount,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 16),
                      _ScoreChip(
                        icon: Icons.cancel,
                        count: _incorrectCount,
                        color: Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Audio button
                  _AudioButton(
                    onPressed: () {
                      // TODO: Play audio
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('🔊 "${currentWord.word}"'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Listen and spell the word',
                    style: context.textTheme.titleMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),

                  // Hint: Turkish meaning
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Hint: ${currentWord.meaningTR}',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Letter boxes
                  _LetterBoxes(
                    word: currentWord.word,
                    userInput: _userInput,
                    controllers: _controllers,
                    focusNodes: _focusNodes,
                    showResult: _showResult,
                    onChanged: (index, value) {
                      setState(() {
                        _userInput[index] = value;
                      });
                      // Auto-advance to next box
                      if (value.isNotEmpty && index < _focusNodes.length - 1) {
                        _focusNodes[index + 1].requestFocus();
                      }
                    },
                    onBackspace: (index) {
                      if (index > 0 && _userInput[index].isEmpty) {
                        _focusNodes[index - 1].requestFocus();
                        setState(() {
                          _userInput[index - 1] = '';
                          _controllers[index - 1].clear();
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 32),

                  // Result display
                  if (_showResult) ...[
                    _ResultDisplay(
                      isCorrect: _isCorrect,
                      correctWord: currentWord.word,
                      userWord: _userInput.join(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Action button
                  if (!_showResult)
                    FilledButton.icon(
                      onPressed: _userInput.every((c) => c.isNotEmpty)
                          ? _checkAnswer
                          : null,
                      icon: const Icon(Icons.check),
                      label: const Text('Check'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(200, 50),
                        backgroundColor: Colors.purple,
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _nextWord,
                      icon: Icon(_currentIndex < words.length - 1
                          ? Icons.arrow_forward
                          : Icons.done_all),
                      label: Text(_currentIndex < words.length - 1
                          ? 'Next Word'
                          : 'Complete'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(200, 50),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _checkAnswer() {
    final correctWord = _words[_currentIndex].word.toLowerCase();
    final userWord = _userInput.join().toLowerCase();

    setState(() {
      _showResult = true;
      _isCorrect = correctWord == userWord;
      if (_isCorrect) {
        _correctCount++;
      } else {
        _incorrectCount++;
      }
    });

    HapticFeedback.mediumImpact();
  }

  void _nextWord() {
    if (_currentIndex < _words.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _resetForNextWord();
    } else {
      _completePhase();
    }
  }

  void _completePhase() {
    final total = _correctCount + _incorrectCount;
    final percentage = total > 0 ? (_correctCount / total * 100).round() : 0;

    // Mark phase as complete
    ref.read(wordListProgressControllerProvider.notifier)
        .completePhase(widget.listId, 2);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          percentage >= 70 ? Icons.celebration : Icons.school,
          color: percentage >= 70 ? Colors.amber : Colors.purple,
          size: 48,
        ),
        title: const Text('Phase 2 Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Score: $_correctCount/$total ($percentage%)',
              style: context.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              percentage >= 70
                  ? 'Excellent spelling skills!'
                  : 'Keep practicing to improve!',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Back to List'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Navigate to phase 3
              context.pushReplacement('/vocabulary/list/${widget.listId}/phase/3');
            },
            child: const Text('Continue to Flashcards'),
          ),
        ],
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;

  const _ScoreChip({
    required this.icon,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: context.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _AudioButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.purple,
              Colors.purple.shade700,
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.volume_up,
          color: Colors.white,
          size: 48,
        ),
      ),
    );
  }
}

class _LetterBoxes extends StatelessWidget {
  final String word;
  final List<String> userInput;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final bool showResult;
  final Function(int, String) onChanged;
  final Function(int) onBackspace;

  const _LetterBoxes({
    required this.word,
    required this.userInput,
    required this.controllers,
    required this.focusNodes,
    required this.showResult,
    required this.onChanged,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate box size based on word length and screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBoxWidth = ((screenWidth - 48) / word.length.clamp(1, 10)) - 6;
    final boxSize = maxBoxWidth.clamp(32.0, 44.0);

    return Wrap(
      spacing: 6,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: List.generate(word.length, (index) {
        final isCorrect = showResult &&
            userInput[index].toLowerCase() == word[index].toLowerCase();
        final isIncorrect = showResult &&
            userInput[index].isNotEmpty &&
            userInput[index].toLowerCase() != word[index].toLowerCase();

        return SizedBox(
          width: boxSize,
          height: boxSize + 8,
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.backspace &&
                  userInput[index].isEmpty &&
                  index > 0) {
                onBackspace(index);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: controllers[index],
              focusNode: focusNodes[index],
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              maxLength: 1,
              enabled: !showResult,
              style: TextStyle(
                fontSize: boxSize * 0.5,
                fontWeight: FontWeight.bold,
                color: showResult
                    ? (isCorrect ? Colors.green : Colors.red)
                    : null,
                height: 1.2,
              ),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                fillColor: showResult
                    ? (isCorrect
                        ? Colors.green.withValues(alpha: 0.1)
                        : isIncorrect
                            ? Colors.red.withValues(alpha: 0.1)
                            : context.colorScheme.surfaceContainerHighest)
                    : context.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: showResult
                        ? (isCorrect ? Colors.green : Colors.red)
                        : context.colorScheme.outline,
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: context.colorScheme.outline.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Colors.purple,
                    width: 2,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isCorrect ? Colors.green : Colors.red,
                    width: 2,
                  ),
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
              ],
              onChanged: (value) => onChanged(index, value),
              onSubmitted: (_) {
                if (index < focusNodes.length - 1) {
                  focusNodes[index + 1].requestFocus();
                }
              },
            ),
          ),
        );
      }),
    );
  }
}

class _ResultDisplay extends StatelessWidget {
  final bool isCorrect;
  final String correctWord;
  final String userWord;

  const _ResultDisplay({
    required this.isCorrect,
    required this.correctWord,
    required this.userWord,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCorrect
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCorrect ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            color: isCorrect ? Colors.green : Colors.red,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            isCorrect ? 'Correct!' : 'Not quite...',
            style: context.textTheme.titleLarge?.copyWith(
              color: isCorrect ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (!isCorrect) ...[
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: context.textTheme.bodyLarge,
                children: [
                  const TextSpan(text: 'Correct spelling: '),
                  TextSpan(
                    text: correctWord,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
