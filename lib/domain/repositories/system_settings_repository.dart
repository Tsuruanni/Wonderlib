import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/system_settings.dart';

/// Repository interface for system settings operations
abstract class SystemSettingsRepository {
  /// Fetches all system settings from the database
  /// Returns [SystemSettings] entity on success, [Failure] on error
  Future<Either<Failure, SystemSettings>> getSettings();
}
