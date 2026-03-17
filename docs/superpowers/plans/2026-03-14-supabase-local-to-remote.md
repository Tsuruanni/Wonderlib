# Supabase Local → Remote Migration Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate Supabase backend from local Docker to remote cloud while keeping local Flutter development workflow intact.

**Architecture:** The Flutter apps (main + admin) will continue running locally via `flutter run`, but will connect to remote Supabase (cloud PostgreSQL, Auth, Edge Functions) instead of local Docker. No app deployment needed — only backend migration.

**Tech Stack:** Supabase CLI v2.67.1+, PostgreSQL 17, 6 Deno Edge Functions, Flutter + Riverpod

---

## Pre-Migration Summary

| Item | Count | Notes |
|------|-------|-------|
| Migrations | 59 | 20260131 → 20260220 |
| Edge Functions | 6 | award-xp, check-streak, extract-vocabulary, generate-audio-sync, generate-chapter-audio, reset-student-password |
| Storage Buckets | 0 | App does not use Supabase Storage |
| Seed Data | 2,505 lines | 16 badges, 40+ vocabulary words, 25 test users (all password: `Test1234`), 1 school, 3 classes |
| Apps connecting | 2 | Main app (`.env`) + Admin panel (`owlio_admin/.env`) |
| Edge Function Secrets (manual) | 3 | `SUPABASE_ANON_KEY`, `GEMINI_API_KEY`, `FAL_KEY` |

