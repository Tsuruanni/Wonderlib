# Changelog

Tüm önemli değişiklikler bu dosyada kronolojik olarak tutulur.

Format: [Keep a Changelog](https://keepachangelog.com/)

---

## [Unreleased]

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
