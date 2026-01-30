# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Project Overview
- **Proje adı:** ReadEng (Wonderlib)
- **Amaç:** K-12 öğrencileri için interaktif İngilizce okuma platformu
- **Hedef kullanıcılar:** İlkokul-lise öğrencileri, İngilizce öğretmenleri
- **Ana özellikler:** Dijital kütüphane, bölüm sonu aktiviteleri, kelime egzersizleri, XP/rozet sistemi, öğretmen dashboard

# Tech Stack & Architecture
- **Frontend:** Flutter (Android, iOS, Web, Desktop) - tek codebase
- **State Management:** Riverpod
- **Local Database:** Isar (offline-first)
- **Backend:** Supabase (PostgreSQL + Auth + Storage + Edge Functions)
- **Media Storage:** Cloudflare R2
- **Analytics:** PostHog
- **Error Tracking:** Sentry

**Klasör yapısı (hedef):**
```
lib/
├── core/           # constants, errors, network, services
├── data/           # datasources (local/remote), models, repositories
├── domain/         # entities, repository interfaces, usecases
├── presentation/   # providers, screens, widgets
└── l10n/           # localization (TR/EN)
```

**Mimari tercihler:**
- Clean Architecture (domain-driven)
- Offline-first: önce lokal kaydet, sonra senkronize et
- Repository pattern ile data abstraction

**Offline-First Data Flow:**
```
User Action → Local DB (Isar) → UI Update → Sync Queue → Supabase (when online)
```
- Tüm yazma işlemleri önce Isar'a kaydedilir
- `SyncService` bağlantı gelince queue'yu işler
- Conflict resolution: last-write-wins (server timestamp)

# Coding Guidelines
- **Dil:** Dart (Flutter), strict null safety
- **Stil:** flutter_lints varsayılanları
- **İsimlendirme:**
  - Dosyalar: `snake_case.dart`
  - Sınıflar: `PascalCase`
  - Değişkenler/fonksiyonlar: `camelCase`
- **State:** Riverpod providers, immutable state
- **API çağrıları:** `data/datasources/remote/` altında topla
- **Lokal veri:** `data/datasources/local/` altında Isar kullan
- Gereksiz abstraction üretme, mevcut pattern'i takip et

# Testing & Quality
- **Test aracı:** flutter_test, mockito
- **Beklenti:**
  - UseCases için unit test
  - Repository implementasyonları için integration test
  - Widget'lar için widget test (kritik olanlar)
- **Claude'dan:** Test ekleyebiliyorsan ekle, ekleyemiyorsan hangi testlerin yazılması gerektiğini listele

# Commands & Tooling
```bash
# Kurulum
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Geliştirme
flutter run                              # debug mode
flutter run -d chrome                    # web
dart run build_runner watch              # code generation watch mode

# Build
flutter build apk --release              # Android
flutter build ios --release              # iOS
flutter build web --release              # Web

# Test
flutter test                             # tüm testler
flutter test test/path/to_test.dart      # tek dosya
flutter test --name "test description"   # isimle filtreleme
flutter test --coverage

# Supabase Local Development
supabase start                           # local Supabase başlat
supabase stop                            # local Supabase durdur
supabase status                          # servis durumları

# Supabase Remote
supabase login
supabase link --project-ref <ref>
supabase db push                         # migration'ları uygula
supabase db reset                        # local DB sıfırla + seed
supabase functions deploy                # edge functions deploy
supabase functions serve                 # local edge function test
```

**Env değişkenleri:** (değerler `.env` dosyasında)
- `SUPABASE_URL` - Supabase proje URL
- `SUPABASE_ANON_KEY` - public client key
- `SUPABASE_SERVICE_ROLE_KEY` - sadece backend (gizli)
- `SENTRY_DSN` - error tracking
- `POSTHOG_API_KEY` - analytics
- `R2_*` - Cloudflare medya storage

# Workflows
- **Önce sor:** Belirsizlik varsa tahmin yapma, netleştirici sorular sor
- **Büyük görevlerde:**
  1. Plan çıkar (maddeler halinde)
  2. Planı göster, onay iste
  3. Onaylanan planı adım adım uygula
- **Kod yazarken:**
  - Mevcut dosyayı oku, stilini takip et
  - Yeni pattern icat etme, mevcut olanı kullan
- **Değişiklik sonrası:** `## Changes Summary` ile değişen dosyaları listele

# Context & Limits
- Bu dosya her zaman okunuyor - sadece genel kurallar burada
- Feature detayları için: `readeng-prd.md`, `readeng-trd-v2.md`, `readeng-user-flows.md`
- Kod ile bu kurallar çelişirse: önce mevcut kodu koru, çelişkiyi raporla

# Domain Özeti
- **Kullanıcı rolleri:** student, teacher, head, admin
- **CEFR seviyeleri:** A1, A2, B1, B2, C1, C2
- **Gamification:** XP sistemi, seviyeler (Bronze→Diamond), streak bonusu
- **Offline:** Değişiklikler sync queue'ya eklenir, bağlantı gelince senkronize edilir

# Key Database Tables
- `schools` → `classes` → `profiles` (multi-tenant, RLS ile izole)
- `books` → `chapters` → `activities` (içerik hiyerarşisi)
- `reading_progress`, `activity_results`, `vocabulary_progress` (kullanıcı ilerlemesi)
- `xp_logs`, `badges`, `user_badges` (gamification)

# Supabase Edge Functions
- `award-xp` - XP kazandırma + badge kontrolü + xAPI log
- `check-streak` - Streak hesaplama ve bonus XP
- Tüm functions `supabase/functions/` altında
