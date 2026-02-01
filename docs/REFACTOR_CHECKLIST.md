# Clean Architecture Refactor - Hızlı Checklist

**Detaylı Plan:** `docs/CLEAN_ARCHITECTURE_REFACTOR_PLAN.md`

---

## Başlangıç

```bash
git checkout -b feature/clean-architecture-refactor
git add . && git commit -m "chore: baseline before refactor"
mkdir -p lib/data/models/{auth,book,activity,vocabulary,badge,teacher,assignment,user}
```

- [x] Branch oluşturuldu
- [x] Baseline commit yapıldı
- [x] Model klasörleri oluşturuldu

---

## Modül 1: Auth

**Branch:** `git checkout -b refactor/auth-module`

### Dosyalar
- [x] `lib/data/models/auth/user_model.dart`
- [x] `lib/domain/usecases/auth/sign_in_with_email_usecase.dart`
- [x] `lib/domain/usecases/auth/sign_in_with_student_number_usecase.dart`
- [x] `lib/domain/usecases/auth/sign_out_usecase.dart`
- [x] `lib/domain/usecases/auth/get_current_user_usecase.dart`
- [x] `lib/domain/usecases/auth/refresh_current_user_usecase.dart`

### Güncellemeler
- [x] `supabase_auth_repository.dart` → Model kullan
- [x] `usecase_providers.dart` → Auth UseCase'leri ekle
- [x] `auth_provider.dart` → UseCase kullan
- [x] `login_screen.dart` → Repository import kaldır (zaten yoktu)

### Doğrulama
- [x] `dart analyze lib/domain/usecases/auth/`
- [x] Login test et
- [x] Commit & Merge

---

## Modül 2: Book & Reading

**Branch:** `git checkout -b refactor/book-module`

### Dosyalar
- [x] `lib/data/models/book/book_model.dart`
- [x] `lib/data/models/book/chapter_model.dart`
- [x] `lib/data/models/book/reading_progress_model.dart`
- [x] `lib/domain/usecases/book/get_books_usecase.dart`
- [x] `lib/domain/usecases/book/get_book_by_id_usecase.dart`
- [x] `lib/domain/usecases/book/search_books_usecase.dart`
- [x] `lib/domain/usecases/book/get_chapters_usecase.dart`
- [x] `lib/domain/usecases/book/get_chapter_by_id_usecase.dart`
- [x] `lib/domain/usecases/book/get_continue_reading_usecase.dart`
- [x] `lib/domain/usecases/book/get_recommended_books_usecase.dart`
- [x] `lib/domain/usecases/reading/get_reading_progress_usecase.dart`
- [x] `lib/domain/usecases/reading/save_reading_progress_usecase.dart`
- [x] `lib/domain/usecases/reading/mark_chapter_complete_usecase.dart`
- [x] `lib/domain/usecases/reading/update_current_chapter_usecase.dart`
- [x] `lib/domain/usecases/reading/update_reading_progress_usecase.dart`
- [x] `lib/domain/usecases/reading/get_user_reading_history_usecase.dart`

### Güncellemeler
- [x] `supabase_book_repository.dart` → Model kullan
- [x] `usecase_providers.dart` → Book UseCase'leri ekle
- [x] `book_provider.dart` → UseCase kullan
- [x] `library_screen.dart` → Temizle (zaten temizdi)
- [x] `book_detail_screen.dart` → Temizle (zaten temizdi)
- [x] `reader_screen.dart` → Temizle
- [x] `home_screen.dart` → Temizle (zaten temizdi)

### Doğrulama
- [x] `dart analyze`
- [ ] Kütüphane + Okuma test et
- [x] Commit & Merge

---

## Modül 3: Activity

**Branch:** `git checkout -b refactor/activity-module`

