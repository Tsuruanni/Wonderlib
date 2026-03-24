# Username Auth + Bulk Student Creation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace student_number login with username-based auth, add bulk student creation to admin panel, remove old CSV import.

**Architecture:** Synthetic email pattern (`username@owlio.local`) for Supabase Auth. New Edge Function (`bulk-create-students`) handles user creation with service_role key. Admin panel gets a new user creation screen (tekli + toplu CSV). Flutter app login screen unified to single input.

**Tech Stack:** PostgreSQL (migrations), Deno (Edge Function), Flutter/Riverpod (admin panel + main app), Supabase Auth Admin API

**Spec:** `docs/superpowers/specs/2026-03-24-username-auth-bulk-create-design.md`

---

## File Map

### Database (Supabase Migrations)
- **Create:** `supabase/migrations/20260325000001_username_auth.sql` — username column, generate_username function, class unique index, safe_profiles view update, existing student migration

### Edge Function
- **Create:** `supabase/functions/bulk-create-students/index.ts` — bulk user creation with auth.admin API

### Admin Panel (owlio_admin)
- **Create:** `owlio_admin/lib/features/users/screens/user_create_screen.dart` — new user creation screen (tekli + toplu CSV)
- **Modify:** `owlio_admin/lib/core/router.dart` — replace `/users/import` route with `/users/create`
- **Modify:** `owlio_admin/lib/features/users/screens/user_list_screen.dart` — update CSV import button → "Kullanıcı Oluştur", add username column
- **Modify:** `owlio_admin/lib/features/users/screens/user_edit_screen.dart` — show username (read-only), update stale info banner, remove student_number edit
- **Delete:** `owlio_admin/lib/features/users/screens/user_import_screen.dart` — old CSV import

### Flutter App (main app)
- **Modify:** `lib/domain/entities/user.dart` — add `username` field
- **Modify:** `lib/data/models/user/user_model.dart` — add `username` to fromJson/toJson/toEntity
- **Modify:** `lib/presentation/screens/auth/login_screen.dart` — unified login (username or email), update dev shortcuts
- **Modify:** `lib/presentation/providers/auth_provider.dart` — remove signInWithStudentNumber from AuthController
- **Modify:** `lib/domain/repositories/auth_repository.dart` — remove signInWithStudentNumber method
- **Modify:** `lib/data/repositories/supabase/supabase_auth_repository.dart` — remove signInWithStudentNumber implementation
- **Delete:** `lib/domain/usecases/auth/sign_in_with_student_number_usecase.dart` — dead code
- **Modify:** `lib/presentation/providers/usecase_providers.dart` — remove signInWithStudentNumberUseCaseProvider (if exists)

### Migration Script (one-time)
- **Create:** `supabase/functions/migrate-student-emails/index.ts` — one-time script to update existing students' auth.users.email to username@owlio.local

---

## Task 1: Database Migration — Username Column + generate_username Function

**Files:**
- Create: `supabase/migrations/20260325000001_username_auth.sql`

- [ ] **Step 1: Create migration file with username column and indexes**

```sql
-- =============================================================
-- Migration: Username Auth Support
-- =============================================================

-- 1. Add username column to profiles
ALTER TABLE profiles ADD COLUMN username VARCHAR(20);

-- Unique partial index (only students have usernames, NULL for teachers/admins)
CREATE UNIQUE INDEX idx_profiles_username ON profiles(username) WHERE username IS NOT NULL;

-- Prevent duplicate classes with NULL academic_year (for class auto-creation)
CREATE UNIQUE INDEX idx_classes_unique_null_year ON classes(school_id, name) WHERE academic_year IS NULL;
```

- [ ] **Step 2: Add generate_username function to the same migration**

```sql
-- 2. Username generation function
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

  -- Strip non-alphanumeric chars (handles periods, hyphens, etc.)
  v_base := regexp_replace(v_base, '[^a-z0-9]', '', 'g');

  -- Fallback if base is empty after sanitization
  IF v_base = '' THEN
    v_base := 'user';
  END IF;

  -- Advisory lock to prevent race conditions on same base
  PERFORM pg_advisory_xact_lock(hashtext(v_base));

  -- Find highest existing number for this base
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

- [ ] **Step 3: Add existing student username migration to the same file**

```sql
-- 3. Generate usernames for all existing students
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

- [ ] **Step 4: Add safe_profiles view update to the same file**

The existing view is defined in migration `20260316000002_restrict_profiles_visibility.sql`. Replace it to include `username`:

```sql
-- 4. Update safe_profiles view to include username
CREATE OR REPLACE VIEW safe_profiles AS
SELECT
    id,
    school_id,
    class_id,
    role,
    first_name,
    last_name,
    avatar_url,
    username,
    xp,
    level,
    current_streak,
    longest_streak,
    league_tier,
    last_activity_date,
    created_at
    -- Deliberately omits: email, student_number, coins, settings
FROM profiles;

GRANT SELECT ON safe_profiles TO authenticated;

COMMENT ON VIEW safe_profiles IS 'Student-safe profile view. Omits email, student_number, coins, settings. Includes username for public display.';
```

- [ ] **Step 5: Preview migration**

Run: `cd /Users/wonderelt/Desktop/Owlio && supabase db push --dry-run`
Expected: Shows the new migration will be applied

- [ ] **Step 6: Push migration to remote**

Run: `cd /Users/wonderelt/Desktop/Owlio && supabase db push`
Expected: Migration applied successfully

- [ ] **Step 7: Verify migration**

