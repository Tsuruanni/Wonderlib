import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/learning_path.dart';
import '../../providers/daily_review_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/common/top_navbar.dart';
import 'unit_map_screen.dart';

/// Vocabulary hub — entry point for learning paths.
/// 1 path: shows unit map directly.
/// 2+ paths: shows path selection cards.
class VocabularyHubScreen extends ConsumerWidget {
  const VocabularyHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathsAsync = ref.watch(userLearningPathsProvider);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final showRightPanel = screenWidth >= 1000;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const TopNavbar(),
            // Daily review banner — only on mobile (on wide screens it's in the RightInfoPanel)
            if (!showRightPanel) ...[
              const _DailyReviewBanner(),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: pathsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Could not load learning paths',
                    style: GoogleFonts.nunito(color: AppColors.neutralText),
                  ),
                ),
                data: (paths) {
                  if (paths.isEmpty) {
                    return _EmptyState();
                  }
                  if (paths.length == 1) {
                    // Single path — show unit map directly
                    return UnitMapScreen(pathId: paths.first.id);
                  }
                  // Multiple paths — show selection
                  return _PathSelectionList(paths: paths);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PathSelectionList extends ConsumerWidget {
  const _PathSelectionList({required this.paths});
  final List<LearningPath> paths;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allUnits = ref.watch(learningPathProvider).valueOrNull ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 4),
            child: Text(
              'Learning Paths',
              style: GoogleFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
          ),
          for (final path in paths)
            _PathCard(
              path: path,
              allUnits: allUnits,
              onTap: () => context.push(
                AppRoutes.vocabularyPathUnits(path.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.path,
    required this.allUnits,
    required this.onTap,
  });

  final LearningPath path;
  final List<PathUnitData> allUnits;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pathUnits =
        allUnits.where((pu) => pu.pathId == path.id).toList();
    final totalUnits = pathUnits.length;
    final completedUnits = pathUnits.where((u) => u.isAllComplete).length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.neutral, width: 2),
          boxShadow: const [
            BoxShadow(
              color: AppColors.neutral,
              offset: Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.route_rounded, color: AppColors.secondary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    path.name,
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$completedUnits / $totalUnits units completed',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutralText,
                    ),
                  ),
                  if (totalUnits > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: completedUnits / totalUnits,
                        backgroundColor: AppColors.neutral,
                        color: AppColors.primary,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.neutralText,
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyReviewBanner extends ConsumerWidget {
  const _DailyReviewBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySession = ref.watch(todayReviewSessionProvider).valueOrNull;
    final dueWords = ref.watch(dailyReviewWordsProvider).valueOrNull ?? [];

    // Already completed today
    if (todaySession != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: AppColors.primaryShadow,
                offset: Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review Complete!',
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '+${todaySession.xpEarned} XP earned',
                      style: GoogleFonts.nunito(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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

    // Enough words to start a review
    if (dueWords.length >= minDailyReviewCount) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: GestureDetector(
          onTap: () => context.push(AppRoutes.vocabularyDailyReview),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.streakOrange,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0xFFC76A00), offset: Offset(0, 3)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Review',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${dueWords.length} words ready!',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: AppColors.streakOrange, size: 20),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Not enough words — hide
    return const SizedBox.shrink();
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.route_rounded,
              size: 48,
              color: AppColors.neutralText.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No learning path yet',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.neutralText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your teacher will assign one soon!',
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: AppColors.neutralText.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
