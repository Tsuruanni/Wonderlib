# ReadEng - Technical Requirements Document (TRD)

## 📋 Document Info

| Field | Value |
|-------|-------|
| Product Name | ReadEng |
| Document Type | Technical Requirements |
| Version | 2.0 |
| Last Updated | Ocak 2025 |
| Status | Final |
| Architecture | Flutter + Supabase |

---

## 1. Executive Summary

Bu doküman, ReadEng platformunun teknik mimarisini, teknoloji stack'ini, sistem tasarımını ve mühendislik gereksinimlerini tanımlar.

### 1.1 Temel Teknik Hedefler

| Hedef | Açıklama |
|-------|----------|
| **Hızlı Geliştirme** | MVP'yi 3 ayda çıkarabilme |
| **Düşük Maliyet** | İlk yıl aylık <$100 altyapı maliyeti |
| **Çoklu Platform** | Tek codebase ile Android, iOS, Web, Desktop |
| **Offline Destek** | İnternet olmadan kitap okuma ve aktivite yapma |
| **Ölçeklenebilirlik** | 100K+ kullanıcıya kadar sorunsuz büyüme |
| **Güvenlik** | KVKK uyumu, çocuk verisi koruması |

### 1.2 Mimari Felsefesi

```
"Simplicity over complexity"
"Managed services over self-hosted"
"Convention over configuration"
"Offline-first for education"
```

---

## 2. Tech Stack Overview

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                             │
│                          Flutter                                │
│                (Android + iOS + Web + Desktop)                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Riverpod │ GoRouter │ Isar │ Dio │ flutter_hooks       │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                          CDN LAYER                              │
│                        Cloudflare                               │
│         ┌──────────┬──────────┬──────────┐                     │
│         │   CDN    │   WAF    │    R2    │                     │
│         │ (Cache)  │(Security)│ (Media)  │                     │
│         └──────────┴──────────┴──────────┘                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       BACKEND LAYER                             │
│                     Supabase (Hosted)                           │
│  ┌───────────┬───────────┬───────────┬───────────┬─────────┐  │
│  │PostgreSQL │   Auth    │  Storage  │ Realtime  │  Edge   │  │
│  │  + RLS    │(JWT/OAuth)│ (Backup)  │(WebSocket)│Functions│  │
│  └───────────┴───────────┴───────────┴───────────┴─────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     EXTERNAL SERVICES                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │  Learning   │  │ Meilisearch │  │  PostHog    │            │
│  │   Locker    │  │   Cloud     │  │ (Analytics) │            │
│  │   (xAPI)    │  │  (Search)   │  │             │            │
│  └─────────────┘  └─────────────┘  └─────────────┘            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       MONITORING                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │   Sentry    │  │  Logflare   │  │BetterUptime │            │
│  │  (Errors)   │  │   (Logs)    │  │  (Status)   │            │
│  └─────────────┘  └─────────────┘  └─────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

---

### 2.2 Technology Decisions

| Layer | Technology | Why This Choice |
|-------|------------|-----------------|
| **Mobile/Web** | Flutter | Single codebase, native performance, great for tablets |
| **State Management** | Riverpod | Type-safe, testable, better than Provider |
| **Local Database** | Isar | Fast, Flutter-native, offline support |
| **Backend** | Supabase | Instant backend, PostgreSQL underneath, cheap |
| **Auth** | Supabase Auth | Built-in, JWT, magic links, SSO ready |
| **File Storage** | Cloudflare R2 | Zero egress cost, S3 compatible |
| **CDN** | Cloudflare | Free tier generous, global, WAF included |
| **Search** | Meilisearch Cloud | Typo-tolerant, fast, easy setup |
| **Analytics** | Learning Locker | xAPI standard for education |
| **Product Analytics** | PostHog | Open source, generous free tier |
| **Error Tracking** | Sentry | Industry standard, Flutter SDK |

---

## 3. Frontend Architecture (Flutter)

### 3.1 Project Structure

```
lib/
├── main.dart                    # App entry point
├── app/
│   ├── app.dart                 # MaterialApp configuration
│   ├── router.dart              # GoRouter configuration
│   └── theme.dart               # App theme
│
├── core/
│   ├── constants/               # App constants
│   │   ├── api_constants.dart
│   │   ├── app_constants.dart
│   │   └── storage_keys.dart
│   ├── errors/                  # Error handling
│   │   ├── exceptions.dart
│   │   └── failures.dart
│   ├── network/                 # Network layer
│   │   ├── api_client.dart
│   │   ├── interceptors/
│   │   └── network_info.dart
│   ├── utils/                   # Utilities
│   │   ├── extensions/
│   │   ├── helpers/
│   │   └── validators.dart
│   └── services/                # Core services
│       ├── storage_service.dart
│       ├── audio_service.dart
│       └── sync_service.dart
│
├── data/
│   ├── datasources/
│   │   ├── local/               # Isar databases
│   │   │   ├── book_local_ds.dart
│   │   │   ├── progress_local_ds.dart
│   │   │   └── user_local_ds.dart
│   │   └── remote/              # Supabase calls
│   │       ├── auth_remote_ds.dart
│   │       ├── book_remote_ds.dart
│   │       └── progress_remote_ds.dart
│   ├── models/                  # Data models (JSON serializable)
│   │   ├── book_model.dart
│   │   ├── chapter_model.dart
│   │   ├── user_model.dart
│   │   └── ...
│   └── repositories/            # Repository implementations
│       ├── auth_repository_impl.dart
│       ├── book_repository_impl.dart
│       └── ...
│
├── domain/
│   ├── entities/                # Business entities
│   │   ├── book.dart
│   │   ├── chapter.dart
│   │   ├── user.dart
│   │   └── ...
│   ├── repositories/            # Repository interfaces
│   │   ├── auth_repository.dart
│   │   ├── book_repository.dart
│   │   └── ...
│   └── usecases/                # Business logic
│       ├── auth/
│       │   ├── login_usecase.dart
│       │   └── logout_usecase.dart
│       ├── library/
│       │   ├── get_books_usecase.dart
│       │   └── get_chapter_usecase.dart
│       └── gamification/
│           ├── award_xp_usecase.dart
│           └── check_badge_usecase.dart
│
├── presentation/
│   ├── providers/               # Riverpod providers
│   │   ├── auth_provider.dart
│   │   ├── book_provider.dart
│   │   ├── gamification_provider.dart
│   │   └── ...
│   ├── screens/                 # Screen widgets
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── school_code_screen.dart
│   │   ├── home/
│   │   │   └── home_screen.dart
│   │   ├── library/
│   │   │   ├── library_screen.dart
│   │   │   └── book_detail_screen.dart
│   │   ├── reader/
│   │   │   ├── reader_screen.dart
│   │   │   └── activity_screen.dart
│   │   ├── vocabulary/
│   │   │   └── vocabulary_screen.dart
│   │   ├── profile/
│   │   │   └── profile_screen.dart
│   │   └── teacher/             # Teacher-only screens
│   │       ├── dashboard_screen.dart
│   │       ├── class_screen.dart
│   │       └── assignment_screen.dart
│   └── widgets/                 # Reusable widgets
│       ├── common/
│       │   ├── app_button.dart
│       │   ├── app_card.dart
│       │   └── loading_indicator.dart
│       ├── book/
│       │   ├── book_card.dart
│       │   └── book_cover.dart
│       ├── reader/
│       │   ├── page_view.dart
│       │   ├── dictionary_popup.dart
│       │   └── audio_player.dart
│       └── gamification/
│           ├── xp_badge.dart
│           ├── streak_indicator.dart
│           └── leaderboard_item.dart
│
└── l10n/                        # Localization
    ├── app_tr.arb
    └── app_en.arb
```