> **Note:** `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are auto-injected by Supabase hosted platform into Edge Functions. Only 3 secrets need manual setting.

## Test Users (from seed.sql)

| Email | Role | Password | Purpose |
|-------|------|----------|---------|
| `fresh@demo.com` | student | Test1234 | Fresh user, 0 XP |
| `active@demo.com` | student | Test1234 | Mid-progress, 500 XP |
| `advanced@demo.com` | student | Test1234 | Advanced, XP testing |
| `teacher@demo.com` | teacher | Test1234 | Teacher dashboard |
| `admin@demo.com` | admin | Test1234 | Admin panel access |
| + 20 leaderboard students | student | Test1234 | Leaderboard testing |

---

## Chunk 1: Preparation & Validation

### Task 1: Update Supabase CLI

**Why:** Current version is v2.67.1, latest is v2.78.1. Updating prevents compatibility issues with remote operations.

**Files:** None (system tool)

- [ ] **Step 1: Update Supabase CLI**

```bash
brew upgrade supabase
```

- [ ] **Step 2: Verify version**

```bash
supabase --version
```

Expected: `2.78.x` or higher

---

### Task 2: Validate Local Migrations

**Why:** Before pushing to remote, we must confirm all 59 migrations apply cleanly from scratch. If they fail locally, they'll fail remotely too — and remote failures are harder to fix.

**Files:** `supabase/migrations/*.sql`, `supabase/seed.sql`

- [ ] **Step 1: Ensure local Supabase is running**

```bash
supabase start
```

Expected: All services start (db, auth, api, studio, etc.)

- [ ] **Step 2: Reset local database (applies all migrations + seed)**

```bash
supabase db reset
```

Expected: All 59 migrations apply successfully, seed data loads. Output should show each migration name with no errors.

- [ ] **Step 3: Verify tables exist**

Open Supabase Studio at http://127.0.0.1:54323 and confirm:
- Tables visible in Table Editor (books, chapters, profiles, etc.)
- Seed data present: `badges` table → 16 rows
- `vocabulary_words` table → 40+ rows
- `auth.users` → 25 users (fresh@demo.com, active@demo.com, etc.)

- [ ] **Step 4: Quick smoke test — run main app against local**

```bash
cd /Users/wonderelt/Desktop/Owlio
flutter run -d chrome
```

Expected: App loads, login screen appears. Login with `fresh@demo.com` / `Test1234` → home screen loads.

> **CHECKPOINT:** If `supabase db reset` fails on ANY migration, STOP. Fix the migration before proceeding. Do NOT push broken migrations to remote.

---

### Task 3: Verify Remote Supabase Project

**Why:** We need to confirm the remote project exists, is on the correct PostgreSQL version, and is accessible.

- [ ] **Step 1: Login to Supabase CLI**

```bash
supabase login
```

Expected: Browser opens, you authenticate, CLI confirms login.

- [ ] **Step 2: List your projects**

```bash
supabase projects list
```

Expected: Shows your projects. The Owlio project ref appears to be `bxfdbmnedldhzuzsyghs` (from existing `.env` comments).

If you need to create a new project:
```bash
supabase projects create "Owlio" --org-id <YOUR_ORG_ID> --db-password <SECURE_PASSWORD> --region eu-central-1
```

> **Important:** Choose `eu-central-1` (Frankfurt) — closest region to Turkey.

- [ ] **Step 3: Check remote PostgreSQL version**

Go to Supabase Dashboard → Settings → Infrastructure → Database version.

Expected: PostgreSQL **17.x**. Must match local `config.toml` `major_version = 17`. If remote is different, contact Supabase support or create a new project with the correct version.

- [ ] **Step 4: Confirm you have all 4 credentials**

From Dashboard → Settings → API:

| Credential | Where | Example |
|------------|-------|---------|
| Project URL | API Settings | `https://bxfdbmnedldhzuzsyghs.supabase.co` |
| anon public key | API Settings | `eyJ...` |
| service_role key | API Settings | `eyJ...` (KEEP SECRET) |
| Project ref | General Settings | `bxfdbmnedldhzuzsyghs` |

- [ ] **Step 5: Save the database password somewhere safe**

You'll need it for `supabase link` and direct `psql` access. Store it in a password manager.

> **CHECKPOINT:** You have: project ref, URL, anon key, service role key, and DB password. All needed for remaining tasks.

---

## Chunk 2: Security Fix + Remote Database Setup

### Task 4: Remove Hardcoded API Keys from Edge Functions

**Why:** The `generate-audio-sync` and `generate-chapter-audio` functions have a hardcoded FAL_KEY fallback. This key must be removed BEFORE deploying to remote, as deployed edge function code is accessible in the project.

**Files:**
- Modify: `supabase/functions/generate-audio-sync/index.ts` (line 51)
- Modify: `supabase/functions/generate-chapter-audio/index.ts` (line 108)

- [ ] **Step 1: Fix generate-audio-sync**

In `supabase/functions/generate-audio-sync/index.ts`, find line 51:

```typescript
const FAL_KEY = Deno.env.get("FAL_KEY") || "482f71ee-7bbb-4966-a021-e67f0ec3a4a4:173a09396d98fd54b75c8666f7698b84";
```

Replace with:

```typescript
const FAL_KEY = Deno.env.get("FAL_KEY");
if (!FAL_KEY) {
  return new Response(JSON.stringify({ error: "FAL_KEY not configured" }), {
    status: 500,
    headers: { "Content-Type": "application/json" },
  });
}
```

- [ ] **Step 2: Fix generate-chapter-audio**

In `supabase/functions/generate-chapter-audio/index.ts`, find line 108:

```typescript
const FAL_KEY = Deno.env.get("FAL_KEY") || "482f71ee-7bbb-4966-a021-e67f0ec3a4a4:173a09396d98fd54b75c8666f7698b84";
```

Replace with the same pattern:

```typescript
const FAL_KEY = Deno.env.get("FAL_KEY");
if (!FAL_KEY) {
  return new Response(JSON.stringify({ error: "FAL_KEY not configured" }), {
    status: 500,
    headers: { "Content-Type": "application/json" },
  });
}
```

- [ ] **Step 3: Commit the security fix**

```bash
git add supabase/functions/generate-audio-sync/index.ts supabase/functions/generate-chapter-audio/index.ts
git commit -m "security: remove hardcoded FAL_KEY fallback from edge functions"
```

---

### Task 5: Link Project & Push Migrations

**Why:** This is the core step — applying all 59 migrations to the remote database. This creates all tables, RLS policies, functions, and triggers.

- [ ] **Step 1: Link local project to remote**

```bash
cd /Users/wonderelt/Desktop/Owlio
supabase link --project-ref bxfdbmnedldhzuzsyghs
```

When prompted, enter the database password.

Expected: `Finished supabase link.`

- [ ] **Step 2: Dry-run push (preview only)**

```bash
supabase db push --dry-run
```

Expected: Lists all 59 migrations that WILL be applied. No errors. This does NOT modify the remote database.

- [ ] **Step 3: Push migrations to remote**

```bash
supabase db push
```

Expected: All 59 migrations apply one by one. Each line shows the migration name. No errors.

> **If a migration fails:** Note the error. Unlike local `db reset`, remote `db push` does NOT automatically roll back partial migrations. If a migration partially executed (e.g., first 3 of 5 statements succeeded), you may need to manually clean up via Dashboard SQL Editor before re-running. Check the error, fix the SQL, then `supabase db push` again.

- [ ] **Step 4: Verify migration status**

```bash
supabase migration list
```

Expected: All 59 migrations show as applied on the remote.

- [ ] **Step 5: Verify tables via Dashboard**

Go to Supabase Dashboard → Table Editor:
- Confirm tables exist (books, chapters, profiles, vocabulary_words, etc.)
- Confirm they're empty (no data yet — seed doesn't run on `db push`)

> **CHECKPOINT:** Remote database has all tables, RLS policies, and functions. Tables are empty.

---

### Task 6: Load Seed Data to Remote

**Why:** The app needs badges, vocabulary words, test users, a school, and classes to function. The seed.sql creates all of these including 25 auth users with the `handle_new_user()` trigger auto-creating profile rows.

> **Important:** The seed.sql directly inserts into `auth.users` which triggers `handle_new_user()` → auto-creates profiles. Then it UPDATEs those profiles with full data (school, class, XP, etc.). This works on local — but on remote, the `auth.users` table schema might have additional columns in newer Supabase versions. If the INSERT fails, you'll need to adapt the seed.

- [ ] **Step 1: Load seed data via Dashboard SQL Editor**

Go to Supabase Dashboard → SQL Editor → New Query.

Copy-paste the **entire** contents of `supabase/seed.sql` (2,505 lines) and click **Run**.

Alternative via CLI:
```bash
# Get connection string from Dashboard → Settings → Database → Connection string → URI
psql "postgresql://postgres.[project-ref]:[password]@aws-0-[region].pooler.supabase.com:6543/postgres" -f supabase/seed.sql
```

Expected: No errors. All data inserted.

- [ ] **Step 2: Verify seed data**

In Dashboard → Table Editor:
- `badges` table → **16 rows**
- `vocabulary_words` table → **40+ rows**
- `profiles` table → **25 rows** (created by trigger)
- `schools` table → **1 row** (DEMO school)
- `classes` table → **3 rows** (5-A, 5-B, 6-A)

In Dashboard → Authentication → Users:
- **25 users** listed (fresh@demo.com, active@demo.com, teacher@demo.com, admin@demo.com, etc.)

- [ ] **Step 3: Quick login test via Dashboard**

In Dashboard → SQL Editor, run:
```sql
SELECT id, email, role FROM profiles LIMIT 5;
```

Expected: Shows users with correct roles (student, teacher, admin).

> **CHECKPOINT:** Remote database is fully set up with schema + seed data + test users.

---

## Chunk 3: Edge Functions Deployment

### Task 7: Deploy Edge Functions

**Why:** 6 Edge Functions handle server-side logic. Without them, XP awards, streaks, audio generation, vocabulary extraction, and password reset won't work.

- [ ] **Step 1: Deploy all Edge Functions**

```bash
supabase functions deploy award-xp --project-ref bxfdbmnedldhzuzsyghs
supabase functions deploy check-streak --project-ref bxfdbmnedldhzuzsyghs
supabase functions deploy extract-vocabulary --project-ref bxfdbmnedldhzuzsyghs
supabase functions deploy generate-audio-sync --project-ref bxfdbmnedldhzuzsyghs
supabase functions deploy generate-chapter-audio --project-ref bxfdbmnedldhzuzsyghs
supabase functions deploy reset-student-password --project-ref bxfdbmnedldhzuzsyghs
```

Expected: Each function shows `Deployed function <name>`.

- [ ] **Step 2: Verify deployment**

```bash
supabase functions list --project-ref bxfdbmnedldhzuzsyghs
```

Expected: All 6 functions listed with status `Active`.

---

### Task 8: Configure Edge Function Secrets

**Why:** Edge Functions need environment variables for external API access. `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are auto-injected by hosted Supabase — only 3 secrets need manual setting.

| Secret | Used By | Source |
|--------|---------|--------|
| `SUPABASE_ANON_KEY` | reset-student-password | Dashboard → Settings → API |
| `GEMINI_API_KEY` | extract-vocabulary | [Google AI Studio](https://aistudio.google.com/apikey) |
| `FAL_KEY` | generate-audio-sync, generate-chapter-audio | [Fal.ai dashboard](https://fal.ai/dashboard) |

- [ ] **Step 1: Set required secret**

```bash
supabase secrets set SUPABASE_ANON_KEY=<your-anon-key> --project-ref bxfdbmnedldhzuzsyghs
```

- [ ] **Step 2: Set external API secrets (optional — skip if you don't have keys yet)**

```bash
supabase secrets set GEMINI_API_KEY=<your-gemini-key> --project-ref bxfdbmnedldhzuzsyghs
supabase secrets set FAL_KEY=<your-fal-key> --project-ref bxfdbmnedldhzuzsyghs
```

> **Note:** If you skip these, `extract-vocabulary` and audio generation functions won't work. Everything else (XP, streaks, login, reading, badges) will function fine. Set them when ready.

- [ ] **Step 3: Verify secrets**

```bash
supabase secrets list --project-ref bxfdbmnedldhzuzsyghs
```

Expected: Set secrets listed (values are hidden). You should see at minimum: `SUPABASE_ANON_KEY`.

> **CHECKPOINT:** All 6 Edge Functions deployed. Core functions (award-xp, check-streak, reset-student-password) fully operational.

---

## Chunk 4: App Configuration & Testing

### Task 9: Update Main App .env

**Why:** The main Flutter app currently points to local Docker. We need to switch to the remote URL. The `.env` file already has remote credentials commented out — we just need to swap them.

**Files:**
- Modify: `/Users/wonderelt/Desktop/Owlio/.env`

- [ ] **Step 1: Backup current .env**

```bash
cp /Users/wonderelt/Desktop/Owlio/.env /Users/wonderelt/Desktop/Owlio/.env.local.backup
```

- [ ] **Step 2: Update .env — swap local for remote**

In `/Users/wonderelt/Desktop/Owlio/.env`, change the Supabase section from:

```bash
# Remote credentials (commented for later)
# SUPABASE_URL=https://bxfdbmnedldhzuzsyghs.supabase.co
# SUPABASE_ANON_KEY=sb_publishable_RGDr6SB2lf7ABQIjWqd04Q_3mxi8-Ze
# SUPABASE_SERVICE_ROLE_KEY=REDACTED_SERVICE_ROLE_KEY_1
# SUPABASE_PROJECT_REF=bxfdbmnedldhzuzsyghs

# Local Supabase (Docker)
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH
SUPABASE_SERVICE_ROLE_KEY=REDACTED_SERVICE_ROLE_KEY_2
SUPABASE_PROJECT_REF=local
```

To:

```bash
# Local Supabase (Docker) — backed up in .env.local.backup
# SUPABASE_URL=http://127.0.0.1:54321
# SUPABASE_ANON_KEY=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH
# SUPABASE_SERVICE_ROLE_KEY=REDACTED_SERVICE_ROLE_KEY_2
# SUPABASE_PROJECT_REF=local

# Remote Supabase (Cloud)
SUPABASE_URL=https://bxfdbmnedldhzuzsyghs.supabase.co
SUPABASE_ANON_KEY=<your-actual-remote-anon-key-from-dashboard>
SUPABASE_SERVICE_ROLE_KEY=<your-actual-remote-service-role-key-from-dashboard>
SUPABASE_PROJECT_REF=bxfdbmnedldhzuzsyghs
```

> **Important:** The anon key and service role key in the commented lines may be outdated. Always copy fresh keys from Dashboard → Settings → API.

- [ ] **Step 3: Verify EnvConstants won't interfere**

The `EnvConstants.supabaseUrl` getter does localhost→IP translation only when URL contains `127.0.0.1` or `localhost`. Since remote URL is `https://xxx.supabase.co`, no translation triggers. No code change needed.

---

### Task 10: Update Admin Panel .env

**Why:** The admin panel also connects to the same Supabase instance.

**Files:**
- Modify: `/Users/wonderelt/Desktop/Owlio/owlio_admin/.env`

- [ ] **Step 1: Backup current admin .env**

```bash
cp /Users/wonderelt/Desktop/Owlio/owlio_admin/.env /Users/wonderelt/Desktop/Owlio/owlio_admin/.env.local.backup
```

- [ ] **Step 2: Update admin .env with remote credentials**

Change `SUPABASE_URL` and `SUPABASE_ANON_KEY` to match the main app:

```bash
SUPABASE_URL=https://bxfdbmnedldhzuzsyghs.supabase.co
SUPABASE_ANON_KEY=<your-actual-remote-anon-key-from-dashboard>
```

---

### Task 11: Test Main App Against Remote

**Why:** This is the critical validation — confirming the app works with the remote backend end-to-end.

- [ ] **Step 1: Run main app**

```bash
cd /Users/wonderelt/Desktop/Owlio
flutter run -d chrome
```

- [ ] **Step 2: Test student login**

Login with: `fresh@demo.com` / `Test1234`

Expected: Login succeeds, home screen loads.

**If login fails, check these in order:**
1. Browser DevTools console → look for network errors
2. Is the URL correct? Check `.env` → `SUPABASE_URL`
3. RLS policy blocking profile fetch? → Dashboard → SQL Editor → `SELECT * FROM profiles WHERE email = 'fresh@demo.com';`
4. Profile missing school_id? → Check if seed data loaded correctly

- [ ] **Step 3: Test core features**

| Feature | What to Check | Expected |
|---------|---------------|----------|
| Library | Books list loads | Empty list (no books in seed) |
| Badges | Badge screen loads | 16 seeded badges visible |
| Vocabulary | Word list loads | Seeded words visible |
| Profile | User profile loads | Name: "Fresh Student", XP: 0 |

- [ ] **Step 4: Test admin panel**

```bash
cd /Users/wonderelt/Desktop/Owlio/owlio_admin
flutter run -d chrome
```

Login with: **`admin@demo.com`** / **`Test1234`**

> **Important:** The admin panel requires `admin` or `head` role (checked by `isAuthorizedAdminProvider`). `teacher@demo.com` will NOT have admin access. Use `admin@demo.com`.

Expected: Dashboard loads, tables visible in admin interface.

- [ ] **Step 5: Test with active student (has data)**

Login to main app with: `active@demo.com` / `Test1234`

Expected: XP shows as 500, some progress data visible.

> **CHECKPOINT:** Both apps connect to remote Supabase. Login works, basic features load. If something fails, check Troubleshooting section below.

---

## Chunk 5: Post-Migration Cleanup

### Task 12: Update .gitignore

**Why:** The backup files created during migration (`.env.local.backup`) are not covered by existing `.gitignore` patterns.

**Files:**
- Modify: `/Users/wonderelt/Desktop/Owlio/.gitignore`

- [ ] **Step 1: Add backup patterns to .gitignore**

Add these lines to `.gitignore`:

```
.env.local.backup
.env.remote.reference
```

> **Note:** Existing `.gitignore` has `.env`, `.env.local`, `.env.*.local`, and `.env.production`. The `.env.local.backup` does NOT match `.env.*.local` (because `local.backup` contains a dot that breaks the glob).

- [ ] **Step 2: Commit .gitignore update**

```bash
git add .gitignore
git commit -m "chore: add env backup patterns to gitignore"
```

---

### Task 13: Final Verification Checklist

- [ ] **Step 1: Run through this checklist**

| Check | Command / Action | Expected |
|-------|-----------------|----------|
| Migrations applied | `supabase migration list` | All 59 show as applied |
| Edge Functions deployed | `supabase functions list --project-ref <REF>` | 6 functions, all Active |
| Secrets configured | `supabase secrets list --project-ref <REF>` | At minimum: SUPABASE_ANON_KEY |
| Main app .env | Check `SUPABASE_URL` starts with `https://` | Not `http://127.0.0.1` |
| Admin panel .env | Check `SUPABASE_URL` starts with `https://` | Not `http://127.0.0.1` |
| Student login | `fresh@demo.com` / `Test1234` | Home screen loads |
| Admin login | `admin@demo.com` / `Test1234` | Admin dashboard loads |
| Seed data | Check badges table in Dashboard | 16 rows |
| Local backup exists | `ls .env.local.backup` | File exists |

> **CHECKPOINT:** Migration complete. You're now running on remote Supabase.

---

## Chunk 6: Ongoing Development Workflow (Reference)

This is NOT a task to execute — it's your daily reference after migration.

### When You Change Database Schema

```bash
# 1. Create migration file
touch supabase/migrations/YYYYMMDD000XXX_description.sql

# 2. Write the SQL

# 3. Test locally (optional — requires `supabase start` + temporarily switching .env back to local)
supabase db reset

# 4. Push to remote
supabase db push --dry-run    # Preview first (ALWAYS do this)
supabase db push              # Apply
```

### When You Change Edge Functions

```bash
# 1. Edit the function code

# 2. Test locally (requires `supabase start`)
supabase functions serve <function-name>

# 3. Deploy to remote
supabase functions deploy <function-name> --project-ref bxfdbmnedldhzuzsyghs
```

### When You Add New Edge Function Secrets

```bash
supabase secrets set NEW_SECRET=value --project-ref bxfdbmnedldhzuzsyghs
```

### When You Only Change Flutter Code

No Supabase commands needed. Just `flutter run`.

### Useful Commands

```bash
supabase migration list                                          # Which migrations are applied?
supabase functions list --project-ref bxfdbmnedldhzuzsyghs       # Which functions are deployed?
supabase secrets list --project-ref bxfdbmnedldhzuzsyghs         # Which secrets are set?
supabase db push --dry-run                                       # Preview pending migrations
supabase db dump -f backup.sql --project-ref bxfdbmnedldhzuzsyghs # Backup remote DB
```

### Going Back to Local Temporarily

```bash
# Restore backup
cp .env.local.backup .env
supabase start
# Now running against local Docker again
```

---

## Troubleshooting

### "Permission denied" or empty data after login
→ RLS policy issue. Check that the user has a `profiles` row with correct `school_id`. Run in Dashboard SQL Editor:
```sql
SELECT id, email, role, school_id FROM profiles WHERE email = 'fresh@demo.com';
```

### Edge Function returns 500
→ Check logs: Dashboard → Edge Functions → select function → Logs. Usually a missing secret.

### "relation does not exist" error
→ A migration didn't apply. Run `supabase migration list` to see which ones are applied.

### App loads but shows no data
→ Seed data not loaded. Run `seed.sql` in Dashboard SQL Editor.

### Login works but home screen crashes
→ Check browser DevTools console. Common causes:
- Profile missing required fields (school_id, class_id)
- RLS blocking data access for the user's school

### Seed SQL fails on remote with auth.users error
→ Remote Supabase may have additional columns in `auth.users` that don't exist in the seed. Solutions:
- Try running via `psql` instead of SQL Editor
- Check if remote auth schema differs: `SELECT column_name FROM information_schema.columns WHERE table_schema = 'auth' AND table_name = 'users';`
- If columns differ, add `DEFAULT` values for missing columns in the INSERT

### `supabase db push` shows "already applied"
→ That's fine. It skips already-applied migrations. Only new ones will be pushed.

### Admin panel says "unauthorized"
→ You're logging in with a non-admin user. Use `admin@demo.com` / `Test1234` (role: admin). Teacher accounts don't have admin panel access.
