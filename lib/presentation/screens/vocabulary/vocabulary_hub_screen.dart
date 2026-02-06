import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/word_list.dart';
import '../../providers/daily_review_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/vocabulary/learning_path.dart';

/// Main vocabulary hub screen with word lists organized by sections
class VocabularyHubScreen extends ConsumerWidget {
  const VocabularyHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userControllerProvider);
    final user = userAsync.valueOrNull;
    final storyListsAsync = ref.watch(storyWordListsProvider);
    final storyLists = storyListsAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // --- Top Navbar (fixed) ---
          SafeArea(
            bottom: false,
            child: _buildNavbar(context, user),
          ),

          // --- Scrollable Content ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Daily Review Section
                  const _SectionHeader(title: 'Daily Vocabulary Review'),
                  const _DailyReviewSection(),

                  // Daily limit indicator
                  const _DailyLimitIndicator(),

                  // Learning Path (Duolingo-style vertical path)
                  const LearningPath(),

                  // My Word Lists (story vocabulary)
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
    );
  }

  Widget _buildNavbar(BuildContext context, dynamic user) {
    final streak = user?.currentStreak ?? 0;
    final xp = user?.xp ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.primary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: UK Flag
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 16, color: const Color(0xFF012169)),
                Container(width: 8, height: 16, color: Colors.white),
                Container(width: 8, height: 16, color: const Color(0xFFC8102E)),
              ],
            ),
          ),

          _buildNavDivider(),

          // Streak
          _buildNavStat(
            icon: Icons.local_fire_department,
            value: streak,
            iconColor: AppColors.streakOrange,
          ),

          _buildNavDivider(),

          // XP (coins)
          _buildNavStat(
            icon: Icons.monetization_on,
            value: xp,
            iconColor: AppColors.wasp,
          ),

          _buildNavDivider(),

          // Right: Profile Button
          GestureDetector(
            onTap: () => context.push(AppRoutes.profile),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      user?.initials ?? '?',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        height: 24,
        width: 2,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _buildNavStat({
    required IconData icon,
    required int value,
    required Color iconColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.3), size: 28),
            Icon(icon, color: iconColor, size: 24),
          ],
        ),
        const SizedBox(width: 4),
        Text(
          value.toString(),
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Daily Review Section with 4 states: completed, no words, building up, ready
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

    // State 3: Not enough words yet (building up)
    if (dueWords.length < minDailyReviewCount) {
      return _BuildingUpCard(currentCount: dueWords.length);
    }

    // State 4: Words ready for review
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

/// Card showing words building up (below minimum threshold)
class _BuildingUpCard extends StatelessWidget {
  const _BuildingUpCard({required this.currentCount});

  final int currentCount;

  @override
  Widget build(BuildContext context) {
    final progress = currentCount / minDailyReviewCount;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gemBlue.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.gemBlue.withValues(alpha: 0.15),
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
              Icons.hourglass_top_rounded,
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
                  'Words Building Up',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$currentCount/$minDailyReviewCount words — keep learning to unlock review!',
                  style: GoogleFonts.nunito(
                    color: AppColors.neutralText,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.gemBlue.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.gemBlue),
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

/// Small indicator showing daily word learning allowance
class _DailyLimitIndicator extends ConsumerWidget {
  const _DailyLimitIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remainingAsync = ref.watch(remainingDailyWordAllowanceProvider);
    final remaining = remainingAsync.valueOrNull;

    // Don't show if loading or full allowance remaining
    if (remaining == null || remaining >= dailyWordListLimit) return const SizedBox.shrink();

    final used = dailyWordListLimit - remaining;
    final isExhausted = remaining <= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(
            isExhausted ? Icons.lock_rounded : Icons.bolt_rounded,
            size: 14,
            color: isExhausted ? AppColors.neutralText : AppColors.streakOrange,
          ),
          const SizedBox(width: 4),
          Text(
            isExhausted
                ? 'Daily limit reached ($used/$dailyWordListLimit words)'
                : '$used/$dailyWordListLimit new words today',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isExhausted ? AppColors.neutralText : AppColors.streakOrange,
            ),
          ),
        ],
      ),
    );
  }
}

