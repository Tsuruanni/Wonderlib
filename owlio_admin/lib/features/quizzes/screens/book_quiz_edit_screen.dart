import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';

/// Provider for loading a quiz and its questions for a specific book
final bookQuizProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, bookId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.bookQuizzes)
      .select('*, book_quiz_questions(*)')
      .eq('book_id', bookId)
      .order('order_index', referencedTable: 'book_quiz_questions')
      .maybeSingle();

  return response;
});

class BookQuizEditScreen extends ConsumerStatefulWidget {
  const BookQuizEditScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<BookQuizEditScreen> createState() => _BookQuizEditScreenState();
}

class _BookQuizEditScreenState extends ConsumerState<BookQuizEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _passingScoreController = TextEditingController(text: '70');

  bool _isPublished = false;
  bool _isLoading = true;
  bool _isSaving = false;

  String? _quizId;
  List<Map<String, dynamic>> _questions = [];

  bool get isNewQuiz => _quizId == null;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    setState(() => _isLoading = true);

    try {
      final quiz = await ref.read(bookQuizProvider(widget.bookId).future);
      if (quiz != null && mounted) {
        _quizId = quiz['id'] as String;
        _titleController.text = quiz['title'] ?? '';
        _instructionsController.text = quiz['instructions'] ?? '';
        _passingScoreController.text =
            (quiz['passing_score'] ?? 70).toString();
        _isPublished = quiz['is_published'] == true;
        _questions = (quiz['book_quiz_questions'] as List? ?? [])
            .cast<Map<String, dynamic>>();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading quiz: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    _passingScoreController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final passingScore =
          int.tryParse(_passingScoreController.text.trim()) ?? 70;

      final data = {
        'title': _titleController.text.trim(),
        'instructions': _instructionsController.text.trim(),
        'passing_score': passingScore,
        'is_published': _isPublished,
        'book_id': widget.bookId,
        'total_points':
            _questions.fold<int>(0, (sum, q) => sum + ((q['points'] as int?) ?? 1)),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (isNewQuiz) {
        final newId = const Uuid().v4();
        data['id'] = newId;
        data['created_at'] = DateTime.now().toUtc().toIso8601String();
        await supabase.from(DbTables.bookQuizzes).insert(data);
        _quizId = newId;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quiz created successfully')),
          );
        }
      } else {
        await supabase.from(DbTables.bookQuizzes).update(data).eq('id', _quizId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quiz saved successfully')),
          );
        }
      }

      ref.invalidate(bookQuizProvider(widget.bookId));
      if (mounted) setState(() {});
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

  Future<void> _handleDeleteQuestion(String questionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text(
          'Are you sure you want to delete this question? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from(DbTables.bookQuizQuestions).delete().eq('id', questionId);

      ref.invalidate(bookQuizProvider(widget.bookId));
      await _loadQuiz();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    if (newIndex > oldIndex) newIndex--;

    final reordered = List<Map<String, dynamic>>.from(_questions);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    setState(() => _questions = reordered);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final updates = <Future>[];
      for (int i = 0; i < reordered.length; i++) {
        final question = reordered[i];
        if (question['order_index'] != i) {
          updates.add(
            supabase
                .from(DbTables.bookQuizQuestions)
                .update({'order_index': i})
                .eq('id', question['id']),
          );
        }
      }
      await Future.wait(updates);
      ref.invalidate(bookQuizProvider(widget.bookId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reordering: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _handlePublishToggle(bool value) {
    if (value && _questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot publish a quiz with no questions'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _isPublished = value);
  }

  String _getQuestionTypeLabel(String type) {
    switch (type) {
      case 'multiple_choice':
        return 'Multiple Choice';
      case 'fill_blank':
        return 'Fill in the Blank';
      case 'event_sequencing':
        return 'Event Sequencing';
      case 'matching':
        return 'Matching';
      case 'who_says_what':
        return 'Who Says What';
      default:
        return type;
    }
  }

  IconData _getQuestionTypeIcon(String type) {
    final questionType = BookQuizQuestionType.fromDbValue(type);
    switch (questionType) {
      case BookQuizQuestionType.multipleChoice:
        return Icons.radio_button_checked;
      case BookQuizQuestionType.fillBlank:
        return Icons.text_fields;
      case BookQuizQuestionType.eventSequencing:
        return Icons.sort;
      case BookQuizQuestionType.matching:
        return Icons.compare_arrows;
      case BookQuizQuestionType.whoSaysWhat:
        return Icons.chat_bubble_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isNewQuiz ? 'New Book Quiz' : 'Edit Book Quiz'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/books/${widget.bookId}'),
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
                : Text(isNewQuiz ? 'Create' : 'Save'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quiz form
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quiz Details',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 24),

                          // Title
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              hintText: 'Enter quiz title',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Title is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Instructions
                          TextFormField(
                            controller: _instructionsController,
                            decoration: const InputDecoration(
                              labelText: 'Instructions',
                              hintText: 'Enter quiz instructions for students',
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),

                          // Passing Score
                          TextFormField(
                            controller: _passingScoreController,
                            decoration: const InputDecoration(
                              labelText: 'Passing Score (%)',
                              hintText: '70',
                              suffixText: '%',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Passing score is required';
                              }
                              final score = int.tryParse(value.trim());
                              if (score == null || score < 0 || score > 100) {
                                return 'Enter a number between 0 and 100';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Published switch
                          SwitchListTile(
                            title: const Text('Published'),
                            subtitle: Text(
                              _questions.isEmpty
                                  ? 'Add questions before publishing'
                                  : 'When enabled, the quiz will be available to students',
                            ),
                            value: _isPublished,
                            onChanged: _handlePublishToggle,
                            contentPadding: EdgeInsets.zero,
                          ),

                          const SizedBox(height: 24),

                          // Stats card
                          if (!isNewQuiz)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    _StatChip(
                                      label: 'Questions',
                                      value: '${_questions.length}',
                                      icon: Icons.quiz,
                                    ),
                                    const SizedBox(width: 24),
                                    _StatChip(
                                      label: 'Total Points',
                                      value: '${_questions.fold<int>(0, (sum, q) => sum + ((q['points'] as int?) ?? 1))}',
                                      icon: Icons.star,
                                    ),
                                    const SizedBox(width: 24),
                                    _StatChip(
                                      label: 'Status',
                                      value: _isPublished ? 'Published' : 'Draft',
                                      icon: _isPublished
                                          ? Icons.check_circle
                                          : Icons.edit_note,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Questions list
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: _QuestionsList(
                      bookId: widget.bookId,
                      quizId: _quizId,
                      questions: _questions,
                      onReorder: _handleReorder,
                      onDelete: _handleDeleteQuestion,
                      getTypeLabel: _getQuestionTypeLabel,
                      getTypeIcon: _getQuestionTypeIcon,
                      onQuizCreatedFirst: isNewQuiz ? _handleSave : null,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuestionsList extends StatelessWidget {
  const _QuestionsList({
    required this.bookId,
    required this.quizId,
    required this.questions,
    required this.onReorder,
    required this.onDelete,
    required this.getTypeLabel,
    required this.getTypeIcon,
    this.onQuizCreatedFirst,
  });

  final String bookId;
  final String? quizId;
  final List<Map<String, dynamic>> questions;
  final Future<void> Function(int, int) onReorder;
  final Future<void> Function(String) onDelete;
  final String Function(String) getTypeLabel;
  final IconData Function(String) getTypeIcon;
  final Future<void> Function()? onQuizCreatedFirst;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Questions (${questions.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              FilledButton.icon(
                onPressed: () async {
                  if (quizId == null) {
                    // Must save quiz first
                    if (onQuizCreatedFirst != null) {
                      await onQuizCreatedFirst!();
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Quiz saved. Now you can add questions.'),
                        ),
                      );
                    }
                    return;
                  }
                  context.go(
                    '/books/$bookId/quiz/questions/new?quizId=$quizId',
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: questions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.quiz_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No questions yet',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add questions to build your quiz',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: questions.length,
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        final elevation =
                            Tween<double>(begin: 0, end: 4).evaluate(animation);
                        return Material(
                          elevation: elevation,
                          child: child,
                        );
                      },
                      child: child,
                    );
                  },
                  onReorder: onReorder,
                  itemBuilder: (context, index) {
                    final question = questions[index];
                    final type = question['type'] as String? ?? 'multiple_choice';
                    final points = (question['points'] as int?) ?? 1;

                    return ListTile(
                      key: ValueKey(question['id']),
                      leading: CircleAvatar(
                        backgroundColor:
                            const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        child: Icon(
                          getTypeIcon(type),
                          color: const Color(0xFF4F46E5),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        question['question'] ?? 'Untitled Question',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${getTypeLabel(type)} - $points pt${points != 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: Colors.red.shade400, size: 20),
                            onPressed: () => onDelete(question['id'] as String),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(Icons.drag_handle,
                                    color: Colors.grey.shade600),
                              ),
                            ),
                          ),
                        ],
                      ),
                      onTap: () => context.go(
                        '/books/$bookId/quiz/questions/${question['id']}?quizId=$quizId',
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