### 3.2 Dependencies (pubspec.yaml)

```yaml
name: readeng
description: K12 English Reading Platform
version: 1.0.0+1

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  
  # State Management
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3
  
  # Navigation
  go_router: ^13.0.1
  
  # Network
  dio: ^5.4.0
  supabase_flutter: ^2.3.0
  connectivity_plus: ^5.0.2
  
  # Local Storage
  isar: ^3.1.0+1
  isar_flutter_libs: ^3.1.0+1
  shared_preferences: ^2.2.2
  flutter_secure_storage: ^9.0.0
  
  # UI Components
  flutter_svg: ^2.0.9
  cached_network_image: ^3.3.1
  shimmer: ^3.0.0
  lottie: ^3.0.0
  
  # Audio
  just_audio: ^0.9.36
  audio_session: ^0.1.18
  
  # Utils
  intl: ^0.18.1
  equatable: ^2.0.5
  dartz: ^0.10.1
  uuid: ^4.2.2
  timeago: ^3.6.1
  
  # Analytics
  sentry_flutter: ^7.14.0
  posthog_flutter: ^4.0.1
  
  # Search
  meilisearch: ^0.15.2
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
  riverpod_generator: ^2.3.9
  build_runner: ^2.4.8
  isar_generator: ^3.1.0+1
  json_serializable: ^6.7.1
  mockito: ^5.4.4
  bloc_test: ^9.1.5

flutter:
  uses-material-design: true
  generate: true
  
  assets:
    - assets/images/
    - assets/icons/
    - assets/animations/
```

### 3.3 Key Flutter Patterns

#### 3.3.1 Riverpod Provider Example

```dart
// lib/presentation/providers/book_provider.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/book.dart';
import '../../domain/usecases/library/get_books_usecase.dart';

part 'book_provider.g.dart';

@riverpod
class BookList extends _$BookList {
  @override
  Future<List<Book>> build({
    String? level,
    String? genre,
    BookStatus? status,
  }) async {
    final getBooksUseCase = ref.watch(getBooksUseCaseProvider);
    
    final result = await getBooksUseCase(
      GetBooksParams(
        level: level,
        genre: genre,
        status: status,
      ),
    );
    
    return result.fold(
      (failure) => throw failure,
      (books) => books,
    );
  }
  
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

@riverpod
class ReadingProgress extends _$ReadingProgress {
  @override
  Future<BookProgress?> build(String bookId) async {
    final repository = ref.watch(bookRepositoryProvider);
    
    final result = await repository.getProgress(bookId);
    
    return result.fold(
      (failure) => null,
      (progress) => progress,
    );
  }
  
  Future<void> updatePage(int page) async {
    final repository = ref.watch(bookRepositoryProvider);
    final bookId = this.bookId;
    
    await repository.updateProgress(
      bookId: bookId,
      currentPage: page,
    );
    
    ref.invalidateSelf();
  }
}
```

#### 3.3.2 Offline-First Repository Pattern

```dart
// lib/data/repositories/book_repository_impl.dart

class BookRepositoryImpl implements BookRepository {
  final BookRemoteDataSource _remoteDataSource;
  final BookLocalDataSource _localDataSource;
  final NetworkInfo _networkInfo;
  final SyncService _syncService;

  BookRepositoryImpl({
    required BookRemoteDataSource remoteDataSource,
    required BookLocalDataSource localDataSource,
    required NetworkInfo networkInfo,
    required SyncService syncService,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _networkInfo = networkInfo,
        _syncService = syncService;

  @override
  Future<Either<Failure, List<Book>>> getBooks({
    String? level,
    String? genre,
  }) async {
    // Always return local first for speed
    final localBooks = await _localDataSource.getBooks(
      level: level,
      genre: genre,
    );
    
    if (localBooks.isNotEmpty) {
      // Return local immediately, sync in background
      _syncBooksInBackground();
      return Right(localBooks.map((m) => m.toEntity()).toList());
    }
    
    // If no local data, try remote
    if (await _networkInfo.isConnected) {
      try {
        final remoteBooks = await _remoteDataSource.getBooks(
          level: level,
          genre: genre,
        );
        
        // Cache locally
        await _localDataSource.cacheBooks(remoteBooks);
        
        return Right(remoteBooks.map((m) => m.toEntity()).toList());
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message));
      }
    }
    
    return Left(NetworkFailure('No internet connection'));
  }

  @override
  Future<Either<Failure, void>> updateProgress({
    required String bookId,
    required int currentPage,
  }) async {
    // Always save locally first
    final progress = ReadingProgressModel(
      bookId: bookId,
      currentPage: currentPage,
      updatedAt: DateTime.now(),
      isSynced: false,
    );
    
    await _localDataSource.saveProgress(progress);
    
    // Queue for sync
    _syncService.queueSync(SyncItem(
      type: SyncType.readingProgress,
      data: progress.toJson(),
    ));
    
    return const Right(null);
  }

  Future<void> _syncBooksInBackground() async {
    if (!await _networkInfo.isConnected) return;
    
    try {
      final remoteBooks = await _remoteDataSource.getBooks();
      await _localDataSource.cacheBooks(remoteBooks);
    } catch (_) {
      // Fail silently, local data is still valid
    }
  }
}
```

#### 3.3.3 Isar Local Database Schema

