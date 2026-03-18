import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import '../../units/screens/unit_list_screen.dart' show unitsProvider;
import '../../users/screens/user_list_screen.dart' show allSchoolsProvider;
import 'unit_books_list_screen.dart' show unitBookAssignmentsProvider;

// ============================================
// PROVIDERS
// ============================================

/// Classes for a given school
final _schoolClassesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, schoolId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.classes)
      .select('id, name, grade')
      .eq('school_id', schoolId)
      .order('grade')
      .order('name');
  return List<Map<String, dynamic>>.from(response);
});

/// Published books with chapters
final _publishedBooksProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.books)
      .select('id, title, level, cover_url, chapter_count')
      .eq('status', BookStatus.published.dbValue)
      .gt('chapter_count', 0)
      .order('title');
  return List<Map<String, dynamic>>.from(response);
});

/// Book search
final _bookSearchProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, query) async {
  if (query.isEmpty) return [];
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.books)
      .select('id, title, level, cover_url, chapter_count')
      .eq('status', BookStatus.published.dbValue)
      .gt('chapter_count', 0)
      .ilike('title', '%$query%')
      .order('title')
      .limit(20);
  return List<Map<String, dynamic>>.from(response);
});

/// Existing book assignments for a specific scope
final _scopeBookAssignmentsProvider = FutureProvider.family<
    List<Map<String, dynamic>>, _ScopeParams>((ref, params) async {
  final supabase = ref.watch(supabaseClientProvider);
  var query = supabase
      .from(DbTables.unitBookAssignments)
      .select('id, book_id, order_in_unit, books(id, title, level, cover_url, chapter_count)')
      .eq('unit_id', params.unitId)
      .eq('school_id', params.schoolId);

  if (params.grade != null) {
    query = query.eq('grade', params.grade!);
  } else {
    query = query.isFilter('grade', null);
  }

  if (params.classId != null) {
    query = query.eq('class_id', params.classId!);
  } else {
    query = query.isFilter('class_id', null);
  }

  final response = await query.order('order_in_unit');
  return List<Map<String, dynamic>>.from(response);
});

class _ScopeParams {
  const _ScopeParams({
    required this.unitId,
    required this.schoolId,
    this.grade,
    this.classId,
  });
  final String unitId;
  final String schoolId;
  final int? grade;
  final String? classId;

  @override
  bool operator ==(Object other) =>
      other is _ScopeParams &&
      unitId == other.unitId &&
      schoolId == other.schoolId &&
      grade == other.grade &&
      classId == other.classId;

  @override
  int get hashCode => Object.hash(unitId, schoolId, grade, classId);
}

// ============================================
// SCOPE TYPE
// ============================================

enum _ScopeType { school, grade, classSpecific }

// ============================================
// SCREEN
// ============================================

class UnitBooksEditScreen extends ConsumerStatefulWidget {
  const UnitBooksEditScreen({super.key, this.assignmentId});
  final String? assignmentId;

  @override
  ConsumerState<UnitBooksEditScreen> createState() =>
      _UnitBooksEditScreenState();
}

class _UnitBooksEditScreenState extends ConsumerState<UnitBooksEditScreen> {
  String? _unitId;
  String? _schoolId;
  _ScopeType _scopeType = _ScopeType.grade;
  int? _selectedGrade;
  String? _selectedClassId;

  // Selected books with order
  final List<Map<String, dynamic>> _selectedBooks = [];
  Set<String> _existingAssignmentIds = {};

  bool _isLoading = false;

  static const int _maxBooks = 3;

  void _resetScope() {
    setState(() {
      _selectedBooks.clear();
      _existingAssignmentIds = {};
      _selectedGrade = null;
      _selectedClassId = null;
    });
  }

