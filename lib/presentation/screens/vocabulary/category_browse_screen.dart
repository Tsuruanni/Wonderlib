import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/word_list.dart';
import '../../providers/vocabulary_provider.dart';
import '../../utils/app_icons.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/common/app_progress_bar.dart';

/// Screen to browse word lists in a specific category
class CategoryBrowseScreen extends ConsumerWidget {

  const CategoryBrowseScreen({super.key, required this.categoryName});
  final String categoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = _parseCategory(categoryName);

    if (category == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: AppColors.black)),
        body: Center(child: Text('Category not found', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.bold))),
      );
    }

    final listsAsync = ref.watch(wordListsByCategoryProvider(category));
    final allProgress = ref.watch(userWordListProgressProvider).valueOrNull ?? [];
    final progressMap = {for (final p in allProgress) p.wordListId: p};

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
           category.displayName,
           style: GoogleFonts.nunito(fontWeight: FontWeight.w900, color: AppColors.black),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.black),
      ),
      body: listsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (lists) => lists.isEmpty
            ? _EmptyState(category: category)
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: lists.length,
                itemBuilder: (context, index) {
                  final list = lists[index];
                  return _WordListCard(
                    wordList: list,
                    progress: progressMap[list.id],
                  );
                },
              ),
      ),
    );
  }

  WordListCategory? _parseCategory(String name) {
    try {
      return WordListCategory.values.firstWhere(
        (c) => c.name == name,
      );
    } catch (_) {
      return null;
    }
  }
}

class _WordListCard extends StatelessWidget {

  const _WordListCard({
    required this.wordList,
    this.progress,
  });
  final WordList wordList;
  final UserWordListProgress? progress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push(AppRoutes.vocabularyListPath(wordList.id));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
              )
           ]
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: VocabularyColors.getCategoryColor(wordList.category).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  wordList.category.icon,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Title and info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wordList.name,
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${wordList.wordCount} words${wordList.level != null ? ' • ${wordList.level}' : ''}',
                    style: GoogleFonts.nunito(
                      color: AppColors.neutralText,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: 8),
                    AppProgressBar(
                      progress: (progress!.bestAccuracy ?? 0) / 100.0,
                      fillColor: VocabularyColors.getCategoryColor(wordList.category),
                      fillShadow: VocabularyColors.getCategoryColor(wordList.category).withValues(alpha: 0.6),
                      backgroundColor: AppColors.neutral,
                      height: 8,
                    ),
                  ],
                ],
              ),
            ),

            // Status icon
            if (progress?.isComplete ?? false)
               AppIcons.check(size: 28)
            else
               AppIcons.arrowRight(size: 28),
          ],
        ),
      ),
    );
  }

}

class _EmptyState extends StatelessWidget {

  const _EmptyState({required this.category});
  final WordListCategory category;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: AppColors.neutral, width: 2),
              ),
              child: Text(
                category.icon,
                style: const TextStyle(fontSize: 80),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No lists in ${category.displayName}',
              style: GoogleFonts.nunito(
                 fontSize: 20,
                 fontWeight: FontWeight.w900,
                 color: AppColors.neutralText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Check back later for new word lists!',
              style: GoogleFonts.nunito(
                color: AppColors.neutralText,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
