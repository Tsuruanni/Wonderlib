# CLAUDE.md

## Compact Instructions

When compressing context, preserve in priority order:
1. Architecture rules (NEVER/ALWAYS) — never summarize
2. Feature documentation pointers
3. Modified files and key changes
4. Current task context and open TODOs

---

## Architecture Rules (CRITICAL)

### NEVER Do This

| Violation | Why It's Wrong |
|-----------|----------------|
| `ref.read(xxxRepositoryProvider)` in Screen | Screens must use UseCases via Providers |
| `import 'package:flutter'` in UseCase | Domain layer must be framework-agnostic |
| `fromJson`/`toJson` in Entity | JSON handling belongs in Model layer |
| Business logic in Widget | Move to provider |
| UseCase calls directly in Widget | Widget calls Provider, Provider calls UseCase |
| Duplicate helper methods in screens | Use centralized `ui_helpers.dart` |
| Hard-coded table/RPC names | Use `DbTables.x` and `RpcFunctions.x` from owlio_shared |

### ALWAYS Do This

| Pattern | Example |
|---------|---------|
| Screen → Provider → UseCase | `ref.watch(featureProvider)` |
| UseCase returns Either | `Future<Either<Failure, T>>` |
| Model handles JSON | `FeatureModel.fromJson(json).toEntity()` |
| Use shared package enums | `import 'package:owlio_shared/owlio_shared.dart'` |
| Use `DbTables.x` for table names | `supabase.from(DbTables.books)` |
| Use `RpcFunctions.x` for RPC calls | `supabase.rpc(RpcFunctions.awardXpTransaction)` |
| UI in English | All user-facing text must be in English (except admin panel — stays in Turkish) |

### Admin Panel Impact Check

When modifying database schema, RLS policies, or RPC functions:
1. Check if admin accesses affected tables: `grep -r "DbTables.tableName" owlio_admin/lib/`
2. Update shared package if schema changes affect enums or table structure
3. Both `owlio_admin/` and main app use `owlio_shared` — changes affect both

---

## Related Projects

| Project | Path | Description |
|---------|------|-------------|
| Owlio Mobile | `/Users/wonderelt/Desktop/Owlio` | Main Flutter app (student/teacher) |
| Owlio Admin | `/Users/wonderelt/Desktop/Owlio/owlio_admin` | Admin panel (content management) |
| Shared Package | `/Users/wonderelt/Desktop/Owlio/packages/owlio_shared` | Shared enums, table names, RPC constants |

All three share the same Supabase Cloud backend (`wqkxjjakysuabjcotvim`, eu-central-1).

---

## New Feature Methodology

Always follow this order:

1. **Database** (if needed): Create migration in `supabase/migrations/`, `supabase db push --dry-run` then `supabase db push`
2. **Domain Layer**: Entity → Repository Interface → UseCase(s)
3. **Data Layer**: Model (with `fromJson`/`toJson`/`toEntity`) → Repository Implementation
4. **Presentation Layer**: Register provider in `repository_providers.dart` → UseCase provider in `usecase_providers.dart` → Feature provider → Screen/Widget
5. **Verify**: `dart analyze lib/` must pass. Screens must not use repositories directly.

---

## Feature Documentation

Before modifying any feature below, **read the corresponding doc first**.

