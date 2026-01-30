# Project Status

Son güncelleme: 2026-01-30 (Inline Activities eklendi)

## Current Phase

**Faz 1: MVP Foundation** ✅ UI tamamlandı, DB şeması eksik

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
- [x] Bottom navigation (StatefulShellRoute, 4 tab)
- [ ] Supabase database şeması oluşturulmalı

### Faz 2: Öğrenci MVP 🔄 (Aktif)
- [x] Dijital kütüphane (kitap listesi) - grid/list, filters, search
- [x] Okuma ekranı (sayfa görüntüleme) - reader with vocabulary
- [x] Anlık sözlük (kelimeye tıkla) - vocabulary popup
- [x] Inline aktiviteler (3 tip) - true/false, word translation, find words
- [ ] XP ve seviye sistemi (UI var, backend yok)
- [x] Basit profil sayfası

### Faz 3: Öğretmen MVP
- [ ] Öğretmen dashboard
- [ ] Sınıf listesi ve öğrenci takibi
- [ ] Görev atama
- [ ] Temel raporlar

### Faz 4: Admin & İçerik
- [ ] Admin panel
- [ ] Okul/kullanıcı yönetimi
- [ ] Kitap ekleme arayüzü
- [ ] İçerik pipeline

### Faz 5+: İleri Özellikler
- [ ] Kelime egzersizi modülü
- [ ] Sesli okuma / karaoke
- [ ] Rozet sistemi
- [ ] Offline mod
- [ ] Mobil app yayını

## In Progress

| Task | Assignee | Status | Notes |
|------|----------|--------|-------|
| Supabase DB şeması | - | Not started | Tablolar henüz yok |
| Final Quiz | - | Not started | Bölüm sonu gamified quiz (escape room) |
| Vocabulary sayfası | - | Not started | Kelime pratik modülü |

## Blockers

| Blocker | Impact | Resolution |
|---------|--------|------------|
| Supabase şeması yok | Auth ve veri akışı çalışmıyor (mock data ile çalışıyor) | Migration dosyaları oluşturulmalı |

## Tech Debt

| Item | Priority | Notes |
|------|----------|-------|
| Mock data uyuşmazlığı | Low | Home'da kitap adı/kapak uyuşmuyor |
| "Add to vocabulary" | Medium | Reader'da kelime ekleme henüz çalışmıyor |

## Recently Completed

| Task | Date | Notes |
|------|------|-------|
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

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-01-30 | Flutter + Supabase stack | Tek codebase, hızlı MVP, düşük maliyet |
| 2026-01-30 | Meilisearch atlandı | Supabase FTS yeterli, MVP için maliyet düşürme |
| 2026-01-30 | Learning Locker atlandı | MVP için gerekli değil, sonra eklenebilir |
