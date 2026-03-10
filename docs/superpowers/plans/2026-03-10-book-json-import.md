# Book JSON Import Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 3-step stepper UI to the admin panel for importing books via JSON (file upload or paste → validate → import to Supabase).

**Architecture:** New `book_json_validator.dart` service (pure Dart, no UI) handles parsing and validation. New `book_json_import_screen.dart` uses a ConsumerStatefulWidget with a Stepper widget for the 3-step flow. Router and book list screen are modified to integrate the feature.

**Tech Stack:** Flutter, Riverpod, GoRouter, Supabase, file_picker, uuid (all already in pubspec)

**Spec:** `docs/superpowers/specs/2026-03-10-book-json-import-design.md`

---

## File Structure

```
owlio_admin/lib/
├── core/
│   └── router.dart                                    ← MODIFY: add /books/import route
├── features/
│   └── books/
│       ├── screens/
│       │   ├── book_list_screen.dart                  ← MODIFY: add "Import JSON" button
│       │   └── book_json_import_screen.dart            ← CREATE: stepper UI
│       └── services/
│           └── book_json_validator.dart                ← CREATE: validation + parsing
```

---

## Chunk 1: Validator Service

### Task 1: Create book_json_validator.dart — data classes

**Files:**
- Create: `owlio_admin/lib/features/books/services/book_json_validator.dart`

- [ ] **Step 1: Create the validator file with result types and parsed data classes**

```dart
import 'dart:convert';
import 'package:owlio_shared/owlio_shared.dart';

/// Result of JSON validation — either success with parsed data, or failure with errors.
class BookJsonValidationResult {
  final BookJsonData? data;
  final List<String> errors;

  bool get isValid => errors.isEmpty && data != null;

  const BookJsonValidationResult.success(BookJsonData this.data) : errors = const [];
  const BookJsonValidationResult.failure(this.errors) : data = null;
}

/// Parsed and validated book data ready for DB import.
class BookJsonData {
  final Map<String, dynamic> book;
  final List<ParsedChapter> chapters;
  final Map<String, dynamic>? bookQuiz;

  const BookJsonData({
    required this.book,
    required this.chapters,
    this.bookQuiz,
  });

  int get totalContentBlocks =>
      chapters.fold(0, (sum, ch) => sum + ch.contentBlocks.length);
  int get totalInlineActivities =>
      chapters.fold(0, (sum, ch) => sum + ch.inlineActivities.length);
  int get totalQuizQuestions =>
      (bookQuiz?['questions'] as List?)?.length ?? 0;
}

class ParsedChapter {
  final Map<String, dynamic> chapter;
  final List<Map<String, dynamic>> contentBlocks;
  final List<ParsedInlineActivity> inlineActivities;

  const ParsedChapter({
    required this.chapter,
    required this.contentBlocks,
    required this.inlineActivities,
  });
}

/// Links an inline activity to its content block index within the chapter.
class ParsedInlineActivity {
  final Map<String, dynamic> activity;
  final int contentBlockIndex;

  const ParsedInlineActivity({
    required this.activity,
    required this.contentBlockIndex,
  });
}
```

- [ ] **Step 2: Verify file compiles**

Run: `cd owlio_admin && dart analyze lib/features/books/services/book_json_validator.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add owlio_admin/lib/features/books/services/book_json_validator.dart
git commit -m "feat(admin): add book JSON validator data classes"
```

---

### Task 2: Validator — book validation

**Files:**
- Modify: `owlio_admin/lib/features/books/services/book_json_validator.dart`

- [ ] **Step 1: Add the BookJsonValidator class with book validation**

Append to the file:

```dart
class BookJsonValidator {
  static const _validLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
  static const _validStatuses = ['draft', 'published', 'archived'];
  static final _slugRegex = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

  /// Parse raw JSON string and validate structure.
  BookJsonValidationResult validate(String jsonString) {
    final Map<String, dynamic> root;
    try {
      root = json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return BookJsonValidationResult.failure(['Invalid JSON: $e']);
    }

    final errors = <String>[];

    // Validate book
    if (root['book'] is! Map<String, dynamic>) {
      errors.add('book: required object missing');
      return BookJsonValidationResult.failure(errors);
    }
    final book = root['book'] as Map<String, dynamic>;
    _validateBook(book, errors);

    // Validate chapters
    if (root['chapters'] is! List || (root['chapters'] as List).isEmpty) {
      errors.add('chapters: required non-empty array');
      return BookJsonValidationResult.failure(errors);
    }
    final chaptersJson = List<dynamic>.from(root['chapters'] as List);
    final parsedChapters = <ParsedChapter>[];
    final orderIndices = <int>{};

    for (var i = 0; i < chaptersJson.length; i++) {
      if (chaptersJson[i] is! Map<String, dynamic>) {
        errors.add('chapters[$i]: must be an object');
        continue;
      }
      final ch = chaptersJson[i] as Map<String, dynamic>;
      _validateChapter(ch, i, orderIndices, errors, parsedChapters);
    }

    // Validate book_quiz (optional)
    Map<String, dynamic>? parsedQuiz;
    if (root['book_quiz'] != null) {
      if (root['book_quiz'] is! Map<String, dynamic>) {
        errors.add('book_quiz: must be an object');
      } else {
        parsedQuiz = root['book_quiz'] as Map<String, dynamic>;
        _validateBookQuiz(parsedQuiz, errors);
      }
    }

    if (errors.isNotEmpty) {
      return BookJsonValidationResult.failure(errors);
    }

    return BookJsonValidationResult.success(BookJsonData(
      book: book,
      chapters: parsedChapters,
      bookQuiz: parsedQuiz,
    ));
  }

  void _validateBook(Map<String, dynamic> book, List<String> errors) {
    if (_isEmpty(book['title'])) {
      errors.add('book.title: required');
    }
    if (_isEmpty(book['slug'])) {
      errors.add('book.slug: required');
    } else if (!_slugRegex.hasMatch(book['slug'] as String)) {
      errors.add('book.slug: must be lowercase alphanumeric with hyphens (e.g. "the-lost-garden")');
    }
    if (_isEmpty(book['level'])) {
      errors.add('book.level: required');
    } else if (!_validLevels.contains(book['level'])) {
      errors.add('book.level: "${book['level']}" invalid. Expected: ${_validLevels.join(', ')}');
    }
    if (book['status'] != null && !_validStatuses.contains(book['status'])) {
      errors.add('book.status: "${book['status']}" invalid. Expected: ${_validStatuses.join(', ')}');
    }
  }

  bool _isEmpty(dynamic value) => value == null || (value is String && value.trim().isEmpty);
}
```

- [ ] **Step 2: Verify file compiles**

Run: `cd owlio_admin && dart analyze lib/features/books/services/book_json_validator.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add owlio_admin/lib/features/books/services/book_json_validator.dart
git commit -m "feat(admin): add book-level JSON validation"
```

---

### Task 3: Validator — chapter + content block + inline activity validation

**Files:**
- Modify: `owlio_admin/lib/features/books/services/book_json_validator.dart`

- [ ] **Step 1: Add chapter, content block, and inline activity validation methods**

Add these methods inside `BookJsonValidator` class:

