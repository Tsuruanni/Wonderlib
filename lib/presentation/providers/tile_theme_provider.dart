import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/usecase.dart';
import '../../domain/entities/tile_theme.dart';
import 'usecase_providers.dart';

/// Fetches active tile themes from DB.
/// Falls back to empty list on failure (orchestrator uses hardcoded fallback).
final tileThemesProvider = FutureProvider<List<TileThemeEntity>>((ref) async {
  final useCase = ref.watch(getTileThemesUseCaseProvider);
  final result = await useCase(const NoParams());
  return result.fold((_) => [], (themes) => themes);
});
