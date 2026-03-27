# Project Status

Son güncelleme: 2026-03-27 (Inline Activities audit & fixes)

## Current Phase

**Faz 5: Clean Architecture Refactor** 🔄 In Progress

## Roadmap

### Faz 0: Altyapı ✅
- [x] GitHub repo oluşturma
- [x] Supabase projesi kurulumu
- [x] Cloudflare R2 (medya storage)
- [x] Sentry (error tracking)
- [x] PostHog (analytics)
- [x] CLAUDE.md ve dökümanlar

### Faz 1: MVP Foundation ✅
- [x] Flutter proje oluşturma
- [x] Temel klasör yapısı (Clean Architecture)
- [x] Supabase bağlantısı (client kurulu, şema eksik)
- [x] Authentication UI (school code + login ekranları)
- [x] Temel UI shell (GoRouter, theme)
- [x] Bottom navigation (StatefulShellRoute, 3 tabs: Home, Library, Vocabulary)
- [x] Supabase database şeması oluşturuldu (21 tablo, local + seed data)

### Faz 2: Öğrenci MVP 🔄 (Aktif)
- [x] Dijital kütüphane (kitap listesi) - grid/list, filters, search
- [x] Okuma ekranı (sayfa görüntüleme) - reader with vocabulary
- [x] Anlık sözlük (kelimeye tıkla) - vocabulary popup
- [x] Inline aktiviteler (3 tip) - true/false, word translation, find words
- [x] XP ve seviye sistemi (UI + Supabase backend)
- [x] Profil sayfası (rebuilt: level progress, badges, stats, card preview)

### Faz 3: Öğretmen MVP ✅
- [x] Öğretmen dashboard
- [x] Sınıf listesi ve öğrenci takibi
- [x] Görev atama
- [x] Temel raporlar
- [x] Student assignment view (öğrenci tarafı)

### Faz 4: Admin & İçerik ✅
- [x] Admin panel (readeng_admin/ — Flutter web)
- [x] Okul/kullanıcı yönetimi (CRUD + import)
- [x] Kitap ekleme arayüzü (books + chapters + content blocks)
- [x] Vocabulary & Word List management
- [x] Unit Curriculum Assignments (school/grade/class scoping)
- [ ] İçerik pipeline (batch content creation)

### Faz 5: Clean Architecture Refactor 🔄
- [x] UseCase base class and initial 4 UseCases
- [x] Common widgets extraction (XPBadge, StatItem)
- [x] Mock repositories deleted
- [x] Provider autoDispose for memory leaks
- [x] Refactor plan documentation
- [ ] Model layer (JSON ↔ Entity separation)
- [ ] Complete UseCase layer (~48 total)
- [ ] Update all Providers to use UseCases
- [ ] Remove repository imports from all Screens

See: CLAUDE.md for architecture guidelines

