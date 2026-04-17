import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/monthly_quest.dart';
import '../../domain/usecases/monthly_quest/get_monthly_quest_progress_usecase.dart';
import 'auth_provider.dart';
import 'usecase_providers.dart';

final monthlyQuestProgressProvider =
    FutureProvider<List<MonthlyQuestProgress>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];

  final useCase = ref.watch(getMonthlyQuestProgressUseCaseProvider);
  final result = await useCase(GetMonthlyQuestProgressParams(userId: userId));
  return result.fold(
    (failure) {
      debugPrint('monthlyQuestProgressProvider error: ${failure.message}');
      return const [];
    },
    (progress) => progress,
  );
});
