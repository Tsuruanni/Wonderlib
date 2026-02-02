import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/system_settings.dart';
import '../../domain/usecases/usecase.dart';
import 'usecase_providers.dart';

/// System settings fetched from database
/// Falls back to defaults if fetch fails
final systemSettingsProvider = FutureProvider<SystemSettings>((ref) async {
  final useCase = ref.watch(getSystemSettingsUseCaseProvider);
  final result = await useCase(const NoParams());

  return result.fold(
    (failure) {
      debugPrint('Failed to load system settings: ${failure.message}');
      return SystemSettings.defaults();
    },
    (settings) => settings,
  );
});

/// Convenience getter for sync access with defaults
/// Usage: ref.watch(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults()
