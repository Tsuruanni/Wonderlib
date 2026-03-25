# Teacher Panel Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix security vulnerabilities, broken features, and code quality issues in the teacher panel without touching student-facing code.

**Architecture:** 4 independent tasks ordered by severity. Tasks 1-3 are DB migrations (SQL only, zero Flutter risk). Task 4 is a Reading Progress Report rebuild (new RPC + Flutter screen rewrite). Task 5 is Flutter-only code quality fixes in teacher/assignment files. Each task produces a standalone commit.

**Tech Stack:** PostgreSQL (Supabase migrations), Flutter/Dart, Riverpod

**Risk Assessment:** Tasks 1-3 are pure SQL `CREATE OR REPLACE FUNCTION` — they replace existing functions atomically with no downtime. The Flutter app calls these RPCs by name; the return signatures stay identical, so no Flutter changes needed. Task 4 touches only teacher report screens. Task 5 touches only model/repository files used by student assignment flows — changes are mechanical (literal string → enum getter).

---

## Task 1: Security — RPC School-Scope Authorization

**Problem:** `get_classes_with_stats(p_school_id)` and `get_students_in_class(p_class_id)` lack school-scope checks. Any authenticated teacher can pass another school's IDs and read their data.

**Pattern to follow:** `get_teacher_stats` was fixed in `20260316000003` with `auth.uid() = p_teacher_id`. We apply the same principle: verify the caller belongs to the school being queried.

**Files:**
- Create: `supabase/migrations/20260325000007_fix_rpc_school_scope_auth.sql`

**Impact on Flutter:** None. Return types are unchanged. The caller already passes their own school_id/class_id, so the new checks will pass for legitimate calls.

- [ ] **Step 1: Write the migration**

```sql
-- =============================================
-- FIX: School-scope authorization for teacher RPCs
-- Problem: get_classes_with_stats and get_students_in_class only check
-- is_teacher_or_higher() but not whether the caller belongs to the
-- requested school. A teacher from School A could query School B's data.
-- Fix: Verify caller's school_id matches the requested scope.
-- =============================================

-- 1. get_classes_with_stats: verify caller belongs to requested school
CREATE OR REPLACE FUNCTION get_classes_with_stats(p_school_id UUID)
RETURNS TABLE (
  id UUID,
  name TEXT,
  grade INT,
  academic_year TEXT,
  description TEXT,
  student_count BIGINT,
  avg_progress NUMERIC,
  created_at TIMESTAMPTZ
) AS $$
DECLARE
  v_caller_school_id UUID;
BEGIN
  -- Authorization: teacher or higher only
  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  -- School-scope: caller must belong to the requested school
  SELECT school_id INTO v_caller_school_id
  FROM profiles WHERE id = auth.uid();

  IF v_caller_school_id IS DISTINCT FROM p_school_id THEN
    RAISE EXCEPTION 'Unauthorized: cannot access classes from another school';
  END IF;

  RETURN QUERY
  SELECT
    c.id,
    c.name::TEXT,
    c.grade,
    c.academic_year::TEXT,
    c.description::TEXT,
    COUNT(DISTINCT p.id) as student_count,
    COALESCE(AVG(rp.completion_percentage), 0) as avg_progress,
    c.created_at
  FROM classes c
  LEFT JOIN profiles p ON p.class_id = c.id AND p.role = 'student'
  LEFT JOIN reading_progress rp ON rp.user_id = p.id
  WHERE c.school_id = p_school_id
  GROUP BY c.id, c.name, c.grade, c.academic_year, c.description, c.created_at
  ORDER BY c.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. get_students_in_class: verify caller's school owns the class
CREATE OR REPLACE FUNCTION get_students_in_class(p_class_id UUID)
RETURNS TABLE (
  id UUID,
  first_name TEXT,
  last_name TEXT,
  student_number TEXT,
  email TEXT,
  avatar_url TEXT,
  xp INT,
  level INT,
  streak INT,
  books_read INT,
  avg_progress NUMERIC
) AS $$
DECLARE
  v_caller_school_id UUID;
  v_class_school_id UUID;
BEGIN
  -- Authorization: teacher or higher only
  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  -- School-scope: class must belong to caller's school
  SELECT school_id INTO v_caller_school_id
  FROM profiles WHERE id = auth.uid();

  SELECT school_id INTO v_class_school_id
  FROM classes WHERE id = p_class_id;

  IF v_caller_school_id IS DISTINCT FROM v_class_school_id THEN
    RAISE EXCEPTION 'Unauthorized: cannot access students from another school';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.first_name::TEXT,
    p.last_name::TEXT,
    p.student_number::TEXT,
    u.email::TEXT,
    p.avatar_url::TEXT,
    p.xp,
    p.level,
    p.current_streak,
    COALESCE((
      SELECT COUNT(DISTINCT rp.book_id)::INT
      FROM reading_progress rp
      WHERE rp.user_id = p.id AND rp.is_completed = true
    ), 0) as books_read,
    COALESCE((
      SELECT AVG(rp2.completion_percentage)
      FROM reading_progress rp2
      WHERE rp2.user_id = p.id
    ), 0) as avg_progress
  FROM profiles p
  LEFT JOIN auth.users u ON p.id = u.id
  WHERE p.class_id = p_class_id
  ORDER BY p.last_name, p.first_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Note:** `get_students_in_class` also adds `avatar_url TEXT` to its return columns — this fixes Task 2 (missing avatars) at the same time. The Flutter model already reads `json['avatar_url']` as nullable, so this is backwards compatible.

- [ ] **Step 2: Dry-run the migration**

Run: `supabase db push --dry-run`
Expected: Shows the migration file will be applied, no errors.

- [ ] **Step 3: Push to remote**

Run: `supabase db push`
Expected: Migration applied successfully.

- [ ] **Step 4: Verify with test call**

Use the Supabase SQL Editor or `curl` to verify:
1. Calling `get_classes_with_stats` with own school_id → works
2. Calling `get_classes_with_stats` with a different school_id → raises exception
3. `get_students_in_class` returns `avatar_url` column in results

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260325000007_fix_rpc_school_scope_auth.sql
git commit -m "fix(security): add school-scope auth to teacher RPCs

get_classes_with_stats and get_students_in_class now verify the caller
belongs to the requested school. Also adds avatar_url to get_students_in_class
return type (was missing, causing null avatars in class list)."
```

