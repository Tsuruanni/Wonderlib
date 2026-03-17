# Remaining Tech Debt Cleanup Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete all immediately actionable tech debt items: league scheduler, Sentry integration, constants consolidation, and CLAUDE.md cleanup.

**Architecture:** League scheduler uses a new Edge Function invoked by an external cron service. Sentry wraps the existing main() with SentryFlutter.init(). Constants are merged into a single source of truth (AppConfig).

**Tech Stack:** Supabase Edge Functions (Deno), Flutter, Sentry, cron-job.org

---

## Resolved Before Starting (No Action Needed)

- ~~`vocabulary_screen.dart` not routed~~ → Already routed at `/vocabulary` → `VocabularyHubScreen`
- ~~`chapters.vocabulary` JSONB vs `chapter_vocabulary` table~~ → JSONB not used in Flutter; junction table is canonical
- ~~`GameConfig` pattern~~ → Aspirational only; not blocking anything

## Deferred to Future Sessions (Big Refactors)

- `completed_chapter_ids UUID[]` → junction table: Touches 5+ Flutter files + DB migration + RPC rewrites
- `assignments.content_config JSONB` → FK columns: Touches 9 Flutter files + DB migration

---

## Chunk 1: League Scheduler + Sentry + Constants

### Task 1: Create league-reset Edge Function + external cron

**Why:** `process_weekly_league_reset()` RPC exists but nothing calls it. Without a scheduler, the league system silently does nothing. Free tier has no pg_cron.

**Approach:** Create an Edge Function that calls the RPC. Use cron-job.org (free) to hit the function URL every Monday 00:00 UTC.

**Files:**
- Create: `supabase/functions/league-reset/index.ts`

- [ ] **Step 1: Create the Edge Function**

```typescript
// supabase/functions/league-reset/index.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Verify this is an authorized call (check for a secret header)
    const cronSecret = req.headers.get('x-cron-secret')
    const expectedSecret = Deno.env.get('CRON_SECRET')

    if (expectedSecret && cronSecret !== expectedSecret) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Call the league reset RPC
    const { error } = await supabase.rpc('process_weekly_league_reset')

    if (error) throw error

    return new Response(
      JSON.stringify({ success: true, message: 'Weekly league reset completed' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('League reset error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

- [ ] **Step 2: Deploy the Edge Function (verify_jwt = false since cron uses secret header)**

Deploy via MCP or CLI:
```bash
supabase functions deploy league-reset --no-verify-jwt
```

> **Note:** `--no-verify-jwt` is needed because the external cron service won't have a Supabase JWT. Security is handled via the `x-cron-secret` header instead.

- [ ] **Step 3: Set the CRON_SECRET**

```bash
supabase secrets set CRON_SECRET=<generate-a-random-32-char-string>
```

Generate a secret: `openssl rand -hex 16`

- [ ] **Step 4: Configure external cron (cron-job.org)**

1. Go to https://cron-job.org and create a free account
2. Create a new cron job:
   - **URL:** `https://wqkxjjakysuabjcotvim.supabase.co/functions/v1/league-reset`
   - **Schedule:** Every Monday 00:00 UTC (`0 0 * * 1`)
   - **Method:** POST
   - **Headers:**
     - `Content-Type: application/json`
     - `x-cron-secret: <your-secret-from-step-3>`
   - **Body:** `{}`

- [ ] **Step 5: Test manually**

```bash
curl -X POST https://wqkxjjakysuabjcotvim.supabase.co/functions/v1/league-reset \
  -H "Content-Type: application/json" \
  -H "x-cron-secret: <your-secret>" \
  -d '{}'
```

Expected: `{"success": true, "message": "Weekly league reset completed"}` or `"Week already processed"` notice.

- [ ] **Step 6: Commit**

```bash
git add supabase/functions/league-reset/index.ts
git commit -m "feat: add league-reset Edge Function for external cron scheduling"
```

---

### Task 2: Initialize Sentry in main.dart

**Why:** `SentryFlutter` is imported in `error_interceptor.dart` and calls `Sentry.captureException()`, but `SentryFlutter.init()` is never called. Sentry silently drops all errors.

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Update main.dart**

Wrap the existing `main()` function with `SentryFlutter.init()`. The DSN is already in `.env` and `EnvConstants.sentryDsn` reads it.

Find the current main() structure and wrap it:

