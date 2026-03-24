# ReadEng Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                             │
│                    Flutter (Multi-platform)                     │
│              Android | iOS | Web | Desktop                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Riverpod │ GoRouter │ Isar (Local) │ Dio │ Hooks       │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       BACKEND LAYER                             │
│               Supabase Cloud (wqkxjjakysuabjcotvim)             │
│  ┌───────────┬───────────┬───────────┬───────────┬─────────┐  │
│  │PostgreSQL │   Auth    │  Storage  │ Realtime  │  Edge   │  │
│  │  + RLS    │(JWT/Magic)│ (Backup)  │(WebSocket)│Functions│  │
│  └───────────┴───────────┴───────────┴───────────┴─────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     EXTERNAL SERVICES                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │ Cloudflare  │  │   PostHog   │  │   Sentry    │            │
│  │     R2      │  │ (Analytics) │  │  (Errors)   │            │
│  │   (Media)   │  │             │  │             │            │
│  └─────────────┘  └─────────────┘  └─────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

## Application Structure

### Clean Architecture Layers

```
┌──────────────────────────────────────────────────────────────┐
│                     PRESENTATION                              │
│  Screens, Widgets, Providers (Riverpod)                      │
│  - UI rendering                                               │
│  - User input handling                                        │
│  - State management via Providers                             │
│  ⚠️ MUST NOT import repositories directly                    │
└──────────────────────────────────────────────────────────────┘
                              │ calls
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                       DOMAIN                                  │
│  Entities, UseCases, Repository Interfaces                   │
│  - Business logic in UseCases                                 │
│  - Platform-agnostic (no Flutter imports)                     │
│  - No external dependencies                                   │
│  - UseCases return Either<Failure, T>                         │
└──────────────────────────────────────────────────────────────┘
                              │ implements
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                        DATA                                   │
│  Models, DataSources, Repository Implementations             │
│  - Models: JSON ↔ Entity transformation                       │
│  - API calls (Supabase)                                       │
│  - Local storage (Isar)                                       │
└──────────────────────────────────────────────────────────────┘
```

### Data Flow (Correct Pattern)

```
Screen → Provider → UseCase → Repository Interface
                                      ↑
                         Repository Impl → Model → Supabase/Isar
```

**Rules:**
- Screens use Providers only (never repositories)
- Providers call UseCases
- UseCases depend on Repository interfaces
- Repository implementations use Models for JSON parsing
- Models have `toEntity()` and `fromJson()` methods

### Directory Structure

