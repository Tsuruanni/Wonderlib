import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/text_styles.dart';
import '../../../app/theme.dart';
import '../../../core/utils/app_clock.dart';
import '../../utils/app_icons.dart';
import '../../../domain/entities/vocabulary.dart';
import '../../providers/vocabulary_provider.dart';

class VocabularyScreen extends ConsumerStatefulWidget {
  const VocabularyScreen({super.key});

  @override
  ConsumerState<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends ConsumerState<VocabularyScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final learnedWordsAsync = ref.watch(learnedWordsWithDetailsProvider);
    final allWords = learnedWordsAsync.valueOrNull ?? [];

    final dueWords = allWords.where((item) {
      return item.progress != null && item.progress!.isDueForReview;
    }).toList();

    final scheduledWords = allWords
        .where((item) => item.progress?.nextReviewAt != null)
        .toList()
      ..sort((a, b) => a.progress!.nextReviewAt!.compareTo(b.progress!.nextReviewAt!));

    final tabs = [
      _TabData('All', allWords.length, allWords),
      _TabData('Due', dueWords.length, dueWords),
      _TabData('Schedule', scheduledWords.length, scheduledWords),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.neutral, width: 2),
                      ),
                      child: AppIcons.arrowBack(size: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'MY WORD BANK',
                    style: AppTextStyles.titleLarge(color: AppColors.black),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Stats row
            if (!learnedWordsAsync.isLoading)
              _StatsRow(words: allWords),

            const SizedBox(height: 16),

            // Tab chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (int i = 0; i < tabs.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _TabChip(
                      label: tabs[i].label,
                      count: tabs[i].count,
                      isSelected: _selectedTab == i,
                      onTap: () => setState(() => _selectedTab = i),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Content
            Expanded(
              child: learnedWordsAsync.isLoading && allWords.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : learnedWordsAsync.hasError && allWords.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                              const SizedBox(height: 12),
                              Text(
                                'Failed to load vocabulary',
                                style: AppTextStyles.titleMedium(color: AppColors.neutralText),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => ref.invalidate(learnedWordsWithDetailsProvider),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _WordList(
                          words: tabs[_selectedTab].words,
                          emptyMessage: _selectedTab == 1
                              ? 'No words due for review'
                              : _selectedTab == 2
                                  ? 'No scheduled reviews'
                                  : 'No words learned yet',
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabData {
  const _TabData(this.label, this.count, this.words);
  final String label;
  final int count;
  final List<UserVocabularyItem> words;
}

// ─── Stats Row ───

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.words});
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neutral, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatBadge(value: total, label: 'Total', color: AppColors.secondary),
            _StatBadge(value: learning, label: 'Learning', color: AppColors.wasp),
            _StatBadge(value: mastered, label: 'Mastered', color: AppColors.primary),
            _StatBadge(value: dueNow, label: 'Due', color: AppColors.streakOrange),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.value, required this.label, required this.color});
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: AppTextStyles.headlineMedium(color: color).copyWith(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: AppTextStyles.caption(color: AppColors.neutralText),
        ),
      ],
    );
  }
}

// ─── Tab Chip ───

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.secondary : AppColors.neutral,
            width: 2,
          ),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: AppColors.neutral.withValues(alpha: 0.5),
                offset: const Offset(0, 2),
                blurRadius: 0,
              ),
          ],
        ),
        child: Text(
          '$label ($count)',
          style: AppTextStyles.button(color: isSelected ? Colors.white : AppColors.neutralText).copyWith(fontSize: 14),
        ),
      ),
    );
  }
}

// ─── Word List ───

class _WordList extends StatelessWidget {
  const _WordList({required this.words, required this.emptyMessage});
  final List<UserVocabularyItem> words;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: AppColors.neutral),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: AppTextStyles.titleMedium(color: AppColors.neutralText).copyWith(fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      itemCount: words.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _WordCard(item: words[index]),
    );
  }
}

// ─── Word Card ───

class _WordCard extends StatelessWidget {
  const _WordCard({required this.item});
  final UserVocabularyItem item;

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusIcon) = _statusVisual(item.status);

    return GestureDetector(
      onTap: () => _showWordDetail(context, item.word),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neutral, width: 2),
        ),
        child: Row(
          children: [
            // Status circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 14),
            // Word + meaning
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.word.word,
                    style: AppTextStyles.titleMedium(color: AppColors.black).copyWith(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    item.word.meaningTR,
                    style: AppTextStyles.bodySmall(color: AppColors.neutralText),
                  ),
                ],
              ),
            ),
            // Review status
            if (item.progress?.nextReviewAt != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.progress!.isDueForReview
                      ? AppColors.streakOrange.withValues(alpha: 0.1)
                      : AppColors.neutral.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatNextReview(item.progress!.nextReviewAt!),
                  style: AppTextStyles.caption(color: item.progress!.isDueForReview
                        ? AppColors.streakOrange
                        : AppColors.neutralText).copyWith(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  (Color, IconData) _statusVisual(VocabularyStatus status) {
    return switch (status) {
      VocabularyStatus.newWord => (AppColors.neutral, Icons.fiber_new_rounded),
      VocabularyStatus.learning => (AppColors.wasp, Icons.school_rounded),
      VocabularyStatus.reviewing => (AppColors.secondary, Icons.refresh_rounded),
      VocabularyStatus.mastered => (AppColors.primary, Icons.star_rounded),
    };
  }

  String _formatNextReview(DateTime date) {
    final today = AppClock.today();
    final reviewDay = DateTime(date.year, date.month, date.day);
    final diff = reviewDay.difference(today).inDays;

    if (diff < 0) return '${-diff}d overdue';
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Tomorrow';
    return 'In $diff days';
  }

  void _showWordDetail(BuildContext context, VocabularyWord word) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _WordDetailSheet(word: word),
    );
  }
}

// ─── Word Detail Sheet ───

class _WordDetailSheet extends StatelessWidget {
  const _WordDetailSheet({required this.word});
  final VocabularyWord word;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.neutral,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Word
          Text(
            word.word,
            style: AppTextStyles.headlineLarge(color: AppColors.black).copyWith(fontWeight: FontWeight.w900),
          ),
          if (word.phonetic != null)
            Text(
              word.phonetic!,
              style: AppTextStyles.titleMedium(color: AppColors.neutralText).copyWith(fontSize: 16),
            ),
          const SizedBox(height: 16),
          // Meaning
          _DetailChip(label: 'Turkish', value: word.meaningTR),
          if (word.meaningEN != null)
            _DetailChip(label: 'English', value: word.meaningEN!),
          // Example
          if (word.exampleSentence != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                word.exampleSentence!,
                style: AppTextStyles.bodyMedium(color: AppColors.black).copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ],
          // Tags
          if (word.level != null || word.categories.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (word.level != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      word.level!,
                      style: AppTextStyles.caption(color: AppColors.primary).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ...word.categories.map((cat) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        cat,
                        style: AppTextStyles.caption(color: AppColors.secondary).copyWith(fontWeight: FontWeight.w700),
                      ),
                    )),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.neutral.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: AppTextStyles.caption(color: AppColors.neutralText).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.titleMedium(color: AppColors.black).copyWith(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
