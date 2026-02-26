# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

# Related Projects

| Project | Path | Description |
|---------|------|-------------|
| Owlio Mobile | `/Users/wonderelt/Desktop/wonderlib` | Main Flutter app (student/teacher) |
| Owlio Admin | `/Users/wonderelt/Desktop/wonderlib/owlio_admin` | Admin panel (content management) |
| Shared Package | `/Users/wonderelt/Desktop/wonderlib/packages/owlio_shared` | Shared enums, table names, RPC constants |

All three projects share the same Supabase backend. The shared package ensures table names, enum values, and RPC function names stay consistent between main app and admin panel.

---

# Project Overview

- **Project:** Owlio
- **Purpose:** Interactive English reading platform for K-12 students
- **Users:** Elementary-high school students, English teachers
- **Core Features:** Digital library, chapter-end activities, vocabulary exercises, XP/badge system, teacher dashboard

---

# Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter (Android, iOS, Web, Desktop) |
| State Management | Riverpod (flutter_riverpod + riverpod_annotation) |
| Navigation | GoRouter |
| Local Storage | sqflite, SharedPreferences, FlutterSecureStorage |
| Backend | Supabase (PostgreSQL + Auth + Storage + Edge Functions) |
| Audio | just_audio + audio_session + flutter_tts |
| Functional | dartz (Either pattern) + equatable |
| Analytics | PostHog |
| Error Tracking | Sentry |

---

# Architecture Overview

## Clean Architecture (Completed ✅)

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│  ┌─────────┐    ┌──────────┐    ┌─────────────────────┐    │
│  │ Screens │───▶│ Providers │───▶│ UseCase Providers  │    │
│  │  (28)   │    │   (24)   │    │     (117)          │    │
│  └─────────┘    └──────────┘    └─────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      DOMAIN LAYER                            │
│  ┌──────────┐    ┌─────────────────────┐    ┌───────────┐  │
│  │ Entities │    │ UseCase (117 total) │    │ Repo Intf │  │
│  │  (21)    │    └─────────────────────┘    │   (13)    │  │
│  └──────────┘                               └───────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       DATA LAYER                             │
│  ┌──────────────────┐    ┌────────────────────────────┐    │
│  │ Models (38 total)│    │ Repository Implementations │    │
│  │ (JSON ↔ Entity)  │    │ (13 Supabase repositories) │    │
│  └──────────────────┘    └────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Folder Structure

```
lib/
├── core/
│   ├── config/          # App config, constants
│   ├── constants/       # AppConstants, UserLevel (enums moved to owlio_shared)
│   ├── errors/          # 8 Failure types, 6 Exception types
│   ├── network/         # ApiClient, interceptors, connectivity
│   ├── services/        # AudioService, WordPronunciationService, EdgeFunctionService
│   └── utils/           # SM2 algorithm, extensions (context, string, datetime)
├── data/
│   ├── models/          # JSON serialization (38 models)
│   │   ├── activity/    # 3 models (activity, result, inline)
│   │   ├── assignment/  # 3 models (assignment, student, student_assignment)
│   │   ├── badge/       # 2 models (badge, user_badge)
│   │   ├── book/        # 3 models (book, chapter, reading_progress)
│   │   ├── book_quiz/   # 3 models (quiz, result, student_progress)
│   │   ├── card/        # 4 models (myth_card, pack_result, buy_pack_result, user_card_stats)
│   │   ├── content/     # 1 model (content_block)
│   │   ├── settings/    # 1 model (system_settings)
│   │   ├── teacher/     # 4 models (stats, class, student_summary, progress)
│   │   ├── user/        # 2 models (user, leaderboard_entry)
│   │   └── vocabulary/  # 7 models (word, progress, word_list, list_progress, daily_review, session, node_completion)
│   └── repositories/
│       └── supabase/    # 13 repository implementations
├── domain/
│   ├── entities/        # 21 entity files (pure business objects)
│   ├── repositories/    # 13 repository interfaces
│   └── usecases/        # 117 use cases + 1 base class
│       ├── auth/        # 5 usecases
│       ├── book/        # 9 usecases
│       ├── book_quiz/   # 6 usecases
│       ├── reading/     # 8 usecases
│       ├── activity/    # 10 usecases
│       ├── vocabulary/  # 18 usecases
│       ├── wordlist/    # 10 usecases
│       ├── badge/       # 6 usecases
│       ├── card/        # 9 usecases
│       ├── user/        # 11 usecases
│       ├── teacher/     # 11 usecases
│       ├── assignment/  # 5 usecases (teacher-side)
│       ├── student_assignment/ # 6 usecases (student-side)
│       ├── content/     # 2 usecases
│       └── settings/    # 1 usecase
├── presentation/
│   ├── providers/       # 24 provider files (117 UseCase + 13 Repository providers)
│   ├── screens/         # 28 active screens (auth, home, library, reader, vocabulary, profile, leaderboard, student, teacher)
│   ├── utils/           # UI helpers (colors, formatters)
│   └── widgets/         # Reusable components
│       ├── book_quiz/       # BookQuiz* - final book quiz widgets (8)
│       ├── cards/           # Card collection widgets (CoinBadge, CardFlip, etc.)
│       ├── common/          # Shared: AnimatedGameButton, FeedbackAnimation, SubtleBackground, StudentProfileDialog, etc.
│       ├── home/            # Home screen widgets (TopNavbar, BottomNavbar)
│       ├── inline_activities/ # InlineActivity* - in-chapter activities (6)
│       ├── reader/          # Reader* - reader screen widgets (15)
│       ├── shell/           # App shell widgets
│       └── vocabulary/
│           ├── session/     # Vocab* - vocabulary session question widgets (12)
│           └── *.dart       # LearningPath, PathNodes, etc.
└── l10n/                # Localization (TR/EN)
```

