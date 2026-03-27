# Book Quiz Audit Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all 12 actionable issues from the Book Quiz audit — 3 high-severity bugs, 2 medium code quality issues, 6 low dead code/cleanup items, 1 DB optimization.

**Architecture:** All Flutter changes follow the existing Clean Architecture. DB changes go in a single new migration. Admin panel follows its established direct-Supabase pattern.

**Tech Stack:** Flutter/Dart, Riverpod, Supabase (PostgreSQL), owlio_shared package

---

## File Map

| File | Action | What Changes |
|------|--------|-------------|
| `supabase/migrations/20260327100000_book_quiz_audit_fixes.sql` | Create | Migration: fix `book_has_quiz` RPC, fix `get_best_book_quiz_result` RPC, add composite index |
| `lib/data/repositories/supabase/supabase_book_repository.dart` | Modify | Add `quiz_passed` to `updateReadingProgress` data map |
| `lib/data/models/book_quiz/book_quiz_model.dart` | Modify | Replace `_parseType`/`_typeToString` with shared enum, remove unused `fromEntity` constructors |
| `lib/presentation/screens/quiz/book_quiz_screen.dart` | Modify | Add stopwatch, remove dead nav condition, remove `answeredIndices` passing |
| `lib/presentation/widgets/book_quiz/book_quiz_progress_bar.dart` | Modify | Remove `answeredIndices` param |
| `lib/presentation/widgets/book_quiz/book_quiz_result_card.dart` | Modify | Replace hard-coded colors with `AppColors` |
| `owlio_admin/lib/features/quizzes/screens/book_quiz_edit_screen.dart` | Modify | English labels, 0-question validation |
| `owlio_admin/lib/features/quizzes/screens/quiz_question_edit_screen.dart` | Modify | English labels, enum `dbValue` switches |

---

### Task 1: Database Migration — Fix RPCs and Add Index (#2, #3 server, #13)

**Files:**
- Create: `supabase/migrations/20260327100000_book_quiz_audit_fixes.sql`

- [ ] **Step 1: Create migration file**

```sql
-- Book Quiz Audit Fixes
-- Fixes: #2 (get_best_book_quiz_result missing auth), #3 (book_has_quiz 0-question check), #13 (composite index)

-- =============================================
-- FIX #3: book_has_quiz must require at least one question
-- A published quiz with 0 questions should not gate book completion
-- =============================================
CREATE OR REPLACE FUNCTION book_has_quiz(p_book_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM book_quizzes bq
        WHERE bq.book_id = p_book_id
        AND bq.is_published = true
        AND EXISTS (
            SELECT 1 FROM book_quiz_questions bqq
            WHERE bqq.quiz_id = bq.id
        )
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- =============================================
-- FIX #2: get_best_book_quiz_result must enforce authorization
-- Caller must be the user themselves, or a teacher/admin/head in the same school
-- =============================================
CREATE OR REPLACE FUNCTION get_best_book_quiz_result(
    p_user_id UUID,
    p_book_id UUID
)
RETURNS TABLE (
    result_id UUID,
    quiz_id UUID,
    score DECIMAL,
    max_score DECIMAL,
    percentage DECIMAL,
    is_passing BOOLEAN,
    attempt_number INTEGER,
    time_spent INTEGER,
    completed_at TIMESTAMPTZ
) AS $$
DECLARE
    v_caller_id UUID;
    v_caller_role TEXT;
    v_caller_school UUID;
    v_target_school UUID;
BEGIN
    v_caller_id := auth.uid();

    -- Allow users to query their own results
    IF v_caller_id = p_user_id THEN
        RETURN QUERY
        SELECT
            bqr.id,
            bqr.quiz_id,
            bqr.score,
            bqr.max_score,
            bqr.percentage,
            bqr.is_passing,
            bqr.attempt_number,
            bqr.time_spent,
            bqr.completed_at
        FROM book_quiz_results bqr
        WHERE bqr.user_id = p_user_id
        AND bqr.book_id = p_book_id
        ORDER BY bqr.percentage DESC
        LIMIT 1;
        RETURN;
    END IF;

    -- For other users: caller must be teacher/admin/head in same school
    SELECT p.role, p.school_id INTO v_caller_role, v_caller_school
    FROM profiles p
    WHERE p.id = v_caller_id;

    IF v_caller_role NOT IN ('teacher', 'head', 'admin') THEN
        RETURN;
    END IF;

    SELECT p.school_id INTO v_target_school
    FROM profiles p
    WHERE p.id = p_user_id;

    IF v_caller_school IS NULL OR v_target_school IS NULL OR v_caller_school != v_target_school THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        bqr.id,
        bqr.quiz_id,
        bqr.score,
        bqr.max_score,
        bqr.percentage,
        bqr.is_passing,
        bqr.attempt_number,
        bqr.time_spent,
        bqr.completed_at
    FROM book_quiz_results bqr
    WHERE bqr.user_id = p_user_id
    AND bqr.book_id = p_book_id
    ORDER BY bqr.percentage DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- FIX #13: Add composite index for (user_id, book_id) queries
-- Used by getUserQuizResults and get_best_book_quiz_result
-- =============================================
CREATE INDEX IF NOT EXISTS idx_book_quiz_results_user_book
    ON book_quiz_results(user_id, book_id);
```