```
lib/
├── main.dart                 # Entry point
├── app/
│   ├── app.dart              # MaterialApp config
│   ├── router.dart           # GoRouter routes
│   └── theme.dart            # App theme
│
├── core/
│   ├── constants/            # API, app constants
│   ├── errors/               # Exceptions, failures
│   ├── network/              # API client, interceptors
│   ├── utils/                # Extensions, helpers
│   └── services/             # Storage, audio, sync
│
├── data/
│   ├── datasources/
│   │   ├── local/            # Isar databases
│   │   └── remote/           # Supabase calls
│   ├── models/               # JSON ↔ Entity transformation
│   │   ├── auth/             # UserModel
│   │   ├── book/             # BookModel, ChapterModel
│   │   ├── activity/         # ActivityModel
│   │   └── ...
│   └── repositories/
│       └── supabase/         # Supabase implementations
│
├── domain/
│   ├── entities/             # Pure business objects (no JSON)
│   ├── repositories/         # Repository interfaces
│   └── usecases/             # Business logic
│       ├── usecase.dart      # Base UseCase class
│       ├── auth/             # Auth UseCases
│       ├── book/             # Book UseCases
│       ├── reading/          # Reading UseCases
│       ├── activity/         # Activity UseCases
│       ├── vocabulary/       # Vocabulary UseCases
│       ├── teacher/          # Teacher UseCases
│       ├── assignment/       # Assignment UseCases
│       ├── content/          # ContentBlock UseCases
│       ├── card/             # Card collection UseCases (6)
│       ├── student_assignment/ # Student assignment UseCases
│       └── settings/         # SystemSettings UseCases
│
├── presentation/
│   ├── providers/
│   │   ├── usecase_providers.dart  # All UseCase providers
│   │   ├── repository_providers.dart
│   │   ├── audio_sync_provider.dart  # Audio playback + auto-play orchestration
│   │   ├── vocabulary_session_provider.dart  # Vocabulary quiz session state
│   │   └── *_provider.dart   # Feature providers
│   ├── screens/              # Page widgets (31 screens)
│   │   ├── cards/            # Card collection + pack opening
│   │   └── ...
│   └── widgets/
│       ├── book_quiz/        # BookQuiz* — final book quiz widgets (8)
│       ├── cards/            # Card collection widgets (CoinBadge, CardFlip, etc.)
│       ├── common/           # Shared widgets (AnimatedGameButton, FeedbackAnimation, SubtleBackground, XPBadge, TopNavbar)
│       ├── home/             # Home screen widgets (TopNavbar, BottomNavbar)
│       ├── inline_activities/ # InlineActivity* — in-chapter activities (6)
│       ├── vocabulary/       # Vocabulary path widgets
│       │   ├── learning_path.dart    # Duolingo-style zigzag path (orchestrator)
│       │   ├── path_painters.dart    # Background path + connector painters
│       │   ├── path_row.dart         # Word list node positioning
│       │   ├── path_node.dart        # Circle node with progress/stars
│       │   ├── path_special_nodes.dart # Flipbook/Review/Game/Treasure nodes
│       │   └── session/              # Vocab* — quiz session widgets (12)
│       └── reader/           # Reader* — reader-specific widgets (15)
│           ├── reader_body.dart               # Main scrollable content
│           ├── reader_popups.dart             # Vocabulary/word popups
│           ├── reader_chapter_completion.dart  # Next chapter UI
│           └── ...
│
├── l10n/                     # Localization
│
packages/owlio_shared/         # Shared Dart package (used by main app + admin)
├── lib/
│   ├── owlio_shared.dart      # Barrel export
│   └── src/
│       ├── constants/tables.dart  # DbTables, RpcFunctions
│       └── enums/                 # BookStatus, CardRarity, CefrLevel, UserRole, LeagueTier, AssignmentStatus, AssignmentType, ...
└── pubspec.yaml

readeng_admin/                 # Admin panel (separate Flutter web project)
├── lib/
│   ├── core/                  # Supabase client (+ RBAC providers), router
│   └── features/              # Feature modules (17 total)
│       ├── assignments/       # Teacher assignment viewer (read-only)
│       ├── auth/              # Login with RBAC enforcement
│       ├── badges/            # Badge CRUD
│       ├── books/             # Book + chapter + content block CRUD
│       ├── cards/             # Myth card CRUD
│       ├── classes/           # Class management
│       ├── curriculum/        # Unit curriculum assignments
│       ├── dashboard/         # Overview with feature cards
│       ├── quests/            # Daily quest management (inline editing + stats)
│       ├── gallery/           # Media gallery
│       ├── quizzes/           # Book quiz + question editing
│       ├── schools/           # School management
│       ├── settings/          # System settings
│       ├── unit_books/        # Unit-book assignments
│       ├── units/             # Vocabulary unit management
│       ├── users/             # User management + creation (single/bulk CSV) + progress tabs
│       ├── vocabulary/        # Vocabulary word management
│       └── wordlists/         # Word list management
├── pubspec.yaml
└── web/

supabase/functions/               # Edge Functions (Deno/TypeScript)
├── award-xp/                     # XP transaction orchestration
├── bulk-create-students/         # Bulk user creation (students + teachers) with auth.admin API
├── check-streak/                 # Streak validation
├── extract-vocabulary/           # AI vocabulary extraction
├── generate-audio-sync/          # TTS audio generation
├── generate-chapter-audio/       # Chapter-level audio
├── league-reset/                 # Weekly league tier reset
├── migrate-student-emails/       # One-time: migrate student emails to synthetic pattern
└── reset-student-password/       # Admin/teacher password reset

widgetbook/                   # Standalone UI catalog (separate Flutter project)
├── lib/
│   ├── main.dart             # Widgetbook app entry
│   └── components/           # Widget use cases
│       ├── book_widgets.dart
│       ├── common_widgets.dart
│       ├── activity_widgets.dart
│       └── reader_widgets.dart
├── pubspec.yaml              # Depends on main app via path: ..
└── serve.command             # One-click local server startup
```