Run from Supabase SQL Editor or via curl:
```sql
SELECT generate_username('Mesut', 'Yılmaz');
-- Expected: mesyil1

SELECT generate_username('Mesut', 'Yıldırım');
-- Expected: mesyil1 (first time) or mesyil2 (if mesyil1 exists)

SELECT username FROM profiles WHERE role = 'student' AND username IS NOT NULL LIMIT 5;
-- Expected: existing students now have usernames
```

- [ ] **Step 8: Commit**

```bash
git add supabase/migrations/20260325000001_username_auth.sql
git commit -m "feat(db): add username column, generate_username function, migrate existing students"
```

---

## Task 2: Edge Function — bulk-create-students

**Files:**
- Create: `supabase/functions/bulk-create-students/index.ts`

- [ ] **Step 1: Create Edge Function directory and file**

Run: `mkdir -p /Users/wonderelt/Desktop/Owlio/supabase/functions/bulk-create-students`

- [ ] **Step 2: Write the Edge Function**

Create `/Users/wonderelt/Desktop/Owlio/supabase/functions/bulk-create-students/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// --- Interfaces ---

interface StudentInput {
  first_name: string;
  last_name: string;
  class_name: string;
}

interface TeacherInput {
  first_name: string;
  last_name: string;
  email: string;
}

interface RequestBody {
  school_id: string;
  students?: StudentInput[];
  teachers?: TeacherInput[];
}

interface CreatedUser {
  first_name: string;
  last_name: string;
  username?: string;
  email?: string;
  password: string;
  class_name?: string;
  role: string;
}

interface ErrorEntry {
  first_name: string;
  last_name: string;
  error: string;
}

// --- Password Generation ---

const WORDS = [
  "owl", "fox", "sun", "cat", "dog", "bee", "sky", "ice", "red", "pen",
  "cup", "hat", "map", "box", "key", "gem", "fin", "pod", "ray", "dew",
  "elm", "oak", "fig", "ant", "bat", "elk", "cod", "ram", "yak", "emu",
];

function generatePassword(): string {
  const word = WORDS[Math.floor(Math.random() * WORDS.length)];
  const num = Math.floor(Math.random() * 900) + 100; // 100-999 (always 3 digits)
  return `${word}${num}`;
}

// --- CORS ---

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// --- Main Handler ---

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Parse request
    const body: RequestBody = await req.json();
    const { school_id, students = [], teachers = [] } = body;

    if (!school_id) {
      return new Response(
        JSON.stringify({ error: "school_id is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (students.length === 0 && teachers.length === 0) {
      return new Response(
        JSON.stringify({ error: "At least one student or teacher is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (students.length > 200) {
      return new Response(
        JSON.stringify({ error: "Maximum 200 students per request" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Create admin client (service role)
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // Verify caller authorization
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const token = authHeader.replace("Bearer ", "");
    const supabaseUser = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: `Bearer ${token}` } } }
    );

    const { data: { user: caller }, error: authError } = await supabaseUser.auth.getUser();
    if (authError || !caller) {
      return new Response(
        JSON.stringify({ error: "Invalid authentication" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check caller role
    const { data: callerProfile } = await supabaseAdmin
      .from("profiles")
      .select("role")
      .eq("id", caller.id)
      .single();

    if (!callerProfile || !["admin", "head"].includes(callerProfile.role)) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: admin or head role required" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify school exists
    const { data: school } = await supabaseAdmin
      .from("schools")
      .select("id")
      .eq("id", school_id)
      .single();

    if (!school) {
      return new Response(
        JSON.stringify({ error: `School not found: ${school_id}` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const created: CreatedUser[] = [];
    const errors: ErrorEntry[] = [];

    // Class cache to avoid repeated lookups
    const classCache = new Map<string, string>();

    // --- Helper: get or create class (SELECT-first, INSERT-if-not-found, SELECT-again-on-conflict) ---
    async function getOrCreateClass(className: string): Promise<string> {
      const cached = classCache.get(className);
      if (cached) return cached;

      // Try to find existing class first
      const { data: existing } = await supabaseAdmin
        .from("classes")
        .select("id")
        .eq("school_id", school_id)
        .eq("name", className)
        .is("academic_year", null)
        .single();

      if (existing) {
        classCache.set(className, existing.id);
        return existing.id;
      }

      // Not found — try to insert
      try {
        const { data: inserted, error } = await supabaseAdmin
          .from("classes")
          .insert({ school_id, name: className })
          .select("id")
          .single();

        if (inserted && !error) {
          classCache.set(className, inserted.id);
          return inserted.id;
        }
      } catch {
        // Unique constraint conflict from concurrent insert — fall through to re-fetch
      }

      // Re-fetch (handles race condition where concurrent request created it)
      const { data: refetched } = await supabaseAdmin
        .from("classes")
        .select("id")
        .eq("school_id", school_id)
        .eq("name", className)
        .is("academic_year", null)
        .single();

      if (refetched) {
        classCache.set(className, refetched.id);
        return refetched.id;
      }

      throw new Error(`Could not find or create class: ${className}`);
    }

    // --- Process Students ---
    for (const student of students) {
      try {
        if (!student.first_name?.trim() || !student.last_name?.trim()) {
          errors.push({
            first_name: student.first_name || "",
            last_name: student.last_name || "",
            error: "first_name and last_name are required",
          });
          continue;
        }

        if (!student.class_name?.trim()) {
          errors.push({
            first_name: student.first_name,
            last_name: student.last_name,
            error: "class_name is required",
          });
          continue;
        }

        const firstName = student.first_name.trim();
        const lastName = student.last_name.trim();
        const className = student.class_name.trim();

        // Get or create class
        const classId = await getOrCreateClass(className);

        // Duplicate detection
        const { data: existing } = await supabaseAdmin
          .from("profiles")
          .select("id")
          .eq("first_name", firstName)
          .eq("last_name", lastName)
          .eq("school_id", school_id)
          .eq("class_id", classId)
          .limit(1);

        if (existing && existing.length > 0) {
          errors.push({
            first_name: firstName,
            last_name: lastName,
            error: `Duplicate: student already exists in class ${className}`,
          });
          continue;
        }

        // Generate username via DB function (inside transaction for advisory lock)
        const { data: usernameResult, error: usernameError } = await supabaseAdmin
          .rpc("generate_username", {
            p_first_name: firstName,
            p_last_name: lastName,
          });

        if (usernameError || !usernameResult) {
          errors.push({
            first_name: firstName,
            last_name: lastName,
            error: `Username generation failed: ${usernameError?.message || "unknown"}`,
          });
          continue;
        }

        const username = usernameResult as string;
        const password = generatePassword();
        const syntheticEmail = `${username}@owlio.local`;

        // Create auth user
        const { data: authData, error: createError } = await supabaseAdmin.auth.admin.createUser({
          email: syntheticEmail,
          password: password,
          email_confirm: true,
          user_metadata: {
            first_name: firstName,
            last_name: lastName,
            role: "student",
          },
        });

        if (createError || !authData.user) {
          errors.push({
            first_name: firstName,
            last_name: lastName,
            error: `Auth creation failed: ${createError?.message || "unknown"}`,
          });
          continue;
        }

        // Update profile with username (retry on unique violation — advisory lock is per-transaction
        // but RPC call has its own transaction, so a race is theoretically possible)
        let finalUsername = username;
        let updateSuccess = false;
        for (let attempt = 0; attempt < 3; attempt++) {
          const { error: updateError } = await supabaseAdmin
            .from("profiles")
            .update({
              username: finalUsername,
              school_id: school_id,
              class_id: classId,
              email: null, // Clear synthetic email from profiles
            })
            .eq("id", authData.user.id);

          if (!updateError) {
            updateSuccess = true;
            break;
          }

          // If unique violation on username, regenerate and retry
          if (updateError.code === "23505" && updateError.message.includes("username")) {
            const { data: retryUsername } = await supabaseAdmin
              .rpc("generate_username", { p_first_name: firstName, p_last_name: lastName });
            if (retryUsername) {
              finalUsername = retryUsername as string;
              // Also update the auth email to match new username
              await supabaseAdmin.auth.admin.updateUserById(authData.user.id, {
                email: `${finalUsername}@owlio.local`,
              });
            }
          } else {
            errors.push({
              first_name: firstName,
              last_name: lastName,
              error: `Profile update failed: ${updateError.message}`,
            });
            break;
          }
        }

        if (!updateSuccess) continue;

        // Use finalUsername (may differ from original if retried)
        const usedUsername = finalUsername;

        created.push({
          first_name: firstName,
          last_name: lastName,
          username: usedUsername,
          password: password,
          class_name: className,
          role: "student",
        });
      } catch (err) {
        errors.push({
          first_name: student.first_name || "",
          last_name: student.last_name || "",
          error: `Unexpected error: ${(err as Error).message}`,
        });
      }
    }

    // --- Process Teachers ---
    for (const teacher of teachers) {
      try {
        if (!teacher.first_name?.trim() || !teacher.last_name?.trim()) {
          errors.push({
            first_name: teacher.first_name || "",
            last_name: teacher.last_name || "",
            error: "first_name and last_name are required",
          });
          continue;
        }

        if (!teacher.email?.trim()) {
          errors.push({
            first_name: teacher.first_name,
            last_name: teacher.last_name,
            error: "email is required for teachers",
          });
          continue;
        }

        const firstName = teacher.first_name.trim();
        const lastName = teacher.last_name.trim();
        const email = teacher.email.trim().toLowerCase();
        const password = generatePassword();

        // Create auth user with real email
        const { data: authData, error: createError } = await supabaseAdmin.auth.admin.createUser({
          email: email,
          password: password,
          email_confirm: true,
          user_metadata: {
            first_name: firstName,
            last_name: lastName,
            role: "teacher",
          },
        });

        if (createError || !authData.user) {
          errors.push({
            first_name: firstName,
            last_name: lastName,
            error: `Auth creation failed: ${createError?.message || "unknown"}`,
          });
          continue;
        }

        // Update profile with school
        const { error: updateError } = await supabaseAdmin
          .from("profiles")
          .update({
            school_id: school_id,
          })
          .eq("id", authData.user.id);

        if (updateError) {
          errors.push({
            first_name: firstName,
            last_name: lastName,
            error: `Profile update failed: ${updateError.message}`,
          });
          continue;
        }

        created.push({
          first_name: firstName,
          last_name: lastName,
          email: email,
          password: password,
          role: "teacher",
        });
      } catch (err) {
        errors.push({
          first_name: teacher.first_name || "",
          last_name: teacher.last_name || "",
          error: `Unexpected error: ${(err as Error).message}`,
        });
      }
    }

    return new Response(
      JSON.stringify({ created, errors }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
```

