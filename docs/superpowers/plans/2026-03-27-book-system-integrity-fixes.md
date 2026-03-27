# Book System Integrity Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix XP idempotency bugs, RLS security gap, architecture violations, and error handling gaps in the Book System.

**Architecture:** Three sequential phases: (1) DB migration + addXP chain for idempotency, (2) extract business logic from widgets/repos into UseCases, (3) fix error propagation + performance. No business rules change — same behavior, safer implementation.

**Tech Stack:** Flutter/Dart, Riverpod, Supabase (PostgreSQL), dartz (Either), mockito (tests)

**Spec:** `docs/superpowers/specs/2026-03-27-book-system-integrity-fixes-design.md`
**Audit:** `docs/specs/01-book-system.md`

---

## Phase 1: Data Integrity

### Task 1: Add source/sourceId to addXP Chain

**Files:**
- Modify: `lib/domain/repositories/user_repository.dart:13`
- Modify: `lib/domain/usecases/user/add_xp_usecase.dart` (full file)
- Modify: `lib/data/repositories/supabase/supabase_user_repository.dart:64-88`
- Modify: `lib/presentation/providers/user_provider.dart:205`
- Test: `test/unit/domain/usecases/user/user_usecases_test.dart`

- [ ] **Step 1: Update UserRepository interface**

In `lib/domain/repositories/user_repository.dart`, change the `addXP` signature:

```dart
// Before:
Future<Either<Failure, User>> addXP(String userId, int amount);

// After:
Future<Either<Failure, User>> addXP(
  String userId,
  int amount, {
  String source = 'manual',
  String? sourceId,
});
```

- [ ] **Step 2: Update AddXPParams and AddXPUseCase**

Replace the full content of `lib/domain/usecases/user/add_xp_usecase.dart`:

```dart
import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../entities/user.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class AddXPParams {
  const AddXPParams({
    required this.userId,
    required this.amount,
    this.source = 'manual',
    this.sourceId,
  });
  final String userId;
  final int amount;
  final String source;
  final String? sourceId;
}

class AddXPUseCase implements UseCase<User, AddXPParams> {
  const AddXPUseCase(this._repository);
  final UserRepository _repository;

  @override
  Future<Either<Failure, User>> call(AddXPParams params) {
    return _repository.addXP(
      params.userId,
      params.amount,
      source: params.source,
      sourceId: params.sourceId,
    );
  }
}
```

- [ ] **Step 3: Update SupabaseUserRepository.addXP**

In `lib/data/repositories/supabase/supabase_user_repository.dart`, update the method:

```dart
@override
Future<Either<Failure, domain.User>> addXP(
  String userId,
  int amount, {
  String source = 'manual',
  String? sourceId,
}) async {
  try {
    await _supabase.rpc(RpcFunctions.awardXpTransaction, params: {
      'p_user_id': userId,
      'p_amount': amount,
      'p_source': source,
      'p_source_id': sourceId,
      'p_description': 'XP awarded',
    });

    final response = await _supabase
        .from(DbTables.profiles)
        .select()
        .eq('id', userId)
        .single();

    return Right(UserModel.fromJson(response).toEntity());
  } on PostgrestException catch (e) {
    return Left(ServerFailure(e.message, code: e.code));
  } catch (e) {
    return Left(ServerFailure(e.toString()));
  }
}
```

- [ ] **Step 4: Update UserController.addXP**

In `lib/presentation/providers/user_provider.dart`, update the method signature and UseCase call:

```dart
Future<void> addXP(int amount, {String source = 'manual', String? sourceId}) async {
  final userId = _ref.read(currentUserIdProvider);
  if (userId == null) return;

  final oldLevel = state.valueOrNull?.level ?? 1;

  final useCase = _ref.read(addXPUseCaseProvider);
  debugPrint('🔄 addXP: awarding $amount XP to $userId (source=$source, sourceId=$sourceId)');
  final result = await useCase(AddXPParams(
    userId: userId,
    amount: amount,
    source: source,
    sourceId: sourceId,
  ));
```

The rest of the method (level-up check, badge check) stays unchanged.

- [ ] **Step 5: Update existing test for new params**

In `test/unit/domain/usecases/user/user_usecases_test.dart`, update the AddXPUseCase test to verify source/sourceId are forwarded:

```dart
test('withSourceId_shouldForwardToRepository', () async {
  final updatedUser = UserFixtures.userWithAddedXP(addedXP: 50);
  when(mockUserRepository.addXP(
    'user-123', 50,
    source: 'chapter_complete',
    sourceId: 'chapter-uuid-5',
  )).thenAnswer((_) async => Right(updatedUser));

  const params = AddXPParams(
    userId: 'user-123',
    amount: 50,
    source: 'chapter_complete',
    sourceId: 'chapter-uuid-5',
  );

  final result = await usecase(params);

  expect(result.isRight(), true);
  verify(mockUserRepository.addXP(
    'user-123', 50,
    source: 'chapter_complete',
    sourceId: 'chapter-uuid-5',
  )).called(1);
});
```

- [ ] **Step 6: Run tests and analyze**

```bash
dart analyze lib/domain/usecases/user/ lib/domain/repositories/user_repository.dart lib/data/repositories/supabase/supabase_user_repository.dart
flutter test test/unit/domain/usecases/user/user_usecases_test.dart
```

Expected: All pass. If mock regeneration needed, run `dart run build_runner build --delete-conflicting-outputs` first.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/repositories/user_repository.dart lib/domain/usecases/user/add_xp_usecase.dart lib/data/repositories/supabase/supabase_user_repository.dart lib/presentation/providers/user_provider.dart test/unit/domain/usecases/user/
git commit -m "feat: add source/sourceId params to addXP chain for idempotency"
```

---

### Task 2: Wire source_id to All XP Callers

> **Note:** Tasks 5 and 6 (Phase 2) will rewrite the same addXP call sites in these files. This task ensures idempotency is active immediately after Phase 1, before the architecture refactors land. The Phase 2 code already includes source_id parameters.

**Files:**
- Modify: `lib/presentation/providers/book_provider.dart` (ChapterCompletionNotifier.markComplete)
- Modify: `lib/presentation/providers/book_quiz_provider.dart` (BookQuizController.submitQuiz)
- Modify: `lib/presentation/providers/reader_provider.dart` (handleInlineActivityCompletion)

- [ ] **Step 1: Update chapter + book completion XP in book_provider.dart**

In `lib/presentation/providers/book_provider.dart`, inside `ChapterCompletionNotifier.markComplete`, find the addXP calls and add source/sourceId:

```dart
// Chapter completion XP (around line 187)
// Before:
await _ref.read(userControllerProvider.notifier).addXP(settings.xpChapterComplete);

// After:
await _ref.read(userControllerProvider.notifier).addXP(
  settings.xpChapterComplete,
  source: 'chapter_complete',
  sourceId: chapterId,
);
```

```dart
// Book completion XP (around line 195)
// Before:
await _ref.read(userControllerProvider.notifier).addXP(settings.xpBookComplete);