  Future<void> _loadExistingAssignments() async {
    if (_unitId == null || _schoolId == null) return;

    int? grade;
    String? classId;
    if (_scopeType == _ScopeType.grade) grade = _selectedGrade;
    if (_scopeType == _ScopeType.classSpecific) classId = _selectedClassId;

    if (_scopeType == _ScopeType.grade && grade == null) return;
    if (_scopeType == _ScopeType.classSpecific && classId == null) return;

    final params = _ScopeParams(
      unitId: _unitId!,
      schoolId: _schoolId!,
      grade: grade,
      classId: classId,
    );

    try {
      final existing =
          await ref.read(_scopeBookAssignmentsProvider(params).future);

      setState(() {
        _existingAssignmentIds =
            existing.map((a) => a['id'] as String).toSet();
        _selectedBooks.clear();
        for (final a in existing) {
          final bookData = a['books'] as Map<String, dynamic>?;
          if (bookData != null) {
            _selectedBooks.add(bookData);
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yükleme hatası: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    // Validation
    if (_unitId == null) {
      _showError('Lütfen bir ünite seçin');
      return;
    }
    if (_schoolId == null) {
      _showError('Lütfen bir okul seçin');
      return;
    }
    if (_scopeType == _ScopeType.grade && _selectedGrade == null) {
      _showError('Lütfen bir sınıf seçin');
      return;
    }
    if (_scopeType == _ScopeType.classSpecific && _selectedClassId == null) {
      _showError('Lütfen bir şube seçin');
      return;
    }
    if (_selectedBooks.isEmpty) {
      _showError('Lütfen en az bir kitap seçin');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final userId = supabase.auth.currentUser?.id;

      // 1. Delete existing assignments for this scope
      if (_existingAssignmentIds.isNotEmpty) {
        await supabase
            .from(DbTables.unitBookAssignments)
            .delete()
            .inFilter('id', _existingAssignmentIds.toList());
      }

      // 2. Insert new assignments
      final rows = <Map<String, dynamic>>[];
      for (int i = 0; i < _selectedBooks.length; i++) {
        rows.add({
          'id': const Uuid().v4(),
          'unit_id': _unitId,
          'book_id': _selectedBooks[i]['id'],
          'school_id': _schoolId,
          'grade': _scopeType == _ScopeType.grade ? _selectedGrade : null,
          'class_id':
              _scopeType == _ScopeType.classSpecific ? _selectedClassId : null,
          'order_in_unit': i,
          'assigned_by': userId,
        });
      }

      await supabase.from(DbTables.unitBookAssignments).insert(rows);

      ref.invalidate(unitBookAssignmentsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedBooks.length} kitap başarıyla atandı',
            ),
          ),
        );
        context.go('/unit-books');
      }
    } catch (e) {
      _showError('Hata: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _addBook(Map<String, dynamic> book) {
    if (_selectedBooks.length >= _maxBooks) {
      _showError('Kapsam başına en fazla $_maxBooks kitap');
      return;
    }
    if (_selectedBooks.any((b) => b['id'] == book['id'])) {
      _showError('Kitap zaten seçili');
      return;
    }
    setState(() => _selectedBooks.add(book));
  }

  void _removeBook(int index) {
    setState(() => _selectedBooks.removeAt(index));
  }

  void _reorderBooks(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final book = _selectedBooks.removeAt(oldIndex);
      _selectedBooks.insert(newIndex, book);
    });
  }

  @override
  Widget build(BuildContext context) {
    final unitsAsync = ref.watch(unitsProvider);
    final schoolsAsync = ref.watch(allSchoolsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Üniteye Kitap Ata'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/unit-books'),
        ),
        actions: [
          FilledButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kaydet'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Panel: Scope Selection
            Expanded(
              flex: 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ListView(
                    children: [
                      Text(
                        'Kapsam',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 24),

                      // Unit selector
                      unitsAsync.when(
                        data: (units) => DropdownButtonFormField<String?>(
                          initialValue: _unitId,
                          decoration: const InputDecoration(
                            labelText: 'Ünite *',
                            border: OutlineInputBorder(),
                          ),
                          items: units
                              .map(
                                (u) => DropdownMenuItem<String?>(
                                  value: u['id'] as String,
                                  child: Text(
                                    '${u['sort_order']}. ${u['name']}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _unitId = v;
                              _selectedBooks.clear();
                              _existingAssignmentIds = {};
                            });
                          },
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Hata: $e'),
                      ),
                      const SizedBox(height: 16),

                      // School selector
                      schoolsAsync.when(
                        data: (schools) => DropdownButtonFormField<String?>(
                          initialValue: _schoolId,
                          decoration: const InputDecoration(
                            labelText: 'Okul *',
                            border: OutlineInputBorder(),
                          ),
                          items: schools
                              .map(
                                (s) => DropdownMenuItem<String?>(
                                  value: s['id'] as String,
                                  child: Text(s['name'] as String? ?? ''),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _schoolId = v;
                              _resetScope();
                            });
                          },
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Hata: $e'),
                      ),
                      const SizedBox(height: 24),

                      // Scope type
                      const Text(
                        'Hedef',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      RadioGroup<_ScopeType>(
                        groupValue: _scopeType,
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _scopeType = v;
                            _selectedBooks.clear();
                            _existingAssignmentIds = {};
                            if (v == _ScopeType.school) {
                              _selectedGrade = null;
                              _selectedClassId = null;
                            } else if (v == _ScopeType.grade) {
                              _selectedClassId = null;
                            } else {
                              _selectedGrade = null;
                            }
                          });
                        },
                        child: Column(
                          children: [
                            RadioListTile<_ScopeType>(
                              title: const Text('Tüm Okul'),
                              subtitle:
                                  const Text('Bu okuldaki tüm öğrenciler'),
                              value: _ScopeType.school,
                            ),
                            RadioListTile<_ScopeType>(
                              title: const Text('Sınıfa Göre'),
                              subtitle: const Text(
                                'Belirli bir sınıfın tüm şubeleri',
                              ),
                              value: _ScopeType.grade,
                            ),
                            RadioListTile<_ScopeType>(
                              title: const Text('Şubeye Göre'),
                              subtitle: const Text('Sadece belirli bir şube'),
                              value: _ScopeType.classSpecific,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Grade selector (if by grade)
                      if (_scopeType == _ScopeType.grade)
                        DropdownButtonFormField<int?>(
                          key: ValueKey('grade_$_selectedGrade'),
                          initialValue: _selectedGrade,
                          decoration: const InputDecoration(
                            labelText: 'Sınıf *',
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(
                            12,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text('${i + 1}. Sınıf'),
                            ),
                          ),
                          onChanged: (v) {
                            setState(() {
                              _selectedGrade = v;
                              _selectedBooks.clear();
                              _existingAssignmentIds = {};
                            });
                            _loadExistingAssignments();
                          },
                        ),

                      // Class selector (if by class)
                      if (_scopeType == _ScopeType.classSpecific &&
                          _schoolId != null)
                        Consumer(
                          builder: (context, ref, _) {
                            final classesAsync = ref.watch(
                              _schoolClassesProvider(_schoolId!),
                            );
                            return classesAsync.when(
                              data: (classes) =>
                                  DropdownButtonFormField<String?>(
                                key: ValueKey('class_$_selectedClassId'),
                                initialValue: _selectedClassId,
                                decoration: const InputDecoration(
                                  labelText: 'Şube *',
                                  border: OutlineInputBorder(),
                                ),
                                items: classes
                                    .map(
                                      (c) => DropdownMenuItem<String?>(
                                        value: c['id'] as String,
                                        child: Text(
                                          '${c['name']} (${c['grade']}. Sınıf)',
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  setState(() {
                                    _selectedClassId = v;
                                    _selectedBooks.clear();
                                    _existingAssignmentIds = {};
                                  });
                                  _loadExistingAssignments();
                                },
                              ),
                              loading: () => const LinearProgressIndicator(),
                              error: (e, _) => Text('Hata: $e'),
                            );
                          },
                        ),

                      // Load existing button (for school-wide)
                      if (_scopeType == _ScopeType.school &&
                          _unitId != null &&
                          _schoolId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: OutlinedButton.icon(
                            onPressed: _loadExistingAssignments,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Mevcut atamaları yükle'),
                          ),
                        ),

                      // Info box
                      if (_existingAssignmentIds.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(
                                  'Bu kapsam için ${_existingAssignmentIds.length} mevcut atama',
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
            const SizedBox(width: 24),

            // Right Panel: Book Selection
            Expanded(
              flex: 1,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Kitaplar',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          Text(
                            '${_selectedBooks.length}/$_maxBooks',
                            style: TextStyle(
                              color: _selectedBooks.length >= _maxBooks
                                  ? Colors.red
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Add book button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _selectedBooks.length >= _maxBooks
                              ? null
                              : () => _showBookPicker(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Kitap Ekle'),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selected books (reorderable)
                      if (_selectedBooks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              'Kitap seçilmedi',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ReorderableListView.builder(
                            shrinkWrap: true,
                            itemCount: _selectedBooks.length,
                            onReorder: _reorderBooks,
                            itemBuilder: (context, index) {
                              final book = _selectedBooks[index];
                              return Card(
                                key: ValueKey(book['id']),
                                child: ListTile(
                                  leading: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.drag_handle),
                                      const SizedBox(width: 8),
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor:
                                            Colors.blue.shade100,
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  title: Text(
                                    book['title'] as String? ?? '',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    '${book['level'] ?? '-'} | '
                                    '${book['chapter_count'] ?? 0} bölüm',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _removeBook(index),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookPicker(BuildContext context) {
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Kitap Seç'),
            content: SizedBox(
              width: 500,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Kitap ara...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final query = searchController.text.trim();
                        final booksAsync = query.isEmpty
                            ? ref.watch(_publishedBooksProvider)
                            : ref.watch(_bookSearchProvider(query));

                        return booksAsync.when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          error: (e, _) => Center(
                            child: Text('Hata: $e'),
                          ),
                          data: (books) {
                            // Filter out already selected books
                            final selectedIds = _selectedBooks
                                .map((b) => b['id'] as String)
                                .toSet();
                            final available = books
                                .where((b) =>
                                    !selectedIds.contains(b['id'] as String))
                                .toList();

                            if (available.isEmpty) {
                              return const Center(
                                child: Text('Eşleşen kitap bulunamadı'),
                              );
                            }

                            return ListView.builder(
                              itemCount: available.length,
                              itemBuilder: (context, index) {
                                final book = available[index];
                                return ListTile(
                                  leading: const Icon(Icons.menu_book),
                                  title: Text(
                                    book['title'] as String? ?? '',
                                  ),
                                  subtitle: Text(
                                    '${book['level'] ?? '-'} | '
                                    '${book['chapter_count'] ?? 0} bölüm',
                                  ),
                                  onTap: () {
                                    _addBook(book);
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal'),
              ),
            ],
          );
        },
      ),
    );
  }
}
