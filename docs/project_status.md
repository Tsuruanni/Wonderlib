# Project Status

Son güncelleme: 2026-01-31 (Phase 3 Complete + Student Assignments)

## Current Phase

**Faz 3: Öğretmen MVP** ✅ Complete

## Roadmap

### Faz 0: Altyapı ✅
- [x] GitHub repo oluşturma
- [x] Supabase projesi kurulumu
- [x] Cloudflare R2 (medya storage)
- [x] Sentry (error tracking)
- [x] PostHog (analytics)
- [x] CLAUDE.md ve dökümanlar

### Faz 1: MVP Foundation ✅
- [x] Flutter proje oluşturma
- [x] Temel klasör yapısı (Clean Architecture)
- [x] Supabase bağlantısı (client kurulu, şema eksik)
- [x] Authentication UI (school code + login ekranları)
- [x] Temel UI shell (GoRouter, theme)
- [x] Bottom navigation (StatefulShellRoute, 3 tabs: Home, Library, Vocabulary)
- [x] Supabase database şeması oluşturuldu (21 tablo, local + seed data)

### Faz 2: Öğrenci MVP 🔄 (Aktif)
- [x] Dijital kütüphane (kitap listesi) - grid/list, filters, search
- [x] Okuma ekranı (sayfa görüntüleme) - reader with vocabulary
- [x] Anlık sözlük (kelimeye tıkla) - vocabulary popup
- [x] Inline aktiviteler (3 tip) - true/false, word translation, find words
- [x] XP ve seviye sistemi (UI + Supabase backend)
- [x] Basit profil sayfası

### Faz 3: Öğretmen MVP ✅
- [x] Öğretmen dashboard
- [x] Sınıf listesi ve öğrenci takibi
- [x] Görev atama
- [x] Temel raporlar
- [x] Student assignment view (öğrenci tarafı)

### Faz 4: Admin & İçerik
- [ ] Admin panel
- [ ] Okul/kullanıcı yönetimi
- [ ] Kitap ekleme arayüzü
- [ ] İçerik pipeline

### Faz 4+: İleri Özellikler (Deferred)
- [x] Kelime egzersizi modülü (4-Phase Vocabulary Builder)
- [x] Rozet sistemi (badge earning after XP/streak)
- [ ] Final Quiz (chapter-end gamified quiz) - deferred
- [ ] Offline mod (SyncService) - deferred
- [ ] Sesli okuma / karaoke
- [ ] Mobil app yayını
- [ ] Remote Supabase deployment (`supabase db push`)

## In Progress

| Task | Assignee | Status | Notes |
|------|----------|--------|-------|
| Testing & Validation | User | Active | Manual testing of all features |

## Deferred to Phase 4

| Task | Notes |
|------|-------|
| Final Quiz | Bölüm sonu gamified quiz (escape room) |
| Offline Mode | SyncService + Isar local storage |
| Edge Functions | award-xp, check-streak (currently using RPC functions) |

## Blockers

| Blocker | Impact | Resolution |
|---------|--------|------------|
| ~~Supabase şeması yok~~ | ~~Auth ve veri akışı çalışmıyor~~ | ✅ Full Supabase entegrasyonu tamamlandı |

## Tech Debt

| Item | Priority | Notes |
|------|----------|-------|
| ~~Mock data uyuşmazlığı~~ | ~~Low~~ | ✅ Artık gerçek veri kullanılıyor |
| ~~"Add to vocabulary"~~ | ~~Medium~~ | ✅ Reader'da kelime ekleme çalışıyor |
| Unnecessary break statements | Low | Lint warnings in switch cases |

## Recently Completed

