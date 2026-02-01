# Clean Architecture Refactor Planı

**Proje:** ReadEng (Wonderlib)
**Oluşturulma:** 2026-02-01
**Tahmini Süre:** 10-12 gün
**Durum:** 🟡 Devam Ediyor

---

## İçindekiler

1. [Özet](#özet)
2. [Mimari Hedef](#mimari-hedef)
3. [Mevcut Durum Analizi](#mevcut-durum-analizi)
4. [Strateji ve Prensipler](#strateji-ve-prensipler)
5. [Git Branching Stratejisi](#git-branching-stratejisi)
6. [Dosya Yapısı](#dosya-yapısı)
7. [Modül Planları](#modül-planları)
8. [Master Checklist](#master-checklist)
9. [Doğrulama Komutları](#doğrulama-komutları)
10. [Sorun Giderme](#sorun-giderme)

---

## Özet

Bu refactor ile:
- **48 UseCase** oluşturulacak (4 mevcut)
- **~25 Model** sınıfı eklenecek
- **Tüm Provider'lar** UseCase kullanacak
- **Tüm Screen'ler** Repository import'larından temizlenecek

### Temel Değişiklikler

| Katman | Önce | Sonra |
|--------|------|-------|
| Screen | Repository çağırıyor | Sadece Provider kullanıyor |
| Provider | Repository çağırıyor | UseCase çağırıyor |
| UseCase | Yok (4 tane var) | Tüm iş mantığı burada |
| Repository | Entity döndürüyor | Model→Entity dönüşümü |
| Model | Yok | JSON↔Entity köprüsü |

---

## Mimari Hedef

### Katman Akışı (Doğru Yön)

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│  ┌─────────┐    ┌──────────┐                                │
│  │ Screen  │───▶│ Provider │  (Widget + State)              │
│  └─────────┘    └────┬─────┘                                │
└──────────────────────┼──────────────────────────────────────┘
                       │ calls
┌──────────────────────▼──────────────────────────────────────┐
│                      DOMAIN LAYER                            │
│  ┌─────────┐    ┌────────────┐                              │
│  │ UseCase │───▶│ Repository │  (Business Logic + Interface)│
│  └─────────┘    │ (Interface)│                              │
│                 └────────────┘                              │
└──────────────────────┼──────────────────────────────────────┘
                       │ implements
┌──────────────────────▼──────────────────────────────────────┐
│                       DATA LAYER                             │
│  ┌────────────────┐    ┌───────┐    ┌──────────┐           │
│  │ RepositoryImpl │───▶│ Model │───▶│ Supabase │           │
│  └────────────────┘    └───────┘    └──────────┘           │
└─────────────────────────────────────────────────────────────┘
```

### Bağımlılık Kuralı

```
Screen → Provider → UseCase → Repository Interface
                                      ↑
                              Repository Impl → Model → External
```

**KRİTİK:** Oklar sadece içeri doğru. Domain katmanı hiçbir şeye bağımlı değil.

---

## Mevcut Durum Analizi

### İhlaller (Refactor Öncesi)

| İhlal Tipi | Sayı | Örnek |
|------------|------|-------|
| Screen→Repository import | 12+ | `reader_screen.dart` |
| Screen→Repository çağrısı | 8+ | `bookRepo.updateCurrentChapter()` |
| Provider→Repository (UseCase bypass) | 70+ | Tüm provider'lar |
| Model katmanı eksik | %100 | Entity direkt JSON parse |

### Mevcut Yapılar (Korunacak)

```
✅ lib/domain/usecases/usecase.dart          # Base class
✅ lib/domain/usecases/teacher/reset_student_password_usecase.dart
✅ lib/domain/usecases/teacher/change_student_class_usecase.dart
✅ lib/domain/usecases/assignment/create_assignment_usecase.dart
✅ lib/domain/usecases/reading/save_reading_progress_usecase.dart
✅ lib/presentation/providers/usecase_providers.dart
```

---

## Strateji ve Prensipler

### 1. Modül Bazlı İlerleme

Her modül tamamen bitirilmeden sonrakine geçilmez.

```
Auth ✅ → Book ✅ → Activity ✅ → Vocabulary ✅ → Badge ✅ → Teacher ✅ → Student ✅
```

### 2. Her Modülde Sıralama

```
1. Model sınıfları oluştur
2. Repository implementasyonunu güncelle (Model kullan)
3. UseCase'leri oluştur
4. Provider'ları güncelle (UseCase kullan)
5. Screen'leri temizle (Repository import kaldır)
6. dart analyze + test
7. Commit + merge
```

### 3. Atlanmaması Gereken Kurallar

⚠️ **KRİTİK KURALLAR:**

| Kural | Neden |
|-------|-------|
| Her Model'de `toEntity()` olmalı | Dönüşüm standardı |
| Her Model'de `fromJson()` factory olmalı | Supabase entegrasyonu |
| UseCase'ler Flutter import etmemeli | Domain katmanı saf kalmalı |
| Screen'ler Repository import etmemeli | Presentation→Domain direkt bağlantı yasak |
| Her UseCase `Either<Failure, T>` döndürmeli | Hata yönetimi standardı |
| Provider'lar `ref.watch(useCaseProvider)` kullanmalı | DI standardı |

### 4. UseCase Şablonu

```dart
import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../repositories/xxx_repository.dart';
import '../usecase.dart';

class XxxParams {
  final String param1;
  final int param2;

  const XxxParams({
    required this.param1,
    required this.param2,
  });
}

class XxxUseCase implements UseCase<ReturnType, XxxParams> {
  final XxxRepository _repository;

  const XxxUseCase(this._repository);

  @override
  Future<Either<Failure, ReturnType>> call(XxxParams params) {
    return _repository.someMethod(params.param1, params.param2);
  }
}
```

### 5. Model Şablonu

```dart
import '../../domain/entities/xxx.dart';

class XxxModel {
  final String id;
  final String name;
  final DateTime createdAt;

  const XxxModel({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory XxxModel.fromJson(Map<String, dynamic> json) {
    return XxxModel(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Xxx toEntity() {
    return Xxx(
      id: id,
      name: name,
      createdAt: createdAt,
    );
  }

  factory XxxModel.fromEntity(Xxx entity) {
    return XxxModel(
      id: entity.id,
      name: entity.name,
      createdAt: entity.createdAt,
    );
  }
}
```

---

## Git Branching Stratejisi

### Branch Yapısı

```
main
 │
 └── feature/clean-architecture-refactor (ana refactor branch)
      │
      ├── refactor/model-layer-setup        # Model base yapısı
      ├── refactor/auth-module              # Auth modülü
      ├── refactor/book-module              # Book modülü
      ├── refactor/activity-module          # Activity modülü
      ├── refactor/vocabulary-module        # Vocabulary modülü
      ├── refactor/badge-module             # Badge modülü
      ├── refactor/teacher-module           # Teacher modülü
      └── refactor/student-assignment-module # Student Assignment modülü
```

### Branch Workflow

```bash
# 1. Ana refactor branch oluştur
git checkout main
git pull origin main
git checkout -b feature/clean-architecture-refactor

# 2. Her modül için
git checkout -b refactor/auth-module
# ... çalış ...
git add .
git commit -m "refactor(auth): add Model layer and UseCases"
git checkout feature/clean-architecture-refactor
git merge refactor/auth-module
git branch -d refactor/auth-module

# 3. Tüm modüller bitince
git checkout main
git merge feature/clean-architecture-refactor
```

### Commit Mesaj Formatı

```
refactor(module): kısa açıklama

- Model sınıfları eklendi
- UseCase'ler oluşturuldu
- Provider'lar güncellendi
- Screen'ler temizlendi
```

---

## Dosya Yapısı

### Hedef Yapı (Refactor Sonrası)

```
lib/
├── core/
│   ├── errors/
│   │   └── failures.dart
│   └── utils/
│
├── data/
│   ├── models/                          # YENİ
│   │   ├── auth/
│   │   │   └── user_model.dart
│   │   ├── book/
│   │   │   ├── book_model.dart
│   │   │   └── chapter_model.dart
│   │   ├── activity/
│   │   │   ├── activity_model.dart
│   │   │   └── inline_activity_model.dart
│   │   ├── vocabulary/
│   │   │   ├── vocabulary_word_model.dart
│   │   │   └── word_list_model.dart
│   │   ├── badge/
│   │   │   └── badge_model.dart
│   │   ├── teacher/
│   │   │   ├── teacher_stats_model.dart
│   │   │   ├── teacher_class_model.dart
│   │   │   └── student_summary_model.dart
│   │   └── assignment/
│   │       ├── assignment_model.dart
│   │       └── student_assignment_model.dart
│   │
│   ├── datasources/
│   │   └── remote/
│   │
│   └── repositories/
│       └── supabase/                    # Model kullanacak şekilde güncelle
│           ├── supabase_auth_repository.dart
│           ├── supabase_book_repository.dart
│           ├── supabase_activity_repository.dart
│           ├── supabase_vocabulary_repository.dart
│           ├── supabase_badge_repository.dart
│           ├── supabase_teacher_repository.dart
│           └── supabase_student_assignment_repository.dart
│
├── domain/
│   ├── entities/                        # Değişmez (fromJson kaldırılacak)
│   │   ├── user.dart
│   │   ├── book.dart
│   │   ├── chapter.dart
│   │   ├── activity.dart
│   │   ├── vocabulary_word.dart
│   │   ├── badge.dart
│   │   └── assignment.dart
│   │
│   ├── repositories/                    # Interface'ler (değişmez)
│   │   ├── auth_repository.dart
│   │   ├── book_repository.dart
│   │   ├── activity_repository.dart
│   │   ├── vocabulary_repository.dart
│   │   ├── badge_repository.dart
│   │   ├── teacher_repository.dart
│   │   └── student_assignment_repository.dart
│   │
│   └── usecases/                        # YENİ (48 UseCase)
│       ├── usecase.dart                 # Base class (mevcut)
│       ├── auth/
│       │   ├── sign_in_with_email_usecase.dart
│       │   ├── sign_in_with_student_number_usecase.dart
│       │   ├── sign_out_usecase.dart
│       │   └── get_current_user_usecase.dart
│       ├── book/
│       │   ├── get_books_usecase.dart
│       │   ├── get_book_by_id_usecase.dart
│       │   ├── search_books_usecase.dart
│       │   ├── get_chapters_usecase.dart
│       │   └── get_continue_reading_usecase.dart
│       ├── reading/
│       │   ├── save_reading_progress_usecase.dart  # Mevcut
│       │   ├── get_reading_progress_usecase.dart
│       │   ├── mark_chapter_complete_usecase.dart
│       │   └── update_current_chapter_usecase.dart
│       ├── activity/
│       │   ├── get_inline_activities_usecase.dart
│       │   ├── save_inline_activity_result_usecase.dart
│       │   ├── get_completed_inline_activities_usecase.dart
│       │   └── submit_activity_result_usecase.dart
│       ├── vocabulary/
│       │   ├── search_words_usecase.dart
│       │   ├── add_word_to_vocabulary_usecase.dart
│       │   ├── get_words_due_for_review_usecase.dart
│       │   └── get_all_word_lists_usecase.dart
│       ├── badge/
│       │   ├── get_all_badges_usecase.dart
│       │   ├── get_user_badges_usecase.dart
│       │   └── award_badge_usecase.dart
│       ├── user/
│       │   ├── get_user_stats_usecase.dart
│       │   ├── add_xp_usecase.dart
│       │   └── update_streak_usecase.dart
│       ├── teacher/
│       │   ├── reset_student_password_usecase.dart  # Mevcut
│       │   ├── change_student_class_usecase.dart    # Mevcut
│       │   ├── get_teacher_stats_usecase.dart
│       │   ├── get_classes_usecase.dart
│       │   ├── create_class_usecase.dart
│       │   └── send_password_reset_email_usecase.dart
│       ├── assignment/
│       │   ├── create_assignment_usecase.dart       # Mevcut
│       │   ├── get_assignments_usecase.dart
│       │   ├── get_assignment_detail_usecase.dart
│       │   └── delete_assignment_usecase.dart
│       └── student_assignment/
│           ├── get_active_assignments_usecase.dart
│           ├── start_assignment_usecase.dart
│           └── complete_assignment_usecase.dart
│
└── presentation/
    ├── providers/
    │   ├── usecase_providers.dart       # Tüm UseCase provider'ları
    │   ├── repository_providers.dart    # Değişmez
    │   ├── auth_provider.dart           # UseCase kullanacak
    │   ├── book_provider.dart           # UseCase kullanacak
    │   ├── activity_provider.dart       # UseCase kullanacak
    │   ├── vocabulary_provider.dart     # UseCase kullanacak
    │   ├── badge_provider.dart          # UseCase kullanacak
    │   ├── teacher_provider.dart        # UseCase kullanacak
    │   └── student_assignment_provider.dart  # UseCase kullanacak
    │
    ├── screens/                         # Repository import YASAK
    │   ├── auth/
    │   ├── home/
    │   ├── library/
    │   ├── reader/
    │   ├── vocabulary/
    │   ├── teacher/
    │   └── student/
    │
    └── widgets/
```

---

## Modül Planları

### Modül 0: Hazırlık (Başlamadan Önce)

**Süre:** 1 saat

- [x] Git branch oluştur: `feature/clean-architecture-refactor`
- [x] Mevcut durumu commit et (baseline)
- [x] `lib/data/models/` klasörü oluştur
- [x] Model base yapısını hazırla

```bash
# Komutlar
git checkout -b feature/clean-architecture-refactor
git status
git add .
git commit -m "chore: baseline before clean architecture refactor"
mkdir -p lib/data/models/{auth,book,activity,vocabulary,badge,teacher,assignment}
```

---

### Modül 1: Auth

**Süre:** 3-4 saat
**Branch:** `refactor/auth-module`

#### 1.1 Model Oluştur

| Model | Dosya |
|-------|-------|
| UserModel | `lib/data/models/auth/user_model.dart` |

#### 1.2 UseCase Oluştur

| UseCase | Params | Return |
|---------|--------|--------|
| SignInWithEmailUseCase | email, password | `Either<Failure, User>` |
| SignInWithStudentNumberUseCase | studentNumber, password | `Either<Failure, User>` |
| SignOutUseCase | NoParams | `Either<Failure, void>` |
| GetCurrentUserUseCase | NoParams | `Either<Failure, User?>` |

#### 1.3 Dosya Checklist

- [x] `lib/data/models/auth/user_model.dart`
- [x] `lib/domain/usecases/auth/sign_in_with_email_usecase.dart`
- [x] `lib/domain/usecases/auth/sign_in_with_student_number_usecase.dart`
- [x] `lib/domain/usecases/auth/sign_out_usecase.dart`
- [x] `lib/domain/usecases/auth/get_current_user_usecase.dart`
- [x] `lib/data/repositories/supabase/supabase_auth_repository.dart` güncelle
- [x] `lib/presentation/providers/usecase_providers.dart` güncelle
- [x] `lib/presentation/providers/auth_provider.dart` güncelle
- [x] `lib/presentation/screens/auth/login_screen.dart` temizle (zaten temizdi)
- [x] `lib/presentation/screens/splash_screen.dart` temizle (zaten temizdi)
- [x] `dart analyze` çalıştır
- [x] Test et: Login akışı
- [x] Commit

---

### Modül 2: Book & Reading

**Süre:** 6-8 saat
**Branch:** `refactor/book-module`

#### 2.1 Model Oluştur

| Model | Dosya |
|-------|-------|
| BookModel | `lib/data/models/book/book_model.dart` |
| ChapterModel | `lib/data/models/book/chapter_model.dart` |
| ReadingProgressModel | `lib/data/models/book/reading_progress_model.dart` |

#### 2.2 UseCase Oluştur

| UseCase | Params | Return |
|---------|--------|--------|
| GetBooksUseCase | level?, genre?, page | `Either<Failure, List<Book>>` |
| GetBookByIdUseCase | bookId | `Either<Failure, Book>` |
| SearchBooksUseCase | query | `Either<Failure, List<Book>>` |
| GetChaptersUseCase | bookId | `Either<Failure, List<Chapter>>` |
| GetChapterByIdUseCase | chapterId | `Either<Failure, Chapter>` |
| GetContinueReadingUseCase | userId | `Either<Failure, List<Book>>` |
| GetReadingProgressUseCase | userId, bookId | `Either<Failure, ReadingProgress>` |
| MarkChapterCompleteUseCase | userId, bookId, chapterId | `Either<Failure, ReadingProgress>` |
| UpdateCurrentChapterUseCase | userId, bookId, chapterId | `Either<Failure, void>` |
| GetUserReadingHistoryUseCase | userId | `Either<Failure, List<ReadingProgress>>` |

**Not:** `SaveReadingProgressUseCase` zaten mevcut.

#### 2.3 Dosya Checklist

- [x] `lib/data/models/book/book_model.dart`
- [x] `lib/data/models/book/chapter_model.dart`
- [x] `lib/data/models/book/reading_progress_model.dart`
- [x] `lib/domain/usecases/book/get_books_usecase.dart`
- [x] `lib/domain/usecases/book/get_book_by_id_usecase.dart`
- [x] `lib/domain/usecases/book/search_books_usecase.dart`
- [x] `lib/domain/usecases/book/get_chapters_usecase.dart`
- [x] `lib/domain/usecases/book/get_chapter_by_id_usecase.dart`
- [x] `lib/domain/usecases/book/get_continue_reading_usecase.dart`
- [x] `lib/domain/usecases/reading/get_reading_progress_usecase.dart`
- [x] `lib/domain/usecases/reading/mark_chapter_complete_usecase.dart`
- [x] `lib/domain/usecases/reading/update_current_chapter_usecase.dart`
- [x] `lib/domain/usecases/reading/get_user_reading_history_usecase.dart`
- [x] `lib/domain/usecases/book/get_recommended_books_usecase.dart` (ek)
- [x] `lib/domain/usecases/reading/update_reading_progress_usecase.dart` (ek)
- [x] `lib/data/repositories/supabase/supabase_book_repository.dart` güncelle
- [x] `lib/presentation/providers/usecase_providers.dart` güncelle
- [x] `lib/presentation/providers/book_provider.dart` güncelle
- [x] `lib/presentation/screens/library/library_screen.dart` temizle (zaten temizdi)
- [x] `lib/presentation/screens/library/book_detail_screen.dart` temizle (zaten temizdi)
- [x] `lib/presentation/screens/reader/reader_screen.dart` temizle
- [x] `lib/presentation/screens/home/home_screen.dart` temizle (zaten temizdi)
- [x] `dart analyze` çalıştır
- [ ] Test et: Kütüphane, kitap detay, okuma
- [x] Commit

---

### Modül 3: Activity

**Süre:** 4-5 saat
**Branch:** `refactor/activity-module`

#### 3.1 Model Oluştur

| Model | Dosya |
|-------|-------|
| ActivityModel | `lib/data/models/activity/activity_model.dart` |
| InlineActivityModel | `lib/data/models/activity/inline_activity_model.dart` |
| ActivityResultModel | `lib/data/models/activity/activity_result_model.dart` |

#### 3.2 UseCase Oluştur

| UseCase | Params | Return |
|---------|--------|--------|
| GetActivitiesByChapterUseCase | chapterId | `Either<Failure, List<Activity>>` |
| GetInlineActivitiesUseCase | chapterId | `Either<Failure, List<InlineActivity>>` |
| SubmitActivityResultUseCase | result | `Either<Failure, ActivityResult>` |
| SaveInlineActivityResultUseCase | userId, activityId, isCorrect, xp | `Either<Failure, bool>` |
| GetCompletedInlineActivitiesUseCase | userId, chapterId | `Either<Failure, List<String>>` |
| GetActivityStatsUseCase | userId | `Either<Failure, Map<String, dynamic>>` |

#### 3.3 Dosya Checklist

- [x] `lib/data/models/activity/activity_model.dart`
- [x] `lib/data/models/activity/inline_activity_model.dart`
- [x] `lib/data/models/activity/activity_result_model.dart`
- [x] `lib/domain/usecases/activity/get_activities_by_chapter_usecase.dart`
- [x] `lib/domain/usecases/activity/get_activity_by_id_usecase.dart`
- [x] `lib/domain/usecases/activity/get_activity_stats_usecase.dart`
- [x] `lib/domain/usecases/activity/get_best_result_usecase.dart`
- [x] `lib/domain/usecases/activity/get_user_activity_results_usecase.dart`
- [x] `lib/domain/usecases/activity/get_inline_activities_usecase.dart`
- [x] `lib/domain/usecases/activity/submit_activity_result_usecase.dart`
- [x] `lib/domain/usecases/activity/save_inline_activity_result_usecase.dart`
- [x] `lib/domain/usecases/activity/get_completed_inline_activities_usecase.dart`
- [x] `lib/data/repositories/supabase/supabase_activity_repository.dart` güncelle
- [x] `lib/data/repositories/supabase/supabase_book_repository.dart` (inline activities) güncelle
- [x] `lib/presentation/providers/usecase_providers.dart` güncelle
- [x] `lib/presentation/providers/activity_provider.dart` güncelle
- [x] `lib/presentation/providers/reader_provider.dart` güncelle
- [x] `dart analyze` çalıştır
- [ ] Test et: Aktivite tamamlama
- [ ] Commit

---

### Modül 4: Vocabulary

**Süre:** 5-6 saat
**Branch:** `refactor/vocabulary-module`

#### 4.1 Model Oluştur

| Model | Dosya |
|-------|-------|
| VocabularyWordModel | `lib/data/models/vocabulary/vocabulary_word_model.dart` |
| VocabularyProgressModel | `lib/data/models/vocabulary/vocabulary_progress_model.dart` |
| WordListModel | `lib/data/models/vocabulary/word_list_model.dart` |
| WordListProgressModel | `lib/data/models/vocabulary/word_list_progress_model.dart` |

#### 4.2 UseCase Oluştur

| UseCase | Params | Return |
|---------|--------|--------|
| GetAllWordsUseCase | level?, categories?, page | `Either<Failure, List<VocabularyWord>>` |
| SearchWordsUseCase | query | `Either<Failure, List<VocabularyWord>>` |
| GetWordsDueForReviewUseCase | userId | `Either<Failure, List<VocabularyWord>>` |
| AddWordToVocabularyUseCase | userId, wordId | `Either<Failure, VocabularyProgress>` |
| UpdateWordProgressUseCase | progress | `Either<Failure, VocabularyProgress>` |
| GetVocabularyStatsUseCase | userId | `Either<Failure, Map<String, int>>` |
| GetAllWordListsUseCase | category?, isSystem? | `Either<Failure, List<WordList>>` |
| GetWordsForListUseCase | listId | `Either<Failure, List<VocabularyWord>>` |
| CompleteWordListPhaseUseCase | userId, listId, phase, score | `Either<Failure, WordListProgress>` |

#### 4.3 Dosya Checklist

- [ ] `lib/data/models/vocabulary/vocabulary_word_model.dart`
- [ ] `lib/data/models/vocabulary/vocabulary_progress_model.dart`
- [ ] `lib/data/models/vocabulary/word_list_model.dart`
- [ ] `lib/data/models/vocabulary/word_list_progress_model.dart`
- [ ] `lib/domain/usecases/vocabulary/get_all_words_usecase.dart`
- [ ] `lib/domain/usecases/vocabulary/search_words_usecase.dart`
- [ ] `lib/domain/usecases/vocabulary/get_words_due_for_review_usecase.dart`
- [ ] `lib/domain/usecases/vocabulary/add_word_to_vocabulary_usecase.dart`
- [ ] `lib/domain/usecases/vocabulary/update_word_progress_usecase.dart`
- [ ] `lib/domain/usecases/vocabulary/get_vocabulary_stats_usecase.dart`
- [ ] `lib/domain/usecases/wordlist/get_all_word_lists_usecase.dart`
- [ ] `lib/domain/usecases/wordlist/get_words_for_list_usecase.dart`
- [ ] `lib/domain/usecases/wordlist/complete_word_list_phase_usecase.dart`
- [ ] `lib/data/repositories/supabase/supabase_vocabulary_repository.dart` güncelle
- [ ] `lib/data/repositories/supabase/supabase_word_list_repository.dart` güncelle
- [ ] `lib/presentation/providers/usecase_providers.dart` güncelle
- [ ] `lib/presentation/providers/vocabulary_provider.dart` güncelle
- [ ] `lib/presentation/screens/vocabulary/` temizle
- [ ] `dart analyze` çalıştır
- [ ] Test et: Kelime çalışma
- [ ] Commit

---

### Modül 5: Badge & User

**Süre:** 3-4 saat
**Branch:** `refactor/badge-module`

#### 5.1 Model Oluştur

| Model | Dosya |
|-------|-------|
| BadgeModel | `lib/data/models/badge/badge_model.dart` |
| UserBadgeModel | `lib/data/models/badge/user_badge_model.dart` |
| XPLogModel | `lib/data/models/user/xp_log_model.dart` |

#### 5.2 UseCase Oluştur

| UseCase | Params | Return |
|---------|--------|--------|
| GetAllBadgesUseCase | NoParams | `Either<Failure, List<Badge>>` |
| GetUserBadgesUseCase | userId | `Either<Failure, List<UserBadge>>` |
| AwardBadgeUseCase | userId, badgeId | `Either<Failure, UserBadge>` |
| CheckEarnableBadgesUseCase | userId | `Either<Failure, List<Badge>>` |
| GetUserStatsUseCase | userId | `Either<Failure, Map<String, dynamic>>` |
| AddXPUseCase | userId, amount | `Either<Failure, User>` |
| UpdateStreakUseCase | userId | `Either<Failure, User>` |

#### 5.3 Dosya Checklist

- [ ] `lib/data/models/badge/badge_model.dart`
- [ ] `lib/data/models/badge/user_badge_model.dart`
- [ ] `lib/data/models/user/xp_log_model.dart`
- [ ] `lib/domain/usecases/badge/get_all_badges_usecase.dart`
- [ ] `lib/domain/usecases/badge/get_user_badges_usecase.dart`
- [ ] `lib/domain/usecases/badge/award_badge_usecase.dart`
- [ ] `lib/domain/usecases/badge/check_earnable_badges_usecase.dart`
- [ ] `lib/domain/usecases/user/get_user_stats_usecase.dart`
- [ ] `lib/domain/usecases/user/add_xp_usecase.dart`
- [ ] `lib/domain/usecases/user/update_streak_usecase.dart`
- [ ] `lib/data/repositories/supabase/supabase_badge_repository.dart` güncelle
- [ ] `lib/data/repositories/supabase/supabase_user_repository.dart` güncelle
- [ ] `lib/presentation/providers/usecase_providers.dart` güncelle
- [ ] `lib/presentation/providers/badge_provider.dart` güncelle
- [ ] `dart analyze` çalıştır
- [ ] Test et: Rozet görüntüleme
- [ ] Commit

---

### Modül 6: Teacher

**Süre:** 5-6 saat
**Branch:** `refactor/teacher-module`

#### 6.1 Model Oluştur

| Model | Dosya |
|-------|-------|
| TeacherStatsModel | `lib/data/models/teacher/teacher_stats_model.dart` |
| TeacherClassModel | `lib/data/models/teacher/teacher_class_model.dart` |
| StudentSummaryModel | `lib/data/models/teacher/student_summary_model.dart` |
| AssignmentModel | `lib/data/models/assignment/assignment_model.dart` |
| AssignmentStudentModel | `lib/data/models/assignment/assignment_student_model.dart` |

#### 6.2 UseCase Oluştur

**Mevcut UseCase'ler (4):**
- ✅ ResetStudentPasswordUseCase
- ✅ ChangeStudentClassUseCase
- ✅ CreateAssignmentUseCase
- ✅ SaveReadingProgressUseCase (reading modülünde)

**Yeni UseCase'ler:**

| UseCase | Params | Return |
|---------|--------|--------|
| GetTeacherStatsUseCase | teacherId | `Either<Failure, TeacherStats>` |
| GetClassesUseCase | schoolId | `Either<Failure, List<TeacherClass>>` |
| GetClassStudentsUseCase | classId | `Either<Failure, List<StudentSummary>>` |
| CreateClassUseCase | schoolId, name, description | `Either<Failure, String>` |
| SendPasswordResetEmailUseCase | email | `Either<Failure, void>` |
| GetAssignmentsUseCase | teacherId | `Either<Failure, List<Assignment>>` |
| GetAssignmentDetailUseCase | assignmentId | `Either<Failure, Assignment>` |
| GetAssignmentStudentsUseCase | assignmentId | `Either<Failure, List<AssignmentStudent>>` |
| DeleteAssignmentUseCase | assignmentId | `Either<Failure, void>` |

#### 6.3 Dosya Checklist

- [ ] `lib/data/models/teacher/teacher_stats_model.dart`
- [ ] `lib/data/models/teacher/teacher_class_model.dart`
- [ ] `lib/data/models/teacher/student_summary_model.dart`
- [ ] `lib/data/models/assignment/assignment_model.dart`
- [ ] `lib/data/models/assignment/assignment_student_model.dart`
- [ ] `lib/domain/usecases/teacher/get_teacher_stats_usecase.dart`
- [ ] `lib/domain/usecases/teacher/get_classes_usecase.dart`
- [ ] `lib/domain/usecases/teacher/get_class_students_usecase.dart`
- [ ] `lib/domain/usecases/teacher/create_class_usecase.dart`
- [ ] `lib/domain/usecases/teacher/send_password_reset_email_usecase.dart`
- [ ] `lib/domain/usecases/assignment/get_assignments_usecase.dart`
- [ ] `lib/domain/usecases/assignment/get_assignment_detail_usecase.dart`
- [ ] `lib/domain/usecases/assignment/get_assignment_students_usecase.dart`
- [ ] `lib/domain/usecases/assignment/delete_assignment_usecase.dart`
- [ ] `lib/data/repositories/supabase/supabase_teacher_repository.dart` güncelle
- [ ] `lib/presentation/providers/usecase_providers.dart` güncelle
- [ ] `lib/presentation/providers/teacher_provider.dart` güncelle
- [ ] `lib/presentation/screens/teacher/teacher_dashboard_screen.dart` temizle
- [ ] `lib/presentation/screens/teacher/classes_screen.dart` temizle
- [ ] `lib/presentation/screens/teacher/class_detail_screen.dart` temizle
- [ ] `lib/presentation/screens/teacher/student_detail_screen.dart` temizle
- [ ] `lib/presentation/screens/teacher/assignments_screen.dart` temizle
- [ ] `lib/presentation/screens/teacher/assignment_detail_screen.dart` temizle
- [ ] `lib/presentation/screens/teacher/create_assignment_screen.dart` temizle
- [ ] `lib/presentation/screens/teacher/reports/` temizle
- [ ] `dart analyze` çalıştır
- [ ] Test et: Öğretmen dashboard
- [ ] Commit

---

### Modül 7: Student Assignment

**Süre:** 3-4 saat
**Branch:** `refactor/student-assignment-module`

#### 7.1 Model Oluştur

| Model | Dosya |
|-------|-------|
| StudentAssignmentModel | `lib/data/models/assignment/student_assignment_model.dart` |

#### 7.2 UseCase Oluştur

| UseCase | Params | Return |
|---------|--------|--------|
| GetStudentAssignmentsUseCase | studentId | `Either<Failure, List<StudentAssignment>>` |
| GetActiveAssignmentsUseCase | studentId | `Either<Failure, List<StudentAssignment>>` |
| GetStudentAssignmentDetailUseCase | studentId, assignmentId | `Either<Failure, StudentAssignment>` |
| StartAssignmentUseCase | studentId, assignmentId | `Either<Failure, void>` |
| UpdateAssignmentProgressUseCase | studentId, assignmentId, progress | `Either<Failure, void>` |
| CompleteAssignmentUseCase | studentId, assignmentId, score | `Either<Failure, void>` |

#### 7.3 Dosya Checklist

- [ ] `lib/data/models/assignment/student_assignment_model.dart`
- [ ] `lib/domain/usecases/student_assignment/get_student_assignments_usecase.dart`
- [ ] `lib/domain/usecases/student_assignment/get_active_assignments_usecase.dart`
- [ ] `lib/domain/usecases/student_assignment/get_student_assignment_detail_usecase.dart`
- [ ] `lib/domain/usecases/student_assignment/start_assignment_usecase.dart`
- [ ] `lib/domain/usecases/student_assignment/update_assignment_progress_usecase.dart`
- [ ] `lib/domain/usecases/student_assignment/complete_assignment_usecase.dart`
- [ ] `lib/data/repositories/supabase/supabase_student_assignment_repository.dart` güncelle
- [ ] `lib/presentation/providers/usecase_providers.dart` güncelle
- [ ] `lib/presentation/providers/student_assignment_provider.dart` güncelle
- [ ] `lib/presentation/screens/student/student_assignments_screen.dart` temizle
- [ ] `lib/presentation/screens/student/student_assignment_detail_screen.dart` temizle
- [ ] `dart analyze` çalıştır
- [ ] Test et: Öğrenci ödev görüntüleme
- [ ] Commit

---

### Modül 8: Final Temizlik

**Süre:** 2-3 saat
**Branch:** `refactor/final-cleanup`

#### 8.1 Checklist

- [ ] Tüm screen'lerde repository import kontrolü
- [ ] Entity'lerden `fromJson`/`toJson` kaldır (Model'e taşındı)
- [ ] Kullanılmayan import'ları temizle
- [ ] `dart analyze` - 0 error, 0 warning
- [ ] `flutter test` - tüm testler geçmeli
- [ ] Manuel test: Tam akış (login → okuma → aktivite → logout)
- [ ] Final commit
- [ ] `feature/clean-architecture-refactor` → `main` merge

```bash
# Final kontroller
dart analyze lib/
grep -r "import.*domain/repositories" lib/presentation/screens/ | wc -l  # 0 olmalı
flutter test
```

---

## Master Checklist

### Başlangıç Kontrolleri

- [x] Git branch oluşturuldu: `feature/clean-architecture-refactor`
- [x] Baseline commit yapıldı
- [x] `lib/data/models/` klasörleri oluşturuldu
- [x] Plan dosyası okundu ve anlaşıldı

### Modül İlerleme Durumu

| Modül | Model | UseCase | Provider | Screen | Test | Commit |
|-------|-------|---------|----------|--------|------|--------|
| 0. Hazırlık | - | - | - | - | - | ✅ |
| 1. Auth | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2. Book & Reading | ✅ | ✅ | ✅ | ✅ | ⬜ | ✅ |
| 3. Activity | ✅ | ✅ | ✅ | ✅ | ⬜ | ⬜ |
| 4. Vocabulary | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 5. Badge & User | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 6. Teacher | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 7. Student Assignment | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| 8. Final Temizlik | - | - | - | - | ⬜ | ⬜ |

### Bitiş Kontrolleri

- [ ] `dart analyze lib/` → 0 error
- [ ] `grep -r "import.*domain/repositories" lib/presentation/screens/` → 0 sonuç
- [ ] `flutter test` → Tüm testler geçti
- [ ] Manuel test tamamlandı
- [ ] `main` branch'e merge edildi

---

## Doğrulama Komutları

### Her Modül Sonrası

```bash
# 1. Syntax ve lint kontrolü
dart analyze lib/domain/usecases/
dart analyze lib/data/models/
dart analyze lib/data/repositories/
dart analyze lib/presentation/providers/
dart analyze lib/presentation/screens/

# 2. Screen'lerde repository import kontrolü (0 olmalı)
grep -r "import.*domain/repositories" lib/presentation/screens/ | wc -l

# 3. Provider'larda direkt repository kullanımı kontrolü
grep -r "ref.read(.*RepositoryProvider)" lib/presentation/screens/ | wc -l
grep -r "ref.watch(.*RepositoryProvider)" lib/presentation/screens/ | wc -l

# 4. Uygulama başlatma testi
flutter run -d chrome
```

### Final Kontrol

```bash
# Tam analiz
dart analyze lib/

# Repository import ihlali (0 olmalı)
grep -r "import.*domain/repositories" lib/presentation/screens/

# Test suite
flutter test

# Build kontrolü
flutter build web --release
```

---

## Sorun Giderme

### Yaygın Hatalar ve Çözümleri

#### 1. "UseCase not found" hatası

```dart
// Problem: Provider'da UseCase import edilmemiş
// Çözüm: usecase_providers.dart'a ekle

final xxxUseCaseProvider = Provider((ref) {
  return XxxUseCase(ref.watch(xxxRepositoryProvider));
});
```

#### 2. "Entity.fromJson not found" hatası

```dart
// Problem: Entity'den fromJson kaldırıldı ama repository hala kullanıyor
// Çözüm: Model kullan

// Yanlış:
return Entity.fromJson(json);

// Doğru:
return EntityModel.fromJson(json).toEntity();
```

#### 3. "Circular dependency" hatası

```dart
// Problem: UseCase başka bir UseCase'i import ediyor
// Çözüm: UseCase'ler birbirini çağırmamalı, Repository üzerinden gitsin
```

#### 4. Screen'de repository import kaldırılamıyor

```dart
// Problem: Screen'de hala AssignmentType gibi tipler kullanılıyor
// Çözüm: Bu tipler domain/entities veya domain/repositories'de tanımlı
//        Screen sadece provider üzerinden erişmeli

// Yanlış:
import '../../../domain/repositories/teacher_repository.dart'; // AssignmentType için

// Doğru:
// AssignmentType'ı ayrı bir dosyaya taşı: domain/entities/assignment_type.dart
import '../../../domain/entities/assignment_type.dart';
```

### Geri Alma (Rollback)

Bir modülde sorun çıkarsa:

```bash
# Modül branch'ini sil ve yeniden başla
git checkout feature/clean-architecture-refactor
git branch -D refactor/problem-module
git checkout -b refactor/problem-module

# Veya tüm refactor'ı geri al
git checkout main
git branch -D feature/clean-architecture-refactor
```

---

## Notlar

### Karar Geçmişi

| Tarih | Karar | Gerekçe |
|-------|-------|---------|
| 2026-02-01 | Model/Entity ayrımı yapılacak | Gelecekte aktivite tipleri eklenecek |
| 2026-02-01 | Tüm entity'ler için Model (Badge, XPLog dahil) | Tutarlılık |
| 2026-02-01 | Modül bazlı ilerleme | Risk azaltma |
| 2026-02-01 | Her modül ayrı branch | Kolay rollback |

### Referanslar

- Clean Architecture: https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html
- Flutter Clean Architecture: https://resocoder.com/flutter-clean-architecture-tdd/
- Riverpod Docs: https://riverpod.dev/

---

**Son Güncelleme:** 2026-02-01
**Versiyon:** 1.1
**İlerleme:** Modül 1 (Auth) tamamlandı
