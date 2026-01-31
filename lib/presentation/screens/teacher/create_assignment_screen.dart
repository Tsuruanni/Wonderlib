import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/extensions/context_extensions.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/repositories/teacher_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/repository_providers.dart';
import '../../providers/teacher_provider.dart';
import '../../providers/vocabulary_provider.dart';

class CreateAssignmentScreen extends ConsumerStatefulWidget {
  const CreateAssignmentScreen({super.key});

  @override
  ConsumerState<CreateAssignmentScreen> createState() => _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends ConsumerState<CreateAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  AssignmentType _selectedType = AssignmentType.book;
  String? _selectedClassId;
  DateTime _startDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _isLoading = false;

  // For book assignments
  String? _selectedBookId;
  String? _selectedBookTitle;
  List<String> _selectedChapterIds = [];
  List<Chapter> _selectedChapters = [];

  // For vocabulary assignments
  String? _selectedWordListId;
  String? _selectedWordListName;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate = isStartDate ? _startDate : _dueDate;
    final firstDate = isStartDate ? DateTime.now() : _startDate;
    final lastDate = DateTime.now().add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_dueDate.isBefore(_startDate)) {
            _dueDate = _startDate.add(const Duration(days: 7));
          }
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  Future<void> _createAssignment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        throw Exception('Not authenticated');
      }

      final teacherRepo = ref.read(teacherRepositoryProvider);

      // Validate content selection
      if (_selectedType == AssignmentType.book && _selectedBookId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a book')),
        );
        return;
      }

      if (_selectedType == AssignmentType.vocabulary && _selectedWordListId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a word list')),
        );
        return;
      }

      // Build content config based on type
      Map<String, dynamic> contentConfig = {};
      if (_selectedType == AssignmentType.book) {
        contentConfig = {
          'bookId': _selectedBookId,
          'chapterIds': _selectedChapterIds,
        };
      } else if (_selectedType == AssignmentType.vocabulary) {
        contentConfig = {
          'wordListId': _selectedWordListId,
        };
      }

      final data = CreateAssignmentData(
        classId: _selectedClassId,
        type: _selectedType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        contentConfig: contentConfig,
        startDate: _startDate,
        dueDate: _dueDate,
      );

      final result = await teacherRepo.createAssignment(userId, data);

      result.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${failure.message}')),
            );
          }
        },
        (assignment) {
          ref.invalidate(teacherAssignmentsProvider);
          ref.invalidate(teacherStatsProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Assignment created successfully')),
            );
            context.pop();
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showBookSelectionSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => _BookSelectionSheet(
          scrollController: scrollController,
          selectedBookId: _selectedBookId,
          selectedChapterIds: _selectedChapterIds,
          onBookSelected: (book, chapters) {
            setState(() {
              _selectedBookId = book.id;
              _selectedBookTitle = book.title;
              _selectedChapters = chapters;
              _selectedChapterIds = chapters.map((c) => c.id).toList();
            });
            Navigator.of(sheetContext).pop();
          },
        ),
      ),
    );
  }

  Future<void> _showWordListSelectionSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => _WordListSelectionSheet(
          scrollController: scrollController,
          selectedWordListId: _selectedWordListId,
          onWordListSelected: (listId, listName) {
            setState(() {
              _selectedWordListId = listId;
              _selectedWordListName = listName;
            });
            Navigator.of(sheetContext).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(teacherClassesProvider);
    final dateFormat = DateFormat('MMM d, y');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Assignment'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Assignment Type
            Text(
              'Assignment Type',
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<AssignmentType>(
              segments: const [
                ButtonSegment(
                  value: AssignmentType.book,
                  label: Text('Book'),
                  icon: Icon(Icons.menu_book),
                ),
                ButtonSegment(
                  value: AssignmentType.vocabulary,
                  label: Text('Vocabulary'),
                  icon: Icon(Icons.abc),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (Set<AssignmentType> newSelection) {
                setState(() {
                  _selectedType = newSelection.first;
                  // Clear selections when type changes
                  _selectedBookId = null;
                  _selectedBookTitle = null;
                  _selectedChapterIds = [];
                  _selectedChapters = [];
                  _selectedWordListId = null;
                  _selectedWordListName = null;
                });
              },
            ),

            const SizedBox(height: 24),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g., Read Chapter 1-3',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Description (optional)
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Instructions for students...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            // Class selection
            Text(
              'Assign to Class',
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            classesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Error loading classes'),
              data: (classes) {
                if (classes.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No classes available',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.outline,
                        ),
                      ),
                    ),
                  );
                }

                return DropdownButtonFormField<String>(
                  value: _selectedClassId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Select a class',
                  ),
                  items: classes.map((c) {
                    return DropdownMenuItem(
                      value: c.id,
                      child: Text('${c.name} (${c.studentCount} students)'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedClassId = value;
                    });
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            // Date selection
            Text(
              'Schedule',
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DatePickerCard(
                    label: 'Start Date',
                    date: _startDate,
                    dateFormat: dateFormat,
                    onTap: () => _selectDate(context, true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DatePickerCard(
                    label: 'Due Date',
                    date: _dueDate,
                    dateFormat: dateFormat,
                    onTap: () => _selectDate(context, false),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Book content selection
            if (_selectedType == AssignmentType.book) ...[
              Text(
                'Book Content',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.menu_book,
                    color: _selectedBookId != null
                        ? context.colorScheme.primary
                        : context.colorScheme.outline,
                  ),
                  title: Text(
                    _selectedBookId != null
                        ? _selectedBookTitle ?? 'Book selected'
                        : 'Select Book & Chapters',
                  ),
                  subtitle: Text(
                    _selectedBookId != null
                        ? '${_selectedChapters.length} chapter(s) selected'
                        : 'Tap to choose content',
                    style: TextStyle(
                      color: _selectedBookId != null
                          ? context.colorScheme.primary
                          : context.colorScheme.outline,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showBookSelectionSheet(context, ref),
                ),
              ),
            ],

            // Vocabulary content selection
            if (_selectedType == AssignmentType.vocabulary) ...[
              Text(
                'Vocabulary Content',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.abc,
                    color: _selectedWordListId != null
                        ? context.colorScheme.primary
                        : context.colorScheme.outline,
                  ),
                  title: Text(
                    _selectedWordListId != null
                        ? _selectedWordListName ?? 'Word list selected'
                        : 'Select Word List',
                  ),
                  subtitle: Text(
                    _selectedWordListId != null
                        ? 'Vocabulary assignment'
                        : 'Tap to choose vocabulary',
                    style: TextStyle(
                      color: _selectedWordListId != null
                          ? context.colorScheme.primary
                          : context.colorScheme.outline,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showWordListSelectionSheet(context, ref),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Create button
            FilledButton(
              onPressed: _isLoading ? null : _createAssignment,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Assignment'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePickerCard extends StatelessWidget {
  const _DatePickerCard({
    required this.label,
    required this.date,
    required this.dateFormat,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat.format(date),
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================
// BOOK SELECTION SHEET
// =============================================

class _BookSelectionSheet extends ConsumerStatefulWidget {
  const _BookSelectionSheet({
    required this.scrollController,
    required this.selectedBookId,
    required this.selectedChapterIds,
    required this.onBookSelected,
  });

  final ScrollController scrollController;
  final String? selectedBookId;
  final List<String> selectedChapterIds;
  final void Function(Book book, List<Chapter> chapters) onBookSelected;

  @override
  ConsumerState<_BookSelectionSheet> createState() => _BookSelectionSheetState();
}

class _BookSelectionSheetState extends ConsumerState<_BookSelectionSheet> {
  String? _currentBookId;
  final Set<String> _selectedChapterIds = {};

  @override
  void initState() {
    super.initState();
    _currentBookId = widget.selectedBookId;
    _selectedChapterIds.addAll(widget.selectedChapterIds);
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(booksProvider(null));

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: context.colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _currentBookId == null ? 'Select Book' : 'Select Chapters',
                  style: context.textTheme.titleLarge,
                ),
              ),
              if (_currentBookId != null)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _currentBookId = null;
                      _selectedChapterIds.clear();
                    });
                  },
                  child: const Text('Change Book'),
                ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _currentBookId == null
              ? _buildBookList(booksAsync)
              : _buildChapterList(),
        ),

        // Confirm button (when chapters are selected)
        if (_currentBookId != null && _selectedChapterIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: context.colorScheme.outlineVariant,
                ),
              ),
            ),
            child: FilledButton(
              onPressed: () async {
                final bookAsync = ref.read(bookByIdProvider(_currentBookId!));
                final book = bookAsync.valueOrNull;
                if (book == null) return;

                final chaptersAsync = ref.read(chaptersProvider(_currentBookId!));
                final allChapters = chaptersAsync.valueOrNull ?? [];
                final selectedChapters = allChapters
                    .where((c) => _selectedChapterIds.contains(c.id))
                    .toList();

                widget.onBookSelected(book, selectedChapters);
              },
              child: Text('Confirm (${_selectedChapterIds.length} chapters)'),
            ),
          ),
      ],
    );
  }

  Widget _buildBookList(AsyncValue<List<Book>> booksAsync) {
    return booksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading books')),
      data: (books) {
        if (books.isEmpty) {
          return const Center(child: Text('No books available'));
        }

        return ListView.builder(
          controller: widget.scrollController,
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            return ListTile(
              leading: book.coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        book.coverUrl!,
                        width: 40,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 40,
                          height: 56,
                          color: context.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.menu_book, size: 20),
                        ),
                      ),
                    )
                  : Container(
                      width: 40,
                      height: 56,
                      decoration: BoxDecoration(
                        color: context.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.menu_book, size: 20),
                    ),
              title: Text(book.title),
              subtitle: Text(
                '${book.genre ?? 'Book'} • ${book.level}',
                style: context.textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                setState(() {
                  _currentBookId = book.id;
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChapterList() {
    final chaptersAsync = ref.watch(chaptersProvider(_currentBookId!));

    return chaptersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading chapters')),
      data: (chapters) {
        if (chapters.isEmpty) {
          return const Center(child: Text('No chapters available'));
        }

        return Column(
          children: [
            // Select all option
            CheckboxListTile(
              title: const Text('Select All Chapters'),
              value: _selectedChapterIds.length == chapters.length,
              tristate: true,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedChapterIds.addAll(chapters.map((c) => c.id));
                  } else {
                    _selectedChapterIds.clear();
                  }
                });
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: widget.scrollController,
                itemCount: chapters.length,
                itemBuilder: (context, index) {
                  final chapter = chapters[index];
                  final isSelected = _selectedChapterIds.contains(chapter.id);

                  return CheckboxListTile(
                    title: Text('Chapter ${chapter.orderIndex}: ${chapter.title}'),
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedChapterIds.add(chapter.id);
                        } else {
                          _selectedChapterIds.remove(chapter.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// =============================================
// WORD LIST SELECTION SHEET
// =============================================

class _WordListSelectionSheet extends ConsumerWidget {
  const _WordListSelectionSheet({
    required this.scrollController,
    required this.selectedWordListId,
    required this.onWordListSelected,
  });

  final ScrollController scrollController;
  final String? selectedWordListId;
  final void Function(String listId, String listName) onWordListSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordListsAsync = ref.watch(allWordListsProvider);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: context.colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Select Word List',
                  style: context.textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: wordListsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('Error loading word lists')),
            data: (wordLists) {
              if (wordLists.isEmpty) {
                return const Center(child: Text('No word lists available'));
              }

              return ListView.builder(
                controller: scrollController,
                itemCount: wordLists.length,
                itemBuilder: (context, index) {
                  final wordList = wordLists[index];
                  final isSelected = selectedWordListId == wordList.id;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? context.colorScheme.primary
                          : context.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.abc,
                        color: isSelected
                            ? context.colorScheme.onPrimary
                            : context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(wordList.name),
                    subtitle: Text(
                      '${wordList.wordCount} words • ${wordList.category}',
                      style: context.textTheme.bodySmall,
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: context.colorScheme.primary)
                        : null,
                    onTap: () => onWordListSelected(wordList.id, wordList.name),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
