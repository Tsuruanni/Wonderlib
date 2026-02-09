import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/book.dart';
import '../../providers/book_provider.dart';
import '../../providers/daily_review_provider.dart';
import '../../widgets/common/pressable_scale.dart';
import '../../widgets/common/top_navbar.dart';
import '../../widgets/home/daily_goal_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. User & Stats
    // Data Providers
    final continueReadingAsync = ref.watch(continueReadingProvider);
    final recommendedBooksAsync = ref.watch(recommendedBooksProvider);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // --- Top Navbar (fixed) ---
          SafeArea(
            bottom: false,

            child: const TopNavbar(),
          ),

          // --- Scrollable Content ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Daily Tasks Section ---
                  const DailyGoalWidget(),
                  const SizedBox(height: 16),

                  // --- Daily Vocabulary Review ---
                  const _DailyReviewSection(),
                  const SizedBox(height: 32),

              // --- Continue Reading Section ---
              _buildSectionHeader(context, 'Continue Reading'),
              const SizedBox(height: 16),
              continueReadingAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
                data: (books) {
                  if (books.isEmpty) {
                     return _buildEmptyState(context, 'No books in progress', Icons.auto_stories);
                  }
                  return SizedBox(
                    height: 220,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: books.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                         return _BookCard(book: books[index]);
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

               // --- Recommended Section ---
              _buildSectionHeader(context, 'Recommended for You'),
              const SizedBox(height: 16),
              recommendedBooksAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
                data: (books) {
                  if (books.isEmpty) return const Text('No recommendations yet.');
                  return SizedBox(
                    height: 220,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: books.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                         return _BookCard(book: books[index]);
                      },
                    ),
                  );
                },
              ),
                  const SizedBox(height: 80), // Bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
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
    );
  }
  
  Widget _buildEmptyState(BuildContext context, String message, IconData icon) {
     return Container(
       width: double.infinity,
       padding: const EdgeInsets.all(24),
       decoration: BoxDecoration(
         color: AppColors.white.withValues(alpha: 0.5),
         borderRadius: BorderRadius.circular(16),
         border: Border.all(color: AppColors.neutral.withValues(alpha: 0.5), width: 2),
       ),
       child: Column(
         children: [
           Icon(icon, color: AppColors.neutral, size: 40),
           const SizedBox(height: 8),
           Text(message, style: GoogleFonts.nunito(color: AppColors.neutralText, fontWeight: FontWeight.bold)),
         ],
       ),
     );
  }
}

/// Daily Review Section — only shows when completed or ready (>= 10 words).
class _DailyReviewSection extends ConsumerWidget {
  const _DailyReviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySession = ref.watch(todayReviewSessionProvider).valueOrNull;
    final dueWords = ref.watch(dailyReviewWordsProvider).valueOrNull ?? [];

    // Already completed today
    if (todaySession != null) {
      return _CompletedReviewCard(session: todaySession);
    }

    // Enough words to start a review session
    if (dueWords.length >= minDailyReviewCount) {
      return _ReadyToReviewCard(wordCount: dueWords.length);
    }

    // Not enough words — hide
    return const SizedBox.shrink();
  }
}

class _CompletedReviewCard extends StatelessWidget {
  const _CompletedReviewCard({required this.session});

  final dynamic session; // DailyReviewSession

  @override
  Widget build(BuildContext context) {
    return Container(
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
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review Complete!',
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

class _ReadyToReviewCard extends StatelessWidget {
  const _ReadyToReviewCard({required this.wordCount});

  final int wordCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.vocabularyDailyReview),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.streakOrange,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: const Color(0xFFC76A00), offset: const Offset(0, 4)),
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
              child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 32),
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
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: AppColors.streakOrange, size: 24),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final Book book;
  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => context.go('${AppRoutes.library}/book/${book.id}'),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neutral, width: 2),
          boxShadow: [
             BoxShadow(color: AppColors.neutral, offset: Offset(0, 4))
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Image.network(
                  book.coverUrl ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: AppColors.primary.withValues(alpha: 0.2), child: Icon(Icons.book, color: AppColors.primary)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    book.level,
                    style: GoogleFonts.nunito(color: AppColors.secondary, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