### Faz 4+: İleri Özellikler (Deferred)
- [x] Kelime egzersizi modülü (4-Phase Vocabulary Builder)
- [x] Rozet sistemi (badge earning after XP/streak)
- [x] Sesli okuma / karaoke (word-level highlighting with Fal AI TTS)
- [x] Daily Review (Anki-style spaced repetition for vocabulary)
- [x] Vocabulary Learning Path (Duolingo-style zigzag skill tree with units)
- [x] Card Collection System (Mythology gacha cards with rarities + pack opening)
- [x] Pack Inventory System (buy-to-inventory, open later, daily quest rewards)
- [x] Matching Inline Activity (tap-to-match pairs in reader)
- [x] Unit Curriculum Assignments (school/grade/class-based unit filtering)
- [x] Teacher Student Vocab Stats (per-student vocabulary & word list progress)
- [x] Sequential Lock System (word list → special node → next unit progression)
- [x] Unit Review Mode (cram review for all words in a unit)
- [x] Book Quiz (chapter-end gamified quiz with 5 question types)
- [x] Widget naming convention (group prefixes: inline_, reader_, book_quiz_, vocab_)
- [x] Card artwork integration (real card images replacing mock placeholders)
- [x] Lexile score support (full-stack: DB, entity, model, admin, main app display)
- [x] Book Quiz system (5 question types, Clean Architecture, admin quiz editor)
- [x] Admin Panel RBAC (role-based access control, two-layer defense)
- [x] Admin Myth Cards CRUD (card list + edit with rarity preview + image upload)
- [x] Admin Assignments Viewer (read-only teacher assignments + student progress)
- [x] Inline Activity Editor (full CRUD for 4 activity types in content block editor)
- [x] Recent Activity Dashboard (12 sections with pagination detail pages)
- [x] Collectibles merged screen (badges + myth cards tabbed view)
- [x] Card images migrated to Supabase Storage (95 PNGs, `image_url` column)
- [x] Vocabulary source tracking (`source` column: manual/import/activity)
- [x] Daily Quest Engine (DB-driven quests, auto-completion, per-quest rewards, popup)
- [x] Admin Quest Dashboard (Phase 2 — inline editing, completion stats)
- [x] Streak Freeze & Milestones (buy/consume freezes, milestone XP, event dialogs, login tracking)
- [x] Debug Time Offset (system-wide app_current_date/app_now, AppClock, admin-configurable)
- [x] Book Quiz Admin Integration (admin navigation, atomic attempt_number, dynamic XP)
- [x] Dynamic XP Settings (all XP reads from system_settings, 15 unused settings removed)
- [x] Type-Based XP + Combo Refactor (per-activity → type-based, combo → session-end bonus, 12 new settings)
- [x] Notification Settings + Streak Extended (daily Day X! dialog, 7 admin-configurable notification toggles)
- [x] Admin Notification Gallery (dedicated /notifications page with preview cards)
- [x] Admin Units & Unit Books management (CRUD screens)
- [x] Shared Dart package (owlio_shared: DbTables, RpcFunctions, shared enums)
- [x] Username Auth & Bulk Student Creation (synthetic email pattern, admin user creation screen, CSV bulk import)
- [x] Admin Badge Improvements (dailyLogin removal, missing condition types, shared helper, per-badge stats, 3 new streak badges)
- [x] Badge Earned Notification (dialog with icon/name/XP, dialog queue, admin toggle, badge check at controller level)
- [x] Profile Screen Rebuild (8 sections, real data, LevelHelper, card previews, combined stats)
- [x] Avatar Customization System (layered PNG avatars, 6 base animals, 52 accessories, per-animal outfit memory, admin CRUD)
- [x] League system (weekly tier-based competition within schools)
- [x] Leaderboard screen (class/school/league scopes with student profile popup)
- [x] Codebase audit (RLS security, null safety, race conditions, architecture consistency)
- [x] Teacher Panel Audit & Fixes (security, atomicity, broken features, code quality — 15 migrations)
- [x] Teacher Profile Page (editable name, password reset, role badge, school name)
- [x] Class Management Redesign (edit/delete class, bulk move, login cards PDF, management vs report mode)
- [x] Assignment System Overhaul (unit type, mixed removal, dead code cleanup, sync activation, 8 RPCs, code review)
- [x] Teacher Panel Responsive Redesign (responsive layout, playful UI, sidebar nav, enriched reports, student profile deep links)
- [x] Vocabulary Hub Performance (N+1 elimination, batch book fetch, RPC merge, empty state UX)
- [x] Class Grade Enforcement (NOT NULL + CHECK(1-12), required grade on create/edit)
- [x] Assignment Notification System (in-app dialog on app open, direct detail navigation, admin toggle, gradient style)
- [x] Student Class Change Assignment Sync (DB trigger, withdrawn status, unit progress backfill, stats RPC updates)
- [x] Book System Audit & Integrity Fixes (38-finding audit, XP idempotency, RLS fix, 5 new UseCases, dead code removal, admin English)
- [x] Inline Activities Audit & Fixes (25-finding audit, data integrity, dead code removal (-628 lines), UX polish, admin validation)
- [ ] Offline mod (SyncService) - deferred
- [ ] Mobil app yayını
- [x] Remote Supabase deployment (`supabase db push`) ✅ 2026-03-16

## In Progress

| Task | Assignee | Status | Notes |
|------|----------|--------|-------|
| ~~Type-Based XP + Combo Refactor~~ | - | ~~Done~~ | ~~Implemented: 12 settings, combo refactor, RPC update~~ |
| ~~Teacher Panel Audit~~ | - | ~~Done~~ | ~~15 migrations, security fixes, class management redesign~~ |
| Testing & Validation | User | Active | Manual testing on remote Supabase |
| Main app card image migration | - | Pending | Switch from local assets to Storage URLs, remove 148MB assets |
| Username Auth — Flutter app deploy | - | Pending | Build & deploy new login screen, then run migrate-student-emails |

## Deferred

