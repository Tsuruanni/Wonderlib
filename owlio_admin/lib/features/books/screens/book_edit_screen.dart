import 'package:flutter/material.dart';
import '../../../core/widgets/edit_screen_shortcuts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';

/// Provider for loading a single book with its chapters
final bookDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, bookId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.books)
      .select('*, chapters(*)')
      .eq('id', bookId)
      .order('order_index', ascending: true, referencedTable: 'chapters')
      .maybeSingle();

  return response;
});

/// Provider for checking if a book has a quiz
final bookQuizSummaryProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, bookId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.bookQuizzes)
      .select('id, passing_score, total_points, is_published, book_quiz_questions(id)')
      .eq('book_id', bookId)
      .maybeSingle();
  return response;
});

class BookEditScreen extends ConsumerStatefulWidget {
  const BookEditScreen({super.key, this.bookId});

  final String? bookId;

  @override
  ConsumerState<BookEditScreen> createState() => _BookEditScreenState();
}

class _BookEditScreenState extends ConsumerState<BookEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _coverUrlController = TextEditingController();
  final _lexileController = TextEditingController();

  // CEFR levels from shared package
  static final _validLevels = CEFRLevel.allValues;

  String _getLevelLabel(String level) {
    return CEFRLevel.fromDbValue(level).displayName;
  }

  String _level = 'B1';
  bool _isPublished = false;
  bool _isLoading = false;
  bool _isSaving = false;

  bool get isNewBook => widget.bookId == null;

  @override
  void initState() {
    super.initState();
    if (!isNewBook) {
      _loadBook();
    }
  }

  Future<void> _loadBook() async {
    setState(() => _isLoading = true);

    final book = await ref.read(bookDetailProvider(widget.bookId!).future);
    if (book != null && mounted) {
      _titleController.text = book['title'] ?? '';
      _authorController.text = book['author'] ?? '';
      _descriptionController.text = book['description'] ?? '';
      _coverUrlController.text = book['cover_image_url'] ?? '';
      final lexile = book['lexile_score'] as int?;
      _lexileController.text = lexile != null ? '$lexile' : '';
      final dbLevel = book['level'] as String? ?? 'B1';
      setState(() {
        // Normalize level to valid CEFR levels
        _level = _validLevels.contains(dbLevel) ? dbLevel : 'B1';
        _isPublished = book['status'] == BookStatus.published.dbValue;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _coverUrlController.dispose();
    _lexileController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      final lexileText = _lexileController.text.trim();
      final lexileScore = lexileText.isNotEmpty ? int.tryParse(lexileText) : null;

      final data = <String, dynamic>{
        'title': _titleController.text.trim(),
        'author': _authorController.text.trim(),
        'description': _descriptionController.text.trim(),
        'cover_image_url': _coverUrlController.text.trim(),
        'level': _level,
        'lexile_score': lexileScore,
        'status': _isPublished ? BookStatus.published.dbValue : BookStatus.draft.dbValue,
      };

      if (isNewBook) {
        data['id'] = const Uuid().v4();
        // Generate slug from title
        data['slug'] = _titleController.text
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
            .replaceAll(RegExp(r'\s+'), '-');
        await supabase.from(DbTables.books).insert(data);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Book created successfully')),
          );
          context.go('/books/${data['id']}');
        }
      } else {
        await supabase.from(DbTables.books).update(data).eq('id', widget.bookId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Book saved successfully')),
          );
          ref.invalidate(bookDetailProvider(widget.bookId!));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book'),
        content: const Text(
          'Are you sure you want to delete this book? This action cannot be undone.',
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
      await supabase.from(DbTables.books).delete().eq('id', widget.bookId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book deleted')),
        );
        context.go('/books');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
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
    final bookAsync = isNewBook ? null : ref.watch(bookDetailProvider(widget.bookId!));

    return Scaffold(
      appBar: AppBar(
        title: Text(isNewBook ? 'New Book' : 'Edit Book'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/books'),
        ),
        actions: [
          if (!isNewBook)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              onPressed: _handleDelete,
            ),
          const SizedBox(width: 8),
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
                : Text(isNewBook ? 'Create' : 'Save'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Book form
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
                            'Book Details',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 24),

                          // Title
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              hintText: 'Enter book title',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Title is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Author
                          TextFormField(
                            controller: _authorController,
                            decoration: const InputDecoration(
                              labelText: 'Author',
                              hintText: 'Enter author name',
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Description
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              hintText: 'Enter book description',
                            ),
                            maxLines: 4,
                          ),
                          const SizedBox(height: 16),

                          // Cover URL
                          TextFormField(
                            controller: _coverUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Cover Image URL',
                              hintText: 'https://...',
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Level dropdown (CEFR + descriptive levels)
                          DropdownButtonFormField<String>(
                            value: _validLevels.contains(_level) ? _level : 'B1',
                            decoration: const InputDecoration(
                              labelText: 'Level',
                            ),
                            items: _validLevels.map((level) {
                              return DropdownMenuItem(
                                value: level,
                                child: Text(_getLevelLabel(level)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _level = value);
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // Lexile Score
                          TextFormField(
                            controller: _lexileController,
                            decoration: const InputDecoration(
                              labelText: 'Lexile Score',
                              hintText: 'e.g. 820',
                              helperText: 'Typical range: 0–2000',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final n = int.tryParse(value);
                                if (n == null) return 'Enter a valid number';
                                if (n < 0 || n > 2000) return 'Must be between 0–2000';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Published switch
                          SwitchListTile(
                            title: const Text('Published'),
                            subtitle: const Text(
                              'When enabled, the book will be visible to users',
                            ),
                            value: _isPublished,
                            onChanged: (value) {
                              setState(() => _isPublished = value);
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Chapters list (only for existing books)
                if (!isNewBook)
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: bookAsync?.when(
                            data: (book) {
                              final chapters = (book?['chapters'] as List? ?? [])
                                  .cast<Map<String, dynamic>>();

                              return _ChaptersList(
                                bookId: widget.bookId!,
                                chapters: chapters,
                                onRefresh: () => ref.invalidate(
                                  bookDetailProvider(widget.bookId!),
                                ),
                              );
                            },
                            loading: () =>
                                const Center(child: CircularProgressIndicator()),
                            error: (e, _) => Center(child: Text('Error: $e')),
                          ) ??
                          const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ChaptersList extends ConsumerStatefulWidget {
  const _ChaptersList({
    required this.bookId,
    required this.chapters,
    required this.onRefresh,
  });

  final String bookId;
  final List<Map<String, dynamic>> chapters;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_ChaptersList> createState() => _ChaptersListState();
}

class _ChaptersListState extends ConsumerState<_ChaptersList> {
  bool _isExtracting = false;

  Future<void> _extractVocabulary() async {
    if (widget.chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No chapters found to extract vocabulary from')),
      );
      return;
    }

    setState(() => _isExtracting = true);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Extracting vocabulary from ${widget.chapters.length} chapters...'),
            const SizedBox(height: 8),
            Text(
              'This may take a moment...',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );

    try {
      final supabase = ref.read(supabaseClientProvider);

      // 1. Collect all chapter texts
      final allTexts = <String>[];
      for (final chapter in widget.chapters) {
        // Check for content blocks first
        final blocksResponse = await supabase
            .from(DbTables.contentBlocks)
            .select('text')
            .eq('chapter_id', chapter['id'])
            .eq('type', 'text')
            .order('order_index', ascending: true);

        final blocks = blocksResponse as List;
        if (blocks.isNotEmpty) {
          // Use content blocks
          final blockTexts = blocks.map((b) => b['text'] as String? ?? '').toList();
          allTexts.add(blockTexts.join('\n'));
        } else if (chapter['content'] != null) {
          // Use legacy content
          allTexts.add(chapter['content'] as String);
        }
      }

      final combinedText = allTexts.join('\n\n');

      if (combinedText.trim().isEmpty) {
        if (mounted) Navigator.pop(context); // Close dialog
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No text content found in chapters')),
          );
        }
        return;
      }

      // 2. Call edge function
      final response = await supabase.functions.invoke(
        'extract-vocabulary',
        body: {
          'text': combinedText,
          'bookId': widget.bookId,
          'extractAll': true,
          'saveToDb': true,
        },
      );

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        final savedCount = data['savedCount'] as int? ?? 0;
        final words = data['words'] as List? ?? [];

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ ${words.length} words extracted, $savedCount saved to database'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final error = response.data?['error'] ?? 'Unknown error';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExtracting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizAsync = ref.watch(bookQuizSummaryProvider(widget.bookId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quiz section
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quiz',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              quizAsync.when(
                loading: () => const SizedBox(
                  height: 40,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (e, _) => Text('Error: $e', style: TextStyle(color: Colors.red.shade600)),
                data: (quiz) {
                  if (quiz != null) {
                    final questions = (quiz['book_quiz_questions'] as List?) ?? [];
                    final passingScore = quiz['passing_score'] ?? 70;
                    final isPublished = quiz['is_published'] ?? false;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                child: const Icon(Icons.quiz, size: 18, color: Color(0xFF4F46E5)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${questions.length} questions · $passingScore% passing score',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isPublished ? 'Published' : 'Draft',
                                      style: TextStyle(
                                        color: isPublished ? Colors.green.shade600 : Colors.orange.shade600,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => context.go('/books/${widget.bookId}/quiz'),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Edit Quiz'),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.go('/books/${widget.bookId}/quiz'),
                        icon: const Icon(Icons.quiz, size: 18),
                        label: const Text('Create Quiz'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4F46E5),
                          side: const BorderSide(color: Color(0xFF4F46E5)),
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chapters (${widget.chapters.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  FilledButton.icon(
                    onPressed: () => context.go('/books/${widget.bookId}/chapters/new'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Vocabulary extraction button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isExtracting ? null : _extractVocabulary,
                  icon: _isExtracting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Extract All Vocabulary'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4F46E5),
                    side: const BorderSide(color: Color(0xFF4F46E5)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: widget.chapters.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.article_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No chapters yet',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: widget.chapters.length,
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        final elevation = Tween<double>(begin: 0, end: 4).evaluate(animation);
                        return Material(
                          elevation: elevation,
                          child: child,
                        );
                      },
                      child: child,
                    );
                  },
                  onReorder: (oldIndex, newIndex) async {
                    if (oldIndex == newIndex) return;
                    if (newIndex > oldIndex) newIndex--;

                    final supabase = ref.read(supabaseClientProvider);

                    // Create a mutable copy and reorder
                    final reorderedChapters = List<Map<String, dynamic>>.from(widget.chapters);
                    final movedChapter = reorderedChapters.removeAt(oldIndex);
                    reorderedChapters.insert(newIndex, movedChapter);

                    // Update all order_index values in a batch
                    final updates = <Future>[];
                    for (int i = 0; i < reorderedChapters.length; i++) {
                      final chapter = reorderedChapters[i];
                      if (chapter['order_index'] != i) {
                        updates.add(
                          supabase
                              .from(DbTables.chapters)
                              .update({'order_index': i})
                              .eq('id', chapter['id']),
                        );
                      }
                    }

                    await Future.wait(updates);
                    widget.onRefresh();
                  },
                  itemBuilder: (context, index) {
                    final chapter = widget.chapters[index];
                    return _ChapterTile(
                      key: ValueKey(chapter['id']),
                      chapter: chapter,
                      index: index,
                      bookId: widget.bookId,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    super.key,
    required this.chapter,
    required this.index,
    required this.bookId,
  });

  final Map<String, dynamic> chapter;
  final int index;
  final String bookId;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
        child: Text(
          '${index + 1}',
          style: const TextStyle(
            color: Color(0xFF4F46E5),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        'Chapter ${index + 1}: ${chapter['title'] ?? 'Untitled Chapter'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        chapter['use_content_blocks'] == true
            ? 'Content blocks'
            : '${(chapter['content'] as String?)?.split(' ').length ?? 0} words',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
      trailing: ReorderableDragStartListener(
        index: index,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(Icons.drag_handle, color: Colors.grey.shade600),
          ),
        ),
      ),
      onTap: () => context.go('/books/$bookId/chapters/${chapter['id']}'),
    );
  }
}
