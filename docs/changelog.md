# Changelog

Tüm önemli değişiklikler bu dosyada kronolojik olarak tutulur.

Format: [Keep a Changelog](https://keepachangelog.com/)

---

## [Unreleased]

### Remove School Code Screen (2026-02-01)

#### Changed
- **Simplified Login Flow** - Removed school code entry screen entirely
- **Student Number Login** - Now globally unique (no school code needed)
- **Direct Login** - App starts at login screen, not school code

#### Removed
- `SchoolCodeScreen` - Deleted (no longer needed for login)
- `validateSchoolCode` method from AuthRepository
- `signInWithSchoolCode` replaced with `signInWithStudentNumber`

#### Infrastructure
- **Migration** - Added `profiles_student_number_unique` partial index
- **Auth Flow** - Student # lookup no longer requires school_id filter

### Book-Based Assignments & Library Locking (2026-02-01)

#### Changed
- **Simplified Assignment Creation** - Teachers now assign entire books (no chapter selection)
- **Assignment contentConfig** - Removed `chapterIds`, added `lockLibrary` boolean option
- **Progress Calculation** - Assignment progress now based on all chapters in book (not selected subset)

#### Added
- **Library Locking Feature** - Teachers can lock student library until assignment completed
- **BookLockInfo Provider** - `book_access_provider.dart` manages lock state for students
- **Locked Library Banner** - Students see banner explaining assignment lock
- **Locked Book UI** - Lock icon overlay on inaccessible books (grid & list views)
- **Locked Book Dialog** - Tap locked book shows explanation dialog
- **Locked Book Screen** - Full screen explaining lock with navigation to assignments

### Student Assignments & Auto-Progress (2026-01-31)

#### Added
- **Student Assignments Screen** - Students can view all assigned tasks (To Do / Overdue / Completed groups)
- **Assignment Detail Screen** - View task details, due date, progress, and navigate to content
- **Home Assignments Section** - Pending assignments displayed on HomeScreen with badge count
- **Auto Assignment Progress** - When student completes a chapter, assignment progress updates automatically
- **Assignment Completion** - When all required chapters are read, assignment is marked complete

#### Infrastructure
- **StudentAssignmentRepository** - Domain interface + Supabase implementation
- **Student Assignment Providers** - activeAssignmentsProvider, studentAssignmentDetailProvider
- **Chapter Completion Integration** - ChapterCompletionNotifier now updates assignment progress

### Phase 3: Teacher MVP (2026-01-31)

#### Added
- **Teacher Dashboard** - Stats cards (students, classes, assignments, avg progress), welcome header
- **Role-based Navigation** - Separate shell for teachers (Dashboard, Classes, Assignments, Reports)
- **Classes Screen** - View all classes with student count and average progress
- **Class Detail Screen** - View students in class with XP, level, streak, books read
- **Student Detail Screen** - Full student profile with reading progress per book
- **Assignments Management** - Create, view, delete assignments; assign to classes
- **Assignment Detail** - Student-by-student progress tracking with completion rates
- **Reports Hub** - 4 report types: Class Overview, Reading Progress, Assignment Performance, Leaderboard
- **TeacherRepository** - Full Supabase implementation for teacher operations
- **Assignment Seed Data** - 3 test assignments with student progress data

### Reader Persistence Fixes (2026-01-31)

#### Fixed
- **Activity State Persistence** - Completed activities now properly load when re-entering chapters (fixed provider caching + state reset timing)
- **Continue Reading Shows Completed Books** - Books are now removed from Continue Reading after all chapters completed (invalidate continueReadingProvider)
- **Reading Time Not Saved** - Fixed async callback in fold() not being awaited, added periodic save every 30s

#### Changed
- **Periodic Reading Time Save** - Reading time now saved every 30 seconds to prevent data loss
- **Navigation Saves Time** - Close button, Next Chapter, and Back to Book buttons now save reading time before navigating
- **Widget Key for Chapter** - IntegratedReaderContent now keyed by chapter.id to reset internal state on chapter change

### Code Quality & Bug Fixes (2026-01-31)

#### Fixed
- **Duplicate XP Prevention** - Two-layer defense: local state check + DB returns boolean to prevent awarding XP multiple times from same inline activity
- **Add to Vocabulary from Reader** - Vocabulary popup now actually persists words to database (searches word, creates progress record)
- **Badge Earning System** - Badge checking now triggers after XP award and streak update via `check_and_award_badges` RPC
- **Memory Leaks** - Added `dispose()` methods and `ref.onDispose()` callbacks for StreamControllers in auth repository and sync service
- **N+1 Query** - `getRecommendedBooks` now uses single `.not('id', 'in', ...)` query instead of loop
- **Perfect Scores Query** - Fixed badge repository's perfect score calculation (was using invalid filter)
- **XP Logs Column** - Fixed column name in badge repository (`reason` → `source`)

#### Changed
- **Env Validation** - `EnvConstants` now throws `StateError` on missing required values instead of returning empty strings
- **Turkish Text Removed** - All remaining Turkish error messages and UI text translated to English:
  - "Hepsini çevir" → "Translate all"
  - "+XP kazandın" → "You earned +XP"
  - "Bu rozet zaten kazanıldı" → "Badge already earned"
  - Various mock repository error messages

#### Added
- **Test Users Expansion** - 4 test users with different states (fresh, active, advanced, teacher)
- **Expanded Seed Data** - 36 inline activities across all books, reading progress, completed activities

### MockData Removal & Bug Fixes (2026-01-31)
- **InlineActivities Provider** - `getInlineActivities()` method added to BookRepository, reader now fetches activities from Supabase
- **MockData Eliminated** - All presentation layer MockData usages removed (reader_screen, integrated_reader_content)
- **Vocabulary Screen Fix** - AsyncValue handling fixed (was causing type errors with FutureProvider)
- **Slash Command** - `/update-docs-and-commit` custom command for automated documentation updates

### Full Supabase Repository Integration (2026-01-31)
- **SupabaseActivityRepository** - Activity results, XP awarding, best score tracking
- **SupabaseUserRepository** - XP management, streak calculation, leaderboard queries
- **SupabaseVocabularyRepository** - SM-2 spaced repetition, word progress tracking
- **SupabaseWordListRepository** - 4-phase vocabulary builder (learn, spelling, flashcards, review)
- **SupabaseBadgeRepository** - Badge earning logic, earnable badge checking
- **Provider Updates** - All 7 repository providers now use Supabase implementations
- **Table Name Fixes** - vocabulary_words, word_list_items, user_word_list_progress

### Local Supabase Integration (2026-01-31)
- **Environment Config** - `.env` updated to use local Supabase (`127.0.0.1:54321`)
- **SupabaseAuthRepository** - Full implementation with school code + email login
- **SupabaseBookRepository** - Full implementation with books, chapters, reading progress
- **Repository Providers** - Switched Auth and Book from Mock to Supabase implementations
- **Seed Data** - 6 books, 9 chapters, 9 inline activities, test user (test@demo.com)
- **Trigger Fix** - `handle_new_user()` now uses `public.profiles` for schema qualification
- **Test User** - `test@demo.com` / `Test1234` linked to Demo School (DEMO123, 2024001)

### Reader Screen Overhaul (2026-01-31)
- **Collapsible Header** - Expanded: kitap kapağı, başlık, chapter kartı; Collapsed: chapter info, XP, reading time, progress bar
- **Activity-based Progress** - Scroll yerine aktivite tamamlama oranına göre progress (%completed activities)
- **Chapter Completion Persistence** - `ReadingProgress.completedChapterIds` ile tamamlanan chapter'lar kaydediliyor
- **Chapter Locking** - Önceki chapter tamamlanmadan sonrakine geçiş engellendi (book detail'da kilit ikonu)
- **Next Chapter Navigation** - Reader sonunda "Sonraki Bölüm" butonu (tüm aktiviteler tamamlanınca)
- **Book Completion** - Son chapter tamamlanınca "Kitabı Tamamladın! 🎉" mesajı + XP summary
- **State Reset** - Chapter değişiminde activity state sıfırlanıyor (erken completion bug fix)
- **Settings Button** - SliverAppBar.actions'dan CollapsibleReaderHeader içine taşındı
- **Bottom Bar Removed** - Reader'dan bottom navigation bar kaldırıldı
- **Dev Bypass Auth** - `kDevBypassAuth` flag ile development'ta auth atlanabiliyor

### Fixed
- "Kitabı Tamamladın" mesajı aktiviteler tamamlanmadan görünme bug'ı düzeltildi
- Settings butonu chapter thumbnail ile çakışma sorunu giderildi
- Widget tree building sırasında provider modification hatası (Future.microtask ile çözüldü)

### Added
- Proje başlatıldı
- `CLAUDE.md` oluşturuldu - proje hafızası
- `.env` ve `.env.example` oluşturuldu
- Temel dökümanlar hazırlandı (PRD, TRD, User Flows)

### Infrastructure
- GitHub repo oluşturuldu: `Tsuruanni/Wonderlib`
- Supabase projesi kuruldu (Wonderlib - EU Central)
- Cloudflare R2 bucket oluşturuldu (readeng-media)
- Sentry projesi kuruldu (error tracking)
- PostHog kuruldu (analytics)

### UI/Flutter (2026-01-30)
- Flutter projesi oluşturuldu (Clean Architecture yapısı)
- GoRouter ile routing kuruldu (10 route tanımlı)
- Tema ve renk paleti uygulandı (mor/indigo primary)
- **Çalışan sayfalar:**
  - `/school-code` - Okul kodu giriş ekranı (tam işlevsel)
  - `/login` - Giriş ekranı, Email/Student # toggle (tam işlevsel)
  - `/` - Ana sayfa: XP, Streak, Level stats + Continue Reading + Quick Actions
  - `/profile` - Profil sayfası: Avatar, stats, sign out

### UI/Flutter - Major Update (2026-01-30)
- **Bottom Navigation** eklendi (StatefulShellRoute)
  - 4 tab: Home, Library, Vocabulary, Profile
  - Tab state korunuyor (scroll position, etc.)
  - Reader/Activity tam ekran açılıyor
- **Library sayfası** tam implementasyon
  - Grid/List view toggle
  - CEFR seviye filtreleme (A1-C2)
  - Arama fonksiyonu
  - LevelBadge widget (seviyeye göre renk)
  - BookGridCard, BookListTile widgets
- **Book Detail sayfası** tam implementasyon
  - SliverAppBar ile collapsible cover image
  - Kitap bilgileri (author, level, duration, word count)
  - Reading progress indicator
  - Chapter list with completion status
  - "Start/Continue Reading" FAB
- **Reader sayfası** tam implementasyon
  - Vocabulary highlighting (tıklanabilir kelimeler)
  - VocabularyPopup (kelime tanımı)
  - Reader settings (font size, line height, theme)
  - 3 tema: Light, Sepia, Dark
  - Chapter navigation bar (progress, prev/next)
  - Scroll-based progress tracking

### Vocabulary & Daily Tasks (2026-01-30)
- **Vocabulary sayfası** tam implementasyon
  - Kelime listesi (Tümü/Tekrar/Yeni tabs)
  - Status göstergeleri (new, learning, reviewing, mastered)
  - Kelime detay sheet (anlam, fonetik, örnek cümle)
  - Flashcard pratik modu (doğru/yanlış değerlendirme)
  - Stats kartı (toplam, ustalaşılan, öğreniliyor)
- **Günlük Görevler widget'ı** - Home sayfasında
  - 10 dakika oku
  - Kelime tekrarı
  - Aktivite tamamla
  - Progress barlar ve tamamlanma durumu
- **UI Polish** - Türkçe çeviriler (Home sayfası)

### Inline Activities - Microlearning System (2026-01-30)
- **Yeni aktivite sistemi** - paragraflar arasına inline aktiviteler
  - `TrueFalseActivity` - Doğru/Yanlış soruları
  - `WordTranslationActivity` - Kelime çevirisi (çoktan seçmeli)
  - `FindWordsActivity` - Kelime bulma (multi-select chips)
- **Progressive reveal** - aktivite tamamlanmadan sonraki içerik görünmüyor
- **XP sistemi** - doğru cevaplarda XP animasyonu (+5 XP)
- **Auto-scroll** - aktivite tamamlandığında yeni içeriğe kayma
- **Kompakt UI** - minimal, mobile-friendly aktivite kartları
- **Arkaplan rengi** - doğru/yanlış duruma göre kart rengi değişiyor
- **Home butonu** - reader'da sol üste geri dönüş ikonu eklendi
- Mock data güncellendi (3 aktivite tipi için örnek veriler)

### Vocabulary Builder - 4-Phase Learning System (2026-01-30)
- **Wordela-inspired Vocabulary Builder** tam implementasyon
  - Phase 1: Learn Vocab - Grid view, kelime kartları, audio, definition toggle
  - Phase 2: Spelling - Dinleyerek yazma, responsive letter boxes, backspace handling
  - Phase 3: Flashcards - SM-2 flip cards, "I don't know / Got it / Very EASY" buttons
  - Phase 4: Review Quiz - Çoktan seçmeli + fill-in-blank, %70 geçme kriteri
- **Word List Hub** - Horizontal scroll cards, Continue Learning, Recommended, Categories
- **Word List Detail** - SliverAppBar, phase progress tracking, FAB navigation
- **Category Browse** - Word listelerini kategoriye göre listele
- **Progress Controller** - StateNotifier ile phase completion tracking
- **Navigation Flow** - Phase tamamlandığında pushReplacement ile sonraki phase'e geçiş

### Fixed
- Phase completion navigation - Continue to Next Phase butonu çalışıyor
- Spelling backspace - Focus widget ile onKeyEvent handling
- Horizontal card overflow - Container height 160→180px
- Header progress indicator - Bottom collision fix (top positioning)

### Known Issues
- ~~Home'da kitap adı "The Little Prince" ama kapak görseli "Fantastic Mr. Fox" (mock veri uyuşmazlığı)~~ ✅ Fixed - real data from Supabase
- ~~Supabase şeması henüz oluşturulmadı (tablolar boş)~~ ✅ Fixed - 21 tables created with seed data
- ~~Vocabulary "Add to vocabulary" henüz çalışmıyor (TODO)~~ ✅ Fixed - Reader popup now persists words

---

## [0.0.1] - 2026-01-30

### Added
- İlk commit
- Proje yapısı ve dökümanlar

---

<!--
Template for new entries:

## [X.X.X] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes in existing functionality

### Deprecated
- Soon-to-be removed features

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Security fixes
-->