```dart
// lib/data/datasources/local/schemas/book_schema.dart

import 'package:isar/isar.dart';

part 'book_schema.g.dart';

@collection
class BookLocal {
  Id get isarId => fastHash(id);
  
  @Index(unique: true)
  late String id;
  
  late String title;
  late String slug;
  late String? description;
  late String? coverUrl;
  
  @Index()
  late String level;
  
  @Index()
  late String? genre;
  
  late String? ageGroup;
  late int? estimatedMinutes;
  late int? wordCount;
  late String status;
  
  late DateTime createdAt;
  late DateTime updatedAt;
  late DateTime? syncedAt;
  
  // Embedded chapters for offline access
  late List<ChapterLocal> chapters;
}

@embedded
class ChapterLocal {
  late String id;
  late String title;
  late int order;
  late String? content;
  late String? audioUrl;
  late List<String>? imageUrls;
  late bool isDownloaded;
}

@collection
class ReadingProgressLocal {
  Id get isarId => fastHash('$userId-$bookId');
  
  @Index()
  late String userId;
  
  @Index()
  late String bookId;
  
  late String? chapterId;
  late int currentPage;
  late bool isCompleted;
  late double completionPercentage;
  late int totalReadingTime;
  
  late DateTime startedAt;
  late DateTime? completedAt;
  late DateTime updatedAt;
  
  @Index()
  late bool isSynced;
}

// Fast hash function for composite keys
int fastHash(String string) {
  var hash = 0xcbf29ce484222325;
  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }
  return hash;
}
```

---

## 4. Backend Architecture (Supabase)

### 4.1 Database Schema

```sql
-- =============================================
-- CORE TABLES
-- =============================================

-- Schools
CREATE TABLE schools (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    code VARCHAR(20) UNIQUE NOT NULL,
    logo_url VARCHAR(500),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'trial', 'suspended')),
    settings JSONB DEFAULT '{}',
    subscription_tier VARCHAR(20) DEFAULT 'free',
    subscription_expires_at TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Classes
CREATE TABLE classes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    grade INTEGER,
    academic_year VARCHAR(20),
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(school_id, name, academic_year)
);

-- Profiles (extends Supabase auth.users)
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE,
    class_id UUID REFERENCES classes(id) ON DELETE SET NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('student', 'teacher', 'head', 'admin')),
    student_number VARCHAR(50),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    avatar_url VARCHAR(500),
    
    -- Gamification
    xp INTEGER DEFAULT 0,
    level INTEGER DEFAULT 1,
    current_streak INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,
    last_activity_date DATE,
    
    -- Settings
    settings JSONB DEFAULT '{}',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(school_id, student_number)
);

-- =============================================
-- CONTENT TABLES
-- =============================================

-- Books
CREATE TABLE books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    cover_url VARCHAR(500),
    level VARCHAR(10) NOT NULL CHECK (level IN ('A1', 'A2', 'B1', 'B2', 'C1', 'C2')),
    genre VARCHAR(50),
    age_group VARCHAR(20) CHECK (age_group IN ('elementary', 'middle', 'high')),
    estimated_minutes INTEGER,
    word_count INTEGER,
    status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
    metadata JSONB DEFAULT '{}',
    published_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Chapters
CREATE TABLE chapters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    order_index INTEGER NOT NULL,
    content TEXT,
    audio_url VARCHAR(500),
    images JSONB DEFAULT '[]',
    word_count INTEGER,
    estimated_minutes INTEGER,
    vocabulary JSONB DEFAULT '[]',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(book_id, order_index)
);

-- Activities
CREATE TABLE activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chapter_id UUID NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL CHECK (type IN (
        'multiple_choice', 'true_false', 'matching', 
        'ordering', 'fill_blank', 'short_answer'
    )),
    order_index INTEGER NOT NULL,
    title VARCHAR(255),
    instructions TEXT,
    questions JSONB NOT NULL DEFAULT '[]',
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Vocabulary Words
CREATE TABLE vocabulary_words (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    word VARCHAR(100) NOT NULL,
    phonetic VARCHAR(100),
    meaning_tr TEXT NOT NULL,
    meaning_en TEXT,
    example_sentence TEXT,
    audio_url VARCHAR(500),
    image_url VARCHAR(500),
    level VARCHAR(10),
    categories VARCHAR(50)[] DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Chapter-Word relationship
CREATE TABLE chapter_vocabulary (
    chapter_id UUID REFERENCES chapters(id) ON DELETE CASCADE,
    word_id UUID REFERENCES vocabulary_words(id) ON DELETE CASCADE,
    PRIMARY KEY (chapter_id, word_id)
);

-- =============================================
-- PROGRESS TABLES
-- =============================================

-- Reading Progress
CREATE TABLE reading_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    chapter_id UUID REFERENCES chapters(id) ON DELETE SET NULL,
    current_page INTEGER DEFAULT 1,
    is_completed BOOLEAN DEFAULT FALSE,
    completion_percentage DECIMAL(5,2) DEFAULT 0,
    total_reading_time INTEGER DEFAULT 0,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(user_id, book_id)
);

-- Activity Results
CREATE TABLE activity_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    score DECIMAL(5,2) NOT NULL,
    max_score DECIMAL(5,2) NOT NULL,
    answers JSONB NOT NULL,
    time_spent INTEGER,
    attempt_number INTEGER DEFAULT 1,
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Vocabulary Progress (Spaced Repetition)
CREATE TABLE vocabulary_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    word_id UUID NOT NULL REFERENCES vocabulary_words(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'new' CHECK (status IN ('new', 'learning', 'reviewing', 'mastered')),
    ease_factor DECIMAL(3,2) DEFAULT 2.50,
    interval_days INTEGER DEFAULT 0,
    repetitions INTEGER DEFAULT 0,
    next_review_at TIMESTAMP WITH TIME ZONE,
    last_reviewed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(user_id, word_id)
);

-- =============================================
-- GAMIFICATION TABLES
-- =============================================

-- Badges
CREATE TABLE badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    icon VARCHAR(50),
    category VARCHAR(50),
    condition_type VARCHAR(50) NOT NULL,
    condition_value INTEGER NOT NULL,
    xp_reward INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User Badges
CREATE TABLE user_badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    badge_id UUID NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
    earned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(user_id, badge_id)
);

-- XP Logs
CREATE TABLE xp_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL,
    source VARCHAR(50) NOT NULL,
    source_id UUID,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================
-- ASSIGNMENT TABLES
-- =============================================

-- Assignments
CREATE TABLE assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    class_id UUID REFERENCES classes(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL CHECK (type IN ('book', 'vocabulary', 'mixed')),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    content_config JSONB NOT NULL,
    settings JSONB DEFAULT '{}',
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    due_date TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Assignment Students
CREATE TABLE assignment_students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assignment_id UUID NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'overdue')),
    score DECIMAL(5,2),
    progress DECIMAL(5,2) DEFAULT 0,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    UNIQUE(assignment_id, student_id)
);

-- =============================================
-- INDEXES
-- =============================================

CREATE INDEX idx_profiles_school ON profiles(school_id);
CREATE INDEX idx_profiles_class ON profiles(class_id);
CREATE INDEX idx_profiles_role ON profiles(role);

CREATE INDEX idx_books_level ON books(level);
CREATE INDEX idx_books_status ON books(status);
CREATE INDEX idx_books_genre ON books(genre);

CREATE INDEX idx_chapters_book ON chapters(book_id);
CREATE INDEX idx_activities_chapter ON activities(chapter_id);

CREATE INDEX idx_reading_progress_user ON reading_progress(user_id);
CREATE INDEX idx_reading_progress_book ON reading_progress(book_id);

CREATE INDEX idx_activity_results_user ON activity_results(user_id);
CREATE INDEX idx_activity_results_activity ON activity_results(activity_id);

CREATE INDEX idx_xp_logs_user ON xp_logs(user_id);
CREATE INDEX idx_xp_logs_created ON xp_logs(created_at);

CREATE INDEX idx_assignments_teacher ON assignments(teacher_id);
CREATE INDEX idx_assignments_class ON assignments(class_id);
CREATE INDEX idx_assignments_due ON assignments(due_date);

-- Full-text search for books
ALTER TABLE books ADD COLUMN fts tsvector 
    GENERATED ALWAYS AS (to_tsvector('english', coalesce(title, '') || ' ' || coalesce(description, ''))) STORED;
CREATE INDEX idx_books_fts ON books USING GIN(fts);
```

