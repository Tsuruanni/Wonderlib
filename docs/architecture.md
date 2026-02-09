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
│                     Supabase (Hosted)                           │
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
│       ├── common/           # Shared widgets (XPBadge, StatItem, TopNavbar, StreakStatusDialog)
│       ├── vocabulary/       # Vocabulary path widgets
│       │   ├── learning_path.dart    # Duolingo-style zigzag path
│       │   ├── path_node.dart        # Circle node with progress ring
│       │   └── session/              # Quiz session widgets (7 question types + feedback)
│       └── reader/           # Reader-specific widgets
│           ├── reader_body.dart           # Main scrollable content
│           ├── reader_popups.dart         # Vocabulary/word popups
│           ├── chapter_completion_card.dart # Next chapter UI
│           └── ...
│
├── l10n/                     # Localization
│
readeng_admin/                 # Admin panel (separate Flutter web project)
├── lib/
│   ├── core/                  # Supabase client, router
│   └── features/              # Feature modules (books, schools, users, classes, badges, vocabulary, wordlists, curriculum, settings, gallery)
│       └── */screens/         # CRUD screens per feature
├── pubspec.yaml
└── web/

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
- `books` - Book metadata (title, author, level, cover_image_url)
- `chapters` - Book content (use_content_blocks flag)
- `content_blocks` - Structured content (text, image, audio, activity types)
  - `word_timings` JSONB - Audio-text sync data for karaoke highlighting
- `activities` - Comprehension exercises
- `vocabulary_words` - Word definitions (supports multiple meanings per word)
  - `source_book_id` - FK to books for meaning attribution
  - `part_of_speech` - Grammatical classification
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

### Gamification
- `badges` - Badge definitions
- `user_badges` - Earned badges
- `xp_logs` - XP history

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

## Offline Strategy

1. **Local-first writes**: All user actions saved to Isar immediately
2. **Sync queue**: Changes queued for server sync
3. **Background sync**: Automatic sync when connectivity restored
4. **Conflict resolution**: Server timestamp wins (last-write-wins)