---

# 🚀 New Feature Methodology

When adding a new feature, **always follow this order**:

## Step 1: Database (if needed)
```bash
# Create migration file
touch supabase/migrations/YYYYMMDD000XXX_feature_name.sql

# Test locally
supabase db reset
```

## Step 2: Domain Layer
1. **Entity** (if new data type): `lib/domain/entities/feature_name.dart`
2. **Repository Interface** (if new operations): `lib/domain/repositories/feature_repository.dart`
3. **UseCase(s)**: `lib/domain/usecases/feature/verb_noun_usecase.dart`

```dart
// UseCase Template
class GetFeatureDataUseCase implements UseCase<FeatureData, GetFeatureParams> {
  final FeatureRepository _repository;
  const GetFeatureDataUseCase(this._repository);

  @override
  Future<Either<Failure, FeatureData>> call(GetFeatureParams params) {
    return _repository.getFeatureData(params.id);
  }
}

class GetFeatureParams {
  final String id;
  const GetFeatureParams({required this.id});
}
```

## Step 3: Data Layer
1. **Model**: `lib/data/models/feature/feature_model.dart`

```dart
// Model Template
class FeatureModel {
  final String id;
  // ... fields

  factory FeatureModel.fromJson(Map<String, dynamic> json) => FeatureModel(
    id: json['id'] as String,
    // ...
  );

  Map<String, dynamic> toJson() => {'id': id, ...};

  FeatureEntity toEntity() => FeatureEntity(id: id, ...);

  factory FeatureModel.fromEntity(FeatureEntity e) => FeatureModel(id: e.id, ...);
}
```

2. **Repository Implementation**: `lib/data/repositories/supabase/supabase_feature_repository.dart`

## Step 4: Presentation Layer
1. **Provider registration**: `lib/presentation/providers/repository_providers.dart`
2. **UseCase provider**: `lib/presentation/providers/usecase_providers.dart`
3. **Feature provider**: `lib/presentation/providers/feature_provider.dart`
4. **Screen/Widget**: Use provider, NOT repository

## Step 5: Verification
```bash
# Must pass
dart analyze lib/

# Must return 0 for screens (entity type imports are OK)
grep -r "ref\.(read|watch).*RepositoryProvider" lib/presentation/screens/ | wc -l

# Run tests
flutter test
```

---

# ⛔ Architecture Rules (CRITICAL)

## NEVER Do This