### 4.2 Row Level Security (RLS)

```sql
-- =============================================
-- ROW LEVEL SECURITY POLICIES
-- =============================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE books ENABLE ROW LEVEL SECURITY;
ALTER TABLE chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE reading_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE vocabulary_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE assignment_students ENABLE ROW LEVEL SECURITY;
ALTER TABLE xp_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_badges ENABLE ROW LEVEL SECURITY;

-- Helper function to get current user's school
CREATE OR REPLACE FUNCTION get_user_school_id()
RETURNS UUID AS $$
    SELECT school_id FROM profiles WHERE id = auth.uid();
$$ LANGUAGE SQL SECURITY DEFINER;

-- Helper function to get current user's role
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS TEXT AS $$
    SELECT role FROM profiles WHERE id = auth.uid();
$$ LANGUAGE SQL SECURITY DEFINER;

-- Profiles: Users can read within their school
CREATE POLICY "Users can view profiles in their school"
    ON profiles FOR SELECT
    USING (school_id = get_user_school_id());

CREATE POLICY "Users can update own profile"
    ON profiles FOR UPDATE
    USING (id = auth.uid());

-- Books: Everyone can read published books
CREATE POLICY "Anyone can read published books"
    ON books FOR SELECT
    USING (status = 'published');

CREATE POLICY "Admins can manage all books"
    ON books FOR ALL
    USING (get_user_role() = 'admin');

-- Reading Progress: Users can only access their own
CREATE POLICY "Users can manage own reading progress"
    ON reading_progress FOR ALL
    USING (user_id = auth.uid());

-- Teachers can view their students' progress
CREATE POLICY "Teachers can view student progress"
    ON reading_progress FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            JOIN classes c ON p.class_id = c.id
            WHERE p.id = reading_progress.user_id
            AND c.id IN (
                SELECT class_id FROM profiles 
                WHERE id = auth.uid() AND role = 'teacher'
            )
        )
    );

-- Assignments: Teachers can manage their assignments
CREATE POLICY "Teachers can manage own assignments"
    ON assignments FOR ALL
    USING (teacher_id = auth.uid() OR get_user_role() IN ('head', 'admin'));

-- Students can view assignments assigned to them
CREATE POLICY "Students can view their assignments"
    ON assignments FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM assignment_students
            WHERE assignment_id = assignments.id
            AND student_id = auth.uid()
        )
    );
```

### 4.3 Supabase Edge Functions

```typescript
// supabase/functions/award-xp/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface AwardXPRequest {
  userId: string
  amount: number
  source: string
  sourceId?: string
  description?: string
}

serve(async (req) => {
  try {
    const { userId, amount, source, sourceId, description } = await req.json() as AwardXPRequest
    
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )
    
    // Start transaction using RPC
    const { data, error } = await supabase.rpc('award_xp_transaction', {
      p_user_id: userId,
      p_amount: amount,
      p_source: source,
      p_source_id: sourceId,
      p_description: description
    })
    
    if (error) throw error
    
    // Check for badges
    await checkAndAwardBadges(supabase, userId)
    
    // Send xAPI statement to Learning Locker
    await sendXAPIStatement({
      actor: { mbox: `mailto:${userId}@readeng.com` },
      verb: { id: 'http://adlnet.gov/expapi/verbs/earned' },
      object: { 
        id: `https://readeng.com/xp/${source}`,
        definition: { name: { en: `Earned ${amount} XP` } }
      },
      result: { score: { raw: amount } }
    })
    
    return new Response(
      JSON.stringify({ success: true, data }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    )
  }
})

async function checkAndAwardBadges(supabase: any, userId: string) {
  // Get user stats
  const { data: profile } = await supabase
    .from('profiles')
    .select('xp, current_streak')
    .eq('id', userId)
    .single()
  
  // Get available badges user doesn't have
  const { data: availableBadges } = await supabase
    .from('badges')
    .select('*')
    .eq('is_active', true)
    .not('id', 'in', (
      supabase.from('user_badges').select('badge_id').eq('user_id', userId)
    ))
  
  for (const badge of availableBadges || []) {
    let earned = false
    
    switch (badge.condition_type) {
      case 'xp_total':
        earned = profile.xp >= badge.condition_value
        break
      case 'streak_days':
        earned = profile.current_streak >= badge.condition_value
        break
      // Add more conditions...
    }
    
    if (earned) {
      await supabase.from('user_badges').insert({
        user_id: userId,
        badge_id: badge.id
      })
      
      // Award badge XP
      if (badge.xp_reward > 0) {
        await supabase.rpc('add_xp', {
          p_user_id: userId,
          p_amount: badge.xp_reward
        })
      }
    }
  }
}