- [ ] **Step 3: Deploy Edge Function**

Run: `cd /Users/wonderelt/Desktop/Owlio && supabase functions deploy bulk-create-students`
Expected: Function deployed successfully

- [ ] **Step 4: Test Edge Function via curl**

```bash
# Get admin JWT first by logging in
curl -X POST "https://wqkxjjakysuabjcotvim.supabase.co/auth/v1/token?grant_type=password" \
  -H "apikey: <ANON_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@demo.com", "password": "Test1234"}'

# Then call the function (use the access_token from above)
curl -X POST "https://wqkxjjakysuabjcotvim.supabase.co/functions/v1/bulk-create-students" \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "school_id": "<DEMO_SCHOOL_ID>",
    "students": [
      {"first_name": "Test", "last_name": "Öğrenci", "class_name": "Test-A"}
    ]
  }'
```

Expected: `{"created": [{"first_name": "Test", "last_name": "Öğrenci", "username": "tesogr1", "password": "fox047", ...}], "errors": []}`

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/bulk-create-students/index.ts
git commit -m "feat(edge): add bulk-create-students Edge Function"
```

---

## Task 3: Admin Panel — Remove Old CSV Import

**Files:**
- Delete: `owlio_admin/lib/features/users/screens/user_import_screen.dart`
- Modify: `owlio_admin/lib/core/router.dart` — remove `/users/import` route
- Modify: `owlio_admin/lib/features/users/screens/user_list_screen.dart` — remove CSV import button

- [ ] **Step 1: Remove import route from router**

In `/Users/wonderelt/Desktop/Owlio/owlio_admin/lib/core/router.dart`, find the route definition for `/users/import` (around lines 157-160):

```dart
GoRoute(
  path: 'import',
  builder: (context, state) => const UserImportScreen(),
),
```

Delete this entire route block. Also remove the `UserImportScreen` import at the top of the file.

- [ ] **Step 2: Remove CSV import button from user list screen**

In `/Users/wonderelt/Desktop/Owlio/owlio_admin/lib/features/users/screens/user_list_screen.dart`, find the CSV import button (around line 84) that navigates to `/users/import`. Replace it with a button that navigates to `/users/create` (will be created in next task):

Change the button text from "CSV İçe Aktar" to "Kullanıcı Oluştur" and the icon from `Icons.upload_file` to `Icons.person_add`. Update the route from `/users/import` to `/users/create`.

- [ ] **Step 3: Delete the old import screen file**

Run: `rm /Users/wonderelt/Desktop/Owlio/owlio_admin/lib/features/users/screens/user_import_screen.dart`

- [ ] **Step 4: Check if csv_import_dialog.dart is still used**

Run: `grep -r "CsvImportDialog" /Users/wonderelt/Desktop/Owlio/owlio_admin/lib/ --include="*.dart"`

If only used by the deleted `user_import_screen.dart` and vocabulary import, keep it (vocabulary still needs it). If only used by the deleted file, delete it too.

- [ ] **Step 5: Verify no broken imports**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/`
Expected: No errors related to missing imports

