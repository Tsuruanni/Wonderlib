import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/extensions/context_extensions.dart';
import '../../../domain/repositories/teacher_repository.dart';
import '../../providers/teacher_provider.dart';

class StudentDetailScreen extends ConsumerWidget {
  const StudentDetailScreen({
    super.key,
    required this.studentId,
  });

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(studentDetailProvider(studentId));
    final progressAsync = ref.watch(studentProgressProvider(studentId));
    final vocabStatsAsync = ref.watch(studentVocabStatsProvider(studentId));
    final wordListProgressAsync = ref.watch(studentWordListProgressProvider(studentId));

    return Scaffold(
      body: studentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: context.colorScheme.error),
              const SizedBox(height: 16),
              Text('Error loading student', style: context.textTheme.bodyLarge),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  ref.invalidate(studentDetailProvider(studentId));
                  ref.invalidate(studentProgressProvider(studentId));
                  ref.invalidate(studentVocabStatsProvider(studentId));
                  ref.invalidate(studentWordListProgressProvider(studentId));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (student) {
          if (student == null) {
            return const Center(child: Text('Student not found'));
          }

          return CustomScrollView(
            slivers: [
              // Header with student info
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.colorScheme.primary,
                          context.colorScheme.primary.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white,
                            backgroundImage: student.avatarUrl != null
                                ? NetworkImage(student.avatarUrl!)
                                : null,
                            child: student.avatarUrl == null
                                ? Text(
                                    student.firstName.isNotEmpty
                                        ? student.firstName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 32,
                                      color: context.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            student.fullName,
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (student.studentNumber != null)
                            Text(
                              'Student #${student.studentNumber}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Stats row
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  color: context.colorScheme.surfaceContainerHighest,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatColumn(
                        value: '${student.xp}',
                        label: 'XP',
                        icon: Icons.star,
                        color: Colors.amber,
                      ),
                      _StatColumn(
                        value: '${student.level}',
                        label: 'Level',
                        icon: Icons.trending_up,
                        color: Colors.blue,
                      ),
                      _StatColumn(
                        value: '${student.currentStreak}',
                        label: 'Streak',
                        icon: Icons.local_fire_department,
                        color: Colors.orange,
                      ),
                      _StatColumn(
                        value: '${student.longestStreak}',
                        label: 'Best',
                        icon: Icons.emoji_events,
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ),
              ),

              // Reading Progress section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Reading Progress',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Book progress list
              progressAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SliverToBoxAdapter(
                  child: Center(child: Text('Error loading progress')),
                ),
                data: (progressList) {
                  if (progressList.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              size: 48,
                              color: context.colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No reading activity yet',
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: context.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final progress = progressList[index];
                        return _BookProgressCard(progress: progress);
                      },
                      childCount: progressList.length,
                    ),
                  );
                },
              ),

              // Vocabulary Stats section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: Text(
                    'Vocabulary Progress',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: vocabStatsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('Error loading vocabulary stats')),
                  ),
                  data: (stats) => _VocabStatsSection(stats: stats),
                ),
              ),

              // Word Lists section
              SliverToBoxAdapter(
                child: wordListProgressAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (lists) => lists.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Word Lists (${lists.length})',
                            style: context.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),

              wordListProgressAsync.when(
                loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                data: (lists) {
                  if (lists.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.abc_outlined,
                              size: 48,
                              color: context.colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No vocabulary activity yet',
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: context.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final progress = lists[index];
                        return _WordListProgressCard(progress: progress);
                      },
                      childCount: lists.length,
                    ),
                  );
                },
              ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 32),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: context.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _BookProgressCard extends StatelessWidget {
  const _BookProgressCard({required this.progress});

  final StudentBookProgress progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Book cover
            Container(
              width: 50,
              height: 70,
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
                image: progress.bookCoverUrl != null
                    ? DecorationImage(
                        image: NetworkImage(progress.bookCoverUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: progress.bookCoverUrl == null
                  ? Icon(
                      Icons.book,
                      color: context.colorScheme.outline,
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Book info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    progress.bookTitle,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${progress.completedChapters}/${progress.totalChapters} chapters',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: context.colorScheme.outline),
                      const SizedBox(width: 4),
                      Text(
                        _formatReadingTime(progress.totalReadingTime),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Progress percentage
            SizedBox(
              width: 50,
              height: 50,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress.completionPercentage / 100,
                    strokeWidth: 4,
                    backgroundColor: context.colorScheme.surfaceContainerHighest,
                    color: _getProgressColor(progress.completionPercentage),
                  ),
                  Text(
                    '${progress.completionPercentage.toStringAsFixed(0)}%',
                    style: context.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatReadingTime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 100) return Colors.green;
    if (percentage >= 50) return Colors.blue;
    if (percentage >= 25) return Colors.orange;
    return Colors.red;
  }
}

class _VocabStatsSection extends StatelessWidget {
  const _VocabStatsSection({required this.stats});

  final StudentVocabStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatColumn(
            value: '${stats.totalWords}',
            label: 'Words',
            icon: Icons.abc,
            color: Colors.blue,
          ),
          _StatColumn(
            value: '${stats.masteredCount}',
            label: 'Mastered',
            icon: Icons.check_circle,
            color: Colors.green,
          ),
          _StatColumn(
            value: '${stats.learningCount}',
            label: 'Learning',
            icon: Icons.school,
            color: Colors.orange,
          ),
          _StatColumn(
            value: '${stats.totalSessions}',
            label: 'Sessions',
            icon: Icons.replay,
            color: Colors.purple,
          ),
        ],
      ),
    );
  }
}

class _WordListProgressCard extends StatelessWidget {
  const _WordListProgressCard({required this.progress});

  final StudentWordListProgress progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // List icon with level badge
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _getCategoryColor(progress.wordListCategory).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.list_alt,
                    color: _getCategoryColor(progress.wordListCategory),
                    size: 24,
                  ),
                  if (progress.wordListLevel != null)
                    Text(
                      progress.wordListLevel!,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: _getCategoryColor(progress.wordListCategory),
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // List info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    progress.wordListName,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${progress.wordCount} words',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${progress.totalSessions} sessions',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  if (progress.bestAccuracy != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(3, (i) => Icon(
                          i < progress.starCount ? Icons.star : Icons.star_border,
                          size: 16,
                          color: i < progress.starCount ? Colors.amber : context.colorScheme.outline,
                        )),
                        const SizedBox(width: 4),
                        Text(
                          '${progress.bestAccuracy!.toStringAsFixed(0)}%',
                          style: context.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _getAccuracyColor(progress.bestAccuracy!),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Completion indicator
            if (progress.isComplete)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'common_words':
        return Colors.blue;
      case 'grade_level':
        return Colors.green;
      case 'test_prep':
        return Colors.red;
      case 'thematic':
        return Colors.purple;
      case 'story_vocab':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return Colors.green;
    if (accuracy >= 70) return Colors.blue;
    if (accuracy >= 50) return Colors.orange;
    return Colors.red;
  }
}