| Task | Notes |
|------|-------|
| Offline Mode | SyncService + Isar local storage |
| `completed_chapter_ids` refactor | UUID array → junction table (5+ Flutter files) |
| `assignments.content_config` refactor | JSONB → FK columns (9 Flutter files) |
| PostHog analytics integration | Dependency + key exist, needs init + event tracking |

## Blockers

| Blocker | Impact | Resolution |
|---------|--------|------------|
| ~~Supabase şeması yok~~ | ~~Auth ve veri akışı çalışmıyor~~ | ✅ Full Supabase entegrasyonu tamamlandı |

## Tech Debt

| Item | Priority | Notes |
|------|----------|-------|
| ~~Mock data uyuşmazlığı~~ | ~~Low~~ | ✅ Artık gerçek veri kullanılıyor |
| ~~"Add to vocabulary"~~ | ~~Medium~~ | ✅ Reader'da kelime ekleme çalışıyor |
| ~~Mock repositories~~ | ~~High~~ | ✅ Deleted 7 mock repository files |
| ~~withOpacity deprecated~~ | ~~Low~~ | ✅ Changed to withValues(alpha:) |
| ~~N+1 query in vocabulary~~ | ~~High~~ | ✅ Fixed - single query instead of loop |
| ~~Timer error handling~~ | ~~Medium~~ | ✅ Fixed - catchError added to reader |
| ~~AudioService null safety~~ | ~~High~~ | ✅ Fixed - uses getter with StateError |
| ~~Reading progress bug~~ | ~~High~~ | ✅ Fixed - Continue Reading condition, chapter completion logic |
| ~~connectivity_plus 6.x~~ | ~~Medium~~ | ✅ Fixed - Updated for new List<ConnectivityResult> API |
| ~~Screens importing repositories~~ | ~~High~~ | ✅ Route helpers + unused imports cleaned |
| ~~SQL injection in search queries~~ | ~~High~~ | ✅ PostgREST filter escaping added to book + vocab search |
| ~~Entities missing Equatable~~ | ~~High~~ | ✅ 12 entities fixed (teacher, assignment, card) |
| ~~Domain dart:ui dependency~~ | ~~Medium~~ | ✅ Moved parsedColor to presentation extension |
| ~~Duplicate MatchingPair class~~ | ~~Medium~~ | ✅ Renamed to ActivityMatchingPair + SessionMatchingPair |
| ~~Providers bypassing UseCases~~ | ~~High~~ | ✅ Leaderboard provider fixed, all providers now use UseCases |
| ~~Unsafe JSON type casts~~ | ~~High~~ | ✅ Null guards added to 8+ model files |
| ~~Race conditions in upserts~~ | ~~High~~ | ✅ Check-then-act replaced with atomic upsert in 3 repos |
| ~~Hard-coded table/RPC strings~~ | ~~Medium~~ | ✅ All 13 repos use DbTables/RpcFunctions constants |
| ~~RLS INSERT too permissive~~ | ~~Critical~~ | ✅ user_badges + xp_logs + coin_logs restricted to auth.uid() |
| ~~XP constants overlap~~ | ~~Medium~~ | ✅ All XP reads from SystemSettings (DB). AppConfig.xpRewards removed. |
| ~~Coin idempotency missing~~ | ~~High~~ | ✅ Partial unique index + idempotency check added |
| ~~Schools public visibility~~ | ~~High~~ | ✅ Replaced with lookup_school_by_code RPC |
| Server-side SM-2 mismatch | Medium | `complete_vocabulary_session` RPC uses different SM-2 formula than client (flat +0.02 ease vs quality-based, rep=1 vs rep=0 start). Needs migration to align with `SM2.calculateNextReview()` |
| ~~N+1 in assignmentSyncProvider~~ | ~~Low~~ | ✅ Debounced with 60s keepAlive, server-side progress calc |
| ~~`canStartWordListProvider` N+1~~ | ~~Medium~~ | ~~Per-list progress query still fires from PathRow. Batch data available but not yet wired~~ |
| Unnecessary break statements | Low | Lint warnings in switch cases |
| Legacy activity system coexistence | Medium | `activities`/`activity_results` (end-of-chapter) coexist with `inline_activities`. Deprecate legacy after all content migrated. |
| Offline quiz XP not queued | Low | Quiz pass offline saves result but does not queue `award_xp` pending action. XP lost until online retake. |
| XP balancing (quiz vs non-quiz books) | Low | Quiz-less books: 200 XP (book_complete). Quiz books: 20 XP (quiz_pass). Needs dedicated balancing session. |