- [ ] **Step 6: Commit**

```bash
cd /Users/wonderelt/Desktop/Owlio
git add owlio_admin/lib/features/users/screens/user_import_screen.dart  # staged deletion
git add owlio_admin/lib/core/router.dart
git add owlio_admin/lib/features/users/screens/user_list_screen.dart
git commit -m "refactor(admin): remove old CSV user import screen"
```

---

## Task 4: Admin Panel — User Creation Screen

**Files:**
- Create: `owlio_admin/lib/features/users/screens/user_create_screen.dart`
- Modify: `owlio_admin/lib/core/router.dart` — add `/users/create` route

This is the largest task. The screen has:
- School dropdown (top, shared)
- Two tabs: Tekli (single) and Toplu CSV (bulk)
- Tekli tab: role toggle (student/teacher), form fields, results list
- Toplu CSV tab: file picker, preview, results, CSV download

- [ ] **Step 1: Add route for the new screen**

In `/Users/wonderelt/Desktop/Owlio/owlio_admin/lib/core/router.dart`, add the route inside the `/users` route children (where `/users/import` was):

```dart
GoRoute(
  path: 'create',
  builder: (context, state) => const UserCreateScreen(),
),
```

Add the import: `import '../features/users/screens/user_create_screen.dart';`

- [ ] **Step 2: Create the user creation screen file**

Create `/Users/wonderelt/Desktop/Owlio/owlio_admin/lib/features/users/screens/user_create_screen.dart`.

The screen needs these providers (defined at top of file, following admin panel pattern):

```dart
// School list provider (reuse from existing allSchoolsProvider or define here)
final createSchoolsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from(DbTables.schools)
      .select('id, name, code')
      .order('name');
  return List<Map<String, dynamic>>.from(response);
});

// Classes for selected school
final createClassesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, schoolId) async {
  final response = await Supabase.instance.client
      .from(DbTables.classes)
      .select('id, name')
      .eq('school_id', schoolId)
      .isFilter('academic_year', null)
      .order('name');
  return List<Map<String, dynamic>>.from(response);
});
```

Main widget structure:

```dart
class UserCreateScreen extends ConsumerStatefulWidget {
  const UserCreateScreen({super.key});

  @override
  ConsumerState<UserCreateScreen> createState() => _UserCreateScreenState();
}

class _UserCreateScreenState extends ConsumerState<UserCreateScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedSchoolId;

  // Tekli form state
  bool _isStudent = true;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedClassId;
  String? _newClassName;

  // Results (shared between tabs)
  final List<Map<String, dynamic>> _createdUsers = [];
  final List<Map<String, dynamic>> _errors = [];

  // Bulk CSV state
  List<Map<String, String>>? _csvRows;
  bool _isProcessing = false;
  double _progress = 0;
}
```

Key methods:
- `_createSingleUser()` — calls Edge Function with single student/teacher
- `_processCsvFile()` — parse CSV, validate headers, show preview
- `_createBulkStudents()` — call Edge Function with student array (batch 200)
- `_downloadCsv()` — generate and download CSV with credentials
- `_buildSchoolSelector()` — dropdown at top
- `_buildSingleTab()` — form with role toggle
- `_buildBulkTab()` — CSV upload + preview + results

- [ ] **Step 3: Implement school selector (top of screen)**

