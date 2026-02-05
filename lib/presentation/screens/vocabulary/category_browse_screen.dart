import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/utils/extensions/context_extensions.dart';
import '../../../domain/entities/word_list.dart';
import '../../providers/vocabulary_provider.dart';

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
                  final progressAsync = ref.watch(progressForListProvider(list.id));
                  return _WordListCard(
                    wordList: list,
                    progress: progressAsync.valueOrNull,
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
        context.push('/vocabulary/list/${wordList.id}');
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
                color: _getCategoryColor(wordList.category).withValues(alpha: 0.1),
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress!.progressPercentage,
                        minHeight: 8,
                        backgroundColor: AppColors.neutral,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getCategoryColor(wordList.category),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Status icon
            if (progress?.isFullyComplete ?? false)
               Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 28)
            else
               Icon(
                Icons.chevron_right_rounded,
                color: AppColors.neutralText,
                size: 28,
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
