import 'package:flutter/material.dart';
import '../../../core/widgets/edit_screen_shortcuts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';

/// Provider for loading a single quiz question
final quizQuestionProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, questionId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.bookQuizQuestions)
      .select()
      .eq('id', questionId)
      .maybeSingle();

  return response;
});

/// The five supported question types
final _questionTypes =
    BookQuizQuestionType.values.map((t) => t.dbValue).toList();

class QuizQuestionEditScreen extends ConsumerStatefulWidget {
  const QuizQuestionEditScreen({
    super.key,
    required this.quizId,
    this.questionId,
  });

  final String quizId;
  final String? questionId;

  @override
  ConsumerState<QuizQuestionEditScreen> createState() =>
      _QuizQuestionEditScreenState();
}

class _QuizQuestionEditScreenState
    extends ConsumerState<QuizQuestionEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _explanationController = TextEditingController();
  final _pointsController = TextEditingController(text: '1');

  String _selectedType = BookQuizQuestionType.multipleChoice.dbValue;
  bool _isLoading = false;
  bool _isSaving = false;

  // Multiple choice state
  final List<TextEditingController> _mcOptionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  String _mcCorrectAnswer = 'A';

  // Fill in the blank state
  final _fillSentenceController = TextEditingController();
  final _fillCorrectController = TextEditingController();
  final _fillAlternativesController = TextEditingController();

  // Event sequencing state
  final List<TextEditingController> _eventControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  List<int> _correctOrder = [0, 1, 2];

  // Matching state
  final List<TextEditingController> _matchLeftControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  final List<TextEditingController> _matchRightControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  // Who says what state
  final List<TextEditingController> _characterControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  final List<TextEditingController> _quoteControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool get isNewQuestion => widget.questionId == null;

  String? _bookId;

  @override
  void initState() {
    super.initState();
    _resolveBookId();
    if (!isNewQuestion) {
      _loadQuestion();
    }
  }

  Future<void> _resolveBookId() async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final quiz = await supabase
          .from(DbTables.bookQuizzes)
          .select('book_id')
          .eq('id', widget.quizId)
          .maybeSingle();
      if (quiz != null && mounted) {
        setState(() => _bookId = quiz['book_id'] as String);
      }
    } catch (e) {
      debugPrint(
        'quiz_question_edit: failed to resolve book_id for quiz ${widget.quizId}: $e',
      );
    }
  }

  Future<void> _loadQuestion() async {
    setState(() => _isLoading = true);

    try {
      final question =
          await ref.read(quizQuestionProvider(widget.questionId!).future);
      if (question != null && mounted) {
        _questionController.text = question['question'] ?? '';
        _explanationController.text = question['explanation'] ?? '';
        _pointsController.text = (question['points'] ?? 1).toString();
        _selectedType = question['type'] ?? BookQuizQuestionType.multipleChoice.dbValue;

        final content = question['content'] as Map<String, dynamic>? ?? {};
        _populateContentFields(content);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading question: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _populateContentFields(Map<String, dynamic> content) {
    final type = BookQuizQuestionType.fromDbValue(_selectedType);
    switch (type) {
      case BookQuizQuestionType.multipleChoice:
        final options = (content['options'] as List?)?.cast<String>() ?? [];
        for (int i = 0; i < _mcOptionControllers.length && i < options.length; i++) {
          _mcOptionControllers[i].text = options[i];
        }
        _mcCorrectAnswer = content['correct_answer'] as String? ?? 'A';

      case BookQuizQuestionType.fillBlank:
        _fillSentenceController.text = content['sentence'] as String? ?? '';
        _fillCorrectController.text = content['correct_answer'] as String? ?? '';
        final alternatives =
            (content['accept_alternatives'] as List?)?.cast<String>() ?? [];
        _fillAlternativesController.text = alternatives.join(', ');

      case BookQuizQuestionType.eventSequencing:
        final events = (content['events'] as List?)?.cast<String>() ?? [];
        final order = (content['correct_order'] as List?)
                ?.map((e) => e as int)
                .toList() ??
            [];
        // Clear existing and rebuild
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
    }
  }

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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final content = _buildContentJson();

      final data = {
        'quiz_id': widget.quizId,
        'type': _selectedType,
        'question': _questionController.text.trim(),
        'content': content,
        'explanation': _explanationController.text.trim().isEmpty
            ? null
            : _explanationController.text.trim(),
        'points': int.tryParse(_pointsController.text.trim()) ?? 1,
      };

      if (isNewQuestion) {
        data['id'] = const Uuid().v4();
        // Get next order_index
        final existing = await supabase
            .from(DbTables.bookQuizQuestions)
            .select('order_index')
            .eq('quiz_id', widget.quizId)
            .order('order_index', ascending: false)
            .limit(1);
        final maxIndex = (existing as List).isNotEmpty
            ? (existing[0]['order_index'] as int) + 1
            : 0;
        data['order_index'] = maxIndex;

        await supabase.from(DbTables.bookQuizQuestions).insert(data);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Question created successfully')),
          );
          // Navigate back to quiz
          if (_bookId != null) {
            context.go('/books/$_bookId/quiz');
          } else {
            context.pop();
          }
        }
      } else {
        await supabase
            .from(DbTables.bookQuizQuestions)
            .update(data)
            .eq('id', widget.questionId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Question saved successfully')),
          );
          if (_bookId != null) {
            context.go('/books/$_bookId/quiz');
          } else {
            context.pop();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _explanationController.dispose();
    _pointsController.dispose();
    for (final c in _mcOptionControllers) {
      c.dispose();
    }
    _fillSentenceController.dispose();
    _fillCorrectController.dispose();
    _fillAlternativesController.dispose();
    for (final c in _eventControllers) {
      c.dispose();
    }
    for (final c in _matchLeftControllers) {
      c.dispose();
    }
    for (final c in _matchRightControllers) {
      c.dispose();
    }
    for (final c in _characterControllers) {
      c.dispose();
    }
    for (final c in _quoteControllers) {
      c.dispose();
    }
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    return EditScreenShortcuts(
      onSave: _isSaving ? null : _handleSave,
      child: _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isNewQuestion ? 'New Question' : 'Edit Question'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_bookId != null) {
              context.go('/books/$_bookId/quiz');
            } else {
              context.pop();
            }
          },
        ),
        actions: [
          FilledButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(isNewQuestion ? 'Create' : 'Save'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type dropdown + Points in a row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedType,
                            decoration: const InputDecoration(
                              labelText: 'Question Type',
                            ),
                            items: _questionTypes.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(_getTypeLabel(type)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedType = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _pointsController,
                            decoration: const InputDecoration(
                              labelText: 'Points',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              final pts = int.tryParse(value.trim());
                              if (pts == null || pts < 1) {
                                return 'Minimum 1';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Question text
                    TextFormField(
                      controller: _questionController,
                      decoration: const InputDecoration(
                        labelText: 'Question',
                        hintText: 'Enter question text',
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Question text is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Dynamic content form
                    Text(
                      'Content',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _buildContentForm(),

                    const SizedBox(height: 24),

                    // Explanation
                    TextFormField(
                      controller: _explanationController,
                      decoration: const InputDecoration(
                        labelText: 'Explanation (optional)',
                        hintText:
                            'Explain the correct answer to help students learn',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

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

  // --------------- Multiple Choice ---------------

  Widget _buildMultipleChoiceForm() {
    const labels = ['A', 'B', 'C', 'D'];
    return RadioGroup<String>(
      groupValue: _mcCorrectAnswer,
      onChanged: (value) {
        if (value != null) {
          setState(() => _mcCorrectAnswer = value);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(4, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: _mcOptionControllers[index],
                decoration: InputDecoration(
                  labelText: 'Option ${labels[index]}',
                  prefixIcon: Radio<String>(
                    value: labels[index],
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Option ${labels[index]} is required';
                  }
                  return null;
                },
              ),
            );
          }),
          Text(
            'Select the radio button next to the correct answer',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // --------------- Fill in the Blank ---------------

  Widget _buildFillBlankForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _fillSentenceController,
          decoration: const InputDecoration(
            labelText: 'Sentence',
            hintText: 'Use ___ for the blank (e.g. "The ___ ran fast.")',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Sentence is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _fillCorrectController,
          decoration: const InputDecoration(
            labelText: 'Correct Answer',
            hintText: 'The word that fills the blank',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Correct answer is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _fillAlternativesController,
          decoration: const InputDecoration(
            labelText: 'Accepted Alternatives (optional)',
            hintText: 'Comma-separated (e.g. "Fox, FOX")',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Alternative answers that should be accepted',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }

  // --------------- Event Sequencing ---------------

  Widget _buildEventSequencingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter events in CORRECT order. Students will see them shuffled.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 12),
        ...List.generate(_eventControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Color(0xFF4F46E5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _eventControllers[index],
                    decoration: InputDecoration(
                      labelText: 'Event ${index + 1}',
                      hintText: 'Describe the event',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Event is required';
                      }
                      return null;
                    },
                  ),
                ),
                if (_eventControllers.length > 2)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline,
                        color: Colors.red.shade400, size: 20),
                    onPressed: () {
                      setState(() {
                        _eventControllers[index].dispose();
                        _eventControllers.removeAt(index);
                        _correctOrder =
                            List.generate(_eventControllers.length, (i) => i);
                      });
                    },
                  ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _eventControllers.add(TextEditingController());
              _correctOrder =
                  List.generate(_eventControllers.length, (i) => i);
            });
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Event'),
        ),
      ],
    );
  }

  // --------------- Matching ---------------

  Widget _buildMatchingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter matching pairs. Left items will be matched with right items.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 12),
        // Header row
        Row(
          children: [
            const SizedBox(width: 40),
            Expanded(
              child: Text(
                'Left',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Right (correct match)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_matchLeftControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Color(0xFF4F46E5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _matchLeftControllers[index],
                    decoration: InputDecoration(
                      hintText: 'Left item ${index + 1}',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _matchRightControllers[index],
                    decoration: InputDecoration(
                      hintText: 'Right item ${index + 1}',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                if (_matchLeftControllers.length > 2)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline,
                        color: Colors.red.shade400, size: 20),
                    onPressed: () {
                      setState(() {
                        _matchLeftControllers[index].dispose();
                        _matchRightControllers[index].dispose();
                        _matchLeftControllers.removeAt(index);
                        _matchRightControllers.removeAt(index);
                      });
                    },
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _matchLeftControllers.add(TextEditingController());
              _matchRightControllers.add(TextEditingController());
            });
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Pair'),
        ),
      ],
    );
  }

  // --------------- Who Says What ---------------

  Widget _buildWhoSaysWhatForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter character-quote pairs. Students will match characters with their quotes.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 12),
        // Header row
        Row(
          children: [
            const SizedBox(width: 40),
            Expanded(
              child: Text(
                'Character',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Quote (correct match)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_characterControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Color(0xFF4F46E5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _characterControllers[index],
                    decoration: InputDecoration(
                      hintText: 'Character ${index + 1}',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _quoteControllers[index],
                    decoration: InputDecoration(
                      hintText: 'Quote ${index + 1}',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                if (_characterControllers.length > 2)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline,
                        color: Colors.red.shade400, size: 20),
                    onPressed: () {
                      setState(() {
                        _characterControllers[index].dispose();
                        _quoteControllers[index].dispose();
                        _characterControllers.removeAt(index);
                        _quoteControllers.removeAt(index);
                      });
                    },
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _characterControllers.add(TextEditingController());
              _quoteControllers.add(TextEditingController());
            });
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Pair'),
        ),
      ],
    );
  }
}