The school dropdown is shared between both tabs. When school changes, class dropdown resets.

```dart
Widget _buildSchoolSelector() {
  final schoolsAsync = ref.watch(createSchoolsProvider);
  return schoolsAsync.when(
    data: (schools) => DropdownButtonFormField<String>(
      value: _selectedSchoolId,
      decoration: const InputDecoration(
        labelText: 'Okul',
        border: OutlineInputBorder(),
      ),
      items: schools.map((s) => DropdownMenuItem(
        value: s['id'] as String,
        child: Text(s['name'] as String),
      )).toList(),
      onChanged: (value) => setState(() {
        _selectedSchoolId = value;
        _selectedClassId = null;
      }),
    ),
    loading: () => const LinearProgressIndicator(),
    error: (e, _) => Text('Error: $e'),
  );
}
```

- [ ] **Step 4: Implement single creation tab**

The form shows different fields based on role toggle:
- Student: class dropdown (with "Yeni sınıf" option) + first_name + last_name
- Teacher: email + first_name + last_name

The Edge Function call:

```dart
Future<void> _createSingleUser() async {
  if (_selectedSchoolId == null) return;

  final firstName = _firstNameController.text.trim();
  final lastName = _lastNameController.text.trim();

  if (firstName.isEmpty || lastName.isEmpty) return;

  setState(() => _isProcessing = true);

  try {
    final body = <String, dynamic>{
      'school_id': _selectedSchoolId,
    };

    if (_isStudent) {
      final className = _newClassName ?? /* get name from selected class ID */;
      body['students'] = [
        {
          'first_name': firstName,
          'last_name': lastName,
          'class_name': className,
        }
      ];
    } else {
      final email = _emailController.text.trim();
      if (email.isEmpty) return;
      body['teachers'] = [
        {
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
        }
      ];
    }

    final response = await Supabase.instance.client.functions.invoke(
      'bulk-create-students',
      body: body,
    );

    final data = response.data as Map<String, dynamic>;
    final created = List<Map<String, dynamic>>.from(data['created'] ?? []);
    final errs = List<Map<String, dynamic>>.from(data['errors'] ?? []);

    setState(() {
      _createdUsers.addAll(created);
      _errors.addAll(errs);
      _firstNameController.clear();
      _lastNameController.clear();
      _emailController.clear();
    });
  } finally {
    setState(() => _isProcessing = false);
  }
}
```

- [ ] **Step 5: Implement bulk CSV tab**

CSV parsing (use the `csv` package already in pubspec):

```dart
Future<void> _pickAndParseCsv() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['csv'],
  );
  if (result == null) return;

  final bytes = result.files.single.bytes;
  if (bytes == null) return;

  final content = utf8.decode(bytes);
  final rows = const CsvToListConverter().convert(content);

  if (rows.isEmpty) return;

  // Validate headers
  final headers = rows.first.map((h) => h.toString().trim().toLowerCase()).toList();
  final required = ['ad', 'soyad', 'sınıf'];
  // Also accept English: 'first_name', 'last_name', 'class_name'

  // Map rows to list of maps
  final parsed = <Map<String, String>>[];
  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    parsed.add({
      'first_name': row[headers.indexOf('ad')].toString().trim(),
      'last_name': row[headers.indexOf('soyad')].toString().trim(),
      'class_name': row[headers.indexOf('sınıf')].toString().trim(),
    });
  }

  setState(() => _csvRows = parsed);
}
```

Bulk creation (with batching):

```dart
Future<void> _createBulkStudents() async {
  if (_selectedSchoolId == null || _csvRows == null) return;

  setState(() { _isProcessing = true; _progress = 0; });

  final allStudents = _csvRows!;
  final batchSize = 200;

  for (var i = 0; i < allStudents.length; i += batchSize) {
    final batch = allStudents.sublist(i, min(i + batchSize, allStudents.length));

    final response = await Supabase.instance.client.functions.invoke(
      'bulk-create-students',
      body: {
        'school_id': _selectedSchoolId,
        'students': batch.map((s) => {
          'first_name': s['first_name'],
          'last_name': s['last_name'],
          'class_name': s['class_name'],
        }).toList(),
      },
    );

    final data = response.data as Map<String, dynamic>;
    setState(() {
      _createdUsers.addAll(List<Map<String, dynamic>>.from(data['created'] ?? []));
      _errors.addAll(List<Map<String, dynamic>>.from(data['errors'] ?? []));
      _progress = (i + batch.length) / allStudents.length;
    });
  }

  setState(() { _isProcessing = false; _csvRows = null; });
}
```

- [ ] **Step 6: Implement results display and CSV download**

Results table showing created users with username/password:

```dart
Widget _buildResultsTable() {
  if (_createdUsers.isEmpty && _errors.isEmpty) return const SizedBox.shrink();

  return Column(
    children: [
      // Warning banner
      Container(
        padding: const EdgeInsets.all(12),
        color: Colors.orange.shade50,
        child: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Bu şifreler bir daha gösterilemez. Lütfen CSV olarak indirin.'),
          ],
        ),
      ),
      // Results table
      DataTable(
        columns: const [
          DataColumn(label: Text('Ad Soyad')),
          DataColumn(label: Text('Kullanıcı Adı')),
          DataColumn(label: Text('Şifre')),
          DataColumn(label: Text('Sınıf')),
          DataColumn(label: Text('Durum')),
        ],
        rows: [
          ..._createdUsers.map((u) => DataRow(cells: [
            DataCell(Text('${u['first_name']} ${u['last_name']}')),
            DataCell(Text(u['username'] ?? u['email'] ?? '')),
            DataCell(Text(u['password'] ?? '')),
            DataCell(Text(u['class_name'] ?? '')),
            DataCell(Icon(Icons.check_circle, color: Colors.green)),
          ])),
          ..._errors.map((e) => DataRow(cells: [
            DataCell(Text('${e['first_name']} ${e['last_name']}')),
            DataCell(const Text('-')),
            DataCell(const Text('-')),
            DataCell(const Text('-')),
            DataCell(Tooltip(message: e['error'], child: Icon(Icons.error, color: Colors.red))),
          ])),
        ],
      ),
      // Download buttons
      Row(
        children: [
          ElevatedButton.icon(
            onPressed: _downloadCsv,
            icon: const Icon(Icons.download),
            label: const Text('CSV İndir'),
          ),
        ],
      ),
    ],
  );
}
```

