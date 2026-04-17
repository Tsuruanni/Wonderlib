# Teacher Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give teachers a Library tab that mirrors the student library, lets them read books in "teacher preview" mode (answers pre-revealed, no progress saved), and assign books from the detail screen — reusing the existing assign flow and backend.

**Architecture:** Role-derived `isTeacherPreviewModeProvider` (true when current user is a teacher) gates four behaviors: (1) rendering a "Teacher Preview" banner in the reader, (2) suppressing all reading-progress writes, (3) forcing every inline activity into the widget's existing `isCompleted: true, wasCorrect: true` state (so correct answers show with the same visuals students see after answering correctly), (4) pre-filling the book quiz `_answers` map with correct answers and replacing Submit with Exit. No new domain code, no backend changes, no widget modifications — only call-site changes.

**Tech Stack:** Flutter, Riverpod, go_router, Supabase (unchanged).

**Spec reference:** `docs/superpowers/specs/2026-04-17-teacher-library-design.md`

---

## Preliminary Context for the Engineer

Before you start, read these (5 min each):

- `CLAUDE.md` at repo root — architecture rules (Screen → Provider → UseCase, no `import 'package:flutter'` in domain, etc.)
- `docs/superpowers/specs/2026-04-17-teacher-library-design.md` — the approved spec this plan implements
- `docs/specs/17-assignment-system.md` §2 only — understand that the assign flow is reused unchanged
- Skim `lib/presentation/widgets/reader/reader_activity_block.dart` — this is the single choke point for inline activities
- Skim `lib/presentation/screens/reader/reader_screen.dart` lines 60-220 — all three progress writes live here

`isTeacherProvider` is defined at `lib/presentation/providers/auth_provider.dart:48` as `Provider<bool>` (returns true for teacher/head/admin roles). The `UserRole` enum comes from `owlio_shared`. Every subsequent task watches `isTeacherPreviewModeProvider` (created in Task 1) rather than `isTeacherProvider` directly.

Assume Supabase access and test users are already configured per `CLAUDE.md`. Login as `teacher@demo.com` / `Test1234` to verify teacher flows, `active@demo.com` for student regression.

---

## File Structure

**New files (2):**
- `lib/presentation/providers/teacher_preview_provider.dart` — the `isTeacherPreviewModeProvider`.
- `lib/presentation/widgets/reader/teacher_preview_banner.dart` — the banner shown beneath the reader AppBar.

**Modified files (6):**
- `lib/presentation/widgets/shell/teacher_shell_scaffold.dart` — add Library destination (bottom nav + sidebar).
- `lib/app/router.dart` — add `/teacher/library` branch pointing to existing `LibraryScreen`; add `teacherLibrary` route constant.
- `lib/presentation/screens/library/book_detail_screen.dart` — teacher FAB shows both **Start Reading** and **Assign Book** (currently only Assign).
- `lib/presentation/screens/reader/reader_screen.dart` — render banner below AppBar when in preview; early-return on all three progress write methods when in preview.
- `lib/presentation/widgets/reader/reader_activity_block.dart` — when in preview, force `isCompleted = true, wasCorrect = true` for the activity being built.
- `lib/presentation/widgets/reader/reader_sidebar.dart` — `_BookQuizTile` unlocks for teachers so they can tap through to the quiz (without this, the tile stays greyed out because `allChaptersRead` is never true for teachers).
- `lib/presentation/screens/quiz/book_quiz_screen.dart` — when in preview: bypass the `completionPercentage < 100` guard; pre-fill `_answers` with correct answers on first load; replace Submit button with **Exit Preview**.

**Tests:**
- `test/unit/presentation/providers/teacher_preview_provider_test.dart` — unit test the provider's three cases.

No new files in `domain/` or `data/`. No migrations. No RPC changes. No model changes. The whole feature ships in the presentation layer.

---

## Task 1: Create `isTeacherPreviewModeProvider`

**Files:**
- Create: `lib/presentation/providers/teacher_preview_provider.dart`
- Test: `test/unit/presentation/providers/teacher_preview_provider_test.dart`

Foundation for every subsequent task. The provider returns `true` iff the current user's role is `teacher`.

- [ ] **Step 1: Verify the current-user / role source**

Run: `grep -n "isTeacherProvider" lib/presentation/providers/auth_provider.dart | head -20`

Expected: find an existing provider like `isTeacherProvider` and/or `currentUserProvider` that exposes either a `User` (with a `role` field) or a boolean `isTeacher`. Note which one(s) exist — you will use them verbatim, not re-invent.

If `isTeacherProvider` already exists (it does, per `book_detail_screen.dart:363`), your new provider simply re-exports it under a preview-mode name. The new name is what every other file watches so the semantic is "teacher preview mode," not "user is a teacher." Keeping the names distinct lets the gate evolve later without a repo-wide rename.

- [ ] **Step 2: Write the failing test**

