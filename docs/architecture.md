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
│       └── assignment/       # Assignment UseCases
│
├── presentation/
│   ├── providers/
│   │   ├── usecase_providers.dart  # All UseCase providers
│   │   ├── repository_providers.dart
│   │   └── *_provider.dart   # Feature providers
│   ├── screens/              # Page widgets
│   └── widgets/
│       └── common/           # Shared widgets (XPBadge, StatItem)
│
└── l10n/                     # Localization
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
- `books` - Book metadata
- `chapters` - Book content
- `activities` - Comprehension exercises
- `vocabulary_words` - Word definitions

### Progress
- `reading_progress` - Book completion tracking
- `activity_results` - Quiz answers and scores
- `vocabulary_progress` - Spaced repetition state

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
