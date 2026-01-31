import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/edge_function_service.dart';
import '../../data/repositories/supabase/supabase_activity_repository.dart';
import '../../data/repositories/supabase/supabase_auth_repository.dart';
import '../../data/repositories/supabase/supabase_badge_repository.dart';
import '../../data/repositories/supabase/supabase_book_repository.dart';
import '../../data/repositories/supabase/supabase_user_repository.dart';
import '../../data/repositories/supabase/supabase_vocabulary_repository.dart';
import '../../data/repositories/supabase/supabase_word_list_repository.dart';
import '../../domain/entities/activity.dart';
import '../../domain/repositories/activity_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/badge_repository.dart';
import '../../domain/repositories/book_repository.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/repositories/vocabulary_repository.dart';
import '../../domain/repositories/word_list_repository.dart';

/// Repository providers
/// All repositories now use Supabase implementations

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repository = SupabaseAuthRepository();
  ref.onDispose(() => repository.dispose());
  return repository;
});

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return SupabaseBookRepository();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return SupabaseUserRepository();
});

final vocabularyRepositoryProvider = Provider<VocabularyRepository>((ref) {
  return SupabaseVocabularyRepository();
});

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return SupabaseActivityRepository();
});

final badgeRepositoryProvider = Provider<BadgeRepository>((ref) {
  return SupabaseBadgeRepository();
});

final wordListRepositoryProvider = Provider<WordListRepository>((ref) {
  return SupabaseWordListRepository();
});

/// Inline activities provider (for reader screen)
final inlineActivitiesProvider =
    FutureProvider.family<List<InlineActivity>, String>((ref, chapterId) async {
  final bookRepo = ref.watch(bookRepositoryProvider);
  final result = await bookRepo.getInlineActivities(chapterId);
  return result.fold(
    (failure) => [],
    (activities) => activities,
  );
});

/// Edge Function service provider (for XP awards, streak updates)
final edgeFunctionServiceProvider = Provider<EdgeFunctionService>((ref) {
  return EdgeFunctionService();
});