```dart
  static const _validBlockTypes = ['text', 'image', 'activity'];
  static const _validInlineTypes = ['true_false', 'word_translation', 'find_words', 'matching'];

  void _validateChapter(
    Map<String, dynamic> ch,
    int index,
    Set<int> orderIndices,
    List<String> errors,
    List<ParsedChapter> parsedChapters,
  ) {
    final prefix = 'chapters[$index]';

    if (_isEmpty(ch['title'])) {
      errors.add('$prefix.title: required');
    }
    if (ch['order_index'] is! int) {
      errors.add('$prefix.order_index: required integer');
    } else {
      final oi = ch['order_index'] as int;
      if (!orderIndices.add(oi)) {
        errors.add('$prefix.order_index: duplicate value $oi');
      }
    }

    // Content blocks
    if (ch['content_blocks'] is! List || (ch['content_blocks'] as List).isEmpty) {
      errors.add('$prefix.content_blocks: required non-empty array');
      return;
    }
    final blocks = List<dynamic>.from(ch['content_blocks'] as List);
    final parsedBlocks = <Map<String, dynamic>>[];
    final parsedActivities = <ParsedInlineActivity>[];

    for (var j = 0; j < blocks.length; j++) {
      if (blocks[j] is! Map<String, dynamic>) {
        errors.add('$prefix.content_blocks[$j]: must be an object');
        continue;
      }
      final block = blocks[j] as Map<String, dynamic>;
      _validateContentBlock(block, prefix, j, errors, parsedBlocks, parsedActivities);
    }

    parsedChapters.add(ParsedChapter(
      chapter: ch,
      contentBlocks: parsedBlocks,
      inlineActivities: parsedActivities,
    ));
  }

  void _validateContentBlock(
    Map<String, dynamic> block,
    String chapterPrefix,
    int index,
    List<String> errors,
    List<Map<String, dynamic>> parsedBlocks,
    List<ParsedInlineActivity> parsedActivities,
  ) {
    final prefix = '$chapterPrefix.content_blocks[$index]';

    if (block['order_index'] is! int) {
      errors.add('$prefix.order_index: required integer');
    }

    final type = block['type'];
    if (_isEmpty(type) || !_validBlockTypes.contains(type)) {
      errors.add('$prefix.type: must be one of ${_validBlockTypes.join(', ')}');
      return;
    }

    switch (type) {
      case 'text':
        if (_isEmpty(block['text'])) {
          errors.add('$prefix.text: required for type=text');
        }
        break;
      case 'image':
        if (_isEmpty(block['image_url'])) {
          errors.add('$prefix.image_url: required for type=image');
        }
        break;
      case 'activity':
        if (block['inline_activity'] is! Map<String, dynamic>) {
          errors.add('$prefix.inline_activity: required for type=activity');
        } else {
          final activity = block['inline_activity'] as Map<String, dynamic>;
          _validateInlineActivity(activity, prefix, errors);
          parsedActivities.add(ParsedInlineActivity(
            activity: activity,
            contentBlockIndex: index,
          ));
        }
        break;
    }

    parsedBlocks.add(block);
  }

  void _validateInlineActivity(
    Map<String, dynamic> activity,
    String blockPrefix,
    List<String> errors,
  ) {
    final prefix = '$blockPrefix.inline_activity';
    final type = activity['type'];

    if (_isEmpty(type) || !_validInlineTypes.contains(type)) {
      errors.add('$prefix.type: must be one of ${_validInlineTypes.join(', ')}');
      return;
    }

    if (activity['content'] is! Map<String, dynamic>) {
      errors.add('$prefix.content: required object');
      return;
    }
    final content = activity['content'] as Map<String, dynamic>;

    switch (type) {
      case 'true_false':
        if (_isEmpty(content['statement'])) {
          errors.add('$prefix.content.statement: required');
        }
        if (content['correct_answer'] is! bool) {
          errors.add('$prefix.content.correct_answer: required boolean');
        }
        break;
      case 'word_translation':
        if (_isEmpty(content['word'])) {
          errors.add('$prefix.content.word: required');
        }
        if (_isEmpty(content['correct_answer'])) {
          errors.add('$prefix.content.correct_answer: required');
        }
        if (content['options'] is! List || (content['options'] as List).length < 2) {
          errors.add('$prefix.content.options: required array with min 2 items');
        }
        break;
      case 'find_words':
        if (_isEmpty(content['instruction'])) {
          errors.add('$prefix.content.instruction: required');
        }
        if (content['options'] is! List || (content['options'] as List).isEmpty) {
          errors.add('$prefix.content.options: required non-empty array');
        }
        if (content['correct_answers'] is! List || (content['correct_answers'] as List).isEmpty) {
          errors.add('$prefix.content.correct_answers: required non-empty array');
        } else if (content['options'] is List) {
          final options = (content['options'] as List).map((e) => e.toString()).toList();
          final answers = (content['correct_answers'] as List).map((e) => e.toString()).toList();
          for (final a in answers) {
            if (!options.contains(a)) {
              errors.add('$prefix.content.correct_answers: "$a" not found in options');
            }
          }
        }
        break;
      case 'matching':
        if (_isEmpty(content['instruction'])) {
          errors.add('$prefix.content.instruction: required');
        }
        if (content['pairs'] is! List || (content['pairs'] as List).length < 2) {
          errors.add('$prefix.content.pairs: required array with min 2 items');
        } else {
          final pairs = content['pairs'] as List;
          for (var k = 0; k < pairs.length; k++) {
            if (pairs[k] is! Map || _isEmpty(pairs[k]['left']) || _isEmpty(pairs[k]['right'])) {
              errors.add('$prefix.content.pairs[$k]: must have "left" and "right" strings');
            }
          }
        }
        break;
    }
  }
```

- [ ] **Step 2: Verify file compiles**

Run: `cd owlio_admin && dart analyze lib/features/books/services/book_json_validator.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add owlio_admin/lib/features/books/services/book_json_validator.dart
git commit -m "feat(admin): add chapter/content-block/inline-activity validation"
```

