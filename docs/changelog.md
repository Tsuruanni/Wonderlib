# Changelog

Tüm önemli değişiklikler bu dosyada kronolojik olarak tutulur.

Format: [Keep a Changelog](https://keepachangelog.com/)

---

## [Unreleased]

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
- Home'da kitap adı "The Little Prince" ama kapak görseli "Fantastic Mr. Fox" (mock veri uyuşmazlığı)
- Supabase şeması henüz oluşturulmadı (tablolar boş)
- Vocabulary "Add to vocabulary" henüz çalışmıyor (TODO)

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
