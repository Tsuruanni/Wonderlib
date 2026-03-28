# Auth

## Audit

### Findings

| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Dead Code | Test file `auth_usecases_test.dart:7` imports non-existent `SignInWithStudentNumberUseCase` — tests will fail to compile | Medium | Fixed (removed dead import + entire test group) |
| 2 | Architecture | Admin login screen (`owlio_admin/.../login_screen.dart:38–74`) has business logic directly in widget — calls `supabase.auth.signInWithPassword`, queries profiles, calls `signOut()` on role failure, uses `setState` for errors. No UseCase, no Either pattern | Low | Skipped (admin panel convention — intentionally flat architecture) |
| 3 | Code Quality | Hard-coded role strings `'teacher'`, `'head'`, `'admin'` in main app router (`router.dart:140,212,222`) instead of `UserRole.xxx.dbValue` from shared package | Low | Fixed (replaced with `UserRole.xxx.dbValue`) |
| 4 | Code Quality | `UserModel.parseRole`/`roleToString` static methods duplicate `UserRole.fromDbValue`/`UserRole.dbValue` from shared package — drift-prone | Low | Skipped (works correctly, flagged in #20 as well) |
| 5 | Code Quality | `AuthController.signOut` (`auth_provider.dart:113–118`) ignores `Either` result from UseCase — silent failure on sign-out error | Low | Skipped (sign-out failure is non-critical; UI navigates to login regardless) |
| 6 | Code Quality | `refreshCurrentUser` returns `Future<void>` in `AuthRepository` interface (`auth_repository.dart:20`) while all other methods return `Either<Failure, T>` — breaks uniform contract | Low | Skipped (intentional — refresh is fire-and-forget, callers don't need error) |
| 7 | Code Quality | `debugPrint` with emoji in `currentUserIdProvider` (`auth_provider.dart:43`) — debug noise in production | Low | Skipped (minor) |
| 8 | Code Quality | Fragile error string matching: `e.message.contains('Invalid login credentials')` in `supabase_auth_repository.dart:80` — breaks if Supabase changes error text | Low | Skipped (no alternative without Supabase error codes) |
| 9 | Security | `award-xp` edge function (`supabase/functions/award-xp/index.ts`) uses `SUPABASE_SERVICE_ROLE_KEY` with **no caller authentication** — any request with anon key can award arbitrary XP to any user | High | Fixed (added JWT verification + self-only constraint) |
| 10 | Security | `handle_new_user()` trigger (`20260131000002:84–88`) trusts `raw_user_meta_data->>'role'` — if open signup is exploited, a user could pass `role: 'admin'` in metadata | Medium | Fixed (trigger now always sets `role='student'`; migration `20260328600001`) |
| 11 | Security | `profiles` table school-wide SELECT policy (`20260131000008:93–95`) exposes all columns (including `password_plain`, `coins`, `email`) to any student in the same school via direct query | Medium | Fixed (school-wide SELECT restricted to `is_teacher_or_higher()`; students use `safe_profiles` view; migration `20260328600001`) |
| 12 | Security | Low-entropy student passwords — `bulk-create-students` generates `word + 3-digit-number` (~27K combinations), combined with `minimum_password_length = 6` and no complexity rules | Low | Accepted (school context — teachers distribute credentials; rate limiting provides mitigation) |
| 13 | Performance | Admin router (`owlio_admin/lib/core/router.dart:44–48`) recreates `GoRouter` on every auth state change — loses navigation history and in-progress transitions | Low | Skipped (admin panel only, acceptable trade-off) |
| 14 | Edge Case | Broadcast stream timing: `_authStateController.broadcast()` in `supabase_auth_repository.dart` can drop initial auth state if no subscriber is listening — splash screen works around this by checking `currentSession` directly | Low | Skipped (workaround is in place) |
| 15 | Code Quality | `signOut()` side effect called inside admin router `redirect` callback (`owlio_admin/lib/core/router.dart:59`) — redirect callbacks should be pure; side effects can cause infinite redirect loops | Low | Skipped (works in practice; GoRouter guards against infinite redirects) |

### Checklist Result

- Architecture Compliance: **PASS** — Main app follows Screen → Provider → UseCase → Repository; admin panel uses intentionally flat architecture (no UseCases, direct Supabase calls). Router bypasses UseCase for auth state stream (documented exception).
- Code Quality: **3 issues** — hard-coded role strings in router (#3), duplicated role parsing (#4), silent sign-out failure (#5). All low severity.
- Dead Code: **PASS** — stale test import removed (#1 fixed)
- Database & Security: **PASS** — award-xp edge function secured with JWT + self-only (#9 fixed), profiles school-wide SELECT restricted to teachers (#11 fixed), trigger hardened to force student role (#10 fixed). Migration: `20260328600001_auth_security_hardening.sql`.
- Edge Cases & UX: **PASS** — login screen handles loading/error states; empty state = login page; role-denied users get clear Turkish error message in admin; forgot-password not implemented (by design — teachers manage credentials).
- Performance: **PASS** — no N+1; login is 2 round-trips (auth + profile fetch) which is acceptable; admin router recreation is minor.
- Cross-System Integrity: **PASS** — auth state drives `authStateChangesProvider` which cascades to all role-gated providers; sign-out clears `AuthState` and stream emits null.

---

## Overview

Auth handles authentication (login/logout), session management, and role-based routing across the main app and admin panel. **Students** log in with a username (auto-appended `@owlio.local` synthetic email) and password distributed by teachers. **Teachers/admins** log in with a real email. The **admin panel** adds an extra role gate — only `admin` and `head` roles can access it. Supabase Auth manages sessions, JWT tokens, and refresh; the app layer adds role routing and profile hydration on top.

## Data Model

### Tables

**`profiles`** — Extends `auth.users` via 1:1 FK (`ON DELETE CASCADE`)
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | FK → auth.users |
| role | VARCHAR(20) NOT NULL | CHECK: `student`, `teacher`, `head`, `admin` |
| school_id | UUID FK → schools | Nullable |
| class_id | UUID FK → classes | ON DELETE SET NULL |
| username | VARCHAR(20) | Students only; unique partial index WHERE NOT NULL |
| password_plain | VARCHAR(20) | For admin/teacher credential display; omitted from `safe_profiles` view |
| email | VARCHAR(255) | Teachers: real email; students: NULL (synthetic email in auth.users only) |

**`auth.users`** — Supabase-managed; synthetic emails (`username@owlio.local`) for students, real emails for teachers/admins.

**`safe_profiles`** — View that strips `email`, `student_number`, `coins`, `settings`, `password_plain`. Used for peer-visible queries (leaderboard, etc.).

### Auto-Profile Trigger

`handle_new_user()` fires `AFTER INSERT ON auth.users`, creates a `profiles` row from `raw_user_meta_data`. Role defaults to `'student'` if not supplied.

### RLS Helper Functions

| Function | Purpose |
|----------|---------|
| `get_user_school_id()` | Returns caller's school_id from profiles |
| `get_user_role()` | Returns caller's role string |
| `is_admin()` | True if role = `'admin'` (note: excludes `head`) |
| `is_teacher_or_higher()` | True if role IN (`'teacher'`, `'head'`, `'admin'`) |

All are `SECURITY DEFINER STABLE` to avoid RLS recursion on profiles.

## Surfaces

### Admin

**Login flow:**
1. Admin enters email + password on login screen
2. `signInWithPassword` authenticates via Supabase Auth
3. Screen queries `profiles.role` for the authenticated user
4. If role is not `admin` or `head` → immediate `signOut()` + Turkish error message
5. If authorized → `context.go('/')` to dashboard

**Role gate:** `isAuthorizedAdminProvider` checks `currentUserRoleProvider` against `UserRole.admin.dbValue` / `UserRole.head.dbValue`.

**Architecture note:** Admin login uses direct Supabase calls in the widget (no UseCase layer). This is the intentional flat architecture convention for the admin panel.

### Student

**Login flow:**
1. Student enters username + password on login screen
2. If input lacks `@` → synthetic email: `$username@owlio.local`
3. `AuthController.signInWithEmail` → `SignInWithEmailUseCase` → `supabase.auth.signInWithPassword`
4. On success → `getCurrentUser()` fetches full profile from `profiles` table
5. `authStateChanges` stream emits the domain `User` entity
6. Router reads role from `session.user.userMetadata` → routes to home

**Session persistence:** Supabase SDK auto-persists sessions and handles token refresh. No explicit refresh logic in the app.

### Teacher

**Login flow:** Same as student but with real email (contains `@`). Router detects `teacher`/`head`/`admin` role from user metadata and redirects to `/teacher/dashboard`.

**Role routing rules:**
- `teacher`, `head`, `admin` → teacher dashboard
- `student` → student home
- Students trying to access `/teacher/*` → redirected to home
- Teachers on student home → redirected to teacher dashboard

## Business Rules

1. **Username = synthetic email identity.** Students don't have real emails. `username@owlio.local` is both the Supabase auth identity and the login key. Teachers distribute username + password via credential cards.

2. **Role is immutable after creation.** The `handle_new_user()` trigger sets role once from metadata. Role changes require direct database update (admin action).

3. **Admin panel double-gate.** Authentication (valid credentials) is necessary but not sufficient — the login screen explicitly checks `profiles.role` and signs out unauthorized users before they reach any admin route.

4. **`password_plain` is a school-context trade-off.** Stored to allow teachers to reprint credential cards. Not included in `safe_profiles` view. Exposed to teachers via `get_students_in_class` and `get_school_students_for_teacher` RPCs (both guarded by `is_teacher_or_higher()` + school-match).

5. **Username generation is race-safe.** `generate_username()` SQL function uses `pg_advisory_xact_lock` to prevent duplicate usernames from concurrent bulk-create operations.

6. **Forgot password is not implemented.** By design — students don't have email addresses, so password reset requires teacher/admin intervention.

7. **`kDevBypassAuth` flag** in `app_config.dart` skips auth entirely when true. Committed as `false`; local dev only.

## Cross-System Interactions

Auth is a **foundation** — most features depend on it, but it triggers very few side effects itself:

- **Login → Profile hydration:** `getCurrentUser()` fetches full profile (XP, coins, level, streak, league tier) and broadcasts via `authStateChangesProvider`. All downstream providers (leaderboard, assignments, progress) derive from this.
- **Login → Streak check:** App open triggers `_updateStreakIfNeeded()` (not in auth layer, but depends on auth state).
- **Sign-out → State clear:** `AuthController.signOut()` resets `AuthState`, stream emits `null`, router redirects to login. Riverpod `autoDispose` cleans up dependent providers.
- **Bulk create → Profile + Auth:** `bulk-create-students` edge function creates `auth.users` entry + profile row in one transaction. Username generation is server-side.

```
Login → signInWithPassword → getCurrentUser (profile fetch) → authStateChanges emit
  → Router: role routing (student home / teacher dashboard)
  → All providers: cascade from authStateChangesProvider

Sign-out → signOut → authStateChanges emit null
  → Router: redirect to login
  → autoDispose: clean up dependent providers
```

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Wrong credentials | `AuthFailure` with localized message; loading state resets |
| Student tries admin panel | Admin login screen rejects non-admin/head roles with Turkish error, signs out |
| Teacher tries student routes | Router redirects to teacher dashboard |
| Student tries teacher routes | Router redirects to student home |
| Network error during login | Generic `ServerFailure`; error displayed on login screen |
| Session expired mid-use | Supabase SDK auto-refreshes; if refresh fails, `onAuthStateChange` emits signed-out, router redirects to login |
| Broadcast stream misses initial state | Splash screen directly checks `currentSession` as workaround |
| Concurrent bulk-create usernames | `pg_advisory_xact_lock` in `generate_username()` prevents duplicates |
| `password_plain` gets stale | No self-service password reset exists, so `password_plain` stays in sync (only set during creation or admin reset) |

## Test Scenarios

- [ ] Happy path: student login with username + password → lands on home
- [ ] Happy path: teacher login with email + password → lands on teacher dashboard
- [ ] Happy path: admin login on admin panel → lands on admin dashboard
- [ ] Error: wrong credentials → error message displayed, no navigation
- [ ] Error: non-admin user tries admin panel → role error shown, signed out
- [ ] Role routing: student navigates to `/teacher/*` → redirected to home
- [ ] Role routing: teacher navigates to `/` → redirected to teacher dashboard
- [ ] Session: close and reopen app → session persists, auto-routed to correct surface
- [ ] Sign-out: tap logout → returns to login screen, session cleared
- [ ] Edge case: bulk-create concurrent students → no duplicate usernames

## Key Files

### Main App
| File | Role |
|------|------|
| `lib/domain/repositories/auth_repository.dart` | Repository contract (5 methods) |
| `lib/data/repositories/supabase/supabase_auth_repository.dart` | Supabase implementation + auth stream |
| `lib/presentation/providers/auth_provider.dart` | Auth providers + AuthController |
| `lib/presentation/screens/auth/login_screen.dart` | Student/teacher login UI |
| `lib/app/router.dart` | Role-based routing + splash screen |

### Admin Panel
| File | Role |
|------|------|
| `owlio_admin/lib/features/auth/screens/login_screen.dart` | Admin login with role gate |
| `owlio_admin/lib/core/supabase_client.dart` | Auth providers + role authorization |
| `owlio_admin/lib/core/router.dart` | Admin route guards |

### Shared / Infrastructure
| File | Role |
|------|------|
| `packages/owlio_shared/lib/src/enums/user_role.dart` | `UserRole` enum (4 roles + predicates) |
| `lib/core/network/interceptors/auth_interceptor.dart` | Dio 401 retry with token refresh |
| `supabase/migrations/20260131000002_create_core_tables.sql` | Profiles schema + `handle_new_user` trigger |
| `supabase/migrations/20260131000008_create_rls_policies.sql` | RLS helper functions + base policies |
| `supabase/migrations/20260325000001_username_auth.sql` | Username column + `generate_username()` |
| `supabase/functions/bulk-create-students/index.ts` | Bulk student creation edge function |

## Known Issues & Tech Debt

1. **Forgot password not implemented** — By design for K-12 context (students have no email). Password resets require teacher/admin intervention via credential cards.

2. **`is_admin()` RLS function excludes `head` role** — Admin panel grants access to both `admin` and `head`, but `is_admin()` only matches `admin`. Content management tables using `is_admin()` in policies will reject `head` users. Current workaround: most content operations use `is_teacher_or_higher()` instead. Audit during individual feature reviews to confirm no `head` user is blocked.

3. **Dual source of truth for role** — Router reads role from `session.user.userMetadata` (JWT), providers read from `profiles` table. Role changes won't affect routing until JWT refresh (up to 1 hour). Acceptable trade-off to avoid async profile fetch in synchronous router redirect.
