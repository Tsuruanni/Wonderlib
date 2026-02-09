import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/word_list.dart';
import '../../providers/daily_review_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/vocabulary/learning_path.dart';
import '../../widgets/common/top_navbar.dart';

import '../../widgets/common/terrain_background.dart';

/// Main vocabulary hub screen with word lists organized by sections
class VocabularyHubScreen extends ConsumerWidget {
  const VocabularyHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storyListsAsync = ref.watch(storyWordListsProvider);
    final storyLists = storyListsAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.terrain, // Fallback/Base color
      body: TerrainBackground(
        child: SafeArea(
          child: Column(
            children: [
              // --- Duolingo-style Navbar ---
              const TopNavbar(),

              // --- Scrollable Content ---
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Daily Review Section
                      const _DailyReviewHeader(),
                      const _DailyReviewSection(),

                      // Learning Path
                      const LearningPath(),

                      // My Word Lists
                      if (storyLists.isNotEmpty) ...[
                        const _SectionHeader(title: 'My Word Lists'),
                        _VerticalListSection(lists: storyLists, ref: ref),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Conditionally shows the "Daily Vocabulary Review" header only when the section is visible.
class _DailyReviewHeader extends ConsumerWidget {
  const _DailyReviewHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySession = ref.watch(todayReviewSessionProvider).valueOrNull;
    final dueWords = ref.watch(dailyReviewWordsProvider).valueOrNull ?? [];

    final shouldShow = todaySession != null || dueWords.length >= minDailyReviewCount;
    if (!shouldShow) return const SizedBox.shrink();

    return const _SectionHeader(title: 'Daily Vocabulary Review');
  }
}

/// Daily Review Section — only shows when completed or ready (>= 10 words).
/// "Building up" and "all caught up" states are handled by the profile screen.
class _DailyReviewSection extends ConsumerWidget {
  const _DailyReviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySessionAsync = ref.watch(todayReviewSessionProvider);
    final dueWordsAsync = ref.watch(dailyReviewWordsProvider);

    final todaySession = todaySessionAsync.valueOrNull;
    final dueWords = dueWordsAsync.valueOrNull ?? [];

    // Already completed today — show completed card
    if (todaySession != null) {
      return _CompletedReviewCard(session: todaySession);
    }

    // Enough words to start a review session
    if (dueWords.length >= minDailyReviewCount) {
      return _ReadyToReviewCard(wordCount: dueWords.length);
    }

    // Not enough words (or zero) — hide entirely; profile shows the status
    return const SizedBox.shrink();
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

/// Card showing words ready for review
class _ReadyToReviewCard extends StatelessWidget {
  const _ReadyToReviewCard({required this.wordCount});

  final int wordCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.vocabularyDailyReview),
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

/// Section header with centered text and gradient lines
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.neutral.withValues(alpha: 0),
                    AppColors.neutral,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.neutralText,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.neutral,
                    AppColors.neutral.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
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
      onTap: () => context.push(AppRoutes.vocabularyListPath(wordList.id)),
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
                      if (progress!.isComplete)
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