| Violation | Why It's Wrong |
|-----------|----------------|
| `ref.read(xxxRepositoryProvider)` in Screen | Screens must use UseCases via Providers |
| `import 'package:flutter'` in UseCase | Domain layer must be framework-agnostic |
| `fromJson`/`toJson` in Entity | JSON handling belongs in Model layer |
| Hard-coded values in games | Use GameConfig for configurability |
| Business logic in Widget | Move to provider (e.g., `handleActivityCompletion`) |
| Duplicate helper methods in screens | Use centralized `ui_helpers.dart` |
| UseCase calls directly in Widget | Widget calls Provider, Provider calls UseCase |

## ALWAYS Do This

| Pattern | Example |
|---------|---------|
| Screen → Provider → UseCase | `ref.watch(featureProvider)` |
| UseCase returns Either | `Future<Either<Failure, T>>` |
| Model handles JSON | `FeatureModel.fromJson(json).toEntity()` |
| Repository uses Model | `return Right(model.toEntity())` |
| Use shared package enums | `import 'package:owlio_shared/owlio_shared.dart'` |
| Use `DbTables.x` for table names | `supabase.from(DbTables.books)` not `supabase.from('books')` |
| Use `RpcFunctions.x` for RPC | `supabase.rpc(RpcFunctions.awardXpTransaction)` |

## Admin Panel Impact Check

When modifying database schema (migrations, RLS policies, RPC functions):

1. **Check if admin accesses affected tables:** `grep -r "DbTables.tableName" owlio_admin/lib/`
2. **If yes**, verify admin panel still works with the change
3. **Update shared package** if schema changes affect enums or table structure
4. **Both apps use `owlio_shared`** — changes to shared enums affect both projects

The admin panel (`owlio_admin/`) accesses 17+ Supabase tables for content management. Any migration that changes table structure, RLS policies, or RPC functions can silently break it.

---

# Game Configuration Pattern (NOT YET IMPLEMENTED)

> **Status:** This pattern is aspirational. Activities currently use values from `AppConfig` and `AppConstants` directly. Implement this when adding new game modes or difficulty levels.

```dart
// lib/core/config/game_config.dart (future)
abstract class GameConfig {
  Duration get timeLimit;
  Color get themeColor;
  int get difficultyMultiplier;
  List<String> get wordList;
}
```

---

# UI Helpers (`lib/presentation/utils/ui_helpers.dart`)

Centralized helpers for colors, icons, and formatters. **Never duplicate these in screens/widgets.**

| Helper | Methods |
|--------|---------|
| `AssignmentColors` | `getTypeColor()`, `getTypeIcon()`, `getStatusColor()`, `getStatusIcon()` |
| `StudentAssignmentColors` | `getTypeColor()`, `getTypeIcon()`, `getStatusColor()`, `getStatusIcon()` |
| `VocabularyColors` | `getCategoryColor()` |
| `ScoreColors` | `getScoreColor()`, `getProgressColor()`, `getCompletionColor()` |
| `TimeFormatter` | `formatReadingTime()`, `formatDuration()` |
| `GreetingHelper` | `getGreeting()` |

```dart
// Usage in screen/widget:
color: AssignmentColors.getTypeColor(assignment.type)
color: ScoreColors.getScoreColor(score)
final greeting = GreetingHelper.getGreeting();
```

---

# Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Files | `snake_case.dart` | `get_books_usecase.dart` |
| Classes | `PascalCase` | `GetBooksUseCase` |
| Variables | `camelCase` | `bookRepository` |
| UseCase | `VerbNounUseCase` | `CreateAssignmentUseCase` |
| Model | `EntityNameModel` | `BookModel` |
| Provider | `featureNameProvider` | `currentUserProvider` |

---

# Commands

```bash
# Development
flutter pub get
flutter run -d chrome
dart analyze lib/

# Supabase
supabase start              # Start local
supabase db reset           # Reset + seed
supabase db push            # Push to remote (CAUTION!)

# Build
flutter build web --release
flutter build apk --release

# Test
flutter test
flutter test --coverage
```

---

# Test Users

| Role | Email | Password |
|------|-------|----------|
| Student | test@demo.com | Test1234 |
| Teacher | teacher@demo.com | Teacher1234 |

**Student Number:** 2024001
**School Code:** DEMO123

---

# Current Status (2026-02-20)