---

## Task 2: createAssignment Atomicity — RPC Transaction

**Problem:** `createAssignment` in `SupabaseTeacherRepository` does 3 sequential operations (INSERT assignment → SELECT students → bulk INSERT assignment_students). If step 2 or 3 fails, an orphan assignment with 0 students is left behind.

**Fix:** Move the logic into a single PLPGSQL function that runs in a transaction.

**Files:**
- Create: `supabase/migrations/20260325000008_create_assignment_rpc.sql`
- Modify: `packages/owlio_shared/lib/src/constants/rpc_functions.dart` (add new constant)
- Modify: `lib/data/repositories/supabase/supabase_teacher_repository.dart:310-372` (replace 3 queries with 1 RPC call)

- [ ] **Step 1: Write the migration**

```sql
-- =============================================
-- Atomic createAssignment RPC
-- Problem: Flutter client does 3 separate queries (insert assignment,
-- select students, bulk insert assignment_students). If any step fails
-- after the first, we get an orphan assignment with 0 students.
-- Fix: Single RPC function that runs in an implicit transaction.
-- =============================================

CREATE OR REPLACE FUNCTION create_assignment_with_students(
  p_teacher_id UUID,
  p_class_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_description TEXT,
  p_content_config JSONB,
  p_start_date TIMESTAMPTZ,
  p_due_date TIMESTAMPTZ,
  p_student_ids UUID[] DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_assignment_id UUID;
  v_student_ids UUID[];
BEGIN
  -- Authorization
  IF auth.uid() != p_teacher_id THEN
    RAISE EXCEPTION 'Unauthorized: can only create own assignments';
  END IF;

  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  -- 1. Insert assignment
  INSERT INTO assignments (teacher_id, class_id, type, title, description, content_config, start_date, due_date)
  VALUES (p_teacher_id, p_class_id, p_type, p_title, p_description, p_content_config, p_start_date, p_due_date)
  RETURNING id INTO v_assignment_id;

  -- 2. Determine student list
  IF p_student_ids IS NOT NULL AND array_length(p_student_ids, 1) > 0 THEN
    v_student_ids := p_student_ids;
  ELSIF p_class_id IS NOT NULL THEN
    SELECT array_agg(id) INTO v_student_ids
    FROM profiles
    WHERE class_id = p_class_id AND role = 'student';
  END IF;

  -- 3. Bulk insert assignment_students
  IF v_student_ids IS NOT NULL AND array_length(v_student_ids, 1) > 0 THEN
    INSERT INTO assignment_students (assignment_id, student_id, status, progress)
    SELECT v_assignment_id, unnest(v_student_ids), 'pending', 0;
  END IF;

  RETURN v_assignment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

- [ ] **Step 2: Dry-run and push migration**

Run: `supabase db push --dry-run && supabase db push`

- [ ] **Step 3: Add RPC constant to shared package**

In `packages/owlio_shared/lib/src/constants/rpc_functions.dart`, add:
```dart
static const createAssignmentWithStudents = 'create_assignment_with_students';
```

- [ ] **Step 4: Update repository to use RPC**

Replace the `createAssignment` method in `supabase_teacher_repository.dart:310-372` with:

```dart
@override
Future<Either<Failure, Assignment>> createAssignment(
  String teacherId,
  CreateAssignmentData data,
) async {
  try {
    final assignmentId = await _supabase.rpc(
      RpcFunctions.createAssignmentWithStudents,
      params: {
        'p_teacher_id': teacherId,
        'p_class_id': data.classId,
        'p_type': data.type.name,
        'p_title': data.title,
        'p_description': data.description,
        'p_content_config': data.contentConfig,
        'p_start_date': data.startDate.toIso8601String(),
        'p_due_date': data.dueDate.toIso8601String(),
        'p_student_ids': data.studentIds,
      },
    );

    // Return the created assignment
    return getAssignmentDetail(assignmentId as String);
  } on PostgrestException catch (e) {
    return Left(ServerFailure(e.message, code: e.code));
  } catch (e) {
    return Left(ServerFailure(e.toString()));
  }
}
```

- [ ] **Step 5: Run dart analyze**

Run: `dart analyze lib/data/repositories/supabase/supabase_teacher_repository.dart`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/20260325000008_create_assignment_rpc.sql \
  packages/owlio_shared/lib/src/constants/rpc_functions.dart \
  lib/data/repositories/supabase/supabase_teacher_repository.dart
git commit -m "fix(teacher): atomic createAssignment via RPC transaction

Replaces 3 sequential client-side queries with a single
create_assignment_with_students RPC that runs in an implicit
PG transaction. Prevents orphan assignments with 0 students."
```

