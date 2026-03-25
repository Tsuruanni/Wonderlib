# Username Auth + Bulk Student Creation — Design Spec

**Date:** 2026-03-24
**Scope:** Replace student_number login with username-based auth (synthetic email pattern), add bulk student creation to admin panel, remove old CSV import.

---

## Problem Statement

1. **Login UX:** Students currently log in with `student_number` — not intuitive. Teachers use email. Two separate login tabs create friction.
2. **User creation:** Admin panel cannot create users (only update existing profiles via CSV). New users must be created through Supabase Dashboard — impractical for schools with hundreds of students.
3. **CSV import:** Current import only updates profiles for users who already registered — limited utility.

---

## Design

### A. Synthetic Email Auth Pattern

**Approach:** Map usernames to synthetic emails so Supabase Auth works unchanged.

- Student login: `username` → `signInWithPassword(email: '${username}@owlio.local')`
- Teacher/admin login: `email` → `signInWithPassword(email: email)` (no change)
- Detection: input contains `@` → email auth, otherwise → username auth

**Single login screen** replaces current tabbed student/teacher login:

```
┌──────────────────────────┐
│  Username veya Email     │
│  [____________________]  │
│  Şifre                   │
│  [____________________]  │
│                          │
│  [     Giriş Yap     ]  │
└──────────────────────────┘
```

---

### B. Username Generation Algorithm

**Format:** first 3 chars of first_name + first 3 chars of last_name + incrementing number

