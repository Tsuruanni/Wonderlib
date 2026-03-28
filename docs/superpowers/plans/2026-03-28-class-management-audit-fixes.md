# Class Management Audit Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 7 audit findings from the Class Management spec (Feature #18) — dead code removal, edit dialog description bug, silent provider failures.

**Architecture:** Straightforward cleanup — remove unused files/registrations, add a missing entity field + UI form field, and change provider error handling from silent to throwing.

**Tech Stack:** Flutter/Dart, Riverpod, Supabase

---

## File Map

| Action | File | Purpose |
|--------|------|---------|
| Delete | `lib/domain/usecases/teacher/change_student_class_usecase.dart` | Dead usecase (#1) |
| Delete | `lib/domain/usecases/user/get_classmates_usecase.dart` | Dead usecase (#2) |
| Modify | `lib/presentation/providers/usecase_providers.dart` | Remove 2 dead provider registrations + 2 dead imports |
| Modify | `lib/data/models/teacher/teacher_class_model.dart` | Remove `fromEntity` + `toJson` (#3), add `description` parsing (#5) |
| Modify | `lib/data/models/teacher/student_summary_model.dart` | Remove `fromEntity` + `toJson` (#4) |
| Modify | `lib/domain/entities/teacher.dart` | Add `description` field to `TeacherClass` (#5) |
| Modify | `lib/presentation/screens/teacher/classes_screen.dart` | Add description field to edit dialog (#5) |
| Modify | `lib/presentation/providers/teacher_provider.dart` | Throw on failure in 2 providers (#6) |

---

### Task 1: Remove dead `ChangeStudentClassUseCase` (Finding #1, #10)

**Files:**
- Delete: `lib/domain/usecases/teacher/change_student_class_usecase.dart`
- Modify: `lib/presentation/providers/usecase_providers.dart:69,208-210`

- [ ] **Step 1: Delete the dead usecase file**

```bash
rm lib/domain/usecases/teacher/change_student_class_usecase.dart
```

- [ ] **Step 2: Remove import and provider registration from `usecase_providers.dart`**

Remove line 69:
```dart
import '../../domain/usecases/teacher/change_student_class_usecase.dart';
```

Remove lines 208-210:
```dart
final changeStudentClassUseCaseProvider = Provider((ref) {
  return ChangeStudentClassUseCase(ref.watch(teacherRepositoryProvider));
});
```

- [ ] **Step 3: Verify no remaining references**

```bash
cd /Users/wonderelt/Desktop/Owlio && grep -r "changeStudentClassUseCase\|ChangeStudentClassUseCase\|ChangeStudentClassParams" lib/
```

Expected: zero matches.

- [ ] **Step 4: Run analyzer**

```bash
cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/
```

Expected: no new errors.

---

### Task 2: Remove dead `GetClassmatesUseCase` (Finding #2)

**Files:**
- Delete: `lib/domain/usecases/user/get_classmates_usecase.dart`
- Modify: `lib/presentation/providers/usecase_providers.dart:93,501-503`

- [ ] **Step 1: Delete the dead usecase file**

```bash
rm lib/domain/usecases/user/get_classmates_usecase.dart
```

- [ ] **Step 2: Remove import and provider registration from `usecase_providers.dart`**

Remove line 93 (will be line 92 after Task 1 edit):
```dart
import '../../domain/usecases/user/get_classmates_usecase.dart';
```

Remove lines 501-503 (shifted after Task 1 edit):
```dart
final getClassmatesUseCaseProvider = Provider((ref) {
  return GetClassmatesUseCase(ref.watch(userRepositoryProvider));
});
```

- [ ] **Step 3: Verify no remaining references**

```bash
cd /Users/wonderelt/Desktop/Owlio && grep -r "getClassmatesUseCase\|GetClassmatesUseCase\|GetClassmatesParams" lib/
```

Expected: zero matches.

- [ ] **Step 4: Run analyzer**

```bash
cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/
```

Expected: no new errors.

---

### Task 3: Remove dead model methods (Findings #3, #4)

**Files:**
- Modify: `lib/data/models/teacher/teacher_class_model.dart:42-58,74-90`
- Modify: `lib/data/models/teacher/student_summary_model.dart:40-56,71-87`

- [ ] **Step 1: Remove `fromEntity` and `toJson` from `TeacherClassModel`**

Remove the `fromEntity` factory (lines 42-58):
```dart
  factory TeacherClassModel.fromEntity(TeacherClass entity) {
    return TeacherClassModel(
      id: entity.id,
      name: entity.name,
      grade: entity.grade,
      academicYear: entity.academicYear,
      studentCount: entity.studentCount,
      avgProgress: entity.avgProgress,
      avgXp: entity.avgXp,
      avgStreak: entity.avgStreak,
      totalReadingTime: entity.totalReadingTime,
      completedBooks: entity.completedBooks,
      activeLast30d: entity.activeLast30d,
      totalVocabWords: entity.totalVocabWords,
      createdAt: entity.createdAt,
    );
  }
```

Remove the `toJson` method (lines 74-90):
```dart
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'grade': grade,
      'academic_year': academicYear,
      'student_count': studentCount,
      'avg_progress': avgProgress,
      'avg_xp': avgXp,
      'avg_streak': avgStreak,
      'total_reading_time': totalReadingTime,
      'completed_books': completedBooks,
      'active_last_30d': activeLast30d,
      'total_vocab_words': totalVocabWords,
      'created_at': createdAt?.toIso8601String(),
    };
  }
```

- [ ] **Step 2: Remove `fromEntity` and `toJson` from `StudentSummaryModel`**

Remove the `fromEntity` factory (lines 40-56):
```dart
  factory StudentSummaryModel.fromEntity(StudentSummary entity) {
    return StudentSummaryModel(
      id: entity.id,
      firstName: entity.firstName,
      lastName: entity.lastName,
      studentNumber: entity.studentNumber,
      username: entity.username,
      email: entity.email,
      avatarUrl: entity.avatarUrl,
      xp: entity.xp,
      level: entity.level,
      currentStreak: entity.currentStreak,
      booksRead: entity.booksRead,
      avgProgress: entity.avgProgress,
      passwordPlain: entity.passwordPlain,
    );
  }
```

Remove the `toJson` method (lines 71-87):
```dart
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'student_number': studentNumber,
      'username': username,
      'email': email,
      'avatar_url': avatarUrl,
      'xp': xp,
      'level': level,
      'streak': currentStreak,
      'books_read': booksRead,
      'avg_progress': avgProgress,
      'password_plain': passwordPlain,
    };
  }
```

- [ ] **Step 3: Run analyzer**

```bash
cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/
```

Expected: no new errors.

---

### Task 4: Fix edit dialog missing description (Finding #5)

**Files:**
- Modify: `lib/domain/entities/teacher.dart:23-58` — add `description` field to `TeacherClass`
- Modify: `lib/data/models/teacher/teacher_class_model.dart:22-40` — parse `description` in `fromJson`, add to constructor + `toEntity`
- Modify: `lib/presentation/screens/teacher/classes_screen.dart:263-347` — add description field to edit dialog

- [ ] **Step 1: Add `description` to `TeacherClass` entity**

In `lib/domain/entities/teacher.dart`, add `this.description` to `TeacherClass` constructor and field:

```dart
class TeacherClass extends Equatable {

  const TeacherClass({
    required this.id,
    required this.name,
    required this.grade,
    this.academicYear,
    this.description,
    required this.studentCount,
    required this.avgProgress,
    this.avgXp = 0,
    this.avgStreak = 0,
    this.totalReadingTime = 0,
    this.completedBooks = 0,
    this.activeLast30d = 0,
    this.totalVocabWords = 0,
    this.createdAt,
  });
  final String id;
  final String name;
  final int grade;
  final String? academicYear;
  final String? description;
  final int studentCount;
  // ... rest unchanged
```

Add `description` to `props`:
```dart
  @override
  List<Object?> get props => [id, name, grade, academicYear, description, studentCount, avgProgress, avgXp, avgStreak, totalReadingTime, completedBooks, activeLast30d, totalVocabWords, createdAt];
```

- [ ] **Step 2: Update `TeacherClassModel` to parse and pass `description`**

In `lib/data/models/teacher/teacher_class_model.dart`:

Add `this.description` to constructor and field:
```dart
  const TeacherClassModel({
    required this.id,
    required this.name,
    required this.grade,
    this.academicYear,
    this.description,
    required this.studentCount,
    // ...
  });
```

Add `description` field:
```dart
  final String? description;
```

Add to `fromJson`:
```dart
      description: json['description'] as String?,
```

Add to `toEntity`:
```dart
  TeacherClass toEntity() {
    return TeacherClass(
      id: id,
      name: name,
      grade: grade,
      academicYear: academicYear,
      description: description,
      studentCount: studentCount,
      // ... rest unchanged
```

- [ ] **Step 3: Add description field to `_showEditClassDialog`**

In `lib/presentation/screens/teacher/classes_screen.dart`, in `_showEditClassDialog` method, add a `descController` initialized with the existing description, and a `TextFormField` after the grade dropdown:

```dart
  void _showEditClassDialog(BuildContext context, WidgetRef ref, TeacherClass classItem) {
    final nameController = TextEditingController(text: classItem.name);
    final descController = TextEditingController(text: classItem.description ?? '');
    final formKey = GlobalKey<FormState>();
    int? selectedGrade = classItem.grade;
```

Add the TextFormField after the grade `DropdownButtonFormField` closing:
```dart
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
```

Pass description in the `UpdateClassParams`:
```dart
                final useCase = ref.read(updateClassUseCaseProvider);
                final result = await useCase(
                  UpdateClassParams(
                    classId: classItem.id,
                    name: name,
                    grade: selectedGrade!,
                    description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                  ),
                );
```

- [ ] **Step 4: Run analyzer**

```bash
cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/
```

Expected: no new errors.

---

### Task 5: Fix silent provider failures (Finding #6)

**Files:**
- Modify: `lib/presentation/providers/teacher_provider.dart:62-72,83-92`

- [ ] **Step 1: Fix `teacherClassesProvider` to throw on failure**

In `lib/presentation/providers/teacher_provider.dart`, change lines 68-71:

Before:
```dart
  return result.fold(
    (failure) => <TeacherClass>[],
    (classes) => classes,
  );
```

After:
```dart
  return result.fold(
    (failure) => throw Exception(failure.message),
    (classes) => classes,
  );
```

- [ ] **Step 2: Fix `classStudentsProvider` to throw on failure**

Change lines 88-91:

Before:
```dart
  return result.fold(
    (failure) => [],
    (students) => students,
  );
```

After:
```dart
  return result.fold(
    (failure) => throw Exception(failure.message),
    (students) => students,
  );
```

- [ ] **Step 3: Run analyzer**

```bash
cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/
```

Expected: no new errors.

---

### Task 6: Update spec and commit

**Files:**
- Modify: `docs/specs/18-class-management.md`

- [ ] **Step 1: Update finding statuses in spec**

In `docs/specs/18-class-management.md`, update the audit findings table — change all TODO items to Fixed for findings #1-6 and #10. Update the Checklist Result section to reflect PASS on Dead Code and the fixes on Code Quality and Edge Cases.

- [ ] **Step 2: Update Known Issues section**

Remove fixed items from Known Issues, keep only items #9 (missing index — skipped).

- [ ] **Step 3: Final analyzer run**

```bash
cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/
```

Expected: no errors.

- [ ] **Step 4: Commit all changes**

```bash
cd /Users/wonderelt/Desktop/Owlio && git add -A && git commit -m "docs: Class Management audit & spec + fix 7 findings"
```