// After:
await _ref.read(userControllerProvider.notifier).addXP(
  settings.xpBookComplete,
  source: 'book_complete',
  sourceId: bookId,
);
```

- [ ] **Step 2: Update quiz XP in book_quiz_provider.dart**

In `lib/presentation/providers/book_quiz_provider.dart`, inside `BookQuizController.submitQuiz`, find the addXP call:

```dart
// Around line 138
// Before:
await _ref.read(userControllerProvider.notifier).addXP(settings.xpQuizPass);

// After:
await _ref.read(userControllerProvider.notifier).addXP(
  settings.xpQuizPass,
  source: 'quiz_pass',
  sourceId: quizId,
);
```

- [ ] **Step 3: Update inline activity XP in reader_provider.dart**

In `lib/presentation/providers/reader_provider.dart`, inside `_handleInlineActivityCompletionImpl`, find the addXP call:

```dart
// Around line 418
// Before:
await ref.read(userControllerProvider.notifier).addXP(xpEarned);

// After:
await ref.read(userControllerProvider.notifier).addXP(
  xpEarned,
  source: 'inline_activity',
  sourceId: activityId,
);
```

- [ ] **Step 4: Run analyze**

```bash
dart analyze lib/presentation/providers/book_provider.dart lib/presentation/providers/book_quiz_provider.dart lib/presentation/providers/reader_provider.dart
```

Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/providers/book_provider.dart lib/presentation/providers/book_quiz_provider.dart lib/presentation/providers/reader_provider.dart
git commit -m "feat: wire source_id to chapter/book/quiz/activity XP awards"
```

---

### Task 3: RLS Migration — reading_progress DELETE Protection

**Files:**
- Create: `supabase/migrations/20260328000001_fix_reading_progress_rls.sql`

- [ ] **Step 1: Create migration file**

Create `supabase/migrations/20260328000001_fix_reading_progress_rls.sql`:

```sql
-- Fix: reading_progress FOR ALL policy allows students to DELETE their own progress.
-- Split into granular SELECT/INSERT/UPDATE policies (no DELETE).
-- Ref: docs/specs/01-book-system.md finding #9

-- Drop the overly permissive FOR ALL policy
DROP POLICY IF EXISTS "Users can manage own reading progress" ON reading_progress;

-- Granular student policies
CREATE POLICY "Users can read own reading progress"
    ON reading_progress FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can insert own reading progress"
    ON reading_progress FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own reading progress"
    ON reading_progress FOR UPDATE
    USING (user_id = auth.uid());

-- Note: No DELETE policy for students.
-- Existing teacher SELECT policy (from separate migration) is unaffected.
```

- [ ] **Step 2: Dry-run migration**

```bash
supabase db push --dry-run
```

Expected: Shows the policy changes. Verify no unexpected drops.

- [ ] **Step 3: Push migration**

```bash
supabase db push
```

Expected: Migration applied successfully.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260328000001_fix_reading_progress_rls.sql
git commit -m "fix: restrict reading_progress RLS to SELECT/INSERT/UPDATE (remove DELETE)"
```

---

## Phase 2: Architecture Refactors

### Task 4: GradeBookQuizUseCase

**Files:**
- Create: `lib/domain/usecases/book_quiz/grade_book_quiz_usecase.dart`
- Modify: `lib/presentation/providers/usecase_providers.dart`
- Modify: `lib/presentation/screens/quiz/book_quiz_screen.dart`
- Create: `test/unit/domain/usecases/book_quiz/grade_book_quiz_usecase_test.dart`

- [ ] **Step 1: Create the UseCase**

Create `lib/domain/usecases/book_quiz/grade_book_quiz_usecase.dart`:

```dart
import '../../entities/book_quiz.dart';

class GradeBookQuizParams {
  const GradeBookQuizParams({
    required this.quiz,
    required this.answers,
  });
  final BookQuiz quiz;
  final Map<String, dynamic> answers;
}

class GradeQuizResult {
  const GradeQuizResult({
    required this.totalScore,
    required this.maxScore,
    required this.percentage,
    required this.isPassing,
    required this.answersJson,
  });
  final double totalScore;
  final double maxScore;
  final double percentage;
  final bool isPassing;
  final Map<String, dynamic> answersJson;
}

class GradeBookQuizUseCase {
  GradeQuizResult call(GradeBookQuizParams params) {
    final quiz = params.quiz;
    final answers = params.answers;
    double totalScore = 0;
    double maxScore = 0;
    final answersJson = <String, dynamic>{};

    for (final question in quiz.questions) {
      final answer = answers[question.id];
      maxScore += question.points;

      final isCorrect = _gradeQuestion(question, answer);
      if (isCorrect) {
        totalScore += question.points;
      }

      answersJson[question.id] = {
        'answer': _serializeAnswer(answer),
        'correct': isCorrect,
      };
    }

    final percentage = maxScore > 0 ? (totalScore / maxScore) * 100 : 0.0;

    return GradeQuizResult(
      totalScore: totalScore,
      maxScore: maxScore,
      percentage: percentage,
      isPassing: percentage >= quiz.passingScore,
      answersJson: answersJson,
    );
  }

  bool _gradeQuestion(BookQuizQuestion question, dynamic answer) {
    if (answer == null) return false;

    switch (question.type) {
      case BookQuizQuestionType.multipleChoice:
        final content = question.content as MultipleChoiceContent;
        return answer == content.correctAnswer;

      case BookQuizQuestionType.fillBlank:
        final content = question.content as FillBlankContent;
        return content.checkAnswer(answer as String);

      case BookQuizQuestionType.eventSequencing:
        final content = question.content as EventSequencingContent;
        return content.checkAnswer(answer as List<int>);

      case BookQuizQuestionType.matching:
        final content = question.content as QuizMatchingContent;
        final pairs = answer as Map<int, int>;
        if (pairs.length != content.correctPairs.length) return false;
        return content.correctPairs.entries
            .every((e) => pairs[e.key] == e.value);

      case BookQuizQuestionType.whoSaysWhat:
        final content = question.content as WhoSaysWhatContent;
        final pairs = answer as Map<int, int>;
        if (pairs.length != content.correctPairs.length) return false;
        return content.correctPairs.entries
            .every((e) => pairs[e.key] == e.value);
    }
  }

  dynamic _serializeAnswer(dynamic answer) {
    if (answer is Map<int, int>) {
      return answer.map((k, v) => MapEntry(k.toString(), v));
    }
    if (answer is List<int>) {
      return answer;
    }
    return answer;
  }
}
```

- [ ] **Step 2: Write tests**

Create `test/unit/domain/usecases/book_quiz/grade_book_quiz_usecase_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:owlio/domain/entities/book_quiz.dart';
import 'package:owlio/domain/usecases/book_quiz/grade_book_quiz_usecase.dart';
import 'package:owlio_shared/owlio_shared.dart';

