# Changelog

Tüm önemli değişiklikler bu dosyada kronolojik olarak tutulur.

Format: [Keep a Changelog](https://keepachangelog.com/)

---

## [Unreleased]

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