---

## Task 3: Reading Progress Report — Make Functional

**Problem:** `ReadingProgressReportScreen` shows all zeros. The `bookReadingStatsProvider` hardcodes `totalReaders: 0`, `completedReaders: 0`, `avgProgress: 0` for every book. There is no RPC that aggregates reading_progress by book for a school.

**Fix:** Create a new RPC `get_school_book_reading_stats` that aggregates reading data per book, scoped to the teacher's school. Rewrite the screen to use it via proper provider chain.

**Files:**
- Create: `supabase/migrations/20260325000009_school_book_reading_stats_rpc.sql`
- Modify: `packages/owlio_shared/lib/src/constants/rpc_functions.dart` (add constant)
- Modify: `lib/domain/entities/teacher.dart` (add `BookReadingStats` entity)
- Modify: `lib/domain/repositories/teacher_repository.dart` (add method)
- Create: `lib/data/models/teacher/book_reading_stats_model.dart`
- Modify: `lib/data/repositories/supabase/supabase_teacher_repository.dart` (add implementation)
- Create: `lib/domain/usecases/teacher/get_school_book_reading_stats_usecase.dart`
- Modify: `lib/presentation/providers/usecase_providers.dart` (register usecase)
- Modify: `lib/presentation/providers/teacher_provider.dart` (add provider)
- Rewrite: `lib/presentation/screens/teacher/reports/reading_progress_report_screen.dart`

- [ ] **Step 1: Write the RPC migration**

