# Book Quiz Admin Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect the admin panel book editor to the existing quiz editor, fix hardcoded XP, and make attempt numbering atomic via a DB trigger.

**Architecture:** Three independent fixes: (A) admin UI navigation, (B) AppConfig XP constant, (C) Supabase migration + client cleanup. No domain/entity changes needed.

**Tech Stack:** Flutter, Riverpod, Supabase (PostgreSQL triggers), owlio_shared

**Spec:** `docs/superpowers/specs/2026-03-23-book-quiz-admin-integration-design.md`

---

## Task 1: DB Migration — Quiz Attempt Number Trigger

**Files:**
- Create: `supabase/migrations/20260323000012_quiz_attempt_number_trigger.sql`

- [ ] **Step 1: Create the migration file**

```sql
-- Automatically set attempt_number on insert via trigger
-- Replaces client-side COUNT which had a race condition

CREATE OR REPLACE FUNCTION set_quiz_attempt_number()
RETURNS TRIGGER AS $$
BEGIN
  NEW.attempt_number := COALESCE(
    (SELECT MAX(attempt_number) FROM book_quiz_results
     WHERE user_id = NEW.user_id AND quiz_id = NEW.quiz_id),
    0
  ) + 1;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_set_quiz_attempt_number
  BEFORE INSERT ON book_quiz_results
  FOR EACH ROW
  EXECUTE FUNCTION set_quiz_attempt_number();

-- Safety net: prevent duplicate attempt numbers under concurrent inserts
ALTER TABLE book_quiz_results
  ADD CONSTRAINT uq_quiz_attempt UNIQUE (user_id, quiz_id, attempt_number);
```

- [ ] **Step 2: Dry-run the migration**

Run: `supabase db push --dry-run`
Expected: Shows the new migration as pending, no errors.

- [ ] **Step 3: Push the migration**

Run: `supabase db push`
Expected: Migration applied successfully.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260323000012_quiz_attempt_number_trigger.sql
git commit -m "feat(db): add BEFORE INSERT trigger for quiz attempt_number

Replaces client-side COUNT with atomic DB trigger. Adds UNIQUE
constraint on (user_id, quiz_id, attempt_number) as safety net."
```

---

## Task 2: Remove Client-Side Attempt Number Logic

**Files:**
- Modify: `lib/data/repositories/supabase/supabase_book_quiz_repository.dart:58-69`
- Modify: `lib/data/models/book_quiz/book_quiz_result_model.dart:96`

- [ ] **Step 1: Remove COUNT query and attempt_number patch from repository**

In `lib/data/repositories/supabase/supabase_book_quiz_repository.dart`, replace the `submitQuizResult` method body (lines 57-92):

**Before (lines 57-69):**
```dart
    try {
      // Calculate attempt number
      final countResponse = await _supabase
          .from(DbTables.bookQuizResults)
          .select('id')
          .eq('user_id', result.userId)
          .eq('quiz_id', result.quizId);
      final attemptNumber = (countResponse as List).length + 1;

      // Insert result
      final model = BookQuizResultModel.fromEntity(result);
      final insertData = model.toInsertJson();
      insertData['attempt_number'] = attemptNumber;
```

**After:**
```dart
    try {
      // Insert result (attempt_number set by DB trigger)
      final model = BookQuizResultModel.fromEntity(result);
      final insertData = model.toInsertJson();
```

- [ ] **Step 2: Remove attempt_number from toInsertJson()**

In `lib/data/models/book_quiz/book_quiz_result_model.dart`, remove line 96 from `toInsertJson()`:

**Before (lines 85-99):**
```dart
  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'quiz_id': quizId,
      'book_id': bookId,
      'score': score,
      'max_score': maxScore,
      'percentage': percentage,
      'is_passing': isPassing,
      'answers': answers,
      'time_spent': timeSpent,
      'attempt_number': attemptNumber,
      'completed_at': completedAt.toIso8601String(),
    };
  }
```

**After:**
```dart
  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'quiz_id': quizId,
      'book_id': bookId,
      'score': score,
      'max_score': maxScore,
      'percentage': percentage,
      'is_passing': isPassing,
      'answers': answers,
      'time_spent': timeSpent,
      'completed_at': completedAt.toIso8601String(),
    };
  }
```

- [ ] **Step 3: Run analyze**

Run: `dart analyze lib/`
Expected: No errors (warnings OK).

- [ ] **Step 4: Commit**

```bash
git add lib/data/repositories/supabase/supabase_book_quiz_repository.dart lib/data/models/book_quiz/book_quiz_result_model.dart
git commit -m "refactor: remove client-side attempt_number calculation

DB trigger now handles this atomically. Removes COUNT query and
manual attempt_number assignment from submitQuizResult flow."
```

---

## Task 3: Replace Hardcoded XP with AppConfig

**Files:**
- Modify: `lib/core/config/app_config.dart:74`
- Modify: `lib/data/repositories/supabase/supabase_book_quiz_repository.dart:143-145`

- [ ] **Step 1: Add quiz_pass key to AppConfig.xpRewards**

In `lib/core/config/app_config.dart`, add `'quiz_pass': 20,` after line 73 (`'assignment_complete': 100,`):

**Before (lines 65-74):**
```dart
  static const Map<String, int> xpRewards = {
    'chapter_complete': 50,
    'activity_complete': 20,
    'activity_perfect': 30,
    'word_learned': 5,
    'word_mastered': 15,
    'book_complete': 200,
    'streak_bonus_day': 10,
    'assignment_complete': 100,
  };