### Dosyalar
- [x] `lib/data/models/activity/activity_model.dart`
- [x] `lib/data/models/activity/inline_activity_model.dart`
- [x] `lib/data/models/activity/activity_result_model.dart`
- [x] `lib/domain/usecases/activity/get_activities_by_chapter_usecase.dart`
- [x] `lib/domain/usecases/activity/get_activity_by_id_usecase.dart`
- [x] `lib/domain/usecases/activity/get_activity_stats_usecase.dart`
- [x] `lib/domain/usecases/activity/get_best_result_usecase.dart`
- [x] `lib/domain/usecases/activity/get_user_activity_results_usecase.dart`
- [x] `lib/domain/usecases/activity/get_inline_activities_usecase.dart`
- [x] `lib/domain/usecases/activity/save_inline_activity_result_usecase.dart`
- [x] `lib/domain/usecases/activity/get_completed_inline_activities_usecase.dart`
- [x] `lib/domain/usecases/activity/submit_activity_result_usecase.dart`

### Güncellemeler
- [x] `supabase_activity_repository.dart` → Model kullan
- [x] `supabase_book_repository.dart` → InlineActivityModel kullan
- [x] `usecase_providers.dart` → Activity UseCase'leri ekle
- [x] `activity_provider.dart` → UseCase kullan
- [x] `reader_provider.dart` → UseCase kullan

### Doğrulama
- [x] `dart analyze` → 0 error
- [ ] Aktivite tamamlama test et
- [ ] Commit & Merge

---

## Modül 4: Vocabulary

**Branch:** `git checkout -b refactor/vocabulary-module`

### Model Dosyaları
- [x] `lib/data/models/vocabulary/vocabulary_word_model.dart`
- [x] `lib/data/models/vocabulary/vocabulary_progress_model.dart`
- [x] `lib/data/models/vocabulary/word_list_model.dart`
- [x] `lib/data/models/vocabulary/word_list_progress_model.dart`

### Vocabulary UseCases
- [x] `lib/domain/usecases/vocabulary/get_all_words_usecase.dart`
- [x] `lib/domain/usecases/vocabulary/get_word_by_id_usecase.dart`
- [x] `lib/domain/usecases/vocabulary/search_words_usecase.dart`
- [x] `lib/domain/usecases/vocabulary/get_user_vocabulary_progress_usecase.dart`
- [x] `lib/domain/usecases/vocabulary/get_word_progress_usecase.dart`
- [x] `lib/domain/usecases/vocabulary/update_word_progress_usecase.dart`
- [x] `lib/domain/usecases/vocabulary/get_due_for_review_usecase.dart`
- [x] `lib/domain/usecases/vocabulary/get_new_words_usecase.dart`
- [x] `lib/domain/usecases/vocabulary/get_vocabulary_stats_usecase.dart`
- [x] `lib/domain/usecases/vocabulary/add_word_to_vocabulary_usecase.dart`

### WordList UseCases
- [x] `lib/domain/usecases/wordlist/get_all_word_lists_usecase.dart`
- [x] `lib/domain/usecases/wordlist/get_word_list_by_id_usecase.dart`
- [x] `lib/domain/usecases/wordlist/get_words_for_list_usecase.dart`
- [x] `lib/domain/usecases/wordlist/get_user_word_list_progress_usecase.dart`
- [x] `lib/domain/usecases/wordlist/get_progress_for_list_usecase.dart`
- [x] `lib/domain/usecases/wordlist/update_word_list_progress_usecase.dart`
- [x] `lib/domain/usecases/wordlist/complete_phase_usecase.dart`
- [x] `lib/domain/usecases/wordlist/reset_progress_usecase.dart`

### Güncellemeler
- [x] `supabase_vocabulary_repository.dart` → Model kullan
- [x] `supabase_word_list_repository.dart` → Model kullan
- [x] `usecase_providers.dart` → Vocabulary & WordList UseCase'leri ekle
- [x] `vocabulary_provider.dart` → UseCase kullan
- [x] Vocabulary screen'leri temizle (zaten repository import yoktu)
- [x] `reader_screen.dart` → Vocabulary UseCase kullan (searchWords, addWordToVocabulary)
- [x] `integrated_reader_content.dart` → Vocabulary UseCase kullan (addWordToVocabulary)
- [x] `reading_progress_report_screen.dart` → Book UseCase kullan (getBooks)