## ✅ Completed
- Clean Architecture refactor (17 modules)
- 38 Models, 117 UseCases, 13 Repositories
- 28 screens, 24 provider files
- All screens use UseCases via Providers (not repositories)
- All 13 repos use `DbTables.*` and `RpcFunctions.*` constants (no hard-coded strings)
- UI helpers centralized (`ui_helpers.dart`)
- Business logic moved from widgets to providers
- 59 DB migrations, properly versioned
- Shared package: 41 DbTables, 31 RpcFunctions, 13 shared enums
- Audio system with word-level karaoke + listening mode
- Spaced repetition (SM2 algorithm)
- Codebase audit: RLS security, null safety, race conditions fixed (2026-02-20)

## 🐛 Known Issues (To Fix)

### Medium Priority
- [ ] `vocabulary_screen.dart` router'da yok - ileride eklenecek (önemli sayfa, SİLME)
- [ ] Constants overlap between `AppConfig.xpRewards` and `AppConstants` XP values

### Resolved (2026-02-20)
- [x] RLS security: `user_badges` + `xp_logs` INSERT restricted to `auth.uid()`
- [x] Quiz XP bug: RPC param name mismatch fixed (`p_xp_amount` → `p_amount`)
- [x] Null safety: guards added to 8+ model files
- [x] Race conditions: 3 repos converted to atomic upsert
- [x] Hard-coded table/RPC strings eliminated across all 13 repos
- [x] Leaderboard provider rewired through UseCases (was only architecture violation)
- [x] StudentAssignment enums consolidated to shared package typedefs
- [x] Dead UseCases: 4 registered, 1 superseded deleted
- [x] Sign-out stale state: event providers cleared

