# Admin User Detail Redesign + Soft-Delete

**Date:** 2026-05-01
**Scope:** owlio_admin user detail screen + main app login flow

## Problem

`owlio_admin/lib/features/users/screens/user_edit_screen.dart` shows the same 3-tab layout (Profil / İlerleme / Kartlar) for every role. For a teacher or admin, the "İlerleme" (reading progress, badges, quiz results) and "Kartlar" tabs are meaningless — they apply only to students. The layout is also dense (3 inline data tables on one tab) and outdated relative to the rest of the admin panel polish.

There is also no way to **disable** a user from the admin panel — the only destructive action is "XP & İlerlemeyi Sıfırla". Admins cannot deactivate a misbehaving teacher or graduated student without hard-deleting from Supabase Auth (loses history, breaks foreign keys).

## Goals

1. Replace the 3-tab "one size fits all" layout with a **role-aware single-scroll page**.
2. Surface role-relevant data (assignments for teachers, condensed gamification for students; nothing extra for admin/head).
3. Add **soft-delete via `is_active` flag** that actually blocks login.
4. Keep credentials display (username/email + plaintext password with copy buttons) as it is — admin needs it for handing out reset info.

## Non-Goals

- No avatar editing in admin panel (out of scope; avatar is user-facing).
- No password reset from admin panel (separate feature, would require Edge Function).
- No auth-level ban via `auth.users.banned_until` — app-level `is_active` check only. Auth-level can be added later if needed.
- No bulk soft-delete (single-user toggle only).
- No audit log of who deactivated whom (use `updated_at` for now).

## Design

### Layout — Single Scroll, Role-Aware

Tabs removed. The screen becomes one `SingleChildScrollView` with sections stacked vertically. For an inactive user the whole header is rendered with a muted background and a `Pasif` chip, so the state is unmistakable.

```
┌──────────────────────────────────────────────────┐
│ IDENTITY CARD                                     │
│   Avatar · Full name · Role chip · School chip    │
│   (student: also Class chip)                      │
│   Username (if student) · Email (if teacher/head) │
│   Plaintext password + copy button                │
│   [Pasif] chip if !is_active                      │
└──────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────┐
│ EDIT FORM                                         │
│   Ad · Soyad                                      │
│   Rol (dropdown) · Okul (dropdown)                │
│   Öğrenci Numarası (only when role=student)       │
│   [Kaydet]                                        │
└──────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────┐
│ ROLE-SPECIFIC SECTION (see below)                 │
└──────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────┐
│ TEHLİKELİ BÖLGE                                   │
│   (student only) [XP & İlerlemeyi Sıfırla]        │
│   [Hesabı Pasifleştir] / [Hesabı Aktifleştir]     │
└──────────────────────────────────────────────────┘
```

### Role-Specific Section

**Student**
- Stat row: 4 compact tiles — Lv, XP, Streak (current), Coins
- "Okuma İlerlemesi" — first 5 books with %, "Tümünü Gör →" if more
- "Rozetler" — earned badges as chip strip (no date)
- "Quiz Sonuçları" — first 5 results, pass/fail icon
- "Kart Koleksiyonu" — total + unique count, "Koleksiyona Git →" link (no detailed grid)

**Teacher / Head**
- "Atama Özeti" — top-level stats: total assignments, distinct classes touched, last assignment date
- "Son Atamalar" — first 5 assignments (title, target class, created_at), "Tümünü Gör →" filters assignments page by `teacher_id=userId`

**Admin**
- No role-specific section. Identity card + edit form + danger zone are enough.

### Soft-Delete

#### DB
New column on `profiles`:
```sql
ALTER TABLE profiles ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT true;
CREATE INDEX idx_profiles_is_active ON profiles(is_active) WHERE is_active = false;
```
Partial index because the common path (active users) doesn't need it; the inactive set is small and benefits from quick filtering.

#### Admin UI behavior
- Detail screen danger zone shows either "Hesabı Pasifleştir" or "Hesabı Aktifleştir" depending on current state. Confirm dialog before toggle.
- Toggle just updates `profiles.is_active`. The provider re-invalidates and the identity card re-renders with the muted style + `Pasif` chip.
- User list: each user card shows a `Pasif` chip next to the role chip when `!is_active`. No new filter for now (search/role filter still works).

#### Main app login enforcement
File: `lib/data/repositories/supabase/supabase_auth_repository.dart`