- [ ] **Step 2: Dry-run the migration**

Run: `supabase db push --dry-run`
Expected: Migration listed as pending, no errors.

- [ ] **Step 3: Push the migration**

Run: `supabase db push`
Expected: Migration applied successfully.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260327100000_book_quiz_audit_fixes.sql
git commit -m "fix: book quiz RPC auth, 0-question guard, composite index (#2, #3, #13)"
```

---

### Task 2: Fix `quiz_passed` Never Written to DB (#1)

**Files:**
- Modify: `lib/data/repositories/supabase/supabase_book_repository.dart:239-250`

- [ ] **Step 1: Add `quiz_passed` to the upsert data map**

In `updateReadingProgress`, add `quiz_passed` to the `data` map, right after `completed_at`:

```dart
      final data = {
        'user_id': progress.userId,
        'book_id': progress.bookId,
        'chapter_id': progress.chapterId,
        'current_page': progress.currentPage,
        'is_completed': progress.isCompleted,
        'completion_percentage': progress.completionPercentage,
        'total_reading_time': progress.totalReadingTime,
        'completed_chapter_ids': progress.completedChapterIds,
        'completed_at': progress.completedAt?.toIso8601String(),
        'quiz_passed': progress.quizPassed,
        'updated_at': DateTime.now().toIso8601String(),
      };
```

The only change is adding the line `'quiz_passed': progress.quizPassed,`.

- [ ] **Step 2: Run analyzer**

Run: `dart analyze lib/data/repositories/supabase/supabase_book_repository.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/data/repositories/supabase/supabase_book_repository.dart
git commit -m "fix: write quiz_passed to DB in updateReadingProgress (#1)"
```

---

### Task 3: Replace Type Parsing Duplication with Shared Enum (#8) + Remove Unused `fromEntity` (#7)

**Files:**
- Modify: `lib/data/models/book_quiz/book_quiz_model.dart`

- [ ] **Step 1: Replace `_parseType` with `BookQuizQuestionType.fromDbValue` in `toEntity()`**

Change `toEntity()` method at line 156-167:

```dart
  BookQuizQuestion toEntity() {
    return BookQuizQuestion(
      id: id,
      quizId: quizId,
      type: BookQuizQuestionType.fromDbValue(type),
      orderIndex: orderIndex,
      question: question,
      content: _parseContent(type, content),
      explanation: explanation,
      points: points,
    );
  }
```

The only change: `_parseType(type)` → `BookQuizQuestionType.fromDbValue(type)`.

- [ ] **Step 2: Remove the `_parseType` and `_typeToString` static methods**

Delete the entire block at lines 173-203:

```dart
  // DELETE THIS BLOCK:
  static BookQuizQuestionType _parseType(String type) { ... }
  static String _typeToString(BookQuizQuestionType type) { ... }