### Resolved (2026-02-06)
- [x] `UserBadge.odId` → `userId` renamed
- [x] `_sqrt()` bug fixed (Newton's method)
- [x] Duplicate `UserModel` consolidated (auth/ deleted, user/ kept with UserRole enum)
- [x] `StudentAssignment` → Equatable added
- [x] Teacher entity extraction (9 types → `entities/teacher.dart` + `entities/assignment.dart`)
- [x] `inlineActivityByIdProvider` stub removed

## ⚠️ Pending (Deployment)
- [ ] `supabase db push` to remote (production)
- [ ] Full manual testing
- [ ] Sentry integration

## 🚨 Remote DB is EMPTY!
```bash
# Before production, run:
supabase db push
```

---

# Remaining Technical Debt

1. **Constants Consolidation**: Merge `AppConfig.xpRewards` and `AppConstants` XP values into single source of truth
2. **vocabulary_screen.dart**: Eklenmeyi bekliyor (router'da route yok, ileride bağlanacak)
3. **GameConfig pattern**: Documented in CLAUDE.md but not implemented - activities use AppConfig directly

---

# Debugging Tips

```dart
// Add debug logs in providers
debugPrint('providerName: key=$value');

// Check RPC functions directly
curl -X POST "http://127.0.0.1:54321/rest/v1/rpc/function_name" \
  -H "apikey: <anon_key>" \
  -d '{"param": "value"}'
```

---

# ⚠️ Riverpod Listener & Audio Patterns (Critical)

## Provider Lifecycle Gotchas

| Issue | Wrong | Correct |
|-------|-------|---------|
| Stale state across navigation | Non-autoDispose provider retains value | Reset provider on screen init OR use autoDispose |
| Modifying provider in lifecycle | `ref.read(x.notifier).state = y` in `didChangeDependencies` | Use `Future.microtask()` or `addPostFrameCallback` |
| Captured vs current value | Using local var in callback: `if (isInit) {...}` | Read current: `if (ref.read(provider)) {...}` |

## ref.listen Behavior

```dart
// ⚠️ ONLY fires when value CHANGES, NOT on initial subscription
ref.listen<bool>(myProvider, (previous, current) {
  // This will NOT fire if provider is already true when listener is set up!
});

// ✅ Handle both: listener for changes + check current value in postFrameCallback
ref.listen<bool>(chapterInitializedProvider, (prev, initialized) {
  if (initialized && !_hasInitialized) {
    _captureBaseline();
    _hasInitialized = true;
  }
});

WidgetsBinding.instance.addPostFrameCallback((_) {
  // Handle case where provider is already true
  if (ref.read(chapterInitializedProvider) && !_hasInitialized) {
    _captureBaseline();
    _hasInitialized = true;
  }
});
```

## "New Items" Detection Pattern

When detecting items completed in THIS session vs loaded from DB:

```dart
// ❌ WRONG: _previousIds starts empty, ALL loaded items appear "new"
final newIds = currentIds.difference(_previousIds); // ALL items on first load!

// ✅ CORRECT: Capture baseline AFTER data loads, before tracking changes
bool _hasInitializedBaseline = false;
Set<String> _baselineIds = {};

// In listener (fires when load completes):
ref.listen<bool>(dataLoadedProvider, (prev, loaded) {
  if (loaded && !_hasInitializedBaseline) {
    _baselineIds = ref.read(itemsProvider).keys.toSet();
    _hasInitializedBaseline = true;
  }
});

// Only check for new items AFTER baseline captured:
if (_hasInitializedBaseline) {
  final newIds = currentIds.difference(_baselineIds);
  if (newIds.isNotEmpty) {
    // These are genuinely new (completed this session)
  }
}
```

## Audio Auto-Play Rules

1. **Never auto-play on chapter load** - User must manually press play
2. **Auto-play after activity completion** - Only if user is in "listening mode"
3. **Auto-play after audio block completion** - Continue to next audio block
4. **Stop audio on navigation** - Call `audioSyncController.stop()` before navigating away

### Listening Mode Concept

`_isInListeningMode` tracks whether user is in an active listening session:

| Action | `isPlaying` | `_isInListeningMode` |
|--------|-------------|----------------------|
| Never pressed play | false | **false** |
| Pressed play | true | **true** |
| Audio completed | false | **true** (flow continues) |
| User pressed pause | false | **false** |
| User pressed stop | false | **false** |

**Auto-play only triggers if `_isInListeningMode == true`.**
This prevents auto-play when user completes activity without ever starting audio.

## Key Files

| File | Responsibility |
|------|----------------|
| `audio_sync_provider.dart` | Core audio playback, word-level audio, segment playback, auto-play orchestration |
| `content_block_list.dart` | Listens for completions, scrolls to next block, calls `onActivityCompleted()` |
| `reader_screen.dart` | Initializes chapter state, stops audio on navigation |

**Note:** Auto-play logic is integrated into `AudioSyncController` (no separate auto-play provider).

## Auto-Scroll Follow Mode

Word-level karaoke scroll, kullanıcı manuel scroll yapınca durur:

| Action | `isFollowingScroll` | Behavior |
|--------|---------------------|----------|
| User presses play | `true` | Scroll follows active word |
| Audio plays, word changes | `true` | Scroll updates |
| User scrolls manually | `false` | Scroll stops, audio continues |
| User presses play again | `true` | Scroll resumes from current word |

### User Scroll Detection

```dart
// reader_body.dart - NotificationListener içinde
if (notification is ScrollStartNotification) {
  if (notification.dragDetails != null) {
    // User initiated scroll (finger drag) - not programmatic
    ref.read(audioSyncControllerProvider.notifier).disableFollowScroll();
  }
}
```

**Key insight:** `dragDetails != null` sadece parmak sürüklemesinde dolu. `Scrollable.ensureVisible()` (programmatic scroll) için `null` olur.

### State Location

- `AudioSyncState.isFollowingScroll` - scroll takip durumu
- `AudioSyncController.disableFollowScroll()` - takibi kapat
- `AudioSyncController.play()` - takibi aç (`isFollowingScroll = true`)

### Guard in WordHighlightText

```dart
// word_highlight_text.dart
void didUpdateWidget(...) {
  if (widget.isFollowingScroll &&  // ← Guard
      widget.activeWordIndex != _previousActiveIndex) {
    _scrollToActiveWord();
  }
}
```

---

# Key Principles

1. **Ask First**: Clarify before assuming
2. **Read Existing Code**: Follow established patterns
3. **Don't Over-Engineer**: Solve today's problem
4. **Verify Changes**: `dart analyze` after every change
5. **UI in English**: All user-facing text must be in English
