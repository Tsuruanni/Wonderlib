import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import '../../../core/widgets/learning_path_tree_view.dart';
import '../../users/screens/user_list_screen.dart' show allSchoolsProvider;

// ============================================
// PROVIDERS
// ============================================

/// Classes for a school (for class-specific scope selection).
final _schoolClassesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, schoolId) async {
  final supabase = ref.watch(supabaseClientProvider);
  return List<Map<String, dynamic>>.from(
    await supabase
        .from(DbTables.classes)
        .select('id, name, grade')
        .eq('school_id', schoolId)
        .order('grade')
        .order('name'),
  );
});

/// All templates (for the "apply template" dialog).
final _allTemplatesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  return List<Map<String, dynamic>>.from(
    await supabase
        .from(DbTables.learningPathTemplates)
        .select('id, name, description')
        .order('name'),
  );
});

// ============================================
// DATA CLASSES
// ============================================

enum _ScopeType { school, grade, classSpecific }

class _ScopeLearningPathData {
  String? id; // null for newly added (not yet used — we INSERT then reload)
  String name;
  String? templateId;
  int sortOrder;
  List<LearningPathUnitData> units;
  bool sequentialLock;
  bool booksExemptFromLock;
  bool unitGate;

  _ScopeLearningPathData({
    this.id,
    required this.name,
    this.templateId,
    required this.sortOrder,
    required this.units,
    this.sequentialLock = true,
    this.booksExemptFromLock = true,
    this.unitGate = true,
  });
}

// ============================================
// SCREEN
// ============================================

class AssignmentScreen extends ConsumerStatefulWidget {
  const AssignmentScreen({
    super.key,
    this.initialSchoolId,
    this.initialGrade,
    this.initialClassId,
  });

  final String? initialSchoolId;
  final int? initialGrade;
  final String? initialClassId;