After `signInWithPassword` succeeds, fetch the profile:
```dart
final profile = await _supabase
    .from('profiles')
    .select('is_active')
    .eq('id', response.user!.id)
    .single();

if (profile['is_active'] == false) {
  await _supabase.auth.signOut();
  throw const AuthException('Hesabınız pasifleştirildi. Lütfen yöneticinizle iletişime geçin.');
}
```

The login screen catches `AuthException` and displays its message — no extra UI plumbing needed (`login_screen.dart` already shows auth errors).

For users already in a session when they get deactivated: they keep the session until token refresh. Acceptable for v1; can be hardened later via realtime subscription on profile or by checking is_active on app resume.

## Data Flow

```
Admin clicks "Hesabı Pasifleştir"
  → confirm dialog
  → supabase.from('profiles').update({is_active: false}).eq('id', userId)
  → invalidate userDetailProvider, usersProvider
  → UI re-renders: muted header + Pasif chip + button label flips

Student opens main app
  → signInWithPassword → success
  → fetch profile.is_active
  → if false: signOut + throw → login screen shows error
  → if true: proceeds normally
```

## Components / Files

### New
- `supabase/migrations/20260501000003_add_profiles_is_active.sql` — column + index
- `owlio_admin/lib/features/users/widgets/user_identity_card.dart` — top header widget (avatar, name, chips, credentials)
- `owlio_admin/lib/features/users/widgets/user_edit_form.dart` — extracted form (no behavior change)
- `owlio_admin/lib/features/users/widgets/student_progress_section.dart` — stats row + condensed reading/badges/quiz/cards
- `owlio_admin/lib/features/users/widgets/teacher_assignments_section.dart` — assignment summary + last 5 list

### Modified
- `owlio_admin/lib/features/users/screens/user_edit_screen.dart` — gut and rebuild with role switch; remove `_UserProgressTab`, `_UserCardsTab`, `_StatCard`, `_LevelChip`, `_emptyState` (replaced by section widgets); remove TabController.
- `owlio_admin/lib/features/users/screens/user_list_screen.dart` — `_UserCard` adds `Pasif` chip when `!is_active`; provider already returns `*` so no query change.
- `lib/data/repositories/supabase/supabase_auth_repository.dart` — post-login `is_active` check.

### Provider additions
- `userAssignmentsSummaryProvider` (family on userId): single Supabase call `from('assignments').select('*, classes(name), books(title), word_lists(name)', count: CountOption.exact).eq('teacher_id', userId).order('created_at', ascending: false).limit(5)`. Returns `{rows, totalCount}`. Distinct class count is derived client-side from `rows`; if the user has more than 5 assignments touching different classes the count understates, but for the summary "X atama · ~Y sınıf" that's acceptable — exact distinct class count would need an RPC and isn't worth it for a header line.

Existing providers (`userDetailProvider`, `userReadingProgressProvider`, `userBadgesProvider`, `userQuizResultsProvider`, `userCardsProvider`) are reused unchanged. The student section just renders the first 5 of each.

## Error Handling

- Login `is_active` check failure (network error fetching profile): treat as login failure, sign out, show generic error. Don't leak users in if we can't verify status.
- Profile UPDATE failure on toggle: show snackbar with error, leave provider stale until user retries (existing pattern).
- Assignments query failure: section shows "Yüklenirken hata: {err}" inline, doesn't block rest of screen.

## Testing

This is admin-internal UI; no automated test infrastructure exists for these screens currently. Manual verification:
1. Open student detail → see condensed sections, no tabs.
2. Open teacher detail → see assignment summary, no progress/cards.
3. Open admin detail → identity + edit + danger only.
4. Toggle active on a teacher → user list shows `Pasif` chip; teacher tries to log in to main app → blocked with Turkish error; toggle back active → can log in.
5. Verify identity card shows username (student) or email (teacher) + plaintext password copy button works.

## Compatibility Risks

- `is_active` defaults to true for existing rows, so no behavior change for current users.
- Login flow: extra DB roundtrip after every successful sign-in. Single `select` on `profiles` by primary key — negligible cost.
- Existing `_UserCardsTab` / `_UserProgressTab` deletion: nothing imports them outside this file.
- Admin panel localization: Turkish only (existing convention; admin-panel-only file).

## Open Questions

None. Decisions taken:
- Tabs removed (vs. role-conditional tabs) — simpler.
- App-level enforcement (vs. auth-level ban) — sufficient for now.
- Plaintext password kept visible (vs. masked + reveal) — operational need.
- Soft-delete via single boolean (vs. status enum) — YAGNI; add states later if needed.