| Task | Date | Notes |
|------|------|-------|
| Student Assignments | 2026-01-31 | Students can view/complete assigned tasks, auto-progress updates |
| Assignment Auto-Progress | 2026-01-31 | Chapter completion triggers assignment progress calculation |
| Phase 3: Teacher MVP | 2026-01-31 | Dashboard, Classes, Assignments, Reports (4 tabs) |
| Teacher Reports | 2026-01-31 | Class Overview, Reading Progress, Assignments, Leaderboard |
| Teacher Assignments | 2026-01-31 | Create, view, delete assignments with student progress |
| Class Management | 2026-01-31 | Classes list, class detail, student detail screens |
| Teacher Dashboard | 2026-01-31 | Stats cards, role-based navigation |
| Activity State Persistence | 2026-01-31 | Fixed caching + timing issues on chapter re-entry |
| Continue Reading Fix | 2026-01-31 | Completed books removed from list |
| Reading Time Persistence | 2026-01-31 | Fixed async issue, added periodic save |
| Duplicate XP Prevention | 2026-01-31 | Two-layer defense for inline activities |
| Add to Vocabulary | 2026-01-31 | Reader vocabulary popup now persists words |
| Badge Earning System | 2026-01-31 | Triggers after XP/streak changes |
| Memory Leak Fixes | 2026-01-31 | StreamController dispose callbacks |
| N+1 Query Fix | 2026-01-31 | getRecommendedBooks optimization |
| Test Users Expansion | 2026-01-31 | 4 users, 36 activities in seed data |
| Turkish Text Cleanup | 2026-01-31 | All UI/errors now in English |
| MockData Removal | 2026-01-31 | Presentation layer no longer uses MockData |
| InlineActivities Provider | 2026-01-31 | Reader activities fetched from Supabase |
| Full Supabase Integration | 2026-01-31 | All 7 repositories now use Supabase |
| SupabaseActivityRepository | 2026-01-31 | Activity results, XP awarding |
| SupabaseUserRepository | 2026-01-31 | XP, streak, leaderboard |
| SupabaseVocabularyRepository | 2026-01-31 | SM-2 spaced repetition |
| SupabaseWordListRepository | 2026-01-31 | 4-phase vocabulary builder |
| SupabaseBadgeRepository | 2026-01-31 | Badge earning system |
| Local Supabase Integration | 2026-01-31 | Auth + Book repos, seed data, test user |
| Reader Collapsible Header | 2026-01-31 | Expanded/collapsed states, book cover, chapter info |
| Activity-based Progress | 2026-01-31 | Progress = completed activities / total activities |
| Chapter Completion System | 2026-01-31 | completedChapterIds persistence, chapter locking |
| Next Chapter Navigation | 2026-01-31 | "Sonraki Bölüm" button, "Kitabı Tamamladın" message |
| GitHub repo | 2026-01-30 | Tsuruanni/Wonderlib |
| Supabase setup | 2026-01-30 | EU region, Wonderlib projesi |
| R2 bucket | 2026-01-30 | readeng-media |
| Sentry setup | 2026-01-30 | Flutter project |
| PostHog setup | 2026-01-30 | EU region |
| Docs structure | 2026-01-30 | CLAUDE.md, architecture, changelog |
| Flutter proje | 2026-01-30 | Clean Architecture yapısı |
| Auth UI | 2026-01-30 | School code + login ekranları |
| Home page | 2026-01-30 | Stats, continue reading, quick actions |
| Profile page | 2026-01-30 | Avatar, stats, sign out |
| UI Audit | 2026-01-30 | Playwright ile tam test yapıldı |
| Bottom Navigation | 2026-01-30 | StatefulShellRoute, 4 tabs |
| Library Page | 2026-01-30 | Grid/list, filters, search |
| Book Detail | 2026-01-30 | SliverAppBar, chapter list, FAB |
| Reader Page | 2026-01-30 | Vocabulary highlighting, settings, nav |
| Inline Activities | 2026-01-30 | 3 aktivite tipi, progressive reveal, XP animasyonu |
| Vocabulary Page | 2026-01-30 | Liste, flashcard pratik, stats |
| Daily Tasks | 2026-01-30 | Home sayfasında günlük görevler widget'ı |
| Profile refactor | 2026-01-30 | Profile tab kaldırıldı, AppBar'a taşındı |
| UI English | 2026-01-30 | Tüm UI metinleri İngilizce'ye çevrildi |
| Recommended Books | 2026-01-30 | Home'da kitap önerisi slider'ı |
| Vocabulary Builder | 2026-01-30 | 4-phase learning: Learn, Spelling, Flashcards, Review |
| Word List Hub | 2026-01-30 | Continue Learning, Recommended, Categories sections |
| Phase Progress | 2026-01-30 | StateNotifier ile progress tracking |

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-01-30 | Flutter + Supabase stack | Tek codebase, hızlı MVP, düşük maliyet |
| 2026-01-30 | Meilisearch atlandı | Supabase FTS yeterli, MVP için maliyet düşürme |
| 2026-01-30 | Learning Locker atlandı | MVP için gerekli değil, sonra eklenebilir |