Create `test/unit/presentation/providers/teacher_preview_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owlio/presentation/providers/teacher_preview_provider.dart';
import 'package:owlio/presentation/providers/auth_provider.dart';

void main() {
  test('returns true when isTeacherProvider is true', () {
    final container = ProviderContainer(overrides: [
      isTeacherProvider.overrideWith((ref) => true),
    ]);
    addTearDown(container.dispose);

    expect(container.read(isTeacherPreviewModeProvider), isTrue);
  });

  test('returns false when isTeacherProvider is false', () {
    final container = ProviderContainer(overrides: [
      isTeacherProvider.overrideWith((ref) => false),
    ]);
    addTearDown(container.dispose);

    expect(container.read(isTeacherPreviewModeProvider), isFalse);
  });
}
```

**Note:** If `isTeacherProvider`'s actual type is not a plain `Provider<bool>` (e.g. it wraps an `AsyncValue`), adjust the override syntax accordingly. Match whatever the real provider looks like after Step 1.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/unit/presentation/providers/teacher_preview_provider_test.dart`
Expected: FAIL — `teacher_preview_provider.dart` does not exist yet.

- [ ] **Step 4: Implement the provider**

Create `lib/presentation/providers/teacher_preview_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

/// True when the current user is a teacher, meaning the reader/quiz/activities
/// should run in "preview mode": correct answers revealed, no progress saved,
/// all access gates bypassed.
///
/// Role-derived rather than flag-driven because teachers never consume book
/// content as learners — if they're in the reader, they're previewing.
final isTeacherPreviewModeProvider = Provider<bool>((ref) {
  return ref.watch(isTeacherProvider);
});
```

If `isTeacherProvider` turned out to be async in Step 1, wrap accordingly:
```dart
final isTeacherPreviewModeProvider = Provider<bool>((ref) {
  return ref.watch(isTeacherProvider).valueOrNull ?? false;
});
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/unit/presentation/providers/teacher_preview_provider_test.dart`
Expected: PASS, both cases.

- [ ] **Step 6: Analyze**

Run: `dart analyze lib/presentation/providers/teacher_preview_provider.dart test/unit/presentation/providers/teacher_preview_provider_test.dart`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/providers/teacher_preview_provider.dart \
        test/unit/presentation/providers/teacher_preview_provider_test.dart
git commit -m "feat(teacher-library): add isTeacherPreviewModeProvider"
```

---

## Task 2: Create `TeacherPreviewBanner` widget

**Files:**
- Create: `lib/presentation/widgets/reader/teacher_preview_banner.dart`

Thin strip rendered below the reader AppBar. Hidden for students, visible for teachers.

- [ ] **Step 1: Create the widget**

Create `lib/presentation/widgets/reader/teacher_preview_banner.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../providers/teacher_preview_provider.dart';

/// Thin banner rendered beneath the reader AppBar when the current user is a
/// teacher. Communicates that answers are revealed and no progress is saved,
/// so the teacher cannot mistake the preview state for a broken student view.
class TeacherPreviewBanner extends ConsumerWidget {
  const TeacherPreviewBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPreview = ref.watch(isTeacherPreviewModeProvider);
    if (!isPreview) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.wasp.withValues(alpha: 0.18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.visibility_outlined,
              size: 16, color: AppColors.waspDark),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Teacher Preview — answers shown, no progress saved',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.waspDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
```

**Note:** If `AppColors.wasp` / `waspDark` are not exactly named that in `lib/app/theme.dart`, substitute the nearest warning/info tint from the theme. Use `grep -n "Color(0xFF" lib/app/theme.dart | head` to find the palette. Do not introduce hard-coded hex values — reuse theme tokens.

- [ ] **Step 2: Analyze**

Run: `dart analyze lib/presentation/widgets/reader/teacher_preview_banner.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/reader/teacher_preview_banner.dart
git commit -m "feat(teacher-library): add TeacherPreviewBanner widget"
```

---

## Task 3: Add Library destination to teacher shell

**Files:**
- Modify: `lib/presentation/widgets/shell/teacher_shell_scaffold.dart:17-42` (add 5th entry to `_destinations`)

The shell renders `_destinations` as a bottom nav on mobile and a sidebar on wide layouts. Both paths iterate over `_destinations`, so adding one entry extends both UIs.

- [ ] **Step 1: Edit `_destinations` list**

In `lib/presentation/widgets/shell/teacher_shell_scaffold.dart`, replace the `_destinations` block (lines 17-42) with:

```dart
  static const _destinations = <_NavItem>[
    _NavItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
      color: AppColors.primary,
    ),
    _NavItem(
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
      label: 'Classes',
      color: AppColors.secondary,
    ),
    _NavItem(
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment,
      label: 'Assignments',
      color: AppColors.wasp,
    ),
    _NavItem(
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
      label: 'Reports',
      color: Color(0xFF9B59B6),
    ),
    _NavItem(
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
      label: 'Library',
      color: AppColors.primaryDark,
    ),
  ];