---

### Task 4: Validator — book quiz validation

**Files:**
- Modify: `owlio_admin/lib/features/books/services/book_json_validator.dart`

- [ ] **Step 1: Add book quiz validation methods**

Add these methods inside `BookJsonValidator` class:

```dart
  static const _validQuizTypes = [
    'multiple_choice',
    'fill_blank',
    'event_sequencing',
    'matching',
    'who_says_what',
  ];

  void _validateBookQuiz(Map<String, dynamic> quiz, List<String> errors) {
    const prefix = 'book_quiz';

    if (_isEmpty(quiz['title'])) {
      errors.add('$prefix.title: required');
    }

    if (quiz['questions'] is! List || (quiz['questions'] as List).isEmpty) {
      errors.add('$prefix.questions: required non-empty array');
      return;
    }

    final questions = quiz['questions'] as List;
    for (var i = 0; i < questions.length; i++) {
      if (questions[i] is! Map<String, dynamic>) {
        errors.add('$prefix.questions[$i]: must be an object');
        continue;
      }
      _validateQuizQuestion(questions[i] as Map<String, dynamic>, i, errors);
    }
  }

  void _validateQuizQuestion(Map<String, dynamic> q, int index, List<String> errors) {
    final prefix = 'book_quiz.questions[$index]';
    final type = q['type'];

    if (_isEmpty(type) || !_validQuizTypes.contains(type)) {
      errors.add('$prefix.type: must be one of ${_validQuizTypes.join(', ')}');
      return;
    }
    if (_isEmpty(q['question'])) {
      errors.add('$prefix.question: required');
    }
    if (q['content'] is! Map<String, dynamic>) {
      errors.add('$prefix.content: required object');
      return;
    }
    final content = q['content'] as Map<String, dynamic>;

    switch (type) {
      case 'multiple_choice':
        if (content['options'] is! List || (content['options'] as List).length < 2) {
          errors.add('$prefix.content.options: required array with min 2 items');
        }
        if (_isEmpty(content['correct_answer'])) {
          errors.add('$prefix.content.correct_answer: required');
        } else if (content['options'] is List &&
            !(content['options'] as List).contains(content['correct_answer'])) {
          errors.add('$prefix.content.correct_answer: must match one of the options');
        }
        break;
      case 'fill_blank':
        final sentence = content['sentence'];
        if (_isEmpty(sentence)) {
          errors.add('$prefix.content.sentence: required');
        } else if (!(sentence as String).contains('___')) {
          errors.add('$prefix.content.sentence: must contain "___" placeholder');
        }
        if (_isEmpty(content['correct_answer'])) {
          errors.add('$prefix.content.correct_answer: required');
        }
        break;
      case 'event_sequencing':
        if (content['events'] is! List || (content['events'] as List).length < 2) {
          errors.add('$prefix.content.events: required array with min 2 items');
        }
        if (content['correct_order'] is! List) {
          errors.add('$prefix.content.correct_order: required array of indices');
        } else if (content['events'] is List) {
          final events = content['events'] as List;
          final order = content['correct_order'] as List;
          if (order.length != events.length) {
            errors.add('$prefix.content.correct_order: must have same length as events');
          } else {
            for (var k = 0; k < order.length; k++) {
              final idx = order[k] is int ? order[k] as int : int.tryParse(order[k].toString());
              if (idx == null || idx < 0 || idx >= events.length) {
                errors.add('$prefix.content.correct_order[$k]: invalid index "${order[k]}"');
              }
            }
          }
        }
        break;
      case 'matching':
        _validatePairedQuiz(content, prefix, 'left', 'right', errors);
        break;
      case 'who_says_what':
        _validatePairedQuiz(content, prefix, 'characters', 'quotes', errors);
        break;
    }
  }

  void _validatePairedQuiz(
    Map<String, dynamic> content,
    String prefix,
    String leftKey,
    String rightKey,
    List<String> errors,
  ) {
    final left = content[leftKey];
    final right = content[rightKey];

    if (left is! List || left.length < 2) {
      errors.add('$prefix.content.$leftKey: required array with min 2 items');
    }
    if (right is! List || right.length < 2) {
      errors.add('$prefix.content.$rightKey: required array with min 2 items');
    }
    if (left is List && right is List && left.length != right.length) {
      errors.add('$prefix.content: $leftKey and $rightKey must have same length');
    }
    if (content['correct_pairs'] is! Map) {
      errors.add('$prefix.content.correct_pairs: required object mapping indices');
    } else if (left is List && right is List) {
      final pairs = content['correct_pairs'] as Map;
      for (final entry in pairs.entries) {
        final li = int.tryParse(entry.key.toString());
        final ri = int.tryParse(entry.value.toString());
        if (li == null || ri == null || li < 0 || li >= left.length || ri < 0 || ri >= right.length) {
          errors.add('$prefix.content.correct_pairs: invalid mapping "${ entry.key}" -> "${entry.value}" (out of bounds)');
        }
      }
    }
  }
```

