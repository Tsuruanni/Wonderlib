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
- **Placeholder sayfalar:**
  - `/library` - "Library coming soon" empty state
  - `/vocabulary` - "Vocabulary practice coming soon" empty state
  - `/teacher` - "Teacher Dashboard coming soon" empty state
  - `/book/:id` - Sadece Book ID gösteriyor
  - `/reader/:bookId/:chapterId` - Sadece Book/Chapter ID gösteriyor
  - `/activity/:chapterId` - Sadece Chapter Activity ID gösteriyor

### Known Issues
- Home'da kitap adı "The Little Prince" ama kapak görseli "Fantastic Mr. Fox" (mock veri uyuşmazlığı)
- Bottom navigation henüz yok
- Supabase şeması henüz oluşturulmadı (tablolar boş)

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