```sql
-- =============================================
-- Reading Progress Report: per-book stats scoped to a school
-- Returns reader counts and avg progress for each book,
-- considering only students in the teacher's school.
-- =============================================

CREATE OR REPLACE FUNCTION get_school_book_reading_stats(p_school_id UUID)
RETURNS TABLE (
  book_id UUID,
  title TEXT,
  cover_url TEXT,
  level TEXT,
  total_readers INT,
  completed_readers INT,
  avg_progress NUMERIC
) AS $$
DECLARE
  v_caller_school_id UUID;
BEGIN
  -- Authorization
  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  -- School-scope
  SELECT school_id INTO v_caller_school_id
  FROM profiles WHERE id = auth.uid();

  IF v_caller_school_id IS DISTINCT FROM p_school_id THEN
    RAISE EXCEPTION 'Unauthorized: cannot access another school data';
  END IF;

  RETURN QUERY
  SELECT
    b.id as book_id,
    b.title::TEXT,
    b.cover_url::TEXT,
    b.level::TEXT,
    COALESCE(COUNT(DISTINCT rp.user_id)::INT, 0) as total_readers,
    COALESCE(COUNT(DISTINCT rp.user_id) FILTER (WHERE rp.is_completed = true)::INT, 0) as completed_readers,
    COALESCE(AVG(rp.completion_percentage), 0) as avg_progress
  FROM books b
  LEFT JOIN reading_progress rp ON rp.book_id = b.id
    AND rp.user_id IN (
      SELECT p.id FROM profiles p
      WHERE p.school_id = p_school_id AND p.role = 'student'
    )
  GROUP BY b.id, b.title, b.cover_url, b.level
  ORDER BY total_readers DESC, b.title;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

- [ ] **Step 2: Push migration**

Run: `supabase db push --dry-run && supabase db push`

- [ ] **Step 3: Add RPC constant**

In `packages/owlio_shared/lib/src/constants/rpc_functions.dart`, add:
```dart
static const getSchoolBookReadingStats = 'get_school_book_reading_stats';
```

- [ ] **Step 4: Add entity**

Append to `lib/domain/entities/teacher.dart`:
```dart
class BookReadingStats extends Equatable {
  const BookReadingStats({
    required this.bookId,
    required this.title,
    this.coverUrl,
    required this.level,
    required this.totalReaders,
    required this.completedReaders,
    required this.avgProgress,
  });

  final String bookId;
  final String title;
  final String? coverUrl;
  final String level;
  final int totalReaders;
  final int completedReaders;
  final double avgProgress;

  double get completionRate =>
      totalReaders > 0 ? (completedReaders / totalReaders) * 100 : 0;

  @override
  List<Object?> get props => [bookId, title, coverUrl, level, totalReaders, completedReaders, avgProgress];
}
```

- [ ] **Step 5: Add repository interface method**

In `lib/domain/repositories/teacher_repository.dart`, add to the interface:
```dart
Future<Either<Failure, List<BookReadingStats>>> getSchoolBookReadingStats(String schoolId);
```

- [ ] **Step 6: Create model**

Create `lib/data/models/teacher/book_reading_stats_model.dart`:
```dart
import '../../../domain/repositories/teacher_repository.dart';

class BookReadingStatsModel {
  const BookReadingStatsModel({
    required this.bookId,
    required this.title,
    this.coverUrl,
    required this.level,
    required this.totalReaders,
    required this.completedReaders,
    required this.avgProgress,
  });

  factory BookReadingStatsModel.fromJson(Map<String, dynamic> json) {
    return BookReadingStatsModel(
      bookId: json['book_id'] as String,
      title: json['title'] as String,
      coverUrl: json['cover_url'] as String?,
      level: json['level'] as String? ?? '',
      totalReaders: (json['total_readers'] as num?)?.toInt() ?? 0,
      completedReaders: (json['completed_readers'] as num?)?.toInt() ?? 0,
      avgProgress: (json['avg_progress'] as num?)?.toDouble() ?? 0,
    );
  }

  final String bookId;
  final String title;
  final String? coverUrl;
  final String level;
  final int totalReaders;
  final int completedReaders;
  final double avgProgress;