- [ ] **Step 2: Verify file compiles**

Run: `cd owlio_admin && dart analyze lib/features/books/services/book_json_validator.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add owlio_admin/lib/features/books/services/book_json_validator.dart
git commit -m "feat(admin): add book quiz validation"
```

---

## Chunk 2: Import Screen

### Task 5: Create book_json_import_screen.dart — scaffold + Step 1 (JSON input)

**Files:**
- Create: `owlio_admin/lib/features/books/screens/book_json_import_screen.dart`

- [ ] **Step 1: Create the screen file with Stepper and Step 1 (JSON input)**

```dart
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import '../services/book_json_validator.dart';
import 'book_list_screen.dart';

class BookJsonImportScreen extends ConsumerStatefulWidget {
  const BookJsonImportScreen({super.key});

  @override
  ConsumerState<BookJsonImportScreen> createState() =>
      _BookJsonImportScreenState();
}

class _BookJsonImportScreenState extends ConsumerState<BookJsonImportScreen> {
  int _currentStep = 0;
  final _jsonController = TextEditingController();
  String? _fileName;

  // Step 2 state
  BookJsonValidationResult? _validationResult;

  // Step 3 state
  bool _isImporting = false;
  final _importLog = <_ImportLogEntry>[];
  String? _importedBookId;

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    try {
      final content = utf8.decode(file.bytes!);
      setState(() {
        _jsonController.text = content;
        _fileName = file.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya okunamadı: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleValidate() async {
    final jsonText = _jsonController.text.trim();
    if (jsonText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('JSON girişi boş'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final validator = BookJsonValidator();
    final result = validator.validate(jsonText);

    // Check slug uniqueness in DB
    if (result.isValid) {
      final slug = result.data!.book['slug'] as String;
      final supabase = ref.read(supabaseClientProvider);
      final existing = await supabase
          .from(DbTables.books)
          .select('id')
          .eq('slug', slug)
          .maybeSingle();

      if (!mounted) return;

      if (existing != null) {
        setState(() {
          _validationResult = BookJsonValidationResult.failure(
            ['book.slug: "$slug" zaten mevcut. Farklı bir slug kullanın.'],
          );
          _currentStep = 1;
        });
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _validationResult = result;
      _currentStep = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JSON ile Kitap İçe Aktar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/books'),
        ),
      ),
      body: Stepper(
        currentStep: _currentStep,
        controlsBuilder: (context, details) => const SizedBox.shrink(),
        steps: [
          _buildStep1(),
          _buildStep2(),
          _buildStep3(),
        ],
      ),
    );
  }

  Step _buildStep1() {
    return Step(
      title: const Text('JSON Giriş'),
      subtitle: _fileName != null ? Text(_fileName!) : null,
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // File upload + paste toggle
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickFile,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.indigo, width: 2, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.indigo.shade50,
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.upload_file, size: 36, color: Colors.indigo.shade700),
                          const SizedBox(height: 8),
                          Text('Dosya Yükle', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.indigo.shade700)),
                          const SizedBox(height: 4),
                          Text('.json dosyası seç', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('veya', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400, width: 2, style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.content_paste, size: 36, color: Colors.grey.shade600),
                        const SizedBox(height: 8),
                        Text('JSON Yapıştır', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                        const SizedBox(height: 4),
                        Text('Aşağıya yapıştırın', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // JSON textarea
            TextField(
              controller: _jsonController,
              maxLines: 15,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                hintText: '{"book": {...}, "chapters": [...]}',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.grey.shade900,
                hintStyle: TextStyle(color: Colors.grey.shade500),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _handleValidate,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Validate'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Placeholder steps — will be implemented in next tasks
  Step _buildStep2() {
    return Step(
      title: const Text('Validation & Preview'),
      isActive: _currentStep >= 1,
      state: _currentStep > 1
          ? StepState.complete
          : _currentStep == 1
              ? StepState.indexed
              : StepState.disabled,
      content: const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Step 2 placeholder'),
      ),
    );
  }

  Step _buildStep3() {
    return Step(
      title: const Text('Import'),
      isActive: _currentStep >= 2,
      state: _currentStep == 2 ? StepState.indexed : StepState.disabled,
      content: const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Step 3 placeholder'),
      ),
    );
  }
}

class _ImportLogEntry {
  final String message;
  final bool isComplete;
  final bool isError;

  const _ImportLogEntry(this.message, {this.isComplete = false, this.isError = false});
}
```

