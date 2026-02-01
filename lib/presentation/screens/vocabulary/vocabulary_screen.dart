import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/extensions/context_extensions.dart';
import '../../../domain/entities/vocabulary.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/common/stat_item.dart';

class VocabularyScreen extends ConsumerStatefulWidget {
  const VocabularyScreen({super.key});

  @override
  ConsumerState<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends ConsumerState<VocabularyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(vocabularyStatsSimpleProvider);
    final allWordsAsync = ref.watch(userVocabularyProvider);
    final dueWordsAsync = ref.watch(wordsDueForReviewProvider);
    final newWordsAsync = ref.watch(newWordsToLearnProvider);

    // Extract values from AsyncValue, using empty lists/defaults while loading
    final allWords = allWordsAsync.valueOrNull ?? [];
    final dueWords = dueWordsAsync.valueOrNull ?? [];
    final newWords = newWordsAsync.valueOrNull ?? [];
    final stats = statsAsync.valueOrNull;

    final isLoading = allWordsAsync.isLoading ||
        dueWordsAsync.isLoading ||
        newWordsAsync.isLoading ||
        statsAsync.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vocabulary'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'All (${allWords.length})'),
            Tab(text: 'Review (${dueWords.length})'),
            Tab(text: 'New (${newWords.length})'),
          ],
        ),
      ),
      body: isLoading && stats == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stats Card
                if (stats != null) _StatsCard(stats: stats),

                // Word Lists
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _WordListView(words: allWords),
                      _WordListView(words: dueWords, emptyMessage: 'No words to review'),
                      _WordListView(words: newWords, emptyMessage: 'No new words'),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: dueWords.isNotEmpty || newWords.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _startPractice(context, [...dueWords, ...newWords.take(5)]),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Practice'),
            )
          : null,
    );
  }

  void _startPractice(BuildContext context, List<UserVocabularyItem> words) {
    if (words.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FlashcardPracticeScreen(words: words),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final VocabularyStats stats;

  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colorScheme.primaryContainer,
            context.colorScheme.primaryContainer.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StatItem(
                value: stats.totalWords.toString(),
                label: 'Total',
                icon: Icons.library_books,
                valueStyle: context.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              StatItem(
                value: stats.masteredCount.toString(),
                label: 'Mastered',
                icon: Icons.star,
                color: Colors.amber,
                valueStyle: context.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              StatItem(
                value: stats.inProgressCount.toString(),
                label: 'Learning',
                icon: Icons.trending_up,
                color: Colors.blue,
                valueStyle: context.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: stats.totalWords > 0 ? stats.masteredCount / stats.totalWords : 0,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${((stats.masteredCount / stats.totalWords) * 100).toStringAsFixed(0)}% mastered',
            style: context.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _WordListView extends StatelessWidget {
  final List<UserVocabularyItem> words;
  final String emptyMessage;

  const _WordListView({
    required this.words,
    this.emptyMessage = 'No words found',
  });

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: context.colorScheme.outline),
            const SizedBox(height: 16),
            Text(emptyMessage, style: context.textTheme.bodyLarge),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: words.length,
      itemBuilder: (context, index) {
        return _WordCard(item: words[index]);
      },
    );
  }
}

class _WordCard extends StatelessWidget {
  final UserVocabularyItem item;

  const _WordCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _StatusIndicator(status: item.status),
        title: Text(
          item.word.word,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(item.word.meaningTR),
        trailing: item.word.phonetic != null
            ? Text(
                item.word.phonetic!,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.outline,
                ),
              )
            : null,
        onTap: () => _showWordDetail(context, item.word),
      ),
    );
  }

  void _showWordDetail(BuildContext context, VocabularyWord word) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _WordDetailSheet(word: word),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final VocabularyStatus status;

  const _StatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      VocabularyStatus.newWord => (Colors.grey, Icons.fiber_new),
      VocabularyStatus.learning => (Colors.orange, Icons.school),
      VocabularyStatus.reviewing => (Colors.blue, Icons.refresh),
      VocabularyStatus.mastered => (Colors.green, Icons.star),
    };

    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withValues(alpha: 0.2),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _WordDetailSheet extends StatelessWidget {
  final VocabularyWord word;

  const _WordDetailSheet({required this.word});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Word
              Text(
                word.word,
                style: context.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              if (word.phonetic != null) ...[
                const SizedBox(height: 4),
                Text(
                  word.phonetic!,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colorScheme.outline,
                  ),
                ),
              ],

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Turkish meaning
              _DetailRow(
                label: 'Turkish',
                value: word.meaningTR,
              ),

              if (word.meaningEN != null)
                _DetailRow(
                  label: 'English',
                  value: word.meaningEN!,
                ),

              if (word.exampleSentence != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Example Sentence',
                  style: context.textTheme.labelLarge?.copyWith(
                    color: context.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    word.exampleSentence!,
                    style: context.textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],

              if (word.level != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Chip(
                      label: Text(word.level!),
                      backgroundColor: context.colorScheme.primaryContainer,
                    ),
                    const SizedBox(width: 8),
                    ...word.categories.map((cat) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text(cat),
                            backgroundColor: context.colorScheme.secondaryContainer,
                          ),
                        )),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: context.textTheme.labelLarge?.copyWith(
                color: context.colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: context.textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// FLASHCARD PRACTICE SCREEN
// ============================================

class _FlashcardPracticeScreen extends StatefulWidget {
  final List<UserVocabularyItem> words;

  const _FlashcardPracticeScreen({required this.words});

  @override
  State<_FlashcardPracticeScreen> createState() => _FlashcardPracticeScreenState();
}

class _FlashcardPracticeScreenState extends State<_FlashcardPracticeScreen> {
  int _currentIndex = 0;
  bool _showAnswer = false;
  int _correctCount = 0;
  int _incorrectCount = 0;

  UserVocabularyItem get currentWord => widget.words[_currentIndex];
  bool get isComplete => _currentIndex >= widget.words.length;
  double get progress => (_currentIndex) / widget.words.length;

  void _flipCard() {
    setState(() {
      _showAnswer = true;
    });
  }

  void _answerCard(bool correct) {
    setState(() {
      if (correct) {
        _correctCount++;
      } else {
        _incorrectCount++;
      }
      _showAnswer = false;
      _currentIndex++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Practice (${_currentIndex + 1}/${widget.words.length})'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: isComplete ? _buildResults(context) : _buildPractice(context),
    );
  }

  Widget _buildPractice(BuildContext context) {
    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(value: progress),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GestureDetector(
              onTap: _showAnswer ? null : _flipCard,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _showAnswer
                    ? _buildAnswerCard(context)
                    : _buildQuestionCard(context),
              ),
            ),
          ),
        ),

        // Answer buttons (only when showing answer)
        if (_showAnswer)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _answerCard(false),
                    icon: const Icon(Icons.close),
                    label: const Text("Don't Know"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red.shade900,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _answerCard(true),
                    icon: const Icon(Icons.check),
                    label: const Text('I Know'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade100,
                      foregroundColor: Colors.green.shade900,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Tap card to see the answer',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.outline,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuestionCard(BuildContext context) {
    return Card(
      key: const ValueKey('question'),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              currentWord.word.word,
              style: context.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (currentWord.word.phonetic != null) ...[
              const SizedBox(height: 8),
              Text(
                currentWord.word.phonetic!,
                style: context.textTheme.titleMedium?.copyWith(
                  color: context.colorScheme.outline,
                ),
              ),
            ],
            const SizedBox(height: 32),
            Icon(
              Icons.touch_app,
              size: 48,
              color: context.colorScheme.outline.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerCard(BuildContext context) {
    return Card(
      key: const ValueKey('answer'),
      elevation: 4,
      color: context.colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              currentWord.word.word,
              style: context.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                currentWord.word.meaningTR,
                style: context.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
            if (currentWord.word.exampleSentence != null) ...[
              const SizedBox(height: 24),
              Text(
                currentWord.word.exampleSentence!,
                style: context.textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final total = _correctCount + _incorrectCount;
    final accuracy = total > 0 ? (_correctCount / total * 100).toStringAsFixed(0) : '0';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _correctCount >= _incorrectCount ? Icons.celebration : Icons.sentiment_neutral,
              size: 80,
              color: _correctCount >= _incorrectCount ? Colors.amber : Colors.grey,
            ),
            const SizedBox(height: 24),
            Text(
              'Practice Complete!',
              style: context.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ResultStat(
                  value: _correctCount.toString(),
                  label: 'Correct',
                  color: Colors.green,
                ),
                _ResultStat(
                  value: _incorrectCount.toString(),
                  label: 'Incorrect',
                  color: Colors.red,
                ),
                _ResultStat(
                  value: '$accuracy%',
                  label: 'Accuracy',
                  color: context.colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.done),
              label: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _ResultStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: context.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: context.textTheme.bodyMedium),
      ],
    );
  }
}
