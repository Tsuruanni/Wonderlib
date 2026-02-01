import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/content/content_block.dart';
import '../../../domain/repositories/content_block_repository.dart';
import '../../models/content/content_block_model.dart';

class SupabaseContentBlockRepository implements ContentBlockRepository {
  SupabaseContentBlockRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, List<ContentBlock>>> getContentBlocks(
    String chapterId,
  ) async {
    try {
      final response = await _supabase
          .from('content_blocks')
          .select()
          .eq('chapter_id', chapterId)
          .order('order_index', ascending: true);

      final blocks = (response as List)
          .map((json) => ContentBlockModel.fromJson(json).toEntity())
          .toList();

      return Right(blocks);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ContentBlock>> getContentBlockById(
    String blockId,
  ) async {
    try {
      final response = await _supabase
          .from('content_blocks')
          .select()
          .eq('id', blockId)
          .single();

      return Right(ContentBlockModel.fromJson(response).toEntity());
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return const Left(NotFoundFailure('Content block not found'));
      }
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> chapterUsesContentBlocks(
    String chapterId,
  ) async {
    try {
      final response = await _supabase
          .from('chapters')
          .select('use_content_blocks')
          .eq('id', chapterId)
          .single();

      final usesContentBlocks =
          response['use_content_blocks'] as bool? ?? false;

      return Right(usesContentBlocks);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return const Left(NotFoundFailure('Chapter not found'));
      }
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
