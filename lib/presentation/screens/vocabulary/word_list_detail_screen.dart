import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/word_list.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/common/game_button.dart';

/// Detail screen for a word list — simplified session-based design
class WordListDetailScreen extends ConsumerWidget {

  const WordListDetailScreen({super.key, required this.listId});
  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordListAsync = ref.watch(wordListByIdProvider(listId));
    final progressAsync = ref.watch(progressForListProvider(listId));
    final wordsAsync = ref.watch(wordsForListProvider(listId));
    final canStart = ref.watch(canStartWordListProvider(listId));

    final progress = progressAsync.valueOrNull;

    // Lock applies only to un-started lists that exceed daily limit
    final isLocked = !canStart && progress == null;

    if (wordListAsync.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final wordList = wordListAsync.valueOrNull;
    final words = wordsAsync.valueOrNull ?? [];

    if (wordList == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(iconTheme: IconThemeData(color: AppColors.black)),
        body: Center(child: Text('Word list not found', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.bold))),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _ListHeader(wordList: wordList, progress: progress),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Daily limit banner
                  if (isLocked)
                    _DailyLimitBanner(wordsToday: ref.watch(wordsStartedTodayFromListsProvider).valueOrNull ?? 0),

                  // Description
                  Text(
                    wordList.description,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      color: AppColors.neutralText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Stats row
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.menu_book_rounded,
                        label: '${words.length} words',
                      ),
                      const SizedBox(width: 8),
                      if (wordList.level != null)
                        _StatChip(
                          icon: Icons.signal_cellular_alt_rounded,
                          label: wordList.level!,
                        ),
                    ],
                  ),

                  // Session stats (if has progress)
                  if (progress != null) ...[
                    const SizedBox(height: 24),
                    _SessionStatsCard(progress: progress),
                  ],

                  // Star display
                  if (progress != null && progress.starCount > 0) ...[
                    const SizedBox(height: 16),
                    _StarDisplay(stars: progress.starCount),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomButton(context, progress, isLocked: isLocked),
    );
  }

  Widget _buildBottomButton(BuildContext context, UserWordListProgress? progress, {required bool isLocked}) {
    final hasCompleted = progress?.isComplete ?? false;

    final Widget button;

    if (isLocked) {
      button = SizedBox(
        width: 280,
        height: 54,
        child: GameButton(
          label: 'Daily Limit Reached',
          icon: const Icon(Icons.lock_rounded),
          variant: GameButtonVariant.primary,
          onPressed: null,
        ),
      );
    } else if (hasCompleted) {
      button = SizedBox(
        width: 280,
        height: 54,
        child: GameButton(
          label: 'Practice Again',
          icon: const Icon(Icons.replay_rounded),
          variant: GameButtonVariant.primary,
          onPressed: () => _startSession(context),
        ),
      );
    } else {
      button = SizedBox(
        width: 280,
        height: 54,
        child: GameButton(
          label: progress == null ? 'Start Session' : 'Continue Learning',
          icon: const Icon(Icons.play_arrow_rounded),
          variant: GameButtonVariant.primary,
          onPressed: () => _startSession(context),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20, top: 8),
        child: Center(heightFactor: 1.0, child: button),
      ),
    );
  }

  void _startSession(BuildContext context) {
    context.push(AppRoutes.vocabularySessionPath(listId));
  }
}

/// Header with gradient and list info
class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.wordList,
    this.progress,
  });
  final WordList wordList;
  final UserWordListProgress? progress;

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor(wordList.category);

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: color,
      leading: IconButton(
         icon: Container(
           padding: const EdgeInsets.all(8),
           decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
           child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
         ),
         onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
        centerTitle: false,
        title: Text(
          wordList.name,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: Colors.white,
            shadows: [Shadow(blurRadius: 2, color: Colors.black26, offset: Offset(0, 1))],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        background: Stack(
          children: [
             Container(color: color),
             Container(
               decoration: BoxDecoration(
                 gradient: LinearGradient(
                   begin: Alignment.topCenter,
                   end: Alignment.bottomCenter,
                   colors: [Colors.transparent, Colors.black.withValues(alpha: 0.3)],
                 ),
               ),
             ),
            Positioned(
              right: -20,
              bottom: 20,
              child: Transform.rotate(
                angle: -0.2,
                child: Text(
                  wordList.category.icon,
                  style: TextStyle(
                    fontSize: 140,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),
            ),
            // Accuracy progress bar
            if (progress != null && progress!.bestAccuracy != null)
              Positioned(
                left: 20,
                right: 20,
                bottom: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress!.progressPercentage,
                        minHeight: 12,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Best: ${progress!.bestAccuracy!.toStringAsFixed(0)}% accuracy',
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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

  Color _getCategoryColor(WordListCategory category) {
    switch (category) {
      case WordListCategory.commonWords:
        return AppColors.gemBlue;
      case WordListCategory.gradeLevel:
        return AppColors.primary;
      case WordListCategory.testPrep:
        return AppColors.streakOrange;
      case WordListCategory.thematic:
        return AppColors.secondary;
      case WordListCategory.storyVocab:
        return Colors.pink;
    }
  }
}

/// Session stats card
class _SessionStatsCard extends StatelessWidget {
  const _SessionStatsCard({required this.progress});
  final UserWordListProgress progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral, width: 2),
        boxShadow: [
          BoxShadow(color: AppColors.neutral, offset: Offset(0, 3), blurRadius: 0),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MiniStat(
            value: '${progress.totalSessions}',
            label: 'Sessions',
            icon: Icons.repeat_rounded,
          ),
          if (progress.bestAccuracy != null)
            _MiniStat(
              value: '${progress.bestAccuracy!.toStringAsFixed(0)}%',
              label: 'Best',
              icon: Icons.star_rounded,
            ),
          if (progress.bestScore != null)
            _MiniStat(
              value: '${progress.bestScore}',
              label: 'Top Coin',
              icon: Icons.bolt_rounded,
            ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label, required this.icon});
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.black,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.neutralText,
          ),
        ),
      ],
    );
  }
}

/// Star display based on accuracy
class _StarDisplay extends StatelessWidget {
  const _StarDisplay({required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isFilled = i < stars;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            isFilled ? Icons.star_rounded : Icons.star_border_rounded,
            color: isFilled ? Colors.amber : AppColors.neutral,
            size: 36,
          ),
        );
      }),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neutral, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.neutralText),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: AppColors.neutralText),
          ),
        ],
      ),
    );
  }
}

class _DailyLimitBanner extends StatelessWidget {
  const _DailyLimitBanner({required this.wordsToday});
  final int wordsToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.streakOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.streakOrange.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_rounded, color: AppColors.streakOrange, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Limit Reached',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.black),
                ),
                Text(
                  "You've learned $wordsToday/$dailyWordListLimit words today. Come back tomorrow!",
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.neutralText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