### UseCase Pattern

```dart
// lib/domain/usecases/usecase.dart
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

class NoParams {
  const NoParams();
}
```

**Refactor Status:** See `docs/CLEAN_ARCHITECTURE_REFACTOR_PLAN.md`

## Core Data Flows

### 1. Authentication Flow

```
User enters school code
        │
        ▼
Validate school exists (Supabase)
        │
        ▼
User enters credentials
        │
        ▼
Supabase Auth → JWT Token
        │
        ▼
Store token (flutter_secure_storage)
        │
        ▼
Fetch user profile → Navigate to home
```

### 2. Reading Flow (Offline-First)

```
User selects book
        │
        ▼
Check Isar local DB
        │
   ┌────┴────┐
   │         │
Has data   No data
   │         │
   ▼         ▼
Return    Fetch from Supabase
local         │
   │         ▼
   │     Cache in Isar
   │         │
   └────┬────┘
        │
        ▼
Display book content
        │
        ▼
Track progress (save locally)
        │
        ▼
Queue for sync when online
```

### 3. XP & Gamification Flow

```
User completes action (page, chapter, activity)
        │
        ▼
Calculate XP amount
        │
        ▼
Call award_xp_transaction (PostgreSQL function)
        │
   ┌────┴────┬────────────┐
   │         │            │
Update   Log XP      Check badges
profile  history     eligibility
   │         │            │
   └────┬────┴────────────┘
        │
        ▼
Return new XP, level, badges
        │
        ▼
Update UI, show notifications
```

## Database Schema (Key Tables)

### Core Entities
- `schools` - Multi-tenant isolation
- `classes` - Student groupings
- `profiles` - User data + gamification stats

### Content
- `books` - Book metadata (title, author, level, cover_image_url, lexile_score)
- `chapters` - Book content (use_content_blocks flag)
- `content_blocks` - Structured content (text, image, audio, activity types)
  - `word_timings` JSONB - Audio-text sync data for karaoke highlighting
- `activities` - Comprehension exercises
- `vocabulary_words` - Word definitions (supports multiple meanings per word)
  - `source_book_id` - FK to books for meaning attribution
  - `part_of_speech` - Grammatical classification
  - `source` - Origin tracking: `manual`, `import`, `activity`
  - UNIQUE constraint on `(word, meaning_tr)` for deduplication
- `vocabulary_units` - Admin-created unit groupings for learning path
  - `sort_order` - Display order in path
  - `color` (hex), `icon` (emoji) - Visual theming
  - `is_active` - Soft delete flag
- `word_lists` - Extended with `unit_id` FK + `order_in_unit` for path positioning
  - Same `order_in_unit` within a unit = side-by-side nodes in learning path
- `unit_curriculum_assignments` - School/grade/class-based unit access control
  - Scoping: school-wide, grade-level, or class-specific
  - No assignments for a school → all units visible (backward compatible)
  - RPC: `get_assigned_vocabulary_units(p_user_id)` returns filtered unit IDs

### Progress
- `reading_progress` - Book completion tracking
- `activity_results` - Quiz answers and scores
- `vocabulary_progress` - Spaced repetition state (SM-2 algorithm)
- `daily_review_sessions` - Daily review session tracking (one per user per day)