```

**After:**
```dart
  static const Map<String, int> xpRewards = {
    'chapter_complete': 50,
    'activity_complete': 20,
    'activity_perfect': 30,
    'word_learned': 5,
    'word_mastered': 15,
    'book_complete': 200,
    'streak_bonus_day': 10,
    'assignment_complete': 100,
    'quiz_pass': 20,
  };
```

- [ ] **Step 2: Add AppConfig import and replace hardcoded value in repository**

In `lib/data/repositories/supabase/supabase_book_quiz_repository.dart`:

First, add import alongside the other local imports (after line 6, grouped with the `../../../` imports):
```dart
import '../../../core/config/app_config.dart';
```

Then replace lines 143-146:

**Before:**
```dart
        await _supabase.rpc(RpcFunctions.awardXpTransaction, params: {
          'p_user_id': userId,
          'p_amount': 20, // Book completion XP
        });
```

**After:**
```dart
        await _supabase.rpc(RpcFunctions.awardXpTransaction, params: {
          'p_user_id': userId,
          'p_amount': AppConfig.xpRewards['quiz_pass']!, // Quiz pass XP
        });
```

- [ ] **Step 3: Run analyze**

Run: `dart analyze lib/`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/core/config/app_config.dart lib/data/repositories/supabase/supabase_book_quiz_repository.dart
git commit -m "fix: replace hardcoded quiz XP (20) with AppConfig.xpRewards

Adds 'quiz_pass' key to xpRewards map. Fixes misleading comment
that said 'Book completion XP' when it was actually quiz pass XP."
```

---

## Task 4: Admin Panel — Quiz Navigation in Book Editor

**Files:**
- Modify: `owlio_admin/lib/features/books/screens/book_edit_screen.dart:534-537`

- [ ] **Step 1: Add quiz provider at the top of the file**

In `owlio_admin/lib/features/books/screens/book_edit_screen.dart`, add a new provider after the existing `bookDetailProvider` (after line 21):

```dart
/// Provider for checking if a book has a quiz
final bookQuizSummaryProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, bookId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.bookQuizzes)
      .select('id, passing_score, total_points, is_published, book_quiz_questions(id)')
      .eq('book_id', bookId)
      .maybeSingle();
  return response;
});
```

- [ ] **Step 2: Add quiz section to _ChaptersList build method**

In the `build` method of `_ChaptersListState` (line 534), insert a quiz section as the first child in the `Column`, before the existing `Padding` block at line 537.

**Before (lines 534-537):**
```dart
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
```

**After:**
```dart
    final quizAsync = ref.watch(bookQuizSummaryProvider(widget.bookId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quiz section
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quiz',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              quizAsync.when(
                loading: () => const SizedBox(
                  height: 40,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (e, _) => Text('Hata: $e', style: TextStyle(color: Colors.red.shade600)),
                data: (quiz) {
                  if (quiz != null) {
                    final questions = (quiz['book_quiz_questions'] as List?) ?? [];
                    final passingScore = quiz['passing_score'] ?? 70;
                    final isPublished = quiz['is_published'] ?? false;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                child: const Icon(Icons.quiz, size: 18, color: Color(0xFF4F46E5)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${questions.length} soru · %$passingScore geçme notu',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isPublished ? 'Yayında' : 'Taslak',
                                      style: TextStyle(
                                        color: isPublished ? Colors.green.shade600 : Colors.orange.shade600,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => context.go('/books/${widget.bookId}/quiz'),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Quiz Düzenle'),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.go('/books/${widget.bookId}/quiz'),
                        icon: const Icon(Icons.quiz, size: 18),
                        label: const Text('Quiz Oluştur'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4F46E5),
                          side: const BorderSide(color: Color(0xFF4F46E5)),
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
```

- [ ] **Step 3: Run analyze on admin panel**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/`
Expected: No errors.

- [ ] **Step 4: Visual test**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && flutter run -d chrome`
Navigate to an existing book edit screen. Verify:
- Quiz section appears above "Bölümler" section in the right panel
- For books without a quiz: "Quiz Oluştur" button shown
- Clicking it navigates to `/books/:bookId/quiz`

- [ ] **Step 5: Commit**

```bash
cd /Users/wonderelt/Desktop/Owlio
git add owlio_admin/lib/features/books/screens/book_edit_screen.dart
git commit -m "feat(admin): add quiz navigation to book editor

Adds a Quiz section in the right panel of the book edit screen,
above the chapters list. Shows quiz summary (question count, passing
score, publish status) if a quiz exists, or a create button if not."
```

---

## Task 5: Final Verification

- [ ] **Step 1: Analyze both projects**

Run: `dart analyze lib/`
Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/`
Expected: No errors in either project.

- [ ] **Step 2: Verify migration is applied**

Run: `supabase migration list`
Expected: `20260323000012_quiz_attempt_number_trigger.sql` shows as applied.

- [ ] **Step 3: Final commit (if any remaining changes)**

Only if there are uncommitted fixes from verification.
