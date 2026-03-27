import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_clock.dart';
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
    final learnedWordsAsync = ref.watch(learnedWordsWithDetailsProvider);

    // Extract learned words (starts from progress, not dictionary)
    final allWords = learnedWordsAsync.valueOrNull ?? [];

    // Derived lists from learned words
    final dueWords = allWords.where((item) {
      return item.progress != null && item.progress!.isDueForReview;
    }).toList();

    // Schedule tab: words with next_review_at, sorted by date (earliest first)
    final scheduledWords = allWords
        .where((item) => item.progress?.nextReviewAt != null)
        .toList()
      ..sort((a, b) => a.progress!.nextReviewAt!.compareTo(b.progress!.nextReviewAt!));

    final isLoading = learnedWordsAsync.isLoading;
    final hasError = learnedWordsAsync.hasError;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vocabulary'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'All (${allWords.length})'),
            Tab(text: 'Due (${dueWords.length})'),
            Tab(text: 'Schedule (${scheduledWords.length})'),
          ],
        ),
      ),
      body: isLoading && allWords.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : hasError && allWords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 12),
                      const Text('Failed to load vocabulary'),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(learnedWordsWithDetailsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
              children: [
                // Stats Card
                _LearnedStatsCard(words: allWords),

                // Word Lists
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _WordListView(words: allWords),
                      _WordListView(words: dueWords, emptyMessage: 'No words due for review'),
                      _WordListView(words: scheduledWords, emptyMessage: 'No scheduled reviews'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _LearnedStatsCard extends StatelessWidget {

  const _LearnedStatsCard({required this.words});
  final List<UserVocabularyItem> words;

  @override
  Widget build(BuildContext context) {
    final total = words.length;
    final mastered = words.where((w) => w.progress?.isMastered ?? false).length;
    final learning = words.where((w) {
      final s = w.progress?.status;
      return s == VocabularyStatus.learning || s == VocabularyStatus.reviewing;
    }).length;
    final dueNow = words.where((w) => w.progress?.isDueForReview ?? false).length;

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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          StatItem(
            value: total.toString(),
            label: 'Total',
            icon: Icons.library_books,
            valueStyle: context.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          StatItem(
            value: learning.toString(),
            label: 'Learning',
            icon: Icons.trending_up,
            color: Colors.blue,
            valueStyle: context.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          StatItem(
            value: mastered.toString(),
            label: 'Mastered',
            icon: Icons.star,
            color: Colors.amber,
            valueStyle: context.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          StatItem(
            value: dueNow.toString(),
            label: 'Due',
            icon: Icons.schedule,
            color: Colors.orange,
            valueStyle: context.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _WordListView extends StatelessWidget {

  const _WordListView({
    required this.words,
    this.emptyMessage = 'No words found',
  });
  final List<UserVocabularyItem> words;
  final String emptyMessage;

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

  const _WordCard({required this.item});
  final UserVocabularyItem item;

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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.word.meaningTR),
            if (item.progress?.nextReviewAt != null)
              Text(
                _formatNextReview(item.progress!.nextReviewAt!),
                style: context.textTheme.bodySmall?.copyWith(
                  color: item.progress!.isDueForReview
                      ? Colors.orange.shade700
                      : context.colorScheme.outline,
                  fontWeight: item.progress!.isDueForReview
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
          ],
        ),
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

  String _formatNextReview(DateTime date) {
    final today = AppClock.today();
    final reviewDay = DateTime(date.year, date.month, date.day);
    final diff = reviewDay.difference(today).inDays;

    if (diff < 0) return 'Overdue (${-diff}d ago)';
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    return 'Review in $diff days (${date.month}/${date.day})';
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

  const _StatusIndicator({required this.status});
  final VocabularyStatus status;

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

  const _WordDetailSheet({required this.word});
  final VocabularyWord word;

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
                        ),),
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

  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

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