```

The 5th entry must be last — the router branch index assigned in Task 4 must match this position.

- [ ] **Step 2: Analyze**

Run: `dart analyze lib/presentation/widgets/shell/teacher_shell_scaffold.dart`
Expected: `No issues found!` (Library destination doesn't have a branch yet — that comes in Task 4; scaffold itself still compiles.)

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/shell/teacher_shell_scaffold.dart
git commit -m "feat(teacher-library): add Library destination to teacher shell"
```

---

## Task 4: Add `/teacher/library` branch to router

**Files:**
- Modify: `lib/app/router.dart` (add route constant + branch)

Wire the 5th shell tab to `LibraryScreen`. Because `bookLockProvider` already returns `empty` for teachers, the library grid reuses its student implementation unchanged and shows every book.

- [ ] **Step 1: Locate teacher shell branches**

Run: `grep -n "teacher\|TeacherShell\|StatefulShellBranch" lib/app/router.dart | head -40`

Expected: find the `StatefulShellRoute.indexedStack` or similar block for the teacher shell, with 4 existing `StatefulShellBranch(...)` entries for Dashboard/Classes/Assignments/Reports. You will add a 5th.

- [ ] **Step 2: Add route constant**

In `lib/app/router.dart`, in the `AppRoutes` class (search for `static const teacherReports` or similar existing teacher routes), add:

```dart
  static const teacherLibrary = '/teacher/library';
```

- [ ] **Step 3: Add the branch**

After the Reports branch in the teacher shell definition, add:

```dart
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.teacherLibrary,
                  builder: (context, state) => const LibraryScreen(),
                ),
              ],
            ),
```

If `LibraryScreen` is not already imported in `router.dart`, add the import at the top:

```dart
import '../presentation/screens/library/library_screen.dart';
```

Do NOT create a teacher-specific library screen. The existing `LibraryScreen` works because `bookLockProvider` already bypasses for teachers.

- [ ] **Step 4: Analyze**

Run: `dart analyze lib/app/router.dart`
Expected: `No issues found!`

- [ ] **Step 5: Manual smoke check**

Run: `flutter run -d chrome` (or your usual target)

- Log in as `teacher@demo.com` / `Test1234`.
- Confirm 5 tabs in the teacher shell: Dashboard, Classes, Assignments, Reports, **Library**.
- Tap Library → the student library grid renders with all books (no lock overlays).
- Tap a book → `BookDetailScreen` opens. (You will improve the FAB in Task 5.)

- [ ] **Step 6: Commit**

```bash
git add lib/app/router.dart
git commit -m "feat(teacher-library): wire /teacher/library route to LibraryScreen"
```

---

## Task 5: Teacher FAB shows Start Reading + Assign

**Files:**
- Modify: `lib/presentation/screens/library/book_detail_screen.dart:362-394` (teacher branch of `_BookDetailFAB.build`)

Currently the teacher branch renders only an "Assign Book" button and returns early, so teachers never see Start Reading. Change that: teachers see Start Reading + Assign Book. The quiz entry lives in the reader sidebar (Task 9), not in book detail — this keeps book detail's two primary actions clean and matches spec §11.4.

- [ ] **Step 1: Read the current FAB build for context**

Run: `sed -n '340,475p' lib/presentation/screens/library/book_detail_screen.dart`

Expected: see the teacher early-return at lines 365-393, the quiz-ready block at 401-426, and the student Start Reading block at 429-469. Note the shape of `GameButton` usage and the route paths used (`AppRoutes.teacherCreateAssignment`, `AppRoutes.readerPath`, `AppRoutes.bookQuizPath`). You will reuse those verbatim.

- [ ] **Step 2: Rewrite `_BookDetailFAB.build`**

