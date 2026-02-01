import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/extensions/context_extensions.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/repositories/teacher_repository.dart';
import '../../../domain/usecases/assignment/create_assignment_usecase.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/teacher_provider.dart';
import '../../providers/usecase_providers.dart';
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
  // Use start of today for start_date to avoid timezone issues
  DateTime _startDate = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7)).copyWith(hour: 23, minute: 59, second: 59);
  bool _isLoading = false;

  // For book assignments
  String? _selectedBookId;
  String? _selectedBookTitle;
  int? _selectedBookChapterCount;
  bool _lockLibrary = false;

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

      final useCase = ref.read(createAssignmentUseCaseProvider);
      final result = await useCase(CreateAssignmentParams(
        teacherId: userId,
        classId: _selectedClassId,
        type: _selectedType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        bookId: _selectedBookId,
        wordListId: _selectedWordListId,
        lockLibrary: _lockLibrary,
        startDate: _startDate,
        dueDate: _dueDate,
      ),);

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
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => _BookSelectionSheet(
          scrollController: scrollController,
          selectedBookId: _selectedBookId,
          onBookSelected: (book, chapterCount) {
            setState(() {
              _selectedBookId = book.id;
              _selectedBookTitle = book.title;
              _selectedBookChapterCount = chapterCount;
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
    final classesAsync = ref.watch(currentTeacherClassesProvider);
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
                  _selectedBookChapterCount = null;
                  _lockLibrary = false;
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
                hintText: 'e.g., Read The Little Prince',
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
                        : 'Select Book',
                  ),
                  subtitle: Text(
                    _selectedBookId != null
                        ? '${_selectedBookChapterCount ?? 0} chapters (full book)'
                        : 'Tap to choose a book',
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

              // Lock library option
              if (_selectedBookId != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: CheckboxListTile(
                    title: const Text('Lock other books'),
                    subtitle: const Text(
                      'Students can only read this book until completed',
                    ),
                    value: _lockLibrary,
                    onChanged: (value) {
                      setState(() {
                        _lockLibrary = value ?? false;
                      });
                    },
                    secondary: Icon(
                      _lockLibrary ? Icons.lock : Icons.lock_open,
                      color: _lockLibrary
                          ? context.colorScheme.primary
                          : context.colorScheme.outline,
                    ),
                  ),
                ),
              ],
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
// BOOK SELECTION SHEET (Simplified - no chapter selection)
// =============================================

class _BookSelectionSheet extends ConsumerWidget {
  const _BookSelectionSheet({
    required this.scrollController,
    required this.selectedBookId,
    required this.onBookSelected,
  });

  final ScrollController scrollController;
  final String? selectedBookId;
  final void Function(Book book, int chapterCount) onBookSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  'Select Book',
                  style: context.textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),

        // Book list
        Expanded(
          child: booksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('Error loading books')),
            data: (books) {
              if (books.isEmpty) {
                return const Center(child: Text('No books available'));
              }

              return ListView.builder(
                controller: scrollController,
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final book = books[index];
                  final isSelected = selectedBookId == book.id;

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
                    title: Text(
                      book.title,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : null,
                        color: isSelected ? context.colorScheme.primary : null,
                      ),
                    ),
                    subtitle: Text(
                      '${book.chapterCount} chapters • ${book.level}',
                      style: context.textTheme.bodySmall,
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: context.colorScheme.primary)
                        : const Icon(Icons.chevron_right),
                    onTap: () => onBookSelected(book, book.chapterCount),
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
