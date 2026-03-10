import 'dart:convert';

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

class BookJsonValidator {
  static const _validLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
  static const _validStatuses = ['draft', 'published', 'archived'];
  static final _slugRegex = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

  static const _validBlockTypes = ['text', 'image', 'activity'];
  static const _validInlineTypes = ['true_false', 'word_translation', 'find_words', 'matching'];

  static const _validQuizTypes = [
    'multiple_choice',
    'fill_blank',
    'event_sequencing',
    'matching',
    'who_says_what',
  ];

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
          errors.add('$prefix.content.correct_pairs: invalid mapping "${entry.key}" -> "${entry.value}" (out of bounds)');
        }
      }
    }
  }
}