### Doğrulama
- [x] `dart analyze` → 0 error
- [ ] Kelime çalışma test et
- [ ] Commit & Merge

---

## Modül 5: Badge & User

**Branch:** `git checkout -b refactor/badge-module`

### Badge Model Dosyaları
- [x] `lib/data/models/badge/badge_model.dart`
- [x] `lib/data/models/badge/user_badge_model.dart`

### User Model Dosyaları
- [x] `lib/data/models/user/user_model.dart`

### Badge UseCases
- [x] `lib/domain/usecases/badge/get_all_badges_usecase.dart`
- [x] `lib/domain/usecases/badge/get_badge_by_id_usecase.dart`
- [x] `lib/domain/usecases/badge/get_user_badges_usecase.dart`
- [x] `lib/domain/usecases/badge/award_badge_usecase.dart`
- [x] `lib/domain/usecases/badge/check_earnable_badges_usecase.dart`
- [x] `lib/domain/usecases/badge/get_recently_earned_usecase.dart`

### User UseCases
- [x] `lib/domain/usecases/user/get_user_by_id_usecase.dart`
- [x] `lib/domain/usecases/user/update_user_usecase.dart`
- [x] `lib/domain/usecases/user/add_xp_usecase.dart`
- [x] `lib/domain/usecases/user/update_streak_usecase.dart`
- [x] `lib/domain/usecases/user/get_user_stats_usecase.dart`
- [x] `lib/domain/usecases/user/get_classmates_usecase.dart`
- [x] `lib/domain/usecases/user/get_leaderboard_usecase.dart`

### Güncellemeler
- [x] `supabase_badge_repository.dart` → Model kullan
- [x] `supabase_user_repository.dart` → Model kullan
- [x] `usecase_providers.dart` → Badge & User UseCase'leri ekle
- [x] `badge_provider.dart` → UseCase kullan
- [x] `user_provider.dart` → UseCase kullan
- [x] `reader_provider.dart` → User UseCase kullan (updateUser)

### Doğrulama
- [x] `dart analyze` → 0 error
- [ ] Rozet görüntüleme test et
- [ ] Commit & Merge

---

## Modül 6: Teacher

**Branch:** `git checkout -b refactor/teacher-module`

### Model Dosyaları
- [x] `lib/data/models/teacher/teacher_stats_model.dart`
- [x] `lib/data/models/teacher/teacher_class_model.dart`
- [x] `lib/data/models/teacher/student_summary_model.dart`
- [x] `lib/data/models/teacher/student_book_progress_model.dart`
- [x] `lib/data/models/assignment/assignment_model.dart`
- [x] `lib/data/models/assignment/assignment_student_model.dart`

### Teacher UseCases
- [x] `lib/domain/usecases/teacher/get_teacher_stats_usecase.dart`
- [x] `lib/domain/usecases/teacher/get_classes_usecase.dart`
- [x] `lib/domain/usecases/teacher/get_class_students_usecase.dart`
- [x] `lib/domain/usecases/teacher/get_student_detail_usecase.dart`
- [x] `lib/domain/usecases/teacher/get_student_progress_usecase.dart`
- [x] `lib/domain/usecases/teacher/create_class_usecase.dart`
- [x] `lib/domain/usecases/teacher/send_password_reset_email_usecase.dart`
- [x] `lib/domain/usecases/teacher/reset_student_password_usecase.dart` (önceden vardı)
- [x] `lib/domain/usecases/teacher/change_student_class_usecase.dart` (önceden vardı)

