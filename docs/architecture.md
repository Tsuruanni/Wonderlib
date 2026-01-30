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
│  - State management                                           │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                       DOMAIN                                  │
│  Entities, UseCases, Repository Interfaces                   │
│  - Business logic                                             │
│  - Platform-agnostic                                          │
│  - No external dependencies                                   │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                        DATA                                   │
│  Models, DataSources, Repository Implementations             │
│  - API calls (Supabase)                                       │
│  - Local storage (Isar)                                       │
│  - Data transformation                                        │
└──────────────────────────────────────────────────────────────┘
```

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
│   ├── models/               # JSON serializable
│   └── repositories/         # Implementations
│
├── domain/
│   ├── entities/             # Business objects
│   ├── repositories/         # Interfaces
│   └── usecases/             # Business logic
│
├── presentation/
│   ├── providers/            # Riverpod providers
│   ├── screens/              # Page widgets
│   └── widgets/              # Reusable components
│
└── l10n/                     # Localization
```

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