- [ ] **Step 2: Verify file compiles**

Run: `cd owlio_admin && dart analyze lib/features/books/screens/book_json_import_screen.dart`
Expected: No issues found (or just unused field warnings for step 2/3 state)

- [ ] **Step 3: Commit**

```bash
git add owlio_admin/lib/features/books/screens/book_json_import_screen.dart
git commit -m "feat(admin): add book JSON import screen with step 1 (JSON input)"
```

---

### Task 6: Import screen — Step 2 (Validation & Preview)

**Files:**
- Modify: `owlio_admin/lib/features/books/screens/book_json_import_screen.dart`

- [ ] **Step 1: Replace the _buildStep2 placeholder method**

```dart
  Step _buildStep2() {
    final result = _validationResult;
    return Step(
      title: const Text('Validation & Preview'),
      isActive: _currentStep >= 1,
      state: _currentStep > 1
          ? StepState.complete
          : _currentStep == 1
              ? StepState.indexed
              : StepState.disabled,
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: result == null
            ? const Text('Önce JSON girişi yapın.')
            : result.isValid
                ? _buildValidPreview(result.data!)
                : _buildErrorList(result.errors),
      ),
    );
  }

  Widget _buildValidPreview(BookJsonData data) {
    final book = data.book;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Text(
                'JSON geçerli — import\'a hazır',
                style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _previewRow('Kitap', '${book['title']} (${book['level']})'),
        _previewRow('Slug', book['slug'] as String),
        _previewRow('Bölümler', '${data.chapters.length} chapter'),
        _previewRow('Content Blocks', '${data.totalContentBlocks} blok'),
        _previewRow('Inline Aktiviteler', '${data.totalInlineActivities} adet'),
        _previewRow('Final Quiz', data.bookQuiz != null
            ? '${data.totalQuizQuestions} soru'
            : 'Yok'),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _currentStep = 0),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Geri'),
            ),
            FilledButton.icon(
              onPressed: _handleImport,
              icon: const Icon(Icons.cloud_upload, size: 18),
              label: const Text('Import Et'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildErrorList(List<String> errors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.error, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Text(
                '${errors.length} hata bulundu',
                style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...errors.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderLeft: BorderSide(color: Colors.red.shade400, width: 3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(e, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
              ),
            )),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _currentStep = 0),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('JSON\'u Düzelt'),
          ),
        ),
      ],
    );
  }
```

- [ ] **Step 2: Add a placeholder _handleImport method** (will be implemented in next task)

```dart
  Future<void> _handleImport() async {
    setState(() {
      _currentStep = 2;
    });
    // Implementation in next task
  }
```

- [ ] **Step 3: Verify file compiles**

Run: `cd owlio_admin && dart analyze lib/features/books/screens/book_json_import_screen.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add owlio_admin/lib/features/books/screens/book_json_import_screen.dart
git commit -m "feat(admin): add validation preview (step 2) to book JSON import"
```

---

### Task 7: Import screen — Step 3 (DB import logic)

**Files:**
- Modify: `owlio_admin/lib/features/books/screens/book_json_import_screen.dart`

- [ ] **Step 1: Replace the _handleImport and _buildStep3 methods with full implementation**

Replace `_handleImport`:

