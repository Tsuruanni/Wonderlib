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

**Klasör yapısı:**
```
lib/
├── core/           # constants, errors, network, services
├── data/
│   ├── models/     # JSON↔Entity dönüşümü (Supabase response → Entity)
│   └── repositories/supabase/  # Repository implementasyonları
├── domain/
│   ├── entities/   # Saf iş nesneleri (Flutter bağımsız)
│   ├── repositories/  # Repository interface'leri
│   └── usecases/   # İş mantığı (tek sorumluluk)
├── presentation/
│   ├── providers/  # Riverpod state management
│   ├── screens/    # UI katmanı
│   └── widgets/    # Reusable components
└── l10n/           # localization (TR/EN)
```

**Mimari tercihler:**
- Clean Architecture (domain-driven)
- Offline-first: önce lokal kaydet, sonra senkronize et
- Repository pattern ile data abstraction
- **Model/Entity ayrımı:** Data layer JSON parse, Domain layer saf kalır

## ⚠️ Clean Architecture Kuralları (KRİTİK)

**Katman Akışı (TEK YÖN):**
```
Screen → Provider → UseCase → Repository Interface
                                      ↑
                              Repository Impl → Model → Supabase
```

**YASAK İşlemler:**
| Yapma | Neden |
|-------|-------|
| Screen'de Repository import | Presentation → Domain direkt bağlantı yasak |
| Screen'de `ref.read(xxxRepositoryProvider)` | UseCase üzerinden git |
| UseCase'de Flutter import | Domain katmanı saf kalmalı |
| Entity'de `fromJson`/`toJson` | Model katmanında olmalı |

**DOĞRU Pattern:**
```dart
// Screen - sadece Provider kullanır
final data = ref.watch(someProvider);

// Provider - UseCase çağırır
final result = await ref.read(someUseCaseProvider)(SomeParams(...));

// UseCase - Repository interface kullanır
return _repository.someMethod(params);

// Repository Impl - Model kullanır
final model = SomeModel.fromJson(json);
return model.toEntity();
```

**Refactor Planı:** `docs/CLEAN_ARCHITECTURE_REFACTOR_PLAN.md`
**Checklist:** `docs/REFACTOR_CHECKLIST.md`

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
  - UseCase: `VerbNounUseCase` (örn: `GetBooksUseCase`, `CreateAssignmentUseCase`)
  - Model: `EntityNameModel` (örn: `BookModel`, `UserModel`)
- **State:** Riverpod providers, immutable state
- **UseCase'ler:** `lib/domain/usecases/` altında, `Either<Failure, T>` döndürmeli
- **Model'ler:** `lib/data/models/` altında, `toEntity()` ve `fromJson()` içermeli
- **API çağrıları:** Repository implementasyonları üzerinden
- **Lokal veri:** `data/datasources/local/` altında Isar kullan
- Gereksiz abstraction üretme, mevcut pattern'i takip et
- **UI Language:** All user-facing text must be in English (no Turkish in UI)

## UseCase Şablonu
```dart
class XxxUseCase implements UseCase<ReturnType, XxxParams> {
  final XxxRepository _repository;
  const XxxUseCase(this._repository);

  @override
  Future<Either<Failure, ReturnType>> call(XxxParams params) {
    return _repository.someMethod(params.field);
  }
}
```

## Model Şablonu
```dart
class XxxModel {
  // fields...

  factory XxxModel.fromJson(Map<String, dynamic> json) { ... }
  Map<String, dynamic> toJson() { ... }
  XxxEntity toEntity() { ... }
  factory XxxModel.fromEntity(XxxEntity entity) { ... }
}
```

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
  - **Clean Architecture kurallarına uy** (yukarıdaki YASAK tablosuna bak)
- **Yeni özellik eklerken:**
  1. Model oluştur (`lib/data/models/`)
  2. UseCase oluştur (`lib/domain/usecases/`)
  3. Provider güncelle (UseCase kullan)
  4. Screen'de Provider kullan (Repository değil!)
- **Değişiklik sonrası:** `## Changes Summary` ile değişen dosyaları listele
- **Doğrulama:** `dart analyze` ve `grep -r "import.*domain/repositories" lib/presentation/screens/`

# Context & Limits
- Bu dosya her zaman okunuyor - sadece genel kurallar burada
- Feature detayları için: `readeng-prd.md`, `readeng-trd-v2.md`, `readeng-user-flows.md`
- **Mimari plan:** `docs/CLEAN_ARCHITECTURE_REFACTOR_PLAN.md`
- **Refactor checklist:** `docs/REFACTOR_CHECKLIST.md`
- Kod ile bu kurallar çelişirse: önce mevcut kodu koru, çelişkiyi raporla
- **Clean Architecture ihlali görürsen:** Düzelt veya raporla (Screen'de repository import vb.)

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

# ⚠️ IMPORTANT: Development Status

## Current State (2026-02-01)
- **Local Supabase:** ✅ Docker ile çalışıyor, 21 tablo + seed data
- **Remote Supabase:** ❌ Tablolar YOK (migrations push edilmedi)
- **Flutter App:** ✅ Tüm 9 repository Supabase kullanıyor
- **Clean Architecture Refactor:** 🔄 Devam ediyor (bkz: `docs/CLEAN_ARCHITECTURE_REFACTOR_PLAN.md`)

## Mimari Refactor Durumu
| Katman | Durum | Not |
|--------|-------|-----|
| Repository Interface | ✅ Tamamlandı | 9 interface |
| Repository Impl | ✅ Tamamlandı | Supabase implementasyonları |
| Model Layer | 🔄 Ekleniyor | `lib/data/models/` |
| UseCase Layer | 🔄 Ekleniyor | 4 mevcut, ~48 hedef |
| Provider Layer | 🔄 Güncelleniyor | UseCase kullanacak |
| Screen Layer | 🔄 Temizleniyor | Repository import kaldırılacak |

## 🚨 REMOTE PUSH YAPILMADI - ÇOK ÖNEMLİ!
Tüm geliştirme LOCAL Supabase üzerinde yapılıyor. Production'a geçmeden önce:
```bash
supabase db push  # migrations'ları remote'a gönder
```
Bu komut çalıştırılana kadar remote DB boş kalacak!

## Supabase Entegrasyon Durumu
| Repository | Implementation | Status |
|------------|----------------|--------|
| AuthRepository | SupabaseAuthRepository | ✅ |
| BookRepository | SupabaseBookRepository | ✅ |
| UserRepository | SupabaseUserRepository | ✅ |
| VocabularyRepository | SupabaseVocabularyRepository | ✅ |
| WordListRepository | SupabaseWordListRepository | ✅ |
| ActivityRepository | SupabaseActivityRepository | ✅ |
| BadgeRepository | SupabaseBadgeRepository | ✅ |

## Test Kullanıcısı
- **Email:** test@demo.com
- **Password:** Test1234
- **School Code:** DEMO123
- **Student Number:** 2024001

## Local Development Setup
```bash
# 1. Docker Desktop'ı aç
# 2. Local Supabase başlat
supabase start

# 3. .env zaten local URL kullanıyor
SUPABASE_URL=http://127.0.0.1:54321

# 4. Uygulamayı çalıştır
flutter run -d chrome
```
