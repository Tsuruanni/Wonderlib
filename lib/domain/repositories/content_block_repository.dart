import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/content/content_block.dart';

abstract class ContentBlockRepository {
  /// Get all content blocks for a chapter, ordered by orderIndex
  Future<Either<Failure, List<ContentBlock>>> getContentBlocks(String chapterId);

  /// Check if a chapter uses content blocks or legacy content field
  Future<Either<Failure, bool>> chapterUsesContentBlocks(String chapterId);
}