void main() {
  late GradeBookQuizUseCase usecase;

  setUp(() {
    usecase = GradeBookQuizUseCase();
  });

  group('GradeBookQuizUseCase', () {
    test('allCorrect_shouldReturn100Percent', () {
      final quiz = BookQuiz(
        id: 'quiz-1',
        bookId: 'book-1',
        title: 'Test Quiz',
        passingScore: 70.0,
        totalPoints: 20,
        isPublished: true,
        questions: [
          BookQuizQuestion(
            id: 'q1',
            quizId: 'quiz-1',
            type: BookQuizQuestionType.multipleChoice,
            orderIndex: 0,
            question: 'What color?',
            content: MultipleChoiceContent(
              options: ['Red', 'Blue', 'Green'],
              correctAnswer: 0,
            ),
            points: 10,
          ),
          BookQuizQuestion(
            id: 'q2',
            quizId: 'quiz-1',
            type: BookQuizQuestionType.multipleChoice,
            orderIndex: 1,
            question: 'What shape?',
            content: MultipleChoiceContent(
              options: ['Circle', 'Square'],
              correctAnswer: 1,
            ),
            points: 10,
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = usecase(GradeBookQuizParams(
        quiz: quiz,
        answers: {'q1': 0, 'q2': 1},
      ));

      expect(result.totalScore, 20.0);
      expect(result.maxScore, 20.0);
      expect(result.percentage, 100.0);
      expect(result.isPassing, true);
    });

    test('noAnswers_shouldReturn0Percent', () {
      final quiz = BookQuiz(
        id: 'quiz-1',
        bookId: 'book-1',
        title: 'Test Quiz',
        passingScore: 70.0,
        totalPoints: 10,
        isPublished: true,
        questions: [
          BookQuizQuestion(
            id: 'q1',
            quizId: 'quiz-1',
            type: BookQuizQuestionType.multipleChoice,
            orderIndex: 0,
            question: 'What?',
            content: MultipleChoiceContent(
              options: ['A', 'B'],
              correctAnswer: 0,
            ),
            points: 10,
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = usecase(GradeBookQuizParams(
        quiz: quiz,
        answers: {},
      ));

      expect(result.totalScore, 0.0);
      expect(result.percentage, 0.0);
      expect(result.isPassing, false);
    });

    test('belowPassingScore_shouldReturnNotPassing', () {
      final quiz = BookQuiz(
        id: 'quiz-1',
        bookId: 'book-1',
        title: 'Test Quiz',
        passingScore: 70.0,
        totalPoints: 20,
        isPublished: true,
        questions: [
          BookQuizQuestion(
            id: 'q1',
            quizId: 'quiz-1',
            type: BookQuizQuestionType.multipleChoice,
            orderIndex: 0,
            question: 'Q1',
            content: MultipleChoiceContent(options: ['A', 'B'], correctAnswer: 0),
            points: 10,
          ),
          BookQuizQuestion(
            id: 'q2',
            quizId: 'quiz-1',
            type: BookQuizQuestionType.multipleChoice,
            orderIndex: 1,
            question: 'Q2',
            content: MultipleChoiceContent(options: ['A', 'B'], correctAnswer: 0),
            points: 10,
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Only q1 correct = 50%
      final result = usecase(GradeBookQuizParams(
        quiz: quiz,
        answers: {'q1': 0, 'q2': 1},
      ));

      expect(result.percentage, 50.0);
      expect(result.isPassing, false);
    });
  });
}
```

- [ ] **Step 3: Run tests**

```bash
flutter test test/unit/domain/usecases/book_quiz/grade_book_quiz_usecase_test.dart
```

Expected: All 3 tests pass.

- [ ] **Step 4: Register provider**

In `lib/presentation/providers/usecase_providers.dart`, add after existing book quiz providers:

```dart
final gradeBookQuizUseCaseProvider = Provider((ref) {
  return GradeBookQuizUseCase();
});
```

- [ ] **Step 5: Update BookQuizScreen to use UseCase**

In `lib/presentation/screens/quiz/book_quiz_screen.dart`:

1. Remove `_gradeQuestion`, `_serializeAnswer`, `_isAnswerValid` methods and the score accumulation loop from `_submitQuiz`.
2. Replace with:

```dart
// In _submitQuiz method, replace the grading loop with:
final gradeUseCase = ref.read(gradeBookQuizUseCaseProvider);
final gradeResult = gradeUseCase(GradeBookQuizParams(
  quiz: quiz,
  answers: _answers,
));

// Then use gradeResult for submission:
await ref.read(bookQuizControllerProvider.notifier).submitQuiz(
  quizId: quiz.id,
  bookId: widget.bookId,
  score: gradeResult.totalScore,
  maxScore: gradeResult.maxScore,
  answers: gradeResult.answersJson,
  passingScore: quiz.passingScore,
  timeSpent: _timeSpent, // preserve existing timer variable from the screen
);
```

3. Replace `_isAnswerValid` usage in the submit button guard with:
```dart
// Check if all questions have non-null answers
final allAnswered = quiz.questions.every((q) => _answers[q.id] != null);
```

- [ ] **Step 6: Run analyze**

```bash
dart analyze lib/domain/usecases/book_quiz/grade_book_quiz_usecase.dart lib/presentation/screens/quiz/book_quiz_screen.dart lib/presentation/providers/usecase_providers.dart
```

Expected: No issues.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/usecases/book_quiz/grade_book_quiz_usecase.dart test/unit/domain/usecases/book_quiz/ lib/presentation/screens/quiz/book_quiz_screen.dart lib/presentation/providers/usecase_providers.dart
git commit -m "refactor: extract quiz grading logic to GradeBookQuizUseCase"
```

---

### Task 5: HandleBookCompletionUseCase

**Files:**
- Create: `lib/domain/usecases/reading/handle_book_completion_usecase.dart`
- Modify: `lib/presentation/providers/usecase_providers.dart`
- Modify: `lib/presentation/providers/book_provider.dart` (ChapterCompletionNotifier)
- Modify: `lib/presentation/providers/book_quiz_provider.dart` (BookQuizController)
- Modify: `lib/data/repositories/supabase/supabase_book_repository.dart` (simplify markChapterComplete)
- Modify: `lib/data/repositories/supabase/supabase_book_quiz_repository.dart` (remove _handleQuizPassed)
- Create: `test/unit/domain/usecases/reading/handle_book_completion_usecase_test.dart`

- [ ] **Step 1: Create the UseCase**

Create `lib/domain/usecases/reading/handle_book_completion_usecase.dart`:

```dart
import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../entities/reading_progress.dart';
import '../../repositories/book_repository.dart';
import '../../repositories/book_quiz_repository.dart';
import '../usecase.dart';

class HandleBookCompletionParams {
  const HandleBookCompletionParams({
    required this.userId,
    required this.bookId,
    this.quizJustPassed = false,
  });
  final String userId;
  final String bookId;
  final bool quizJustPassed;
}

class BookCompletionResult {
  const BookCompletionResult({
    required this.progress,
    required this.justCompleted,
    required this.hasQuiz,
  });
  final ReadingProgress progress;
  final bool justCompleted; // true if book was just marked complete this call
  final bool hasQuiz;
}

class HandleBookCompletionUseCase
    implements UseCase<BookCompletionResult, HandleBookCompletionParams> {
  const HandleBookCompletionUseCase(this._bookRepository, this._quizRepository);
  final BookRepository _bookRepository;
  final BookQuizRepository _quizRepository;

  @override
  Future<Either<Failure, BookCompletionResult>> call(
    HandleBookCompletionParams params,
  ) async {
    // 1. Get current progress
    final progressResult = await _bookRepository.getReadingProgress(
      userId: params.userId,
      bookId: params.bookId,
    );

    return progressResult.fold(
      (failure) => Left(failure),
      (progress) async {
        // Already completed — no action
        if (progress.isCompleted) {
          final hasQuizResult = await _quizRepository.bookHasQuiz(params.bookId);
          final hasQuiz = hasQuizResult.fold((_) => false, (v) => v);
          return Right(BookCompletionResult(
            progress: progress,
            justCompleted: false,
            hasQuiz: hasQuiz,
          ));
        }

        // 2. Check if all chapters complete
        final chaptersResult = await _bookRepository.getChapters(params.bookId);
        final totalChapters = chaptersResult.fold((_) => 0, (c) => c.length);
        final allChaptersComplete =
            progress.completedChapterIds.length >= totalChapters && totalChapters > 0;

        if (!allChaptersComplete) {
          final hasQuizResult = await _quizRepository.bookHasQuiz(params.bookId);
          final hasQuiz = hasQuizResult.fold((_) => false, (v) => v);
          return Right(BookCompletionResult(
            progress: progress,
            justCompleted: false,
            hasQuiz: hasQuiz,
          ));
        }

        // 3. Check quiz status
        final hasQuizResult = await _quizRepository.bookHasQuiz(params.bookId);
        final hasQuiz = hasQuizResult.fold((_) => false, (v) => v);

        final quizPassed = progress.quizPassed || params.quizJustPassed;

        // Book completes when: all chapters done AND (no quiz OR quiz passed)
        final shouldComplete = !hasQuiz || quizPassed;

        if (!shouldComplete) {
          return Right(BookCompletionResult(
            progress: progress,
            justCompleted: false,
            hasQuiz: hasQuiz,
          ));
        }

        // 4. Mark as complete
        final updatedProgress = progress.copyWith(
          isCompleted: true,
          quizPassed: quizPassed,
          completedAt: DateTime.now(),
        );

        final updateResult =
            await _bookRepository.updateReadingProgress(updatedProgress);

        return updateResult.fold(
          (failure) => Left(failure),
          (saved) => Right(BookCompletionResult(
            progress: saved,
            justCompleted: true,
            hasQuiz: hasQuiz,
          )),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Write tests**

Create `test/unit/domain/usecases/reading/handle_book_completion_usecase_test.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:owlio/core/errors/failures.dart';
import 'package:owlio/domain/entities/book.dart';
import 'package:owlio/domain/entities/chapter.dart';
import 'package:owlio/domain/entities/reading_progress.dart';
import 'package:owlio/domain/repositories/book_repository.dart';
import 'package:owlio/domain/repositories/book_quiz_repository.dart';
import 'package:owlio/domain/usecases/reading/handle_book_completion_usecase.dart';

@GenerateMocks([BookRepository, BookQuizRepository])
import 'handle_book_completion_usecase_test.mocks.dart';

void main() {
  late HandleBookCompletionUseCase usecase;
  late MockBookRepository mockBookRepo;
  late MockBookQuizRepository mockQuizRepo;

  setUp(() {
    mockBookRepo = MockBookRepository();
    mockQuizRepo = MockBookQuizRepository();
    usecase = HandleBookCompletionUseCase(mockBookRepo, mockQuizRepo);
  });

  ReadingProgress _makeProgress({
    required List<String> completedChapterIds,
    bool isCompleted = false,
    bool quizPassed = false,
  }) {
    return ReadingProgress(
      id: 'prog-1',
      userId: 'user-1',
      bookId: 'book-1',
      currentPage: 0,
      isCompleted: isCompleted,
      completionPercentage: 0,
      totalReadingTime: 0,
      completedChapterIds: completedChapterIds,
      quizPassed: quizPassed,
      startedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  List<Chapter> _makeChapters(int count) {
    return List.generate(count, (i) => Chapter(
      id: 'ch-$i',
      bookId: 'book-1',
      title: 'Chapter $i',
      orderIndex: i,
      imageUrls: [],
      vocabulary: [],
      useContentBlocks: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  }

  group('HandleBookCompletionUseCase', () {
    test('allChaptersDone_noQuiz_shouldComplete', () async {
      when(mockBookRepo.getReadingProgress(userId: 'user-1', bookId: 'book-1'))
          .thenAnswer((_) async => Right(_makeProgress(completedChapterIds: ['ch-0', 'ch-1'])));
      when(mockBookRepo.getChapters('book-1'))
          .thenAnswer((_) async => Right(_makeChapters(2)));
      when(mockQuizRepo.bookHasQuiz('book-1'))
          .thenAnswer((_) async => const Right(false));
      when(mockBookRepo.updateReadingProgress(any))
          .thenAnswer((_) async => Right(_makeProgress(
            completedChapterIds: ['ch-0', 'ch-1'],
            isCompleted: true,
          )));

      final result = await usecase(const HandleBookCompletionParams(
        userId: 'user-1',
        bookId: 'book-1',
      ));

      expect(result.isRight(), true);
      result.fold((_) {}, (r) {
        expect(r.justCompleted, true);
        expect(r.hasQuiz, false);
      });
    });

    test('allChaptersDone_quizNotPassed_shouldNotComplete', () async {
      when(mockBookRepo.getReadingProgress(userId: 'user-1', bookId: 'book-1'))
          .thenAnswer((_) async => Right(_makeProgress(completedChapterIds: ['ch-0', 'ch-1'])));
      when(mockBookRepo.getChapters('book-1'))
          .thenAnswer((_) async => Right(_makeChapters(2)));
      when(mockQuizRepo.bookHasQuiz('book-1'))
          .thenAnswer((_) async => const Right(true));

      final result = await usecase(const HandleBookCompletionParams(
        userId: 'user-1',
        bookId: 'book-1',
      ));

      expect(result.isRight(), true);
      result.fold((_) {}, (r) {
        expect(r.justCompleted, false);
        expect(r.hasQuiz, true);
      });
      verifyNever(mockBookRepo.updateReadingProgress(any));
    });

    test('allChaptersDone_quizJustPassed_shouldComplete', () async {
      when(mockBookRepo.getReadingProgress(userId: 'user-1', bookId: 'book-1'))
          .thenAnswer((_) async => Right(_makeProgress(completedChapterIds: ['ch-0', 'ch-1'])));
      when(mockBookRepo.getChapters('book-1'))
          .thenAnswer((_) async => Right(_makeChapters(2)));
      when(mockQuizRepo.bookHasQuiz('book-1'))
          .thenAnswer((_) async => const Right(true));
      when(mockBookRepo.updateReadingProgress(any))
          .thenAnswer((_) async => Right(_makeProgress(
            completedChapterIds: ['ch-0', 'ch-1'],
            isCompleted: true,
            quizPassed: true,
          )));

      final result = await usecase(const HandleBookCompletionParams(
        userId: 'user-1',
        bookId: 'book-1',
        quizJustPassed: true,
      ));

      expect(result.isRight(), true);
      result.fold((_) {}, (r) {
        expect(r.justCompleted, true);
        expect(r.hasQuiz, true);
      });
    });

    test('notAllChaptersDone_shouldNotComplete', () async {
      when(mockBookRepo.getReadingProgress(userId: 'user-1', bookId: 'book-1'))
          .thenAnswer((_) async => Right(_makeProgress(completedChapterIds: ['ch-0'])));
      when(mockBookRepo.getChapters('book-1'))
          .thenAnswer((_) async => Right(_makeChapters(3)));
      when(mockQuizRepo.bookHasQuiz('book-1'))
          .thenAnswer((_) async => const Right(false));

      final result = await usecase(const HandleBookCompletionParams(
        userId: 'user-1',
        bookId: 'book-1',
      ));

      expect(result.isRight(), true);
      result.fold((_) {}, (r) {
        expect(r.justCompleted, false);
      });
      verifyNever(mockBookRepo.updateReadingProgress(any));
    });

    test('alreadyCompleted_shouldReturnWithoutAction', () async {
      when(mockBookRepo.getReadingProgress(userId: 'user-1', bookId: 'book-1'))
          .thenAnswer((_) async => Right(_makeProgress(
            completedChapterIds: ['ch-0', 'ch-1'],
            isCompleted: true,
          )));
      when(mockQuizRepo.bookHasQuiz('book-1'))
          .thenAnswer((_) async => const Right(false));

      final result = await usecase(const HandleBookCompletionParams(
        userId: 'user-1',
        bookId: 'book-1',
      ));

      expect(result.isRight(), true);
      result.fold((_) {}, (r) {
        expect(r.justCompleted, false);
      });
      verifyNever(mockBookRepo.getChapters(any));
      verifyNever(mockBookRepo.updateReadingProgress(any));
    });
  });
}
```

- [ ] **Step 3: Generate mocks and run tests**

```bash
cd /Users/wonderelt/Desktop/Owlio && dart run build_runner build --delete-conflicting-outputs
flutter test test/unit/domain/usecases/reading/handle_book_completion_usecase_test.dart
```

Expected: All 5 tests pass.

- [ ] **Step 4: Register provider**

In `lib/presentation/providers/usecase_providers.dart`:

```dart
final handleBookCompletionUseCaseProvider = Provider((ref) {
  return HandleBookCompletionUseCase(
    ref.watch(bookRepositoryProvider),
    ref.watch(bookQuizRepositoryProvider),
  );
});
```

- [ ] **Step 5: Simplify SupabaseBookRepository.markChapterComplete**

In `lib/data/repositories/supabase/supabase_book_repository.dart`, simplify `markChapterComplete` to only:
1. Get/upsert reading_progress
2. Add chapterId to completed_chapter_ids
3. Recalculate completion_percentage
4. Update reading_progress (but do NOT set is_completed — UseCase handles that)
5. Log daily_chapter_read

Remove the `bookHasQuiz` RPC call and the `is_completed` logic from this method. The method should return the updated `ReadingProgress` with the new completion percentage but `isCompleted` unchanged.

- [ ] **Step 6: Remove _handleQuizPassed from SupabaseBookQuizRepository**

In `lib/data/repositories/supabase/supabase_book_quiz_repository.dart`:
1. Remove the `_handleQuizPassed` private method entirely.
2. In `submitQuizResult`, remove the call to `_handleQuizPassed`. The repository just inserts the quiz result and returns it.

- [ ] **Step 7: Update ChapterCompletionNotifier.markComplete**

In `lib/presentation/providers/book_provider.dart`, after the `markChapterComplete` UseCase call succeeds:

```dart
// After markChapterComplete returns successfully:
if (!wasAlreadyCompleted) {
  final settings = _ref.read(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();

  // Award chapter XP
  await _ref.read(userControllerProvider.notifier).addXP(
    settings.xpChapterComplete,
    source: 'chapter_complete',
    sourceId: chapterId,
  );

  // Check if book is now complete
  final completionUseCase = _ref.read(handleBookCompletionUseCaseProvider);
  final completionResult = await completionUseCase(HandleBookCompletionParams(
    userId: userId,
    bookId: bookId,
  ));

  completionResult.fold(
    (_) {},
    (result) async {
      if (result.justCompleted && !result.hasQuiz) {
        await _ref.read(userControllerProvider.notifier).addXP(
          settings.xpBookComplete,
          source: 'book_complete',
          sourceId: bookId,
        );
      }
    },
  );
}
```

Remove the old `bookHasQuizUseCaseProvider` call and the inline completion logic.

- [ ] **Step 8: Update BookQuizController.submitQuiz**

In `lib/presentation/providers/book_quiz_provider.dart`, after quiz result is saved:

```dart
// After savedResult is returned and isPassing:
if (savedResult != null && savedResult.isPassing) {
  final settings = _ref.read(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();
  await _ref.read(userControllerProvider.notifier).addXP(
    settings.xpQuizPass,
    source: 'quiz_pass',
    sourceId: quizId,
  );

  // Check book completion (quiz just passed)
  final completionUseCase = _ref.read(handleBookCompletionUseCaseProvider);
  await completionUseCase(HandleBookCompletionParams(
    userId: userId!,
    bookId: bookId,
    quizJustPassed: true,
  ));
}
```

- [ ] **Step 9: Run analyze and tests**

```bash
dart analyze lib/
flutter test
```

Expected: All pass.

- [ ] **Step 10: Commit**

```bash
git add lib/domain/usecases/reading/handle_book_completion_usecase.dart test/unit/domain/usecases/reading/ lib/presentation/providers/usecase_providers.dart lib/presentation/providers/book_provider.dart lib/presentation/providers/book_quiz_provider.dart lib/data/repositories/supabase/supabase_book_repository.dart lib/data/repositories/supabase/supabase_book_quiz_repository.dart
git commit -m "refactor: extract book completion logic to HandleBookCompletionUseCase"
```

---

### Task 6: CompleteInlineActivityUseCase

**Files:**
- Create: `lib/domain/usecases/activity/complete_inline_activity_usecase.dart`
- Modify: `lib/presentation/providers/usecase_providers.dart`
- Modify: `lib/presentation/providers/reader_provider.dart`
- Create: `test/unit/domain/usecases/activity/complete_inline_activity_usecase_test.dart`

- [ ] **Step 1: Create the UseCase**

Create `lib/domain/usecases/activity/complete_inline_activity_usecase.dart`:

```dart
import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../repositories/book_repository.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class CompleteInlineActivityParams {
  const CompleteInlineActivityParams({
    required this.userId,
    required this.activityId,
    required this.isCorrect,
    required this.xpEarned,
    required this.wordsLearned,
  });
  final String userId;
  final String activityId;
  final bool isCorrect;
  final int xpEarned;
  final List<String> wordsLearned;
}

class CompleteInlineActivityResult {
  const CompleteInlineActivityResult({
    required this.isNewCompletion,
    required this.wordsAdded,
  });
  final bool isNewCompletion;
  final int wordsAdded;
}

class CompleteInlineActivityUseCase
    implements UseCase<CompleteInlineActivityResult, CompleteInlineActivityParams> {
  const CompleteInlineActivityUseCase(this._bookRepository, this._vocabularyRepository);
  final BookRepository _bookRepository;
  final VocabularyRepository _vocabularyRepository;

  @override
  Future<Either<Failure, CompleteInlineActivityResult>> call(
    CompleteInlineActivityParams params,
  ) async {
    // 1. Save result (DB UNIQUE constraint handles dedup)
    final saveResult = await _bookRepository.saveInlineActivityResult(
      userId: params.userId,
      activityId: params.activityId,
      isCorrect: params.isCorrect,
      xpEarned: params.xpEarned,
    );

    final isNew = saveResult.fold((_) => false, (v) => v);

    // 2. Add vocabulary words if any
    int wordsAdded = 0;
    if (params.wordsLearned.isNotEmpty) {
      final vocabResult = await _vocabularyRepository.addWordsBatch(
        userId: params.userId,
        wordIds: params.wordsLearned,
        immediate: !params.isCorrect,
      );
      wordsAdded = vocabResult.fold((_) => 0, (count) => count);
    }

    return Right(CompleteInlineActivityResult(
      isNewCompletion: isNew,
      wordsAdded: wordsAdded,
    ));
  }
}
```

Note: Verify `VocabularyRepository` has an `addWordsBatch` method. If the method is named differently (e.g., `addWords` or the UseCase `AddWordsBatchUseCase` wraps a different repo method), adapt accordingly. Read the file before implementing.

- [ ] **Step 2: Write tests**

Create `test/unit/domain/usecases/activity/complete_inline_activity_usecase_test.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:owlio/domain/repositories/book_repository.dart';
import 'package:owlio/domain/repositories/vocabulary_repository.dart';
import 'package:owlio/domain/usecases/activity/complete_inline_activity_usecase.dart';

@GenerateMocks([BookRepository, VocabularyRepository])
import 'complete_inline_activity_usecase_test.mocks.dart';

void main() {
  late CompleteInlineActivityUseCase usecase;
  late MockBookRepository mockBookRepo;
  late MockVocabularyRepository mockVocabRepo;

  setUp(() {
    mockBookRepo = MockBookRepository();
    mockVocabRepo = MockVocabularyRepository();
    usecase = CompleteInlineActivityUseCase(mockBookRepo, mockVocabRepo);
  });

  group('CompleteInlineActivityUseCase', () {
    test('newCompletion_shouldReturnIsNew', () async {
      when(mockBookRepo.saveInlineActivityResult(
        userId: 'user-1',
        activityId: 'act-1',
        isCorrect: true,
        xpEarned: 25,
      )).thenAnswer((_) async => const Right(true));

      final result = await usecase(const CompleteInlineActivityParams(
        userId: 'user-1',
        activityId: 'act-1',
        isCorrect: true,
        xpEarned: 25,
        wordsLearned: [],
      ));

      expect(result.isRight(), true);
      result.fold((_) {}, (r) {
        expect(r.isNewCompletion, true);
        expect(r.wordsAdded, 0);
      });
    });

    test('duplicateCompletion_shouldReturnNotNew', () async {
      when(mockBookRepo.saveInlineActivityResult(
        userId: 'user-1',
        activityId: 'act-1',
        isCorrect: true,
        xpEarned: 25,
      )).thenAnswer((_) async => const Right(false));

      final result = await usecase(const CompleteInlineActivityParams(
        userId: 'user-1',
        activityId: 'act-1',
        isCorrect: true,
        xpEarned: 25,
        wordsLearned: [],
      ));

      result.fold((_) {}, (r) {
        expect(r.isNewCompletion, false);
      });
    });

    test('withWords_shouldAddVocabulary', () async {
      when(mockBookRepo.saveInlineActivityResult(
        userId: 'user-1',
        activityId: 'act-1',
        isCorrect: true,
        xpEarned: 25,
      )).thenAnswer((_) async => const Right(true));
      when(mockVocabRepo.addWordsBatch(
        userId: 'user-1',
        wordIds: ['w1', 'w2'],
        immediate: false,
      )).thenAnswer((_) async => const Right(2));

      final result = await usecase(const CompleteInlineActivityParams(
        userId: 'user-1',
        activityId: 'act-1',
        isCorrect: true,
        xpEarned: 25,
        wordsLearned: ['w1', 'w2'],
      ));

      result.fold((_) {}, (r) {
        expect(r.isNewCompletion, true);
        expect(r.wordsAdded, 2);
      });
    });
  });
}
```

- [ ] **Step 3: Generate mocks and run tests**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/unit/domain/usecases/activity/complete_inline_activity_usecase_test.dart
```

Expected: All 3 tests pass.

- [ ] **Step 4: Register provider and update reader_provider.dart**

In `lib/presentation/providers/usecase_providers.dart`:

```dart
final completeInlineActivityUseCaseProvider = Provider((ref) {
  return CompleteInlineActivityUseCase(
    ref.watch(bookRepositoryProvider),
    ref.watch(vocabularyRepositoryProvider),
  );
});
```

In `lib/presentation/providers/reader_provider.dart`, replace `_handleInlineActivityCompletionImpl` body with:

```dart
Future<void> _handleInlineActivityCompletionImpl(
  WidgetRef ref, {
  required String activityId,
  required bool isCorrect,
  required int xpEarned,
  required List<String> wordsLearned,
  void Function(bool isCorrect, int xpEarned)? onComplete,
}) async {
  // Local dedup check
  final completedActivities = ref.read(inlineActivityStateProvider);
  if (completedActivities.containsKey(activityId)) return;

  ref.read(inlineActivityStateProvider.notifier).markCompleted(activityId, isCorrect);

  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return;

  // Domain logic via UseCase
  final useCase = ref.read(completeInlineActivityUseCaseProvider);
  final result = await useCase(CompleteInlineActivityParams(
    userId: userId,
    activityId: activityId,
    isCorrect: isCorrect,
    xpEarned: xpEarned,
    wordsLearned: wordsLearned,
  ));

  final activityResult = result.fold((_) => null, (r) => r);
  if (activityResult == null) return;

  // UI concerns — stay in presentation layer
  if (activityResult.isNewCompletion) {
    ref.invalidate(dailyQuestProgressProvider);

    if (xpEarned > 0) {
      ref.read(sessionXPProvider.notifier).addXP(xpEarned);
      await ref.read(userControllerProvider.notifier).addXP(
        xpEarned,
        source: 'inline_activity',
        sourceId: activityId,
      );
    }
  }

  if (activityResult.wordsAdded > 0) {
    ref.read(learnedWordsProvider.notifier).addWords(wordsLearned);
    ref.invalidate(dailyReviewWordsProvider);
    ref.invalidate(userVocabularyProgressProvider);
    ref.invalidate(learnedWordsWithDetailsProvider);
  }

  onComplete?.call(isCorrect, xpEarned);
}
```

Remove the old inline `saveInlineActivityResultUseCaseProvider` and `addWordsBatchUseCaseProvider` calls.

- [ ] **Step 5: Run analyze**

```bash
dart analyze lib/domain/usecases/activity/complete_inline_activity_usecase.dart lib/presentation/providers/reader_provider.dart lib/presentation/providers/usecase_providers.dart
```

- [ ] **Step 6: Commit**

```bash
git add lib/domain/usecases/activity/complete_inline_activity_usecase.dart test/unit/domain/usecases/activity/ lib/presentation/providers/reader_provider.dart lib/presentation/providers/usecase_providers.dart
git commit -m "refactor: extract inline activity completion to CompleteInlineActivityUseCase"
```

---

### Task 7: Chapter Lock Status Provider + Book Access Typed Getters

**Files:**
- Modify: `lib/presentation/providers/book_provider.dart` (add chaptersWithLockStatusProvider)
- Modify: `lib/presentation/screens/library/book_detail_screen.dart`
- Modify: `lib/domain/entities/student_assignment.dart`
- Modify: `lib/presentation/providers/book_access_provider.dart`

- [ ] **Step 1: Add ChapterWithLockStatus class and provider**

In `lib/presentation/providers/book_provider.dart`, add near the top (after imports):

```dart
class ChapterWithLockStatus {
  const ChapterWithLockStatus({
    required this.chapter,
    required this.isLocked,
    required this.isCompleted,
  });
  final Chapter chapter;
  final bool isLocked;
  final bool isCompleted;
}

final chaptersWithLockStatusProvider =
    Provider.family<List<ChapterWithLockStatus>, String>((ref, bookId) {
  final chapters = ref.watch(chaptersProvider(bookId)).valueOrNull ?? [];
  final progress = ref.watch(readingProgressProvider(bookId)).valueOrNull;
  final completedIds = progress?.completedChapterIds ?? [];

  return chapters.indexed.map((e) {
    final (index, chapter) = e;
    final isLocked = index > 0 &&
        chapters.take(index).any((c) => !completedIds.contains(c.id));
    return ChapterWithLockStatus(
      chapter: chapter,
      isLocked: isLocked,
      isCompleted: completedIds.contains(chapter.id),
    );
  }).toList();
});
```

- [ ] **Step 2: Update BookDetailScreen**

In `lib/presentation/screens/library/book_detail_screen.dart`, replace the chapter list builder that computes lock status inline. Use `chaptersWithLockStatusProvider(bookId)` instead:

```dart
final chaptersWithLock = ref.watch(chaptersWithLockStatusProvider(widget.bookId));

// In SliverList delegate:
(context, index) {
  final item = chaptersWithLock[index];
  return _ChapterTile(
    number: index + 1,
    title: item.chapter.title,
    duration: item.chapter.estimatedMinutes,
    isLocked: item.isLocked,
    isCompleted: item.isCompleted,
    // ... rest of constructor
  );
}
```

Remove the inline `completedIds`, `isLocked` computation for-loop, and `isCompleted` check.

- [ ] **Step 3: Add typed getters to StudentAssignment entity**

In `lib/domain/entities/student_assignment.dart`, add:

```dart
/// Whether this assignment locks the library to only the assigned book.
bool get hasLibraryLock => contentConfig['lockLibrary'] == true;

/// The book ID this assignment is for (book-type assignments only).
String? get lockedBookId => contentConfig['bookId'] as String?;
```

- [ ] **Step 4: Update bookLockProvider**

In `lib/presentation/providers/book_access_provider.dart`, replace the dynamic map access:

```dart
// Before:
final lockLibrary = assignment.contentConfig['lockLibrary'];
if (lockLibrary == true) {
  hasLock = true;
  final bookId = assignment.contentConfig['bookId'] as String?;
  if (bookId != null) {
    allowedBooks.add(bookId);
  }
}

// After:
if (assignment.hasLibraryLock) {
  hasLock = true;
  final bookId = assignment.lockedBookId;
  if (bookId != null) {
    allowedBooks.add(bookId);
  }
}
```

- [ ] **Step 5: Run analyze**

```bash
dart analyze lib/presentation/providers/book_provider.dart lib/presentation/screens/library/book_detail_screen.dart lib/domain/entities/student_assignment.dart lib/presentation/providers/book_access_provider.dart
```

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/providers/book_provider.dart lib/presentation/screens/library/book_detail_screen.dart lib/domain/entities/student_assignment.dart lib/presentation/providers/book_access_provider.dart
git commit -m "refactor: extract chapter lock logic to provider, add typed assignment getters"
```

---

## Phase 3: Error Handling / UX / Performance

### Task 8: Provider Error Propagation

**Files:**
- Modify: `lib/presentation/providers/book_provider.dart`
- Modify: `lib/presentation/providers/book_quiz_provider.dart`

- [ ] **Step 1: Fix book_provider.dart FutureProviders**

In `lib/presentation/providers/book_provider.dart`, update all `fold` calls that swallow errors. For each provider that returns a list, change:

```dart
// Before (repeated in booksProvider, bookSearchProvider, recommendedBooksProvider,
// continueReadingProvider, chaptersProvider):
return result.fold(
  (failure) => [],
  (items) => items,
);

// After:
return result.fold(
  (failure) => throw Exception(failure.message),
  (items) => items,
);
```

For providers that return nullable single items:

```dart
// Before (bookByIdProvider, readingProgressProvider):
return result.fold(
  (failure) => null,
  (item) => item,
);

// After:
return result.fold(
  (failure) => throw Exception(failure.message),
  (item) => item,
);
```

For `completedBookIdsProvider`:

```dart
// Before:
return result.fold(
  (failure) => <String>{},
  (ids) => ids,
);

// After:
return result.fold(
  (failure) => throw Exception(failure.message),
  (ids) => ids,
);
```

- [ ] **Step 2: Fix book_quiz_provider.dart FutureProviders**

Same pattern for `bookHasQuizProvider`, `bookQuizProvider`, `bestQuizResultProvider`, `studentQuizResultsProvider`.

- [ ] **Step 3: Run analyze**

```bash
dart analyze lib/presentation/providers/book_provider.dart lib/presentation/providers/book_quiz_provider.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/providers/book_provider.dart lib/presentation/providers/book_quiz_provider.dart
git commit -m "fix: propagate errors in book providers instead of swallowing silently"
```

---

### Task 9: Error State Widgets in Screens

**Files:**
- Modify: `lib/presentation/screens/library/library_screen.dart`
- Modify: `lib/presentation/screens/library/book_detail_screen.dart`

- [ ] **Step 1: Update library_screen.dart**

The project has `ErrorStateWidget` at `lib/presentation/widgets/common/error_state_widget.dart`. Import and use it.

For the categories error (currently `SizedBox(height: 80)`):

```dart
// Before:
error: (error, _) => const SizedBox(height: 80),

// After:
error: (error, _) => SizedBox(
  height: 80,
  child: Center(
    child: TextButton.icon(
      onPressed: () => ref.invalidate(booksProvider),
      icon: const Icon(Icons.refresh, size: 16),
      label: const Text('Retry'),
    ),
  ),
),
```

For the book list error (currently `Center(child: Text('Error: $error'))`):

```dart
// Before:
error: (error, _) => Center(child: Text('Error: $error')),

// After:
error: (error, _) => ErrorStateWidget(
  message: 'Failed to load books',
  onRetry: () => ref.invalidate(booksProvider),
),
```

- [ ] **Step 2: Update book_detail_screen.dart**

Replace raw error text with `ErrorStateWidget`:

```dart
// For book load error:
error: (error, _) => Scaffold(
  appBar: AppBar(),
  body: ErrorStateWidget(
    message: 'Failed to load book details',
    onRetry: () => ref.invalidate(bookByIdProvider(widget.bookId)),
  ),
),

// For chapters error:
error: (error, _) => SliverToBoxAdapter(
  child: ErrorStateWidget(
    message: 'Failed to load chapters',
    onRetry: () => ref.invalidate(chaptersProvider(widget.bookId)),
  ),
),
```

- [ ] **Step 3: Run analyze**

```bash
dart analyze lib/presentation/screens/library/library_screen.dart lib/presentation/screens/library/book_detail_screen.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/screens/library/library_screen.dart lib/presentation/screens/library/book_detail_screen.dart
git commit -m "fix: show proper error states with retry in library and book detail screens"
```

---

### Task 10: Unit Assignment Filtering + autoDispose

**Files:**
- Modify: `lib/presentation/providers/book_provider.dart` (_updateAssignmentProgress)
- Modify: `lib/presentation/providers/book_provider.dart` (add autoDispose)
- Modify: `lib/presentation/providers/book_quiz_provider.dart` (add autoDispose)
- Modify: `lib/presentation/providers/reader_provider.dart` (completedInlineActivitiesProvider)
- Modify: `lib/presentation/providers/content_block_provider.dart`

- [ ] **Step 1: Filter unit assignments in _updateAssignmentProgress**

In `lib/presentation/providers/book_provider.dart`, in the `_updateAssignmentProgress` method, find the unit assignment loop (after the book assignment loop). Add a filter before calling the RPC:

```dart
// Before (calls RPC for ALL unit assignments):
for (final assignment in assignments) {
  if (assignment.scopeLpUnitId != null && ...) {
    await calculateUnitProgressUseCase(...);
  }
}

// After (only call for units that might contain this book):
for (final assignment in assignments) {
  if (assignment.scopeLpUnitId != null &&
      assignment.status != StudentAssignmentStatus.completed) {
    // Only recalculate if this book could be part of the unit
    // The contentConfig may contain item references — check if bookId is referenced
    final unitItems = assignment.contentConfig['itemIds'] as List<dynamic>?;
    if (unitItems != null && !unitItems.contains(bookId)) {
      continue; // Skip — this book is not in this unit
    }
    await _ref.read(calculateUnitProgressUseCaseProvider)(
      CalculateUnitProgressParams(
        studentId: userId,
        scopeLpUnitId: assignment.scopeLpUnitId!,
      ),
    );
  }
}
```

Note: Read the actual `_updateAssignmentProgress` code and `contentConfig` structure before implementing. The filter key may differ — adapt to whatever identifies unit items.

- [ ] **Step 2: Add autoDispose to book FutureProviders**

In `lib/presentation/providers/book_provider.dart`, add `.autoDispose` to family providers:

```dart
// Before:
final booksProvider = FutureProvider.family<List<Book>, BookFilters?>((ref, filters) async {
// After:
final booksProvider = FutureProvider.autoDispose.family<List<Book>, BookFilters?>((ref, filters) async {
```

Apply same change to: `bookByIdProvider`, `bookSearchProvider`, `chaptersProvider`, `readingProgressProvider`, `completedBookIdsProvider`.

In `lib/presentation/providers/reader_provider.dart`:
```dart
// completedInlineActivitiesProvider — add autoDispose
final completedInlineActivitiesProvider = FutureProvider.autoDispose.family<List<String>, String>(...);
```

In `lib/presentation/providers/content_block_provider.dart`:
```dart
// contentBlocksProvider, chapterUsesContentBlocksProvider — add autoDispose
```

- [ ] **Step 3: Fix any keepAlive issues**

After adding `autoDispose`, check if any provider that is invalidated elsewhere needs `ref.keepAlive()` temporarily. Common case: `readingProgressProvider` is invalidated in `ChapterCompletionNotifier` — if the notifier runs while the screen is disposed, the invalidation is harmless. But if a screen watches the provider and navigates away during an async op, verify no state is lost.

```bash
dart analyze lib/presentation/providers/
```

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/providers/book_provider.dart lib/presentation/providers/reader_provider.dart lib/presentation/providers/content_block_provider.dart lib/presentation/providers/book_quiz_provider.dart
git commit -m "perf: filter unit assignment RPCs, add autoDispose to book providers"
```

---

### Task 11: Update Audit Spec Status

**Files:**
- Modify: `docs/specs/01-book-system.md`

- [ ] **Step 1: Update finding statuses**

In `docs/specs/01-book-system.md`, update the Status column for fixed findings:

| # | Status |
|---|--------|
| 1 | Fixed |
| 2 | Fixed |
| 3 | Fixed |
| 4 | Fixed |
| 5 | Fixed |
| 6 | Fixed |
| 7 | Fixed |
| 8 | Fixed |
| 9 | Fixed |
| 10 | N/A (already fixed) |
| 23 | Fixed |
| 24 | Fixed (via #7) |
| 25 | Fixed |
| 30 | Fixed |
| 31 | Fixed |

- [ ] **Step 2: Commit all docs**

```bash
git add docs/specs/01-book-system.md docs/superpowers/specs/2026-03-27-book-system-integrity-fixes-design.md
git commit -m "docs: update book system audit findings status after integrity fixes"
```
