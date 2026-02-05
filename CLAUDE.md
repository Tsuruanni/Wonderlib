# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

# Related Projects

| Project | Path | Description |
|---------|------|-------------|
| ReadEng Mobile | `/Users/wonderelt/Desktop/wonderlib` | Main Flutter app (student/teacher) |
| ReadEng Admin | `/Users/wonderelt/Desktop/readeng_admin` | Admin panel (content management) |

Both projects share the same Supabase backend.

---

# Project Overview

- **Project:** ReadEng (Wonderlib)
- **Purpose:** Interactive English reading platform for K-12 students
- **Users:** Elementary-high school students, English teachers
- **Core Features:** Digital library, chapter-end activities, vocabulary exercises, XP/badge system, teacher dashboard

---

# Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter (Android, iOS, Web, Desktop) |
| State Management | Riverpod |
| Local Database | Isar (offline-first) |
| Backend | Supabase (PostgreSQL + Auth + Storage + Edge Functions) |
| Media Storage | Cloudflare R2 |
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
│  └─────────┘    └──────────┘    └─────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      DOMAIN LAYER                            │
│  ┌──────────┐    ┌────────────────────┐    ┌───────────┐   │
│  │ Entities │    │ UseCase (81 total) │    │ Repo Intf │   │
│  └──────────┘    └────────────────────┘    └───────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       DATA LAYER                             │
│  ┌──────────────────┐    ┌────────────────────────────┐    │
│  │ Models (21 total)│    │ Repository Implementations │    │
│  │ (JSON ↔ Entity)  │    │ (9 Supabase repositories)  │    │
│  └──────────────────┘    └────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Folder Structure

```
lib/
├── core/
│   ├── config/          # Game configs, app constants
│   ├── errors/          # Failure types
│   ├── network/         # Network utilities
│   └── services/        # Edge function service, etc.
├── data/
│   ├── models/          # JSON serialization (21 models)
│   │   ├── auth/
│   │   ├── book/
│   │   ├── activity/
│   │   ├── vocabulary/
│   │   ├── badge/
│   │   ├── user/
│   │   ├── teacher/
│   │   └── assignment/
│   └── repositories/
│       └── supabase/    # 9 repository implementations
├── domain/
│   ├── entities/        # Pure business objects
│   ├── repositories/    # 9 repository interfaces
│   └── usecases/        # 81 use cases
│       ├── auth/        # 5 usecases
│       ├── book/        # 7 usecases
│       ├── reading/     # 6 usecases
│       ├── activity/    # 9 usecases
│       ├── vocabulary/  # 10 usecases
│       ├── wordlist/    # 8 usecases
│       ├── badge/       # 6 usecases
│       ├── user/        # 7 usecases
│       ├── teacher/     # 9 usecases
│       ├── assignment/  # 5 usecases
│       └── student_assignment/  # 6 usecases
├── presentation/
│   ├── providers/       # Riverpod state management
│   ├── screens/         # UI screens
│   ├── utils/           # UI helpers (colors, formatters)
│   └── widgets/         # Reusable components
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

---

# Game Configuration Pattern

For word games and activities, use configurable configs:

```dart
// lib/core/config/game_config.dart
abstract class GameConfig {
  Duration get timeLimit;
  Color get themeColor;
  int get difficultyMultiplier;
  List<String> get wordList;
}

class VocabularyGameConfig implements GameConfig {
  final Duration timeLimit;
  final Color themeColor;
  final int difficultyMultiplier;
  final List<String> wordList;

  const VocabularyGameConfig({
    this.timeLimit = const Duration(seconds: 60),
    this.themeColor = Colors.blue,
    this.difficultyMultiplier = 1,
    required this.wordList,
  });
}

// Usage in UseCase
class StartGameUseCase {
  Future<Either<Failure, Game>> call(GameConfig config) {
    // Game uses config, not hard-coded values
  }
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

# Current Status (2026-02-05)

## ✅ Completed
- Clean Architecture refactor (7 modules)
- 21 Models, 81 UseCases
- 9 Supabase repository implementations
- All screens use UseCases (not repositories)
- UI helpers centralized (`ui_helpers.dart`)
- Business logic moved from widgets to providers

## ⚠️ Pending
- [ ] `supabase db push` to remote (production)
- [ ] Full manual testing
- [ ] Sentry integration
- [ ] flutter_gen asset management
- [ ] Entity files separation (from repository interfaces)

## 🚨 Remote DB is EMPTY!
```bash
# Before production, run:
supabase db push
```

---

# Future Refactors (Tracked)

1. **Entity Separation**: Move entity types from repository interfaces to `domain/entities/`
2. **Asset Generation**: Add flutter_gen for type-safe asset paths
3. **Game Config System**: Implement configurable game modes
4. **Offline Sync**: Complete Isar integration for offline-first

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

---

# Key Principles

1. **Ask First**: Clarify before assuming
2. **Read Existing Code**: Follow established patterns
3. **Don't Over-Engineer**: Solve today's problem
4. **Verify Changes**: `dart analyze` after every change
5. **UI in English**: All user-facing text must be in English