CSV download implementation:

```dart
/// CSV download using universal_html (add to pubspec: universal_html: ^2.2.4)
void _downloadCsv() {
  final csvData = [
    ['Ad', 'Soyad', 'Kullanıcı Adı', 'Şifre', 'Sınıf', 'Rol'],
    ..._createdUsers.map((u) => [
      u['first_name'],
      u['last_name'],
      u['username'] ?? u['email'] ?? '',
      u['password'],
      u['class_name'] ?? '',
      u['role'],
    ]),
  ];

  final csv = const ListToCsvConverter().convert(csvData);
  final bytes = utf8.encode(csv);
  // Use universal_html for web-safe download
  // import 'package:universal_html/html.dart' as html;
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', 'olusturulan_kullanicilar.csv')
    ..click();
  html.Url.revokeObjectUrl(url);
}
```

**Note:** Add `universal_html: ^2.2.4` to `owlio_admin/pubspec.yaml` dependencies. This is the standard cross-platform replacement for `dart:html`. Import as `import 'package:universal_html/html.dart' as html;`

- [ ] **Step 7: Verify with dart analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/`
Expected: No errors

- [ ] **Step 8: Commit**

```bash
git add owlio_admin/lib/features/users/screens/user_create_screen.dart
git add owlio_admin/lib/core/router.dart
git commit -m "feat(admin): add user creation screen with single + bulk CSV modes"
```

---

## Task 5: Admin Panel — Update User List and Edit Screens

**Files:**
- Modify: `owlio_admin/lib/features/users/screens/user_list_screen.dart`
- Modify: `owlio_admin/lib/features/users/screens/user_edit_screen.dart`

- [ ] **Step 1: Add username to user list display**

In `user_list_screen.dart`, the user card shows name, email, role. Add username display.

Find the user card widget (around lines 200-250) and add username to the display. Add it below the name, styled as a secondary text:

```dart
if (user['username'] != null)
  Text(
    '@${user['username']}',
    style: TextStyle(
      color: Colors.grey.shade600,
      fontSize: 13,
    ),
  ),
```

- [ ] **Step 2: Add username to user list search**

In the `usersProvider`, the query currently searches by name/email. Update the query to also include username in the select and make it searchable in the UI filter logic.

The current query at line 38:
```dart
supabase.from(DbTables.profiles).select('*, schools(name), classes(name, grade)')
```

This already fetches `*` so `username` is included. Just ensure the search/filter UI also checks `username` when filtering results.

- [ ] **Step 3: Update user edit screen — show username (read-only)**

In `user_edit_screen.dart`, find the profile tab form fields (around lines 400-440). Add a username field after the name fields:

```dart
if (user['username'] != null)
  TextFormField(
    initialValue: user['username'] as String,
    decoration: const InputDecoration(
      labelText: 'Username',
      border: OutlineInputBorder(),
      enabled: false,
    ),
    readOnly: true,
  ),
```

- [ ] **Step 4: Update stale info banner in user edit screen**

In `user_edit_screen.dart` (line 298), replace the stale banner text:

Old: `'Yeni kullanıcılar Supabase Dashboard üzerinden oluşturulur. '`
New: `'Yeni kullanıcılar Kullanıcı Oluştur sayfasından eklenebilir.'`

- [ ] **Step 5: Remove student_number edit from user edit screen**

In `user_edit_screen.dart`, find the `_studentNumberController` and its TextFormField (around lines 85 and 427-434). Remove the editable student_number field, or keep it as read-only display-only:

Change from editable to read-only, or remove entirely if student_number is no longer relevant.

- [ ] **Step 6: Verify with dart analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/`
Expected: No errors

- [ ] **Step 7: Commit**

```bash
git add owlio_admin/lib/features/users/screens/user_list_screen.dart
git add owlio_admin/lib/features/users/screens/user_edit_screen.dart
git commit -m "feat(admin): show username in user list and edit screens, update stale banner"
```

---

## Task 6: Flutter App — Add username to User Entity and Model

**Files:**
- Modify: `lib/domain/entities/user.dart`
- Modify: `lib/data/models/user/user_model.dart`

- [ ] **Step 1: Add username field to User entity**

In `/Users/wonderelt/Desktop/Owlio/lib/domain/entities/user.dart`, add `username` field:

```dart
// Add to constructor (after studentNumber):
this.username,

// Add field:
final String? username;

// Add to copyWith:
String? username,
// ... in return:
username: username ?? this.username,

// Add to props:
username,
```

- [ ] **Step 2: Add username to UserModel**

In `/Users/wonderelt/Desktop/Owlio/lib/data/models/user/user_model.dart`:

```dart
// Add to constructor (after studentNumber):
this.username,

// Add field:
final String? username;

// Add to fromJson (after studentNumber line):
username: json['username'] as String?,

// Add to fromEntity:
username: entity.username,

// Add to toJson (after student_number):
'username': username,

// Add to toEntity (after studentNumber):
username: username,
```

