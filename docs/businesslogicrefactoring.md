# Clean Architecture Tam Refactor Planı

> ⚠️ **Bu dosya eski versiyondur.**
>
> **Güncel ve detaylı plan için:** `docs/CLEAN_ARCHITECTURE_REFACTOR_PLAN.md`
> **Hızlı checklist için:** `docs/REFACTOR_CHECKLIST.md`

**Oluşturulma:** 2026-02-01
**Durum:** Devam Ediyor

---

## Özet
68 repository metodu için use case katmanı oluşturulacak, tüm provider ve screen'ler güncellenerek Clean Architecture'a geçilecek.

---

## Strateji: Modül Bazlı Aşamalı Geçiş

Her modül için sırayla:
1. Use case'leri oluştur
2. Provider'ları güncelle (use case kullan)
3. Screen'lerden repository import'larını kaldır
4. `dart analyze` ile doğrula
5. Bir sonraki modüle geç

**Avantaj:** Her adım bağımsız test edilebilir, hata riski minimize.

---

## Modül Sıralaması (Bağımlılık Sırasına Göre)

| Sıra | Modül | Use Case Sayısı | Durum |
|------|-------|-----------------|-------|
| 1 | Auth | 4 | ⏳ Bekliyor |
| 2 | Book & Reading | 12 | ⏳ Bekliyor |
| 3 | Activity | 8 | ⏳ Bekliyor |
| 4 | Vocabulary | 15 | ⏳ Bekliyor |
| 5 | Badge | 5 | ⏳ Bekliyor |
| 6 | Teacher | 10 | ⏳ Bekliyor (4 mevcut) |
| 7 | Student Assignment | 6 | ⏳ Bekliyor |

**Toplam:** ~48 use case (4 mevcut)

---

## Modül 1: Auth

### Use Case'ler

| Use Case | Durum |
|----------|-------|
| `sign_in_with_email_usecase.dart` | ⏳ |
| `sign_in_with_student_number_usecase.dart` | ⏳ |
| `sign_out_usecase.dart` | ⏳ |
| `get_current_user_usecase.dart` | ⏳ |

### Detay

**1. SignInWithEmailUseCase**
```dart
class SignInWithEmailParams {
  final String email;
  final String password;
}
// Return: Either<Failure, User>
```

**2. SignInWithStudentNumberUseCase**
```dart
class SignInWithStudentNumberParams {
  final String studentNumber;
  final String password;
}
// Return: Either<Failure, User>
```

**3. SignOutUseCase**
```dart
// NoParams
// Return: Either<Failure, void>
```

**4. GetCurrentUserUseCase**
```dart
// NoParams
// Return: Either<Failure, User?>
```

### Provider Güncellemesi
- `auth_provider.dart` → Use case provider'ları ekle

### Screen Güncellemesi
- `login_screen.dart` → Repository import kaldır
- `splash_screen.dart` → Repository import kaldır

---

## Modül 2: Book & Reading

### Use Case'ler

| Use Case | Durum |
|----------|-------|
| `get_books_usecase.dart` | ⏳ |
| `get_book_by_id_usecase.dart` | ⏳ |
| `search_books_usecase.dart` | ⏳ |
| `get_recommended_books_usecase.dart` | ⏳ |
| `get_chapters_usecase.dart` | ⏳ |
| `get_chapter_by_id_usecase.dart` | ⏳ |
| `get_continue_reading_usecase.dart` | ⏳ |
| `get_reading_progress_usecase.dart` | ⏳ |
| `save_reading_progress_usecase.dart` | ✅ Mevcut |
| `mark_chapter_complete_usecase.dart` | ⏳ |
| `update_current_chapter_usecase.dart` | ⏳ |
| `get_user_reading_history_usecase.dart` | ⏳ |

### Provider Güncellemesi
- `book_provider.dart` → Tüm provider'ları use case ile değiştir

### Screen Güncellemesi
- `library_screen.dart`
- `book_detail_screen.dart`
- `reader_screen.dart` (kısmen mevcut)
- `home_screen.dart`

---

## Modül 3: Activity

### Use Case'ler

