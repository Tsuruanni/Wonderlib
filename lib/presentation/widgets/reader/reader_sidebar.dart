import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/services/audio_service.dart';
import '../../../domain/entities/chapter.dart';
import '../../providers/audio_sync_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/book_quiz_provider.dart';
import '../../providers/reader_provider.dart';
import '../../providers/content_block_provider.dart';
import '../common/game_button.dart';

/// Reader sidebar shown on wide screens (≥1000px) during reader routes.
/// Top: scrollable chapters list. Bottom: sticky audio player.
class ReaderSidebar extends ConsumerWidget {
  const ReaderSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final segments = location.split('/');
    final bookId = segments.length > 2 ? segments[2] : '';
    final currentChapterId = segments.length > 3 ? segments[3] : '';

    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          right: BorderSide(color: AppColors.neutral, width: 2),
        ),
      ),
      child: _ChaptersList(
        bookId: bookId,
        currentChapterId: currentChapterId,
      ),
    );
  }
}

// ─── Chapters List ───

class _ChaptersList extends ConsumerWidget {
  const _ChaptersList({
    required this.bookId,
    required this.currentChapterId,
  });

  final String bookId;
  final String currentChapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(chaptersProvider(bookId));

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chapters header
            Text(
              'Chapters',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 12),
            // Chapter list
            chaptersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (_, __) => Text(
                'Could not load chapters',
                style: GoogleFonts.nunito(color: AppColors.neutralText),
              ),
              data: (chapters) {
                final completedIds = ref.watch(
                  readingProgressProvider(bookId)
                      .select((v) => v.valueOrNull?.completedChapterIds ?? []),
                );
                final currentIdx =
                    chapters.indexWhere((c) => c.id == currentChapterId);
                final isQuizActive = ref.watch(quizActiveProvider);

                return Column(
                  children: [
                    for (int i = 0; i < chapters.length; i++) ...[
                      if (i > 0) const SizedBox(height: 4),
                      _ChapterTile(
                        chapter: chapters[i],
                        index: i,
                        isCurrent: chapters[i].id == currentChapterId,
                        isCompleted: completedIds.contains(chapters[i].id),
                        isLocked: isQuizActive ||
                            (!completedIds.contains(chapters[i].id) &&
                                i > currentIdx),
                        onTap: () => context.go(
                          AppRoutes.readerPath(bookId, chapters[i].id),
                        ),
                      ),
                    ],
                    // Book Quiz as last item in the list
                    const SizedBox(height: 4),
                    _BookQuizTile(
                      bookId: bookId,
                      chapterCount: chapters.length,
                    ),
                  ],
                );
              },
            ),
            // Audio player below chapters
            const SizedBox(height: 16),
            _SidebarAudioPlayer(currentChapterId: currentChapterId),
          ],
        ),
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.chapter,
    required this.index,
    required this.isCurrent,
    required this.isCompleted,
    required this.onTap,
    this.isLocked = false,
  });

  final Chapter chapter;
  final int index;
  final bool isCurrent;
  final bool isCompleted;
  final bool isLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: Opacity(
        opacity: isLocked ? 0.4 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isCurrent
                ? AppColors.secondary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isCurrent
                ? Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.3),
                    width: 2,
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.secondary
                      : isCompleted
                          ? AppColors.primary
                          : AppColors.neutral.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted && !isCurrent
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 14)
                      : Text(
                          '${index + 1}',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isCurrent || isCompleted
                                ? Colors.white
                                : AppColors.neutralText,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  chapter.title,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    color: isCurrent ? AppColors.secondary : AppColors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sidebar Audio Player (Sticky Bottom) ───

class _SidebarAudioPlayer extends ConsumerWidget {
  const _SidebarAudioPlayer({required this.currentChapterId});

  final String currentChapterId;

  void _startListening(WidgetRef ref) {
    final blocks = ref.read(contentBlocksProvider(currentChapterId)).valueOrNull;
    if (blocks == null) return;
    final firstAudio = blocks.where((b) => b.hasAudio).firstOrNull;
    if (firstAudio == null) return;
    final controller = ref.read(audioSyncControllerProvider.notifier);
    controller.loadBlock(firstAudio).then((_) => controller.play());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioReady = ref.watch(audioServiceProvider).hasValue;
    if (!audioReady) return const SizedBox.shrink();

    // Check if chapter has audio at all
    final hasAudio = ref.watch(chapterHasAudioProvider(currentChapterId));
    if (!hasAudio) return const SizedBox.shrink();

    final AudioSyncState audioState;
    try {
      audioState = ref.watch(audioSyncControllerProvider);
    } catch (_) {
      return const SizedBox.shrink();
    }

    // Show "Click to listen" when no audio loaded
    if (audioState.currentBlockId == null) {
      return _ClickToListenButton(onTap: () => _startListening(ref));
    }

    final isPlaying = audioState.isPlaying;
    final progress = audioState.progress;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/pause + progress
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  final controller =
                      ref.read(audioSyncControllerProvider.notifier);
                  if (isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.neutral,
                        color: AppColors.secondary,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          audioState.positionFormatted,
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.neutralText,
                          ),
                        ),
                        Text(
                          audioState.durationFormatted,
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.neutralText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Speed + close row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  ref.read(audioSyncControllerProvider.notifier).cycleSpeed();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.neutral, width: 2),
                  ),
                  child: Text(
                    '${audioState.playbackSpeed}x',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  ref.read(audioSyncControllerProvider.notifier).stop();
                },
                child: const Icon(
                  Icons.close_rounded,
                  color: AppColors.neutralText,
                  size: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Book Quiz Tile ───

class _BookQuizTile extends ConsumerWidget {
  const _BookQuizTile({required this.bookId, required this.chapterCount});

  final String bookId;
  final int chapterCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasQuiz = ref.watch(bookHasQuizProvider(bookId)).valueOrNull ?? false;
    if (!hasQuiz) return const SizedBox.shrink();

    final progressAsync = ref.watch(readingProgressProvider(bookId));
    final allChaptersRead =
        progressAsync.valueOrNull?.completionPercentage == 100;
    final bestResult = ref.watch(bestQuizResultProvider(bookId)).valueOrNull;
    final isPassed = bestResult?.isPassing ?? false;
    final location = GoRouterState.of(context).uri.path;
    final isCurrent = location.startsWith('/quiz');
    final isLocked = !allChaptersRead;

    // Same style as _ChapterTile
    return GestureDetector(
      onTap: isLocked ? null : () => context.go(AppRoutes.bookQuizPath(bookId)),
      child: Opacity(
        opacity: isLocked ? 0.4 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isCurrent
                ? AppColors.secondary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isCurrent
                ? Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.3),
                    width: 2,
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.secondary
                      : isPassed
                          ? AppColors.primary
                          : AppColors.neutral.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isPassed && !isCurrent
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 14)
                      : Icon(
                          Icons.quiz_rounded,
                          size: 13,
                          color: isCurrent || isPassed
                              ? Colors.white
                              : AppColors.neutralText,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Book Quiz',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    color: isCurrent ? AppColors.secondary : AppColors.black,
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

class _ClickToListenButton extends StatelessWidget {
  const _ClickToListenButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GameButton(
      label: 'Listen to the story',
      onPressed: onTap,
      variant: GameButtonVariant.secondary,
      fullWidth: true,
      icon: const Icon(Icons.headphones_rounded),
    );
  }
}
