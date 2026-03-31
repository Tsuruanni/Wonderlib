import 'package:dartz/dartz.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/tile_theme.dart';
import '../../../domain/repositories/tile_theme_repository.dart';
import '../../models/tile_theme_model.dart';

class SupabaseTileThemeRepository implements TileThemeRepository {
  const SupabaseTileThemeRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Either<Failure, List<TileThemeEntity>>> getTileThemes() async {
    try {
      final response = await _client
          .from(DbTables.tileThemes)
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final rows = List<Map<String, dynamic>>.from(response);
      final themes = rows.map((r) => TileThemeModel.fromJson(r).toEntity()).toList();
      return Right(themes);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
