import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/content/content_block.dart';

abstract class ContentBlockRepository {
  /// Get all content blocks for a chapter, ordered by orderIndex
  Future<Either<Failure, List<ContentBlock>>> getContentBlocks(String chapterId);

  /// Get a single content block by ID
  Future<Either<Failure, ContentBlock>> getContentBlockById(String blockId);

  /// Check if a chapter uses content blocks or legacy content field
  Future<Either<Failure, bool>> chapterUsesContentBlocks(String chapterId);
}