```

- [ ] **Step 3: Remove `BookQuizModel.fromEntity` constructor**

Delete lines 37-52 (the `factory BookQuizModel.fromEntity(BookQuiz entity)` constructor).

- [ ] **Step 4: Remove `BookQuizQuestionModel.fromEntity` constructor and `_contentToJson`**

Delete lines 121-132 (the `factory BookQuizQuestionModel.fromEntity(BookQuizQuestion entity)` constructor).

Also delete lines 276-318 (the `_contentToJson` method) since it was only used by `fromEntity`.

- [ ] **Step 5: Add the owlio_shared import if not already present**

Check the file's imports. The shared package enum `BookQuizQuestionType` is used via `book_quiz.dart` entity imports. Verify `BookQuizQuestionType.fromDbValue` is accessible. The entity file already imports it, so the model file accesses it through `../../../domain/entities/book_quiz.dart`.

- [ ] **Step 6: Run analyzer**

Run: `dart analyze lib/data/models/book_quiz/book_quiz_model.dart`
Expected: No issues found.

- [ ] **Step 7: Commit**

```bash
git add lib/data/models/book_quiz/book_quiz_model.dart
git commit -m "refactor: use shared enum for quiz type parsing, remove unused fromEntity (#7, #8)"
```

---

### Task 4: Fix BookQuizScreen — Stopwatch, Dead Nav, Dead Param (#4, #5, #6)

**Files:**
- Modify: `lib/presentation/screens/quiz/book_quiz_screen.dart`
- Modify: `lib/presentation/widgets/book_quiz/book_quiz_progress_bar.dart`

- [ ] **Step 1: Add `Stopwatch` field and start it in `initState`**

Add a field after the `_answers` map declaration (line 39):

```dart
  final Map<String, dynamic> _answers = {};
  final Stopwatch _stopwatch = Stopwatch();
```

In `initState` (line 42-45), start the stopwatch:

```dart
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _stopwatch.start();
  }
```

- [ ] **Step 2: Pass `timeSpent` to `submitQuiz`**

In `_submitQuiz` method (line 411-418), add `timeSpent`:

```dart
    await ref.read(bookQuizControllerProvider.notifier).submitQuiz(
              quizId: quiz.id,
              bookId: widget.bookId,
              score: gradeResult.totalScore,
              maxScore: gradeResult.maxScore,
              answers: gradeResult.answersJson,
              passingScore: quiz.passingScore,
              timeSpent: _stopwatch.elapsed.inSeconds,
            );
```

- [ ] **Step 3: Reset stopwatch on retake**

In `_retakeQuiz` method (line 430-442), reset and restart the stopwatch:

```dart
  void _retakeQuiz(BookQuiz quiz) {
    ref.read(bookQuizControllerProvider.notifier).reset();
    setState(() {
      _answers.clear();
      _currentPage = 0;
      _showResults = false;
      _isSubmitting = false;
    });
    _stopwatch.reset();
    _stopwatch.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (_pageController.hasClients) _pageController.jumpToPage(0);
    });
  }
```

- [ ] **Step 4: Fix dead navigation condition (#5)**

Replace `_goToNextPage` (lines 375-383):

```dart
  void _goToNextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
```

- [ ] **Step 5: Remove `answeredIndices` from `BookQuizProgressBar` call site (#4)**

Replace the `BookQuizProgressBar` widget in `_buildQuizScaffold` (lines 204-211):

```dart
                  child: BookQuizProgressBar(
                    currentIndex: _currentPage,
                    totalQuestions: questions.length,
                  ),
```

- [ ] **Step 6: Remove `answeredIndices` from `BookQuizProgressBar` constructor**

In `lib/presentation/widgets/book_quiz/book_quiz_progress_bar.dart`, update the constructor and remove the field:

```dart
class BookQuizProgressBar extends StatelessWidget {
  const BookQuizProgressBar({
    super.key,
    required this.currentIndex,
    required this.totalQuestions,
  });

