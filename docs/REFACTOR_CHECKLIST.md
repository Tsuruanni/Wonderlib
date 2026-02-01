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
- [x] `lib/domain/usecases/reading/get_reading_progress_usecase.dart`
- [x] `lib/domain/usecases/reading/mark_chapter_complete_usecase.dart`
- [x] `lib/domain/usecases/reading/update_current_chapter_usecase.dart`
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
- [ ] `lib/data/models/activity/activity_model.dart`
- [ ] `lib/data/models/activity/inline_activity_model.dart`
- [ ] `lib/data/models/activity/activity_result_model.dart`
- [ ] `lib/domain/usecases/activity/get_inline_activities_usecase.dart`
- [ ] `lib/domain/usecases/activity/save_inline_activity_result_usecase.dart`
- [ ] `lib/domain/usecases/activity/get_completed_inline_activities_usecase.dart`
- [ ] `lib/domain/usecases/activity/submit_activity_result_usecase.dart`

### Güncellemeler
- [ ] `supabase_activity_repository.dart` → Model kullan
- [ ] `activity_provider.dart` → UseCase kullan
- [ ] `reader_provider.dart` → UseCase kullan

### Doğrulama
- [ ] `dart analyze`
- [ ] Aktivite tamamlama test et
- [ ] Commit & Merge

---

## Modül 4: Vocabulary

**Branch:** `git checkout -b refactor/vocabulary-module`

### Dosyalar
- [ ] `lib/data/models/vocabulary/vocabulary_word_model.dart`
- [ ] `lib/data/models/vocabulary/vocabulary_progress_model.dart`
- [ ] `lib/data/models/vocabulary/word_list_model.dart`
- [ ] `lib/domain/usecases/vocabulary/search_words_usecase.dart`
- [ ] `lib/domain/usecases/vocabulary/add_word_to_vocabulary_usecase.dart`
- [ ] `lib/domain/usecases/vocabulary/get_words_due_for_review_usecase.dart`
- [ ] `lib/domain/usecases/wordlist/get_all_word_lists_usecase.dart`
- [ ] `lib/domain/usecases/wordlist/complete_word_list_phase_usecase.dart`

### Güncellemeler
- [ ] `supabase_vocabulary_repository.dart` → Model kullan
- [ ] `vocabulary_provider.dart` → UseCase kullan
- [ ] Vocabulary screen'leri temizle

### Doğrulama
- [ ] `dart analyze`
- [ ] Kelime çalışma test et
- [ ] Commit & Merge

---

## Modül 5: Badge & User

**Branch:** `git checkout -b refactor/badge-module`

### Dosyalar
- [ ] `lib/data/models/badge/badge_model.dart`
- [ ] `lib/data/models/badge/user_badge_model.dart`
- [ ] `lib/data/models/user/xp_log_model.dart`
- [ ] `lib/domain/usecases/badge/get_user_badges_usecase.dart`
- [ ] `lib/domain/usecases/badge/award_badge_usecase.dart`
- [ ] `lib/domain/usecases/user/add_xp_usecase.dart`
- [ ] `lib/domain/usecases/user/update_streak_usecase.dart`

### Güncellemeler
- [ ] `supabase_badge_repository.dart` → Model kullan
- [ ] `badge_provider.dart` → UseCase kullan

### Doğrulama
- [ ] `dart analyze`
- [ ] Rozet görüntüleme test et
- [ ] Commit & Merge

---

## Modül 6: Teacher

**Branch:** `git checkout -b refactor/teacher-module`

### Dosyalar
- [ ] `lib/data/models/teacher/teacher_stats_model.dart`
- [ ] `lib/data/models/teacher/teacher_class_model.dart`
- [ ] `lib/data/models/teacher/student_summary_model.dart`
- [ ] `lib/data/models/assignment/assignment_model.dart`
- [ ] `lib/domain/usecases/teacher/get_teacher_stats_usecase.dart`
- [ ] `lib/domain/usecases/teacher/get_classes_usecase.dart`
- [ ] `lib/domain/usecases/teacher/get_class_students_usecase.dart`
- [ ] `lib/domain/usecases/teacher/create_class_usecase.dart`
- [ ] `lib/domain/usecases/teacher/send_password_reset_email_usecase.dart`
- [ ] `lib/domain/usecases/assignment/get_assignments_usecase.dart`
- [ ] `lib/domain/usecases/assignment/delete_assignment_usecase.dart`

### Güncellemeler
- [ ] `supabase_teacher_repository.dart` → Model kullan
- [ ] `teacher_provider.dart` → UseCase kullan
- [ ] Tüm teacher screen'leri temizle

### Doğrulama
- [ ] `dart analyze`
- [ ] Öğretmen dashboard test et
- [ ] Commit & Merge

---

## Modül 7: Student Assignment

**Branch:** `git checkout -b refactor/student-assignment-module`

### Dosyalar
- [ ] `lib/data/models/assignment/student_assignment_model.dart`
- [ ] `lib/domain/usecases/student_assignment/get_active_assignments_usecase.dart`
- [ ] `lib/domain/usecases/student_assignment/start_assignment_usecase.dart`
- [ ] `lib/domain/usecases/student_assignment/complete_assignment_usecase.dart`

### Güncellemeler
- [ ] `supabase_student_assignment_repository.dart` → Model kullan
- [ ] `student_assignment_provider.dart` → UseCase kullan
- [ ] Student assignment screen'leri temizle

### Doğrulama
- [ ] `dart analyze`
- [ ] Öğrenci ödev test et
- [ ] Commit & Merge

---

## Final

**Branch:** `git checkout -b refactor/final-cleanup`

### Kontroller
- [ ] `dart analyze lib/` → 0 error
- [ ] `grep -r "import.*domain/repositories" lib/presentation/screens/` → 0 sonuç
- [ ] `flutter test` → Geçti
- [ ] Manuel tam akış testi

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
