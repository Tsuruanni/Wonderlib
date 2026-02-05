import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/word_list.dart';
import '../../providers/daily_review_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../providers/vocabulary_provider.dart';

/// Main vocabulary hub screen with word lists organized by sections
class VocabularyHubScreen extends ConsumerWidget {
  const VocabularyHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continueLearningAsync = ref.watch(continueWordListsProvider);
    final recommendedAsync = ref.watch(recommendedWordListsProvider);
    final storyListsAsync = ref.watch(storyWordListsProvider);
    final hubStatsAsync = ref.watch(vocabularyHubStatsProvider);

    // Extract values with defaults
    final continueLeaning = continueLearningAsync.valueOrNull ?? [];
    final recommended = recommendedAsync.valueOrNull ?? [];
    final storyLists = storyListsAsync.valueOrNull ?? [];
    final hubStats = hubStatsAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               // --- Header ---
               Padding(
                 padding: const EdgeInsets.all(20),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           'VOCABULARY',
                           style: GoogleFonts.nunito(
                             fontSize: 28,
                             fontWeight: FontWeight.w900,
                             color: AppColors.secondary,
                             letterSpacing: 1.2,
                           ),
                         ),
                         Text(
                           'Master new words',
                           style: GoogleFonts.nunito(
                             fontSize: 16,
                             fontWeight: FontWeight.bold,
                             color: AppColors.neutralText,
                           ),
                         ),
                       ],
                     ),
                     Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.neutral, width: 2),
                          boxShadow: [BoxShadow(color: AppColors.neutral, offset: Offset(0, 3))],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              '${hubStats?.masteredWords ?? 0}',
                              style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                          ],
                        ),
                     ),
                   ],
                 ),
               ),

              // Daily Review Section (always first and prominent)
              const _DailyReviewSection(),

              // Continue Learning section
              if (continueLeaning.isNotEmpty) ...[
                const _SectionHeader(
                  title: 'Continue Learning',
                  icon: Icons.play_circle_fill,
                  color: AppColors.primary,
                ),
                _HorizontalListSection(lists: continueLeaning),
              ],

              // Recommended section
              if (recommended.isNotEmpty) ...[
                const _SectionHeader(
                  title: 'Recommended for You',
                  icon: Icons.star_rounded,
                  color: Colors.amber,
                ),
                _HorizontalListSection(lists: recommended),
              ],

              // My Word Lists (story vocabulary)
              if (storyLists.isNotEmpty) ...[
                const _SectionHeader(
                  title: 'My Word Lists',
                  icon: Icons.bookmark_rounded,
                   color: AppColors.secondary,
                ),
                _VerticalListSection(lists: storyLists, ref: ref),
              ],

              // Explore Categories
              _SectionHeader(
                title: 'Explore Categories',
                icon: Icons.category_rounded,
                color: AppColors.gemBlue,
              ),
              const _CategoriesGrid(),

              // Empty state if nothing to show
              if (continueLeaning.isEmpty && recommended.isEmpty && storyLists.isEmpty)
                _EmptyState(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Daily Review Section with 3 states: completed, no words, ready
class _DailyReviewSection extends ConsumerWidget {
  const _DailyReviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySessionAsync = ref.watch(todayReviewSessionProvider);
    final dueWordsAsync = ref.watch(dailyReviewWordsProvider);

    final todaySession = todaySessionAsync.valueOrNull;
    final dueWords = dueWordsAsync.valueOrNull ?? [];

    // State 1: Already completed today
    if (todaySession != null) {
      return _CompletedReviewCard(session: todaySession);
    }

    // State 2: No words due
    if (dueWords.isEmpty) {
      return const _AllCaughtUpCard();
    }

    // State 3: Words ready for review
    return _ReadyToReviewCard(wordCount: dueWords.length);
  }
}

/// Card showing completed review session
class _CompletedReviewCard extends StatelessWidget {
  const _CompletedReviewCard({required this.session});

  final dynamic session; // DailyReviewSession

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryShadow,
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Review Complete!",
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                Text(
                  '+${session.xpEarned} XP earned',
                  style: GoogleFonts.nunito(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card showing no words due
class _AllCaughtUpCard extends StatelessWidget {
  const _AllCaughtUpCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neutral, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral,
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gemBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              color: AppColors.gemBlue,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Caught Up!',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppColors.black,
                  ),
                ),
                Text(
                  'No words due for review.',
                  style: GoogleFonts.nunito(
                    color: AppColors.neutralText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card showing words ready for review
class _ReadyToReviewCard extends StatelessWidget {
  const _ReadyToReviewCard({required this.wordCount});

  final int wordCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/vocabulary/daily-review'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.streakOrange,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
             BoxShadow(color: Color(0xFFC76A00), offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Review',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    '$wordCount words ready!',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow_rounded, color: AppColors.streakOrange, size: 24),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section header with icon and title
class _SectionHeader extends StatelessWidget {

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });
  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal scrolling list of word list cards
class _HorizontalListSection extends StatelessWidget {

  const _HorizontalListSection({required this.lists});
  final List<WordListWithProgress> lists;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: lists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          return _WordListCard(listWithProgress: lists[index]);
        },
      ),
    );
  }
}

/// Vertical list of word list items
class _VerticalListSection extends StatelessWidget {