  @override
  ConsumerState<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends ConsumerState<AssignmentScreen> {
  String? _schoolId;
  _ScopeType _scopeType = _ScopeType.grade;
  int? _selectedGrade;
  String? _selectedClassId;
  List<_ScopeLearningPathData> _learningPaths = [];
  bool _isLoading = false;
  bool _isSaving = false;
  Timer? _saveDebounceTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialSchoolId != null) {
      _schoolId = widget.initialSchoolId;
      if (widget.initialClassId != null) {
        _scopeType = _ScopeType.classSpecific;
        _selectedClassId = widget.initialClassId;
      } else if (widget.initialGrade != null) {
        _scopeType = _ScopeType.grade;
        _selectedGrade = widget.initialGrade;
      } else {
        _scopeType = _ScopeType.school;
      }
      // Auto-load after frame so providers are ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadScopeAssignments();
      });
    }
  }

  bool get _isScopeComplete {
    if (_schoolId == null) return false;
    if (_scopeType == _ScopeType.grade && _selectedGrade == null) return false;
    if (_scopeType == _ScopeType.classSpecific && _selectedClassId == null) {
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _saveDebounceTimer?.cancel();
    super.dispose();
  }

  // ============================================
  // LOAD
  // ============================================

  Future<void> _loadScopeAssignments() async {
    if (!_isScopeComplete) return;

    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      // Build query for scope_learning_paths matching current scope
      var query = supabase
          .from(DbTables.scopeLearningPaths)
          .select('id, name, template_id, sort_order, sequential_lock, books_exempt_from_lock, unit_gate')
          .eq('school_id', _schoolId!);

      if (_scopeType == _ScopeType.grade) {
        query = query.eq('grade', _selectedGrade!).isFilter('class_id', null);
      } else if (_scopeType == _ScopeType.classSpecific) {
        query =
            query.eq('class_id', _selectedClassId!).isFilter('grade', null);
      } else {
        // School-wide
        query = query.isFilter('grade', null).isFilter('class_id', null);
      }

      final pathsResponse = await query.order('sort_order');
      final paths = <_ScopeLearningPathData>[];

      for (final pathRow in pathsResponse) {
        final pathId = pathRow['id'] as String;

        // Load units for this learning path
        final unitsResponse = await supabase
            .from(DbTables.scopeLearningPathUnits)
            .select(
                'id, unit_id, sort_order, tile_theme_id, vocabulary_units(id, name, icon, color)')
            .eq('scope_learning_path_id', pathId)
            .order('sort_order');

        final units = <LearningPathUnitData>[];

        for (final unitRow in unitsResponse) {
          final unitData =
              unitRow['vocabulary_units'] as Map<String, dynamic>? ?? {};
          final scopeUnitId = unitRow['id'] as String;

          // Load items for this unit
          final itemsResponse = await supabase
              .from(DbTables.scopeUnitItems)
              .select(
                  'id, item_type, word_list_id, book_id, sort_order, '
                  'word_lists(id, name, word_count), '
                  'books(id, title, level, chapter_count)')
              .eq('scope_lp_unit_id', scopeUnitId)
              .order('sort_order');

          final items = <LearningPathItemData>[];

          for (final itemRow in itemsResponse) {
            final itemType = itemRow['item_type'] as String;
            final isWordList =
                itemType == LearningPathItemType.wordList.dbValue;
            final isBook = itemType == LearningPathItemType.book.dbValue;

            String itemId;
            String itemName;
            String? subtitle;

            if (isWordList) {
              final wlData =
                  itemRow['word_lists'] as Map<String, dynamic>? ?? {};
              itemId = itemRow['word_list_id'] as String;
              itemName = wlData['name'] as String? ?? '';
              subtitle = '${wlData['word_count'] ?? 0} kelime';
            } else if (isBook) {
              final bookData =
                  itemRow['books'] as Map<String, dynamic>? ?? {};
              itemId = itemRow['book_id'] as String;
              itemName = bookData['title'] as String? ?? '';
              subtitle =
                  '${bookData['level'] ?? '-'} \u00b7 ${bookData['chapter_count'] ?? 0} b\u00f6l\u00fcm';
            } else {
              // game or treasure — no FK references
              itemId = itemRow['id'] as String;
              itemName = itemType == LearningPathItemType.game.dbValue
                  ? 'Oyun'
                  : 'Hazine';
              subtitle = null;
            }

            items.add(LearningPathItemData(
              id: itemRow['id'] as String?,
              itemType: itemType,
              itemId: itemId,
              itemName: itemName,
              subtitle: subtitle,
              sortOrder: itemRow['sort_order'] as int? ?? 0,
            ));
          }

          units.add(LearningPathUnitData(
            id: unitRow['id'] as String?,
            unitId: unitRow['unit_id'] as String,
            unitName: unitData['name'] as String? ?? '',
            unitIcon: unitData['icon'] as String?,
            unitColor: unitData['color'] as String?,
            tileThemeId: unitRow['tile_theme_id'] as String?,
            sortOrder: unitRow['sort_order'] as int? ?? 0,
            items: items,
          ));
        }

        paths.add(_ScopeLearningPathData(
          id: pathId,
          name: pathRow['name'] as String? ?? '',
          templateId: pathRow['template_id'] as String?,
          sortOrder: pathRow['sort_order'] as int? ?? 0,
          units: units,
          sequentialLock: pathRow['sequential_lock'] as bool? ?? true,
          booksExemptFromLock: pathRow['books_exempt_from_lock'] as bool? ?? true,
          unitGate: pathRow['unit_gate'] as bool? ?? true,
        ));
      }

      if (mounted) {
        setState(() {
          _learningPaths = paths;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ============================================
  // APPLY TEMPLATE
  // ============================================

  Future<void> _showApplyTemplateDialog() async {
    final templatesAsync = ref.read(_allTemplatesProvider);

    final templates = templatesAsync.valueOrNull;
    if (templates == null || templates.isEmpty) {
      // Force fetch if not loaded yet
      try {
        await ref.read(_allTemplatesProvider.future);
      } catch (_) {}
    }

    if (!mounted) return;

    final selectedTemplateId = await showDialog<String>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final asyncTemplates = ref.watch(_allTemplatesProvider);

          return AlertDialog(
            title: const Text('\u015eablondan Ekle'),
            content: SizedBox(
              width: 500,
              height: 400,
              child: asyncTemplates.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
                data: (templateList) {
                  if (templateList.isEmpty) {
                    return const Center(
                      child: Text('Hen\u00fcz \u015fablon olu\u015fturulmam\u0131\u015f'),
                    );
                  }

                  return ListView.builder(
                    itemCount: templateList.length,
                    itemBuilder: (context, index) {
                      final t = templateList[index];
                      return ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(t['name'] as String? ?? ''),
                        subtitle: t['description'] != null
                            ? Text(
                                t['description'] as String,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                        onTap: () =>
                            Navigator.pop(ctx, t['id'] as String),
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('\u0130ptal'),
              ),
            ],
          );
        },
      ),
    );

    if (selectedTemplateId == null || !mounted) return;

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final userId = supabase.auth.currentUser?.id;

      await supabase.rpc(RpcFunctions.applyLearningPathTemplate, params: {
        'p_template_id': selectedTemplateId,
        'p_school_id': _schoolId,
        'p_grade':
            _scopeType == _ScopeType.grade ? _selectedGrade : null,
        'p_class_id':
            _scopeType == _ScopeType.classSpecific ? _selectedClassId : null,
        'p_user_id': userId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('\u015eablon ba\u015far\u0131yla uyguland\u0131!')),
        );
        await _loadScopeAssignments();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ============================================
  // ADD EMPTY LEARNING PATH
  // ============================================

  Future<void> _showAddEmptyPathDialog() async {
    final nameController = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bo\u015f \u00d6\u011frenme Yolu Ekle'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Ad *',
            hintText: '\u00f6r. 5. S\u0131n\u0131f Ek M\u00fcfredat',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(ctx, value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('\u0130ptal'),
          ),
          FilledButton(
            onPressed: () {
              final text = nameController.text.trim();
              if (text.isNotEmpty) Navigator.pop(ctx, text);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );

    nameController.dispose();

    if (name == null || name.isEmpty || !mounted) return;

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final userId = supabase.auth.currentUser?.id;

      // Calculate next sort_order
      final nextSortOrder = _learningPaths.isEmpty
          ? 0
          : _learningPaths
                  .map((p) => p.sortOrder)
                  .reduce((a, b) => a > b ? a : b) +
              1;

      final row = <String, dynamic>{
        'id': const Uuid().v4(),
        'name': name,
        'school_id': _schoolId,
        'sort_order': nextSortOrder,
        'created_by': userId,
      };

      if (_scopeType == _ScopeType.grade) {
        row['grade'] = _selectedGrade;
      } else if (_scopeType == _ScopeType.classSpecific) {
        row['class_id'] = _selectedClassId;
      }

      await supabase.from(DbTables.scopeLearningPaths).insert(row);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('\u00d6\u011frenme yolu olu\u015fturuldu!')),
        );
        await _loadScopeAssignments();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ============================================
  // SAVE LEARNING PATH (per-path, on tree change)
  // ============================================

  Future<void> _saveLearningPath(int pathIndex) async {
    final path = _learningPaths[pathIndex];
    if (path.id == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final pathId = path.id!;

      // ── 1. Fetch existing state from DB ──
      final existingUnitsResponse = await supabase
          .from(DbTables.scopeLearningPathUnits)
          .select('id')
          .eq('scope_learning_path_id', pathId);
      final existingUnitIds =
          existingUnitsResponse.map((r) => r['id'] as String).toSet();

      final existingItemsByUnit = <String, Set<String>>{};
      if (existingUnitIds.isNotEmpty) {
        final existingItemsResponse = await supabase
            .from(DbTables.scopeUnitItems)
            .select('id, scope_lp_unit_id')
            .inFilter('scope_lp_unit_id', existingUnitIds.toList());
        for (final item in existingItemsResponse) {
          final unitId = item['scope_lp_unit_id'] as String;
          existingItemsByUnit
              .putIfAbsent(unitId, () => <String>{})
              .add(item['id'] as String);
        }
      }

      // ── 2. Process units + items: INSERT new, UPDATE existing ──
      final memoryUnitIds = <String>{};

      for (int i = 0; i < path.units.length; i++) {
        final unit = path.units[i];

        if (unit.id == null) {
          // NEW unit → INSERT
          final newUnitId = const Uuid().v4();
          await supabase.from(DbTables.scopeLearningPathUnits).insert({
            'id': newUnitId,
            'scope_learning_path_id': pathId,
            'unit_id': unit.unitId,
            'sort_order': i,
            'tile_theme_id': unit.tileThemeId,
          });
          unit.id = newUnitId;
          memoryUnitIds.add(newUnitId);

          // All items in a new unit are new → INSERT all
          for (int j = 0; j < unit.items.length; j++) {
            final item = unit.items[j];
            final newItemId = const Uuid().v4();
            final isWordList =
                item.itemType == LearningPathItemType.wordList.dbValue;
            final isBook =
                item.itemType == LearningPathItemType.book.dbValue;

            await supabase.from(DbTables.scopeUnitItems).insert({
              'id': newItemId,
              'scope_lp_unit_id': newUnitId,
              'item_type': item.itemType,
              'word_list_id': isWordList ? item.itemId : null,
              'book_id': isBook ? item.itemId : null,
              'sort_order': j,
            });
            item.id = newItemId;
          }
        } else {
          // EXISTING unit → UPDATE sort_order + tile_theme_id
          memoryUnitIds.add(unit.id!);
          await supabase
              .from(DbTables.scopeLearningPathUnits)
              .update({'sort_order': i, 'tile_theme_id': unit.tileThemeId})
              .eq('id', unit.id!);

          // Process items within this existing unit
          final existingItemIds = existingItemsByUnit[unit.id!] ?? {};
          final memoryItemIds = <String>{};

          for (int j = 0; j < unit.items.length; j++) {
            final item = unit.items[j];

            if (item.id == null) {
              // NEW item → INSERT
              final newItemId = const Uuid().v4();
              final isWordList =
                  item.itemType == LearningPathItemType.wordList.dbValue;
              final isBook =
                  item.itemType == LearningPathItemType.book.dbValue;

              await supabase.from(DbTables.scopeUnitItems).insert({
                'id': newItemId,
                'scope_lp_unit_id': unit.id!,
                'item_type': item.itemType,
                'word_list_id': isWordList ? item.itemId : null,
                'book_id': isBook ? item.itemId : null,
                'sort_order': j,
              });
              item.id = newItemId;
            } else {
              // EXISTING item → UPDATE sort_order
              memoryItemIds.add(item.id!);
              await supabase
                  .from(DbTables.scopeUnitItems)
                  .update({'sort_order': j})
                  .eq('id', item.id!);
            }
          }

          // DELETE removed items (items in DB but not in memory)
          final deletedItemIds = existingItemIds.difference(memoryItemIds);
          for (final itemId in deletedItemIds) {
            await supabase
                .from(DbTables.scopeUnitItems)
                .delete()
                .eq('id', itemId);
          }
        }
      }

      // ── 3. DELETE removed units (with assignment check) ──
      final deletedUnitIds = existingUnitIds.difference(memoryUnitIds);

      if (deletedUnitIds.isNotEmpty) {
        // Check for active assignments referencing any deleted unit
        final unitAssignments = await supabase
            .from(DbTables.assignments)
            .select('id, content_config')
            .eq('assignment_type', AssignmentType.unit.dbValue);

        final affectedCount = unitAssignments.where((a) {
          final config = a['content_config'] as Map<String, dynamic>?;
          return config != null &&
              deletedUnitIds.contains(config['scopeLpUnitId']);
        }).length;

        if (affectedCount > 0 && mounted) {
          final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Dikkat'),
                  content: Text(
                    'Silinen ünitelere bağlı $affectedCount aktif ödev var. '
                    'Devam ederseniz bu ödevler yetim kalır.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('İptal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Devam',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ) ??
              false;

          if (!confirmed) {
            // Admin cancelled — reload to restore deleted units
            await _loadScopeAssignments();
            return;
          }
        }

        for (final unitId in deletedUnitIds) {
          await supabase
              .from(DbTables.scopeLearningPathUnits)
              .delete()
              .eq('id', unitId);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${path.name}" kaydedildi'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Kaydetme hatası: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ============================================
  // UPDATE LOCK SETTINGS
  // ============================================

  Future<void> _updateLockSettings(_ScopeLearningPathData lp) async {
    if (lp.id == null) return;
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from(DbTables.scopeLearningPaths)
          .update({
            'sequential_lock': lp.sequentialLock,
            'books_exempt_from_lock': lp.booksExemptFromLock,
            'unit_gate': lp.unitGate,
          })
          .eq('id', lp.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kilit ayarları güncellendi'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ============================================
  // DELETE LEARNING PATH
  // ============================================

  Future<void> _deleteLearningPath(int pathIndex) async {
    final path = _learningPaths[pathIndex];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('\u00d6\u011frenme Yolunu Sil'),
        content: Text(
          '"${path.name}" \u00f6\u011frenme yolu ve t\u00fcm i\u00e7eri\u011fi kal\u0131c\u0131 olarak silinecektir. '
          'Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('\u0130ptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from(DbTables.scopeLearningPaths)
          .delete()
          .eq('id', path.id!);

      if (mounted) {
        setState(() {
          _learningPaths.removeAt(pathIndex);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${path.name}" silindi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ============================================
  // BUILD
  // ============================================

  @override
  Widget build(BuildContext context) {
    final schoolsAsync = ref.watch(allSchoolsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/learning-paths'),
        ),
        title: const Text('Yeni Öğrenme Yolu Ataması'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Scope Selection ---
            _buildScopeSection(context, schoolsAsync),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // --- Learning Paths ---
            _buildLearningPathsSection(context),
          ],
        ),
      ),
    );
  }

  // ============================================
  // SCOPE SELECTION SECTION
  // ============================================

  Widget _buildScopeSection(
    BuildContext context,
    AsyncValue<List<Map<String, dynamic>>> schoolsAsync,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kapsam Se\u00e7imi',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '\u00d6\u011frenme yollar\u0131n\u0131n hangi \u00f6\u011frencilere g\u00f6r\u00fcnece\u011fini belirleyin.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),

            // School dropdown
            schoolsAsync.when(
              data: (schools) => DropdownButtonFormField<String?>(
                value: _schoolId,
                decoration: const InputDecoration(
                  labelText: 'Okul *',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Okul se\u00e7in'),
                  ),
                  ...schools.map((school) => DropdownMenuItem(
                        value: school['id'] as String,
                        child: Text(school['name'] as String),
                      )),
                ],
                onChanged: (value) {
                  setState(() {
                    _schoolId = value;
                    _selectedClassId = null;
                    _selectedGrade = null;
                    _learningPaths = [];
                  });
                  if (value != null && _scopeType == _ScopeType.school) {
                    _loadScopeAssignments();
                  }
                },
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Okullar y\u00fcklenirken hata'),
            ),
            const SizedBox(height: 24),

            // Scope type radio buttons
            Text('Hedef', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _ScopeRadio(
              value: _ScopeType.school,
              groupValue: _scopeType,
              label: 'T\u00fcm Okul',
              description: 'Okuldaki t\u00fcm \u00f6\u011frenciler',
              onChanged: (v) {
                setState(() {
                  _scopeType = v!;
                  _selectedGrade = null;
                  _selectedClassId = null;
                  _learningPaths = [];
                });
                if (_schoolId != null) _loadScopeAssignments();
              },
            ),
            _ScopeRadio(
              value: _ScopeType.grade,
              groupValue: _scopeType,
              label: 'S\u0131n\u0131f',
              description: 'Belirli bir s\u0131n\u0131f\u0131n t\u00fcm \u015fubeleri',
              onChanged: (v) {
                setState(() {
                  _scopeType = v!;
                  _selectedClassId = null;
                  _learningPaths = [];
                });
              },
            ),
            _ScopeRadio(
              value: _ScopeType.classSpecific,
              groupValue: _scopeType,
              label: '\u015eube',
              description: 'Sadece belirli bir \u015fube',
              onChanged: (v) {
                setState(() {
                  _scopeType = v!;
                  _selectedGrade = null;
                  _learningPaths = [];
                });
              },
            ),
            const SizedBox(height: 16),

            // Grade selector
            if (_scopeType == _ScopeType.grade)
              DropdownButtonFormField<int?>(
                value: _selectedGrade,
                decoration: const InputDecoration(
                  labelText: 'S\u0131n\u0131f *',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('S\u0131n\u0131f se\u00e7in'),
                  ),
                  for (int i = 1; i <= 12; i++)
                    DropdownMenuItem(value: i, child: Text('$i. S\u0131n\u0131f')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedGrade = value;
                    _learningPaths = [];
                  });
                  if (value != null && _schoolId != null) {
                    _loadScopeAssignments();
                  }
                },
              ),

            // Class selector
            if (_scopeType == _ScopeType.classSpecific && _schoolId != null)
              ref.watch(_schoolClassesProvider(_schoolId!)).when(
                    data: (classes) => DropdownButtonFormField<String?>(
                      value: _selectedClassId,
                      decoration: const InputDecoration(
                        labelText: '\u015eube *',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('\u015eube se\u00e7in'),
                        ),
                        ...classes.map((cls) => DropdownMenuItem(
                              value: cls['id'] as String,
                              child: Text(
                                '${cls['name']} (${cls['grade'] ?? '?'}. S\u0131n\u0131f)',
                              ),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedClassId = value;
                          _learningPaths = [];
                        });
                        if (value != null) _loadScopeAssignments();
                      },
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) =>
                        const Text('\u015eubeler y\u00fcklenirken hata'),
                  ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // LEARNING PATHS SECTION
  // ============================================

  Widget _buildLearningPathsSection(BuildContext context) {
    // Show loading indicator while fetching
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show prompt if scope is not yet selected
    if (!_isScopeComplete) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            children: [
              Icon(Icons.account_tree_outlined,
                  size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                '\u00d6\u011frenme yollar\u0131n\u0131 g\u00f6rmek i\u00e7in kapsam se\u00e7in',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '\u00d6\u011frenme Yollar\u0131 (${_learningPaths.length})',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),

        // Empty state
        if (_learningPaths.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.account_tree_outlined,
                      size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'Bu kapsam i\u00e7in hen\u00fcz \u00f6\u011frenme yolu atanmam\u0131\u015f',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Learning path cards
        for (int i = 0; i < _learningPaths.length; i++) ...[
          _buildLearningPathCard(context, i),
          const SizedBox(height: 16),
        ],

        // Add buttons row
        const SizedBox(height: 8),
        _buildAddButtonsRow(),
      ],
    );
  }

  // ============================================
  // LEARNING PATH CARD
  // ============================================

  Widget _buildLearningPathCard(BuildContext context, int pathIndex) {
    final path = _learningPaths[pathIndex];
    final theme = Theme.of(context);

    // Pick a color based on index for visual variety
    final colors = [
      Colors.blue,
      Colors.teal,
      Colors.purple,
      Colors.orange,
      Colors.indigo,
      Colors.pink,
    ];
    final accentColor = colors[pathIndex % colors.length];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with colored bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accentColor.withAlpha(25),
              border: Border(
                left: BorderSide(color: accentColor, width: 4),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.account_tree, color: accentColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        path.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (path.templateId != null)
                        Text(
                          '\u015eablondan olu\u015fturuldu',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _isSaving ? null : () => _deleteLearningPath(pathIndex),
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.red),
                  label: const Text('Sil',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),

          // Tree view
          Padding(
            padding: const EdgeInsets.all(16),
            child: LearningPathTreeView(
              units: path.units,
              onUnitsChanged: (updatedUnits) {
                setState(() {
                  _learningPaths[pathIndex].units = updatedUnits;
                });
                _saveDebounceTimer?.cancel();
                _saveDebounceTimer = Timer(
                  const Duration(milliseconds: 500),
                  () => _saveLearningPath(pathIndex),
                );
              },
              showWordPreview: false,
            ),
          ),

          // Lock settings
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Sıralı ilerleme'),
            subtitle: const Text('Önceki tamamlanmadan sonraki açılmaz'),
            value: path.sequentialLock,
            onChanged: (v) {
              setState(() {
                _learningPaths[pathIndex].sequentialLock = v;
                if (!v) _learningPaths[pathIndex].booksExemptFromLock = true;
              });
              _updateLockSettings(_learningPaths[pathIndex]);
            },
          ),
          if (path.sequentialLock)
            SwitchListTile(
              title: const Text('Kitapları hariç tut'),
              subtitle: const Text('Kitaplar her zaman erişilebilir'),
              value: path.booksExemptFromLock,
              onChanged: (v) {
                setState(() => _learningPaths[pathIndex].booksExemptFromLock = v);
                _updateLockSettings(_learningPaths[pathIndex]);
              },
            ),
          SwitchListTile(
            title: const Text('Üniteler arası kilit'),
            subtitle: const Text('Önceki ünite bitmeden sonraki açılmaz'),
            value: path.unitGate,
            onChanged: (v) {
              setState(() => _learningPaths[pathIndex].unitGate = v);
              _updateLockSettings(_learningPaths[pathIndex]);
            },
          ),
        ],
      ),
    );
  }

  // ============================================
  // ADD BUTTONS ROW
  // ============================================

  Widget _buildAddButtonsRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed:
              (_isScopeComplete && !_isSaving) ? _showApplyTemplateDialog : null,
          icon: const Icon(Icons.description_outlined),
          label: const Text('\u015eablondan Ekle'),
        ),
        OutlinedButton.icon(
          onPressed:
              (_isScopeComplete && !_isSaving) ? _showAddEmptyPathDialog : null,
          icon: const Icon(Icons.add),
          label: const Text('Bo\u015f \u00d6\u011frenme Yolu Ekle'),
        ),
      ],
    );
  }
}

// ============================================
// SCOPE RADIO
// ============================================

class _ScopeRadio extends StatelessWidget {
  const _ScopeRadio({
    required this.value,
    required this.groupValue,
    required this.label,
    required this.description,
    required this.onChanged,
  });

  final _ScopeType value;
  final _ScopeType groupValue;
  final String label;
  final String description;
  final ValueChanged<_ScopeType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<_ScopeType>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      title: Text(label),
      subtitle: Text(
        description,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