- [ ] **Step 3: Verify no broken references**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/domain/entities/user.dart lib/data/models/user/user_model.dart
git commit -m "feat(domain): add username field to User entity and UserModel"
```

---

## Task 7: Flutter App — Unified Login Screen

**Files:**
- Modify: `lib/presentation/screens/auth/login_screen.dart`

- [ ] **Step 1: Read current login screen**

Read `/Users/wonderelt/Desktop/Owlio/lib/presentation/screens/auth/login_screen.dart` to understand full structure.

- [ ] **Step 2: Replace tabbed login with single form**

Remove the `_useStudentNumber` toggle and the tab/toggle UI. Replace with a single form:

```dart
// State: remove _useStudentNumber
// Replace _studentNumberController and _emailController with single:
final _identityController = TextEditingController();
final _passwordController = TextEditingController();

// Build method: single form
Column(
  children: [
    TextFormField(
      controller: _identityController,
      decoration: const InputDecoration(
        labelText: 'Username or Email',
        hintText: 'Enter your username or email',
        prefixIcon: Icon(Icons.person),
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.next,
    ),
    const SizedBox(height: 16),
    TextFormField(
      controller: _passwordController,
      decoration: const InputDecoration(
        labelText: 'Password',
        prefixIcon: Icon(Icons.lock),
        border: OutlineInputBorder(),
      ),
      obscureText: true,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _login(),
    ),
    const SizedBox(height: 24),
    ElevatedButton(
      onPressed: _isLoading ? null : _login,
      child: _isLoading
          ? const CircularProgressIndicator()
          : const Text('Sign In'),
    ),
  ],
)
```

- [ ] **Step 3: Implement unified login method**

```dart
Future<void> _login() async {
  final input = _identityController.text.trim();
  final password = _passwordController.text;

  if (input.isEmpty || password.isEmpty) return;

  setState(() => _isLoading = true);

  try {
    // @ detection: if contains @, treat as email; otherwise as username
    final email = input.contains('@') ? input : '$input@owlio.local';

    final success = await ref.read(authControllerProvider.notifier)
        .signInWithEmail(email, password);

    if (!success && mounted) {
      // Show error
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

**Note:** This uses the existing `signInWithEmail()` method since we're converting username to synthetic email. No need for a new auth method.

- [ ] **Step 4: Update dev shortcuts (debug mode quick login)**

The login screen has `_quickLogin` dev shortcuts (lines 261-362) that use real emails like `fresh@demo.com`. After the D4 migration, these students' auth emails will be `username@owlio.local`.

Update `_quickLogin` to work with the new unified login — it should pass through the same `@` detection logic:

```dart
Future<void> _quickLogin(String identity, String password) async {
  _identityController.text = identity;
  _passwordController.text = password;
  await _login();
}
```

Update the dev chip calls: student shortcuts should use usernames (will be known after D3 migration), teacher/admin shortcuts keep emails:

```dart
// Students — these will use usernames after D4 migration runs
// The exact usernames depend on generate_username output for seed data
// For now, keep as emails — they'll work until D4 migration runs
// After D4, update to: _quickLogin('fredem1', 'Test1234')
onTap: () => _quickLogin('fresh@demo.com', 'Test1234'),

// Teachers/admins — keep as emails (unchanged)
onTap: () => _quickLogin('teacher@demo.com', 'Test1234'),
onTap: () => _quickLogin('admin@demo.com', 'Test1234'),
```

**Important:** Dev shortcuts for students must be updated to usernames AFTER Task 8 (D4 migration) runs and the exact usernames are known. Add a TODO comment in the code for this.

- [ ] **Step 5: Verify with dart analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/`
Expected: No errors (may have warnings about unused student number imports — will clean in next task)

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/auth/login_screen.dart
git commit -m "feat(auth): unified login screen with username or email"
```

---

## Task 8: Flutter App — Remove Dead Student Number Auth Code

**Files:**
- Delete: `lib/domain/usecases/auth/sign_in_with_student_number_usecase.dart`
- Modify: `lib/domain/repositories/auth_repository.dart`
- Modify: `lib/data/repositories/supabase/supabase_auth_repository.dart`
- Modify: `lib/presentation/providers/auth_provider.dart`
- Modify: `lib/presentation/providers/usecase_providers.dart` (if it has signInWithStudentNumber provider)

- [ ] **Step 1: Remove signInWithStudentNumber from AuthRepository interface**

In `/Users/wonderelt/Desktop/Owlio/lib/domain/repositories/auth_repository.dart`, remove the `signInWithStudentNumber()` method signature (lines 8-11).

- [ ] **Step 2: Remove implementation from SupabaseAuthRepository**

In `/Users/wonderelt/Desktop/Owlio/lib/data/repositories/supabase/supabase_auth_repository.dart`, remove the `signInWithStudentNumber()` method (lines 57-111).

- [ ] **Step 3: Remove signInWithStudentNumber from AuthController**

In `/Users/wonderelt/Desktop/Owlio/lib/presentation/providers/auth_provider.dart`, remove the `signInWithStudentNumber()` method from `AuthController` (lines 89-111).

- [ ] **Step 4: Delete the usecase file**

Run: `rm /Users/wonderelt/Desktop/Owlio/lib/domain/usecases/auth/sign_in_with_student_number_usecase.dart`

- [ ] **Step 5: Remove usecase provider (if exists)**

Check `/Users/wonderelt/Desktop/Owlio/lib/presentation/providers/usecase_providers.dart` for `signInWithStudentNumberUseCaseProvider` and remove it.

- [ ] **Step 6: Verify no broken references**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/`
Expected: No errors

Also run: `grep -r "signInWithStudentNumber\|student_number" lib/ --include="*.dart"` to find any remaining references. The `student_number` field in models/entities may remain (it's still a valid profile field for display), but login-related references should be gone.

- [ ] **Step 7: Commit**

```bash
git add -A lib/domain/usecases/auth/sign_in_with_student_number_usecase.dart
git add lib/domain/repositories/auth_repository.dart
git add lib/data/repositories/supabase/supabase_auth_repository.dart
git add lib/presentation/providers/auth_provider.dart
git add lib/presentation/providers/usecase_providers.dart
git commit -m "refactor(auth): remove dead student number auth code"
```

---

## Task 9: Migration Script — Existing Students Auth Email Update (D4)

> **DEPLOYMENT NOTE:** This task and Task 7 (Flutter login change) MUST be deployed atomically. See Migration Strategy in spec.

> **WARNING:** This task is DESTRUCTIVE — existing students cannot log in with old emails after this runs. Deploy together with the Flutter login change (Task 7).

**Files:**
- Create: `supabase/functions/migrate-student-emails/index.ts`

- [ ] **Step 1: Create the one-time migration Edge Function**

Create `/Users/wonderelt/Desktop/Owlio/supabase/functions/migrate-student-emails/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Verify caller is admin
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const token = authHeader.replace("Bearer ", "");
    const supabaseUser = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: `Bearer ${token}` } } }
    );

    const { data: { user: caller } } = await supabaseUser.auth.getUser();
    if (!caller) {
      return new Response(
        JSON.stringify({ error: "Invalid auth" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: callerProfile } = await supabaseAdmin
      .from("profiles")
      .select("role")
      .eq("id", caller.id)
      .single();

    if (!callerProfile || callerProfile.role !== "admin") {
      return new Response(
        JSON.stringify({ error: "Admin only" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Fetch all students with usernames
    const { data: students, error } = await supabaseAdmin
      .from("profiles")
      .select("id, username, email")
      .eq("role", "student")
      .not("username", "is", null);

    if (error) throw error;

    let migrated = 0;
    let skipped = 0;
    const errors: string[] = [];

    for (const student of students || []) {
      const syntheticEmail = `${student.username}@owlio.local`;

      // Skip if already migrated
      if (student.email === null || student.email === syntheticEmail) {
        skipped++;
        continue;
      }

      try {
        // Update auth.users email
        const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
          student.id,
          { email: syntheticEmail }
        );

        if (updateError) {
          errors.push(`${student.username}: ${updateError.message}`);
          continue;
        }

        // Clear profiles.email
        await supabaseAdmin
          .from("profiles")
          .update({ email: null })
          .eq("id", student.id);

        migrated++;
      } catch (err) {
        errors.push(`${student.username}: ${(err as Error).message}`);
      }
    }

    return new Response(
      JSON.stringify({
        total: students?.length || 0,
        migrated,
        skipped,
        errors,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
```

- [ ] **Step 2: Deploy the migration function**

Run: `cd /Users/wonderelt/Desktop/Owlio && supabase functions deploy migrate-student-emails`

- [ ] **Step 3: Run the migration (DESTRUCTIVE — coordinate with Flutter deploy)**

```bash
# Get admin JWT
curl -X POST "https://wqkxjjakysuabjcotvim.supabase.co/auth/v1/token?grant_type=password" \
  -H "apikey: <ANON_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@demo.com", "password": "Test1234"}'

# Run migration
curl -X POST "https://wqkxjjakysuabjcotvim.supabase.co/functions/v1/migrate-student-emails" \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  -H "Content-Type: application/json"
```

Expected: `{"total": N, "migrated": N, "skipped": 0, "errors": []}`

- [ ] **Step 4: Verify existing student can log in with username**

Test with a migrated student:
```bash
curl -X POST "https://wqkxjjakysuabjcotvim.supabase.co/auth/v1/token?grant_type=password" \
  -H "apikey: <ANON_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"email": "<username>@owlio.local", "password": "Test1234"}'
```

Expected: Successful auth response with JWT

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/migrate-student-emails/index.ts
git commit -m "feat(edge): add one-time student email migration to synthetic emails"
```

---

## Task 10: End-to-End Verification

- [ ] **Step 1: Test bulk creation from admin panel**

1. Open admin panel → `/users/create`
2. Select a school
3. Tab 1 (Tekli): Create a student → verify username + password shown
4. Tab 1 (Tekli): Create a teacher → verify email + password shown
5. Tab 2 (Toplu CSV): Upload a CSV with 3-5 students → verify preview → create → verify results
6. Download CSV → verify it contains correct data
7. Go to `/users` → verify new users appear with usernames

- [ ] **Step 2: Test login with new student**

1. Open Flutter app
2. Enter the username from step 1 → enter the generated password
3. Verify successful login, student sees their dashboard

- [ ] **Step 3: Test login with existing student (after migration)**

1. Open Flutter app
2. Enter the existing student's username (check in admin panel)
3. Enter their old password
4. Verify successful login

- [ ] **Step 4: Test teacher login unchanged**

1. Open Flutter app
2. Enter teacher email (teacher@demo.com) + password
3. Verify successful login (should work exactly as before)

- [ ] **Step 5: Test edge cases**

1. Try creating a student with Turkish characters (Şükrü Çağlar) → verify username generation
2. Try creating duplicate student (same name, same class) → verify error
3. Try uploading CSV with non-existent class → verify auto-creation
4. Try logging in with `mesyil1@` (trailing @) → verify it trims and works or shows clear error

- [ ] **Step 6: Final dart analyze**

Run both:
```bash
cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/
cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/
```

Expected: No errors in either project
