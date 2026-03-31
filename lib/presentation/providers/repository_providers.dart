import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/network_info.dart';
import '../../core/services/book_cache_store.dart';
import '../../core/services/book_download_service.dart';
import '../../core/services/edge_function_service.dart';
import '../../core/services/file_cache_service.dart';
import '../../data/repositories/book_download_repository_impl.dart';
import '../../data/repositories/cached/cached_activity_repository.dart';
import '../../data/repositories/cached/cached_book_quiz_repository.dart';
import '../../data/repositories/cached/cached_book_repository.dart';
import '../../data/repositories/cached/cached_content_block_repository.dart';
import '../../data/repositories/supabase/supabase_activity_repository.dart';
import '../../data/repositories/supabase/supabase_auth_repository.dart';
import '../../data/repositories/supabase/supabase_avatar_repository.dart';
import '../../data/repositories/supabase/supabase_daily_quest_repository.dart';
import '../../data/repositories/supabase/supabase_badge_repository.dart';
import '../../data/repositories/supabase/supabase_book_repository.dart';
import '../../data/repositories/supabase/supabase_book_quiz_repository.dart';
import '../../data/repositories/supabase/supabase_card_repository.dart';
import '../../data/repositories/supabase/supabase_content_block_repository.dart';
import '../../data/repositories/supabase/supabase_student_assignment_repository.dart';
import '../../data/repositories/supabase/supabase_system_settings_repository.dart';
import '../../data/repositories/supabase/supabase_teacher_repository.dart';
import '../../data/repositories/supabase/supabase_user_repository.dart';
import '../../data/repositories/supabase/supabase_vocabulary_repository.dart';
import '../../data/repositories/supabase/supabase_tile_theme_repository.dart';
import '../../data/repositories/supabase/supabase_word_list_repository.dart';
import '../../domain/entities/system_settings.dart';
import '../../domain/repositories/activity_repository.dart';
import '../providers/system_settings_provider.dart';
import '../../domain/repositories/book_download_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/avatar_repository.dart';
import '../../domain/repositories/daily_quest_repository.dart';
import '../../domain/repositories/badge_repository.dart';
import '../../domain/repositories/book_quiz_repository.dart';
import '../../domain/repositories/book_repository.dart';
import '../../domain/repositories/card_repository.dart';
import '../../domain/repositories/content_block_repository.dart';
import '../../domain/repositories/student_assignment_repository.dart';
import '../../domain/repositories/system_settings_repository.dart';
import '../../domain/repositories/teacher_repository.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/repositories/vocabulary_repository.dart';
import '../../domain/repositories/tile_theme_repository.dart';
import '../../domain/repositories/word_list_repository.dart';

/// Repository providers
/// All repositories now use Supabase implementations

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repository = SupabaseAuthRepository();
  ref.onDispose(() => repository.dispose());
  return repository;
});

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final remoteRepo = SupabaseBookRepository();
  final cacheStore = ref.watch(bookCacheStoreProvider);
  final networkInfo = ref.watch(networkInfoProvider);
  return CachedBookRepository(
    remoteRepo: remoteRepo,
    cacheStore: cacheStore,
    networkInfo: networkInfo,
  );
});

final bookDownloadRepositoryProvider = Provider<BookDownloadRepository>((ref) {
  final downloadService = ref.watch(bookDownloadServiceProvider);
  final fileCacheService = ref.watch(fileCacheServiceProvider);
  final cacheStore = ref.watch(bookCacheStoreProvider);
  return BookDownloadRepositoryImpl(
    downloadService: downloadService,
    fileCacheService: fileCacheService,
    cacheStore: cacheStore,
  );
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return SupabaseUserRepository();
});

final vocabularyRepositoryProvider = Provider<VocabularyRepository>((ref) {
  return SupabaseVocabularyRepository();
});

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final settings = ref.watch(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();
  final remoteRepo = SupabaseActivityRepository(settings: settings);
  final cacheStore = ref.watch(bookCacheStoreProvider);
  final networkInfo = ref.watch(networkInfoProvider);
  return CachedActivityRepository(
    remoteRepo: remoteRepo,
    cacheStore: cacheStore,
    networkInfo: networkInfo,
  );
});

final badgeRepositoryProvider = Provider<BadgeRepository>((ref) {
  return SupabaseBadgeRepository();
});

final wordListRepositoryProvider = Provider<WordListRepository>((ref) {
  return SupabaseWordListRepository();
});

final teacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  return SupabaseTeacherRepository();
});

final studentAssignmentRepositoryProvider = Provider<StudentAssignmentRepository>((ref) {
  return SupabaseStudentAssignmentRepository();
});

// NOTE: inlineActivitiesProvider moved to activity_provider.dart with UseCase

/// Edge Function service provider (for XP awards, streak updates)
final edgeFunctionServiceProvider = Provider<EdgeFunctionService>((ref) {
  return EdgeFunctionService();
});

final contentBlockRepositoryProvider = Provider<ContentBlockRepository>((ref) {
  final remoteRepo = SupabaseContentBlockRepository();
  final cacheStore = ref.watch(bookCacheStoreProvider);
  final networkInfo = ref.watch(networkInfoProvider);
  return CachedContentBlockRepository(
    remoteRepo: remoteRepo,
    cacheStore: cacheStore,
    networkInfo: networkInfo,
  );
});

final cardRepositoryProvider = Provider<CardRepository>((ref) {
  return SupabaseCardRepository();
});

final systemSettingsRepositoryProvider = Provider<SystemSettingsRepository>((ref) {
  return SupabaseSystemSettingsRepository(Supabase.instance.client);
});

final bookQuizRepositoryProvider = Provider<BookQuizRepository>((ref) {
  final remoteRepo = SupabaseBookQuizRepository();
  final cacheStore = ref.watch(bookCacheStoreProvider);
  final networkInfo = ref.watch(networkInfoProvider);
  return CachedBookQuizRepository(
    remoteRepo: remoteRepo,
    cacheStore: cacheStore,
    networkInfo: networkInfo,
  );
});

final dailyQuestRepositoryProvider = Provider<DailyQuestRepository>((ref) {
  return SupabaseDailyQuestRepository(Supabase.instance.client);
});

final avatarRepositoryProvider = Provider<AvatarRepository>((ref) {
  return SupabaseAvatarRepository();
});

final tileThemeRepositoryProvider = Provider<TileThemeRepository>((ref) {
  return SupabaseTileThemeRepository(Supabase.instance.client);
});