| Use Case | Durum |
|----------|-------|
| `get_activities_by_chapter_usecase.dart` | ⏳ |
| `get_activity_by_id_usecase.dart` | ⏳ |
| `submit_activity_result_usecase.dart` | ⏳ |
| `get_user_activity_results_usecase.dart` | ⏳ |
| `get_activity_stats_usecase.dart` | ⏳ |
| `get_inline_activities_usecase.dart` | ⏳ |
| `save_inline_activity_result_usecase.dart` | ⏳ |
| `get_completed_inline_activities_usecase.dart` | ⏳ |

### Provider Güncellemesi
- `activity_provider.dart`
- `reader_provider.dart` (inline activity kısımları)

---

## Modül 4: Vocabulary

### Use Case'ler

| Use Case | Durum |
|----------|-------|
| `get_all_words_usecase.dart` | ⏳ |
| `get_word_by_id_usecase.dart` | ⏳ |
| `search_words_usecase.dart` | ⏳ |
| `get_user_vocabulary_progress_usecase.dart` | ⏳ |
| `update_word_progress_usecase.dart` | ⏳ |
| `get_words_due_for_review_usecase.dart` | ⏳ |
| `get_new_words_usecase.dart` | ⏳ |
| `get_vocabulary_stats_usecase.dart` | ⏳ |
| `add_word_to_vocabulary_usecase.dart` | ⏳ |
| `get_all_word_lists_usecase.dart` | ⏳ |
| `get_word_list_by_id_usecase.dart` | ⏳ |
| `get_words_for_list_usecase.dart` | ⏳ |
| `get_user_word_list_progress_usecase.dart` | ⏳ |
| `update_word_list_progress_usecase.dart` | ⏳ |
| `complete_word_list_phase_usecase.dart` | ⏳ |

### Provider Güncellemesi
- `vocabulary_provider.dart`

### Screen Güncellemesi
- `vocabulary_screen.dart`
- `word_list_screen.dart`
- `word_practice_screen.dart`

---

## Modül 5: Badge

### Use Case'ler

| Use Case | Durum |
|----------|-------|
| `get_all_badges_usecase.dart` | ⏳ |
| `get_user_badges_usecase.dart` | ⏳ |
| `award_badge_usecase.dart` | ⏳ |
| `check_earnable_badges_usecase.dart` | ⏳ |
| `get_recently_earned_badges_usecase.dart` | ⏳ |

### Provider Güncellemesi
- `badge_provider.dart`

---

## Modül 6: Teacher

### Use Case'ler

| Use Case | Durum |
|----------|-------|
| `reset_student_password_usecase.dart` | ✅ Mevcut |
| `change_student_class_usecase.dart` | ✅ Mevcut |
| `get_teacher_stats_usecase.dart` | ⏳ |
| `get_classes_usecase.dart` | ⏳ |
| `get_class_students_usecase.dart` | ⏳ |
| `get_student_detail_usecase.dart` | ⏳ |
| `get_student_progress_usecase.dart` | ⏳ |
| `create_class_usecase.dart` | ⏳ |
| `send_password_reset_email_usecase.dart` | ⏳ |
| `create_assignment_usecase.dart` | ✅ Mevcut |
| `get_assignments_usecase.dart` | ⏳ |
| `get_assignment_detail_usecase.dart` | ⏳ |
| `get_assignment_students_usecase.dart` | ⏳ |
| `delete_assignment_usecase.dart` | ⏳ |

### Provider Güncellemesi
- `teacher_provider.dart`

### Screen Güncellemesi
- `teacher_dashboard_screen.dart`
- `classes_screen.dart`
- `class_detail_screen.dart` (kısmen mevcut)
- `student_detail_screen.dart`
- `assignments_screen.dart`
- `assignment_detail_screen.dart`
- `create_assignment_screen.dart` (kısmen mevcut)
- Report screen'leri

---

## Modül 7: Student Assignment

### Use Case'ler

| Use Case | Durum |
|----------|-------|
| `get_student_assignments_usecase.dart` | ⏳ |
| `get_active_assignments_usecase.dart` | ⏳ |
| `get_assignment_detail_usecase.dart` | ⏳ |
| `start_assignment_usecase.dart` | ⏳ |
| `update_assignment_progress_usecase.dart` | ⏳ |
| `complete_assignment_usecase.dart` | ⏳ |

