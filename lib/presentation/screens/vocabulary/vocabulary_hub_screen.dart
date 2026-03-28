import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/word_list.dart';
import '../../providers/vocabulary_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/vocabulary/learning_path.dart';
import '../../widgets/common/top_navbar.dart';

import '../../widgets/common/terrain_background.dart';

/// Main vocabulary hub screen with word lists organized by sections
class VocabularyHubScreen extends ConsumerStatefulWidget {
  const VocabularyHubScreen({super.key});

  @override
  ConsumerState<VocabularyHubScreen> createState() => _VocabularyHubScreenState();
}

class _VocabularyHubScreenState extends ConsumerState<VocabularyHubScreen> {
  ScrollController? _scrollController;

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storyListsAsync = ref.watch(storyWordListsProvider);

    // Create scroll controller once with initial offset centered on active node
    if (_scrollController == null) {
      final activeY = ref.read(activeNodeYProvider);
      final screenHeight = MediaQuery.of(context).size.height;
      final initialOffset = activeY != null
          ? (activeY - screenHeight / 2).clamp(0.0, double.maxFinite)
          : 0.0;
      _scrollController = ScrollController(initialScrollOffset: initialOffset);
    }

    return Scaffold(
      backgroundColor: AppColors.terrain,
      body: TerrainBackground(
        child: SafeArea(
          child: Column(
            children: [
              const TopNavbar(),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const LearningPath(),
                      ...storyListsAsync.when(
                        loading: () => [const SizedBox.shrink()],
                        error: (e, _) => [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Text('Failed to load word lists', style: TextStyle(color: Colors.red.shade300)),
                          ),
                        ],
                        data: (storyLists) => storyLists.isEmpty
                            ? []
                            : [
                                const _SectionHeader(title: 'My Word Lists'),
                                _VerticalListSection(lists: storyLists),
                              ],
                      ),
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
class _VerticalListSection extends ConsumerWidget {

  const _VerticalListSection({required this.lists});
  final List<WordList> lists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allProgress = ref.watch(userWordListProgressProvider).valueOrNull ?? [];
    final progressMap = {for (final p in allProgress) p.wordListId: p};

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: lists.map((list) {
          return _WordListTile(
            wordList: list,
            progress: progressMap[list.id],
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
                         value: (progress!.bestAccuracy ?? 0) / 100.0,
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