async function sendXAPIStatement(statement: any) {
  const LRS_ENDPOINT = Deno.env.get('LEARNING_LOCKER_ENDPOINT')
  const LRS_KEY = Deno.env.get('LEARNING_LOCKER_KEY')
  const LRS_SECRET = Deno.env.get('LEARNING_LOCKER_SECRET')
  
  await fetch(`${LRS_ENDPOINT}/statements`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Basic ${btoa(`${LRS_KEY}:${LRS_SECRET}`)}`
    },
    body: JSON.stringify(statement)
  })
}
```

```typescript
// supabase/functions/check-streak/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const { userId } = await req.json()
  
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )
  
  // Get user's last activity date
  const { data: profile } = await supabase
    .from('profiles')
    .select('last_activity_date, current_streak, longest_streak')
    .eq('id', userId)
    .single()
  
  const today = new Date().toISOString().split('T')[0]
  const lastActivity = profile.last_activity_date
  
  let newStreak = 1
  let streakBroken = false
  
  if (lastActivity) {
    const lastDate = new Date(lastActivity)
    const todayDate = new Date(today)
    const diffDays = Math.floor((todayDate.getTime() - lastDate.getTime()) / (1000 * 60 * 60 * 24))
    
    if (diffDays === 0) {
      // Same day, no change
      return new Response(JSON.stringify({ 
        streak: profile.current_streak,
        changed: false 
      }))
    } else if (diffDays === 1) {
      // Consecutive day, increment streak
      newStreak = profile.current_streak + 1
    } else {
      // Streak broken
      newStreak = 1
      streakBroken = true
    }
  }
  
  // Update profile
  const longestStreak = Math.max(newStreak, profile.longest_streak)
  
  await supabase
    .from('profiles')
    .update({
      current_streak: newStreak,
      longest_streak: longestStreak,
      last_activity_date: today
    })
    .eq('id', userId)
  
  // Award streak bonuses
  if (newStreak === 7) {
    await supabase.functions.invoke('award-xp', {
      body: { userId, amount: 50, source: 'streak_7_days' }
    })
  } else if (newStreak === 30) {
    await supabase.functions.invoke('award-xp', {
      body: { userId, amount: 200, source: 'streak_30_days' }
    })
  }
  
  return new Response(JSON.stringify({
    streak: newStreak,
    longestStreak,
    streakBroken,
    changed: true
  }))
})
```

### 4.4 Database Functions (PostgreSQL)

```sql
-- Award XP Transaction
CREATE OR REPLACE FUNCTION award_xp_transaction(
    p_user_id UUID,
    p_amount INTEGER,
    p_source VARCHAR,
    p_source_id UUID DEFAULT NULL,
    p_description TEXT DEFAULT NULL
)
RETURNS TABLE(new_xp INTEGER, new_level INTEGER, level_up BOOLEAN)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_xp INTEGER;
    v_new_xp INTEGER;
    v_current_level INTEGER;
    v_new_level INTEGER;
BEGIN
    -- Get current XP
    SELECT xp, level INTO v_current_xp, v_current_level
    FROM profiles
    WHERE id = p_user_id
    FOR UPDATE;
    
    -- Calculate new values
    v_new_xp := v_current_xp + p_amount;
    v_new_level := calculate_level(v_new_xp);
    
    -- Update profile
    UPDATE profiles
    SET xp = v_new_xp,
        level = v_new_level,
        updated_at = NOW()
    WHERE id = p_user_id;
    
    -- Log XP
    INSERT INTO xp_logs (user_id, amount, source, source_id, description)
    VALUES (p_user_id, p_amount, p_source, p_source_id, p_description);
    
    -- Return result
    RETURN QUERY SELECT v_new_xp, v_new_level, (v_new_level > v_current_level);
END;
$$;

-- Calculate Level from XP
CREATE OR REPLACE FUNCTION calculate_level(p_xp INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Level thresholds: 0, 100, 300, 600, 1000, 1500, 2100, 2800, 3600, 4500...
    -- Formula: threshold(n) = n * (n + 1) * 50
    RETURN FLOOR((-1 + SQRT(1 + p_xp / 25.0)) / 2) + 1;
END;
$$;

-- Get Class Leaderboard
CREATE OR REPLACE FUNCTION get_class_leaderboard(
    p_class_id UUID,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    avatar_url VARCHAR,
    xp INTEGER,
    level INTEGER,
    rank BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.first_name,
        p.last_name,
        p.avatar_url,
        p.xp,
        p.level,
        RANK() OVER (ORDER BY p.xp DESC)
    FROM profiles p
    WHERE p.class_id = p_class_id
    AND p.role = 'student'
    ORDER BY p.xp DESC
    LIMIT p_limit;
END;
$$;

-- Get Student Weak Areas
CREATE OR REPLACE FUNCTION get_student_weak_areas(p_user_id UUID)
RETURNS TABLE(
    area VARCHAR,
    success_rate DECIMAL,
    total_attempts INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.type as area,
        ROUND(AVG(ar.score / ar.max_score * 100), 2) as success_rate,
        COUNT(*)::INTEGER as total_attempts
    FROM activity_results ar
    JOIN activities a ON ar.activity_id = a.id
    WHERE ar.user_id = p_user_id
    AND ar.completed_at > NOW() - INTERVAL '30 days'
    GROUP BY a.type
    HAVING AVG(ar.score / ar.max_score * 100) < 70
    ORDER BY success_rate ASC;
END;
$$;
```

---

## 5. External Services Integration

### 5.1 Learning Locker (xAPI)

```typescript
// lib/core/services/xapi_service.dart

class XAPIService {
  final String endpoint;
  final String key;
  final String secret;
  
  XAPIService({
    required this.endpoint,
    required this.key,
    required this.secret,
  });
  
  Future<void> sendStatement(XAPIStatement statement) async {
    final response = await _client.post(
      Uri.parse('$endpoint/statements'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Basic ${base64Encode(utf8.encode('$key:$secret'))}',
        'X-Experience-API-Version': '1.0.3',
      },
      body: jsonEncode(statement.toJson()),
    );
    
    if (response.statusCode != 200) {
      throw XAPIException('Failed to send statement: ${response.body}');
    }
  }
  
  // Pre-built statement factories
  XAPIStatement bookStarted(String userId, String bookId, String bookTitle) {
    return XAPIStatement(
      actor: XAPIActor(mbox: 'mailto:$userId@readeng.com'),
      verb: XAPIVerb.started,
      object: XAPIObject(
        id: 'https://readeng.com/books/$bookId',
        definition: XAPIDefinition(
          name: {'en': bookTitle},
          type: 'http://adlnet.gov/expapi/activities/book',
        ),
      ),
    );
  }
  
  XAPIStatement chapterCompleted(
    String userId, 
    String chapterId, 
    String chapterTitle,
    double score,
    Duration duration,
  ) {
    return XAPIStatement(
      actor: XAPIActor(mbox: 'mailto:$userId@readeng.com'),
      verb: XAPIVerb.completed,
      object: XAPIObject(
        id: 'https://readeng.com/chapters/$chapterId',
        definition: XAPIDefinition(
          name: {'en': chapterTitle},
          type: 'http://adlnet.gov/expapi/activities/lesson',
        ),
      ),
      result: XAPIResult(
        score: XAPIScore(scaled: score / 100, raw: score, max: 100),
        duration: _formatDuration(duration),
        completion: true,
        success: score >= 60,
      ),
    );
  }
  
  XAPIStatement vocabularyLearned(
    String userId,
    String wordId,
    String word,
    bool correct,
  ) {
    return XAPIStatement(
      actor: XAPIActor(mbox: 'mailto:$userId@readeng.com'),
      verb: correct ? XAPIVerb.mastered : XAPIVerb.attempted,
      object: XAPIObject(
        id: 'https://readeng.com/vocabulary/$wordId',
        definition: XAPIDefinition(
          name: {'en': word},
          type: 'http://adlnet.gov/expapi/activities/vocabulary',
        ),
      ),
      result: XAPIResult(
        success: correct,
      ),
    );
  }
}
```

### 5.2 Meilisearch Integration

```typescript
// supabase/functions/sync-search/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { MeiliSearch } from 'https://esm.sh/meilisearch@0.36.0'

serve(async (req) => {
  const { type, record, old_record } = await req.json()
  
  const client = new MeiliSearch({
    host: Deno.env.get('MEILISEARCH_HOST')!,
    apiKey: Deno.env.get('MEILISEARCH_API_KEY')!,
  })
  
  const booksIndex = client.index('books')
  const wordsIndex = client.index('vocabulary')
  
  switch (type) {
    case 'INSERT':
    case 'UPDATE':
      if (record.status === 'published') {
        await booksIndex.addDocuments([{
          id: record.id,
          title: record.title,
          description: record.description,
          level: record.level,
          genre: record.genre,
          age_group: record.age_group,
        }])
      }
      break
      
    case 'DELETE':
      await booksIndex.deleteDocument(old_record.id)
      break
  }
  
  return new Response(JSON.stringify({ success: true }))
})
```

```dart
// lib/core/services/search_service.dart

class SearchService {
  final MeiliSearchClient _client;
  
  SearchService({required String host, required String apiKey})
      : _client = MeiliSearchClient(host, apiKey);
  
  Future<List<Book>> searchBooks(
    String query, {
    String? level,
    String? genre,
    int limit = 20,
  }) async {
    final index = _client.index('books');
    
    final filter = <String>[];
    if (level != null) filter.add('level = "$level"');
    if (genre != null) filter.add('genre = "$genre"');
    
    final result = await index.search(
      query,
      SearchQuery(
        limit: limit,
        filter: filter.isNotEmpty ? filter : null,
        attributesToRetrieve: ['id', 'title', 'level', 'genre', 'cover_url'],
      ),
    );
    
    return result.hits
        .map((hit) => Book.fromSearchHit(hit))
        .toList();
  }
  
  Future<List<VocabularyWord>> searchWords(
    String query, {
    int limit = 10,
  }) async {
    final index = _client.index('vocabulary');
    
    final result = await index.search(
      query,
      SearchQuery(limit: limit),
    );
    
    return result.hits
        .map((hit) => VocabularyWord.fromSearchHit(hit))
        .toList();
  }
}
```

### 5.3 Cloudflare R2 Configuration

```dart
// lib/core/services/storage_service.dart

class StorageService {
  final String r2Endpoint;
  final String r2AccessKey;
  final String r2SecretKey;
  final String bucketName;
  final String cdnUrl;
  
  late final Minio _client;
  
  StorageService({
    required this.r2Endpoint,
    required this.r2AccessKey,
    required this.r2SecretKey,
    required this.bucketName,
    required this.cdnUrl,
  }) {
    _client = Minio(
      endPoint: r2Endpoint,
      accessKey: r2AccessKey,
      secretKey: r2SecretKey,
      useSSL: true,
    );
  }
  
  String getPublicUrl(String path) {
    return '$cdnUrl/$path';
  }
  
  Future<String> uploadFile(
    String path,
    Uint8List data,
    String contentType,
  ) async {
    await _client.putObject(
      bucketName,
      path,
      Stream.fromIterable([data]),
      size: data.length,
      metadata: {'Content-Type': contentType},
    );
    
    return getPublicUrl(path);
  }
  
  Future<void> downloadBookForOffline(String bookId) async {
    // Download book content, images, and audio
    final chapters = await _getChapters(bookId);
    
    for (final chapter in chapters) {
      // Download audio
      if (chapter.audioUrl != null) {
        final audioData = await _downloadFile(chapter.audioUrl!);
        await _localStorage.saveAudio(chapter.id, audioData);
      }
      
      // Download images
      for (final imageUrl in chapter.imageUrls ?? []) {
        final imageData = await _downloadFile(imageUrl);
        await _localStorage.saveImage(imageUrl, imageData);
      }
    }
  }
}
```

---

## 6. Security

### 6.1 Authentication Flow

```
┌─────────┐                                    ┌─────────────┐
│ Flutter │                                    │  Supabase   │
│   App   │                                    │    Auth     │
└────┬────┘                                    └──────┬──────┘
     │                                                │
     │  1. Enter school code                         │
     │─────────────────────────────────────────────►│
     │                                                │
     │  2. School found, show login form              │
     │◄─────────────────────────────────────────────│
     │                                                │
     │  3. Login (email/student_number + password)   │
     │─────────────────────────────────────────────►│
     │                                                │
     │  4. Validate credentials                      │
     │                     ┌───────────────────────►│
     │                     │    Check school_id      │
     │                     │    Verify password      │
     │                     │◄───────────────────────│
     │                                                │
     │  5. Return JWT + Refresh Token                │
     │◄─────────────────────────────────────────────│
     │                                                │
     │  6. Store tokens securely                     │
     │     (flutter_secure_storage)                  │
     │                                                │
     │  7. API calls with Bearer token               │
     │─────────────────────────────────────────────►│
     │                                                │
```

### 6.2 Security Checklist

```
Authentication:
☑ JWT tokens with short expiry (1 hour)
☑ Refresh tokens stored in secure storage
☑ School code validation before login
☑ Password hashing (bcrypt via Supabase)
☑ Rate limiting on auth endpoints

Authorization:
☑ Row Level Security (RLS) on all tables
☑ Role-based access control
☑ School isolation (multi-tenancy)
☑ API key rotation support

Data Protection:
☑ HTTPS everywhere (Cloudflare SSL)
☑ Encryption at rest (Supabase default)
☑ No PII in logs
☑ KVKK compliant data handling

Client Security:
☑ Certificate pinning (optional)
☑ Secure storage for tokens
☑ ProGuard/obfuscation for release builds
☑ No sensitive data in app bundle
```

### 6.3 KVKK Compliance

```
Veri İşleme:
├── Açık rıza: Okul sözleşmesi kapsamında
├── Çocuk verisi: 13 yaş altı için veli onayı
├── Veri minimizasyonu: Sadece gerekli veriler
└── Amaç sınırlaması: Sadece eğitim amaçlı

Veri Saklama:
├── Konum: Supabase EU (Frankfurt)
├── Şifreleme: AES-256 at rest
├── Backup: Günlük, 30 gün tutma
└── Silme: Hesap silinince 30 gün sonra kalıcı silme

Veri Erişimi:
├── Audit log: Tüm admin işlemleri
├── Erişim kontrolü: RLS ile
├── Veri aktarımı: Talep üzerine JSON/CSV export
└── Silme hakkı: Settings'ten hesap silme
```

---

## 7. Performance & Scalability

### 7.1 Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| App startup | < 2s | Cold start to home screen |
| Page transition | < 300ms | Navigation animation |
| API response (P95) | < 500ms | Supabase latency |
| Book page load | < 100ms | Local DB read |
| Audio start | < 500ms | Streaming start |
| Search results | < 200ms | Meilisearch response |
| Offline sync | < 30s | Full book download |

### 7.2 Caching Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                      CACHING LAYERS                             │
└─────────────────────────────────────────────────────────────────┘

Layer 1: Flutter Memory Cache
├── Current screen data
├── Recently accessed books
├── User profile
└── TTL: Session lifetime

Layer 2: Isar Local Database
├── All downloaded books
├── Reading progress (offline-first)
├── Activity results (queue for sync)
├── Vocabulary progress
└── TTL: Until manually deleted

Layer 3: Cloudflare CDN
├── Book cover images
├── Chapter images
├── Audio files
└── TTL: 30 days

Layer 4: Supabase/PostgreSQL
├── Query result caching
├── Materialized views (leaderboard)
└── Connection pooling (PgBouncer)
```

### 7.3 Offline Capabilities

```dart
// lib/core/services/sync_service.dart

class SyncService {
  final IsarDatabase _localDb;
  final SupabaseClient _supabase;
  final ConnectivityService _connectivity;
  
  final _syncQueue = <SyncItem>[];
  
  // Queue items for sync when online
  void queueSync(SyncItem item) {
    _localDb.syncQueue.add(item);
    _trySyncIfOnline();
  }
  
  // Try to sync when connectivity changes
  Future<void> _trySyncIfOnline() async {
    if (!await _connectivity.isOnline) return;
    
    final pendingItems = await _localDb.syncQueue.getAll();
    
    for (final item in pendingItems) {
      try {
        await _syncItem(item);
        await _localDb.syncQueue.delete(item.id);
      } catch (e) {
        // Will retry next time
        break;
      }
    }
  }
  
  Future<void> _syncItem(SyncItem item) async {
    switch (item.type) {
      case SyncType.readingProgress:
        await _supabase.from('reading_progress').upsert(item.data);
        break;
      case SyncType.activityResult:
        await _supabase.from('activity_results').insert(item.data);
        break;
      case SyncType.vocabularyProgress:
        await _supabase.from('vocabulary_progress').upsert(item.data);
        break;
    }
  }
  
  // Download book for offline reading
  Future<void> downloadBook(String bookId) async {
    // 1. Get book metadata
    final book = await _supabase
        .from('books')
        .select('*, chapters(*)')
        .eq('id', bookId)
        .single();
    
    // 2. Save to local DB
    await _localDb.books.put(BookLocal.fromJson(book));
    
    // 3. Download media files
    for (final chapter in book['chapters']) {
      if (chapter['audio_url'] != null) {
        final audioBytes = await _downloadFile(chapter['audio_url']);
        await _localDb.media.put(MediaLocal(
          url: chapter['audio_url'],
          data: audioBytes,
        ));
      }
      
      for (final imageUrl in chapter['images'] ?? []) {
        final imageBytes = await _downloadFile(imageUrl);
        await _localDb.media.put(MediaLocal(
          url: imageUrl,
          data: imageBytes,
        ));
      }
    }
    
    // 4. Mark as downloaded
    await _localDb.books.put(
      bookLocal.copyWith(isDownloaded: true),
    );
  }
}
```

### 7.4 Scaling Plan

```
┌─────────────────────────────────────────────────────────────────┐
│                      SCALING STAGES                             │
└─────────────────────────────────────────────────────────────────┘

Stage 1: MVP (0 - 5,000 users)
├── Supabase Free / Pro ($25/mo)
├── Cloudflare Free
├── Meilisearch Cloud Free (10K docs)
├── Learning Locker Free tier
└── Total: ~$25-50/month

Stage 2: Growth (5,000 - 20,000 users)
├── Supabase Pro ($25/mo)
├── Cloudflare Pro ($20/mo)
├── Meilisearch Cloud ($29/mo)
├── Learning Locker Basic ($49/mo)
├── PostHog Free tier
└── Total: ~$125/month

Stage 3: Scale (20,000 - 100,000 users)
├── Supabase Team ($599/mo)
├── Cloudflare Business ($200/mo)
├── Meilisearch Cloud Pro ($99/mo)
├── Learning Locker Pro ($199/mo)
├── PostHog Scale ($450/mo)
└── Total: ~$1,500/month

Stage 4: Enterprise (100,000+ users)
├── Supabase Enterprise (custom)
├── Cloudflare Enterprise (custom)
├── Self-hosted options evaluated
└── Total: ~$5,000+/month
```

---

## 8. Development Workflow

### 8.1 Project Setup

```bash
# 1. Clone repository
git clone https://github.com/readeng/readeng-app.git
cd readeng-app

# 2. Install Flutter dependencies
flutter pub get

# 3. Generate code (Isar, Riverpod, JSON serialization)
dart run build_runner build --delete-conflicting-outputs

# 4. Setup Supabase CLI
npm install -g supabase
supabase login
supabase link --project-ref your-project-ref

# 5. Run database migrations
supabase db push

# 6. Setup environment variables
cp .env.example .env
# Edit .env with your keys

# 7. Run the app
flutter run
```

### 8.2 Environment Configuration

```dart
// lib/core/config/env_config.dart

enum Environment { development, staging, production }

class EnvConfig {
  static late Environment environment;
  
  static String get supabaseUrl {
    switch (environment) {
      case Environment.development:
        return 'http://localhost:54321';
      case Environment.staging:
        return 'https://xxx-staging.supabase.co';
      case Environment.production:
        return 'https://xxx.supabase.co';
    }
  }
  
  static String get supabaseAnonKey {
    return const String.fromEnvironment('SUPABASE_ANON_KEY');
  }
  
  static String get meiliSearchHost {
    return const String.fromEnvironment('MEILISEARCH_HOST');
  }
  
  static String get meiliSearchKey {
    return const String.fromEnvironment('MEILISEARCH_KEY');
  }
  
  static String get cdnUrl {
    return const String.fromEnvironment('CDN_URL');
  }
}
```

### 8.3 CI/CD Pipeline (GitHub Actions)

```yaml
# .github/workflows/main.yml

name: ReadEng CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.x'
          channel: 'stable'
          
      - name: Install dependencies
        run: flutter pub get
        
      - name: Generate code
        run: dart run build_runner build
        
      - name: Analyze
        run: flutter analyze
        
      - name: Run tests
        run: flutter test --coverage
        
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: coverage/lcov.info

  build-android:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.x'
          
      - name: Build APK
        run: |
          flutter build apk --release \
            --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
            --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
            
      - name: Upload to Play Store
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
          packageName: com.readeng.app
          releaseFiles: build/app/outputs/flutter-apk/app-release.apk
          track: internal

  build-ios:
    needs: test
    runs-on: macos-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.x'
          
      - name: Build iOS
        run: |
          flutter build ipa --release \
            --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
            --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
            
      - name: Upload to TestFlight
        uses: apple-actions/upload-testflight-build@v1
        with:
          app-path: build/ios/ipa/readeng.ipa
          issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
          api-key-id: ${{ secrets.APPSTORE_API_KEY_ID }}
          api-private-key: ${{ secrets.APPSTORE_API_PRIVATE_KEY }}

  build-web:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.x'
          
      - name: Build Web
        run: |
          flutter build web --release \
            --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
            --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
            
      - name: Deploy to Cloudflare Pages
        uses: cloudflare/pages-action@v1
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          projectName: readeng-web
          directory: build/web

  deploy-supabase:
    needs: [build-android, build-ios, build-web]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: supabase/setup-cli@v1
        with:
          version: latest
          
      - name: Deploy migrations
        run: |
          supabase link --project-ref ${{ secrets.SUPABASE_PROJECT_REF }}
          supabase db push
          
      - name: Deploy Edge Functions
        run: supabase functions deploy
```

---

## 9. Monitoring & Observability

### 9.1 Error Tracking (Sentry)

```dart
// lib/main.dart

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = EnvConfig.sentryDsn;
      options.environment = EnvConfig.environment.name;
      options.tracesSampleRate = 0.2;
      options.profilesSampleRate = 0.2;
    },
    appRunner: () => runApp(
      ProviderScope(
        child: const ReadEngApp(),
      ),
    ),
  );
}