  BookReadingStats toEntity() {
    return BookReadingStats(
      bookId: bookId,
      title: title,
      coverUrl: coverUrl,
      level: level,
      totalReaders: totalReaders,
      completedReaders: completedReaders,
      avgProgress: avgProgress,
    );
  }
}
```

- [ ] **Step 7: Add repository implementation**

In `supabase_teacher_repository.dart`, add the method:
```dart
@override
Future<Either<Failure, List<BookReadingStats>>> getSchoolBookReadingStats(
  String schoolId,
) async {
  try {
    final response = await _supabase.rpc(
      RpcFunctions.getSchoolBookReadingStats,
      params: {'p_school_id': schoolId},
    );

    final stats = (response as List)
        .map((data) => BookReadingStatsModel.fromJson(data).toEntity())
        .toList();

    return Right(stats);
  } on PostgrestException catch (e) {
    return Left(ServerFailure(e.message, code: e.code));
  } catch (e) {
    return Left(ServerFailure(e.toString()));
  }
}
```

Also add the import:
```dart
import '../../models/teacher/book_reading_stats_model.dart';
```

- [ ] **Step 8: Create usecase**

Create `lib/domain/usecases/teacher/get_school_book_reading_stats_usecase.dart`:
```dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/teacher.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetSchoolBookReadingStatsUseCase
    implements UseCase<List<BookReadingStats>, GetSchoolBookReadingStatsParams> {
  const GetSchoolBookReadingStatsUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, List<BookReadingStats>>> call(
    GetSchoolBookReadingStatsParams params,
  ) {
    return _repository.getSchoolBookReadingStats(params.schoolId);
  }
}

class GetSchoolBookReadingStatsParams {
  const GetSchoolBookReadingStatsParams({required this.schoolId});
  final String schoolId;
}
```

- [ ] **Step 9: Register usecase provider**

In `lib/presentation/providers/usecase_providers.dart`, in the teacher section add:
```dart
final getSchoolBookReadingStatsUseCaseProvider =
    Provider<GetSchoolBookReadingStatsUseCase>((ref) {
  return GetSchoolBookReadingStatsUseCase(ref.watch(teacherRepositoryProvider));
});
```

With the import:
```dart
import '../../domain/usecases/teacher/get_school_book_reading_stats_usecase.dart';
```

- [ ] **Step 10: Add feature provider**

In `lib/presentation/providers/teacher_provider.dart`, add:
```dart
final schoolBookReadingStatsProvider = FutureProvider<List<BookReadingStats>>((ref) async {
  final user = await ref.watch(authStateChangesProvider.future);
  if (user == null || user.schoolId.isEmpty) return [];

  final useCase = ref.watch(getSchoolBookReadingStatsUseCaseProvider);
  final result = await useCase(GetSchoolBookReadingStatsParams(schoolId: user.schoolId));

  return result.fold(
    (failure) => throw Exception(failure.message),
    (stats) => stats,
  );
});
```

With the import:
```dart
import '../../domain/usecases/teacher/get_school_book_reading_stats_usecase.dart';
```

- [ ] **Step 11: Rewrite reading_progress_report_screen.dart**

Replace the entire file. Remove the co-located `BookReadingStats` class and `bookReadingStatsProvider`. Use `schoolBookReadingStatsProvider` from `teacher_provider.dart`. Keep the same UI layout but now it displays real data.

The `BookReadingStats` entity is now in `teacher.dart`, and the provider is in `teacher_provider.dart`.

Key changes:
- Delete: local `BookReadingStats` class (lines 11-32)
- Delete: local `bookReadingStatsProvider` (lines 35-66)
- Import: `teacher_provider.dart` and `teacher_repository.dart` (for entity)
- Replace: `ref.watch(bookReadingStatsProvider)` → `ref.watch(schoolBookReadingStatsProvider)`
- Replace: `ref.invalidate(bookReadingStatsProvider)` → `ref.invalidate(schoolBookReadingStatsProvider)`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/extensions/context_extensions.dart';
import '../../../../domain/repositories/teacher_repository.dart';
import '../../../providers/teacher_provider.dart';
import '../../../widgets/common/error_state_widget.dart';

class ReadingProgressReportScreen extends ConsumerWidget {
  const ReadingProgressReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(schoolBookReadingStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Progress'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(schoolBookReadingStatsProvider);
        },
        child: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ErrorStateWidget(
            message: 'Error loading data',
            onRetry: () => ref.invalidate(schoolBookReadingStatsProvider),
          ),
          data: (books) {
            if (books.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 64,
                      color: context.colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No books in library',
                      style: context.textTheme.titleMedium,
                    ),
                  ],
                ),
              );
            }

            final activeBooks = books.where((b) => b.totalReaders > 0).length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary
                Card(
                  color: context.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryItem(
                          value: '${books.length}',
                          label: 'Total Books',
                          icon: Icons.menu_book,
                        ),
                        _SummaryItem(
                          value: '$activeBooks',
                          label: 'Being Read',
                          icon: Icons.auto_stories,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Library Books',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Book cards
                ...books.map((book) => _BookStatsCard(book: book)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: context.colorScheme.onPrimaryContainer, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: context.colorScheme.onPrimaryContainer,
          ),
        ),
        Text(
          label,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _BookStatsCard extends StatelessWidget {
  const _BookStatsCard({required this.book});

  final BookReadingStats book;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Book cover
            Container(
              width: 50,
              height: 70,
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
                image: book.coverUrl != null
                    ? DecorationImage(
                        image: NetworkImage(book.coverUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: book.coverUrl == null
                  ? Icon(Icons.book, color: context.colorScheme.outline)
                  : null,
            ),
            const SizedBox(width: 12),

            // Book info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getLevelColor(book.level).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      book.level,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: _getLevelColor(book.level),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people, size: 14, color: context.colorScheme.outline),
                      const SizedBox(width: 4),
                      Text(
                        '${book.totalReaders} readers',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.check_circle, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        '${book.completedReaders} completed',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Avg progress
            if (book.totalReaders > 0)
              SizedBox(
                width: 50,
                height: 50,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: book.avgProgress / 100,
                      strokeWidth: 4,
                      backgroundColor: context.colorScheme.surfaceContainerHighest,
                    ),
                    Text(
                      '${book.avgProgress.toStringAsFixed(0)}%',
                      style: context.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'A1':
        return Colors.green;
      case 'A2':
        return Colors.lightGreen;
      case 'B1':
        return Colors.orange;
      case 'B2':
        return Colors.deepOrange;
      case 'C1':
        return Colors.red;
      case 'C2':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
```