```dart
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  // Initialize Sentry (only if DSN is configured)
  final sentryDsn = EnvConstants.sentryDsn;
  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.environment = EnvConstants.environment;
        options.tracesSampleRate = 0.2; // 20% of transactions
        options.sendDefaultPii = false; // Don't send PII (K-12 privacy)
      },
      appRunner: () => _initAndRunApp(),
    );
  } else {
    await _initAndRunApp();
  }
}

Future<void> _initAndRunApp() async {
  // ... existing Supabase.initialize() and runApp() code ...
}
```

> **Important:** Keep `sendDefaultPii = false` for K-12 privacy compliance.

- [ ] **Step 2: Verify it compiles**

```bash
dart analyze lib/main.dart
```

- [ ] **Step 3: Test locally**

```bash
flutter run -d chrome
```

Expected: No errors. Check browser console for Sentry initialization message.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: initialize Sentry error tracking in main.dart"
```

---

### Task 3: Consolidate XP constants — merge AppConstants into AppConfig

**Why:** Two files define XP values with conflicting numbers:
- `AppConfig.xpRewards['chapter_complete'] = 50` vs `AppConstants.xpPerChapter = 25`
- `AppConfig.xpRewards['word_learned'] = 5` vs `AppConstants.xpPerVocabularyWord = 3`

Code uses both — some screens read AppConfig, others AppConstants. Single source needed.

**Decision:** Keep `AppConfig.xpRewards` (the map-based approach, newer) as the canonical source. Deprecate XP constants in `AppConstants`.

**Files:**
- Modify: `lib/core/config/app_config.dart` (canonical XP values)
- Modify: `lib/core/constants/app_constants.dart` (remove XP constants, redirect to AppConfig)

- [ ] **Step 1: Find all usages of AppConstants XP values**

```bash
grep -rn "AppConstants\.xp\|AppConstants\.xpPer\|AppConstants\.xpDaily\|AppConstants\.xpStreak" lib/ --include="*.dart"
```

List every file that uses `AppConstants.xpPer*` and update it to use `AppConfig.xpRewards['key']` instead.

- [ ] **Step 2: Update AppConstants — remove XP values, add redirect comment**

In `lib/core/constants/app_constants.dart`, remove lines 22-30 (the xp constants) and add:

```dart
// XP values moved to AppConfig.xpRewards — use AppConfig instead
// See: lib/core/config/app_config.dart
```

- [ ] **Step 3: Update all references**

Replace every `AppConstants.xpPerChapter` → `AppConfig.xpRewards['chapter_complete']!`
Replace every `AppConstants.xpPerCorrectAnswer` → `AppConfig.xpRewards['activity_complete']!`
etc.

- [ ] **Step 4: Verify no broken references**

```bash
dart analyze lib/
```

Expected: No errors or warnings.

- [ ] **Step 5: Commit**

```bash
git add lib/core/config/app_config.dart lib/core/constants/app_constants.dart <other-modified-files>
git commit -m "fix: consolidate XP constants into AppConfig (single source of truth)"
```

---

### Task 4: Clean up CLAUDE.md — remove resolved items

**Why:** Several items marked as "to fix" are already resolved:
- `vocabulary_screen.dart` is actually routed
- `chapters.vocabulary` JSONB is not used

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Remove false positives from Known Issues**

Remove:
- `vocabulary_screen.dart router'da yok` — already routed at `/vocabulary`
- `chapters.vocabulary JSONB vs chapter_vocabulary table` — JSONB not used, junction table is canonical

Update:
- `Constants overlap` → mark as resolved after Task 3

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: clean up CLAUDE.md — remove resolved items"
```

---

## Post-Plan: Deferred Items (Future Sessions)

These require both DB migration AND Flutter code changes. Each should be its own planning session:

### `completed_chapter_ids UUID[]` → Junction Table
- **Scope:** New `reading_chapter_completions(user_id, chapter_id, completed_at)` table
- **Affected Flutter files:** `reading_progress_model.dart`, `reading_progress.dart`, `supabase_book_repository.dart`, `supabase_book_quiz_repository.dart`, `book_provider.dart`, `book_detail_screen.dart`
- **Migration:** Create table, migrate data from arrays, update all RPC functions that use `array_length(completed_chapter_ids, 1)`
- **Risk:** High — touches core reading flow

### `assignments.content_config JSONB` → FK Columns
- **Scope:** Add `book_id`, `word_list_id`, `vocabulary_unit_id` nullable FK columns
- **Affected Flutter files:** 9 files across models, entities, repositories, providers, screens
- **Migration:** Add columns, populate from JSONB, update queries to use FK joins
- **Risk:** Medium — assignment system actively used by teachers
