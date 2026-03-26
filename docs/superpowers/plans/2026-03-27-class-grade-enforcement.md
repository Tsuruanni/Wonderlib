# Class Grade Enforcement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce `classes.grade` as NOT NULL across DB, usecases, repositories, and UI so that `get_user_learning_paths` RPC always has a valid grade to match.

**Architecture:** DB migration fixes existing nulls and adds NOT NULL + CHECK(1-12). RPC, usecases, repositories, and both UIs (teacher app + admin panel) updated to require grade on create/update. Entity/model updated to non-nullable.

**Tech Stack:** PostgreSQL migration, Dart (Flutter), Supabase RPC, Riverpod

**Spec:** `docs/superpowers/specs/2026-03-27-class-grade-enforcement-design.md`

---

### Task 1: DB migration — Fix null grades + NOT NULL constraint

**Files:**
- Create: `supabase/migrations/20260327000006_enforce_class_grade_not_null.sql`

- [ ] **Step 1: Write migration**

```sql
-- Enforce classes.grade as NOT NULL with range check.
-- Auto-fix existing null grades from class name heuristics.

DO $$
DECLARE
  r RECORD;
  v_extracted INT;
BEGIN
  FOR r IN SELECT id, name FROM classes WHERE grade IS NULL LOOP
    v_extracted := (regexp_match(r.name, '^(\d+)'))[1]::INT;
    IF v_extracted IS NOT NULL AND v_extracted BETWEEN 1 AND 12 THEN
      UPDATE classes SET grade = v_extracted WHERE id = r.id;
      RAISE NOTICE 'Auto-fixed class "%" → grade %', r.name, v_extracted;
    ELSE
      UPDATE classes SET grade = 5 WHERE id = r.id;
      RAISE NOTICE 'WARNING: Set class "%" to default grade 5', r.name;
    END IF;
  END LOOP;
END $$;

ALTER TABLE classes ALTER COLUMN grade SET NOT NULL;
ALTER TABLE classes ADD CONSTRAINT classes_grade_range CHECK (grade BETWEEN 1 AND 12);
```

- [ ] **Step 2: Dry-run migration**

Run: `supabase db push --dry-run`
Expected: Shows the migration will be applied, no errors.

- [ ] **Step 3: Push migration**

Run: `supabase db push`
Expected: Migration applied successfully. "Test-A" gets grade 5, "6-A" gets grade 6.

- [ ] **Step 4: Verify**