  final int currentIndex;
  final int totalQuestions;
```

Remove the `final Set<int> answeredIndices;` field (line 19).

- [ ] **Step 7: Run analyzer**

Run: `dart analyze lib/presentation/screens/quiz/book_quiz_screen.dart lib/presentation/widgets/book_quiz/book_quiz_progress_bar.dart`
Expected: No issues found.

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/screens/quiz/book_quiz_screen.dart lib/presentation/widgets/book_quiz/book_quiz_progress_bar.dart
git commit -m "fix: add quiz timer, remove dead nav condition and answeredIndices (#4, #5, #6)"
```

---

### Task 5: Replace Hard-Coded Colors with AppColors (#10)

**Files:**
- Modify: `lib/presentation/widgets/book_quiz/book_quiz_result_card.dart:32-34`

- [ ] **Step 1: Replace color literals**

Change lines 32-34 in `build()`:

```dart
    final statusColor = isPassing
        ? AppColors.primary   // was: const Color(0xFF58CC02)
        : AppColors.danger;   // was: const Color(0xFFFF4B4B)
```

- [ ] **Step 2: Run analyzer**

Run: `dart analyze lib/presentation/widgets/book_quiz/book_quiz_result_card.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/book_quiz/book_quiz_result_card.dart
git commit -m "refactor: use AppColors instead of hard-coded color literals (#10)"
```

---

### Task 6: Admin Quiz Editor — English Labels + 0-Question Validation (#3 admin, #11)

**Files:**
- Modify: `owlio_admin/lib/features/quizzes/screens/book_quiz_edit_screen.dart`

- [ ] **Step 1: Translate all Turkish strings to English in `_BookQuizEditScreenState`**

Replace these strings throughout the file:

| Turkish | English |
|---------|---------|
| `'Quiz yükleme hatası: $e'` | `'Error loading quiz: $e'` |
| `'Quiz başarıyla oluşturuldu'` | `'Quiz created successfully'` |
| `'Quiz başarıyla kaydedildi'` | `'Quiz saved successfully'` |
| `'Hata: $e'` | `'Error: $e'` |
| `'Soruyu Sil'` | `'Delete Question'` |
| `'Bu soruyu silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'` | `'Are you sure you want to delete this question? This action cannot be undone.'` |
| `'İptal'` | `'Cancel'` |
| `'Sil'` | `'Delete'` |
| `'Soru silindi'` | `'Question deleted'` |
| `'Sıralama hatası: $e'` | `'Reorder error: $e'` |
| `'Çoktan Seçmeli'` | `'Multiple Choice'` |
| `'Boşluk Doldurma'` | `'Fill in the Blank'` |
| `'Olay Sıralaması'` | `'Event Sequencing'` |
| `'Eşleştirme'` | `'Matching'` |
| `'Kim Ne Dedi'` | `'Who Says What'` |
| `'Yeni Kitap Quizi'` | `'New Book Quiz'` |
| `'Kitap Quizini Düzenle'` | `'Edit Book Quiz'` |
| `'Oluştur'` (in appBar actions) | `'Create'` |
| `'Kaydet'` (in appBar actions) | `'Save'` |
| `'Quiz Bilgileri'` | `'Quiz Details'` |
| `'Başlık'` | `'Title'` |
| `'Quiz başlığını girin'` | `'Enter quiz title'` |
| `'Başlık zorunludur'` | `'Title is required'` |
| `'Talimatlar'` | `'Instructions'` |
| `'Öğrenciler için quiz talimatlarını girin'` | `'Enter quiz instructions for students'` |
| `'Geçme Puanı (%)'` | `'Passing Score (%)'` |
| `'Geçme puanı zorunludur'` | `'Passing score is required'` |
| `'0 ile 100 arasında bir sayı girin'` | `'Enter a number between 0 and 100'` |
| `'Sorular'` | `'Questions'` |
| `'Toplam Puan'` | `'Total Points'` |

In `_QuestionsList`:

| Turkish | English |
|---------|---------|
| `'Sorular (${questions.length})'` | `'Questions (${questions.length})'` |
| `'Ekle'` | `'Add'` |
| `'Quiz kaydedildi. Şimdi soru ekleyebilirsiniz.'` | `'Quiz saved. You can now add questions.'` |
| `'Henüz soru yok'` | `'No questions yet'` |
| `'Quizinizi oluşturmak için soru ekleyin'` | `'Add questions to build your quiz'` |
| `'Başlıksız Soru'` | `'Untitled Question'` |

- [ ] **Step 2: Add 0-question publish validation**

In `_handleSave()`, add a guard before the save logic (after line 88 `if (!_formKey.currentState!.validate()) return;`):

```dart
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    // Prevent publishing quiz with no questions
    if (!isNewQuiz && _questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot publish a quiz with no questions.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    // ... rest unchanged
```

- [ ] **Step 3: Run analyzer**

Run: `cd owlio_admin && dart analyze lib/features/quizzes/screens/book_quiz_edit_screen.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add owlio_admin/lib/features/quizzes/screens/book_quiz_edit_screen.dart
git commit -m "fix: English labels and 0-question validation in admin quiz editor (#3, #11)"
```

---

### Task 7: Admin Question Editor — English Labels + Enum Switches (#9, #11)

**Files:**
- Modify: `owlio_admin/lib/features/quizzes/screens/quiz_question_edit_screen.dart`

- [ ] **Step 1: Replace raw string switch cases with enum `dbValue` in `_populateContentFields`**

Change the switch at line 153:

```dart
  void _populateContentFields(Map<String, dynamic> content) {
    switch (_selectedType) {
      case 'multiple_choice':
```

To:

```dart
  void _populateContentFields(Map<String, dynamic> content) {
    final type = BookQuizQuestionType.fromDbValue(_selectedType);
    switch (type) {
      case BookQuizQuestionType.multipleChoice:
        final options = (content['options'] as List?)?.cast<String>() ?? [];
        for (int i = 0; i < _mcOptionControllers.length && i < options.length; i++) {
          _mcOptionControllers[i].text = options[i];
        }
        _mcCorrectAnswer = content['correct_answer'] as String? ?? 'A';
        break;

      case BookQuizQuestionType.fillBlank:
        _fillSentenceController.text = content['sentence'] as String? ?? '';
        _fillCorrectController.text = content['correct_answer'] as String? ?? '';
        final alternatives =
            (content['accept_alternatives'] as List?)?.cast<String>() ?? [];
        _fillAlternativesController.text = alternatives.join(', ');
        break;

      case BookQuizQuestionType.eventSequencing:
        final events = (content['events'] as List?)?.cast<String>() ?? [];
        final order = (content['correct_order'] as List?)
                ?.map((e) => e as int)
                .toList() ??
            [];
        for (final c in _eventControllers) {
          c.dispose();
        }
        _eventControllers.clear();
        for (final event in events) {
          _eventControllers.add(TextEditingController(text: event));
        }
        if (_eventControllers.isEmpty) {
          _eventControllers.addAll([
            TextEditingController(),
            TextEditingController(),
            TextEditingController(),
          ]);
        }
        _correctOrder =
            order.isNotEmpty ? order : List.generate(events.length, (i) => i);
        break;

      case BookQuizQuestionType.matching:
        final left = (content['left'] as List?)?.cast<String>() ?? [];
        final right = (content['right'] as List?)?.cast<String>() ?? [];
        for (final c in _matchLeftControllers) {
          c.dispose();
        }
        for (final c in _matchRightControllers) {
          c.dispose();
        }
        _matchLeftControllers.clear();
        _matchRightControllers.clear();
        for (int i = 0; i < left.length; i++) {
          _matchLeftControllers.add(TextEditingController(text: left[i]));
          _matchRightControllers.add(TextEditingController(
              text: i < right.length ? right[i] : ''));
        }
        if (_matchLeftControllers.isEmpty) {
          _matchLeftControllers.addAll([
            TextEditingController(),
            TextEditingController(),
          ]);
          _matchRightControllers.addAll([
            TextEditingController(),
            TextEditingController(),
          ]);
        }
        break;

      case BookQuizQuestionType.whoSaysWhat:
        final characters =
            (content['characters'] as List?)?.cast<String>() ?? [];
        final quotes = (content['quotes'] as List?)?.cast<String>() ?? [];
        for (final c in _characterControllers) {
          c.dispose();
        }
        for (final c in _quoteControllers) {
          c.dispose();
        }
        _characterControllers.clear();
        _quoteControllers.clear();
        for (int i = 0; i < characters.length; i++) {
          _characterControllers
              .add(TextEditingController(text: characters[i]));
          _quoteControllers.add(
              TextEditingController(text: i < quotes.length ? quotes[i] : ''));
        }
        if (_characterControllers.isEmpty) {
          _characterControllers.addAll([
            TextEditingController(),
            TextEditingController(),
          ]);
          _quoteControllers.addAll([
            TextEditingController(),
            TextEditingController(),
          ]);
        }
        break;
    }
  }
```

- [ ] **Step 2: Replace raw string switch cases with enum `dbValue` in `_buildContentJson`**

```dart
  Map<String, dynamic> _buildContentJson() {
    final type = BookQuizQuestionType.fromDbValue(_selectedType);
    switch (type) {
      case BookQuizQuestionType.multipleChoice:
        return {
          'options':
              _mcOptionControllers.map((c) => c.text.trim()).toList(),
          'correct_answer': _mcCorrectAnswer,
        };

      case BookQuizQuestionType.fillBlank:
        final alternatives = _fillAlternativesController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        return {
          'sentence': _fillSentenceController.text.trim(),
          'correct_answer': _fillCorrectController.text.trim(),
          'accept_alternatives': alternatives,
        };

      case BookQuizQuestionType.eventSequencing:
        return {
          'events': _eventControllers.map((c) => c.text.trim()).toList(),
          'correct_order': _correctOrder,
        };

      case BookQuizQuestionType.matching:
        final pairs = <String, String>{};
        for (int i = 0; i < _matchLeftControllers.length; i++) {
          pairs[i.toString()] = i.toString();
        }
        return {
          'left': _matchLeftControllers.map((c) => c.text.trim()).toList(),
          'right': _matchRightControllers.map((c) => c.text.trim()).toList(),
          'correct_pairs': pairs,
        };

      case BookQuizQuestionType.whoSaysWhat:
        final pairs = <String, String>{};
        for (int i = 0; i < _characterControllers.length; i++) {
          pairs[i.toString()] = i.toString();
        }
        return {
          'characters':
              _characterControllers.map((c) => c.text.trim()).toList(),
          'quotes': _quoteControllers.map((c) => c.text.trim()).toList(),
          'correct_pairs': pairs,
        };
    }
  }
```

- [ ] **Step 3: Replace raw string switch in `_buildContentForm`**

```dart
  Widget _buildContentForm() {
    final type = BookQuizQuestionType.fromDbValue(_selectedType);
    switch (type) {
      case BookQuizQuestionType.multipleChoice:
        return _buildMultipleChoiceForm();
      case BookQuizQuestionType.fillBlank:
        return _buildFillBlankForm();
      case BookQuizQuestionType.eventSequencing:
        return _buildEventSequencingForm();
      case BookQuizQuestionType.matching:
        return _buildMatchingForm();
      case BookQuizQuestionType.whoSaysWhat:
        return _buildWhoSaysWhatForm();
    }
  }
```

- [ ] **Step 4: Replace `_getTypeLabel` with English labels and enum switch**

```dart
  String _getTypeLabel(String type) {
    final questionType = BookQuizQuestionType.fromDbValue(type);
    switch (questionType) {
      case BookQuizQuestionType.multipleChoice:
        return 'Multiple Choice';
      case BookQuizQuestionType.fillBlank:
        return 'Fill in the Blank';
      case BookQuizQuestionType.eventSequencing:
        return 'Event Sequencing';
      case BookQuizQuestionType.matching:
        return 'Matching';
      case BookQuizQuestionType.whoSaysWhat:
        return 'Who Says What';
    }
  }
```

- [ ] **Step 5: Translate all remaining Turkish strings to English**

| Turkish | English |
|---------|---------|
| `'Soru yükleme hatası: $e'` | `'Error loading question: $e'` |
| `'Soru başarıyla oluşturuldu'` | `'Question created successfully'` |
| `'Soru başarıyla kaydedildi'` | `'Question saved successfully'` |
| `'Hata: $e'` | `'Error: $e'` |
| `'Yeni Soru'` | `'New Question'` |
| `'Soruyu Düzenle'` | `'Edit Question'` |
| `'Oluştur'` | `'Create'` |
| `'Kaydet'` | `'Save'` |
| `'Soru Türü'` | `'Question Type'` |
| `'Puan'` | `'Points'` |
| `'Zorunlu'` | `'Required'` |
| `'En az 1'` | `'Minimum 1'` |
| `'Soru'` | `'Question'` |
| `'Soru metnini girin'` | `'Enter question text'` |
| `'Soru metni zorunludur'` | `'Question text is required'` |
| `'İçerik'` | `'Content'` |
| `'Açıklama (isteğe bağlı)'` | `'Explanation (optional)'` |
| `'Öğrencilerin öğrenmesine yardımcı olmak için doğru cevabı açıklayın'` | `'Explain the correct answer to help students learn'` |
| `'Bilinmeyen soru türü'` | `'Unknown question type'` |
| `'Seçenek ${labels[index]}'` | `'Option ${labels[index]}'` |
| `'Seçenek ${labels[index]} zorunludur'` | `'Option ${labels[index]} is required'` |
| `'Doğru cevabın yanındaki radyo düğmesini seçin'` | `'Select the radio button next to the correct answer'` |
| `'Cümle'` | `'Sentence'` |
| `'Boşluk için ___ kullanın (örn. "The ___ ran fast.")'` | `'Use ___ for the blank (e.g. "The ___ ran fast.")'` |
| `'Cümle zorunludur'` | `'Sentence is required'` |
| `'Doğru Cevap'` | `'Correct Answer'` |
| `'Boşluğu dolduran kelime'` | `'The word that fills the blank'` |
| `'Doğru cevap zorunludur'` | `'Correct answer is required'` |
| `'Kabul Edilen Alternatifler (isteğe bağlı)'` | `'Accepted Alternatives (optional)'` |
| `'Virgülle ayrılmış (örn. "Fox, FOX")'` | `'Comma-separated (e.g. "Fox, FOX")'` |
| `'Kabul edilmesi gereken alternatif cevaplar'` | `'Alternative answers that should be accepted'` |
| `'Olayları DOĞRU sırayla girin. Öğrenciler karışık sırada görecek.'` | `'Enter events in CORRECT order. Students will see them shuffled.'` |
| `'Olay ${index + 1}'` | `'Event ${index + 1}'` |
| `'Olayı açıklayın'` | `'Describe the event'` |
| `'Olay zorunludur'` | `'Event is required'` |
| `'Olay Ekle'` | `'Add Event'` |
| `'Eşleştirme çiftlerini girin. Sol öğeler sağ öğelerle eşleştirilecek.'` | `'Enter matching pairs. Left items will be matched with right items.'` |
| `'Sol'` | `'Left'` |
| `'Sağ (doğru eşleşme)'` | `'Right (correct match)'` |
| `'Sol öğe ${index + 1}'` | `'Left item ${index + 1}'` |
| `'Sağ öğe ${index + 1}'` | `'Right item ${index + 1}'` |
| `'Çift Ekle'` (matching section) | `'Add Pair'` |
| `'Karakter-alıntı çiftlerini girin. Öğrenciler karakterleri alıntılarıyla eşleştirecek.'` | `'Enter character-quote pairs. Students will match characters with their quotes.'` |
| `'Karakter'` | `'Character'` |
| `'Alıntı (doğru eşleşme)'` | `'Quote (correct match)'` |
| `'Karakter ${index + 1}'` | `'Character ${index + 1}'` |
| `'Alıntı ${index + 1}'` | `'Quote ${index + 1}'` |
| `'Çift Ekle'` (who says what section) | `'Add Pair'` |

- [ ] **Step 6: Run analyzer**

Run: `cd owlio_admin && dart analyze lib/features/quizzes/screens/quiz_question_edit_screen.dart`
Expected: No issues found.

- [ ] **Step 7: Commit**

```bash
git add owlio_admin/lib/features/quizzes/screens/quiz_question_edit_screen.dart
git commit -m "fix: English labels and enum switches in admin question editor (#9, #11)"
```

---

### Task 8: Update Audit Spec Status

**Files:**
- Modify: `docs/specs/04-book-quiz.md`

- [ ] **Step 1: Update all finding statuses in the audit table**

Update the Status column for each fixed finding:
- #1: `TODO` → `Fixed`
- #2: `TODO` → `Fixed`
- #3: `TODO` → `Fixed`
- #4: `TODO` → `Fixed`
- #5: `TODO` → `Fixed`
- #6: `TODO` → `Fixed`
- #7: `TODO` → `Fixed`
- #8: `TODO` → `Fixed`
- #9: `TODO` → `Fixed`
- #10: `TODO` → `Fixed`
- #11: `TODO` → `Fixed`
- #13: `TODO` → `Fixed`

- [ ] **Step 2: Update checklist result summaries**

Update each category to reflect fixes:
- **Code Quality**: `PASS — All issues fixed (#8, #9, #10, #11)`
- **Dead Code**: `PASS — All removed (#4, #5, #6, #7)`
- **Database & Security**: `PASS — quiz_passed written (#1), auth check added (#2), composite index (#13)`
- **Edge Cases & UX**: `PASS — 0-question guard added (#3)`

- [ ] **Step 3: Commit**

```bash
git add docs/specs/04-book-quiz.md
git commit -m "docs: mark book quiz audit findings as resolved"
```
