import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/utils/extensions/context_extensions.dart';
import '../../../domain/entities/word_list.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/common/game_button.dart';

/// Detail screen for a word list showing phases and progress
class WordListDetailScreen extends ConsumerWidget {

  const WordListDetailScreen({super.key, required this.listId});
  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordListAsync = ref.watch(wordListByIdProvider(listId));
    final progress = ref.watch(wordListProgressProvider(listId));
    final wordsAsync = ref.watch(wordsForListProvider(listId));

    // Handle loading state
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
          // Header with cover
          _ListHeader(wordList: wordList, progress: progress),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 32),

                  // Learning Phases section
                  Text(
                    'Learning Levels',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Phase cards
                  _PhaseCard(
                    phase: 1,
                    title: 'Learn Vocab',
                    description: 'See all words with meanings and images',
                    icon: Icons.visibility_rounded,
                    color: AppColors.gemBlue,
                    isComplete: progress?.phase1Complete ?? false,
                    isRecommended: progress == null || (!progress.phase1Complete),
                    onTap: () => _navigateToPhase(context, 1),
                  ),
                  _PhaseCard(
                    phase: 2,
                    title: 'Spelling',
                    description: 'Practice spelling by listening',
                    icon: Icons.keyboard_rounded,
                    color: Colors.purple,
                    isComplete: progress?.phase2Complete ?? false,
                    isRecommended: (progress?.phase1Complete ?? false) &&
                                   progress?.phase2Complete != true,
                    onTap: () => _navigateToPhase(context, 2),
                  ),
                  _PhaseCard(
                    phase: 3,
                    title: 'Flashcards',
                    description: 'Test yourself with flip cards',
                    icon: Icons.flip_rounded,
                    color: AppColors.streakOrange,
                    isComplete: progress?.phase3Complete ?? false,
                    isRecommended: (progress?.phase2Complete ?? false) &&
                                   progress?.phase3Complete != true,
                    onTap: () => _navigateToPhase(context, 3),
                  ),
                  _PhaseCard(
                    phase: 4,
                    title: 'Review',
                    description: 'Quiz to check your knowledge',
                    icon: Icons.quiz_rounded,
                    color: AppColors.primary,
                    isComplete: progress?.phase4Complete ?? false,
                    isRecommended: (progress?.phase3Complete ?? false) &&
                                   progress?.phase4Complete != true,
                    onTap: () => _navigateToPhase(context, 4),
                    score: progress?.phase4Score,
                    total: progress?.phase4Total,
                  ),

                  const SizedBox(height: 100), // Space for FAB
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(context, progress),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildFAB(BuildContext context, UserWordListProgress? progress) {
    final nextPhase = progress?.nextPhase ?? 1;
    final isComplete = progress?.isFullyComplete ?? false;

    if (isComplete) {
      return Container(
         width: 200,
         height: 56,
         margin: const EdgeInsets.only(bottom: 20),
         child: GameButton(
            label: 'Practice Again',
            icon: const Icon(Icons.replay_rounded),
            variant: GameButtonVariant.primary,
            onPressed: () => _navigateToPhase(context, 1),
         ),
      );
    }

    final phaseNames = ['', 'Learn Vocab', 'Spelling', 'Flashcards', 'Review'];
    return Container(
        width: 280,
        height: 64,
        margin: const EdgeInsets.only(bottom: 20),
        child: GameButton(
          label: progress == null ? 'Start Learning' : 'Continue: ${phaseNames[nextPhase]}',
          icon: Icon(progress == null ? Icons.play_arrow_rounded : Icons.play_circle_fill_rounded),
          variant: GameButtonVariant.primary,
          onPressed: () => _navigateToPhase(context, nextPhase),
        ),
    );
  }

  void _navigateToPhase(BuildContext context, int phase) {
    context.push('/vocabulary/list/$listId/phase/$phase');
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
      expandedHeight: 220,
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
             // Gradient overlay
             Container(
               decoration: BoxDecoration(
                 gradient: LinearGradient(
                   begin: Alignment.topCenter,
                   end: Alignment.bottomCenter,
                   colors: [Colors.transparent, Colors.black.withValues(alpha: 0.3)],
                 )
               ),
             ),
            // Category icon huge
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

            // Progress indicator
            if (progress != null)
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
                      '${(progress!.progressPercentage * 100).toInt()}% complete',
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

/// Small stat chip
class _StatChip extends StatelessWidget {

  const _StatChip({
    required this.icon,
    required this.label,
  });
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
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.bold,
              color: AppColors.neutralText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card for a learning phase
class _PhaseCard extends StatelessWidget {

  const _PhaseCard({
    required this.phase,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isComplete,
    required this.isRecommended,
    required this.onTap,
    this.score,
    this.total,
  });
  final int phase;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isComplete;
  final bool isRecommended;
  final VoidCallback onTap;
  final int? score;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final borderColor = isRecommended ? color : AppColors.neutral;
    final bgColor = isRecommended ? AppColors.white : AppColors.white.withValues(alpha: 0.8);
    final shadowColor = isRecommended ? color.withValues(alpha: 0.3) : AppColors.neutral;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
           color: bgColor,
           borderRadius: BorderRadius.circular(20),
           border: Border.all(color: borderColor, width: isRecommended ? 3 : 2),
           boxShadow: [
              BoxShadow(
                color: shadowColor,
                offset: Offset(0, 4),
                blurRadius: 0,
              )
           ]
        ),
        child: Row(
           children: [
             // Icon Box
             Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                   color: isComplete ? AppColors.primary : color.withValues(alpha: 0.1),
                   borderRadius: BorderRadius.circular(16),
                   border: Border.all(
                     color: isComplete ? AppColors.primaryShadow : color.withValues(alpha: 0.5),
                     width: 2,
                   )
                ),
                child: Center(
                  child: Icon(
                    isComplete ? Icons.check_rounded : icon,
                    color: isComplete ? Colors.white : color,
                    size: 32,
                  ),
                ),
             ),
             const SizedBox(width: 16),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Row(
                     children: [
                       Text(
                         title,
                         style: GoogleFonts.nunito(
                           fontSize: 18,
                           fontWeight: FontWeight.w900,
                           color: isRecommended ? AppColors.black : AppColors.neutralText,
                         ),
                       ),
                       if (isRecommended && !isComplete)
                          Container(
                             margin: const EdgeInsets.only(left: 8),
                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                             decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                             child: Text('NEXT', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                          )
                     ],
                   ),
                   const SizedBox(height: 4),
                   Text(
                     description,
                     style: GoogleFonts.nunito(
                        color: AppColors.neutralText,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                     ),
                   ),
                   if (score != null)
                      Text(
                         'High Score: $score/$total',
                         style: GoogleFonts.nunito(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                 ],
               ),
             ),
           ],
        ),
      ),
    );
  }
}