```dart
  Future<void> _handleImport() async {
    final data = _validationResult?.data;
    if (data == null) return;

    setState(() {
      _currentStep = 2;
      _isImporting = true;
      _importLog.clear();
    });

    final supabase = ref.read(supabaseClientProvider);
    const uuid = Uuid();

    try {
      // 1. Create book
      final bookId = uuid.v4();
      _addLog('Kitap oluşturuluyor...');
      await supabase.from(DbTables.books).insert({
        'id': bookId,
        'title': (data.book['title'] as String).trim(),
        'slug': (data.book['slug'] as String).trim(),
        'level': data.book['level'],
        'description': data.book['description'],
        'cover_url': data.book['cover_url'],
        'genre': data.book['genre'],
        'age_group': data.book['age_group'],
        'estimated_minutes': data.book['estimated_minutes'],
        'word_count': data.book['word_count'],
        'lexile_score': data.book['lexile_score'],
        'status': data.book['status'] ?? 'draft',
        'metadata': data.book['metadata'] ?? {},
        'chapter_count': data.chapters.length,
      });
      _updateLog('Kitap oluşturuldu ✓');

      // 2. Create chapters + content blocks + inline activities
      for (var i = 0; i < data.chapters.length; i++) {
        final parsedCh = data.chapters[i];
        final ch = parsedCh.chapter;
        final chapterId = uuid.v4();

        _addLog('Bölüm ${i + 1}/${data.chapters.length}: "${ch['title']}"...');

        await supabase.from(DbTables.chapters).insert({
          'id': chapterId,
          'book_id': bookId,
          'title': (ch['title'] as String).trim(),
          'order_index': ch['order_index'],
          'word_count': ch['word_count'],
          'estimated_minutes': ch['estimated_minutes'],
          'vocabulary': ch['vocabulary'] ?? [],
        });

        // 3. Create inline activities first (need activity_ids for content blocks)
        final activityIdMap = <int, String>{}; // contentBlockIndex -> activityId
        for (final pa in parsedCh.inlineActivities) {
          final activityId = uuid.v4();
          activityIdMap[pa.contentBlockIndex] = activityId;

          await supabase.from(DbTables.inlineActivities).insert({
            'id': activityId,
            'chapter_id': chapterId,
            'type': pa.activity['type'],
            'after_paragraph_index': pa.activity['after_paragraph_index'] ?? 0,
            'content': pa.activity['content'],
            'xp_reward': pa.activity['xp_reward'] ?? 5,
            'vocabulary_words': pa.activity['vocabulary_words'] ?? [],
          });
        }

        // 4. Create content blocks
        for (var j = 0; j < parsedCh.contentBlocks.length; j++) {
          final block = parsedCh.contentBlocks[j];
          await supabase.from(DbTables.contentBlocks).insert({
            'id': uuid.v4(),
            'chapter_id': chapterId,
            'order_index': block['order_index'],
            'type': block['type'],
            'text': block['text'],
            'audio_url': block['audio_url'],
            'word_timings': block['word_timings'] ?? [],
            'audio_start_ms': block['audio_start_ms'],
            'audio_end_ms': block['audio_end_ms'],
            'image_url': block['image_url'],
            'caption': block['caption'],
            'activity_id': activityIdMap[j],
          });
        }

        _updateLog('Bölüm ${i + 1}/${data.chapters.length}: "${ch['title']}" ✓');
      }

      // 5. Create book quiz (if present)
      if (data.bookQuiz != null) {
        final quiz = data.bookQuiz!;
        final quizId = uuid.v4();

        _addLog('Final quiz oluşturuluyor...');
        await supabase.from(DbTables.bookQuizzes).insert({
          'id': quizId,
          'book_id': bookId,
          'title': (quiz['title'] as String).trim(),
          'instructions': quiz['instructions'],
          'passing_score': quiz['passing_score'] ?? 70.0,
          'total_points': quiz['total_points'] ?? 10,
          'is_published': quiz['is_published'] ?? false,
        });

        // 6. Create quiz questions
        final questions = quiz['questions'] as List;
        for (var i = 0; i < questions.length; i++) {
          final q = questions[i] as Map<String, dynamic>;
          await supabase.from(DbTables.bookQuizQuestions).insert({
            'id': uuid.v4(),
            'quiz_id': quizId,
            'type': q['type'],
            'order_index': q['order_index'] ?? i,
            'question': (q['question'] as String).trim(),
            'content': q['content'],
            'explanation': q['explanation'],
            'points': q['points'] ?? 1,
          });
        }

        _updateLog('Final quiz oluşturuldu ✓');
      }

      _addLog('Import tamamlandı!');
      setState(() {
        _isImporting = false;
        _importedBookId = bookId;
      });

      ref.invalidate(booksProvider);
    } catch (e) {
      // Rollback: delete the partially created book (cascades to chapters, content_blocks, etc.)
      try {
        await supabase.from(DbTables.books).delete().eq('id', bookId);
      } catch (_) {
        // Rollback failed — log but don't mask original error
      }
      _addLog('Hata: $e — değişiklikler geri alındı', isError: true);
      if (!mounted) return;
      setState(() => _isImporting = false);
    }
  }

  void _addLog(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _importLog.add(_ImportLogEntry(message, isError: isError));
    });
  }

  void _updateLog(String message) {
    if (!mounted) return;
    setState(() {
      if (_importLog.isNotEmpty) {
        _importLog[_importLog.length - 1] = _ImportLogEntry(message, isComplete: true);
      }
    });
  }
```