// Usage
try {
  await doSomething();
} catch (e, stackTrace) {
  Sentry.captureException(e, stackTrace: stackTrace);
  rethrow;
}
```

### 9.2 Analytics Events

```dart
// lib/core/services/analytics_service.dart

class AnalyticsService {
  final Posthog _posthog;
  final XAPIService _xapi;
  
  // Track screen views
  void trackScreen(String screenName) {
    _posthog.screen(screenName: screenName);
  }
  
  // Track user actions
  void trackEvent(String event, {Map<String, dynamic>? properties}) {
    _posthog.capture(eventName: event, properties: properties);
  }
  
  // Learning events (also sent to xAPI)
  Future<void> trackBookStarted(Book book) async {
    trackEvent('book_started', properties: {
      'book_id': book.id,
      'book_title': book.title,
      'book_level': book.level,
    });
    
    await _xapi.sendStatement(_xapi.bookStarted(
      _userId,
      book.id,
      book.title,
    ));
  }
  
  Future<void> trackChapterCompleted(
    Chapter chapter,
    double score,
    Duration duration,
  ) async {
    trackEvent('chapter_completed', properties: {
      'chapter_id': chapter.id,
      'score': score,
      'duration_seconds': duration.inSeconds,
    });
    
    await _xapi.sendStatement(_xapi.chapterCompleted(
      _userId,
      chapter.id,
      chapter.title,
      score,
      duration,
    ));
  }
}
```

### 9.3 Logging Configuration

```typescript
// Logflare integration via Supabase