**Rules:**
1. Take up to 3 characters from first name, up to 3 from last name (shorter names use what's available)
2. Turkish → ASCII transliteration: `ş→s, ç→c, ğ→g, ö→o, ü→u, ı→i, İ→i`
3. Lowercase
4. Append number starting at 1, increment if base+number exists

**Examples:**
| Name | Username |
|------|----------|
| Mesut Yılmaz | mesyil1 |
| Mesut Yıldırım | mesyil2 (mesyil taken) |
| Ece Ay | eceay1 |
| Ali Öz | alioz1 |

**Implementation:** PostgreSQL function `generate_username(p_first_name TEXT, p_last_name TEXT) RETURNS TEXT`
- Computes base from name
- Queries `profiles` for highest existing number with same base
- Returns base + (max_number + 1), or base + 1 if none exist

---

### C. Password Generation

**Format:** English word (3-4 chars) + 3 digit number (always 3 digits to guarantee 6+ char minimum — Supabase Auth requires minimum 6)

**Word list (~30 words):** `owl`, `fox`, `sun`, `cat`, `dog`, `bee`, `sky`, `ice`, `red`, `pen`, `cup`, `hat`, `map`, `box`, `key`, `gem`, `fin`, `pod`, `ray`, `dew`, `elm`, `oak`, `fig`, `ant`, `bat`, `elk`, `cod`, `ram`, `yak`, `emu`

**Examples:** `fox047`, `owl193`, `cat082`, `sun214`

**Generated in Edge Function** (not in DB). Returned in response for admin to download. Not stored anywhere in plaintext — Supabase Auth stores the hash.

---

### D. Database Changes

#### D1. `profiles` table — add `username` column

```sql
ALTER TABLE profiles ADD COLUMN username VARCHAR(20);
CREATE UNIQUE INDEX idx_profiles_username ON profiles(username) WHERE username IS NOT NULL;

-- Prevent duplicate classes with NULL academic_year (needed for class auto-creation)
CREATE UNIQUE INDEX idx_classes_unique_null_year ON classes(school_id, name) WHERE academic_year IS NULL;
```

- `username`: Nullable — only students have usernames, teachers/admins have NULL. Unique where not null.
- `idx_classes_unique_null_year`: Prevents concurrent class auto-creation from producing duplicate classes. PostgreSQL treats NULL ≠ NULL for unique constraints, so this partial index is needed.

#### D2. `generate_username()` function

```sql
CREATE OR REPLACE FUNCTION generate_username(p_first_name TEXT, p_last_name TEXT)
RETURNS TEXT AS $$
DECLARE
  v_base TEXT;
  v_max_num INT;
BEGIN
  -- Turkish → ASCII, lowercase, take first 3 chars each
  v_base := lower(
    translate(
      left(p_first_name, 3) || left(p_last_name, 3),
      'şçğöüıİŞÇĞÖÜ',
      'scgouiiSCGOU'
    )
  );

  -- Strip non-alphanumeric chars (handles names with periods, hyphens, etc.)
  v_base := regexp_replace(v_base, '[^a-z0-9]', '', 'g');

  -- Safety: if base is empty after sanitization, use 'user'
  IF v_base = '' THEN
    v_base := 'user';
  END IF;

  -- Find highest existing number for this base (with advisory lock to prevent race conditions)
  PERFORM pg_advisory_xact_lock(hashtext(v_base));

  SELECT MAX(
    CAST(substring(username FROM length(v_base) + 1) AS INT)
  ) INTO v_max_num
  FROM profiles
  WHERE username LIKE v_base || '%'
    AND substring(username FROM length(v_base) + 1) ~ '^\d+$';

  RETURN v_base || COALESCE(v_max_num + 1, 1);
END;
$$ LANGUAGE plpgsql;
```

**Concurrency safety:** Uses `pg_advisory_xact_lock` on the base string hash. If two concurrent requests try to generate a username for the same base (e.g., two "Mesut Yılmaz" in a bulk CSV), they will be serialized. The lock is released when the transaction commits.

#### D3. Migrate existing students — profiles

```sql
-- Generate usernames for all existing students who don't have one
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT id, first_name, last_name
    FROM profiles
    WHERE role = 'student' AND username IS NULL
    AND first_name IS NOT NULL AND last_name IS NOT NULL
  LOOP
    UPDATE profiles
    SET username = generate_username(r.first_name, r.last_name)
    WHERE id = r.id;
  END LOOP;
END $$;
```

#### D4. Migrate existing students — auth.users email

Existing students have real emails in `auth.users` (e.g., `fresh@demo.com`). After username generation, their `auth.users.email` must be updated to `username@owlio.local` so the new login flow works.

**This requires a one-time Edge Function or script using service_role key:**

```typescript
// For each student with a username:
// 1. Read username from profiles
// 2. auth.admin.updateUserById(id, { email: `${username}@owlio.local` })
// 3. Clear profiles.email to NULL (no longer needed for students)
```

**IMPORTANT:** This is a destructive migration — existing students will no longer be able to log in with their old email. Must be deployed together with the Flutter login change (Step 5 in Migration Strategy).

#### D5. Update `safe_profiles` view

Add `username` to the `safe_profiles` view so it's visible in leaderboard/peer queries. Username is not sensitive — it's a public identifier like a gamertag.

---

### E. Edge Function — `bulk-create-students`

**Endpoint:** `POST /functions/v1/bulk-create-students`

**Auth:** Bearer token (JWT) — caller must be `admin` or `head` role.

**Request body:**
```json
{
  "school_id": "uuid",
  "students": [
    { "first_name": "Mesut", "last_name": "Yılmaz", "class_name": "5-A" },
    { "first_name": "Ece", "last_name": "Ay", "class_name": "5-B" }
  ]
}
```

**Flow per student:**
1. Look up class by `class_name` + `school_id` (WHERE `academic_year IS NULL`) — if not found, create it
2. Call `generate_username(first_name, last_name)` via DB (inside a transaction for advisory lock)
3. Generate random password (word + 3 digits, e.g., `fox047`)
4. `auth.admin.createUser({ email: username@owlio.local, password, email_confirm: true, user_metadata: { first_name, last_name, role: 'student' } })`
5. DB trigger auto-creates profile row (with synthetic email in `profiles.email`)
6. `UPDATE profiles SET username, school_id, class_id, email = NULL WHERE id = new_user.id` (clear synthetic email from profiles — it's only needed in `auth.users`)

**Note on `profiles.email`:** The `handle_new_user` trigger copies `auth.users.email` into `profiles.email`. For students, this would be the synthetic email (`mesyil1@owlio.local`). Step 6 sets `profiles.email = NULL` for students to avoid leaking the internal pattern. Teachers keep their real email.

**Response:**
```json
{
  "created": [
    { "first_name": "Mesut", "last_name": "Yılmaz", "username": "mesyil1", "password": "fox047", "class_name": "5-A" }
  ],
  "errors": [
    { "first_name": "???", "last_name": "", "error": "last_name is required" }
  ]
}
```

**Error handling:** Per-row — one failure doesn't stop others. Partial success is normal.

**Batch size limit:** Maximum 200 students per request. Admin panel splits larger CSVs into batches of 200. This prevents Edge Function timeout (Supabase Pro tier: 150s).

**Duplicate detection:** Before creating, check if `(first_name, last_name, school_id, class_id)` combination already exists in profiles. If found, skip with a warning in the errors array (not a hard failure).

**Also used for single student creation** (array of 1) **and single teacher creation:**
```json
{
  "school_id": "uuid",
  "teachers": [
    { "first_name": "Ayşe", "last_name": "Kaya", "email": "ayse@school.com" }
  ]
}
```

Teacher flow: uses real email, no username generated, password auto-generated.

---

### F. Admin Panel Changes

#### F1. Remove
- `user_import_screen.dart` — old CSV profile updater
- CSV import references from user list screen
- Route `/users/import`

#### F2. New Screen: `/users/create` — User Creation

**Layout:**

```
┌─────────────────────────────────────────────┐
│  Okul: [dropdown ▾]                          │
├─────────────────────────────────────────────┤
│  [Tekli Oluşturma]  [Toplu CSV]             │
├─────────────────────────────────────────────┤
│                                              │
│  ── Tab 1: Tekli ──                         │
│  Rol: (●) Öğrenci  (○) Öğretmen            │
│                                              │
│  Öğrenci:                                   │
│    Sınıf: [dropdown ▾ + "Yeni sınıf"]      │
│    Ad: [______]  Soyad: [______]            │
│    [ + Oluştur ]                            │
│                                              │
│  Öğretmen:                                  │
│    Email: [______________]                   │
│    Ad: [______]  Soyad: [______]            │
│    [ + Oluştur ]                            │
│                                              │
│  Sonuçlar:                                  │
│  ✓ mesyil1 / fox47 — Mesut Yılmaz (5-A)   │
│  ✓ ayse@school.com / cat82 — Ayşe Kaya    │
│  [CSV İndir] [Yazdır]                      │
│                                              │
│  ── Tab 2: Toplu CSV ──                     │
│  CSV sütunları: ad, soyad, sınıf            │
│  (okul üstten seçili)                       │
│                                              │
│  [CSV Yükle] → Önizleme tablosu            │
│  [ Oluştur (N öğrenci) ]                   │
│                                              │
│  Sonuç tablosu + [CSV İndir]               │
│  ⚠ "Bu şifreler bir daha gösterilemez"     │
└─────────────────────────────────────────────┘
```

#### F3. User List updates
- Add `username` column to list
- Username searchable in search bar

#### F4. User Edit updates
- Show `username` field (read-only)

---

### G. Flutter App — Login Screen Change

**Current:** Tabbed login (Student tab: student_number + password, Teacher tab: email + password)

**New:** Single login screen with one input field

```dart
Future<void> _login(String input, String password) async {
  final email = input.contains('@') ? input : '$input@owlio.local';
  await supabase.auth.signInWithPassword(email: email, password: password);
}
```

- Input label: "Username or Email"
- Input trimmed before processing (prevents `mesyil1@` edge case)
- Remove student/teacher tabs
- Remove student_number references from login flow
- `student_number` field stays in profiles table (display-only, not used for auth)

**Code cleanup:** Remove `SignInWithStudentNumberUseCase`, `AuthRepository.signInWithStudentNumber()`, and related code in `supabase_auth_repository.dart` — no longer needed.

---

### H. Class Auto-Creation

When a class name from CSV doesn't exist for the selected school:

- Edge Function upserts class:
  ```sql
  INSERT INTO classes (school_id, name)
  VALUES ($1, $2)
  ON CONFLICT (school_id, name) WHERE academic_year IS NULL
  DO NOTHING
  RETURNING id;
  ```
  If `RETURNING` is empty (conflict), follow up with `SELECT id FROM classes WHERE school_id = $1 AND name = $2 AND academic_year IS NULL`
- No additional admin action needed
- Tekli oluşturmada dropdown includes "Yeni sınıf ekle" option with text input

---

### I. Password Reset

Existing `reset-student-password` Edge Function continues to work:
- Admin triggers password reset from user edit screen
- New password generated in same format (word + digits)
- Admin sees new password, communicates to student

No changes needed to this Edge Function.

---

## Out of Scope

- Student self-service password change (students cannot change username or password)
- Email-based password recovery for students (no real email)
- Teacher bulk creation via CSV
- Username change by admin (username is permanent once created)

---

## Migration Strategy

1. Deploy DB migration (add `username` column + `generate_username()` function + `safe_profiles` view update)
2. Run existing student migration — generate usernames in `profiles` (D3)
3. Deploy `bulk-create-students` Edge Function
4. Deploy admin panel changes (new creation screen, remove old import)
5. **Atomic deploy (together):**
   a. Run existing student auth email migration (D4) — updates `auth.users.email` to `username@owlio.local`
   b. Deploy Flutter app login change
6. Communicate to existing students: "Your new username is X" (admin can see in panel)

**Steps 5a and 5b MUST be deployed together.** After 5a, old email login breaks. After 5b, new username login works. If there's a gap, students can't log in.

Steps 1-4 are safe to deploy incrementally — they don't break existing login.