Run:
```bash
curl -s "https://wqkxjjakysuabjcotvim.supabase.co/rest/v1/rpc/get_user_learning_paths" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $ADMIN_JWT" \
  -H "Content-Type: application/json" \
  -d '{"p_user_id": "88888888-0002-0001-0001-000000000001"}'
```
Expected: Returns learning path data (non-empty array) instead of `[]`.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260327000006_enforce_class_grade_not_null.sql
git commit -m "fix: enforce classes.grade NOT NULL with CHECK(1-12)"
```

---

### Task 2: DB migration — Update `update_class` RPC to accept grade

**Files:**
- Create: `supabase/migrations/20260327000007_update_class_rpc_add_grade.sql`

- [ ] **Step 1: Write migration**

```sql
-- Add p_grade parameter to update_class RPC
CREATE OR REPLACE FUNCTION update_class(
  p_class_id UUID,
  p_name TEXT,
  p_grade INTEGER,
  p_description TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_caller_school_id UUID;
  v_class_school_id UUID;
BEGIN
  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  SELECT pr.school_id INTO v_caller_school_id
  FROM profiles pr WHERE pr.id = auth.uid();

  SELECT cl.school_id INTO v_class_school_id
  FROM classes cl WHERE cl.id = p_class_id;

  IF v_class_school_id IS NULL THEN
    RAISE EXCEPTION 'Class not found';
  END IF;

  IF v_caller_school_id IS DISTINCT FROM v_class_school_id THEN
    RAISE EXCEPTION 'Unauthorized: class is not in your school';
  END IF;

  UPDATE classes
  SET name = p_name, grade = p_grade, description = p_description
  WHERE classes.id = p_class_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

- [ ] **Step 2: Push migration**

Run: `supabase db push`
Expected: RPC updated successfully.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260327000007_update_class_rpc_add_grade.sql
git commit -m "feat: add grade parameter to update_class RPC"
```

---

### Task 3: Domain + Data layer — Add grade to create/update class

**Files:**
- Modify: `lib/domain/entities/teacher.dart:22-58`
- Modify: `lib/data/models/teacher/teacher_class_model.dart`
- Modify: `lib/domain/repositories/teacher_repository.dart:82-87,116-120`
- Modify: `lib/domain/usecases/teacher/create_class_usecase.dart`
- Modify: `lib/domain/usecases/teacher/update_class_usecase.dart`
- Modify: `lib/data/repositories/supabase/supabase_teacher_repository.dart:451-469,563-580`

- [ ] **Step 1: Update `TeacherClass` entity — make grade non-nullable**

In `lib/domain/entities/teacher.dart`, change:

```dart
// OLD
  const TeacherClass({
    required this.id,
    required this.name,
    this.grade,
// NEW
  const TeacherClass({
    required this.id,
    required this.name,
    required this.grade,
```

```dart
// OLD
  final int? grade;
// NEW
  final int grade;
```

- [ ] **Step 2: Update `TeacherClassModel` — parse grade as non-nullable**

In `lib/data/models/teacher/teacher_class_model.dart`, change:

```dart
// OLD constructor
    this.grade,
// NEW constructor
    required this.grade,
```

```dart
// OLD fromJson
      grade: json['grade'] as int?,
// NEW fromJson
      grade: (json['grade'] as num?)?.toInt() ?? 0,
```

```dart
// OLD field
  final int? grade;
// NEW field
  final int grade;
```

- [ ] **Step 3: Update `TeacherRepository` interface**

In `lib/domain/repositories/teacher_repository.dart`, change `createClass`:

```dart
// OLD
  Future<Either<Failure, String>> createClass({
    required String schoolId,
    required String name,
    String? description,
  });
// NEW
  Future<Either<Failure, String>> createClass({
    required String schoolId,
    required String name,
    required int grade,
    String? description,
  });
```

Change `updateClass`:

```dart
// OLD
  Future<Either<Failure, void>> updateClass({
    required String classId,
    required String name,
    String? description,
  });
// NEW
  Future<Either<Failure, void>> updateClass({
    required String classId,
    required String name,
    required int grade,
    String? description,
  });
```

- [ ] **Step 4: Update `CreateClassUseCase` params**

In `lib/domain/usecases/teacher/create_class_usecase.dart`, change:

```dart
// OLD
class CreateClassParams {
  const CreateClassParams({
    required this.schoolId,
    required this.name,
    this.description,
  });
  final String schoolId;
  final String name;
  final String? description;
}
// NEW
class CreateClassParams {
  const CreateClassParams({
    required this.schoolId,
    required this.name,
    required this.grade,
    this.description,
  });
  final String schoolId;
  final String name;
  final int grade;
  final String? description;
}
```

Update `call()`:

```dart
// OLD
    return _repository.createClass(
      schoolId: params.schoolId,
      name: params.name,
      description: params.description,
    );
// NEW
    return _repository.createClass(
      schoolId: params.schoolId,
      name: params.name,
      grade: params.grade,
      description: params.description,
    );
```

- [ ] **Step 5: Update `UpdateClassUseCase` params**

In `lib/domain/usecases/teacher/update_class_usecase.dart`, change:

```dart
// OLD
class UpdateClassParams {
  const UpdateClassParams({
    required this.classId,
    required this.name,
    this.description,
  });
  final String classId;
  final String name;
  final String? description;
}
// NEW
class UpdateClassParams {
  const UpdateClassParams({
    required this.classId,
    required this.name,
    required this.grade,
    this.description,
  });
  final String classId;
  final String name;
  final int grade;
  final String? description;
}
```

Update `call()`:

```dart
// OLD
    return _repository.updateClass(
      classId: params.classId,
      name: params.name,
      description: params.description,
    );
// NEW
    return _repository.updateClass(
      classId: params.classId,
      name: params.name,
      grade: params.grade,
      description: params.description,
    );
```

- [ ] **Step 6: Update `SupabaseTeacherRepository` implementation**

In `lib/data/repositories/supabase/supabase_teacher_repository.dart`, change `createClass`:

```dart
// OLD
  Future<Either<Failure, String>> createClass({
    required String schoolId,
    required String name,
    String? description,
  }) async {
    try {
      final response = await _supabase.from(DbTables.classes).insert({
        'school_id': schoolId,
        'name': name,
        'description': description,
      }).select('id').single();
// NEW
  Future<Either<Failure, String>> createClass({
    required String schoolId,
    required String name,
    required int grade,
    String? description,
  }) async {
    try {
      final response = await _supabase.from(DbTables.classes).insert({
        'school_id': schoolId,
        'name': name,
        'grade': grade,
        'description': description,
      }).select('id').single();
```

Change `updateClass`:

```dart
// OLD
  Future<Either<Failure, void>> updateClass({
    required String classId,
    required String name,
    String? description,
  }) async {
    try {
      await _supabase.rpc(RpcFunctions.updateClass, params: {
        'p_class_id': classId,
        'p_name': name,
        'p_description': description,
      });
// NEW
  Future<Either<Failure, void>> updateClass({
    required String classId,
    required String name,
    required int grade,
    String? description,
  }) async {
    try {
      await _supabase.rpc(RpcFunctions.updateClass, params: {
        'p_class_id': classId,
        'p_name': name,
        'p_grade': grade,
        'p_description': description,
      });
```

- [ ] **Step 7: Run analyze**

Run: `dart analyze lib/`
Expected: Errors in `classes_screen.dart` (missing `grade` param in `CreateClassParams` and `UpdateClassParams`). This is expected — fixed in Task 4.

- [ ] **Step 8: Commit**

```bash
git add lib/domain/entities/teacher.dart lib/data/models/teacher/teacher_class_model.dart lib/domain/repositories/teacher_repository.dart lib/domain/usecases/teacher/create_class_usecase.dart lib/domain/usecases/teacher/update_class_usecase.dart lib/data/repositories/supabase/supabase_teacher_repository.dart
git commit -m "feat: add required grade to class create/update domain+data layer"
```

---

### Task 4: Teacher app — Add grade dropdown to create + edit dialogs

**Files:**
- Modify: `lib/presentation/screens/teacher/classes_screen.dart:146-305`

- [ ] **Step 1: Update `_showCreateClassDialog` — add grade dropdown**

In `lib/presentation/screens/teacher/classes_screen.dart`, replace the create dialog method:

```dart
  void _showCreateClassDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    int? selectedGrade;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Create New Class'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Class Name *',
                    hintText: 'e.g., 5A, Grade 7',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a class name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Grade *',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(12, (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text('Grade ${i + 1}'),
                  )),
                  validator: (value) => value == null ? 'Please select a grade' : null,
                  onChanged: (value) => setDialogState(() => selectedGrade = value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'e.g., Morning English class',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                Navigator.pop(dialogContext);
                await _createClass(
                  context,
                  ref,
                  nameController.text.trim(),
                  selectedGrade!,
                  descController.text.trim().isEmpty ? null : descController.text.trim(),
                );
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 2: Update `_createClass` — accept grade param**

```dart
// OLD
  Future<void> _createClass(
    BuildContext context,
    WidgetRef ref,
    String name,
    String? description,
  ) async {
// NEW
  Future<void> _createClass(
    BuildContext context,
    WidgetRef ref,
    String name,
    int grade,
    String? description,
  ) async {
```

And update the usecase call:

```dart
// OLD
    final result = await useCase(CreateClassParams(
      schoolId: user.schoolId,
      name: name,
      description: description,
    ),);
// NEW
    final result = await useCase(CreateClassParams(
      schoolId: user.schoolId,
      name: name,
      grade: grade,
      description: description,
    ),);
```

- [ ] **Step 3: Update `_showEditClassDialog` — add grade dropdown**

Replace the edit dialog method:

```dart
  void _showEditClassDialog(BuildContext context, WidgetRef ref, TeacherClass classItem) {
    final nameController = TextEditingController(text: classItem.name);
    final formKey = GlobalKey<FormState>();
    int? selectedGrade = classItem.grade;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit Class'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Class Name *',
                    hintText: 'e.g., 5A, Grade 7',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a class name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedGrade,
                  decoration: const InputDecoration(
                    labelText: 'Grade *',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(12, (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text('Grade ${i + 1}'),
                  )),
                  validator: (value) => value == null ? 'Please select a grade' : null,
                  onChanged: (value) => setDialogState(() => selectedGrade = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                Navigator.pop(dialogContext);
                final name = nameController.text.trim();
                final useCase = ref.read(updateClassUseCaseProvider);
                final result = await useCase(
                  UpdateClassParams(
                    classId: classItem.id,
                    name: name,
                    grade: selectedGrade!,
                  ),
                );

                if (!context.mounted) return;

                result.fold(
                  (failure) {
                    showAppSnackBar(context, 'Error: ${failure.message}', type: SnackBarType.error);
                  },
                  (_) {
                    ref.invalidate(currentTeacherClassesProvider);
                    showAppSnackBar(context, 'Class updated', type: SnackBarType.success);
                  },
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 4: Run analyze**

Run: `dart analyze lib/`
Expected: 0 errors, 0 warnings.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/teacher/classes_screen.dart
git commit -m "feat: add grade dropdown to teacher create/edit class dialogs"
```

---

### Task 5: Admin panel — Add grade validation

**Files:**
- Modify: `owlio_admin/lib/features/classes/screens/class_edit_screen.dart:428-436`

- [ ] **Step 1: Add validator to grade field**

In `owlio_admin/lib/features/classes/screens/class_edit_screen.dart`, replace the grade TextFormField (around line 429):

```dart
// OLD
                          TextFormField(
                            controller: _gradeController,
                            decoration: const InputDecoration(
                              labelText: 'Sınıf Seviyesi',
                              hintText: 'ör. 5, 7, 12',
                            ),
                            keyboardType: TextInputType.number,
                          ),
// NEW
                          TextFormField(
                            controller: _gradeController,
                            decoration: const InputDecoration(
                              labelText: 'Sınıf Seviyesi *',
                              hintText: 'ör. 5, 7, 12',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Sınıf seviyesi zorunludur';
                              }
                              final grade = int.tryParse(value.trim());
                              if (grade == null || grade < 1 || grade > 12) {
                                return '1-12 arası bir değer girin';
                              }
                              return null;
                            },
                          ),
```

- [ ] **Step 2: Run analyze**

Run: `dart analyze owlio_admin/lib/`
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add owlio_admin/lib/features/classes/screens/class_edit_screen.dart
git commit -m "feat(admin): add required validation to class grade field"
```

---

### Task 6: Remove debug logs from vocabulary provider

**Files:**
- Modify: `lib/presentation/providers/vocabulary_provider.dart`

- [ ] **Step 1: Remove debug logging added during investigation**

Remove the `import 'package:flutter/foundation.dart';` line (line 1) and all `debugPrint('🔍 ...')` lines that were added to `learningPathProvider` and `userLearningPathsProvider` during the performance investigation.

Restore `learningPathProvider` to use the original `Future.wait` without the tracking wrapper:

```dart
final learningPathProvider = FutureProvider<List<PathUnitData>>((ref) async {
  // Fetch all independent providers in parallel (not sequentially)
  final futures = await Future.wait([
    ref.watch(userLearningPathsProvider.future),       // [0]
    ref.watch(allWordListsProvider.future),             // [1]
    ref.watch(userWordListProgressProvider.future),     // [2]
    ref.watch(nodeCompletionsProvider.future),          // [3]
    ref.watch(completedBookIdsProvider.future),         // [4]
    ref.watch(todayReviewSessionProvider.future)        // [5]
        .catchError((_) => null),
    ref.watch(totalDueWordsForReviewProvider.future)    // [6]
        .catchError((_) => 0),
  ]);
```

Restore `userLearningPathsProvider`:

```dart
final userLearningPathsProvider = FutureProvider<List<LearningPath>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  final useCase = ref.watch(getUserLearningPathsUseCaseProvider);
  final result = await useCase(GetUserLearningPathsParams(userId: user.id));
  return result.fold((_) => [], (paths) => paths);
});
```

- [ ] **Step 2: Run analyze**

Run: `dart analyze lib/`
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/providers/vocabulary_provider.dart
git commit -m "chore: remove debug logging from vocabulary provider"
```

---

### Task 7: Verify end-to-end

- [ ] **Step 1: Run full analyze**

Run: `dart analyze lib/ && dart analyze owlio_admin/lib/`
Expected: 0 errors on both.

- [ ] **Step 2: Hot restart app and test vocabulary screen**

Run: `flutter run -d chrome`
Navigate to `/#/vocabulary`.
Expected: Learning path renders with units and word lists (no longer blank).

- [ ] **Step 3: Test class creation in teacher app**

Login as teacher@demo.com. Go to Classes. Create a new class.
Expected: Grade dropdown is required. Class is created with grade.

- [ ] **Step 4: Test class edit in teacher app**

Edit an existing class.
Expected: Grade dropdown shows current grade. Can change grade.