### Provider Güncellemesi
- `student_assignment_provider.dart`

### Screen Güncellemesi
- `student_assignments_screen.dart`
- `student_assignment_detail_screen.dart`

---

## Dosya Yapısı (Son Hali)

```
lib/domain/usecases/
├── usecase.dart                    # Base class (mevcut)
├── auth/
│   ├── sign_in_with_email_usecase.dart
│   ├── sign_in_with_student_number_usecase.dart
│   ├── sign_out_usecase.dart
│   └── get_current_user_usecase.dart
├── book/
│   ├── get_books_usecase.dart
│   ├── get_book_by_id_usecase.dart
│   ├── search_books_usecase.dart
│   ├── get_recommended_books_usecase.dart
│   ├── get_chapters_usecase.dart
│   ├── get_chapter_by_id_usecase.dart
│   └── get_continue_reading_usecase.dart
├── reading/
│   ├── get_reading_progress_usecase.dart
│   ├── save_reading_progress_usecase.dart  # Mevcut
│   ├── mark_chapter_complete_usecase.dart
│   ├── update_current_chapter_usecase.dart
│   └── get_user_reading_history_usecase.dart
├── activity/
│   ├── get_activities_by_chapter_usecase.dart
│   ├── get_inline_activities_usecase.dart
│   ├── submit_activity_result_usecase.dart
│   ├── save_inline_activity_result_usecase.dart
│   ├── get_completed_inline_activities_usecase.dart
│   └── get_activity_stats_usecase.dart
├── vocabulary/
│   ├── get_all_words_usecase.dart
│   ├── search_words_usecase.dart
│   ├── get_words_due_for_review_usecase.dart
│   ├── add_word_to_vocabulary_usecase.dart
│   └── get_vocabulary_stats_usecase.dart
├── wordlist/
│   ├── get_all_word_lists_usecase.dart
│   ├── get_words_for_list_usecase.dart
│   └── complete_word_list_phase_usecase.dart
├── badge/
│   ├── get_all_badges_usecase.dart
│   ├── get_user_badges_usecase.dart
│   ├── award_badge_usecase.dart
│   └── check_earnable_badges_usecase.dart
├── user/
│   ├── get_user_by_id_usecase.dart
│   ├── update_user_usecase.dart
│   ├── add_xp_usecase.dart
│   ├── update_streak_usecase.dart
│   └── get_user_stats_usecase.dart
├── teacher/
│   ├── reset_student_password_usecase.dart  # Mevcut
│   ├── change_student_class_usecase.dart    # Mevcut
│   ├── get_teacher_stats_usecase.dart
│   ├── get_classes_usecase.dart
│   ├── get_class_students_usecase.dart
│   ├── create_class_usecase.dart
│   └── send_password_reset_email_usecase.dart
├── assignment/
│   ├── create_assignment_usecase.dart       # Mevcut
│   ├── get_assignments_usecase.dart
│   ├── get_assignment_detail_usecase.dart
│   └── delete_assignment_usecase.dart
└── student_assignment/
    ├── get_active_assignments_usecase.dart
    ├── start_assignment_usecase.dart
    └── complete_assignment_usecase.dart
```

---

## Doğrulama Adımları

Her modül sonrası:
```bash
# 1. Syntax check
dart analyze lib/domain/usecases/
dart analyze lib/presentation/providers/
dart analyze lib/presentation/screens/

# 2. Repository import kontrolü (0 olmalı)
grep -r "import.*domain/repositories" lib/presentation/screens/ | wc -l

# 3. Uygulama testi
flutter run -d chrome
```

---

## Risk Azaltma

1. **Her modül sonrası commit** - Geri dönüş noktası
2. **Mevcut testler çalışmalı** - Regresyon kontrolü
3. **Screen'ler son güncellenir** - Provider'lar önce hazır olmalı
4. **Mevcut use case'ler korunur** - 4 mevcut use case değişmez

---

## İlerleme Günlüğü

| Tarih | Modül | Notlar |
|-------|-------|--------|
| 2026-02-01 | Plan | Plan oluşturuldu |
| | | |