### Assessment
- `book_quizzes` - Quiz definitions per book (title, passing score)
- `book_quiz_questions` - Quiz questions (5 types: multiple_choice, fill_blank, matching, event_sequencing, who_says_what)
- `book_quiz_results` - Student quiz attempts and scores

### Gamification
- `badges` - Badge definitions
- `user_badges` - Earned badges
- `xp_logs` - XP history
- `league_history` - Weekly league tier changes (promotion/demotion tracking)

### Card Collection
- `myth_cards` - Card catalog (96 mythology cards, `image_url` from Supabase Storage `card-images` bucket)
- `user_cards` - Owned cards per user
- `user_card_stats` - Collection stats (pity counter, total packs)
- `pack_purchases` - Pack purchase history
- `daily_quest_pack_claims` - Daily quest reward claims (legacy, replaced by bonus_claims)
- `coin_logs` - Coin transaction history

### Daily Quests
- `daily_quests` - Quest definitions (type, goal, reward, active flag). DB-driven, admin-configurable via `/quests` in admin panel.
- `daily_quest_completions` - Per-quest daily completion records with auto-awarded rewards
- `daily_quest_bonus_claims` - All-quests-complete bonus (card pack) claims
- RPCs: `get_daily_quest_progress` (auto-completes + awards), `claim_daily_bonus`, `get_quest_completion_stats` (admin)
- Quest types: `daily_review` (1 session), `read_chapters` (3 chapters), `vocab_session` (1 session)

### Streak & Login Tracking
- `daily_logins` - Records each day a user logged in (`login_date`, `is_freeze` flag). Used for streak calendar visualization.
- `profiles.streak_freeze_count` - Number of streak freezes the user currently holds (max configurable via `system_settings`)
- RPCs: `update_user_streak` (login-based, freeze consumption, milestone XP, daily_logins insert), `buy_streak_freeze`
- Milestones: 7/14/30/60/100 days → 50/100/200/400/1000 XP bonus

### Debug Infrastructure
- `app_current_date()` / `app_now()` — PostgreSQL helper functions reading `debug_date_offset` from `system_settings`. All business-logic RPCs use these instead of `CURRENT_DATE`/`NOW()`.
- `AppClock` — Flutter static utility applying the same offset client-side. Used in SM2 algorithm, assignment status, vocabulary due checks, streak calendar.

### Assignments
- `assignments` - Teacher-created tasks
- `assignment_students` - Student-task mapping

## Security Model

### Row Level Security (RLS)
- All tables have RLS enabled
- Users can only access data within their school
- Students see own progress, teachers see class progress
- Admins have full access within school scope

### Authentication
- Supabase Auth with JWT
- School code + credentials for login
- Tokens stored in secure storage
- Auto-refresh on expiry

## Admin Panel (owlio_admin/)

Separate Flutter web project for content management.

### Key Features
- **Content Block Editor** — Visual chapter editor with text, image, and inline activity blocks (drag-reorder)
- **Inline Activity Editor** — Vocab-driven forms for 4 activity types (True/False, Word Translation, Select Multiple, Matching)
- **Vocabulary Management** — Word CRUD with AI generation, CSV import, source tracking
- **Recent Activity** — Dashboard page with 10 data sections + paginated detail pages
- **Collectibles** — Tabbed Badges + Myth Cards with image upload to Supabase Storage
- **Learning Path Templates** — Template creation and school/class assignment

### Storage
- Card images: Supabase Storage `card-images` bucket (public, 95 PNGs)
- All other media: URL-referenced (Supabase Storage or external)

## Offline Strategy

1. **Local-first writes**: All user actions saved to Isar immediately
2. **Sync queue**: Changes queued for server sync
3. **Background sync**: Automatic sync when connectivity restored
4. **Conflict resolution**: Server timestamp wins (last-write-wins)