// supabase/functions/_shared/logger.ts
export function log(level: string, message: string, data?: any) {
  const payload = {
    level,
    message,
    timestamp: new Date().toISOString(),
    ...data,
  };
  
  console.log(JSON.stringify(payload));
  
  // Logflare picks up from stdout automatically
}

// Usage in Edge Functions
import { log } from '../_shared/logger.ts'

log('info', 'XP awarded', { userId, amount, source });
log('error', 'Failed to award XP', { userId, error: e.message });
```

---

## 10. Cost Estimation

### 10.1 Monthly Cost Breakdown (MVP)

| Service | Plan | Cost |
|---------|------|------|
| Supabase | Pro | $25 |
| Cloudflare | Free | $0 |
| Cloudflare R2 | Free tier (10GB) | $0 |
| Meilisearch | Free tier | $0 |
| Learning Locker | Free tier | $0 |
| PostHog | Free tier | $0 |
| Sentry | Free tier | $0 |
| Apple Developer | Annual / 12 | $8 |
| Google Play | One-time / 12 | $2 |
| **Total** | | **~$35/month** |

### 10.2 Cost at Scale (50K users)

| Service | Plan | Cost |
|---------|------|------|
| Supabase | Team | $599 |
| Cloudflare | Pro | $20 |
| Cloudflare R2 | ~100GB | $15 |
| Meilisearch | Pro | $99 |
| Learning Locker | Basic | $49 |
| PostHog | Free (generous) | $0 |
| Sentry | Team | $26 |
| **Total** | | **~$810/month** |

---

## 11. Glossary

| Term | Definition |
|------|------------|
| **RLS** | Row Level Security - PostgreSQL feature for row-based access control |
| **xAPI** | Experience API - E-learning standard for tracking learning activities |
| **LRS** | Learning Record Store - Database for xAPI statements |
| **Isar** | Fast, Flutter-native NoSQL database |
| **Edge Function** | Serverless function running on Supabase/Deno |
| **R2** | Cloudflare's S3-compatible object storage |
| **Riverpod** | State management library for Flutter |
| **GoRouter** | Declarative routing package for Flutter |

---

## 12. Document History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | Ocak 2025 | Initial (Next.js + NestJS) | - |
| 2.0 | Ocak 2025 | Revised (Flutter + Supabase) | - |