### Assignment UseCases
- [x] `lib/domain/usecases/assignment/get_assignments_usecase.dart`
- [x] `lib/domain/usecases/assignment/get_assignment_detail_usecase.dart`
- [x] `lib/domain/usecases/assignment/get_assignment_students_usecase.dart`
- [x] `lib/domain/usecases/assignment/create_assignment_usecase.dart` (önceden vardı)
- [x] `lib/domain/usecases/assignment/delete_assignment_usecase.dart`

### Güncellemeler
- [x] `supabase_teacher_repository.dart` → Model kullan
- [x] `usecase_providers.dart` → Teacher & Assignment UseCase'leri ekle
- [x] `teacher_provider.dart` → UseCase kullan
- [x] `classes_screen.dart` → UseCase kullan (createClass)
- [x] `class_detail_screen.dart` → UseCase kullan (sendPasswordResetEmail)
- [x] `assignment_detail_screen.dart` → UseCase kullan (deleteAssignment)

### Doğrulama
- [x] `dart analyze` → 0 error
- [ ] Öğretmen dashboard test et
- [ ] Commit & Merge

---

## Modül 7: Student Assignment

**Branch:** `git checkout -b refactor/student-assignment-module`

### Model Dosyaları
- [x] `lib/data/models/assignment/student_assignment_model.dart`

### UseCases
- [x] `lib/domain/usecases/student_assignment/get_student_assignments_usecase.dart`
- [x] `lib/domain/usecases/student_assignment/get_active_assignments_usecase.dart`
- [x] `lib/domain/usecases/student_assignment/get_student_assignment_detail_usecase.dart`
- [x] `lib/domain/usecases/student_assignment/start_assignment_usecase.dart`
- [x] `lib/domain/usecases/student_assignment/update_assignment_progress_usecase.dart`
- [x] `lib/domain/usecases/student_assignment/complete_assignment_usecase.dart`

### Güncellemeler
- [x] `supabase_student_assignment_repository.dart` → Model kullan
- [x] `repository_providers.dart` → studentAssignmentRepositoryProvider ekle
- [x] `usecase_providers.dart` → Student Assignment UseCase'leri ekle
- [x] `student_assignment_provider.dart` → UseCase kullan
- [x] `student_assignment_detail_screen.dart` → UseCase kullan (startAssignment)

### Doğrulama
- [x] `dart analyze` → 0 error
- [ ] Öğrenci ödev test et
- [ ] Commit & Merge

---

## Final

**Branch:** `git checkout -b refactor/final-cleanup`

### Kontroller
- [x] `dart analyze lib/` → 0 error (722 info - stil önerileri)
- [x] `grep -r "import.*domain/repositories" lib/presentation/screens/` → ⚠️ 12 sonuç (entity type import'ları - kabul edilebilir, bkz: Gelecek Refactor)
- [x] `flutter test` → Geçti (1 test)
- [ ] Manuel tam akış testi

### ⚠️ Gelecek Refactor (SCOPE DIŞI)
Entity type'lar (`StudentAssignment`, `TeacherClass`, vb.) şu anda repository interface dosyalarında tanımlı.
İdeal olarak `lib/domain/entities/` altında ayrı dosyalarda olmalı. Bu, screen'lerin repository dosyalarını
import etmesini engelleyecek. Şu anki import'lar sadece TYPE tanımları için, repository KULLANIMI yok.

### Merge
```bash
git checkout feature/clean-architecture-refactor
git merge refactor/final-cleanup
git checkout main
git merge feature/clean-architecture-refactor
git push origin main
```

- [ ] Main'e merge edildi
- [ ] 🎉 TAMAMLANDI!

---

## Hızlı Komutlar

```bash
# Analiz
dart analyze lib/

# Screen'lerde repository import (0 olmalı)
grep -r "import.*domain/repositories" lib/presentation/screens/ | wc -l

# Test
flutter test

# Çalıştır
flutter run -d chrome
```