| Feature | Documentation | When to Read |
|---------|--------------|--------------|
| Book System | `docs/specs/01-book-system.md` | Book lifecycle, chapter completion XP flow, quiz integration, reading progress, inline activities, offline caching, access control |
| Audio/Karaoke Reader | `docs/specs/02-audio-karaoke-reader.md` | Word-level audio sync, karaoke highlighting, listening mode, auto-play, scroll follow, audio caching, TTS pronunciation |
| Inline Activities | `docs/specs/03-inline-activities.md` | 4 activity types (true_false, word_translation, find_words, matching), XP awards, vocabulary integration, idempotency, progressive reveal |
| Book Quiz | `docs/specs/04-book-quiz.md` | 5 question types (multiple_choice, fill_blank, event_sequencing, matching, who_says_what), 70% pass threshold, multi-attempt, XP awards, quiz-gates book completion |
| Vocabulary & Spaced Repetition | `docs/specs/05-vocabulary-spaced-repetition.md` | 10 question types, 3-phase session algorithm, SM-2 spaced repetition, mastery levels, XP/combo, daily review, admin CRUD/CSV import, teacher stats |
| Word Lists | `docs/specs/06-word-lists.md` | Word list CRUD, categories, star rating, sequential unlock, learning path integration, assignment tracking, daily limit, teacher progress view |
| Learning Paths | `docs/specs/07-learning-paths.md` | Template/scope hierarchy, sequential lock, books exempt, daily review gate, path node types, unit assignments, scope resolution, class change handling |
| Daily Vocabulary Review | `docs/specs/08-daily-vocabulary-review.md` | SM-2 due words drill, session composition, XP formula, first-answer-wins, learning path gate, unit cram mode, daily quest integration |
| XP/Leveling | `docs/specs/09-xp-leveling.md` | XP award flow, level formula, combo system, admin-configurable XP values, XP=coins 1:1 rule, idempotency, badge/level-up events, leaderboard |
| Streak System | `docs/specs/10-streak-system.md` | Daily streak, login-based model, freeze mechanic (coins), milestone XP bonuses, notification gating, calendar visualization |
| Badge/Achievement | `docs/specs/11-badge-achievement.md` | 6 condition types, auto-award via RPC, XP rewards, badge editor, earned notification dialog, teacher badge view |
| Leaderboard/Leagues | `docs/specs/12-leaderboard-leagues.md` | Weekly tier competition, league reset, promotion/demotion zones, 3 ranking scopes (league/class/school), teacher report |
| Coin Economy | `docs/specs/13-coin-economy.md` | XP=coins 1:1 co-award, 3 spending flows (card packs, avatar items, streak freeze), coin_logs audit trail, idempotency, system settings |
| Daily Quest | `docs/specs/14-daily-quest.md` | Quest types, implicit progress tracking, auto-reward via RPC, bonus pack claim, admin quest management, daily reset |
| Card Collection | `docs/specs/15-card-collection.md` | Buy packs (coins), collect 96 cards, 8 myth categories, rarity tiers, pity mechanic, pack opening flow, admin card CRUD |
| Avatar System | `docs/specs/16-avatar-system.md` | Base animal selection, accessory shop (coins), z-index layering, per-animal outfit memory, admin catalog CRUD, avatar cache rendering |
| Assignment System | `docs/specs/17-assignment-system.md` | 3 assignment types (book/vocab/unit), distributed completion, teacher CRUD, student progress tracking, library lock, class-change handling, admin read-only view |
| Class Management | `docs/specs/18-class-management.md` | School/class CRUD, student roster, bulk move, login cards PDF, class-change assignment sync trigger, admin school management |
| Teacher Dashboard & Reports | `docs/specs/19-teacher-dashboard-reports.md` | Dashboard stats, 4 report types (class overview, reading progress, assignment performance, leaderboard), admin recent activity analytics, school-scoped RPCs |
| Student Management | `docs/specs/20-student-management.md` | Admin user CRUD, bulk CSV import, tabbed detail view, credential cards, teacher student detail, class management routes |
| Auth | `docs/specs/21-auth.md` | Admin/student/teacher login, role routing, username-based auth, session management, RLS helper functions, bulk-create edge function |
| User Profile | `docs/specs/22-user-profile.md` | Profile screen, avatar display, level/XP bar, card collection preview, badges, stats, daily review, teacher name edit, peer profile popup |
| Riverpod & Audio Patterns | `docs/riverpod-audio-patterns.md` | Provider lifecycle, ref.listen, audio auto-play, listening mode, scroll follow |

See `features.md` for full feature map with doc priority tracking.

---

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Files | `snake_case.dart` | `get_books_usecase.dart` |
| Classes | `PascalCase` | `GetBooksUseCase` |
| Variables | `camelCase` | `bookRepository` |
| UseCase | `VerbNounUseCase` | `CreateAssignmentUseCase` |
| Model | `EntityNameModel` | `BookModel` |
| Provider | `featureNameProvider` | `currentUserProvider` |

---

## Commands

```bash
# Development
flutter pub get
flutter run -d chrome
dart analyze lib/

# Supabase (remote only — no local Docker)
supabase db push --dry-run    # Preview pending migrations (always do this first)
supabase db push              # Push new migrations to remote
supabase functions deploy <name>
supabase migration list

# Build
flutter build web --release
flutter build apk --release

# Test
flutter test
```

> **WARNING:** Remote migrations cannot be easily rolled back. Always `--dry-run` first.

---

## Test Users

All passwords: `Test1234` | School Code: `DEMO123`

| Role | Email |
|------|-------|
| Student (fresh, 0 XP) | fresh@demo.com |
| Student (active, 500 XP) | active@demo.com |
| Student (advanced) | advanced@demo.com |
| Teacher | teacher@demo.com |
| Admin | admin@demo.com |
| + 20 leaderboard students | elif@demo.com, ahmet@demo.com, etc. |