## Recently Completed

| Task | Date | Notes |
|------|------|-------|
| Inline Activities Audit & Fixes | 2026-03-27 | 25-finding audit across all layers. Phase 1: DB index, correctness tracking (Map<String, bool>), finally block, save failure rollback + didUpdateWidget, words_learned population. Phase 2: dead code removal (-628 lines: UseCase, wrapper, entity, model, widgetbook), shared enum methods, guard clauses. Phase 3: sound feedback, loading placeholder, index-based matching, admin validation, English labels. 22/25 fixed, 2 accepted, 1 deferred. |
| Audio/Karaoke Reader Audit & Spec | 2026-03-27 | Full audit + spec for Feature #2. 5 findings fixed: audio error pill, dead code removal (showDropCap, 3 unused providers, 2 unused WordTiming methods), debug print cleanup. Spec covers two audio models, listening mode, karaoke sync, auto-play, scroll follow, offline caching. |
| Book System Audit & Integrity Fixes | 2026-03-27 | 38-finding audit across all layers. Phase 1: XP source_id idempotency (full addXP chain), RLS fix (no DELETE). Phase 2: 5 new UseCases (HandleBookCompletion, GradeBookQuiz, CompleteInlineActivity, DownloadBook, RemoveBookDownload), BookDownloadRepository, chapter lock provider, typed getters. Phase 3: error propagation, ErrorStateWidget, autoDispose (12 providers). Group D: dead code (-253 lines), enum dedup, author field, ActivityStats entity, ConsumerWidget, CachedBookImage, timezone fix, admin English translation. 37/38 resolved, 1 deferred. |
| Student Class Change Assignment Sync | 2026-03-27 | DB trigger on profiles.class_id change: withdraws old-class pending/in_progress assignments, enrolls in new-class active assignments, backfills unit progress. Stats RPCs exclude withdrawn. Flutter: withdrawn enum + UI + query filter. 1 migration, 4 Flutter files. |
| Assignment Notification System | 2026-03-27 | In-app notification when student opens app with active assignments. Event-based (follows streak/badge pattern), fires after other notifications via userControllerProvider listener. Single assignment → direct detail navigation (go()), multiple → list. Admin toggle via notif_assignment setting. Gradient dialog matching existing style. Back button fix for detail screen (canPop → home). 1 migration, 1 new widget, event provider. |
| Vocabulary Hub Performance + Class Grade Enforcement | 2026-03-27 | Blank screen root cause: classes.grade nullable → RPC returned 0 paths. Fixed with NOT NULL constraint. Performance: eliminated N+1 patterns (progressForList, bookById), merged getDueForReview into single RPC, derived storyWordLists from cache. Code review fixes: PathDailyReviewNode active state, ref.watch after await, published-only book filter. 3 migrations, 1 new usecase. |
| Assignment System Overhaul | 2026-03-26 | Replaced `mixed` with `unit` assignment type. Teachers assign learning path units; students complete word_list + book items. 8 new RPCs, server-side progress calc, bulk sync on creation, teacher student detail sheet, debounced sync provider. Full code review: architecture violation fixed, NULL safety, auth hardening. 8 migrations, 5 use cases, 4 entities. |
| Avatar Customization System | 2026-03-26 | Layered avatar with 6 base animals + 52 accessories across 5 categories. Per-animal outfit memory (JSONB). Auto-equip on purchase. Admin CRUD with live composite preview. AvatarWidget integrated in profile, leaderboard, student dialog. 9 migrations, 8 usecases, Clean Architecture. |
| Profile Screen Rebuild | 2026-03-25 | Complete rewrite: header (avatar/school/class), level progress bar (*100 formula fix), card collection with MythCardWidget previews, recent badges with bottom sheet, combined 4-stat card + Word Bank, daily review. LevelHelper utility, profileContextProvider. |
| Daily Quest Eligibility Fix | 2026-03-24 | daily_review quest hidden when < 10 due words, XP exploit closed, bonus claim aligned, pack claim date offset fixed. 2 migrations. |
| Performance: Parallel Data Fetching | 2026-03-24 | 7 N+1/sequential fixes across vocabulary hub, word bank, daily review, reader, leaderboard. 2 new batch repository methods + use cases. |
| Type-Based XP + Combo Refactor | 2026-03-24 | 12 new settings, inline XP from settings, vocab flat XP, combo session-end bonus, RPC reads bonuses from DB |
| Notification Settings + Streak Extended | 2026-03-24 | Daily "Day X!" dialog, 7 notification toggles in system_settings, settings-aware event gating |
| Admin Notification Gallery | 2026-03-24 | Dedicated /notifications page with 6 preview cards + toggles, dashboard card |
| Username Auth & Bulk Creation | 2026-03-24 | Synthetic email login, bulk-create-students Edge Function, admin creation screen, migrate-student-emails, dead student_number auth removed |
| Timezone & Streak Fix | 2026-03-24 | UTC→Istanbul in app_current_date/app_now, JSONB cast fix that silently broke daily_logins |
| Admin Settings UX | 2026-03-24 | XP settings grouped with sub-headers, descriptions added to all settings |
| Book Quiz Admin Integration | 2026-03-23 | Admin quiz navigation, DB trigger for atomic attempt_number, dynamic XP from SystemSettings |
| Dynamic XP & Settings Cleanup | 2026-03-23 | All XP reads from system_settings DB, 15 unused settings removed, SystemSettings 21→6 fields, AppConfig.xpRewards deleted |
| Admin Quest Dashboard | 2026-03-23 | Phase 2: quest list screen with inline editing + completion stats, dashboard card |
| Streak Freeze & Milestones | 2026-03-23 | Freeze purchase/consumption, milestone XP, tiered event notifications, daily_logins table, login-based streak, calendar visualization |
| Debug Time Offset | 2026-03-23 | app_current_date/app_now helpers, AppClock utility, 8 RPCs + 7 Flutter files updated, admin-configurable offset |
| SM-2 Consolidation & Stale State Fixes | 2026-03-20 | SM-2 centralized to `sm2_algorithm.dart`, Easy/Good/Hard differentiation, first-answer-wins DR, wordbank+leaderboard+navbar refresh fixes, practice screen removed, double-tap guard, mastered reset |
| Vocabulary Algorithm Improvements | 2026-03-17 | SM2 interval growth fix, XP farming prevention (high-score delta), combo softening (-2 vs reset), matching partial credit, Faz 3 limit 3→5, adaptive skip removed |
| Sentry Bug Fixes | 2026-03-17 | 6 bugs caught and fixed via Sentry: zone mismatch, AudioService init, reader overflow, ref-after-dispose (×2), activity overflow |
| Supabase Cloud Migration | 2026-03-16 | Local Docker → remote cloud (eu-central-1), 69 migrations, 7 Edge Functions, full seed data |
| Database Hardening | 2026-03-16 | 10 migrations: 5 security fixes, 3 integrity fixes, 2 performance optimizations |
| Tech Debt Cleanup | 2026-03-16 | Sentry init, XP constants consolidation, league scheduler, CLAUDE.md update |
| League System & Leaderboard | 2026-02-20 | Weekly tier-based leagues, 3-scope leaderboard, student profile popup, 5 migrations, 4 new UseCases |
| Codebase Audit & Fixes | 2026-02-20 | RLS security fix, quiz XP bug, null safety (8+ models), race conditions (3 repos), hard-coded strings (13 repos), enum consolidation |
| Lexile Score Support | 2026-02-14 | Full-stack: DB migration, entity, model, admin input (0-2000 validation), main app display with speed icon |
| Book Quiz System | 2026-02-14 | 5 question types, Clean Architecture (entities, models, repos, usecases, providers), admin quiz editor |
| Admin Panel Enhancements | 2026-02-14 | RBAC (login + router guard), Myth Cards CRUD, Assignments viewer, Units/Unit Books CRUD, Quizzes editor |
| Shared Dart Package | 2026-02-13 | `packages/owlio_shared/` with DbTables, RpcFunctions, 4 shared enums (BookStatus, CardRarity, CefrLevel, UserRole) |
| Card Artwork & Popup Redesign | 2026-02-14 | Real card images replacing picsum mocks, fullscreen detail dialog, reduced corner radius |
| Widget Rename & Cleanup | 2026-02-13 | Group prefixes (inline_, reader_, book_quiz_, vocab_), 5 dead files removed, shared widgets moved to common/, ~48 file operations |
| Rive Dynamic Image Guide | 2026-02-11 | CallbackAssetLoader API research, image injection docs for pack opening Rive integration |
| Vocabulary Mascot System | 2026-02-11 | Rive owl mascots on feedback, sound effects, streak dialog mascot, TTS removed |
| Pack Inventory System | 2026-02-10 | Buy packs to inventory, open later, daily quest pack rewards, 3 new RPCs, migration with RLS + index |
| Codebase Security Audit | 2026-02-10 | SQL injection fixes (2), Equatable added to 12 entities, duplicate class rename, domain dart:ui removed, timezone fix, autoDispose fix |
| Sequential Lock System | 2026-02-10 | Full progression chain with DB persistence, special node completion tracking, visual lock refinements |
| Unit Review Mode | 2026-02-10 | Cram review for unit words, daily review screen supports unitId param, wired to lock chain |
| Learning Path Refactor | 2026-02-10 | Split 1047-line file into 4 focused files (painters, row, special_nodes, orchestrator) |
| Daily Review → Homepage | 2026-02-10 | Moved daily review section from vocabulary hub to home screen under daily tasks |
| Teacher Vocab Stats | 2026-02-09 | Student vocabulary progress stats, per-list progress with star ratings, new entities/models/usecases |
| Unit Curriculum Assignments | 2026-02-09 | School/grade/class-based unit filtering, DB migration + RPC, admin CRUD screens, backward compatible |
| Learning Path Redesign | 2026-02-09 | Background path line, flipbook node, terrain background, Patrick Hand font, visual overhaul |
| Library Category Filter | 2026-02-09 | Genre-based filtering replaces CEFR level filter, category chips |
| Admin Panel Improvements | 2026-02-09 | Word list unit assignment, content completeness table, clickable words, level/category cleanup |
| Shared Feedback Animation | 2026-02-09 | Lottie-based FeedbackAnimation widget replaces inline animation in 5 widgets |
| Teacher Shell Router Fix | 2026-02-09 | Top-level StatefulShellRoute with full paths (fixes Android key collision) |
| Card Collection System | 2026-02-08 | Mythology gacha cards, 96 cards across 8 categories, pack opening, pity system, coins currency |
| Matching Inline Activity | 2026-02-08 | New tap-to-match activity type for reader with entity/model/widget support |
| Vocabulary Session Fix | 2026-02-08 | Fixed session stuck after retry (Equatable hashCode collision in AnimatedSwitcher key) |
| Route String Elimination | 2026-02-08 | All ~30 screens use AppRoutes.xxxPath() helpers instead of hardcoded strings |
| SnackBar Consolidation | 2026-02-08 | All SnackBars use centralized showAppSnackBar() across ~15 screens |
| Repository Bug Fixes | 2026-02-08 | Badge XP race condition, activity duplicate handling, reading progress persistence, vocab search injection |
| Vocabulary Session v2 | 2026-02-07 | Duolingo-style quiz system with 7 question types, combo system, replaces old 4-phase vocabulary builder (~2,673 lines removed) |
| Reading Progress Fixes | 2026-02-07 | Critical autoDispose bug fixed (chapters never marked complete), stale cache invalidation, UPDATE RLS policy for daily_chapter_reads |
| XP → Coins UI | 2026-02-07 | All XP displays now use coin icon consistently across 5 files |
| Home Screen Quest Cards | 2026-02-07 | Duolingo-style daily quest cards with progress bars, assignments merged into daily tasks widget |
| Learning Path Improvements | 2026-02-07 | Linear path layout (1 node/row), unit completion tracking, profile updates |
| Vocabulary Learning Path | 2026-02-06 | Duolingo-style zigzag skill tree, vocabulary_units table, unit grouping with sinusoidal layout |
| Reader & Library UI Improvements | 2026-02-06 | Duolingo navbar on library, 3-column grid, compact reader header (44px), chapter badge overlay, audio player repositioned |
| Book Completion UI & Assignment Sync | 2026-02-03 | Green checkmark on completed books, FAB hidden when complete, assignment auto-sync, async fold fix |
| Word-on-Tap TTS Refactoring | 2026-02-03 | Flutter TTS for word pronunciation, volume ducking, simplified callbacks |
| Audio System Refactoring | 2026-02-03 | Merged ReaderAutoPlayController into AudioSyncController, listening mode concept |
| Reader Screen Bug Fixes | 2026-02-03 | Chapter navigation, auto-play skip, block-based scrolling, audio stop on leave |
| TTS Audio Seed Data | 2026-02-03 | 47 text blocks with audio_url, word_timings for karaoke highlighting |
| Word Timings Index Fix | 2026-02-03 | Fixed offset issue for blocks starting with quotes |
| Vocabulary Seed Data | 2026-02-03 | ~100 words in vocabulary_words, chapter vocabulary JSONB populated |
| Widgetbook UI Catalog | 2026-02-03 | 17 widgets, 50+ use cases, standalone project in widgetbook/ |
| Homepage Image Fix | 2026-02-03 | Book covers now display correctly on student homepage |
| Daily Review System | 2026-02-03 | Anki-style spaced repetition, SM-2 algorithm, VocabularyHub redesign |
| Seed Data Cleanup | 2026-02-03 | Removed old books, fixed FK ordering, UUID vocabulary_words |
| Gamification Features | 2026-02-02 | Profile badges, level-up celebration, streak triggering |
| Admin Panel Fixes | 2026-02-02 | Settings toggle fix, removed plain text content option |
| Assignment Order Fix | 2026-02-02 | To Do → Completed → Overdue order |
| Teacher UX Improvements | 2026-02-02 | Profile stats, book assignment from detail, wordlist fix |
| Reader Screen Refactoring | 2026-02-02 | 613→215 lines, 4 new widgets, critical mounted bug fixed |
| Dead Code Cleanup | 2026-02-02 | ~1450 lines removed (sync_service, storage_service, game_config, mock_data) |
| System Settings Integration | 2026-02-02 | Clean Architecture: Entity, Repository, Model, UseCase, Provider for admin-configurable settings |
| Multi-Meaning Vocabulary | 2026-02-02 | Word-tap popup, multiple meanings from different books, dev quick login |
| Chapter-Level Batch Audio | 2026-02-02 | Single API call per chapter, consistent voice, cost reduction |
| Word-Level Auto-Scroll | 2026-02-02 | Karaoke scroll follows active word with 200ms animation |
| Smart Auto-Play | 2026-02-02 | Session tracking prevents repeat auto-play on re-entry |
| Reader Auto-Play | 2026-02-02 | Inline icon, auto-play on load, auto-continue after audio/activity |
| Clean Architecture (Reader) | 2026-02-02 | ReaderAutoPlayController, moved business logic from widget to provider |
| Audio Sync & Karaoke | 2026-02-02 | Word-level highlighting, Fal AI TTS, ContentBlock architecture |
| Admin Panel | 2026-02-02 | Separate Flutter web app for content management |
| Content Block System | 2026-02-02 | Replaces plain text chapters with structured blocks |
| Dependency Updates | 2026-02-01 | flutter_lints 5.0, sentry 8.x, connectivity_plus 6.x, etc. |
| Reading Progress Bug Fix | 2026-02-01 | "Continue Reading" condition, chapter completion for no-activity chapters |
| Code Quality Fixes | 2026-02-01 | N+1 query, timer error handling, AudioService null safety |
| Clean Architecture Phase 1 | 2026-02-01 | UseCase base, 4 UseCases, common widgets, mock cleanup |
| Refactor Plan Documentation | 2026-02-01 | CLEAN_ARCHITECTURE_REFACTOR_PLAN.md, REFACTOR_CHECKLIST.md |
| Router & Navigation Fixes | 2026-02-01 | GoRouter key collision fix, splash screen, auth timing |
| Remove School Code Screen | 2026-02-01 | Direct login, global unique student numbers |
| Book-Based Assignments | 2026-02-01 | Simplified to full book (no chapter selection), lockLibrary option |
| Library Locking | 2026-02-01 | Teachers can lock library until assignment completed, soft lock UI |
| Student Assignments | 2026-01-31 | Students can view/complete assigned tasks, auto-progress updates |
| Assignment Auto-Progress | 2026-01-31 | Chapter completion triggers assignment progress calculation |
| Phase 3: Teacher MVP | 2026-01-31 | Dashboard, Classes, Assignments, Reports (4 tabs) |
| Teacher Reports | 2026-01-31 | Class Overview, Reading Progress, Assignments, Leaderboard |
| Teacher Assignments | 2026-01-31 | Create, view, delete assignments with student progress |
| Class Management | 2026-01-31 | Classes list, class detail, student detail screens |
| Teacher Dashboard | 2026-01-31 | Stats cards, role-based navigation |
| Activity State Persistence | 2026-01-31 | Fixed caching + timing issues on chapter re-entry |
| Continue Reading Fix | 2026-01-31 | Completed books removed from list |
| Reading Time Persistence | 2026-01-31 | Fixed async issue, added periodic save |
| Duplicate XP Prevention | 2026-01-31 | Two-layer defense for inline activities |
| Add to Vocabulary | 2026-01-31 | Reader vocabulary popup now persists words |
| Badge Earning System | 2026-01-31 | Triggers after XP/streak changes |
| Memory Leak Fixes | 2026-01-31 | StreamController dispose callbacks |
| N+1 Query Fix | 2026-01-31 | getRecommendedBooks optimization |
| Test Users Expansion | 2026-01-31 | 4 users, 36 activities in seed data |
| Turkish Text Cleanup | 2026-01-31 | All UI/errors now in English |
| MockData Removal | 2026-01-31 | Presentation layer no longer uses MockData |
| InlineActivities Provider | 2026-01-31 | Reader activities fetched from Supabase |
| Full Supabase Integration | 2026-01-31 | All 7 repositories now use Supabase |
| SupabaseActivityRepository | 2026-01-31 | Activity results, XP awarding |
| SupabaseUserRepository | 2026-01-31 | XP, streak, leaderboard |
| SupabaseVocabularyRepository | 2026-01-31 | SM-2 spaced repetition |
| SupabaseWordListRepository | 2026-01-31 | 4-phase vocabulary builder |
| SupabaseBadgeRepository | 2026-01-31 | Badge earning system |
| Local Supabase Integration | 2026-01-31 | Auth + Book repos, seed data, test user |
| Reader Collapsible Header | 2026-01-31 | Expanded/collapsed states, book cover, chapter info |
| Activity-based Progress | 2026-01-31 | Progress = completed activities / total activities |
| Chapter Completion System | 2026-01-31 | completedChapterIds persistence, chapter locking |
| Next Chapter Navigation | 2026-01-31 | "Sonraki Bölüm" button, "Kitabı Tamamladın" message |
| GitHub repo | 2026-01-30 | Tsuruanni/Wonderlib |
| Supabase setup | 2026-01-30 | EU region, Wonderlib projesi |
| R2 bucket | 2026-01-30 | readeng-media |
| Sentry setup | 2026-01-30 | Flutter project |
| PostHog setup | 2026-01-30 | EU region |
| Docs structure | 2026-01-30 | CLAUDE.md, architecture, changelog |
| Flutter proje | 2026-01-30 | Clean Architecture yapısı |
| Auth UI | 2026-01-30 | School code + login ekranları |
| Home page | 2026-01-30 | Stats, continue reading, quick actions |
| Profile page | 2026-01-30 | Avatar, stats, sign out |
| UI Audit | 2026-01-30 | Playwright ile tam test yapıldı |
| Bottom Navigation | 2026-01-30 | StatefulShellRoute, 4 tabs |
| Library Page | 2026-01-30 | Grid/list, filters, search |
| Book Detail | 2026-01-30 | SliverAppBar, chapter list, FAB |
| Reader Page | 2026-01-30 | Vocabulary highlighting, settings, nav |
| Inline Activities | 2026-01-30 | 3 aktivite tipi, progressive reveal, XP animasyonu |
| Vocabulary Page | 2026-01-30 | Liste, flashcard pratik, stats |
| Daily Tasks | 2026-01-30 | Home sayfasında günlük görevler widget'ı |
| Profile refactor | 2026-01-30 | Profile tab kaldırıldı, AppBar'a taşındı |
| UI English | 2026-01-30 | Tüm UI metinleri İngilizce'ye çevrildi |
| Recommended Books | 2026-01-30 | Home'da kitap önerisi slider'ı |
| Vocabulary Builder | 2026-01-30 | 4-phase learning: Learn, Spelling, Flashcards, Review |
| Word List Hub | 2026-01-30 | Continue Learning, Recommended, Categories sections |
| Phase Progress | 2026-01-30 | StateNotifier ile progress tracking |

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-02-01 | Full Clean Architecture Refactor | Ensure maintainability, testability, future activity types |
| 2026-02-01 | Model/Entity separation | Decouple JSON parsing from domain, enable multi-source data |
| 2026-02-01 | Include Badge/XPLog in Model layer | Consistency across all entities |
| 2026-02-01 | Module-by-module refactor | Risk mitigation, independent testing per module |
| 2026-01-30 | Flutter + Supabase stack | Tek codebase, hızlı MVP, düşük maliyet |
| 2026-01-30 | Meilisearch atlandı | Supabase FTS yeterli, MVP için maliyet düşürme |
| 2026-01-30 | Learning Locker atlandı | MVP için gerekli değil, sonra eklenebilir |
