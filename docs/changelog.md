# Changelog

Tüm önemli değişiklikler bu dosyada kronolojik olarak tutulur.

Format: [Keep a Changelog](https://keepachangelog.com/)

---

## [Unreleased]

### Card Collection Audit & Fixes (2026-03-28)

#### Fixed
- **`open_card_pack` missing `image_url`** — RPC JSONB response did not include `image_url`, causing pack reveal to always use local asset fallback instead of Supabase Storage URL. Added `'image_url', v_selected_card.image_url` to the `jsonb_build_object`.
- **`buy_card_pack` no idempotency** — Client retry on network timeout could double-charge. Added optional `p_idempotency_key UUID` parameter; client generates UUID v4 per request, stored as `coin_logs.source_id` with duplicate check.
- **Admin wrong column name** — `user_edit_screen.dart` ordered by `obtained_at` (non-existent), fixed to `first_obtained_at`.
- **`firstWhere` crash risk** — `card_collection_screen.dart` used `firstWhere` without `orElse`; replaced with `where().firstOrNull` + null-safe fallback.

#### Removed
- **Dead code** — `collectionProgressProvider` (unused), `CardSummaryRow` widget (unused), `_buildFallbackBackground` unreachable branch, `CardListScreen` (never routed to — providers extracted to dedicated file).

#### Infrastructure
- **1 DB migration** (20260328200001) — Updated `open_card_pack` (image_url) + `buy_card_pack` (idempotency key).
- **Feature spec** — `docs/specs/15-card-collection.md` documents the full Card Collection system (19 findings: 8 fixed, 1 skipped, 10 deferred). Covers 96-card catalog, 8 myth categories, rarity tiers, pity mechanic, pack opening flow, admin CRUD, idempotency.

### Daily Quest Audit & Fixes (2026-03-28)

#### Fixed
- **Widget-level UseCase call** — `DailyQuestList._claimBonus()` called `claimDailyBonusUseCaseProvider` directly. Extracted `DailyQuestController` StateNotifier (mirrors `AvatarController` pattern).
- **`DateTime.now()` timezone bug** — `hasDailyBonusClaimed` used `DateTime.now().toUtc()` instead of `AppClock.now()`, breaking debug date offset. Fixed to use `AppClock.now()`.
- **Stale docs** — `features.md` Flow 4 referenced wrong RPC name (`claimDailyQuestPack` → `claimDailyBonus`).

#### Removed
- **Dead code** — Legacy `CardRepository.claimDailyQuestPack()` / `hasDailyQuestPackBeenClaimed()` methods, `RpcFunctions.claimDailyQuestPack` / `hasDailyQuestPackClaimed` constants, `DbTables.dailyQuestPackClaims` constant. All superseded by the new quest engine's `DailyQuestRepository`.

#### Infrastructure
- **Feature spec** — `docs/specs/14-daily-quest.md` documents the full Daily Quest system (14 findings: 6 fixed, 8 deferred). Covers implicit progress tracking, auto-reward RPC, bonus pack claim, admin quest management.

### Coin Economy Audit & Fixes (2026-03-28)

#### Fixed
- **4 RPC auth gaps (CRITICAL)** — `buy_card_pack`, `open_card_pack`, `award_coins_transaction`, `spend_coins_transaction` accepted arbitrary `p_user_id` without verifying `auth.uid()`. Any authenticated user could spend another user's coins or award themselves coins. Added auth guards to all 4 RPCs.
- **Direct coin inflation via RLS** — `profiles` UPDATE policy had no column restriction; authenticated users could directly `UPDATE profiles SET coins = 999999`. Applied `REVOKE UPDATE(coins, unopened_packs, streak_freeze_count) ON profiles FROM authenticated`.
- **Avatar screen architecture violation** — `AvatarCustomizeScreen` called UseCases directly and used `ref.invalidate(userControllerProvider)` (triggering unnecessary streak RPC). Extracted `AvatarController` StateNotifier with `refreshProfileOnly()`.
- **Streak freeze fire-and-forget** — Dialog popped before purchase completed, no loading state, no error feedback. `StreakStatusDialog` is now a `ConsumerStatefulWidget` with loading indicator and error snackbar.
- **Pack opening wrong text** — "Opening pack..." shown during buy phase (coin deduction). Split into "Buying pack..." / "Opening pack..." per phase.

#### Removed
- **Dead code** — `GetUserCoinsUseCase`, `GetCardsByCategoryUseCase`, `collectionByCategoryProvider`, `filteredCatalogProvider`, `selectedCategoryProvider` (card variant), corresponding repo methods. 2 files deleted, 118 lines removed.

#### Infrastructure
- **1 DB migration** (20260328100001) — Auth guards on 4 RPCs, column-level REVOKE, `streak_freeze_count` CHECK >= 0 constraint, redundant index dropped.
- **Feature spec** — `docs/specs/13-coin-economy.md` documents the full Coin Economy system (18 findings: 13 fixed, 5 deferred). Includes 3-layer security model documentation.

### Leaderboard/Leagues Audit & Fixes (2026-03-28)

#### Fixed
- **`process_weekly_league_reset` regression** — Debug-time migration (`20260323000006`) accidentally overwrote tier-based algorithm with old school-wide version. Restored correct tier-based competition (school x tier loops) + temp table optimization + `app_now()` timestamps.
- **8 leaderboard RPCs missing auth checks** — All `SECURITY DEFINER` read RPCs accepted arbitrary `school_id`/`class_id` without verifying caller belongs to that scope. Added `auth.uid()` guards to all 8 RPCs.
- **Zone banner miscalculation** — Promotion/demotion zone banners used fetched entry count (max 50) instead of actual tier group size. Added `total_count` to `get_weekly_school_leaderboard` RPC; UI now uses server-reported count for accurate zone thresholds.
- **No retry on error** — Leaderboard error state showed static text with no recovery action. Replaced with `ErrorStateWidget` + retry button.

#### Changed
- **Duplicate enum consolidated** — Renamed `LeaderboardScope` to `WeeklyLeaderboardScope` in domain layer, eliminating `as weekly` import alias collision.
- **Zone size single source of truth** — Extracted `leagueZoneSize()` to `owlio_shared` package. Both Dart UI and SQL reference the same thresholds.
- **Type-safe `LeagueTier` params** — UseCase params changed from raw `String?` to `LeagueTier?` enum; conversion to `.dbValue` happens at the data layer boundary.

#### Removed
- **Stale RLS policy** — Dropped "Users can read classmates league history" (class-based), redundant after migration to school-based system.

#### Infrastructure
- **1 DB migration** (20260328000009) — Tier-based reset fix, auth checks on 8 RPCs, total_count, stale RLS drop.
- **Feature spec** — `docs/specs/12-leaderboard-leagues.md` documents the full Leaderboard/Leagues system (10 findings: 8 fixed, 2 deferred).

### Badge/Achievement System Audit & Fixes (2026-03-28)

#### Fixed
- **`check_and_award_badges` missing auth check** — CRITICAL: SECURITY DEFINER RPC didn't validate `p_user_id = auth.uid()`. Any authenticated user could trigger badge awards (including XP rewards) for any other user. Added auth guard (same pattern as `award_xp_transaction`).

#### Removed
- **Dead code** — `allBadgesProvider`, `earnableBadgesProvider`, `GetAllBadgesUseCase`, `GetBadgeByIdUseCase`, `CheckEarnableBadgesUseCase`, `checkEarnableBadges()` repo method (6 sequential queries), `getAllBadges()`/`getBadgeById()` repo methods — all had zero consumers. Tests updated accordingly (-517 lines).

#### Infrastructure
- **1 DB migration** (20260328000008) — Auth guard on `check_and_award_badges`.
- **Feature spec** — `docs/specs/11-badge-achievement.md` documents the full Badge/Achievement system (12 findings: 7 fixed, 1 N/A, 4 tech debt).

### Streak System Audit, Spec & Fixes (2026-03-28)

#### Fixed
- **`update_user_streak` missing auth check** — CRITICAL: SECURITY DEFINER RPC didn't validate `p_user_id = auth.uid()`. Any authenticated user could update another user's streak, insert login records, and award milestone XP on their behalf. Added auth guard (same pattern as `buy_streak_freeze`).
- **Milestone XP idempotency gap** — `award_xp_transaction` called with `source_id = NULL` for milestones. Changed to deterministic `'day_N'` key for proper deduplication.
- **`hasEvent` hard-coded threshold** — `StreakResult.hasEvent` hard-coded `previousStreak >= 3` for broken-streak dialog, ignoring admin-configurable `notifStreakBrokenMin`. Removed getter; provider's `shouldShow` logic already reads from settings correctly.
- **`loginDatesProvider` bypassed repository** — Called `Supabase.instance.client` directly. Created `GetLoginDatesUseCase` and routed through `UserRepository` for architecture compliance.
- **Stale comment in `addXP()`** — Referenced removed server-side streak calls; updated to reflect login-based model.
- **Redundant Container wrapper** — `StreakStatusDialog` Close button had unnecessary `Container` wrapping `Text`.

#### Added
- **Admin-configurable milestone XP** — Milestone XP values moved from hard-coded SQL `CASE` to `system_settings` key `streak_milestones` (JSON object: `{"7":50,"14":100,...}`). Admin can now tune milestone rewards.
- **Repeating milestones for 100+ day streaks** — New `streak_milestone_repeat_interval` (default 100) and `streak_milestone_repeat_xp` (default 1000) settings. Day 200, 300, etc. each award XP.
- **`GetLoginDatesUseCase`** — New UseCase + Params for streak calendar data, following existing codebase pattern.

#### Removed
- **Dead Edge Function** — `supabase/functions/check-streak/index.ts` deleted (duplicated SQL RPC logic, held `SUPABASE_SERVICE_ROLE_KEY`, never called by app).

#### Infrastructure
- **2 DB migrations** (20260328000006, 20260328000007) — Auth guard + idempotency fix, then configurable milestones with 3 new `system_settings` keys.
- **Feature spec** — `docs/specs/10-streak-system.md` documents the full Streak System (9 findings: all 9 fixed).

### XP/Leveling Audit & Spec (2026-03-28)

#### Fixed
- **`award_xp_transaction` missing auth check** — SECURITY DEFINER RPC didn't validate `p_user_id = auth.uid()`. Any client could award XP/coins to any user. Added auth guard (same pattern as `complete_vocabulary_session`).
- **Misleading SQL comments** — `calculate_level` function comments said thresholds "0, 100, 300, 600" but actual formula gives "0, 200, 600, 1200". Comments corrected to match.

#### Removed
- **Dead code** — `getLeaderboard()` method in `UserRepository` interface and `SupabaseUserRepository` (replaced by RPC-based leaderboard methods, never called).

#### Infrastructure
- **2 DB migrations** (20260328000004, 20260328000005) — Auth guard on `award_xp_transaction`, corrected `calculate_level` comments.
- **Feature spec** — `docs/specs/09-xp-leveling.md` documents the full XP/Leveling system (4 findings: 3 fixed, 1 accepted).

### Daily Vocabulary Review Audit & Fixes (2026-03-28)

#### Fixed
- **2 RPCs missing auth checks** — `complete_daily_review` (Critical: any user could award XP to another) and `get_due_review_words` (info disclosure). Both now verify `auth.uid() = p_user_id`.
- **Session deadlock** — `_isProcessingAnswer` flag not reset when word had no progress record (unit review mode). Wrapped in `try/finally`. Words without progress now get initial SM-2 values.
- **Silent network errors** — `loadSession` and `loadUnitReviewSession` swallowed failures as empty word lists ("All caught up!"). Added `errorMessage` to `DailyReviewState` with error UI + retry button.
- **Threshold mismatch** — Flutter counted all due words (incl. mastered) for 10-word gate, quest RPC counted only non-mastered. Added `status != 'mastered'` filter to `get_due_review_words` RPC — aligns both and enables partial index.
- **Timezone bug** — `saveDailyReviewPosition` used `DateTime.now()` (device local) while session used `app_current_date()` (Istanbul TZ). Changed to update by `session_id` instead of `user_id + date`.
- **XP labeled as "Coins"** — Completion dialog showed `'+$xpEarned Coins'` → corrected to `'+$xpEarned XP'`.
- **Unhandled auth exception** — `dailyReviewControllerProvider` threw on null userId, crashing screen. Now returns inert controller with error state.

#### Changed
- **Architecture fix** — `daily_review_screen.dart` no longer reads `vocabularyRepositoryProvider` directly. Created `SaveDailyReviewPositionUseCase` to maintain Screen → Provider → UseCase rule.
- **Session composition simplified** — RPC now returns only non-mastered words. Removed mastered/non-mastered split logic from `loadSession()`. Sessions are up to 25 non-mastered words.
- **Unit review filtering** — `GetAllWordListsParams` gained optional `unitId` parameter. `loadUnitReviewSession` now filters server-side instead of fetching all lists.
- **Completion stats accuracy** — Dialog stats now use first-pass responses only (exclude requeue duplicates).

#### Removed
- **Dead code** — `getWordProgressUseCase` (injected but never called), `totalDueWordsForReviewProvider` (trivial `.length` wrapper), `DailyReviewSessionModel.fromEntity` (never called), audio button stub (non-functional `IconButton`).

#### Infrastructure
- **1 DB migration** (20260328000003) — Auth checks on 2 RPCs, mastered filter on `get_due_review_words`.
- **Feature spec** — `docs/specs/08-daily-vocabulary-review.md` documents the full Daily Vocabulary Review system (20 findings: 19 fixed, 1 deferred).
- **Provider lifecycle** — `dailyReviewWordsProvider` and `todayReviewSessionProvider` converted to `.autoDispose`.

### Learning Paths Audit & Fixes (2026-03-27)

#### Fixed
- **3 RPCs missing auth checks** — `apply_learning_path_template` (admin/head/teacher gate), `get_user_learning_paths` and `get_path_daily_reviews` (user can only query own data). Previously any authenticated user could call these for any user/school.
- **DR replay attack** — `path_daily_review_completions` RLS split from `FOR ALL` to separate SELECT/INSERT/UPDATE policies. Students can no longer DELETE their own records to replay daily review.
- **Template RLS role mismatch** — 3 template table policies used `'head_teacher'` but profiles CHECK uses `'head'`. Head teachers can now manage templates.
- **Class deletion blocked** — `scope_learning_paths.class_id` FK added `ON DELETE CASCADE`. Class deletion no longer fails when scope paths reference it.
- **Non-atomic sort_order** — `apply_learning_path_template` now uses `FOR UPDATE` row lock to prevent duplicate sort_order from concurrent template applications.
- **Raw string itemType** — 3 entities (`ClassLearningPathUnit`, `UnitAssignmentItem`, `StudentUnitProgressItem`) changed from `String` to `LearningPathItemType` enum. Eliminates fragile `== 'word_list'` comparisons.

#### Removed
- **Dead code** — `RpcFunctions.getPathDailyReviews` (unused constant), `LabelPosition.below` (unreachable branch), `vocabularyUnitReviewPath` (orphaned route), stale comments, duplicate `allAssignmentsProvider` in admin.
- **12 debugPrint statements** — Diagnostic prints removed from `supabase_teacher_repository` (9) and `teacher_provider` (3). Error-condition prints retained.

#### Infrastructure
- **1 DB migration** (20260327100001) — Auth checks, RLS fixes, FK cascade, index add/drop, atomic sort_order.
- **Feature spec** — `docs/specs/07-learning-paths.md` documents the full Learning Paths system (21 findings: 17 fixed, 4 deferred as known limitations).
- **Redundant indexes dropped** — `idx_path_dr_user` and `idx_path_dr_unit` (covered by UNIQUE composite). Added `idx_scope_lp_template`.

### Word Lists Audit & Fixes (2026-03-27)

#### Fixed
- **Star count divergence** — Unified `UserWordListProgress.starCount` and `StudentWordListProgress.starCount` to 90/70/50/0 thresholds. Previously student used 95/80/any, teacher used 90/70/50.
- **isComplete semantics** — Unified to `completedAt != null` across both entities (was `totalSessions > 0` for student).
- **RPC auth vulnerability** — `complete_vocabulary_session` now verifies `p_user_id == auth.uid()`. Previously any authenticated user could submit session data for any other user.
- **Missing error states** — Added error/loading handling to vocabulary hub, word list detail, and word bank screens (previously swallowed errors silently).
- **N+1 progress queries** — `CategoryBrowseScreen` now batch-loads all progress via `userWordListProgressProvider` instead of per-item `progressForListProvider`.

#### Changed
- **Session save architecture** — Extracted multi-UseCase orchestration from `session_summary_screen.dart` into `SessionSaveNotifier` provider. Screen no longer imports domain UseCases directly.
- **UI extension relocated** — `WordListCategoryIcon` moved from domain entity to `ui_helpers.dart`. Duplicate `_getCategoryColor` in 2 screens replaced with centralized `VocabularyColors.getCategoryColor`.
- **Shared enum parsing** — `WordListModel` now uses `WordListCategory.fromDbValue()`/`.dbValue` from owlio_shared instead of duplicate switch statements.
- **Typed category field** — `StudentWordListProgress.wordListCategory` changed from `String` to `WordListCategory` enum. Parsing at model boundary.

#### Removed
- **Dead code** — `UpdateWordListProgressUseCase` + provider (never called), `getVocabularyUnits()` from repository (no consumers), `WordListModel.fromEntity` (never called), `progressPercentage` getter (zero callers), `dueForReviewProvider` (unused), `retryWordIds` parameter (never populated), 3 `debugPrint` statements, stale comments.

#### Infrastructure
- **1 DB migration** (20260328000002) — Auth check on `complete_vocabulary_session` RPC.
- **Feature spec** — `docs/specs/06-word-lists.md` documents the full Word Lists system (20/24 findings fixed, 4 deferred).
- **Pagination guard** — `getAllWordLists` now has `.limit(500)` safety net.

### Vocabulary & Spaced Repetition Audit & Spec (2026-03-27)

#### Fixed
- **Hard-coded table name** — `book_download_service.dart` used `'vocabulary_words'` string instead of `DbTables.vocabularyWords`. Added owlio_shared import.
- **Turkish MC distractor placeholders** — Session provider used Turkish `'(diğer)', '(yok)', '(bilinmiyor)'` as fallback MC options in the main app. Changed to English `'(other)', '(none)', '(unknown)'`.
- **Silent pop on empty word list** — Vocabulary session screen now shows snackbar feedback when word list has 0 words, instead of silently popping back.

#### Changed
- **Admin panel language rule** — CLAUDE.md clarified: "UI in English" applies to main app only. Admin panel stays in Turkish.
- **Vocabulary spec path** — Feature Documentation table now points to `docs/specs/05-vocabulary-spaced-repetition.md` (previously `docs/vocabulary-session-system.md`).

#### Infrastructure
- **Feature spec** — `docs/specs/05-vocabulary-spaced-repetition.md` documents the full Vocabulary & Spaced Repetition system (7 findings: 3 fixed, 1 N/A, 1 resolved, 2 noted as low-priority tech debt).

### Book Quiz Audit & Fixes (2026-03-27)

#### Fixed
- **`quiz_passed` never written to DB** — Added missing field to `updateReadingProgress` upsert data map. Column was always `false` despite `HandleBookCompletionUseCase` setting it to `true`.
- **RPC auth vulnerability** — `get_best_book_quiz_result` now enforces authorization: caller must be the user themselves or a teacher/admin/head in the same school. Previously any authenticated user could query any other user's scores.
- **0-question quiz soft-lock** — `book_has_quiz` RPC now requires at least one question. Admin editor prevents publishing a quiz with no questions. Previously a published empty quiz would permanently block book completion.
- **Quiz timer** — `BookQuizScreen` now measures elapsed time via `Stopwatch` and populates `time_spent` column (was always `null`).
- **Admin Turkish labels** — Translated all user-facing strings in quiz editor and question editor to English (~80 strings across 2 files).

#### Changed
- **Shared enum usage** — `BookQuizQuestionModel` now uses `BookQuizQuestionType.fromDbValue()` / `.dbValue` from owlio_shared instead of duplicate `_parseType`/`_typeToString` switch statements. Admin question editor switch cases also converted to enum-based.
- **AppColors** — Replaced hard-coded `Color(0xFF58CC02)` and `Color(0xFFFF4B4B)` with `AppColors.primary` and `AppColors.danger` in quiz result card.

#### Removed
- **Dead code** — Unused `answeredIndices` parameter from `BookQuizProgressBar`, dead `_goToNextPage` condition (`_currentPage < 999`), stale comments.

#### Infrastructure
- **1 DB migration** (20260327100000) — Auth check on `get_best_book_quiz_result`, question existence check on `book_has_quiz`, composite index `(user_id, book_id)` on `book_quiz_results`.
- **Feature spec** — `docs/specs/04-book-quiz.md` documents the full Book Quiz system (12/16 findings fixed, 4 accepted/deferred).

### Inline Activities Audit & Fixes (2026-03-27)

#### Fixed
- **DB performance index** — Added partial index `(user_id, answered_at DESC) WHERE is_correct = true` on `inline_activity_results` for daily quest progress queries.
- **Chapter initialization resilience** — `chapterInitializedProvider` now set via `finally` block — progressive reveal and auto-play work even on load failure.
- **DB save failure rollback** — Activity state rolled back on server save failure via `removeCompleted` + `didUpdateWidget` on all 4 activity widgets. Student can retry instead of seeing inconsistent state.
- **Correctness tracking on re-open** — `getCompletedInlineActivities` returns `Map<String, bool>` (activityId → isCorrect). Previously-wrong answers now correctly displayed as wrong on chapter re-open.
- **`words_learned` column populated** — `saveInlineActivityResult` now includes `wordsLearned` in INSERT payload. DB column was always empty before.
- **Sound feedback on find_words** — Added `InlineActivitySoundMixin` to `InlineFindWordsActivity` (was missing, other 3 types had it).
- **Loading flicker** — Activity blocks show placeholder instead of error card while `inlineActivitiesAsync` is loading.
- **Chapter completion flash** — `isChapterCompleteProvider` returns `false` until `chapterInitializedProvider` is true (prevents transient completion widget).
- **Matching duplicate right-values** — Changed to index-based pairing (`Map<int, int>`) instead of value-based (`Map<String, String>`). Admin editor validates unique right values on save.
- **Empty options crash** — Added guard clauses in `word_translation` and `find_words` for empty options list.
- **Zero-length auto-submit** — Added `requiredSelections == 0` guard in `find_words`.
- **Unknown activity type** — `InlineActivityModel.fromJson` returns null for unknown types (filtered by repository). Replaces silent fallback to empty true/false card.
- **Offline graceful degradation** — Cached repository returns empty map instead of `NetworkFailure` when offline.
- **Admin Turkish labels** — Translated `İptal`/`Kaydet` to `Cancel`/`Save` in activity editor.
- **Vocab failure logging** — `addWordsToVocabularyBatch` failures now logged via `debugPrint` instead of silently swallowed.

#### Removed
- **Dead code (628 lines)** — `SaveInlineActivityResultUseCase` + provider, `inline_activity_wrapper.dart` (234 lines), `InlineActivity.xpReward` field, `InlineActivityResult` entity + `InlineActivityResultModel` class, broken widgetbook `activity_widgets.dart`, unused `SingleTickerProviderStateMixin`.
- **Redundant enum parsing** — Replaced `_parseInlineActivityType` / `_inlineActivityTypeToString` with shared `InlineActivityType.fromDbValue()` / `.dbValue`.

#### Infrastructure
- **1 DB migration** (20260327000010) — Partial index on `inline_activity_results`.
- **Feature spec** — `docs/specs/03-inline-activities.md` documents the full Inline Activities system (22/25 findings fixed, 2 accepted, 1 deferred).

### Audio/Karaoke Reader Audit & Spec (2026-03-27)

#### Fixed
- **Audio load error visible to user** — `AudioSyncState.error` was set but never rendered. Added `_AudioErrorPill` widget in `ReaderAudioControls` with dark/light theme support and dismiss button.
- **Excessive debug logging** — Removed 8 of 9 `debugPrint` calls from `WordPronunciationService` (kept only init error).

#### Removed
- **Dead code** — `showDropCap` unused parameter + `firstTextBlockId` logic from `ReaderTextBlock`/`ReaderContentBlockList`. 3 unused filtered providers (`textBlocksProvider`, `activityBlocksProvider`, `audioBlocksProvider`). 2 unused `WordTiming` helper methods (`isActiveAt`, `durationMs`).

#### Infrastructure
- **Feature spec** — `docs/specs/02-audio-karaoke-reader.md` documents the full Audio/Karaoke Reader system (5/5 findings resolved). Covers data model, two audio models (per-block vs chapter-level), listening mode, auto-play, karaoke sync, scroll follow, offline caching, TTS pronunciation.

### Book System Audit & Integrity Fixes (2026-03-27)

#### Fixed
- **XP idempotency** — All XP awards (chapter, book, quiz, inline activity) now pass `source`/`source_id` to `award_xp_transaction` RPC. DB-level dedup prevents duplicate XP via partial unique index on `xp_logs(user_id, source, source_id)`. Quiz retakes no longer award repeated XP.
- **reading_progress RLS** — Replaced `FOR ALL` policy with granular SELECT/INSERT/UPDATE. Students can no longer delete their own reading progress via direct API access.
- **Error propagation** — All book FutureProviders now throw on failure instead of silently returning empty data. Screens show `ErrorStateWidget` with retry button.
- **hasReadToday timezone** — Switched from `reading_progress.updated_at` (UTC mismatch) to `daily_chapter_reads.read_date` (DATE column, timezone-safe).
- **Admin Turkish text** — Translated ~49 Turkish strings to English across 3 admin book screens. Fixed `_getLevelColor` to use CEFR values (A1-C2) instead of never-matching beginner/intermediate/advanced.

#### Changed
- **Book completion logic consolidated** — New `HandleBookCompletionUseCase` is the single source of truth for "is this book complete?" (replaces duplicated logic in `markChapterComplete` and `_handleQuizPassed`).
- **Quiz grading extracted** — New `GradeBookQuizUseCase` moves grading from `BookQuizScreen` widget to domain layer.
- **Inline activity extracted** — New `CompleteInlineActivityUseCase` replaces the 90-line free function with proper domain/presentation separation.
- **Book download abstracted** — New `DownloadBookUseCase` and `RemoveBookDownloadUseCase` with `BookDownloadRepository` interface.
- **Chapter lock logic** — Moved from widget build method to `chaptersWithLockStatusProvider`.
- **Book access** — Typed getters (`assignment.hasLibraryLock`, `assignment.lockedBookId`) replace dynamic map access.
- **Book author field** — Added `author` to Book entity/model, replacing `metadata['author']` workaround.
- **ActivityStats entity** — Replaced `Map<String, dynamic>` with typed `ActivityStats` entity.
- **Library screen** — `_BookShelfItem`/`_LibraryShelf` converted to `ConsumerWidget`, `Image.network` replaced with `CachedBookImage`, category filter auto-resets via `autoDispose`.

#### Removed
- **Dead code** — 253 lines removed: 3 unused UseCases, 2 unused providers, `ReadingController`, orphaned library providers, `getContentBlockById` method chain.
- **Duplicate code** — Removed duplicate enum parsing (`_parseBookStatus`, `_parseBlockType`), hard-coded `'published'` strings, triplicated chapter completion try/catch.

#### Infrastructure
- **1 DB migration** (20260328000001) — reading_progress RLS policy split.
- **5 new UseCases** — HandleBookCompletion, GradeBookQuiz, CompleteInlineActivity, DownloadBook, RemoveBookDownload.
- **1 new repository** — BookDownloadRepository (interface + implementation).
- **1 new entity** — ActivityStats.
- **autoDispose** — Added to 12 FutureProvider.family providers to prevent memory accumulation.
- **Feature spec** — `docs/specs/01-book-system.md` documents the full Book System (37/38 findings resolved).

### Student Class Change Assignment Sync (2026-03-27)

#### Added
- **Automatic assignment enrollment on class change** — When a student's `class_id` changes (new student, transfer), a DB trigger automatically enrolls them in the new class's active (non-expired) assignments.
- **Withdrawn status** — New `withdrawn` assignment status for students removed from a class. Completed assignments are preserved; only pending/in_progress are withdrawn.
- **Unit progress backfill** — For unit-type assignments, existing learning path progress (word list completions, book reads) is automatically reflected in the new assignment record.
- **Re-enrollment on return** — If a student returns to a previous class, withdrawn assignments are re-activated to pending.

#### Changed
- **Stats RPCs exclude withdrawn** — `get_assignments_with_stats` and `get_assignment_detail_with_stats` no longer count withdrawn students in `total_students`.
- **Sync RPC skips withdrawn** — `sync_unit_assignment_progress` no longer processes withdrawn students.
- **Student query filters withdrawn** — `getStudentAssignments` repository method excludes withdrawn assignments from student views.

#### Infrastructure
- **1 DB migration** (20260327000009) — CHECK constraint expansion, `_backfill_student_unit_progress` helper, `handle_student_class_change` trigger function + trigger, 3 RPC updates.
- **Shared package** — `AssignmentStatus.withdrawn` added to `owlio_shared`.
- **UI helpers** — Withdrawn status color (`grey.shade400`) and icon (`person_remove`) in both teacher and student helpers.

### Assignment Notification System (2026-03-27)

#### Added
- **In-app assignment notification** — Students see a dialog on app open when they have active (pending/in-progress/overdue) assignments. Shows count and teacher attribution.
- **Direct navigation** — Single assignment: "View" goes directly to assignment detail page. Multiple: goes to assignments list.
- **Session guard** — Notification fires once per app session. Resets on logout so next login can trigger again.
- **Admin toggle** — `notif_assignment` system setting (default: true) with notification gallery card in admin panel.
- **Gradient dialog style** — Matches existing notification dialogs (streak, level-up, badge) with blue gradient + emoji.

#### Fixed
- **Notification ordering** — Assignment notification fires AFTER streak/badge/league notifications by listening to `userControllerProvider` load completion with 500ms delay.
- **Back button on assignment detail** — Always visible. When navigated from notification (`go()`), back returns to homepage. When navigated from list (`push()`), back returns to list.

#### Infrastructure
- **1 DB migration** (20260327000002) — `notif_assignment` setting in system_settings.
- **New widget** — `AssignmentNotificationDialog` with animated fade+scale transition.
- **Event provider** — `AssignmentNotificationEvent` with count + optional assignmentId for direct navigation.

### Vocabulary Hub Performance + Class Grade Enforcement (2026-03-27)

#### Fixed
- **Blank vocabulary screen** — Root cause: `classes.grade` was nullable, causing `get_user_learning_paths` RPC to return 0 results for users in classes with null grade. Fixed with NOT NULL constraint + CHECK(1-12).
- **PathDailyReviewNode active state** — Daily review node always received `isActive: false` due to `foundActive` double-set in outer detection loop.
- **`ref.watch` after `await`** — Moved `getBooksByIdsUseCaseProvider` watch before first `await` in `learningPathProvider` (Riverpod best practice).
- **`completeDailyReview` crash on empty response** — `.first` on empty list replaced with null-safe guard.
- **Empty learning path UX** — `SizedBox.shrink()` replaced with "No learning path yet" message.

#### Performance
- **N+1 `progressForListProvider` eliminated** — `_VerticalListSection` now uses batch `userWordListProgressProvider` (N queries → 0).
- **N+1 `bookByIdProvider` eliminated** — New `getBooksByIds` repository method + usecase fetches all books in single `WHERE id IN(...)` query (M queries → 1).
- **Duplicate word lists fetch eliminated** — `storyWordListsProvider` now derives from cached `allWordListsProvider` (1 query → 0).
- **`getDueForReview` sequential queries merged** — New `get_due_review_words` RPC replaces 2 sequential queries with 1 (2 queries → 1).
- **`getBooksByIds` filters published only** — Unpublished books no longer returned in learning path.

#### Added
- **Required grade on class creation/editing** — Grade dropdown (1-12) added to teacher create + edit class dialogs. Grade field validated as required in admin panel.
- **`update_class` RPC grade support** — RPC now accepts `p_grade` parameter for grade updates.
- **`GetBooksByIdsUseCase`** — New batch book fetch usecase following Clean Architecture pattern.

#### Infrastructure
- **3 DB migrations** (20260327000006–008) — `classes.grade` NOT NULL enforcement, `update_class` RPC grade param, `get_due_review_words` RPC.
- **`RpcFunctions.getDueReviewWords`** — New constant in shared package.

### Teacher Panel Responsive Redesign + Playful UI (2026-03-27)

#### Added
- **Responsive layout system** — `ResponsiveConstraint`, `ResponsiveGrid`, `ResponsiveWrap` widgets for adaptive layouts across mobile/tablet/desktop.
- **PlayfulCard widget** — Duolingo-style card with 2px border, flat shadow, 16px radius. Drop-in replacement for Material Card across all teacher screens.
- **PlayfulListCard widget** — Grouped list variant with dividers for activity feeds.
- **Custom teacher sidebar** — Playful NavigationRail replacement with colored nav items, Owlio logo, profile button at bottom. Replaces default Material NavigationRail on wide screens.
- **2-column dashboard layout** — Welcome + Quick Actions + Stats on left, Recent Student Activities on right (wide screens).
- **AnimatedGameButton on teacher dashboard** — 3D press-down buttons for Quick Actions (New Assignment, Reports, Manage Classes, Leaderboard).
- **Student detail redesign** — Horizontal scroll for books (filtered >0%), word lists (with word chips), quiz results, badges, and card collection. Level+XP progress bar styled like student profile.
- **Student badges & cards on teacher view** — `teacherStudentBadgesProvider` and `teacherStudentCardsProvider` fetch student data via schoolmate RLS policies.
- **Word list words on teacher view** — `wordListWordsProvider` shows vocabulary words as colored chips in word list cards.
- **Student avatar on teacher view** — `AvatarWidget` renders student's equipped avatar from `avatarEquippedCache`.
- **Clickable student profiles** — Recent Activity items and Leaderboard cards navigate to full student profile via `/teacher/dashboard/student/:studentId` route.
- **Class Overview enriched metrics** — New RPC returns avg_xp, avg_streak, total_reading_time, completed_books, active_last_30d, total_vocab_words per class.
- **Class detail report mode enhanced** — PlayfulCard stats bar (Students, Avg XP, Avg Streak, Progress, Books), enriched student cards with progress bars and stat chips.
- **Info banner on Manage Classes** — Explains page purpose and directs to Reports for student progress.
- **Page transition animations** — Global `FadeUpwardsPageTransitionsBuilder` + `AnimatedSwitcher` crossfade on tab switches.

#### Changed
- **Teacher routes moved into shell** — Class detail, student detail, assignment detail, create assignment, and all report sub-routes now render inside the teacher shell (sidebar visible).
- **"My Classes" → "Manage Classes"** — Clearer naming for class management section.
- **"Recent Activity" → "Recent Student Activities"** — Filtered out inline activity XP and generic "XP awarded" entries.
- **Assignment creation reordered** — Class → Content → Schedule → Title → Description (was Title first).
- **Teacher profile redesign** — Removed avatar circle, first+last name side by side, PlayfulCard for personal info and password sections.
- **All teacher AppBars** — `centerTitle: false` for left-aligned titles.
- **ResponsiveWrap orphan prevention** — If last row would have 1 item, reduces columns (e.g., 3+1 → 2+2).

#### Fixed
- **Create assignment routing** — `/teacher/assignments/create` was matching `:assignmentId` param. Fixed by placing `create` route before dynamic param.
- **Student detail routing** — `students/:studentId` path mismatch (plural vs singular). Fixed to match route constant.
- **AnimatedGameButton text overflow** — Added `Flexible` wrapper with `TextOverflow.ellipsis`.
- **Class card overflow** — Inner Row converted to `Wrap` for student count + academic year.

#### Infrastructure
- **3 DB migrations** (20260327000003–005) — `get_classes_with_stats` RPC enriched with 6 new columns.
- **New shared widgets** — `responsive_layout.dart` (3 widgets), `playful_card.dart` (2 widgets).

### Assignment System Overhaul + Unit Assignment Type (2026-03-26)

#### Added
- **Unit assignment type** — Teachers can assign learning path units as homework. Students complete word lists + books within the unit. Progress tracked server-side via `calculate_unit_assignment_progress` RPC.
- **Unit selection sheet** — Create assignment screen shows learning path units for the selected class, with full item preview (word lists with all words, books with chapter counts, game/treasure indicators).
- **Teacher student detail bottom sheet** — Tapping a student in unit assignment detail shows per-item progress: completion status, sessions played, best accuracy/score for word lists, chapters read for books.
- **Unit content section** — Teacher assignment detail shows unit items with word chips under each word list.
- **`assignmentSyncProvider` activated** — Auto-syncs assignment completion when students open assignments screen (handles pre-existing completions). Debounced with 60s keepAlive.
- **Bulk sync on creation** — `sync_unit_assignment_progress` RPC called after creating unit assignments to pick up students' pre-existing progress immediately.
- **8 new DB RPCs** — `get_assignment_detail_with_stats`, `get_class_learning_path_units`, `get_unit_assignment_items`, `calculate_unit_assignment_progress`, `sync_unit_assignment_progress`, `get_student_unit_progress` + fixes.

#### Changed
- **`mixed` → `unit` assignment type** — DB CHECK constraint, shared package enum, all Flutter references updated.
- **`getAssignmentDetail` → RPC** — Replaced 2-query approach with single `get_assignment_detail_with_stats` RPC.
- **Unit is default tab** — Create assignment screen defaults to Unit type (first segment).

#### Fixed
- **`chapterIds` dead code removed** — Unused getter from old chapter-selection design.
- **RPC ambiguity fixes** — `#variable_conflict use_column` added to all RETURNS TABLE functions. Type casts (`::TEXT[]`, `::BIGINT`) for PostgreSQL type matching.
- **Book completion NULL safety** — `COALESCE` wrapper for missing `reading_progress` rows in all progress RPCs.
- **Auth ownership check** — `get_class_learning_path_units` now verifies teacher is in same school.
- **Class change clears unit** — Changing class in create assignment clears previously selected unit.

#### Infrastructure
- **8 DB migrations** (20260326000009–20260326000016) — Constraint change, 8 RPCs, NULL safety fixes, auth hardening.
- **Clean Architecture** — 4 new entities, 5 new use cases, 4 new models, full provider chain. Architecture violation (direct Supabase call) caught in review and fixed.
- **Shared package** — 7 new `RpcFunctions` constants in `owlio_shared`.

### Avatar Customization System (2026-03-26)

#### Added
- **Layered avatar system** — Students select a base animal (6 options, all free) and equip purchasable accessories. Accessories rendered as composited PNG layers via `Stack` widget.
- **5 accessory categories** — Background (z=0), Body (z=10), Neck (z=15), Face (z=20), Head (z=30). One item per category enforced by RPCs.
- **52 seeded accessories** — Common (50c), Rare (150c), Epic (400c), Legendary (1000c). Inactive by default — admin uploads PNGs and activates.
- **Avatar shop in main app** — `AvatarCustomizeScreen` with live preview (240px), base animal row, category tabs, item grid with buy/equip/unequip states.
- **Auto-equip on purchase** — `buy_avatar_item` RPC automatically equips the newly bought item.
- **Per-animal outfit memory** — `avatar_outfits` JSONB on profiles stores equipped items per base animal. Switching animals saves current outfit and restores the target animal's last outfit.
- **Reusable `AvatarWidget`** — Composited layer renderer with SVG+PNG support, used in profile, leaderboard, and student dialog.
- **Profile integration** — Profile header shows `AvatarWidget` with edit button linking to customize screen.
- **Leaderboard integration** — `avatar_equipped_cache` added to all 8 leaderboard RPCs + `safe_profiles` view. `AvatarWidget` renders in leaderboard rows and `StudentProfileDialog`.
- **Admin avatar management** — 3-tab screen (Bases/Categories/Items) with category filter chips, CRUD for all entities, image upload to Supabase Storage `avatars` bucket.
- **Admin live composite preview** — Item edit screen shows accessory overlaid on selectable base animal.
- **Denormalized cache** — `avatar_equipped_cache` JSONB on profiles rebuilt by every equip/unequip/set_base RPC. Prevents N+1 on leaderboard reads.

#### Fixed
- **Tab reset on purchase** — Replaced `DefaultTabController` with managed `TabController` in state to preserve tab position across provider rebuilds.

#### Infrastructure
- **8 DB migrations** (20260326000001–20260326000008, 20260327000001) — 4 tables, 5 RPCs, RLS policies, storage bucket, admin policies, seed data, per-animal outfits.
- **Shared package** — 4 new `DbTables` + 4 new `RpcFunctions` constants in `owlio_shared`.
- **Clean Architecture** — 7 entities, 8 usecases, 5 models, 1 repository (domain→data→presentation).
- **`flutter_svg`** added to admin panel for SVG rendering support.

### Class Management Redesign (2026-03-25)

#### Added
- **Class edit/delete** — Teachers can rename classes and delete empty ones via popup menu on class cards.
- **Bulk student transfer** — Select mode with checkboxes + "Move to..." bottom sheet for moving multiple students to another class atomically.
- **Individual student move** — "Move to Another Class" action in student info bottom sheet.
- **Student login cards PDF** — "Download Login Cards" generates A4 PDF (2×5 grid) with student name, username, password, QR code. Uses Nunito font for Turkish character support.
- **Student password visibility** — Teachers can see `password_plain` in student info sheet (for auto-created accounts).
- **Management vs Report mode** — `ClassDetailScreen` now has dual modes: management (from Classes tab — no stats, actions enabled) and report (from Reports → Class Overview — stats shown, read-only).
- **3 new RPCs** — `delete_class` (safe delete with student count check), `bulk_move_students` (atomic transfer), `update_class` (edit name/description).
- **`username` field** added to `StudentSummary` entity and `get_students_in_class` RPC.

#### Changed
- **Classes tab simplified** — Removed average progress from class cards (management view, not reports).
- **Class detail stats removed** — Stats bar (total XP, avg progress) hidden in management mode.
- **Student list alphabetical** — Sorted by first name, then last name.
- **Bottom action bar** — Opaque background with shadow, replaces floating buttons that overlapped student names.

#### Removed
- **3-dot student menu** — Replaced by tap-to-view info sheet + select mode for bulk operations.
- **Email display** — Removed from student info sheet (all local emails, not useful).

### Teacher Panel Audit & Fixes (2026-03-25)

#### Added
- **Teacher profile page** — Full profile UI replacing empty placeholder: initials circle, name, email, role badge, school name, editable first/last name, password reset, sign out.
- **Recent activity feed** — Teacher dashboard now shows real student activity from `xp_logs` (last 7 days) instead of permanent "No recent activity" placeholder.
- **Reading progress report** — Fully functional with real data from new `get_school_book_reading_stats` RPC, replacing stub zeros.
- **Quick Actions Leaderboard** — Replaced empty 4th button placeholder with Leaderboard shortcut.

#### Fixed
- **CRITICAL: `updateStudentClass` broken** — RLS blocked teacher UPDATE on profiles. Fixed with new `update_student_class` SECURITY DEFINER RPC.
- **CRITICAL: Cross-school data leaks** — `get_student_progress_with_books` and `get_assignments_with_stats` lacked school-scope checks. Any teacher could view any school's data.
- **CRITICAL: SQL ambiguous id** — `RETURNS TABLE (id UUID, ...)` conflicted with unqualified `WHERE id = auth.uid()`. Qualified all column references with table aliases.
- **`createAssignment` non-atomic** — 3 sequential queries replaced with single `create_assignment_with_students` RPC transaction.
- **`updateAssignmentProgress` race condition** — SELECT+UPDATE replaced with single `update_assignment_progress` RPC.
- **Due date time loss** — `showDatePicker` returned midnight, losing 23:59:59. Now preserves end-of-day time.
- **`DateTime.now()` → `AppClock.now()`** — Fixed in `getActiveAssignments` and `StudentAssignmentModel`.
- **Hardcoded status strings** — `'completed'`/`'in_progress'` replaced with `AssignmentStatus.*.dbValue`.
- **`_AssignmentAppBar`** — Converted from `StatelessWidget` + `ProviderScope.containerOf` to proper `ConsumerWidget`.
- **Provider error handling** — `schoolBookReadingStatsProvider` now returns `[]` on failure (consistent with all other teacher providers).

#### Changed
- **Duplicate helpers centralized** — `_formatTimeAgo` → `TimeFormatter.formatTimeAgo`, `_formatReadingTime` → `TimeFormatter.formatReadingTime`, `_getProgressColor` → `ScoreColors.getProgressColor` (5 files).
- **debugPrint removed** — Production debug logging removed from dashboard and teacher providers.
- **`allStudentsLeaderboardProvider`** moved from screen file to `teacher_provider.dart`.
- **Leaderboard refresh** — Now invalidates `classStudentsProvider` family to prevent stale data.
- **`RecentActivity.props`** — Added missing `studentFirstName`, `studentLastName`, `avatarUrl` fields.

#### Infrastructure
- **15 DB migrations** (20260325000007 through 20260325000015) — security fixes, new RPCs, schema updates.
- **`pdf` + `printing` packages** added for client-side PDF generation.

### Profile Screen Rebuild (2026-03-25)

#### Added
- **Complete profile screen rewrite** — 8-section layout replacing old screen with fake/hardcoded data.
- **`LevelHelper` utility** — Shared XP/level formula (`(level-1)*level*100`) extracted to `lib/core/utils/level_helper.dart`. Used by both `ProfileScreen` and `StudentProfileDialog`.
- **`profileContextProvider`** — Resolves `schoolId`/`classId` UUIDs to human-readable school and class names.
- **Card collection preview** — Top 5 rarest cards shown as `MythCardWidget` mini previews (scaled via `FittedBox`).
- **Recent badges section** — Last 5 earned badges with emoji, name, description, and relative date. "See All" bottom sheet for full list.
- **Combined stats card** — Books Read, Chapters Read, Reading Time, New Words in a single 4-column card with Word Bank button.
- **Daily review card** — 3-state card (completed/ready/building up) ported from old screen.

#### Fixed
- **Level progress bar always 100%** — Client formula used `*50` but server's `calculate_level()` uses `*100`. Now matches server.
- **Fake data removed** — "Joined 2026" (hardcoded), "Top 3 Finishes: 0" (fake), email-based username all replaced with real data.
- **Avatar image support** — Now renders `avatarUrl` with network image + initials fallback (was always initials-only).
- **Vocab stats mismatch** — Profile now uses same data source as Word Bank (`learnedWordsWithDetailsProvider`) for consistent numbers.
- **Card collection navigation crash** — `context.push` → `context.go` for shell tab route.

#### Removed
- **Settings button** — Was a dead `// TODO` button, removed.
- **Downloaded Books card** — Removed from profile (route still accessible elsewhere).
- **Separate vocabulary stats section** — Merged into combined stats card.

### Daily Quest Eligibility Fix (2026-03-24)

#### Fixed
- **Daily review quest shown when impossible** — `daily_review` quest appeared for users with < 10 due words, but the review UI requires 10+ words. Users saw an incomplete quest they couldn't finish.
- **Free XP exploit** — Users with 0 vocabulary words got auto-completed `daily_review` quest + 20 XP daily for doing nothing (from earlier edge-case migration).
- **Bonus claim mismatch** — `claim_daily_bonus` counted all active quests (3) but `get_daily_quest_progress` could return fewer (2). Users who completed all visible quests got "Not all quests completed" error when claiming bonus.
- **`claim_daily_quest_pack` wrong date source** — Missed by debug_time_offset migration, still used raw `CURRENT_DATE`/`NOW()` instead of `app_current_date()`/`app_now()`.

#### Infrastructure
- **2 DB migrations** — `20260325000005` (daily_review min 10 words + claim_daily_bonus fix), `20260325000006` (pack claim date offset fix)

### Performance: Parallel Data Fetching (2026-03-24)

#### Fixed
- **Vocabulary Hub N+1 query** — `learningPathProvider` was making 7+ sequential Supabase calls then N additional sequential book fetches. Now uses `Future.wait` for parallel provider fetches and pre-batches all book lookups before the loop.
- **Word Bank N+1 query** — `learnedWordsWithDetailsProvider` was fetching each word individually (50-200 sequential calls). Replaced with single `getWordsByIds` batch query using `.inFilter()`.
- **Daily Review N+1 query** — `loadSession()` and `loadUnitReviewSession()` were fetching progress per-word (up to 100 sequential calls). Replaced with single `getWordProgressBatch` batch query.
- **Inline activity word add** — Per-word vocabulary insert loop replaced with existing `addWordsToVocabularyBatch` method.
- **Teacher leaderboard** — Sequential per-class student fetch replaced with `Future.wait` parallel fetch.
- **Leaderboard display** — 3 independent provider awaits parallelized with `Future.wait`.

#### Added
- **`getWordsByIds` repository method** — Batch fetch words by ID list in a single query (`.inFilter('id', ids)`).
- **`getWordProgressBatch` repository method** — Batch fetch vocabulary progress for multiple words in a single query.
- **`GetWordsByIdsUseCase`** and **`GetWordProgressBatchUseCase`** — Clean Architecture use cases for the new batch methods.

#### Changed
- **Top navbar** — UK flag replaced with 🇬🇧→🇹🇷 language direction indicator.
- **Vocab nav icon** — Changed from `sort_by_alpha` to `route` icon.

### Admin Badge Improvements (2026-03-24)

#### Added
- **3 new streak badges** — Streak Warrior (14 days, +150 XP), Streak Hero (60 days, +750 XP), Streak Immortal (100 days, +1500 XP). Aligned with existing streak milestone XP bonuses.
- **Per-badge earned-by stats** — Badge edit screen now shows which students earned the badge and when (admin panel).
- **`levelCompleted` condition type** — Added to admin badge form dropdown (was in DB but missing from UI).
- **Missing categories** — `activities`, `xp`, `level` added to admin badge category dropdown (fixes crash when editing existing badges with these categories).

#### Changed
- **Shared badge helper** — Extracted duplicated `_getConditionLabel` / `_getConditionHelper` from 3 admin files into `owlio_admin/lib/core/utils/badge_helpers.dart`.

#### Removed
- **`dailyLogin` condition type** — Removed from shared enum, DB CHECK constraint, and all app code. Was never evaluated; `streak_days` covers the same use case.

#### Infrastructure
- **1 DB migration** — `20260325000003` (CHECK constraint update + 3 badge INSERTs)
- **Spec:** `docs/superpowers/specs/2026-03-24-admin-badge-improvements-design.md`
- **Plan:** `docs/superpowers/plans/2026-03-24-admin-badge-improvements.md`

### Badge Earned Notification (2026-03-24)

#### Added
- **Badge earned dialog** — Animated celebration dialog shown when students earn badges. Single badge: large icon + name + XP. Multiple badges: list layout. Uses amber/gold theme.
- **Dialog queue system** — `LevelUpCelebrationListener` converted to `ConsumerStatefulWidget` with a queue that shows dialogs one at a time (level up → streak → badge), preventing overlap.
- **`BadgeEarned` entity + `CheckAndAwardBadgesUseCase`** — New domain layer plumbing for badge check results.
- **`notif_badge_earned` admin toggle** — Admin can enable/disable badge notifications. Card with preview added to notification gallery.
- **`badge_icon` in RPC return** — `check_and_award_badges` now returns the badge emoji icon alongside name and XP.

#### Changed
- **Badge check moved to UserController** — Removed from 3 repository call sites, now called centrally in `UserController.addXP()` and `updateStreak()`. Covers all XP-granting paths automatically.
- **Profile refresh after badge XP** — `refreshProfileOnly()` called after badge award to prevent stale XP display.

#### Infrastructure
- **1 DB migration** — `20260325000004` (DROP+CREATE RPC with icon + notif setting)
- **Spec:** `docs/superpowers/specs/2026-03-24-badge-earned-notification-design.md`
- **Plan:** `docs/superpowers/plans/2026-03-24-badge-earned-notification.md`

### Type-Based XP + Combo Refactor (2026-03-24)

#### Added
- **12 new system_settings entries** — Admin-configurable XP values for inline activities (4 types), vocab question types (5 groups), combo bonus, session bonus, perfect bonus
- **Combo session-end bonus** — Combo no longer multiplies per-question XP. Instead, `maxCombo × combo_bonus_xp` is awarded as a one-time bonus at session end. Shown separately in session summary.

#### Changed
- **Inline activity XP** — Now reads from `systemSettingsProvider` by activity type instead of per-activity `xp_reward` DB column. All 4 widget callbacks simplified (removed `xpEarned` param).
- **Vocab session XP** — `QuestionTypeXP` extension deleted. `answerQuestion`/`answerMatchingQuestion` take `SystemSettings` param, use flat baseXP from settings.
- **`complete_vocabulary_session` RPC** — Session and perfect bonuses now read from `system_settings` table instead of hardcoded `v_session_bonus=10` / `v_perfect_bonus=20`.
- **Admin activity editor** — `xp_reward: 5` removed from INSERT (DB default covers it).

#### Infrastructure
- **2 DB migrations** — Settings INSERT + RPC update
- **Spec:** `docs/superpowers/specs/2026-03-23-type-based-xp-design.md`
- **Plan:** `docs/superpowers/plans/2026-03-23-type-based-xp.md`

### Notification Settings + Streak Extended (2026-03-24)

#### Added
- **Daily streak notification** — "Day X!" dialog shown every time user opens the app. Day 1 shows motivational "Day 1! Let's go!", Day 2+ cycles through 6 subtitles deterministically.
- **7 notification settings** — Admin-configurable toggles for all 6 notification types (streak extended, milestone, freeze saved, streak broken, level up, league change) + `notif_streak_broken_min` threshold.
- **Settings-aware event gating** — All 3 event types (streak, level up, league) in `UserController` now check system_settings before firing. `previousStreak >= 3` hardcode replaced with configurable `notifStreakBrokenMin`.

#### Infrastructure
- **1 DB migration** — 7 notification settings
- **Spec:** `docs/superpowers/specs/2026-03-24-notification-settings-design.md`
- **Plan:** `docs/superpowers/plans/2026-03-24-notification-settings.md`

### Admin Notification Gallery (2026-03-24)

#### Added
- **`/notifications` admin page** — Dedicated page showing all 6 notification types as preview cards with toggles. Each card shows exact message text users will see, with inline `notif_streak_broken_min` parameter.
- **Dashboard card** — "Notifications" card (indigo) on admin dashboard linking to the gallery.

#### Changed
- **Notification settings removed from general settings page** — Now exclusively managed on `/notifications`.

#### Infrastructure
- **Spec:** `docs/superpowers/specs/2026-03-24-notification-gallery-design.md`
- **Plan:** `docs/superpowers/plans/2026-03-24-notification-gallery.md`

### Username Auth & Bulk Student Creation (2026-03-24)

#### Added
- **Username-based login for students** — Students log in with auto-generated usernames (e.g., `mesyil1`) instead of student numbers. Synthetic email pattern (`username@owlio.local`) keeps Supabase Auth unchanged.
- **Unified login screen** — Single input field with `@` detection: contains `@` → email auth (teachers), otherwise → username auth (students). Replaces old tabbed Email/Student# toggle.
- **Bulk student creation** — New `/users/create` admin screen with two modes: single creation (student or teacher) and bulk CSV upload (`ad, soyad, sınıf` columns). Auto-generates usernames and passwords (word+3digits format, e.g., `fox047`).
- **`generate_username()` DB function** — Turkish→ASCII transliteration, first 3 chars of name + first 3 of surname + incrementing number. Advisory lock for concurrency safety.
- **Class auto-creation** — If a class name doesn't exist for the selected school, it's created automatically during bulk import.
- **`password_plain` column** — Stores plaintext passwords for admin visibility. Shown in user edit screen (read-only). Not exposed in `safe_profiles` view.
- **`bulk-create-students` Edge Function** — Creates auth users via `auth.admin.createUser()`, with per-row error handling, duplicate detection, batch limit (200), and retry on username collision.
- **`migrate-student-emails` Edge Function** — One-time migration script that updates existing students' `auth.users.email` to synthetic emails. Idempotent and admin-only.
- **`username` in User entity/model** — Added to domain layer for Flutter app access.
- **CSV download for credentials** — Admin can download created usernames/passwords as CSV after bulk creation.

#### Changed
- **Admin user list** — Shows `@username` instead of email for students.
- **Admin user edit** — Displays username and password (read-only). Info banner updated to reference creation page.
- **`safe_profiles` view** — Now includes `username` column for leaderboard/peer display.

#### Removed
- **Old CSV user import** — `user_import_screen.dart` deleted (only updated existing profiles, couldn't create users).
- **`SignInWithStudentNumberUseCase`** — Dead code removed from domain, data, and presentation layers.
- **Student number login** — `signInWithStudentNumber` removed from `AuthRepository`, `SupabaseAuthRepository`, and `AuthController`.

#### Infrastructure
- **2 DB migrations** — `20260325000001` (username column, generate_username, class unique index, safe_profiles update, existing student migration), `20260325000002` (password_plain column)
- **2 Edge Functions** — `bulk-create-students`, `migrate-student-emails`
- **Spec:** `docs/superpowers/specs/2026-03-24-username-auth-bulk-create-design.md`
- **Plan:** `docs/superpowers/plans/2026-03-24-username-auth-bulk-create.md`

### Timezone & Streak Fix (2026-03-24)

#### Fixed
- **UTC→Istanbul timezone in `app_current_date()`/`app_now()`** — PostgreSQL `CURRENT_DATE` returns UTC. Between 00:00-03:00 Turkey time (UTC+3), server thought it was the previous day. Streak calendar showed wrong "today", daily_logins recorded wrong dates, streak didn't advance until 03:00. Fix: `CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Istanbul'`.
- **JSONB cast error breaking streak system** — `value::INT` failed on JSONB strings like `"3"` when `debug_date_offset` was set. This silently crashed `update_user_streak`, causing `daily_logins` to never be written. Fix: `(value #>> '{}')::INT` strips JSONB quotes.

#### Infrastructure
- **2 DB migrations** — `20260324000003` (timezone fix), `20260324000005` (JSONB cast fix)

### Admin Settings UX Improvements (2026-03-24)

#### Changed
- **XP settings grouped with sub-headers** — Admin settings screen now shows XP settings under labeled groups: "Reading XP", "Vocab Session XP", "Inline Activity XP", "Bonus XP". Uses `group_label` and `sort_order` columns for display ordering.
- **Setting descriptions** — All system_settings entries now have human-readable descriptions in the admin panel.

### Book Quiz Admin Integration & Dynamic XP Settings (2026-03-23)

#### Added
- **Admin quiz navigation** — Book editor right panel now shows a Quiz section above chapters. Displays quiz summary (question count, passing score, publish status) if exists, or "Create Quiz" button if not. Navigates to existing quiz editor routes.
- **`xp_quiz_pass` setting** — New system_settings entry for admin-configurable quiz pass XP (default 20)
- **`xpQuizPass` in SystemSettings** — Entity and model support for the new setting

#### Changed
- **XP values now read from SystemSettings at runtime** — `book_provider.dart` reads `xpChapterComplete`/`xpBookComplete` from `systemSettingsProvider` instead of hardcoded `AppConfig.xpRewards`. Admin panel XP changes now take effect at runtime.
- **Quiz XP moved from repository to controller** — `_handleQuizPassed` no longer awards XP/badges. `BookQuizController.submitQuiz` now handles this via `userControllerProvider.addXP()` with dynamic `SystemSettings.xpQuizPass`.
- **`attempt_number` now set by DB trigger** — `BEFORE INSERT` trigger on `book_quiz_results` replaces client-side COUNT query. UNIQUE constraint on `(user_id, quiz_id, attempt_number)` prevents duplicates under concurrent inserts.

#### Removed
- **`AppConfig.xpRewards` map** — Dead code. All XP values now come from SystemSettings.
- **15 unused system_settings entries** — `xp_activity_complete`, `xp_activity_perfect`, `xp_word_learned`, `xp_word_mastered`, `xp_streak_bonus_day`, `xp_assignment_complete`, `max_streak_multiplier`, `streak_bonus_increment`, `daily_xp_cap`, `default_time_limit`, `hint_penalty_percent`, `skip_penalty_percent`, `maintenance_mode`, `min_app_version`, `feature_word_lists`, `feature_achievements`. None had runtime consumers.
- **SystemSettings trimmed 21→6 fields** — Entity/Model only contains actively used settings. Admin panel auto-adapts (reads from DB dynamically).
- **AppConfig gamification constants** — `maxStreakMultiplier`, `streakBonusIncrement`, `dailyXPCap` removed (unused).

#### Infrastructure
- **4 new DB migrations** — `20260323000012` (quiz attempt trigger), `20260323000013` (xp_quiz_pass insert), `20260323000014` (delete 15 unused settings)

### Admin Quest Dashboard (2026-03-23)

#### Added
- **Quest management screen** — `/quests` route in admin panel with card-per-quest layout for inline editing of quest goals, rewards, active status, and sort order
- **Completion stats** — `get_quest_completion_stats` RPC shows today's completion count and 7-day average per quest
- **Dashboard card** — "Daily Quests" card on admin dashboard with active quest count

### Streak Freeze & Milestones (2026-03-23)

#### Added
- **Streak freeze system** — Users can buy up to 2 streak freezes (50 coins each, configurable via admin settings). Freezes are consumed automatically when a day is missed, preserving the streak.
- **Streak milestones** — Bonus XP at 7/14/30/60/100-day streaks (50/100/200/400/1000 XP), awarded via `award_xp_transaction` inside `update_user_streak` RPC
- **Streak event notifications** — Three dialog types on app open: milestone celebration, freeze-saved confirmation, tiered streak-broken messages (0-2 days: silent, 3-6: "Welcome Back!", 7-9: encouraging, 10-20: supportive, 21+: respectful)
- **Login tracking** — `daily_logins` table records each login date with `is_freeze` flag for calendar visualization
- **Streak calendar** — Fire icon tap shows weekly calendar with orange (login), blue (freeze), grey (inactive), faded (future) days. Today marked with arrow indicator.
- **Buy freeze UI** — Freeze count + buy button in streak dialog, disabled at max capacity or insufficient coins
- **`buy_streak_freeze` RPC** — Uses `spend_coins_transaction` for atomic coin deduction, reads price/max from `system_settings`
- **`previous_streak` in RPC** — `update_user_streak` now returns the streak value before it was broken, enabling tiered notification messages

#### Changed
- **Streak is now login-based** — Streak updates on app open only (not per-activity). Server-side `PERFORM update_user_streak()` removed from `complete_daily_review` and `complete_vocabulary_session` RPCs.
- **`refreshProfileOnly()` method** — New method on UserController for post-action profile refresh without triggering streak check. All callers (activity, vocab, review, cards, quest bonus) migrated.
- **Same-day guard** — `_updateStreakIfNeeded` skips RPC if `lastActivityDate` is already today

#### Fixed
- **async-in-fold bug** — `Either.fold` with async lambdas was dropping Futures. Profile re-fetch and event dialogs were unreliable. Extracted async body outside fold.
- **Double streak call** — `addXP()` no longer calls `updateStreak()` after XP award (server-side RPCs already handled it). Removed redundant call from `reader_provider` too.
- **Stale data flash** — Profile stays in loading state until streak check completes, preventing blue→orange calendar flash.

#### Removed
- **Rive mascot** from streak dialog (user preference)
- **Old `StreakResult`** from `edge_function_service.dart` and `checkStreak()` method (replaced by domain-layer entity)
- **`streakResetHours`** from `AppConstants` (dead config)

### Debug Time Offset (2026-03-23)

#### Added
- **`app_current_date()` / `app_now()`** — PostgreSQL helper functions that add `debug_date_offset` (from `system_settings`) to `CURRENT_DATE`/`NOW()`. All 8 business-logic RPCs updated to use these instead of raw time functions.
- **`AppClock` utility** — Flutter static utility (`AppClock.now()`, `AppClock.today()`) that shifts `DateTime.now()` by the same offset. Used in SM2 algorithm, assignment status, vocabulary due checks, streak calendar, and quest display.
- **Admin-configurable** — `debug_date_offset` setting in `system_settings` (app category). Set to 0 for production, non-zero for testing.

#### Fixed
- **JSONB cast bug** — `system_settings.value` is JSONB type. Direct `::INT` cast failed. Fixed with `(value#>>'{}')::INT` to extract scalar as text first.

### Daily Quest Engine (2026-03-22/23)

#### Added
- **DB-driven quest system** — Replaced hardcoded 3-quest daily goals with `daily_quests` table, `daily_quest_completions`, and `daily_quest_bonus_claims`. Admin can change goals/rewards via DB (Phase 2: admin UI).
- **Auto-completion with rewards** — `get_daily_quest_progress` RPC auto-completes quests and awards per-quest rewards (XP, coins, or card packs) when goal is met. No manual per-quest claim needed.
- **Quest completion popup** — Dialog shown when quests are newly completed, similar to level-up popup. Uses `ref.listen` pattern.
- **All-quests bonus** — Card pack awarded when all daily quests complete. Manual claim via `claim_daily_bonus` RPC with row-level locking.
- **Daily review edge case** — When no vocabulary words are due for review, the daily review quest auto-completes (nothing to do = success).
- **Clean Architecture** — Full stack: entity (`DailyQuest`, `DailyQuestProgress`), repository interface, 3 use cases, model, Supabase repository, providers, widgets.

#### Changed
- **Quest types updated** — `read_words` (unreliable word_count) → `read_chapters` (count daily reads); `correct_answers` (depends on activities) → `vocab_session` (count vocabulary sessions).
- **Vocabulary session invalidation** — `session_summary_screen.dart` now invalidates `dailyQuestProgressProvider` on session completion.

#### Fixed
- **Ambiguous column reference** — RPC `RETURNS TABLE` column names clashed with subquery table columns. Added explicit table aliases (`drs`, `iar`, `dqc`).
- **UI language** — Translated all quest UI strings from Turkish to English.

#### Removed
- **Old daily goal system** — Deleted `daily_goal_provider.dart`, `daily_goal_widget.dart`, `daily_tasks_list.dart`, `DailyGoalConfig`, `wordsReadTodayProvider`, `correctAnswersTodayProvider`, and 2 orphaned use case files.

### Admin Panel: Inline Activity Editor (2026-03-21)

#### Added
- **Inline activity editor** — Full CRUD for 4 activity types (True/False, Word Translation, Select Multiple, Matching) directly in the content block editor
- **Vocab-driven activity creation** — Word Translation and Matching activities auto-populate from vocabulary word selection; translation/meaning editable
- **Vocabulary word picker** — Autocomplete search widget with inline word creation (word + meaning_tr), creates `vocabulary_words` rows with `source: 'activity'`
- **Source tracking for vocabulary words** — New `source` column (`manual`, `import`, `activity`) with badge display ("AKTİVİTEDEN EKLENDİ") in vocab list
- **Chapter numbering** — Chapter list now shows "Chapter N:" prefix for clarity

#### Fixed
- **Activity block PopupMenuButton** — Wrapped in IgnorePointer to prevent tap interception
- **Activity type preservation** — `_blockActivityTypes` map survives DB refresh in content block editor
- **Case-insensitive word duplicate check** — Normalized to lowercase matching DB unique index
- **Word translation options shuffle** — Correct answer no longer always appears last

### Admin Panel: Recent Activity Page (2026-03-22)

#### Added
- **Recent Activity dashboard page** — `/recent-activity` with 2 summary cards + 10 section cards showing latest data across all major tables
- **Summary cards** — Today's active users (distinct from xp_logs) + this week's total XP
- **10 data sections** — Books, chapters, vocabulary, activities, assignments, new users, active users, activity results, reading progress, XP logs
- **Dedicated detail pages** — `/recent-activity/:sectionKey` with paginated lists (50 per page, load more)
- **Admin RLS policies** — SELECT access granted on `inline_activity_results`, `reading_progress`, `xp_logs` for admin users

### Admin Panel: Collectibles & Card Images (2026-03-22)

#### Added
- **Collectibles page** — Merged Badges + Myth Cards into tabbed `/collectibles` screen with compact grids (5-col badges, 6-col cards)
- **Card images in Supabase Storage** — 95 PNGs uploaded to `card-images` bucket, `image_url` column added to `myth_cards`
- **Card image upload** — File picker → Supabase Storage upload in card edit screen with preview
- **Dashboard simplified** — 5-column grid, removed standalone Ödevler + Mitoloji Kartları cards, added Son Etkinlikler + Koleksiyon cards

### SM-2 Consolidation & Stale State Fixes (2026-03-20)

#### Fixed
- **Wordbank not refreshing** — Words added via "I didn't know this" or vocab sessions were not appearing in Word Bank until app restart. Added `learnedWordsWithDetailsProvider` + `userVocabularyProgressProvider` invalidation to all write paths (reader popup, session summary, daily review, inline activities).
- **Leaderboard stale after XP earned** — League rankings didn't update after vocab sessions or daily review. Added `leaderboardEntriesProvider` invalidation after XP awards.
- **Daily Review navbar XP not updating** — `userControllerProvider.refresh()` was missing from `_completeSession()`, so coins/level stayed stale until user tapped "Continue".
- **SM-2 Easy/Good/Hard gave identical intervals** — Standard SM-2 gives the same 1-day interval for all buttons on first review. Modified to Anki-style: Easy=4d, Good=1d, Hard=reset on first review; Easy=10d, Good=6d on second.
- **Daily Review "last answer wins"** — Re-queued hard words could be overridden by a later Good/Easy answer. Changed to "first-answer-wins": first response is saved to DB, re-queue is reinforcement only.
- **"I didn't know this" didn't reset mastered words** — Clicking on a mastered word only updated `next_review_at` without resetting status. Now fully resets to `learning` state (rep=0, ease=2.5).
- **Daily Review XP inflation** — `correctCount`/`incorrectCount` included re-queued word responses, inflating XP. Added `firstPassCorrectCount`/`firstPassIncorrectCount` for accurate XP calculation.
- **Double-tap on Daily Review buttons** — No concurrency guard on `answerWord()`. Added `_isProcessingAnswer` flag.
- **Direct Supabase call in screen** — `_saveDrPosition()` in `daily_review_screen.dart` bypassed Clean Architecture. Moved to `VocabularyRepository.saveDailyReviewPosition()`.
- **Batch add didn't reset mastered words** — `addWordsToVocabularyBatch` with `immediate=true` only updated review date. Now resets full SM-2 state.

#### Changed
- **SM-2 algorithm centralized** — Moved `calculateNextReview()` from `VocabularyProgress` entity to `SM2` utility class in `sm2_algorithm.dart`. Entity is now a pure data holder.

#### Removed
- **Practice screen** — Removed `_FlashcardPracticeScreen` (I Know / Don't Know buttons) from Word Bank. It had no DB integration — answers were purely local with no SM-2 updates.
- **VocabularyReviewController** — Removed unused controller and state class that powered the Practice screen.

### Vocabulary Session Algorithm Improvements (2026-03-17)

#### Fixed
- **SM2 interval growth in sessions** — Strong words now use proper SM2 intervals (1d → 6d → 15d → mastered) instead of always resetting to 1 day. Words can now reach "mastered" status through vocabulary sessions.
- **XP farming exploit** — Repeating the same word list no longer grants infinite XP. Only the improvement over previous best score is awarded (high-score delta system).
- **Matching accuracy inflation** — Matching questions (4 words at once) now count as 1 question for accuracy calculation instead of 4, preventing the adaptive system from receiving inflated signals.

#### Changed
- **Combo system** — Wrong answers now reduce combo by 2 instead of resetting to 0, reducing the penalty for attempting harder production questions.
- **Matching XP** — Partial credit for matching: 3/4 correct now earns proportional XP instead of 0.
- **Faz 3 (Final) question limit** — Increased from 3 to 5, ensuring more weak words get tested before session ends.
- **Adaptive word selection** — Removed `isPerformingWell` skip that could bypass recognition questions for untested words. All words must pass recognition before advancing to bridge/production.
- **Summary screen** — Coins Earned now shows actual awarded XP (delta) from server response instead of client-side total.

#### Removed
- **"Practice Mistakes" button** — Removed from session summary screen; Faz 3's increased limit now handles weak word retesting within the session.

### Sentry Bug Fixes (2026-03-17)

#### Fixed
- **Sentry zone mismatch** — Moved `WidgetsFlutterBinding.ensureInitialized()` inside Sentry's `appRunner` to match zones
- **AudioService not initialized** — Added `audioServiceProvider.hasValue` guard to reader widgets (reader_audio_controls, reader_text_block)
- **Reader 3.4px overflow** — Reduced excessive bottom padding (140px → 96px) in reader content area
- **ref after dispose (session summary)** — Added `mounted` check before `ref.invalidate()` in vocabulary session save callback
- **ref after dispose (activity completion)** — Wrapped `handleInlineActivityCompletion` with StateError catch for disposed widgets
- **Inline activity 19px overflow** — Added `mainAxisSize: MainAxisSize.min` to activity wrapper Column

### Supabase Cloud Migration & Database Hardening (2026-03-16)

#### Infrastructure
- **Supabase Cloud migration** — Migrated from local Docker to remote Supabase Cloud (project: `wqkxjjakysuabjcotvim`, region: eu-central-1)
- **69 DB migrations** applied to remote (59 schema + 10 hardening)
- **7 Edge Functions** deployed to remote (6 existing + league-reset)
- **Seed data** loaded: 25 users, 4 books, 271 vocab words, 17 badges, 47 audio blocks
- **GEMINI_API_KEY + FAL_KEY + CRON_SECRET** configured as Edge Function secrets
- **League scheduler** — `league-reset` Edge Function + cron-job.org weekly trigger (Monday 00:00 UTC)
- **Sentry initialization** — `SentryFlutter.init()` in main.dart with K-12 privacy settings

#### Fixed (Security)
- **coin_logs INSERT RLS** — restricted to `user_id = auth.uid()` (was `WITH CHECK (true)`)
- **safe_profiles view** — hides email/student_number/coins from student peer access
- **get_teacher_stats auth** — enforces `auth.uid() = p_teacher_id` (prevents cross-school data leak)
- **inline_activity_results** — removed student DELETE permission (prevents XP gaming)
- **schools public SELECT** — replaced with `lookup_school_by_code()` RPC (was `USING (true)`)
- **Hardcoded FAL_KEY** — removed from generate-audio-sync and generate-chapter-audio Edge Functions

#### Fixed (Data Integrity)
- **Coin idempotency** — added partial unique index on coin_logs + idempotency check in `award_coins_transaction`
- **XP non-negative** — added `chk_xp_non_negative CHECK (xp >= 0)` constraint
- **TOCTOU race condition** — `award_xp_transaction` now locks row BEFORE idempotency check
- **Vocabulary uniqueness** — case-insensitive unique index `LOWER(word), meaning_tr`

#### Changed (Performance)
- **check_and_award_badges** — replaced FOR LOOP with set-based INSERT...SELECT
- **Composite indexes** — added 4 indexes for leaderboard, class queries, badge checks, coin history
- **League reset** — single-pass XP aggregation with temp table (was N×M nested loops)
- **XP constants consolidated** — merged AppConstants XP values into AppConfig.xpRewards

### League System & Leaderboard (2026-02-20)

#### Added
- **League tier system** — Weekly competitive leagues within schools, tier-based matchmaking (Bronze → Diamond)
  - `LeagueTier` enum in shared package with `dbValue`/`fromDbValue()` DB mapping
  - `league_history` table tracking weekly tier changes
  - `process_weekly_league_reset()` RPC for automated weekly promotions/demotions
  - Tier-scoped leaderboard RPCs: `get_weekly_school_leaderboard`, `get_user_weekly_school_position`
- **Leaderboard screen** — Three scopes (Class, School, League) with scope toggle
  - `LeaderboardScreen` + `LeaderboardListTile` widgets
  - `LeaderboardEntry` entity + `LeaderboardEntryModel` with JSON serialization
  - 4 new UseCases: `GetTotalLeaderboardUseCase`, `GetUserTotalPositionUseCase`, `GetWeeklyLeaderboardUseCase`, `GetUserWeeklyPositionUseCase`
  - `leaderboardDisplayProvider` combines entries + user position + scope state
- **Student profile popup** — Tap any leaderboard entry to see student stats dialog
  - `StudentProfileDialog` widget + `studentProfilePopupProvider`

#### Infrastructure
- **5 DB Migrations**: `20260217000001_create_league_system.sql`, `20260217000002_user_badges_school_rls.sql`, `20260218000001_league_school_based_reset.sql`, `20260218000002_fix_xp_idempotency_index.sql`, `20260218000003_league_tier_based_competition.sql`
- **Shared package**: `LeagueTier` enum added to `owlio_shared`
- **Router**: Leaderboard tab added to student shell

### Codebase Audit & Bug Fixes (2026-02-20)

#### Fixed
- **RLS security** — `user_badges` and `xp_logs` INSERT policies changed from `WITH CHECK (true)` to `WITH CHECK (user_id = auth.uid())` preventing cross-user data injection
- **Quiz XP not awarding** — Fixed RPC parameter name mismatch: `p_xp_amount` → `p_amount` in book quiz repository
- **Null crash on JSON parse** — Added null guards to 8+ model files (activity_result, assignment, pack_result, buy_pack_result, myth_card, content_block, student_summary)
- **Race conditions** — Replaced check-then-act patterns with atomic upsert in 3 repositories (book progress, vocabulary progress, word list progress)
- **Sign-out stale state** — `levelUpEvent` and `leagueTierChange` providers now cleared on sign-out
- **Streak update on failed XP** — `updateStreak()` now only called when XP award succeeds
- **Reader timer crash** — Added `mounted` guard before `ref.read` in timer callback
- **Home screen silent failures** — Added retry UI with "Could not load data" message and Retry button

#### Changed
- **Hard-coded strings eliminated** — All 13 Supabase repository files now use `DbTables.*` and `RpcFunctions.*` constants instead of raw string literals
- **Leaderboard provider** — Rewired from direct repository access to UseCase pattern (was the only architecture violation)
- **StudentAssignment enums consolidated** — Replaced duplicate enum definitions with typedefs to shared `AssignmentStatus`/`AssignmentType`
- **Dead UseCase cleanup** — Registered 4 orphaned UseCases in providers, deleted 1 superseded UseCase (`get_leaderboard_usecase.dart`)
- **DbTables completeness** — Added 7 missing table constants: `xpLogs`, `coinLogs`, `leagueHistory`, `vocabularySessionWords`, `chapterVocabulary`, `packPurchases`, `dailyQuestPackClaims`
- **Warnings cleaned** — Removed unused import and unused variable (0 errors, 0 warnings)

#### Infrastructure
- **1 DB Migration**: `20260220000001_fix_badge_xplog_rls.sql`
- **Seed data** expanded with league system test data

### Lexile Score Support (2026-02-14)

#### Added
- **Lexile score field** on books — full-stack addition: DB migration (`ALTER TABLE books ADD COLUMN lexile_score INTEGER`), entity, model, admin edit screen, main app display
- **Admin panel input** — `TextFormField` with 0–2000 validation in book edit screen
- **Book detail display** — Lexile shown as `820L` with speed icon in stats `Wrap` (replaced `Row` for graceful overflow)

#### Infrastructure
- **DB Migration**: `20260213100001_add_lexile_score.sql`
- **Seed data** updated — 4 books with appropriate Lexile values (320L, 350L, 480L, 300L based on CEFR mapping)
- **Test fixtures** updated — `validBookJson()`, `bookJsonWithNulls()`, `validBook()` include `lexile_score`

### Book Quiz System (2026-02-14)

#### Added
- **Book quiz backend** — Full Clean Architecture implementation for chapter-end quizzes
  - `BookQuiz`, `BookQuizQuestion`, `BookQuizResult`, `StudentQuizProgress` entities
  - `BookQuizModel`, `BookQuizResultModel`, `StudentQuizProgressModel` with JSON serialization
  - `BookQuizRepository` interface + `SupabaseBookQuizRepository` implementation
  - 5 UseCases: `GetQuizForBookUseCase`, `SubmitQuizResultUseCase`, `GetBestQuizResultUseCase`, `GetUserQuizResultsUseCase`, `BookHasQuizUseCase`
  - `bookQuizProvider` with state management for quiz session flow
- **5 question types** — Multiple choice, fill-in-blank, matching, event sequencing, who-says-what
- **Quiz widgets** — `BookQuizProgressBar`, `BookQuizResultCard`, `BookQuizMultipleChoice`, `BookQuizFillBlank`, `BookQuizMatching`, `BookQuizEventSequencing`, `BookQuizWhoSaysWhat`

#### Infrastructure
- **3 DB Migrations**: `20260211000001_create_book_quiz_tables.sql`, `20260211000002_add_quiz_passed.sql`, `20260211000003_quiz_rpc_functions.sql`
- **Admin quiz screens**: `book_quiz_edit_screen.dart`, `quiz_question_edit_screen.dart`

### Admin Panel Enhancements (2026-02-14)

#### Added
- **Role-Based Access Control (RBAC)** — Two-layer defense: login screen rejects non-admin/head-teacher users + router guard redirects unauthorized users
  - `currentUserRoleProvider` + `isAuthorizedAdminProvider` in `supabase_client.dart`
- **Myth Cards CRUD** — `card_list_screen.dart` (grid with rarity chips, category filter) + `card_edit_screen.dart` (full form with preview)
- **Assignments Viewer** — `assignment_list_screen.dart` (read-only teacher assignments) + `assignment_detail_screen.dart` (student progress table)
- **Units Management** — `unit_list_screen.dart` + `unit_edit_screen.dart` for vocabulary unit CRUD
- **Unit Books Management** — `unit_books_list_screen.dart` + `unit_books_edit_screen.dart` for unit-book assignments
- **Dashboard cards** for new features (Myth Cards, Assignments, Units, Unit Books, Quizzes)

#### Infrastructure
- **Shared Dart Package** (`packages/owlio_shared/`) — `DbTables`, `RpcFunctions`, and shared enums (`BookStatus`, `CardRarity`, `CefrLevel`, `UserRole`) used by both main app and admin panel
- **Router updated** with routes for cards, assignments, quizzes, units, unit-books

### Card Artwork Integration & Detail Popup Redesign (2026-02-14)

#### Changed
- **Real card artwork** - Replaced `picsum.photos` mock images with actual card artwork from `assets/images/cards/`
  - `MythCardModel.cardAssetPath()` maps card names to local asset paths (strips `'`, `()` for filename matching)
  - `PackResultModel` reuses same asset path logic for pack opening cards
  - `MythCardWidget._buildCardImage()` detects `assets/` prefix → uses `Image.asset()`, falls back to `Image.network()` for future remote URLs
- **Card detail popup** - Replaced scrollable bottom sheet with centered fullscreen dialog
  - Removed: card name, rarity badge, stats row (POWER/COPIES), lore/description section
  - Card artwork fills the dialog, tap anywhere to dismiss
  - `showDialog` with `barrierColor: Colors.black87` for immersive card viewing
- **Card corners** - Reduced `borderRadius` from 16px to 4px (card artwork no longer clipped by rounded corners)

#### Removed
- **`_DetailStatItem` widget** - No longer needed (card detail info removed from popup)
- **picsum.photos dependency** - Cards no longer require network for placeholder images

#### Infrastructure
- **pubspec.yaml** - Added `assets/images/cards/` to flutter assets
- 95 card artwork PNGs covering all 96 myth cards (Cerberus shared between Greek + Dark Creatures categories)

### Widget Rename & Dead Code Cleanup (2026-02-13)

#### Changed
- **Widget folder & file prefix convention** - All widget files now carry a group prefix for instant identification in IDE tabs and imports:
  - `activities/` → `inline_activities/` with `inline_` prefix (6 files, 5 classes renamed)
  - `reader/` widgets renamed with `reader_` prefix (12 files, 12 classes renamed)
  - `final_quiz/` → `book_quiz/` with `book_quiz_` prefix (8 files, 8 classes renamed)
  - `vocabulary/session/` widgets renamed with `vocab_` prefix (12 files, 12 classes renamed)
- **Shared widgets moved** - `activities/common/` → `common/` (AnimatedGameButton, FeedbackAnimation, ActivityCard)
- **Minor renames** - `CoinBadgeWidget` → `CoinBadge`, `DoodleBackground` → `SubtleBackground` (dead painter code removed)

#### Removed
- **Dead code** (5 unused widget files): `reader_content.dart`, `chapter_navigation_bar.dart`, `gamified_app_bar.dart`, `streak_display.dart`, `unit_path_widget.dart`

#### Infrastructure
- **CLAUDE.md** updated with new widget folder structure
- **Widgetbook** updated with all new class names and imports
- ~48 file operations total, 0 dart analyze errors

### Rive Dynamic Image Replacement Research (2026-02-11)

#### Added
- **Rive Dynamic Image Replacement Guide** - Comprehensive documentation for injecting network images into Rive animations at runtime
  - `CallbackAssetLoader` API verified against rive 0.13.20 source code
  - `ImageAsset.decode(Uint8List)` flow documented with fallback strategy
  - State machine input mapping (next trigger, flipped bool, holding bool)
  - Image slot mapping: C_K.png → card[0], C_Q.png → card[1], C_J.png → card[2]
  - Dart type inference workaround for unexported `FileAsset` class
  - Integration code examples with Dio download + CallbackAssetLoader + StateMachineController

#### Infrastructure
- **New Doc**: `docs/rive-dynamic-image-replacement.md` — full implementation guide for future pack opening Rive integration

### Vocabulary Session Mascot System + Sound Effects (2026-02-11)

#### Added
- **Rive Mascot Animations** - Owl mascot characters appear during vocabulary sessions as feedback overlays
  - **Incorrect answers**: 4 mascots (confused, frightened, angry, crying) cycle through shuffled pool, continuous Rive animation, size 185px
  - **Correct answers**: 3 mascots (cool, flying, kips) with freeze-frame capture + slide-right exit animation, size 257px
  - `vocabulary_mascot_overlay.dart` - Centralized widget: asset pools, `MascotPicker` (shuffle+cycle), `MascotOverlay` (3-phase animation lifecycle)
- **Streak Dialog Mascot** - Balloon owl Rive animation (280x280) in streak status popup with transparent background
- **Sound Effects** - `correctvoc.mp3` / `falsevoc.mp3` play on answer feedback via `just_audio`
- **Rive Package** - Added `rive: ^0.13.17` dependency, `assets/animations/mascot/` asset directory

#### Removed
- **TTS on Feedback** - Removed `FlutterTts` auto-speak from question feedback (replaced by sound effects)
- **Grass/Tree Scenery** - Removed `_GrassSceneryPainter` CustomPainter overlay from feedback panel (visual experiment, discarded)

#### Infrastructure
- **New File**: `lib/presentation/widgets/common/vocabulary_mascot_overlay.dart` (mascot constants, picker, overlay widget)
- **Rive Background Fix**: `artboard.fills.clear()` in `onInit` removes default white artboard backgrounds
- **Dynamic State Machine Detection**: Uses `artboard.animations.whereType<StateMachine>()` instead of hardcoded SM names
- **AnimatedSwitcher Cleanup**: Feedback panel animation unified to single source (AnimatedSwitcher), removed duplicate `.animate().slideY()`

### Pack Inventory System & Codebase Security Audit (2026-02-10)

#### Added
- **Pack Inventory System** - Users can now buy packs to inventory and open them later (instead of buy-and-open immediately)
  - `unopened_packs` column on profiles, `daily_quest_pack_claims` table with RLS policies
  - `BuyPackResult` entity, `BuyPackResultModel`, 3 new UseCases (`BuyPackUseCase`, `ClaimDailyQuestPackUseCase`, `HasDailyQuestPackClaimedUseCase`)
  - `buy_card_pack()` RPC (coins → inventory), `open_card_pack()` RPC refactored (consumes from inventory)
  - `claim_daily_quest_pack()` RPC for daily quest reward with idempotency via UNIQUE constraint
  - `has_daily_quest_pack_claimed()` RPC for server-side date check (avoids timezone mismatch)
  - `userCoinsProvider` + `unopenedPacksProvider` derived from user state (single source of truth)
  - Pack opening screen redesigned with buy/open separation, pack count badge, coin badge
  - Daily quest pack claim flow in `DailyTasksList` with animated reward row
- **Missing UseCase Provider** - `getSessionHistoryUseCaseProvider` registered for future session history UI

#### Fixed
- **SQL Injection in Book Search** - Added PostgREST filter character escaping to `searchBooks()` (matched existing vocabulary search pattern)
- **SQL Injection in .not() Filters** - Replaced string interpolation `'(${ids.join(',')})'` with SDK's `.not('id', 'in_', list)` in book and vocabulary repositories
- **12 Entities Missing Equatable** - Added `extends Equatable` + `props` to: `TeacherStats`, `TeacherClass`, `StudentSummary`, `StudentBookProgress`, `StudentVocabStats`, `StudentWordListProgress`, `Assignment`, `AssignmentStudent`, `CreateAssignmentData`, `PackResult`, `BuyPackResult`, `PackCard`
- **Duplicate Class Name Collision** - Renamed `MatchingPair` → `ActivityMatchingPair` (activity.dart) and `SessionMatchingPair` (vocabulary_session.dart)
- **Domain Layer Flutter Dependency** - Removed `dart:ui` import from `vocabulary_unit.dart`, moved `parsedColor` to `VocabularyUnitColor` extension in `ui_helpers.dart`
- **Client/Server Timezone Mismatch** - Daily quest pack claim check now uses server-side RPC (`has_daily_quest_pack_claimed`) instead of client-side date comparison
- **Missing Database Index** - Added composite index on `daily_quest_pack_claims(user_id, claim_date)` for query performance
- **Memory Leak Risk** - `packOpeningControllerProvider` changed to `autoDispose` (screen-specific state cleaned up on navigation)
- **Missing `toJson()`** - Added to `BuyPackResultModel` for serialization symmetry

#### Infrastructure
- **2 DB Migrations**: `20260209000007_add_pack_inventory.sql` (pack inventory + daily claims + 3 RPCs + index), `20260210000004_add_balance_constraints.sql`
- **New Files**: `buy_pack_result_model.dart`, `buy_pack_usecase.dart`, `claim_daily_quest_pack_usecase.dart`, `has_daily_quest_pack_claimed_usecase.dart`
- **Modified (32 files)**: Across all layers — entities, models, repositories, usecases, providers, screens, widgets, router, migration

### Sequential Lock System & Learning Path Improvements (2026-02-10)

#### Added
- **Sequential Lock System** - Full progression chain: Word List 1 → 2 → ... → N → Flipbook → Daily Review → Game → Treasure → Next Unit
  - `user_node_completions` DB table with RLS policies for tracking special node completions
  - `NodeCompletion` entity, `NodeCompletionModel`, 2 new UseCases (`GetNodeCompletionsUseCase`, `CompleteNodeUseCase`)
  - `nodeCompletionsProvider` + `completePathNode()` action in vocabulary_provider.dart
- **Unit Review Mode** - Cram review for all words in a unit via learning path Daily Review node
  - `DailyReviewScreen` accepts optional `unitId` for unit-scoped review
  - `loadUnitReviewSession()` in daily review controller (fetches all words in unit, ignores SRS scheduling)
  - `/vocabulary/unit-review/:unitId` route added to router
- **Learning Path Special Node Labels** - Side labels (left/right) on Flipbook, Review, Game, Treasure nodes matching word list label style

#### Changed
- **Learning Path** - Major refactor from single 1047-line file → 4 focused files:
  - `learning_path.dart` (orchestrator), `path_painters.dart` (background + connectors), `path_row.dart` (word list positioning), `path_special_nodes.dart` (Flipbook/Review/Game/Treasure)
- **Lock Visual Style** - Locked nodes show original icon in gray (not lock icon), making upcoming content visible
- **Daily Review Section** - Moved from vocabulary hub to home screen (under daily tasks)
- **Flashcard Completion Dialog** - Changed from Correct/Incorrect/Total → Easy/Good/Hard (matches self-assessment semantics)
- **Path Background** - Narrowed organic path width (140→100) and border stroke (8→6)
- **PathUnitData** - Now tracks `completedNodeTypes` set; `isAllComplete` requires both word lists AND all 4 special nodes
- **Word List Nodes** - Lock message updated: "Complete the previous unit" → "Complete previous steps"

#### Infrastructure
- **1 DB Migration**: `20260210000003_create_node_completions.sql` — node completions table with UNIQUE constraint, RLS, index
- **New Files**: `node_completion_model.dart`, `complete_node_usecase.dart`, `get_node_completions_usecase.dart`, `path_painters.dart`, `path_row.dart`, `path_special_nodes.dart`
- **Modified**: router.dart, vocabulary_repository (interface + impl), vocabulary_provider, usecase_providers, daily_review_provider, daily_review_screen, home_screen, vocabulary_hub_screen, learning_path, path_node

### Teacher Student Vocab Stats & Detail Improvements (2026-02-09)

#### Added
- **Student Vocabulary Stats** - Teacher can now see vocabulary progress per student
  - `StudentVocabStats` entity with word counts by status (new, learning, reviewing, mastered)
  - `StudentWordListProgress` entity with per-list progress, star rating, completion status
  - `GetStudentVocabStatsUseCase` + `GetStudentWordListProgressUseCase` (Clean Architecture)
  - `StudentVocabStatsModel` + `StudentWordListProgressModel` for JSON serialization
  - `studentVocabStatsProvider` + `studentWordListProgressProvider` in teacher provider
  - `_VocabStatsSection` + `_WordListProgressSection` widgets in student detail screen
- **Feedback Animation Widget** - Shared Lottie animation for correct/incorrect answers
  - `FeedbackAnimation` widget replaces inline TweenAnimationBuilder in 4 activity widgets + question feedback
  - Lottie files: `animation_success.json`, `animation_error.json`
- **Terrain Background** - `TerrainBackground` widget for vocabulary hub screen
- **Doodle Background** - `DoodleBackground` widget for decorative screen backgrounds
- **Lottie Animations** - `flipbook.json`, `game_controller.json`, `Treasure Box Animation.json` for learning path nodes
- **Card Collection Widgets** - `cards/` widget directory with 7 reusable card components (card_flip, card_reveal_effects, coin_badge, collection_progress, locked_card, myth_card, pack_glow)

#### Changed
- **Unit Curriculum Assignments** - `vocabularyUnitsProvider` now uses `GetAssignedVocabularyUnitsUseCase` to filter units by school/grade/class assignments (backward compatible: no assignments → all units shown)
- **Teacher Shell Router** - Refactored from nested GoRoute + StatefulShellRoute to top-level `StatefulShellRoute.indexedStack` with full paths (fixes Android key collision)
- **Teacher Dashboard** - "Browse Books" quick action → "My Classes" for more relevant teacher workflow
- **Teacher Reports** - `_QuickStatsCard` changed from `StatelessWidget` with `ref` parameter to `ConsumerWidget` (proper Riverpod pattern)
- **Learning Path** - Major visual overhaul:
  - Background path line connecting all nodes via `_PathPainter` custom painter
  - Flipbook node added between word list rows and game node per unit
  - Unit banner now shows locked state indicator
  - Path points collected for smooth background curve rendering
- **Path Node** - Visual redesign:
  - Font: Nunito → Patrick Hand (handwritten style), size 11→22px
  - Label color: conditional → white with text shadow
  - Node width: 92→140px, single-line text with `FittedBox`
  - START pill removed, side labels translated up for visual alignment
- **Library Screen** - Redesigned with category-based filtering:
  - New `selectedCategoryProvider` + `libraryFilteredBooksProvider` + `availableCategoriesProvider`
  - Category (genre) filter chips replace CEFR level filter
  - Layout restructured with genre-based book grouping
- **Vocabulary Hub Screen** - `TerrainBackground` wrapper replaces plain `AppColors.background`
- **Question Feedback** - Compact layout with reduced padding, `FeedbackAnimation` widget, correct answer displayed inline in Row
- **Activity Widgets** - All 4 activities (find_words, matching, true_false, word_translation) use shared `FeedbackAnimation` instead of inline animation code

#### Infrastructure
- **2 DB Migrations**:
  - `20260210000001_teacher_student_vocab.sql` - RPC functions for student vocab stats & word list progress
  - `20260210000002_create_unit_curriculum_assignments.sql` - Unit curriculum assignment table, RPC function, RLS, indexes
- **New Domain**: `GetAssignedVocabularyUnitsUseCase`, `GetStudentVocabStatsUseCase`, `GetStudentWordListProgressUseCase`
- **New Models**: `StudentVocabStatsModel`, `StudentWordListProgressModel`
- **New Widgets**: `FeedbackAnimation`, `TerrainBackground`, `DoodleBackground`, 7 card widgets
- **Modified**: router.dart, theme.dart, teacher entities/repo/provider, word_list repo, vocabulary_provider, usecase_providers, library_screen, vocabulary_hub_screen, student_detail_screen, vocabulary_session_screen, learning_path, path_node, question_feedback, 4 activity widgets

### Admin Panel — Word List & Curriculum Management (2026-02-09)

#### Added
- **Admin Panel** (`readeng_admin/`) - Full Flutter web admin panel for ReadEng content management
  - Dashboard with 10 management cards (Books, Schools, Users, Classes, Badges, Vocabulary, Word Lists, Unit Assignments, Settings, Gallery)
  - CRUD screens for: Books, Chapters, Schools, Users, Classes, Badges, Vocabulary, Word Lists, Unit Assignments
  - User import, vocabulary import screens
  - Gallery screen for developer tools
  - Authentication with Supabase, GoRouter navigation, Riverpod state management

#### Changed (in admin panel, this session)
- **Word List Edit Screen** - Unit assignment (unit dropdown + order_in_unit field), content completeness table showing field status per word, clickable words linking to vocabulary detail page
- **Word List List Screen** - Unit column + order column + unit filter, removed level filter and category column
- **Dashboard** - "Curriculum" card renamed to "Unit Assignments"
- **Curriculum List Screen** - Title: "Curriculum Assignments" → "Unit Assignments"

### Card Collection System — Mythology Cards (2026-02-08)

#### Added
- **Collectible Card System** - Gacha-style mythology card collection with rarities
  - Card catalog: 96 cards across 8 mythology categories (Greek, Norse, Egyptian, etc.)
  - 4 rarity tiers: Common, Rare, Epic, Legendary with distinct colors
  - Pack opening mechanic: 3 cards per pack, costs 100 coins
  - Pity system: guaranteed Epic+ after 15 packs without one
  - Card collection screen with category filters and completion tracking
  - Pack opening screen with immersive reveal animation
- **Coins Currency** - `coins` field added to User entity/model for in-app economy
- **InsufficientFundsFailure** - New failure type for purchase operations
- **Card rarity colors** in `AppColors` (cardCommon, cardRare, cardEpic, cardLegendary)
- **Card constants** in `AppConstants` (packCost, cardsPerPack, totalCardCount, pityThreshold)

#### Infrastructure
- **New Clean Architecture module**: entity (`card.dart`), repository interface + Supabase impl, 4 models, 6 UseCases, provider, 2 screens
- **6 DB migrations**: `add_coins_to_profiles`, `create_card_catalog`, `seed_myth_cards`, `create_user_cards`, `create_pack_opening_function`
- **Router**: New `/cards` shell branch + `/cards/open-pack` standalone route

### Matching Inline Activity (2026-02-08)

#### Added
- **Matching activity type** for reader inline activities (tap-to-match pairs)
  - `InlineActivityType.matching` enum value
  - `MatchingContent` + `MatchingPair` entities
  - Model serialization/deserialization support
  - `MatchingActivity` widget with pair-matching UI
- **Migration**: `add_matching_inline_activity_type.sql`

### Vocabulary Session Bug Fix (2026-02-08)

#### Fixed
- **Session stuck after retry question** — When the same word was asked with the same question type and options in the same order, `AnimatedSwitcher` key collided (because `SessionQuestion` extends `Equatable` → content-based `hashCode`). The old widget's `_answered = true` state persisted, making the UI non-interactive. Fix: replaced `question.hashCode` with monotonically-increasing `questionIndex` in the widget key.

### Code Quality & Routing Refactors (2026-02-08)

#### Changed
- **Route string elimination** — All ~30 screens now use `AppRoutes.xxxPath()` helpers instead of hardcoded route strings (e.g., `'/library/book/$id'` → `AppRoutes.bookDetailPath(id)`)
- **SnackBar consolidation** — All `ScaffoldMessenger.of(context).showSnackBar(...)` calls replaced with centralized `showAppSnackBar(context, message, type:)` across ~15 screens
- **Level-up detection** — `UserController.refresh()` now async, detects level changes and emits `LevelUpEvent` for celebration dialog
- **Post-session user refresh** — After vocabulary session and daily review completion, user state is refreshed to update XP/level/coins in navbar

#### Fixed
- **Badge earning conditions** — `levelCompleted` now checks actual user level, `dailyLogin` checks streak (was hardcoded `false`)
- **XP race condition in badges** — Badge repo now uses atomic `award_xp_transaction` RPC instead of read-then-write
- **Activity result duplicate** — Activity repo retries on unique_violation (23505) with fresh attempt number
- **Reading progress creation** — New progress now persisted to DB immediately (was in-memory only)
- **Inline activity duplicate XP** — Uses optimistic insert + DB UNIQUE constraint instead of check-then-insert
- **Vocabulary search injection** — PostgREST special characters now escaped in search queries
- **Daily word count query** — Optimized: fetches today's progress first (small set), then cross-references word lists
- **Debug prints removed** — Cleaned up leftover `print()` calls in user repository, replaced with `debugPrint`
- **Unused imports cleaned** — Removed ~10 unused repository/provider imports across screens

#### Infrastructure
- **3 DB migrations**: `restrict_content_blocks_rls`, `add_vocabulary_progress_status_check` (idempotent), `fix_content_blocks_rls_and_constraints`

### Reading Progress & Chapter Completion Fixes (2026-02-07)

#### Fixed
- **Chapter completion not persisting** (CRITICAL) - `chapterCompletionProvider` is `autoDispose`, but the notifier was captured via `ref.read()` BEFORE `await _saveReadingTime()`. During the async gap, Riverpod disposed the provider, making `_ref` invalid inside `markComplete()`. The catch block silently swallowed the error, so chapters were **never** marked complete.
  - Fix: Moved `ref.read(chapterCompletionProvider.notifier)` to AFTER the async gap in both `_handleNextChapter` and `_handleBackToBook`
- **Book detail showing stale data after close** - `_handleClose()` (X button) navigated to book detail WITHOUT invalidating `readingProgressProvider`, so cached stale data from before the chapter was completed was shown
  - Fix: Added `ref.invalidate(readingProgressProvider(bookId))` in `_handleClose()` and `_handleBackToBook()`
- **Missing UPDATE RLS policy on `daily_chapter_reads`** - `.upsert()` requires both INSERT and UPDATE RLS policies; only INSERT existed, causing silent failures when re-reading the same chapter on the same day

#### Infrastructure
- **New Migration** `20260207000003_fix_daily_chapter_reads_rls.sql` - UPDATE RLS policy for `daily_chapter_reads`
- **Modified**: `reader_screen.dart` (autoDispose timing fix + provider invalidation)

### Vocabulary Session v2 — Duolingo-Style Quiz System (2026-02-07)

#### Added
- **VocabularySessionScreen** - New quiz session replacing the old 4-phase vocabulary builder
  - 7 question types: multipleChoice, reverseMultipleChoice, listeningSelect, listeningWrite, matching, scrambledLetters, spelling, sentenceGap
  - Two-phase learning: Explore (word introduction pairs) → Practice (adaptive questions)
  - Combo system with XP multiplier, streak tracking, max combo recording
  - Progress bar with animated XP badge and combo indicator
  - Exit confirmation dialog to prevent accidental session loss
- **SessionSummaryScreen** - Post-session results with stats grid (coins, accuracy, max combo, time), per-word status report, and "Practice Mistakes" retry button
- **VocabularySessionState** entity - Immutable state with `WordSessionState` per word, `SessionQuestion` model, `QuestionType` enum, phase tracking
- **VocabularySessionController** - Riverpod `StateNotifier` managing session lifecycle: word introduction pairs, adaptive question generation, answer validation, XP calculation, combo tracking
- **7 Question Widgets**: `MultipleChoiceQuestion`, `ListeningQuestion`, `MatchingQuestion`, `ScrambledLettersQuestion`, `SpellingQuestion`, `SentenceGapQuestion`, `WordIntroductionCard`
- **Session Support Widgets**: `SessionProgressBar`, `ComboIndicator`, `QuestionFeedback` (Duolingo-style bottom sheet with auto-dismiss for correct, "GOT IT" for incorrect)
- **CompleteSessionUseCase** - Saves session results to DB (total questions, accuracy, max combo, XP, word-level results)
- **GetSessionHistoryUseCase** - Retrieves past session results for a word list
- **GetWeeklyActivityUseCase** - Fetches 7-day activity data for profile heatmap
- **TopNavbar** widget - Reusable Duolingo-style navbar with UK flag, streak counter, coin display, profile button
- **StreakStatusDialog** - Streak details popup from navbar

#### Changed
- **WordListDetailScreen** - Completely redesigned: session history list, word grid with mastery indicators, "Start Session" button replacing old phase-based navigation
- **WordList entity** - Simplified: removed `phase1-4Completed` fields, added `totalSessions`, `bestAccuracy`, `lastSessionDate`, `averageAccuracy`
- **WordListProgressModel** - Updated JSON serialization for new fields
- **Home/Library screens** - Now use shared `TopNavbar` widget instead of inline navbar code
- **Activity widgets** - Updated theming: Duolingo-style card borders, shadows, button styles across all inline activities
- **Path node** - Updated styling with Duolingo-inspired visual language

#### Removed
- **4-Phase Vocabulary System** - Deleted 4 screen files (~2,673 lines total):
  - `phase1_learn_screen.dart` (517 lines)
  - `phase2_spelling_screen.dart` (639 lines)
  - `phase3_flashcards_screen.dart` (749 lines)
  - `phase4_review_screen.dart` (768 lines)
- **CompletePhaseUseCase** - No longer needed (replaced by CompleteSessionUseCase)
- **Phase routes** - Removed `/vocabulary/list/:id/phase/:phase` routes from router

#### Infrastructure
- **New Migration** `20260207000002_vocabulary_session_v2.sql` - `vocabulary_sessions` table + `complete_vocabulary_session` RPC function
- **New Entity**: `vocabulary_session.dart` (VocabularySessionState, WordSessionState, SessionQuestion, QuestionType, SessionPhase)
- **New Model**: `vocabulary_session_model.dart`
- **New Provider**: `vocabulary_session_provider.dart` (VocabularySessionController)
- **Modified**: `router.dart`, `usecase_providers.dart`, `vocabulary_provider.dart`, `seed.sql`, `pubspec.yaml` (+confetti)

### XP → Coins UI Consistency (2026-02-07)

#### Changed
- **All XP displays now use coin icon** (`Icons.monetization_on`) consistently across the app:
  - `vocabulary_session_screen.dart`: XP badge in session header
  - `question_feedback.dart`: Correct answer reward display
  - `xp_badge.dart`: Floating XP earned animation (removed "XP" text suffix)
  - `activity_wrapper.dart`: Inline activity reward display
  - `session_summary_screen.dart`: "XP Earned" → "Coins Earned" stat card

### Home Screen Redesign — Duolingo-Style Daily Quest Cards (2026-02-07)

#### Changed
- **Daily Tasks → Quest Cards** - Replaced plain icon+label+badge rows with Duolingo-style quest cards
  - Each quest: 44px circle icon, bold title, gold progress bar with "X/Y" text overlay, treasure chest emoji
  - Progress bar uses `FractionallySizedBox` fill with gold (`AppColors.wasp`) color
  - Completed quests: gold border tint, check icon, gift emoji
  - All quests inside a single unified card with dividers between rows (not separate cards)
- **Assignments merged into Daily Tasks** - `DailyGoalWidget` now watches `activeAssignmentsProvider`
  - Assignment quest rows appear above daily quests with type-based tinted background
  - Assignment types have distinct icons/colors: book (blue), vocabulary (secondary), mixed (green)
  - Progress bars show assignment completion, due date text overlay ("2 days left" / "Due today" / "Overdue")
  - Thick divider separates assignment rows from daily quest rows
  - Tapping assignment still navigates to detail screen
- **Loading skeleton** matches new unified card layout (circle + progress bar shimmer rows)

#### Removed
- **Separate "Assignments" section** from home screen — assignments now inside daily tasks card
- **`_AssignmentCard`** class from `home_screen.dart` (replaced by `_AssignmentQuestRow` in `daily_tasks_list.dart`)
- **"Daily Tasks" section header** from home screen
- **Quest header text** ("Complete your daily quests!" / "X Daily Quest complete!")
- **"DAILY QUESTS" label divider** between assignments and daily quests

#### Infrastructure
- **Modified Files**: `daily_tasks_list.dart` (full redesign), `daily_goal_widget.dart` (watches assignments), `home_screen.dart` (cleanup)
- **No backend changes** — all providers, use cases, entities unchanged

### Vocabulary Learning Path Improvements (2026-02-07)

#### Changed
- **Linear path layout** - Each word list gets its own row (1 node per row instead of 1-3)
- **PathUnitData.isAllComplete** getter added for unit completion tracking
- **Profile screen** - Updated with new stats layout
- **Seed data** - Expanded vocabulary units and word lists

### Duolingo-Style Vocabulary Learning Path (2026-02-06)

#### Added
- **Vocabulary Learning Path** - Duolingo-style vertical skill tree replacing horizontal card sections
  - Word lists organized into admin-created **units** with colored banners (icon, name, description)
  - Zigzag node layout using sinusoidal positioning (`sin(rowIndex * pi/3) * amplitude`)
  - 1-3 nodes per row: same `order_in_unit` value = side-by-side nodes
  - Three visual states: completed (gold/check), in-progress (unit color/progress arc), not-started (grey outline)
  - Progress rings using Flutter's `CircularProgressIndicator` with rounded stroke caps
  - Dashed vertical connectors between rows
- **VocabularyUnit Entity** - New domain entity with `parsedColor` getter (hex string to Flutter Color)
- **vocabulary_units DB Table** - Admin-managed units with sort_order, color (hex), icon (emoji), is_active flag
  - RLS policy: SELECT for all authenticated users
  - `word_lists` table extended with `unit_id` FK and `order_in_unit` column
- **GetVocabularyUnitsUseCase** - Clean Architecture usecase for fetching active units
- **Learning Path Providers** - `vocabularyUnitsProvider` + `learningPathProvider` (combines units, word lists, progress)
  - `PathUnitData` and `PathRowData` data classes for structured path representation

#### Changed
- **VocabularyHubScreen** - Replaced `_HorizontalListSection` + `_CategoriesGrid` with `LearningPath` widget
  - Kept: navbar, daily review section, daily limit indicator, story vocabulary section
- **WordList Entity** - Added `unitId` and `orderInUnit` fields
- **WordListModel** - Added `unit_id` and `order_in_unit` JSON serialization

#### Removed
- **Unused Hub Widgets** - `_HorizontalListSection`, `_WordListCard`, `_CategoriesGrid`, `_CategoryCard`, `_EmptyState`, `_WordBankButton`

#### Infrastructure
- **New Migration** `20260207000001_create_vocabulary_units.sql` - vocabulary_units table + word_lists ALTER
- **Seed Data** - 3 sample units (Basics, Everyday English, Reading Level Up) with 4 word lists assigned
- **New Files**: `vocabulary_unit.dart` (entity), `vocabulary_unit_model.dart` (model), `get_vocabulary_units_usecase.dart`, `learning_path.dart`, `path_node.dart`
- **Modified Files**: `word_list.dart`, `word_list_model.dart`, `word_list_repository.dart`, `supabase_word_list_repository.dart`, `usecase_providers.dart`, `vocabulary_provider.dart`, `vocabulary_hub_screen.dart`

### Reader & Library UI Improvements (2026-02-06)

#### Changed
- **Library Screen Navbar** - Added Duolingo-style navbar identical to home screen
  - UK flag, streak counter, XP indicator, profile button
  - Filter/search row moved below navbar
- **Library Grid Layout** - Changed from 2 columns to 3 columns per row
  - Adjusted card aspect ratio (0.6) for compact display
  - Book titles now allow 2 lines with ellipsis overflow
- **Reader Collapsed Header** - Reduced height from 100px to 44px
  - Removed empty space below collapsed header
  - Added chapter badge with "CHAPTER X" label and title
  - Progress bar and session stats (reading time, XP) in collapsed view
- **Reader Header Chapter Card** - Redesigned from full card to compact badge overlay
  - Chapter badge now overlays book cover image (top-left)
  - Removed redundant progress info from expanded header
- **Audio Player Position** - Moved from bottom to top center (below collapsed header)
  - Animation slides from top instead of bottom
- **Inline Audio Icon** - Changed from play_circle_filled to headphones_rounded
- **Image Block Padding** - Reduced vertical padding for tighter content spacing
- **Content Top Padding** - Reduced from 24px to 8px in ReaderConstants

#### Added
- **Section Headers** - Library screen now has gradient line section headers
  - "Filter by Level" section header
  - "Library" section header before book grid
- **Chapter Badge Component** - `_ChapterBadge` widget for book cover overlay
  - Compact white card with subtle shadow
  - Purple "CHAPTER X" label + chapter title

#### Fixed
- **Header Collapse Animation** - Fixed overflow errors during scroll
  - Added ClipRect wrapper with Clip.hardEdge
  - Linear opacity transition (no more abrupt disappearance)
- **Book Detail Progress Section** - Hidden when progress is 0%
  - Checks `completionPercentage > 0` before showing "Your Progress"

### Book Completion UI & Assignment Sync (2026-02-03)

#### Added
- **Green Checkmark on Completed Books** - Library now shows checkmark indicator on completed books
  - New `GetCompletedBookIdsUseCase` following Clean Architecture pattern
  - New `completedBookIdsProvider` for efficient completed book ID fetching
  - `BookGridCard` and `BookListTile` support `isCompleted` parameter
  - Green circle with white check icon overlay on book covers
- **Assignment Sync Provider** - Auto-fixes stale assignment data on homepage load
  - `assignmentSyncProvider` detects completed books with incomplete assignments
  - Automatically marks assignments as complete when book is finished
  - Triggers on homepage load to ensure data consistency
- **Overdue Assignment Filter** - Assignments >3 days past due hidden from active list
  - `getActiveAssignments` now filters out overdue assignments older than 3 days
  - Reduces clutter in student assignment view

#### Changed
- **Book Detail FAB** - "Continue Reading" button hidden when book is completed
  - Added `isCompleted` parameter to `_BookDetailFAB`
  - Students see no FAB for completed books (teachers still see "Assign Book")
- **Books You Might Like** - Now uses `recommendedBooksProvider` instead of mock logic
  - Properly excludes books user has started reading
  - Limits to 4 books for clean display
- **Provider Invalidation** - Reading progress changes now refresh home screen immediately
  - Added `ref.invalidate(continueReadingProvider)` in reader navigation handlers
  - Added `ref.invalidate(recommendedBooksProvider)` for recommendation updates
  - No more hot reload required to see "Continue Reading" updates

#### Fixed
- **Async Fold Anti-Pattern** - Fixed critical bug where async callbacks in `fold()` weren't awaited
  - `markComplete()` in `ChapterCompletionNotifier` now properly awaits assignment updates
  - `_updateAssignmentProgress()` extracts values before async operations
  - Root cause of assignments not updating when books were completed
- **Continue Reading Not Updating** - Fixed stale provider cache issue
  - `continueReadingProvider` now invalidated after saving reading time
  - Changes visible immediately without hot reload

#### Infrastructure
- **New UseCase**: `lib/domain/usecases/book/get_completed_book_ids_usecase.dart`
- **Repository Update**: Added `getCompletedBookIds()` to `BookRepository` interface and Supabase implementation

### Word-on-Tap TTS Refactoring (2026-02-03)

#### Added
- **WordPronunciationService** - New dedicated service for word pronunciation using Flutter TTS
  - Device-based TTS (offline capable, uses device's built-in voice)
  - Volume ducking: main audio ducks to 20% during word speech
  - Web fallback timer (1500ms) for Chrome where completion handler may not fire
  - Auto-initialization with language detection and error handling
- **flutter_tts dependency** - Added `flutter_tts: ^4.0.2` for device TTS

#### Changed
- **Simplified word tap callbacks** - Removed unnecessary parameters from callback chain
  - Before: `onWordTap(word, position, timingIndex, blockId)`
  - After: `onWordTap(word, position)`
  - Affected files: word_highlight_text.dart, text_block_widget.dart, paragraph_widget.dart, content_block_list.dart, reader_body.dart, integrated_reader_content.dart
- **WordTapPopup speaker icon** - Always enabled now (uses TTS, no longer depends on block audio)

#### Removed
- **AudioSyncController.playWord()** - Removed ~60 lines of complex word playback logic
- **ChapterResumeInfo** - Removed resume state management for word playback
- **isPlayingWord state** - Removed from AudioSyncState (no longer needed)
- **_resumeInfo and _resumeChapterPlayback()** - Removed chapter audio resume logic after word playback

#### Fixed
- **Word reads more than clicked word** - Now uses clean TTS pronunciation instead of segment-based audio
- **TTS timing issues** - Flutter TTS handles timing internally, no WordTiming dependency for pronunciation
- **Main audio interference** - Volume ducking (20%) instead of complex pause/resume logic
- **Spaghetti callback chain** - Simplified from 5+ files with 3 state providers to clean architecture

#### Infrastructure
- **Net code reduction**: ~150+ lines deleted, ~80 lines added
- **Files modified**: 12 files simplified, 1 new service created

### Audio System Refactoring (2026-02-03)

#### Changed
- **Consolidated Audio Controller** - Merged `ReaderAutoPlayController` into `AudioSyncController`
  - Single source of truth for audio state and auto-play logic
  - Removed `reader_autoplay_provider.dart` (175 lines deleted)
  - Auto-play now uses `Timer` instead of `Future.delayed` for proper cleanup
  - Added `onBlockCompleted` stream (replaces `audioCompletedBlockProvider` pattern)
- **Listening Mode Concept** - New `_isInListeningMode` flag for smarter auto-play
  - Auto-play only triggers when user is in active listening session
  - Prevents auto-play when user completes activity without ever starting audio
  - Pause/Stop exits listening mode, audio completion keeps it active
- **Encapsulated Word Resume** - Replaced 3 separate variables with `ChapterResumeInfo` class
  - Cleaner state management for word playback resume logic
- **Simplified ContentBlockList** - Removed orchestration responsibilities
  - Uses `audioSyncController.setBlocks()` and `onActivityCompleted()` directly
  - Reduced from 5 listeners to 2

#### Fixed
- **False Auto-Play on Activity** - Fixed audio auto-playing when user completes activity without ever pressing play
  - Root cause: Auto-play didn't check if user was in listening mode
  - Now requires `_isInListeningMode == true` for activity completion auto-play

### Reader Screen Bug Fixes & TTS Audio Seed Data (2026-02-03)

#### Fixed
- **Chapter Navigation Blocked** - Fixed ChapterCompletionCard not appearing when chapter has no activity at the end
  - Changed condition from `chapter.content != null && isChapterComplete` to just `isChapterComplete`
  - Content blocks system doesn't use `chapter.content` field
- **Auto-Listening on Resume** - Fixed audio auto-playing when returning to a chapter with existing progress
  - Added `hasExistingProgress` parameter to `ReaderAutoPlayController.initialize()`
  - Skips auto-play if user has completed activities
- **Block-Based Scrolling** - Fixed arbitrary 200px scroll after activity completion
  - New `_scrollToNextBlockAfterActivity()` scrolls to actual next content block
  - New `_scrollToNextBlockAfterAudio()` scrolls after audio completion
  - New `_scrollToEndMarker()` scrolls to ChapterCompletionCard area
  - Uses `Scrollable.ensureVisible()` with GlobalKeys per block
- **Audio Continues After Leaving** - Fixed audio continuing to play after navigating away
  - Added `_stopCurrentAudio()` in `_handleNextChapter()`, `_handleBackToBook()`, `_handleClose()`
  - Audio stops before navigation completes
  - `AudioService.stop()` now resets position to prevent resume
- **Word Timings Index Offset** - Fixed text displaying incorrectly (e.g., "IIammtheeWishhButterfly") in chapters 2+
  - Root cause: `word_timings` indices didn't account for leading quotes in text blocks
  - Fixed 12 content blocks with +1 offset for blocks starting with `"`
  - Affects karaoke highlighting in WordHighlightText widget

#### Added
- **TTS Audio Data in Seed** - 47 text blocks now have complete audio data
  - `audio_url` pointing to Fal AI generated audio files
  - `audio_start_ms` / `audio_end_ms` segment boundaries
  - `word_timings` JSONB for karaoke-style highlighting
- **Vocabulary Seed Data** - Added vocabulary extraction for 12 chapters
  - `chapters.vocabulary` JSONB field populated with ~10-15 words per chapter
  - ~100 vocabulary words added to `vocabulary_words` table for word-tap popup
  - Turkish translations included

#### Changed
- **ContentBlockList** - Major refactoring for block-based scrolling
  - Added `_blockKeys` map with GlobalKey per block ID
  - Added `_endMarkerKey` for scrolling to chapter end
  - Removed unused `scrollController` parameter and `_scrollToNewContent()` method

### Widgetbook UI Catalog & Bug Fixes (2026-02-03)

#### Added
- **Widgetbook Project** - Standalone UI catalog for all custom widgets
  - 17 widgets with 50+ use cases organized by category
  - Book Widgets: LevelBadge, BookGridCard, BookListTile
  - Common Widgets: StatItem, XPBadge
  - Activity Widgets: ActivityWrapper, TrueFalseActivity, WordTranslationActivity, FindWordsActivity
  - Reader Widgets: ChapterNavigationBar, ChapterCompletionCard, CollapsibleReaderHeader, ImageBlockWidget, ParagraphWidget, WordHighlightText, TranslateButton, VocabularyPopup
  - Light/Dark theme support, interactive knobs for props
  - `serve.command` for one-click local server startup

#### Fixed
- **Homepage Book Images** - Fixed book cover images not displaying on student homepage
  - Changed from `DecorationImage(NetworkImage())` to `Image.network()` with error handling
  - Library was working because it used different image loading pattern

#### Changed
- **CLAUDE.md** - Added Related Projects section with admin panel path reference

### Anki-Style Daily Review System (2026-02-03)

#### Added
- **Daily Review Feature** - Spaced repetition review system for vocabulary words
  - SM-2 algorithm with 3 responses: "I don't know!", "Got it!", "Very EASY!"
  - Max 20 words per session from words due for review
  - XP rewards: 5 XP per correct + 10 session bonus + 20 perfect bonus
  - Session tracking prevents duplicate rewards same day
- **DailyReviewScreen** - Flashcard-style UI adapted from Phase 3
  - Card flip animation for word/definition reveal
  - Progress indicator and session stats
  - Completion dialog with XP summary
- **VocabularyHubScreen Redesign** - New daily review section replaces due words banner
  - State 1: Completed today → success card with XP earned
  - State 2: No words due → "All caught up!" card
  - State 3: Words ready → prominent review card with count
- **Phase 4 Word Addition** - Completing Phase 4 adds words to vocabulary_progress for daily review
- **New Domain Layer** - `DailyReviewSession` entity, 3 new UseCases (`CompleteDailyReview`, `GetTodayReviewSession`, `AddWordsBatch`)
- **New Data Layer** - `DailyReviewSessionModel` with JSON serialization

#### Infrastructure
- **New Migration** `20260203000001_add_daily_review_sessions.sql`
  - `daily_review_sessions` table with unique constraint on (user_id, session_date)
  - `complete_daily_review` RPC function with atomic XP award and duplicate prevention
  - RLS policies for user data isolation
- **New Migration** `20260202000010_add_description_to_classes.sql` - Optional class description field

#### Changed
- **Seed Data Cleanup** - Removed 6 old books (The Little Prince, Charlotte's Web, etc.)
  - Only 4 content block books remain (The Magic Garden, Space Adventure, The Brave Little Robot, Ocean Explorers)
  - Fixed foreign key constraint violations by reordering INSERT statements
  - Updated vocabulary_words to use proper UUIDs in inline_activities

#### Removed
- **Outdated Documentation** - Removed stale refactor planning docs:
  - `docs/CLEAN_ARCHITECTURE_REFACTOR_PLAN.md`
  - `docs/CODE_REVIEW_2026-02-01.md`
  - `docs/REFACTOR_CHECKLIST.md`
  - `docs/businesslogicrefactoring.md`
  - `docs/features/reading-module.md`

### Gamification Features & Admin Fixes (2026-02-02)

#### Added
- **Profile Badges Section** - Student profile now displays earned badges grouped by category (reading, vocabulary, achievement, special)
  - Category-based color coding and icons
  - Empty state message when no badges earned
- **Level-Up Celebration System** - Tier-specific celebration dialogs when leveling up
  - Tier changes (every 5 levels) get special celebration with gradient backgrounds
  - Tier emojis: 🥉 Bronze, 🥈 Silver, 🥇 Gold, 💎 Diamond, 👑 Platinum
  - `LevelUpEvent` class tracks old/new level and tier changes
  - `LevelUpCelebrationListener` wrapper in app.dart
- **Streak Triggering on Activity** - Daily streak now updates after any activity completion
  - `updateStreak()` called in `addXP()` method
  - Badge checking triggered via `check_and_award_badges` RPC

#### Changed
- **Assignment Order** - Student assignments screen now shows: To Do → Completed → Overdue (was wrong order)
- **Admin Panel: Content Blocks Only** - Removed plain text content option when creating chapters
  - Chapters always use content blocks (`use_content_blocks: true`)
  - Simplified chapter creation flow

#### Fixed
- **Admin Settings Toggle** - Toggle switches now update UI immediately after save
  - Added `ref.invalidate(settingsProvider)` after successful DB update
  - Previously showed "saved" but switch position didn't change

#### Removed
- **xp_per_level Setting** - Removed unused setting from:
  - `SystemSettings` entity
  - `SystemSettingsModel`
  - `AppConfig`
  - Migration seed data
  - (Level calculation uses progressive formula, not flat xp_per_level)

### Teacher UX Improvements (2026-02-02)

#### Changed
- **Teacher Profile Stats** - Teachers now see teaching stats (Total Students, My Classes, Active Assignments, Average Progress) instead of gamification stats (XP, Level, Streak)
- **Teacher Dashboard** - Added "Browse Books" quick action button

#### Added
- **Teacher Book Assignment from Detail** - Teachers see "Assign Book" button in book detail screen instead of "Start Reading"
  - Clicking navigates to create assignment with book pre-selected
- **`isTeacherProvider`** - New provider to check if current user is teacher/admin
- **Library for Teachers** - Teachers can browse library without lock restrictions

#### Fixed
- **Wordlist Category Display** - Fixed category showing enum name instead of human-readable text (e.g., "Common Words" instead of "WordListCategory.commonWords")
- **Library Lock Banner** - Hidden for teachers who shouldn't see student lock messages

### Reader Screen Refactoring & Dead Code Cleanup (2026-02-02)

#### Changed
- **Reader Screen Refactored** - Major restructuring for Clean Architecture compliance
  - `reader_screen.dart` reduced from **613 lines to 215 lines** (-65%)
  - `build()` method reduced from 309 lines to ~50 lines
  - Extracted 4 new widget components for separation of concerns

#### Added
- **ReaderConstants** - Centralized hard-coded values (header heights, padding, colors)
- **ChapterCompletionCard** - Next chapter button and book completion celebration UI
- **ReaderPopups** - Vocabulary and word tap popup management
- **ReaderBody** - Main scrollable content with collapsible header

#### Fixed
- **Critical Runtime Bug** - Fixed `mounted` property usage in `ReaderAutoPlayController`
  - `StateNotifier` does not have `mounted` property (would throw runtime exception)
  - Removed invalid checks at lines 133 and 160

#### Removed
- **Dead Code Cleanup** (~1450 lines removed):
  - `sync_service.dart` + `.g.dart` - Never imported anywhere
  - `storage_service.dart` + `.g.dart` - Never imported anywhere
  - `game_config.dart` - Exported but never used
  - `mock_data.dart` - 1000+ lines, never imported
  - `nextAudioBlockProvider` - Defined but never used

### System Settings Integration (2026-02-02)

#### Added
- **SystemSettings Entity** - Centralized configuration for XP rewards, progression, game settings, and app config
  - 19 configurable values (xp_chapter_complete, daily_xp_cap, maintenance_mode, etc.)
  - Equatable for value comparison
  - Default values fallback when database unavailable
- **SystemSettingsRepository Interface** - Domain layer abstraction for settings access
- **SystemSettingsModel** - JSON/JSONB parsing with type conversion helpers
- **SupabaseSystemSettingsRepository** - Fetches settings from `system_settings` table
- **GetSystemSettingsUseCase** - Clean Architecture compliant usecase with NoParams
- **systemSettingsProvider** - FutureProvider for screens to access settings

#### Infrastructure
- **New Migration** `20260202000001_create_system_settings.sql`
  - `system_settings` table with key-value JSONB storage
  - RLS policies: read for all, modify for admins only
  - Seed data with 19 default settings across 4 categories (xp, progression, game, app)
- **Provider Registration** - Added to `repository_providers.dart` and `usecase_providers.dart`

### Multi-Meaning Vocabulary & Word-Tap Popup (2026-02-02)

#### Added
- **Multi-Meaning Word Support** - Same word can have different meanings from different books (e.g., "bank" = river edge vs financial institution)
  - `source_book_id` column links vocabulary words to source book
  - `part_of_speech` column for grammatical classification
  - UNIQUE constraint on `(word, meaning_tr)` prevents duplicate meanings
- **Word-Tap Popup** - Dark-themed popup showing word definition when tapped in reader
  - Multiple meanings displayed with book attribution (📖 Book Title)
  - Part of speech badge, Turkish meaning, example sentence
  - "I didn't know this" button adds word to vocabulary progress
  - Speaker icon for audio pronunciation (when available)
- **WordDefinition Entity** - New entity supporting multiple meanings
  - `WordMeaning` class for individual meaning entries
  - Backward-compatible getters (`meaningTR`, `meaningEN`, `partOfSpeech`)
  - `hasMultipleMeanings` computed property
- **LookupWordDefinitionUseCase** - Returns all meanings for a word from database
- **Dev Quick Login Buttons** - Debug-only buttons for 4 test users (Fresh, Active, Advanced, Teacher)
- **extract-vocabulary Edge Function** - Insert-if-not-exists logic (no longer overrides meanings)

#### Changed
- **VocabularyWord Entity** - Added `sourceBookId`, `sourceBookTitle`, `partOfSpeech` fields
- **VocabularyRepository** - Added `getWordsByWord()` for multi-meaning queries with book join
- **Word highlighting** - Vocabulary words now tappable in reader (shows popup)

#### Infrastructure
- **New Migration** `20260202000005_add_part_of_speech_to_vocabulary.sql`
- **New Migration** `20260202000006_multi_meaning_vocabulary.sql`
  - Drops `vocabulary_words_word_level_key` constraint
  - Adds `vocabulary_words_word_meaning_unique` constraint
  - Adds `source_book_id` foreign key to books table
  - Creates `idx_vocabulary_words_source_book` index

### Chapter-Level Batch Audio & Word Auto-Scroll (2026-02-02)

#### Added
- **Chapter-Level Batch Audio Generation** - Single API call for all text blocks in a chapter
  - `generate-chapter-audio` Edge Function combines blocks with delimiter, calls Fal AI once
  - Splits timestamps back to individual blocks with `audio_start_ms` / `audio_end_ms`
  - Consistent voice tone across entire chapter (no per-block variations)
  - Cost reduction: N blocks = 1 API call instead of N calls
- **Segment-Based Audio Playback** - Reader plays correct segment from chapter audio file
  - `AudioSyncController` tracks segment boundaries for each block
  - Auto-stops when reaching block's `audio_end_ms`
  - Seamless continuation to next block
- **Word-Level Auto-Scroll** - Active word stays visible during karaoke playback
  - `WordHighlightText` now StatefulWidget with GlobalKey per word
  - `Scrollable.ensureVisible` called on word change with 200ms animation
  - Word kept at 40% viewport height for comfortable reading
- **Smart Auto-Play on Re-entry** - Prevents annoying repeat auto-play
  - `autoPlayedChaptersProvider` tracks chapters auto-played this session
  - First entry: 3-second delay then auto-play
  - Re-entry: No auto-play (user can manually start)

#### Changed
- **ContentBlock Entity** - Added `audioStartMs`, `audioEndMs` fields for segment tracking
- **ContentBlockModel** - JSON serialization for new segment fields
- **Admin Panel** - "Generate Chapter Audio" button in ContentBlockEditor toolbar

#### Infrastructure
- **New Migration** `20260202000004_add_audio_segment_columns.sql`
  - Adds `audio_start_ms INTEGER` and `audio_end_ms INTEGER` to content_blocks
- **New Edge Function** `generate-chapter-audio/index.ts`
  - Batch processing with " ||| " delimiter
  - Character-to-word timestamp conversion per block

### Reader Auto-Play & Clean Architecture Refactor (2026-02-02)

#### Added
- **Inline Play Icon** - Compact circular play/pause icon at the start of each paragraph
  - Replaces full-width "Listen" button with 24x24 inline icon
  - Loading state with spinner, active state with filled background
- **Auto-Play on Chapter Load** - Audio begins automatically 3 seconds after entering a chapter
- **Auto-Continue After Audio** - Next paragraph's audio plays 500ms after current one finishes
- **Auto-Continue After Activity** - Next audio plays 1 second after activity completion
- **Auto-Scroll** - Content scrolls to keep active audio block visible
- **ReaderAutoPlayController** - New provider for auto-play orchestration
  - Configurable timing via `AutoPlayConfig` (initialDelayMs, afterActivityDelayMs, afterAudioDelayMs)
  - Centralized business logic for audio sequence management
- **Audio Completion Tracking** - `audioCompletedBlockProvider` for block completion events
- **Block Loading State** - `isBlockLoadingProvider` for showing loading indicators
- **ContentBlock.empty()** - Factory method for placeholder blocks

#### Changed
- **TextBlockWidget Layout** - Changed from Column to Row layout for inline icon placement
- **ContentBlockList** - Delegated auto-play logic to ReaderAutoPlayController (Clean Architecture)
- **AudioSyncController** - Added completion callback for auto-continue feature
- **ElevenLabs Voice** - Changed default voice from George to Michael

#### Infrastructure
- **Clean Architecture Compliance** - Moved business logic from widget to provider layer
  - Widget (ContentBlockList) now only handles UI and event delegation
  - Provider (ReaderAutoPlayController) handles timing, block selection, orchestration

### Audio Sync & Word-Level Highlighting (2026-02-02)

#### Added
- **ContentBlock Architecture** - New structured content system replacing plain text chapters
  - `ContentBlock` entity with types: text, image, audio, activity
  - `WordTiming` value object for audio-text synchronization
  - Database table `content_blocks` with word_timings JSONB field
- **Word-Level Highlighting (Karaoke)** - Real-time text highlighting during audio playback
  - `WordHighlightText` widget renders words with timing-based highlighting
  - Binary search O(log n) algorithm for active word lookup
  - Vocabulary words remain tappable (shows definition popup)
- **Audio Sync Provider** - `AudioSyncController` StateNotifier manages playback state
  - Position stream tracking with word index calculation
  - Playback speed control (0.75x to 2x)
  - Block-level audio loading and state management
- **Text Block Widget** - Renders paragraphs with inline play button
- **Content Block List** - Progressive reveal orchestration for content blocks
- **Audio Player Controls** - Floating player with progress bar, skip, speed controls
- **Edge Function: generate-audio-sync** - Fal AI TTS integration
  - Calls `fal-ai/elevenlabs/tts/eleven-v3` with timestamps
  - Merges multi-sentence timestamp data
  - Converts character timestamps to word-level timings
  - Saves audio URL + word timings to database

#### Fixed
- **Fal AI Response Parsing** - Fixed `timestamps` array handling (was expecting `alignment` object)
- **Multi-Sentence Timestamps** - Merge function combines timestamp entries from multiple sentences
- **RLS Policies** - Fixed content management access for teachers (was admin-only)
- **Books Schema** - Added `author` and `cover_image_url` columns

#### Infrastructure
- **5 New Migrations**:
  - `20260201000020_create_content_blocks.sql` - ContentBlock table
  - `20260201000021_migrate_content_to_blocks.sql` - Content migration
  - `20260202000001_fix_content_blocks_rls.sql` - RLS for authenticated users
  - `20260202000002_fix_content_management_rls.sql` - Teacher content management
  - `20260202000003_add_author_to_books.sql` - Author column
- **Admin Panel (readeng_admin/)** - Separate Flutter web app for content management
  - Book/Chapter CRUD with content block editor
  - Audio generation UI with Fal AI integration
  - CEFR level dropdown (A1-C2)

### Dependency Updates & Bug Fixes (2026-02-01)

#### Fixed
- **Reading Progress "Continue Reading" Bug** - Fixed condition that showed "Start Reading" even when user had started a book. Now checks for actual DB record instead of `completionPercentage > 0`
- **Chapter Completion Logic** - Chapters without inline activities now correctly mark as complete (was returning `false` when `totalActivities == 0`)
- **connectivity_plus 6.x API** - Updated `NetworkInfo` for new API that returns `List<ConnectivityResult>` instead of single value
- **Seed Data Email** - Added missing `email` field to all profile UPDATE statements in seed.sql

#### Changed
- **go_router pinned to 13.x** - Version 14.x breaks `StatefulShellRoute` API, kept at 13.2.5
- **Error Logging Added** - `_updateCurrentChapter` and `_saveReadingTime` now log errors via `debugPrint` instead of silent failure

#### Updated Dependencies
- flutter_riverpod: 2.4.9 → 2.6.1
- riverpod_annotation: 2.3.3 → 2.6.1
- go_router: 13.0.1 → 13.2.5
- connectivity_plus: 5.0.2 → 6.1.0
- flutter_secure_storage: 9.0.0 → 9.2.0
- just_audio: 0.9.36 → 0.9.40
- audio_session: 0.1.18 → 0.1.25
- sentry_flutter: 7.14.0 → 8.12.0
- posthog_flutter: 4.0.1 → 4.11.0
- flutter_lints: 3.0.1 → 5.0.0
- riverpod_generator: 2.6.0 → 2.6.5
- json_serializable: 6.7.1 → 6.9.0
- mockito: 5.4.4 → 5.4.6
- flutter_gen_runner: 5.4.0 → 5.8.0
- flutter_dotenv: 5.1.0 → 5.2.1

### Code Quality Fixes (2026-02-01)

#### Fixed
- **N+1 Query in Vocabulary Repository** - `getNewWords()` now uses single `.not('id', 'in', ...)` query instead of loop with `.neq()` for each word ID
- **Timer Error Handling** - Reader screen periodic save now catches errors with `catchError()` to prevent silent failures
- **AudioService Null Safety** - Methods now use `player` getter (throws StateError if not initialized) instead of `_player?` (silent fail)

### Clean Architecture Refactor - Phase 1 (2026-02-01)

#### Added
- **UseCase Layer Foundation** - Base `UseCase<Type, Params>` abstract class with `Either<Failure, T>` return type
- **4 Initial UseCases** - `ResetStudentPasswordUseCase`, `ChangeStudentClassUseCase`, `CreateAssignmentUseCase`, `SaveReadingProgressUseCase`
- **UseCase Providers** - Centralized `usecase_providers.dart` for dependency injection
- **Common Widgets** - Extracted `XPBadge` and `StatItem` for reuse across screens
- **Architecture Documentation** - Comprehensive refactor plan (`CLEAN_ARCHITECTURE_REFACTOR_PLAN.md`, `REFACTOR_CHECKLIST.md`)

#### Changed
- **CLAUDE.md Updated** - Added Clean Architecture rules, YASAK table, UseCase/Model templates
- **3 Screens Use UseCases** - `class_detail_screen`, `create_assignment_screen`, `reader_screen` now call UseCases instead of repositories
- **Provider autoDispose** - Added to 9 providers to prevent memory leaks

#### Removed
- **Mock Repositories Deleted** - 7 files (~1,380 lines): `mock_activity_repository.dart`, `mock_auth_repository.dart`, `mock_badge_repository.dart`, `mock_book_repository.dart`, `mock_user_repository.dart`, `mock_vocabulary_repository.dart`, `mock_word_list_repository.dart`

#### Fixed
- **Deprecated API** - `withOpacity()` → `withValues(alpha:)` in theme.dart
- **Lint Rule** - Removed deprecated `avoid_returning_null_for_future` from analysis_options.yaml

#### Infrastructure
- **Docs Reorganization** - Moved `readeng-prd.md`, `readeng-trd-v2.md`, `readeng-user-flows.md` to `docs/`
- **Edge Function** - `reset-student-password` Supabase function added
- **Migration** - `20260201000003_teacher_class_management.sql` for class management features

### Router & Navigation Fixes (2026-02-01)

#### Fixed
- **GoRouter GlobalKey Collision** - Resolved `!keyReservation.contains(key)` assertion failures
- **Shell-to-Shell Navigation** - Fixed `context.push()` causing key conflicts when navigating from standalone routes to shell-nested routes
- **Auth Timing Issue** - Added splash screen to prevent redirect racing during initial auth check
- **User Metadata Role** - Added `role` field to `raw_user_meta_data` in seed data for router role checks

#### Changed
- **Router Architecture** - Removed all explicit GlobalKeys, GoRouter manages internally
- **Auth State Handling** - Router now uses Supabase auth directly (not through Riverpod)
- **App Widget** - Changed `ref.watch` to `ref.read` for router to prevent unnecessary rebuilds
- **Navigation Pattern** - Use `context.go()` for cross-shell navigation, `context.push()` only within same shell

#### Infrastructure
- **Migration** - Added `created_at` column to `assignment_students` table

### Remove School Code Screen (2026-02-01)

#### Changed
- **Simplified Login Flow** - Removed school code entry screen entirely
- **Student Number Login** - Now globally unique (no school code needed)
- **Direct Login** - App starts at login screen, not school code

#### Removed
- `SchoolCodeScreen` - Deleted (no longer needed for login)
- `validateSchoolCode` method from AuthRepository
- `signInWithSchoolCode` replaced with `signInWithStudentNumber`

#### Infrastructure
- **Migration** - Added `profiles_student_number_unique` partial index
- **Auth Flow** - Student # lookup no longer requires school_id filter

### Book-Based Assignments & Library Locking (2026-02-01)

#### Changed
- **Simplified Assignment Creation** - Teachers now assign entire books (no chapter selection)
- **Assignment contentConfig** - Removed `chapterIds`, added `lockLibrary` boolean option
- **Progress Calculation** - Assignment progress now based on all chapters in book (not selected subset)

#### Added
- **Library Locking Feature** - Teachers can lock student library until assignment completed
- **BookLockInfo Provider** - `book_access_provider.dart` manages lock state for students
- **Locked Library Banner** - Students see banner explaining assignment lock
- **Locked Book UI** - Lock icon overlay on inaccessible books (grid & list views)
- **Locked Book Dialog** - Tap locked book shows explanation dialog
- **Locked Book Screen** - Full screen explaining lock with navigation to assignments

### Student Assignments & Auto-Progress (2026-01-31)

#### Added
- **Student Assignments Screen** - Students can view all assigned tasks (To Do / Overdue / Completed groups)
- **Assignment Detail Screen** - View task details, due date, progress, and navigate to content
- **Home Assignments Section** - Pending assignments displayed on HomeScreen with badge count
- **Auto Assignment Progress** - When student completes a chapter, assignment progress updates automatically
- **Assignment Completion** - When all required chapters are read, assignment is marked complete

#### Infrastructure
- **StudentAssignmentRepository** - Domain interface + Supabase implementation
- **Student Assignment Providers** - activeAssignmentsProvider, studentAssignmentDetailProvider
- **Chapter Completion Integration** - ChapterCompletionNotifier now updates assignment progress

### Phase 3: Teacher MVP (2026-01-31)

#### Added
- **Teacher Dashboard** - Stats cards (students, classes, assignments, avg progress), welcome header
- **Role-based Navigation** - Separate shell for teachers (Dashboard, Classes, Assignments, Reports)
- **Classes Screen** - View all classes with student count and average progress
- **Class Detail Screen** - View students in class with XP, level, streak, books read
- **Student Detail Screen** - Full student profile with reading progress per book
- **Assignments Management** - Create, view, delete assignments; assign to classes
- **Assignment Detail** - Student-by-student progress tracking with completion rates
- **Reports Hub** - 4 report types: Class Overview, Reading Progress, Assignment Performance, Leaderboard
- **TeacherRepository** - Full Supabase implementation for teacher operations
- **Assignment Seed Data** - 3 test assignments with student progress data

### Reader Persistence Fixes (2026-01-31)

#### Fixed
- **Activity State Persistence** - Completed activities now properly load when re-entering chapters (fixed provider caching + state reset timing)
- **Continue Reading Shows Completed Books** - Books are now removed from Continue Reading after all chapters completed (invalidate continueReadingProvider)
- **Reading Time Not Saved** - Fixed async callback in fold() not being awaited, added periodic save every 30s

#### Changed
- **Periodic Reading Time Save** - Reading time now saved every 30 seconds to prevent data loss
- **Navigation Saves Time** - Close button, Next Chapter, and Back to Book buttons now save reading time before navigating
- **Widget Key for Chapter** - IntegratedReaderContent now keyed by chapter.id to reset internal state on chapter change

### Code Quality & Bug Fixes (2026-01-31)

#### Fixed
- **Duplicate XP Prevention** - Two-layer defense: local state check + DB returns boolean to prevent awarding XP multiple times from same inline activity
- **Add to Vocabulary from Reader** - Vocabulary popup now actually persists words to database (searches word, creates progress record)
- **Badge Earning System** - Badge checking now triggers after XP award and streak update via `check_and_award_badges` RPC
- **Memory Leaks** - Added `dispose()` methods and `ref.onDispose()` callbacks for StreamControllers in auth repository and sync service
- **N+1 Query** - `getRecommendedBooks` now uses single `.not('id', 'in', ...)` query instead of loop
- **Perfect Scores Query** - Fixed badge repository's perfect score calculation (was using invalid filter)
- **XP Logs Column** - Fixed column name in badge repository (`reason` → `source`)

#### Changed
- **Env Validation** - `EnvConstants` now throws `StateError` on missing required values instead of returning empty strings
- **Turkish Text Removed** - All remaining Turkish error messages and UI text translated to English:
  - "Hepsini çevir" → "Translate all"
  - "+XP kazandın" → "You earned +XP"
  - "Bu rozet zaten kazanıldı" → "Badge already earned"
  - Various mock repository error messages

#### Added
- **Test Users Expansion** - 4 test users with different states (fresh, active, advanced, teacher)
- **Expanded Seed Data** - 36 inline activities across all books, reading progress, completed activities

### MockData Removal & Bug Fixes (2026-01-31)
- **InlineActivities Provider** - `getInlineActivities()` method added to BookRepository, reader now fetches activities from Supabase
- **MockData Eliminated** - All presentation layer MockData usages removed (reader_screen, integrated_reader_content)
- **Vocabulary Screen Fix** - AsyncValue handling fixed (was causing type errors with FutureProvider)
- **Slash Command** - `/update-docs-and-commit` custom command for automated documentation updates

### Full Supabase Repository Integration (2026-01-31)
- **SupabaseActivityRepository** - Activity results, XP awarding, best score tracking
- **SupabaseUserRepository** - XP management, streak calculation, leaderboard queries
- **SupabaseVocabularyRepository** - SM-2 spaced repetition, word progress tracking
- **SupabaseWordListRepository** - 4-phase vocabulary builder (learn, spelling, flashcards, review)
- **SupabaseBadgeRepository** - Badge earning logic, earnable badge checking
- **Provider Updates** - All 7 repository providers now use Supabase implementations
- **Table Name Fixes** - vocabulary_words, word_list_items, user_word_list_progress

### Local Supabase Integration (2026-01-31)
- **Environment Config** - `.env` updated to use local Supabase (`127.0.0.1:54321`)
- **SupabaseAuthRepository** - Full implementation with school code + email login
- **SupabaseBookRepository** - Full implementation with books, chapters, reading progress
- **Repository Providers** - Switched Auth and Book from Mock to Supabase implementations
- **Seed Data** - 6 books, 9 chapters, 9 inline activities, test user (test@demo.com)
- **Trigger Fix** - `handle_new_user()` now uses `public.profiles` for schema qualification
- **Test User** - `test@demo.com` / `Test1234` linked to Demo School (DEMO123, 2024001)

### Reader Screen Overhaul (2026-01-31)
- **Collapsible Header** - Expanded: kitap kapağı, başlık, chapter kartı; Collapsed: chapter info, XP, reading time, progress bar
- **Activity-based Progress** - Scroll yerine aktivite tamamlama oranına göre progress (%completed activities)
- **Chapter Completion Persistence** - `ReadingProgress.completedChapterIds` ile tamamlanan chapter'lar kaydediliyor
- **Chapter Locking** - Önceki chapter tamamlanmadan sonrakine geçiş engellendi (book detail'da kilit ikonu)
- **Next Chapter Navigation** - Reader sonunda "Sonraki Bölüm" butonu (tüm aktiviteler tamamlanınca)
- **Book Completion** - Son chapter tamamlanınca "Kitabı Tamamladın! 🎉" mesajı + XP summary
- **State Reset** - Chapter değişiminde activity state sıfırlanıyor (erken completion bug fix)
- **Settings Button** - SliverAppBar.actions'dan CollapsibleReaderHeader içine taşındı
- **Bottom Bar Removed** - Reader'dan bottom navigation bar kaldırıldı
- **Dev Bypass Auth** - `kDevBypassAuth` flag ile development'ta auth atlanabiliyor

### Fixed
- "Kitabı Tamamladın" mesajı aktiviteler tamamlanmadan görünme bug'ı düzeltildi
- Settings butonu chapter thumbnail ile çakışma sorunu giderildi
- Widget tree building sırasında provider modification hatası (Future.microtask ile çözüldü)

### Added
- Proje başlatıldı
- `CLAUDE.md` oluşturuldu - proje hafızası
- `.env` ve `.env.example` oluşturuldu
- Temel dökümanlar hazırlandı (PRD, TRD, User Flows)

### Infrastructure
- GitHub repo oluşturuldu: `Tsuruanni/Wonderlib`
- Supabase projesi kuruldu (Wonderlib - EU Central)
- Cloudflare R2 bucket oluşturuldu (readeng-media)
- Sentry projesi kuruldu (error tracking)
- PostHog kuruldu (analytics)

### UI/Flutter (2026-01-30)
- Flutter projesi oluşturuldu (Clean Architecture yapısı)
- GoRouter ile routing kuruldu (10 route tanımlı)
- Tema ve renk paleti uygulandı (mor/indigo primary)
- **Çalışan sayfalar:**
  - `/school-code` - Okul kodu giriş ekranı (tam işlevsel)
  - `/login` - Giriş ekranı, Email/Student # toggle (tam işlevsel)
  - `/` - Ana sayfa: XP, Streak, Level stats + Continue Reading + Quick Actions
  - `/profile` - Profil sayfası: Avatar, stats, sign out

### UI/Flutter - Major Update (2026-01-30)
- **Bottom Navigation** eklendi (StatefulShellRoute)
  - 4 tab: Home, Library, Vocabulary, Profile
  - Tab state korunuyor (scroll position, etc.)
  - Reader/Activity tam ekran açılıyor
- **Library sayfası** tam implementasyon
  - Grid/List view toggle
  - CEFR seviye filtreleme (A1-C2)
  - Arama fonksiyonu
  - LevelBadge widget (seviyeye göre renk)
  - BookGridCard, BookListTile widgets
- **Book Detail sayfası** tam implementasyon
  - SliverAppBar ile collapsible cover image
  - Kitap bilgileri (author, level, duration, word count)
  - Reading progress indicator
  - Chapter list with completion status
  - "Start/Continue Reading" FAB
- **Reader sayfası** tam implementasyon
  - Vocabulary highlighting (tıklanabilir kelimeler)
  - VocabularyPopup (kelime tanımı)
  - Reader settings (font size, line height, theme)
  - 3 tema: Light, Sepia, Dark
  - Chapter navigation bar (progress, prev/next)
  - Scroll-based progress tracking

### Vocabulary & Daily Tasks (2026-01-30)
- **Vocabulary sayfası** tam implementasyon
  - Kelime listesi (Tümü/Tekrar/Yeni tabs)
  - Status göstergeleri (new, learning, reviewing, mastered)
  - Kelime detay sheet (anlam, fonetik, örnek cümle)
  - Flashcard pratik modu (doğru/yanlış değerlendirme)
  - Stats kartı (toplam, ustalaşılan, öğreniliyor)
- **Günlük Görevler widget'ı** - Home sayfasında
  - 10 dakika oku
  - Kelime tekrarı
  - Aktivite tamamla
  - Progress barlar ve tamamlanma durumu
- **UI Polish** - Türkçe çeviriler (Home sayfası)

### Inline Activities - Microlearning System (2026-01-30)
- **Yeni aktivite sistemi** - paragraflar arasına inline aktiviteler
  - `TrueFalseActivity` - Doğru/Yanlış soruları
  - `WordTranslationActivity` - Kelime çevirisi (çoktan seçmeli)
  - `FindWordsActivity` - Kelime bulma (multi-select chips)
- **Progressive reveal** - aktivite tamamlanmadan sonraki içerik görünmüyor
- **XP sistemi** - doğru cevaplarda XP animasyonu (+5 XP)
- **Auto-scroll** - aktivite tamamlandığında yeni içeriğe kayma
- **Kompakt UI** - minimal, mobile-friendly aktivite kartları
- **Arkaplan rengi** - doğru/yanlış duruma göre kart rengi değişiyor
- **Home butonu** - reader'da sol üste geri dönüş ikonu eklendi
- Mock data güncellendi (3 aktivite tipi için örnek veriler)

### Vocabulary Builder - 4-Phase Learning System (2026-01-30)
- **Wordela-inspired Vocabulary Builder** tam implementasyon
  - Phase 1: Learn Vocab - Grid view, kelime kartları, audio, definition toggle
  - Phase 2: Spelling - Dinleyerek yazma, responsive letter boxes, backspace handling
  - Phase 3: Flashcards - SM-2 flip cards, "I don't know / Got it / Very EASY" buttons
  - Phase 4: Review Quiz - Çoktan seçmeli + fill-in-blank, %70 geçme kriteri
- **Word List Hub** - Horizontal scroll cards, Continue Learning, Recommended, Categories
- **Word List Detail** - SliverAppBar, phase progress tracking, FAB navigation
- **Category Browse** - Word listelerini kategoriye göre listele
- **Progress Controller** - StateNotifier ile phase completion tracking
- **Navigation Flow** - Phase tamamlandığında pushReplacement ile sonraki phase'e geçiş

### Fixed
- Phase completion navigation - Continue to Next Phase butonu çalışıyor
- Spelling backspace - Focus widget ile onKeyEvent handling
- Horizontal card overflow - Container height 160→180px
- Header progress indicator - Bottom collision fix (top positioning)

### Known Issues
- ~~Home'da kitap adı "The Little Prince" ama kapak görseli "Fantastic Mr. Fox" (mock veri uyuşmazlığı)~~ ✅ Fixed - real data from Supabase
- ~~Supabase şeması henüz oluşturulmadı (tablolar boş)~~ ✅ Fixed - 21 tables created with seed data
- ~~Vocabulary "Add to vocabulary" henüz çalışmıyor (TODO)~~ ✅ Fixed - Reader popup now persists words

---

## [0.0.1] - 2026-01-30

### Added
- İlk commit
- Proje yapısı ve dökümanlar

---

<!--
Template for new entries:

## [X.X.X] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes in existing functionality

### Deprecated
- Soon-to-be removed features

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Security fixes
-->
