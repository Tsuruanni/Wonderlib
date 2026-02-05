import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/student_assignment.dart';
import '../../../domain/entities/book.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_provider.dart'; // Fixed import
import '../../providers/daily_review_provider.dart';
import '../../providers/student_assignment_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common/game_button.dart';
import '../../widgets/common/pro_progress_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. User & Stats
    final userAsync = ref.watch(userControllerProvider);
    final user = userAsync.valueOrNull;

    // 2. Data Providers
    final activeAssignmentsAsync = ref.watch(activeAssignmentsProvider);
    final continueReadingAsync = ref.watch(continueReadingProvider);
    final recommendedBooksAsync = ref.watch(recommendedBooksProvider);
    
    // 3. Daily Stats (Mock or Provider if available, reverting to simple 0 for now as per error logs)
    // Note: If you have providers for these, uncomment them. For now, we mock to ensure compilation.
    final correctAnswers = 0; 
    final wordsRead = 0;

    return Scaffold(
      backgroundColor: AppColors.background, // Light grey background
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header Section ---
              _buildHeader(context, user),
              const SizedBox(height: 32),

              // --- Daily Progress Section ---
              _buildDailyProgress(context, wordsRead, correctAnswers),
              const SizedBox(height: 32),

              // --- Continue Reading Section ---
              _buildSectionHeader(context, 'Continue Reading', Icons.book_rounded),
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

              // --- Assignments Section ---
              _buildSectionHeader(context, 'Assignments', Icons.assignment_rounded),
              const SizedBox(height: 16),
              activeAssignmentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Could not load assignments'),
                data: (assignments) {
                  if (assignments.isEmpty) {
                    return _buildEmptyState(context, 'No active assignments! 🎉', Icons.check_circle_outline);
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: assignments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _AssignmentCard(assignment: assignments[index]);
                    },
                  );
                },
              ),
              
              const SizedBox(height: 32),

               // --- Recommended Section ---
              _buildSectionHeader(context, 'Recommended for You', Icons.star_rounded),
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
    );
  }

  Widget _buildHeader(BuildContext context, dynamic user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back,',
              style: GoogleFonts.nunito(
                fontSize: 16,
                color: AppColors.neutralText,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              user?.firstName ?? 'Student',
              style: GoogleFonts.nunito(
                fontSize: 28,
                color: AppColors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.neutral, width: 2),
            color: AppColors.white,
          ),
          child: CircleAvatar(
             radius: 24,
             backgroundColor: AppColors.primary.withValues(alpha: 0.2),
             child: Text(
               user?.initials ?? '?',
               style: GoogleFonts.nunito(
                 fontWeight: FontWeight.w800,
                 color: AppColors.primary,
               ),
             ),
          ),
        ),
      ],
    ).animate().fadeIn().moveY(begin: -10, end: 0);
  }

  Widget _buildDailyProgress(BuildContext context, int words, int answers) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        children: [
          Row(
            children: [
              const Icon(Icons.flash_on_rounded, color: AppColors.streakOrange, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Goal',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),
                  Text(
                    'Keep your streak alive!',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: AppColors.neutralText,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Mock progress for now
          ProProgressBar(progress: 0.6, height: 20, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.secondary, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
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
    return GestureDetector(
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

class _AssignmentCard extends StatelessWidget {
  final StudentAssignment assignment;
  const _AssignmentCard({required this.assignment});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('${AppRoutes.studentAssignments}/${assignment.assignmentId}'),
      child: Container(
         padding: const EdgeInsets.all(16),
         decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.neutral, width: 2),
             boxShadow: [
                BoxShadow(color: AppColors.neutral, offset: Offset(0, 3))
             ]
         ),
         child: Row(
           children: [
              Container(
                 padding: EdgeInsets.all(12),
                 decoration: BoxDecoration(
                    color: AppColors.gemBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                 ),
                 child: Icon(Icons.class_rounded, color: AppColors.gemBlue),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.title,
                      style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Due ${assignment.dueDate.toString().split(' ')[0]}',
                      style: GoogleFonts.nunito(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (assignment.status == StudentAssignmentStatus.completed)
                 Icon(Icons.check_circle, color: AppColors.primary)
              else 
                 Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.neutralText)
           ],
         ),
      ),
    );
  }
}