Replace the entire body of `_BookDetailFAB.build` (from `final isTeacher = ...` through the final `return SafeArea(... Student sees ...)` block — roughly lines 362-471) with the structure below. The existing `_NavItem`, `GameButton`, imports, and helper vars (`chaptersAsync`, `progress`, etc.) remain unchanged — only the decision tree in `build()` changes.

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTeacher = ref.watch(isTeacherProvider);

    if (isTeacher) {
      return _TeacherBookDetailActions(
        bookId: bookId,
        bookTitle: bookTitle,
        chapterCount: chapterCount,
        chaptersAsync: chaptersAsync,
      );
    }

    // Hide button if book is completed (student only)
    if (isCompleted) {
      return const SizedBox.shrink();
    }

    final isQuizReady =
        ref.watch(isQuizReadyProvider(bookId)).valueOrNull ?? false;

    if (isQuizReady) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20, top: 8),
          child: Center(
            heightFactor: 1.0,
            child: SizedBox(
              width: 280,
              height: 54,
              child: GameButton(
                label: 'Take the Quiz',
                icon: AppIcons.quiz(),
                variant: GameButtonVariant.primary,
                onPressed: () {
                  context.push(AppRoutes.bookQuizPath(bookId));
                },
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20, top: 8),
        child: Center(
          heightFactor: 1.0,
          child: SizedBox(
            width: 280,
            height: 54,
            child: GameButton(
              label: hasProgress ? 'Continue Reading' : 'Start Reading',
              icon: Icon(hasProgress ? Icons.play_arrow_rounded : Icons.book_rounded),
              variant: GameButtonVariant.primary,
              onPressed: () {
                chaptersAsync.whenData((chapters) {
                  if (chapters.isEmpty) return;

                  String targetChapterId;
                  final currentChapterId = progress?.chapterId;
                  if (currentChapterId != null &&
                      currentChapterId.isNotEmpty) {
                    targetChapterId = currentChapterId;
                  } else {
                    targetChapterId = chapters.first.id;
                  }

                  context.go(AppRoutes.readerPath(bookId, targetChapterId));

                  if (userId != null) {
                    ref.read(bookDownloaderProvider.notifier).downloadBook(
                          bookId,
                          userId: userId!,
                        );
                  }
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Add `_TeacherBookDetailActions` widget**

Below the `_BookDetailFAB` class definition (at the end of the file, but before any unrelated helpers), add:

```dart
class _TeacherBookDetailActions extends ConsumerWidget {
  const _TeacherBookDetailActions({
    required this.bookId,
    required this.bookTitle,
    required this.chapterCount,
    required this.chaptersAsync,
  });

  final String bookId;
  final String bookTitle;
  final int chapterCount;
  final AsyncValue<List<Chapter>> chaptersAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20, top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 280,
              height: 54,
              child: GameButton(
                label: 'Start Reading',
                icon: const Icon(Icons.book_rounded),
                variant: GameButtonVariant.primary,
                onPressed: () {
                  chaptersAsync.whenData((chapters) {
                    if (chapters.isEmpty) return;
                    context.go(AppRoutes.readerPath(bookId, chapters.first.id));
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 280,
              height: 54,
              child: GameButton(
                label: 'Assign Book',
                icon: const Icon(Icons.assignment_add),
                variant: GameButtonVariant.secondary,
                onPressed: () {
                  context.push(
                    AppRoutes.teacherCreateAssignment,
                    extra: {
                      'bookId': bookId,
                      'bookTitle': bookTitle,
                      'chapterCount': chapterCount,
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Rationale for stacked (not side-by-side): both buttons fit the existing 280-px island width and keep the primary action (Start Reading) on top, matching the student layout's 54-px tap target. Side-by-side would need two 130-px buttons and break touch-target guidance.

- [ ] **Step 4: Analyze**

Run: `dart analyze lib/presentation/screens/library/book_detail_screen.dart`
Expected: `No issues found!`

- [ ] **Step 5: Manual smoke check**

With the app still running from Task 4:

- Reload, log in as `teacher@demo.com`.
- Navigate: Library → tap any book → Book Detail opens.
- Confirm two stacked buttons: **Start Reading** (primary/filled) and **Assign Book** (secondary).
- Tap **Start Reading** → reader opens on the first chapter. (Banner work is Task 6. You should at least see the reader content load.)
- Return to book detail → tap **Assign Book** → Create Assignment screen opens with the book pre-filled (existing behavior).
- Log out and log in as `active@demo.com` (student) → book detail shows the single Start/Continue Reading button. Confirm no visual regression.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/library/book_detail_screen.dart
git commit -m "feat(teacher-library): teacher book detail shows Start Reading + Assign"
```

---

## Task 6: Render preview banner in reader

**Files:**
- Modify: `lib/presentation/screens/reader/reader_screen.dart` (build method — wrap the scaffold body so the banner sits under the AppBar)

- [ ] **Step 1: Locate the reader's `build()` / Scaffold**

Run: `grep -n "Scaffold\|appBar:\|body:" lib/presentation/screens/reader/reader_screen.dart | head -20`

Expected: find the `Scaffold(...)` return in `build()`. Note whether the body is a direct widget or already a `Column`.

- [ ] **Step 2: Insert the banner above the current body**

Add the import at the top of `reader_screen.dart`:

```dart
import '../../widgets/reader/teacher_preview_banner.dart';
```

Then in the `build()` method, wrap the existing body so the banner renders as the first child of a `Column`:

```dart
    return Scaffold(
      // ... existing appBar, drawer, etc. unchanged
      body: Column(
        children: [
          const TeacherPreviewBanner(),
          Expanded(child: <EXISTING_BODY>),
        ],
      ),
    );
```

Replace `<EXISTING_BODY>` with whatever widget was previously passed to `body:`. `TeacherPreviewBanner` auto-hides for students (returns `SizedBox.shrink()`), so this is safe for the student flow.

- [ ] **Step 3: Analyze**

Run: `dart analyze lib/presentation/screens/reader/reader_screen.dart`
Expected: `No issues found!`

- [ ] **Step 4: Manual smoke check**

- Teacher: navigate Library → book → Start Reading. Banner visible beneath AppBar: "Teacher Preview — answers shown, no progress saved".
- Student (`active@demo.com`): open any book via Start/Continue Reading. Banner is NOT visible.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/reader/reader_screen.dart
git commit -m "feat(teacher-library): render preview banner in reader"
```

---

## Task 7: Suppress progress writes in preview mode

**Files:**
- Modify: `lib/presentation/screens/reader/reader_screen.dart:112` (`_updateCurrentChapter`)
- Modify: `lib/presentation/screens/reader/reader_screen.dart:124` (`_saveReadingTime`)
- Modify: `lib/presentation/screens/reader/reader_screen.dart:197` (`_markCurrentChapterComplete`)

All three methods write student progress. In preview mode each must early-return before doing any work (including reading stopwatch time so the timer doesn't drift).

- [ ] **Step 1: Add the provider import**

At the top of `reader_screen.dart`, add:

```dart
import '../../providers/teacher_preview_provider.dart';
```

- [ ] **Step 2: Gate `_updateCurrentChapter`**

Replace the method body at lines ~112-122 with:

```dart
  Future<void> _updateCurrentChapter() async {
    if (ref.read(isTeacherPreviewModeProvider)) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final useCase = ref.read(updateCurrentChapterUseCaseProvider);
    await useCase(UpdateCurrentChapterParams(
      userId: userId,
      bookId: widget.bookId,
      chapterId: widget.chapterId,
    ));
  }
```

- [ ] **Step 3: Gate `_saveReadingTime`**

Replace the method body at lines ~124-150 with:

```dart
  Future<void> _saveReadingTime() async {
    if (ref.read(isTeacherPreviewModeProvider)) return;

    final int readingTime;
    final String? userId;
    final SaveReadingProgressUseCase saveReadingProgressUseCase;

    try {
      readingTime = ref.read(readingTimerProvider);
      if (readingTime <= 0) return;

      userId = ref.read(currentUserIdProvider);
      if (userId == null) return;

      saveReadingProgressUseCase = ref.read(saveReadingProgressUseCaseProvider);
    } catch (_) {
      return;
    }

    await saveReadingProgressUseCase(SaveReadingProgressParams(
      userId: userId,
      bookId: widget.bookId,
      chapterId: widget.chapterId,
      additionalReadingTime: readingTime,
    ));
  }
```

- [ ] **Step 4: Gate `_markCurrentChapterComplete`**

Replace the method body at lines ~197-207 with:

```dart
  Future<void> _markCurrentChapterComplete() async {
    if (ref.read(isTeacherPreviewModeProvider)) return;

    try {
      final completionNotifier = ref.read(chapterCompletionProvider.notifier);
      await completionNotifier.markComplete(
        bookId: widget.bookId,
        chapterId: widget.chapterId,
      );
    } catch (e) {
      debugPrint('ChapterCompletionNotifier error: $e');
    }
  }
```

- [ ] **Step 5: Analyze**

Run: `dart analyze lib/presentation/screens/reader/reader_screen.dart`
Expected: `No issues found!`

- [ ] **Step 6: Verify student regression — open reader as student**

- Log in as `active@demo.com`. Open a book, read for ~30s, swipe to next chapter.
- Verify in Supabase (via SQL editor or admin panel) that a `reading_progress` / chapter progress row exists for this student and book and the `additional_reading_time` column increased.
- If NOT increased, the provider read may be wrong and early-returning for students too — revisit Step 1 import path and `isTeacherProvider` behavior.

- [ ] **Step 7: Verify teacher suppression**

- Log in as `teacher@demo.com`. Open a book via Library → Start Reading. Read for ~60s, swipe between chapters.
- In Supabase, confirm **no new rows** for `teacher@demo.com`'s user id in `reading_progress`, `chapter_progress`, or any XP log table.

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/screens/reader/reader_screen.dart
git commit -m "feat(teacher-library): suppress reader progress writes in preview mode"
```

---

## Task 8: Force activity-completed state in preview mode

**Files:**
- Modify: `lib/presentation/widgets/reader/reader_activity_block.dart:26-47` (`build` method)

The activity widgets (`InlineTrueFalseActivity`, `InlineWordTranslationActivity`, `InlineFindWordsActivity`, `InlineMatchingActivity`) already render the correct answer with "correct" styling when given `isCompleted: true, wasCorrect: true`, AND their tap handlers early-return when `isCompleted`. Overriding those two values at the single parent call site makes every activity type behave as "answer revealed, no taps." Zero widget modifications needed.

- [ ] **Step 1: Add import**

At the top of `reader_activity_block.dart`, add:

```dart
import '../../providers/teacher_preview_provider.dart';
```

- [ ] **Step 2: Override `isCompleted` and `wasCorrect` in `build`**

Replace the `build` method body (roughly lines 26-47) with:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (activity == null) {
      return _buildErrorState('Activity not found');
    }

    final isPreview = ref.watch(isTeacherPreviewModeProvider);
    final completedActivities = ref.watch(inlineActivityStateProvider);
    final isCompleted = isPreview || completedActivities.containsKey(activity!.id);
    final wasCorrect = isPreview ? true : completedActivities[activity!.id];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: _buildActivity(
          context,
          ref,
          activity!,
          isCompleted,
          wasCorrect,
        ),
      ),
    );
  }
```

Everything downstream — the switch statement, the callbacks, the widget classes themselves — stays identical. `onAnswer` callbacks will never fire because each activity widget's tap handler guards on `widget.isCompleted` before invoking them, so no XP, no server writes, no state mutations.

- [ ] **Step 3: Analyze**

Run: `dart analyze lib/presentation/widgets/reader/reader_activity_block.dart`
Expected: `No issues found!`

- [ ] **Step 4: Manual smoke check — teacher**

- As `teacher@demo.com`, open a book chapter that contains at least one of each inline activity type (check an existing content-rich book, e.g. one listed with activities in your admin content).
- For each activity:
  - **true_false**: correct option highlighted green, check-mark visible.
  - **word_translation**: correct translation chip highlighted green.
  - **find_words**: every target word in `correctAnswers` highlighted green.
  - **matching**: all correct pairs shown connected.
- Tap each activity's options — state does not change; no haptic, no XP animation, no sound.

- [ ] **Step 5: Manual smoke check — student regression**

- As `active@demo.com`, open the same chapter on a fresh (not-yet-answered) activity.
- Activity renders in its unanswered state (no green highlight); answering works exactly as before; XP animation and completion persist.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/widgets/reader/reader_activity_block.dart
git commit -m "feat(teacher-library): force activity completed+correct in preview"
```

---

## Task 9: Unlock quiz tile in reader sidebar for teachers

**Files:**
- Modify: `lib/presentation/widgets/reader/reader_sidebar.dart` (`_BookQuizTile.build`, around lines 396-414)

The reader sidebar contains a `_BookQuizTile` that navigates to the quiz. It locks itself (non-tappable, 0.4 opacity) whenever `allChaptersRead` is false. Teachers never have progress, so without this fix the tile is permanently locked and the teacher has no way to reach the quiz from the reader.

Task 5 explicitly chose NOT to add a teacher "Take the Quiz" button in book detail (matches spec §11.4: no new buttons, teacher reaches quiz through the reader). That makes the sidebar tile the sole teacher entry point — so it must unlock in preview mode.

- [ ] **Step 1: Add import**

At the top of `reader_sidebar.dart`, add:

```dart
import '../../providers/teacher_preview_provider.dart';
```

- [ ] **Step 2: Unlock tile in preview**

Locate the `_BookQuizTile.build` (around lines 396-414). Replace the `isLocked` computation with a teacher-preview-aware version:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasQuiz = ref.watch(bookHasQuizProvider(bookId)).valueOrNull ?? false;
    if (!hasQuiz) return const SizedBox.shrink();

    final isPreview = ref.watch(isTeacherPreviewModeProvider);
    final progressAsync = ref.watch(readingProgressProvider(bookId));
    final allChaptersRead =
        progressAsync.valueOrNull?.completionPercentage == 100;
    final bestResult = ref.watch(bestQuizResultProvider(bookId)).valueOrNull;
    final isPassed = bestResult?.isPassing ?? false;
    final location = GoRouterState.of(context).uri.path;
    final isCurrent = location.startsWith('/quiz');
    final isLocked = !isPreview && !allChaptersRead;

    // (unchanged below — GestureDetector + Opacity + Container + Row etc.)
```

Leave everything from `return GestureDetector(...)` onwards exactly as it is. The single line change `final isLocked = !isPreview && !allChaptersRead;` makes the tile tappable and full-opacity for teachers while preserving the student lock behavior.

- [ ] **Step 3: Analyze**

Run: `dart analyze lib/presentation/widgets/reader/reader_sidebar.dart`
Expected: `No issues found!`

- [ ] **Step 4: Manual smoke check**

- As `teacher@demo.com`, open a book → Start Reading → open the reader sidebar.
- The quiz tile is at full opacity, has no lock icon styling, and is tappable. Tapping navigates to `/quiz/<bookId>`. (The quiz screen itself still blocks entry until Task 10 — you will see the guard screen for now, which is expected.)
- As `active@demo.com`, open a book you have NOT finished reading → sidebar's quiz tile is locked (0.4 opacity, non-tappable) exactly as before.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/reader/reader_sidebar.dart
git commit -m "feat(teacher-library): unlock sidebar quiz tile for teachers"
```

---

## Task 10: Book quiz preview mode

**Files:**
- Modify: `lib/presentation/screens/quiz/book_quiz_screen.dart` (`build` guard, `initState`, submit-button region)

The book quiz has three places to change for teachers: bypass the "chapters must be 100%" guard, pre-fill `_answers` from each question's correct-answer field, and replace Submit with Exit Preview.

Note: there is intentionally NO teacher change in `book_detail_screen.dart` for the "Take the Quiz" button. Task 5 hands teachers Start Reading + Assign; the quiz is reached through the reader sidebar (Task 9). This matches spec §11.4.

- [ ] **Step 1: Bypass the completion guard**

Locate the guard in `book_quiz_screen.dart` build method (currently around lines 86-89):

```dart
if (progress == null || progress.completionPercentage < 100) {
  return _buildGuardScreen(context);
}
```

Replace with:

```dart
final isPreview = ref.watch(isTeacherPreviewModeProvider);
if (!isPreview &&
    (progress == null || progress.completionPercentage < 100)) {
  return _buildGuardScreen(context);
}
```

Add the import at top:

```dart
import '../../providers/teacher_preview_provider.dart';
```

- [ ] **Step 2: Locate the quiz model to understand correct-answer fields**

Run: `grep -n "correctAnswer\|correctOrder\|correctPairs" lib/data/models/book_quiz/book_quiz_model.dart | head -30`

Expected: field names per question type (e.g. `correctAnswer` on `MultipleChoiceContent`, `correctOrder` on `EventSequencingContent`, `correctPairs` on `MatchingContent` / `WhoSaysWhatContent`, `correctAnswer` + `acceptAlternatives` on `FillBlankContent`). Note the domain types used in the quiz entity — those are what `_answers` receives in user mode.

- [ ] **Step 3: Add a pre-fill method**

Inside `_BookQuizScreenState`, add a helper method after `_setQuizActive`:

```dart
  /// Fills [_answers] with correct answers from the quiz so the teacher sees
  /// every question with the right option(s) already selected. Called once per
  /// quiz load when in teacher preview mode.
  void _prefillAnswersFromQuiz(BookQuiz quiz) {
    for (final question in quiz.questions) {
      final content = question.content;
      if (content is MultipleChoiceContent) {
        _answers[question.id] = content.correctAnswer;
      } else if (content is FillBlankContent) {
        _answers[question.id] = content.correctAnswer;
      } else if (content is EventSequencingContent) {
        _answers[question.id] = List<int>.from(content.correctOrder);
      } else if (content is MatchingContent) {
        _answers[question.id] = Map<int, int>.from(content.correctPairs);
      } else if (content is WhoSaysWhatContent) {
        _answers[question.id] = Map<int, int>.from(content.correctPairs);
      }
    }
  }
```

If the actual domain types / field names differ from the ones shown here, use what Step 2 revealed. The pattern remains: for each question, set `_answers[question.id]` to whatever shape that question's renderer consumes as the "user's selection."

Verify the required imports are present:

```dart
import '../../../domain/entities/book_quiz.dart';
// plus any content type imports (MultipleChoiceContent etc.) if not re-exported
```

- [ ] **Step 4: Call the pre-fill when quiz loads in preview mode**

Find the place in `_buildQuizContent` (or wherever the quiz loads via `bookQuizProvider`) where the loaded `BookQuiz` is first available. Add one-time pre-fill guarded by a flag. At the top of `_BookQuizScreenState` declarations, add:

```dart
  bool _prefilledForPreview = false;
```

When you have the loaded `BookQuiz quiz` variable in scope (inside the `.when(data: (quiz) {...})` block of the quiz provider — use `grep -n "bookQuizProvider" lib/presentation/screens/quiz/book_quiz_screen.dart` to find it), add at the top of that data builder:

```dart
              if (ref.watch(isTeacherPreviewModeProvider) &&
                  !_prefilledForPreview) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() {
                    _prefillAnswersFromQuiz(quiz);
                    _prefilledForPreview = true;
                  });
                });
              }
```

`addPostFrameCallback` is required because you cannot call `setState` during build. The flag prevents re-firing on subsequent rebuilds.

- [ ] **Step 5: Replace Submit with Exit Preview**

Locate the Submit button inside `book_quiz_screen.dart` (search for `Submit` or `'Submit'`):

```bash
grep -n "Submit\|GradeBookQuiz" lib/presentation/screens/quiz/book_quiz_screen.dart | head
```

In the widget (likely on the last question page or in a fixed bottom bar), find the `GameButton` or equivalent labeled "Submit" or similar, wrap its `onPressed` so teachers get a silent-exit path. Shape:

```dart
final isPreview = ref.watch(isTeacherPreviewModeProvider);
// ...
GameButton(
  label: isPreview ? 'Exit Preview' : 'Submit',
  onPressed: isPreview
      ? () {
          _setQuizActive(false);
          context.pop();
        }
      : _handleSubmit, // or whatever the existing submit handler is
  // other props unchanged
),
```

Leave the intermediate Next button unchanged — teachers still page through the quiz to see each question.

- [ ] **Step 6: Analyze**

Run: `dart analyze lib/presentation/screens/quiz/book_quiz_screen.dart`
Expected: `No issues found!`

- [ ] **Step 7: Manual smoke check — teacher**

- As `teacher@demo.com`, open Library → pick a book that has a book quiz configured → Start Reading → open the reader sidebar → tap the (now-unlocked, per Task 9) Book Quiz tile.
- Guard screen is NOT shown. Quiz renders with every question's correct answer pre-selected.
- Bottom button reads **Exit Preview**. Tap it → returns to the reader. Verify in Supabase: no `book_quiz_attempts` row for this teacher (see Task 11 Step 2 for the SQL).

- [ ] **Step 8: Manual smoke check — student regression**

- As `active@demo.com`, open a book quiz for a book you have NOT completed. Guard screen still appears.
- Complete chapters (or use an already-complete book in test data) and open the quiz. Questions render empty; answering and submitting still calls `GradeBookQuizUseCase` and shows results as before.

- [ ] **Step 9: Commit**

```bash
git add lib/presentation/screens/quiz/book_quiz_screen.dart
git commit -m "feat(teacher-library): pre-fill quiz answers and add Exit Preview"
```

---

## Task 11: End-to-end verification

**Files:**
- No code changes unless regressions surface.

Run the full verification matrix from the spec (§15.1 and §15.2). If anything fails, fix inline and commit each fix with a `fix(teacher-library): ...` message.

- [ ] **Step 1: Teacher smoke**

- Log in as `teacher@demo.com`.
- Library tab exists and loads all books.
- Open book detail → **Start Reading** + **Assign Book** visible; no lock screen.
- Start Reading → banner visible; read through a chapter; swipe between chapters in either direction.
- Every inline activity shows the correct answer highlighted; taps do nothing.
- Navigate to the quiz (through reader's last-chapter entry or `/quiz/<bookId>`) → no guard screen; every question pre-filled with correct answer; button reads **Exit Preview**.
- Exit quiz and reader.
- Open Assign Book → fills the assignment form; submit creates an assignment row visible in `/teacher/assignments`.

- [ ] **Step 2: Supabase audit — teacher leaves no trace**

Run these queries in the Supabase SQL editor (replace `<TEACHER_USER_ID>` with the UUID of the teacher account):

```sql
select count(*) from reading_progress where user_id = '<TEACHER_USER_ID>';
select count(*) from chapter_progress where user_id = '<TEACHER_USER_ID>';
select count(*) from book_quiz_attempts where user_id = '<TEACHER_USER_ID>';
select count(*) from xp_logs where user_id = '<TEACHER_USER_ID>';
```

Each must equal the count from **before** the teacher session. Table names may differ — use `grep -rn "DbTables\." packages/owlio_shared/lib/` to get exact names from `owlio_shared`.

- [ ] **Step 3: Student regression**

- Log in as `fresh@demo.com` (0 XP), `active@demo.com` (500 XP), `advanced@demo.com`.
- For each: open the library, a book detail, a reader session, at least one inline activity, and the quiz (where applicable). Progress, XP awards, completions, and the quiz guard must all behave exactly as before.

- [ ] **Step 4: Static checks**

Run: `dart analyze lib/`
Expected: `No issues found!` (or at least no new issues vs. baseline — capture baseline with `git stash && dart analyze lib/ > /tmp/baseline && git stash pop` before starting).

Run: `flutter test`
Expected: all existing tests pass plus the new `teacher_preview_provider_test.dart`.

- [ ] **Step 5: Final commit if any fixes**

If you made any fixes in Steps 1-4, commit them. If not, skip.

- [ ] **Step 6: Review the spec checklist one more time**

Open `docs/superpowers/specs/2026-04-17-teacher-library-design.md` §15 (Testing / Verification Plan) and confirm each checkbox is satisfied. Note any intentional deviation in a final commit message (e.g. "docs: note that chapter-sequential-unlock gate did not exist — no bypass needed").

---

## Self-Review Summary

Before handing off:

**Spec coverage:**
- §6 Navigation → Tasks 3, 4 ✓
- §7 Preview mode provider → Task 1 ✓
- §8 Access gate bypasses: `bookLockProvider` already ✓, chapter sequential gate (not found in codebase — verified in discovery; may not exist, no task needed), quiz access gate → Tasks 9 (sidebar tile) + 10 Step 1 (quiz screen guard) ✓, progress writes → Task 7 ✓
- §9 Book detail FAB → Task 5 ✓
- §11.1 Preview banner → Tasks 2, 6 ✓
- §11.2 Progress suppression → Task 7 ✓
- §11.3 Chapter free-navigation → implicit (no code-side gate exists; teacher progress suppression is sufficient — validated in Task 11 Step 1 swipe check)
- §11.4 Quiz entry via reader → Task 9 unlocks the existing sidebar tile (no new button)
- §12 Inline activities pre-fill → Task 8 ✓
- §13 Quiz pre-fill + Exit Preview → Task 10 ✓
- §10 Assign flow unchanged → no task needed (explicitly called out in spec) ✓
- §15 Testing → Task 11 ✓

**Placeholders:** None — every step shows concrete code and commands. Three steps invite the engineer to confirm minor details in the codebase (exact `isTeacherProvider` signature, exact `AppColors` tokens, exact quiz model field names) rather than hardcode them; this is verification, not a placeholder.

**Type consistency:** `isTeacherPreviewModeProvider` is declared as `Provider<bool>` in Task 1 and read via `ref.watch` / `ref.read` with no `.valueOrNull` or `.when` in Tasks 6-9 — consistent synchronous API. The fallback variant (async wrapping) is handled at the provider definition so call sites stay uniform.

**Assign flow:** Zero new work. Tasks 3-5 add discoverability; Task 11 Step 1 confirms it still works end-to-end.
