# User Profile

## Audit

### Findings

| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Edge Case | Teacher name edit: UI does not refresh after save — `refreshCurrentUserUseCaseProvider` refreshes JWT metadata, not `userControllerProvider` state. Every other mutation (avatar, streak freeze, XP) uses `refreshProfileOnly()` | High | Fixed (replaced with `refreshProfileOnly()`) |
| 2 | Code Quality | `_BadgeRow._formatDate()` uses `DateTime.now()` instead of `AppClock.now()` — incorrect in debug time offset mode | Medium | Fixed (uses `AppClock.now()`) |
| 3 | Edge Case | Profile error state (`profile_screen.dart:59`) shows raw error text with no retry button | Medium | Fixed (added retry button with `ref.invalidate`) |
| 4 | Code Quality | `studentProfileExtraProvider` uses runtime `as` downcasts on `Future.wait` results — fragile, runtime crash on signature change | Low | Fixed (Dart 3 record destructuring with `.wait`) |
| 5 | Code Quality | `userStatsProvider`, `activityHistoryProvider`, `loginDatesProvider` lack `autoDispose` — minor lifecycle leak | Low | Skipped (user-scoped, refreshed explicitly; profile tab is always alive in shell) |
| 6 | Code Quality | `learnedWordsWithDetailsProvider` is not `autoDispose` — loads full vocabulary corpus and never frees | Low | Skipped (profile tab is always alive in shell — intentional) |
| 7 | Architecture | `profileContextProvider` bypasses UseCase layer with raw Supabase queries for school/class names | Low | Skipped (acknowledged in code comment; uses `DbTables.x` correctly, graceful fallback) |
| 8 | Code Quality | `updateUser()`/`toUpdateJson()` in repository/model use `DateTime.now()` instead of `AppClock.now()` for `updated_at` | Low | Skipped (server trigger `update_profiles_updated_at` overrides to `NOW()` anyway) |
| 9 | Admin | User detail screen does not display or edit `class_id` — admin must use Class Management to change class | Low | Skipped (documented in #20 Student Management spec; class management is the canonical path) |
| 10 | Admin | No vocabulary progress section in admin Progress tab — only reading + quiz + badges | Low | Skipped (coverage gap, not a bug) |
| 11 | Admin | Danger zone "Reset Progress" omits `coins`, `longest_streak`, `streak_freeze_count` | Low | Skipped (reset scope is intentionally limited to XP/level/streak) |

### Checklist Result

- Architecture Compliance: **PASS** — Screen → Provider → UseCase → Repository layering respected. One documented bypass (`profileContextProvider`).
- Code Quality: **PASS** — stale UI after teacher edit (#1 fixed), `DateTime.now()` → `AppClock.now()` (#2 fixed), fragile runtime casts (#4 fixed).
- Dead Code: **PASS** — no unused imports, providers, or usecases found.
- Database & Security: **PASS** — `profiles` RLS restricts direct SELECT to own row or `is_teacher_or_higher()`. `safe_profiles` view omits sensitive columns. Monetary columns have column-level `REVOKE UPDATE`. All write RPCs enforce `auth.uid()` check.
- Edge Cases & UX: **PASS** — retry button added (#3 fixed), stale UI on teacher edit (#1 fixed).
- Performance: **PASS** — no N+1 queries. `userStatsProvider` uses single RPC. `learnedWordsWithDetailsProvider` loads in one batch.
- Cross-System Integrity: **PASS** — profile correctly reflects XP/level/coins via `userControllerProvider`. Avatar via `equippedAvatarProvider`. Badges via `userBadgesProvider`. All invalidation patterns are correct.

---

## Overview

User Profile displays the authenticated user's identity, progression stats, and account actions. **Students** see a rich dashboard with avatar, level/XP progress, card collection preview, recent badges, reading/vocab stats, daily review status, and sign-out. **Teachers** see a simpler view with personal info (editable name), password reset link, school context, and sign-out. The **admin panel** provides a detail/edit view under Student Management (spec #20) — not a separate feature.

## Data Model

### Tables

**`profiles`** — Core user record (1:1 with `auth.users` via FK ON DELETE CASCADE)

| Column | Type | Profile Relevance |
|--------|------|-------------------|
| id | UUID PK | Identity |
| first_name, last_name | VARCHAR | Display name (teacher-editable) |
| username | VARCHAR(20) | Student display (`@username`) |
| email | VARCHAR(255) | Teacher display; NULL for students |
| role | VARCHAR(20) | Determines student vs teacher profile body |
| school_id, class_id | UUID FK | Resolved to names via `profileContextProvider` |
| xp, level | INT | Level/XP section |
| coins | INT | Not displayed on profile (visible in shop) |
| current_streak, longest_streak | INT | Not on profile screen (visible in streak widget) |
| avatar_base_id | UUID FK | Avatar display |
| avatar_equipped_cache | JSONB | Denormalized equipped items for fast render |
| league_tier | VARCHAR(20) | Not on profile screen (visible in leaderboard) |

**`safe_profiles`** — View stripping `email`, `student_number`, `coins`, `settings`, `password_plain`. Used by `StudentProfileDialog` for peer profile popups.

### Key Relationships

- `profiles.school_id` → `schools.id` (name display)
- `profiles.class_id` → `classes.id` (name display)
- `profiles.avatar_base_id` → `avatar_bases.id` (avatar render)
- `user_badges` → `badges` (recent badges section)
- `user_cards` → `myth_cards` (card collection preview)

## Surfaces

### Admin

Covered by **Student Management** (spec #20). Admin sees a `UserEditScreen` with 3 tabs: Profile (edit name, role, school), Progress (reading, badges, quizzes), Cards. No dedicated "profile" screen — it is the user detail view.

### Student

**Profile Screen** (`/profile` tab) — 7 sections in a scrollable column:

1. **Header** — Avatar (tappable → `/avatar-customize`), full name, `@username`, school/class names
2. **Level & XP** — Level badge, total XP, progress bar to next level (via `LevelHelper`)
3. **Card Collection** — Unique count / total (96), progress bar, top 5 rarest cards preview, packs opened count. Tappable → `/cards`
4. **Recent Badges** — Last 5 earned badges with icon, name, description, relative date. "See All" bottom sheet if >5. Empty state: "Complete lessons to earn badges!"
5. **Stats** — 4 mini-stats: books read, chapters read, reading time, new words. "My Word Bank" shortcut → `/word-bank`
6. **Daily Review** — 3 states: completed (XP earned), ready (word count, tap to start), building up (progress bar to threshold)
7. **Sign Out** — Confirmation dialog

**Student Profile Dialog** — Popup shown from leaderboard/class view for viewing another student's profile. Uses `safe_profiles` view + `GetUserByIdUseCase`, `GetUserCardStatsUseCase`, `GetUserBadgesUseCase` via `studentProfileExtraProvider`.

### Teacher

**Teacher Profile Body** — Simpler layout:

1. **Header** — Full name, role badge (color-coded), school name, email
2. **Personal Info Card** — Editable first/last name (dialog with validation). Email displayed (not editable)
3. **Password Card** — Sends password reset email via `SendPasswordResetEmailUseCase`
4. **Sign Out** — Same confirmation flow as student

**No avatar, XP, badges, cards, or stats sections for teachers.**

## Business Rules

1. **Role-based profile body**: `user.role.isStudent` → `_StudentProfileBody`; otherwise → `_TeacherProfileBody`. No separate head/admin profile — all non-students get teacher body.
2. **Teacher name edit scope**: Teachers can only edit their own `first_name`/`last_name`. Email is read-only. Role and school are not editable from profile.
3. **Avatar cache**: Student avatar is rendered from `avatarEquippedCache` (JSONB on profiles), NOT by querying `user_avatar_items` on every render. Cache is updated server-side by `equip_avatar_item`/`unequip_avatar_item` RPCs.
4. **Level formula**: `LevelHelper.progress(xp, level)` and `LevelHelper.xpToNextLevel(level)` drive the XP bar. Formula defined in `level_helper.dart`.
5. **Card collection total**: Hard-coded `AppConstants.totalCardCount = 96`.
6. **Badge display order**: Newest first (server returns ordered by `earned_at DESC`). Capped at 5 on profile; full list in bottom sheet.
7. **Daily review threshold**: `minDailyReviewCount` (from `daily_review_provider.dart`) determines when "building up" → "ready" transition happens.
8. **Password reset**: Only available for teachers with a real email. Students have no email — password is managed by teacher/admin.
9. **Student popup uses `safe_profiles`**: Peer-visible data excludes coins, email, password_plain, settings.

## Cross-System Interactions

```
Profile Screen load
  → userControllerProvider (StateNotifier, global)
    → GetUserByIdUseCase → profiles table (own row via RLS)
    → _updateStreakIfNeeded() (login-based streak — see spec #10)
  → equippedAvatarProvider → avatarEquippedCache from user entity (no extra query)
  → profileContextProvider → schools + classes name lookup (raw Supabase, not UseCase)
  → userStatsProvider → get_user_stats RPC (books_completed, chapters_completed, total_reading_time)
  → learnedWordsWithDetailsProvider → vocabulary_progress batch lookup
  → userBadgesProvider → user_badges + badges join
  → userCardStatsProvider → user_card_stats aggregate
  → userCardsProvider → user_cards + myth_cards join
  → todayReviewSessionProvider → daily_review_sessions (today)
  → dailyReviewWordsProvider → vocabulary_progress (due words)
```

```
Teacher name edit
  → UpdateTeacherProfileUseCase → TeacherRepository.updateProfile()
    → profiles UPDATE (first_name, last_name)
  → refreshCurrentUserUseCaseProvider → AuthRepository.refreshCurrentUser()
    → ⚠️ BUG: refreshes JWT, NOT profile state — UI stays stale (Finding #1)
```

```
Avatar customize (from profile)
  → context.push(AppRoutes.avatarCustomize)
  → AvatarController handles equip/unequip
  → On return: equippedAvatarProvider re-reads cache → profile header updates
```

## Edge Cases

| Scenario | Current Behavior |
|----------|-----------------|
| User not found (null) | "User not found" text centered |
| Profile fetch error | Raw error text, no retry button (Finding #3) |
| No badges earned | Empty state: "Complete lessons to earn badges!" |
| No cards collected | Card section shows 0/96 with empty progress bar, no card previews |
| Daily review: not enough words | "Building up" card with progress bar |
| Daily review: completed today | Green "Review Complete!" card with XP earned |
| Teacher with no email | Password card is disabled (no `onTap`) |
| Teacher name edit → stale UI | Name displays old value until next app restart (Finding #1) |
| Peer profile popup (leaderboard) | Uses `safe_profiles` — no sensitive data exposed |

## Test Scenarios

- [ ] **Happy path (student)**: Login as `active@demo.com`, navigate to Profile tab → see avatar, name, username, school/class, level/XP bar, card collection, badges, stats, daily review status
- [ ] **Happy path (teacher)**: Login as `teacher@demo.com`, navigate to Profile → see name, role badge, school, email, personal info card, password card
- [ ] **Teacher name edit**: Edit first name → save → verify name updates immediately on screen (currently fails — Finding #1)
- [ ] **Teacher password reset**: Click password card → verify snackbar "reset link sent"
- [ ] **Empty state (fresh student)**: Login as `fresh@demo.com` → Profile shows 0 XP, level 1, no badges (empty state text), 0/96 cards, 0 stats
- [ ] **Avatar navigation**: Tap avatar edit button → navigates to `/avatar-customize` → return → avatar reflects changes
- [ ] **Card collection tap**: Tap card collection section → navigates to `/cards`
- [ ] **Word bank shortcut**: Tap "My Word Bank" → navigates to `/word-bank`
- [ ] **Badge bottom sheet**: With >5 badges, tap "See All" → full list in bottom sheet
- [ ] **Daily review states**: Check all 3 states: building up (< threshold words), ready (≥ threshold), completed (after today's session)
- [ ] **Sign out**: Tap sign out → confirmation dialog → confirm → redirected to login
- [ ] **Peer profile popup**: From leaderboard, tap another student → dialog shows name, avatar, badges, card stats (no coins/email)
- [ ] **Error recovery**: Simulate network error on profile load → verify error displayed (currently no retry — Finding #3)

## Key Files

### App (Student/Teacher)
- `lib/presentation/screens/profile/profile_screen.dart` — Main profile screen (1463 lines, all sections)
- `lib/presentation/providers/user_provider.dart` — `UserController`, `userStatsProvider`, activity/login providers
- `lib/presentation/providers/profile_context_provider.dart` — School/class name resolution
- `lib/presentation/providers/avatar_provider.dart` — `equippedAvatarProvider`, `AvatarController`
- `lib/presentation/widgets/common/avatar_widget.dart` — Avatar render widget
- `lib/presentation/widgets/common/student_profile_dialog.dart` — Peer profile popup
- `lib/presentation/providers/student_profile_popup_provider.dart` — `studentProfileExtraProvider`
- `lib/domain/entities/user.dart` — User entity
- `lib/data/models/user/user_model.dart` — UserModel (fromJson/toEntity/toUpdateJson)
- `lib/data/repositories/supabase/supabase_user_repository.dart` — Profile CRUD, stats RPC
- `lib/domain/usecases/teacher/update_teacher_profile_usecase.dart` — Teacher name edit

### Admin
- Covered by spec #20 (Student Management): `owlio_admin/lib/features/users/screens/user_edit_screen.dart`

### Database
- `supabase/migrations/20260131000002_create_core_tables.sql` — profiles table
- `supabase/migrations/20260316000002_restrict_profiles_visibility.sql` — `safe_profiles` view
- `supabase/migrations/20260328600001_auth_security_hardening.sql` — School-wide SELECT restricted to teachers

## Known Issues & Tech Debt

| Issue | Severity | Notes |
|-------|----------|-------|
| ~~Teacher name edit stale UI (#1)~~ | ~~High~~ | Fixed — replaced `refreshCurrentUserUseCaseProvider` with `refreshProfileOnly()` |
| ~~`_BadgeRow._formatDate` uses `DateTime.now()` (#2)~~ | ~~Medium~~ | Fixed — uses `AppClock.now()` |
| ~~No retry button on error state (#3)~~ | ~~Medium~~ | Fixed — retry button with `ref.invalidate(userControllerProvider)` |
| ~~Runtime `as` casts in `studentProfileExtraProvider` (#4)~~ | ~~Low~~ | Fixed — Dart 3 record destructuring with `.wait` |