- [ ] **Step 12: Run dart analyze**

Run: `dart analyze lib/`
Expected: No issues.

- [ ] **Step 13: Commit**

```bash
git add supabase/migrations/20260325000009_school_book_reading_stats_rpc.sql \
  packages/owlio_shared/lib/src/constants/rpc_functions.dart \
  lib/domain/entities/teacher.dart \
  lib/domain/repositories/teacher_repository.dart \
  lib/data/models/teacher/book_reading_stats_model.dart \
  lib/data/repositories/supabase/supabase_teacher_repository.dart \
  lib/domain/usecases/teacher/get_school_book_reading_stats_usecase.dart \
  lib/presentation/providers/usecase_providers.dart \
  lib/presentation/providers/teacher_provider.dart \
  lib/presentation/screens/teacher/reports/reading_progress_report_screen.dart
git commit -m "feat(teacher): implement reading progress report with real data

Adds get_school_book_reading_stats RPC that aggregates reading_progress
per book scoped to the teacher's school. Replaces stub provider with
proper clean architecture chain (RPC → repo → usecase → provider → screen)."
```

---

## Task 4: Code Quality Fixes (Flutter-only)

**Problem:** Multiple code quality issues across teacher/assignment files that don't affect functionality but create maintenance debt and pattern inconsistencies.

**Scope:** These are mechanical, low-risk changes. Each sub-step is independent.

**Files:**
- Modify: `lib/data/models/assignment/student_assignment_model.dart` (AppClock + remove redundant methods)
- Modify: `lib/data/models/assignment/assignment_student_model.dart` (remove redundant _statusToString)
- Modify: `lib/data/repositories/supabase/supabase_student_assignment_repository.dart` (use enum dbValue)
- Modify: `lib/presentation/screens/teacher/student_detail_screen.dart` (use VocabularyColors)
- Modify: `lib/presentation/screens/teacher/reports/leaderboard_report_screen.dart` (move provider)
- Modify: `lib/presentation/providers/teacher_provider.dart` (receive moved provider)

### 4a: Fix AppClock + redundant status/type methods

- [ ] **Step 1: Fix DateTime.now() → AppClock.now() in StudentAssignmentModel**

In `student_assignment_model.dart:47`, change:
```dart
// Before
if (statusStr != 'completed' && DateTime.now().isAfter(dueDate)) {
// After
if (statusStr != 'completed' && AppClock.now().isAfter(dueDate)) {
```

Add import: `import '../../../core/utils/app_clock.dart';`

- [ ] **Step 2: Replace _typeToString and _statusToString with .dbValue in StudentAssignmentModel**

