import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/content/content_block.dart';
import '../../domain/usecases/content/check_chapter_uses_content_blocks_usecase.dart';
import '../../domain/usecases/content/get_content_blocks_usecase.dart';
import 'usecase_providers.dart';

/// Provider for loading content blocks for a chapter.
/// Returns `AsyncValue<List<ContentBlock>>` - handles loading, error, and data states.
final contentBlocksProvider =
    FutureProvider.family<List<ContentBlock>, String>((ref, chapterId) async {
  final useCase = ref.watch(getContentBlocksUseCaseProvider);
  final result = await useCase(GetContentBlocksParams(chapterId: chapterId));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (blocks) => blocks,
  );
});

/// Provider for checking if a chapter uses content blocks
/// Some chapters may still use legacy plain text content
final chapterUsesContentBlocksProvider =
    FutureProvider.family<bool, String>((ref, chapterId) async {
  final useCase = ref.watch(checkChapterUsesContentBlocksUseCaseProvider);
  final result = await useCase(CheckChapterUsesContentBlocksParams(chapterId: chapterId));

  return result.fold(
    (failure) => false, // Default to false on error
    (usesBlocks) => usesBlocks,
  );
});

/// Provider for getting text blocks only (filtered)
final textBlocksProvider =
    Provider.family<AsyncValue<List<ContentBlock>>, String>((ref, chapterId) {
  final blocks = ref.watch(contentBlocksProvider(chapterId));

  return blocks.whenData(
    (list) => list.where((b) => b.isTextBlock).toList(),
  );
});

/// Provider for getting blocks with audio (for audio player display)
final audioBlocksProvider =
    Provider.family<AsyncValue<List<ContentBlock>>, String>((ref, chapterId) {
  final blocks = ref.watch(contentBlocksProvider(chapterId));

  return blocks.whenData(
    (list) => list.where((b) => b.hasAudio).toList(),
  );
});

/// Provider for getting activity blocks only
final activityBlocksProvider =
    Provider.family<AsyncValue<List<ContentBlock>>, String>((ref, chapterId) {
  final blocks = ref.watch(contentBlocksProvider(chapterId));

  return blocks.whenData(
    (list) => list.where((b) => b.isActivityBlock).toList(),
  );
});

/// Check if any block in the chapter has audio
final chapterHasAudioProvider = Provider.family<bool, String>((ref, chapterId) {
  final blocks = ref.watch(contentBlocksProvider(chapterId));

  return blocks.maybeWhen(
    data: (list) => list.any((b) => b.hasAudio),
    orElse: () => false,
  );
});
