import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/system_settings.dart';
import '../../../domain/repositories/system_settings_repository.dart';
import '../../models/settings/system_settings_model.dart';

/// Supabase implementation of [SystemSettingsRepository]
class SupabaseSystemSettingsRepository implements SystemSettingsRepository {
  final SupabaseClient _client;

  const SupabaseSystemSettingsRepository(this._client);

  @override
  Future<Either<Failure, SystemSettings>> getSettings() async {
    try {
      final response = await _client
          .from('system_settings')
          .select('key, value');

      final rows = List<Map<String, dynamic>>.from(response);

      if (rows.isEmpty) {
        // Return defaults if no settings in database
        return Right(SystemSettingsModel.defaults().toEntity());
      }

      final model = SystemSettingsModel.fromRows(rows);
      return Right(model.toEntity());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
