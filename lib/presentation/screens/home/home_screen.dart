import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/book.dart';
import '../../providers/book_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common/pressable_scale.dart';
import '../../widgets/home/daily_goal_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. User & Stats
    final userAsync = ref.watch(userControllerProvider);
    final user = userAsync.valueOrNull;

    // 2. Data Providers
    final continueReadingAsync = ref.watch(continueReadingProvider);
    final recommendedBooksAsync = ref.watch(recommendedBooksProvider);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // --- Top Navbar (fixed) ---
          SafeArea(
            bottom: false,
            child: _buildHeader(context, user),
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

  Widget _buildHeader(BuildContext context, dynamic user) {
    final streak = user?.currentStreak ?? 0;
    final xp = user?.xp ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.primary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: UK Flag (outlined icon style)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 16, color: const Color(0xFF012169)), // Blue
                Container(width: 8, height: 16, color: Colors.white), // White
                Container(width: 8, height: 16, color: const Color(0xFFC8102E)), // Red
              ],
            ),
          ),

          // Divider
          _buildNavDivider(),

          // Streak
          _buildNavStat(
            icon: Icons.local_fire_department,
            value: streak,
            iconColor: AppColors.streakOrange,
          ),

          // Divider
          _buildNavDivider(),

          // XP (coins)
          _buildNavStat(
            icon: Icons.monetization_on,
            value: xp,
            iconColor: AppColors.wasp,
          ),

          // Divider
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
            // White outline effect
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