In `student_assignment_model.dart`, replace the `fromEntity` factory's usage:
```dart
// Before
type: _typeToString(entity.type),
status: _statusToString(entity.status),
// After
type: entity.type.dbValue,
status: entity.status.dbValue,
```

Then delete the `_typeToString` and `_statusToString` static methods entirely (lines 149-171).

- [ ] **Step 2b: Replace _statusToString with .dbValue in AssignmentStudentModel**

In `assignment_student_model.dart:46`, replace:
```dart
// Before
status: _statusToString(entity.status),
// After
status: entity.status.dbValue,
```

Then delete the `_statusToString` static method (lines 91-102).

- [ ] **Step 3: Fix hardcoded strings in SupabaseStudentAssignmentRepository**

In `supabase_student_assignment_repository.dart`:

Line 149: `'status': 'in_progress'` → `'status': AssignmentStatus.inProgress.dbValue`
Line 150: `DateTime.now()` → `AppClock.now()`
Line 182-183: `currentData['status'] == 'pending'` → `currentData['status'] == AssignmentStatus.pending.dbValue`
Line 185: `DateTime.now()` → `AppClock.now()`
Line 212: `'status': 'completed'` → `'status': AssignmentStatus.completed.dbValue`
Line 216: `DateTime.now()` → `AppClock.now()`

Add imports:
```dart
import 'package:owlio_shared/owlio_shared.dart'; // already present
import '../../../core/utils/app_clock.dart';
```

- [ ] **Step 4: Run dart analyze**

Run: `dart analyze lib/data/`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/assignment/student_assignment_model.dart \
  lib/data/models/assignment/assignment_student_model.dart \
  lib/data/repositories/supabase/supabase_student_assignment_repository.dart
git commit -m "fix(assignments): use AppClock and enum dbValue instead of hardcoded strings

- DateTime.now() → AppClock.now() in StudentAssignmentModel and repository
- Hardcoded 'in_progress'/'completed'/'pending' → AssignmentStatus.*.dbValue
- Remove redundant _typeToString/_statusToString from both models (use .dbValue from owlio_shared)"
```

### 4b: Fix duplicate _getCategoryColor

- [ ] **Step 6: Replace _getCategoryColor with VocabularyColors in student_detail_screen.dart**

In `student_detail_screen.dart`, the `_WordListProgressCard` widget has a private `_getCategoryColor` method (lines 626-641). Replace all usages with `VocabularyColors.getCategoryColor()`.

This requires converting the `String category` to `WordListCategory` enum first. Check how the category value flows into the widget — it comes from `StudentWordListProgress.category` which is a `String`. Use `WordListCategory.fromDbValue(category)` if available, or match by name.

Add import: `import '../../../utils/ui_helpers.dart';`

Replace usage: `_getCategoryColor(progress.category)` → `VocabularyColors.getCategoryColor(WordListCategory.fromDbValue(progress.category))`

Delete the private `_getCategoryColor` method.

- [ ] **Step 7: Run dart analyze**

Run: `dart analyze lib/presentation/screens/teacher/student_detail_screen.dart`
Expected: No issues.

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/screens/teacher/student_detail_screen.dart
git commit -m "refactor(teacher): use VocabularyColors instead of duplicate _getCategoryColor"
```

### 4c: Move co-located provider to teacher_provider.dart

- [ ] **Step 9: Move allStudentsLeaderboardProvider**

Cut `allStudentsLeaderboardProvider` from `leaderboard_report_screen.dart` (lines 11-25) and paste into `teacher_provider.dart`. Update imports in both files.

- [ ] **Step 10: Run dart analyze**

Run: `dart analyze lib/presentation/`
Expected: No issues.

- [ ] **Step 11: Commit**

```bash
git add lib/presentation/screens/teacher/reports/leaderboard_report_screen.dart \
  lib/presentation/providers/teacher_provider.dart
git commit -m "refactor(teacher): move allStudentsLeaderboardProvider to teacher_provider.dart"
```

---

## Pre-flight Checklist

Before starting implementation, verify:
- [ ] Current branch is `feat/type-based-xp` or create a new branch `fix/teacher-panel-fixes`
- [ ] `dart analyze lib/` passes with 0 issues on current code
- [ ] `supabase db push --dry-run` shows no pending unrelated migrations
