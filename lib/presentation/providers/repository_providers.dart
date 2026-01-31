import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/mock/mock_activity_repository.dart';
import '../../data/repositories/mock/mock_badge_repository.dart';
import '../../data/repositories/mock/mock_user_repository.dart';
import '../../data/repositories/mock/mock_vocabulary_repository.dart';
import '../../data/repositories/mock/mock_word_list_repository.dart';
import '../../data/repositories/supabase/supabase_auth_repository.dart';
import '../../data/repositories/supabase/supabase_book_repository.dart';
import '../../domain/repositories/activity_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/badge_repository.dart';
import '../../domain/repositories/book_repository.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/repositories/vocabulary_repository.dart';
import '../../domain/repositories/word_list_repository.dart';

/// Repository providers
/// Auth and Book now use Supabase, others still use Mock

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository();
});

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return SupabaseBookRepository();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return MockUserRepository();
});

final vocabularyRepositoryProvider = Provider<VocabularyRepository>((ref) {
  return MockVocabularyRepository();
});

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return MockActivityRepository();
});

final badgeRepositoryProvider = Provider<BadgeRepository>((ref) {
  return MockBadgeRepository();
});

final wordListRepositoryProvider = Provider<WordListRepository>((ref) {
  return MockWordListRepository();
});