  const _VerticalListSection({required this.lists, required this.ref});
  final List<WordList> lists;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: lists.map((list) {
          final progressAsync = ref.watch(progressForListProvider(list.id));
          return _WordListTile(
            wordList: list,
            progress: progressAsync.valueOrNull,
          );
        }).toList(),
      ),
    );
  }
}

/// Card widget for a word list (used in horizontal scroll)
class _WordListCard extends StatelessWidget {

  const _WordListCard({required this.listWithProgress});
  final WordListWithProgress listWithProgress;

  @override
  Widget build(BuildContext context) {
    final list = listWithProgress.wordList;
    final progress = listWithProgress.progress;

    return GestureDetector(
      onTap: () {
        context.push('/vocabulary/list/${list.id}');
      },
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
           borderRadius: BorderRadius.circular(20),
           border: Border.all(color: AppColors.neutral, width: 2),
           boxShadow: [
              BoxShadow(
                 color: AppColors.neutral,
                 offset: const Offset(0, 4),
                 blurRadius: 0,
              ),
           ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: VocabularyColors.getCategoryColor(list.category).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                list.category.icon,
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Expanded(
              child: Text(
                list.name,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.black,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // Progress bar
            if (progress != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.progressPercentage,
                  minHeight: 8,
                  backgroundColor: AppColors.neutral,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    VocabularyColors.getCategoryColor(list.category),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(progress.progressPercentage * 100).toInt()}%',
                style: GoogleFonts.nunito(
                  color: AppColors.neutralText,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ] else
              Text(
                'Not started',
                style: GoogleFonts.nunito(
                  color: AppColors.neutralText,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

}

/// Tile widget for word list (used in vertical list)
class _WordListTile extends StatelessWidget {

  const _WordListTile({
    required this.wordList,
    this.progress,
  });
  final WordList wordList;
  final UserWordListProgress? progress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/vocabulary/list/${wordList.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
           color: AppColors.white,
           borderRadius: BorderRadius.circular(16),
           border: Border.all(color: AppColors.neutral, width: 2),
           boxShadow: [BoxShadow(color: AppColors.neutral, offset: Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
               width: 50,
               height: 50,
               alignment: Alignment.center,
               decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
               ),
               child: Text(wordList.category.icon, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                     wordList.name,
                     style: GoogleFonts.nunito(
                       fontWeight: FontWeight.bold,
                       fontSize: 16,
                     ),
                   ),
                   Text(
                     '${wordList.wordCount} words',
                     style: GoogleFonts.nunito(
                       color: AppColors.neutralText,
                       fontWeight: FontWeight.bold,
                       fontSize: 12,
                     ),
                   ),
                ],
              ),
            ),
            if (progress != null)
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                   alignment: Alignment.center,
                   children: [
                      CircularProgressIndicator(
                         value: progress!.progressPercentage,
                         color: AppColors.primary,
                         backgroundColor: AppColors.neutral,
                         strokeWidth: 5,
                      ),
                      if (progress!.isFullyComplete)
                         Icon(Icons.check, size: 16, color: AppColors.primary),
                   ],
                ),
              )
            else
               Icon(Icons.chevron_right_rounded, color: AppColors.neutralText),
          ],
        ),
      ),
    );
  }
}

/// Horizontal scrolling category cards (same size as word list cards)
class _CategoriesGrid extends ConsumerWidget {
  const _CategoriesGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = [
      WordListCategory.commonWords,
      WordListCategory.gradeLevel,
      WordListCategory.testPrep,
      WordListCategory.thematic,
    ];

    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final category = categories[index];
          final listsAsync = ref.watch(wordListsByCategoryProvider(category));
          return _CategoryCard(
            category: category,
            listCount: listsAsync.valueOrNull?.length ?? 0,
          );
        },
      ),
    );
  }
}

/// Card for a category (fixed width like word list cards)
class _CategoryCard extends StatelessWidget {

  const _CategoryCard({
    required this.category,
    required this.listCount,
  });
  final WordListCategory category;
  final int listCount;

  @override
  Widget build(BuildContext context) {
    final color = VocabularyColors.getCategoryColor(category);

    return GestureDetector(
      onTap: () {
        context.push('/vocabulary/category/${category.name}');
      },
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
             BoxShadow(
                color: color.withValues(alpha: 0.6), // Darker shadow
                offset: const Offset(0, 4),
             ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                category.icon,
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const Spacer(),
            Text(
              category.displayName,
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '$listCount lists',
              style: GoogleFonts.nunito(
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

}

/// Empty state when no lists available
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
           Icon(Icons.library_books_rounded, size: 80, color: AppColors.neutral),
           const SizedBox(height: 16),
           Text(
             'No word lists yet',
             style: GoogleFonts.nunito(
               fontSize: 20,
               fontWeight: FontWeight.w800,
               color: AppColors.neutralText,
             ),
           ),
           const SizedBox(height: 8),
           Text(
             'Start reading stories to build your vocabulary!',
             style: GoogleFonts.nunito(
               color: AppColors.neutralText,
               fontWeight: FontWeight.w600,
             ),
             textAlign: TextAlign.center,
           ),
        ],
      ),
    );
  }
}