Replace `_buildStep3`:

```dart
  Step _buildStep3() {
    return Step(
      title: const Text('Import'),
      isActive: _currentStep >= 2,
      state: _currentStep == 2 ? StepState.indexed : StepState.disabled,
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isImporting)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(),
              ),
            ..._importLog.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      if (entry.isError)
                        Icon(Icons.error, size: 18, color: Colors.red.shade600)
                      else if (entry.isComplete)
                        Icon(Icons.check_circle, size: 18, color: Colors.green.shade600)
                      else
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.message,
                          style: TextStyle(
                            color: entry.isError ? Colors.red.shade700 : null,
                            fontWeight: entry.isError ? FontWeight.w600 : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            if (_importedBookId != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.celebration, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Import başarıyla tamamlandı!',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    FilledButton(
                      onPressed: () => context.go('/books/$_importedBookId'),
                      child: const Text('Kitabı Düzenle'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 2: Verify file compiles**

Run: `cd owlio_admin && dart analyze lib/features/books/screens/book_json_import_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add owlio_admin/lib/features/books/screens/book_json_import_screen.dart
git commit -m "feat(admin): add DB import logic (step 3) to book JSON import"
```

---

## Chunk 3: Router + Book List Integration

### Task 8: Add route to router

**Files:**
- Modify: `owlio_admin/lib/core/router.dart`

- [ ] **Step 1: Add import statement and route**

Add import at top of `router.dart`:

```dart
import '../features/books/screens/book_json_import_screen.dart';
```

Add new route BEFORE the `/books/new` route (order matters in GoRouter — more specific paths first):

```dart
GoRoute(
  path: '/books/import',
  builder: (context, state) => const BookJsonImportScreen(),
),
```

- [ ] **Step 2: Verify file compiles**

Run: `cd owlio_admin && dart analyze lib/core/router.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add owlio_admin/lib/core/router.dart
git commit -m "feat(admin): add /books/import route"
```

---

### Task 9: Add "Import JSON" button to book list screen

**Files:**
- Modify: `owlio_admin/lib/features/books/screens/book_list_screen.dart`

- [ ] **Step 1: Add an "Import JSON" button in the AppBar actions**

In the `actions` list of the AppBar, add an `OutlinedButton.icon` before the existing `FilledButton.icon`:

```dart
actions: [
  OutlinedButton.icon(
    onPressed: () => context.go('/books/import'),
    icon: const Icon(Icons.upload_file, size: 18),
    label: const Text('JSON İçe Aktar'),
  ),
  const SizedBox(width: 8),
  FilledButton.icon(
    onPressed: () => context.go('/books/new'),
    icon: const Icon(Icons.add, size: 18),
    label: const Text('Yeni Kitap'),
  ),
  const SizedBox(width: 16),
],
```

- [ ] **Step 2: Verify file compiles**

Run: `cd owlio_admin && dart analyze lib/features/books/screens/book_list_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add owlio_admin/lib/features/books/screens/book_list_screen.dart
git commit -m "feat(admin): add JSON import button to book list"
```

---

### Task 10: Final verification

- [ ] **Step 1: Run full analyzer on admin panel**

Run: `cd owlio_admin && dart analyze lib/`
Expected: No issues found (or pre-existing warnings only)

- [ ] **Step 2: Manual test**

Run: `cd owlio_admin && flutter run -d chrome`

Test flow:
1. Navigate to `/books` — verify "JSON İçe Aktar" button appears
2. Click it — verify stepper screen loads at step 1
3. Paste invalid JSON → click Validate → verify errors show in step 2
4. Paste valid JSON → click Validate → verify green preview in step 2
5. Click "Import Et" → verify progress log in step 3
6. Verify redirect to book edit page

- [ ] **Step 3: Final commit if any fixes needed**
