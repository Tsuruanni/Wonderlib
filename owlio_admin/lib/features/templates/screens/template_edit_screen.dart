import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import '../../../core/widgets/learning_path_tree_view.dart';
import 'template_list_screen.dart'; // for templatesProvider

// ============================================
// SCREEN
// ============================================

class TemplateEditScreen extends ConsumerStatefulWidget {
  const TemplateEditScreen({super.key, this.templateId});
  final String? templateId;

  @override
  ConsumerState<TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends ConsumerState<TemplateEditScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<LearningPathUnitData> _units = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _sequentialLock = true;
  bool _booksExemptFromLock = true;

  bool get _isNew => widget.templateId == null;

  @override
  void initState() {
    super.initState();
    if (!_isNew) {
      _loadTemplate();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ============================================
  // LOAD
  // ============================================

  Future<void> _loadTemplate() async {
    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      // 1. Fetch template
      final template = await supabase
          .from(DbTables.learningPathTemplates)
          .select('*')
          .eq('id', widget.templateId!)
          .single();

      _nameController.text = template['name'] as String? ?? '';
      _descriptionController.text = template['description'] as String? ?? '';
      _sequentialLock = template['sequential_lock'] as bool? ?? true;
      _booksExemptFromLock = template['books_exempt_from_lock'] as bool? ?? true;

      // 2. Fetch template units
      final unitsResponse = await supabase
          .from(DbTables.learningPathTemplateUnits)
          .select(
              'id, unit_id, sort_order, vocabulary_units(id, name, icon, color)')
          .eq('template_id', widget.templateId!)
          .order('sort_order', ascending: true);

      final units = <LearningPathUnitData>[];

      for (final unitRow in unitsResponse) {
        final unitData =
            unitRow['vocabulary_units'] as Map<String, dynamic>? ?? {};
        final templateUnitId = unitRow['id'] as String;

        // 3. Fetch items for this unit
        final itemsResponse = await supabase
            .from(DbTables.learningPathTemplateItems)
            .select(
                'id, item_type, word_list_id, book_id, sort_order, '
                'word_lists(id, name, word_count), '
                'books(id, title, level, chapter_count)')
            .eq('template_unit_id', templateUnitId)
            .order('sort_order', ascending: true);

        final items = <LearningPathItemData>[];

        for (final itemRow in itemsResponse) {
          final itemType = itemRow['item_type'] as String;
          final isWordList =
              itemType == LearningPathItemType.wordList.dbValue;

          String itemId;
          String itemName;
          String? subtitle;
          List<String>? words;

          if (isWordList) {
            final wlData =
                itemRow['word_lists'] as Map<String, dynamic>? ?? {};
            itemId = itemRow['word_list_id'] as String;
            itemName = wlData['name'] as String? ?? '';
            subtitle = '${wlData['word_count'] ?? 0} kelime';

            // 4. Fetch word preview
            try {
              final wordPreview = await supabase
                  .from(DbTables.wordListItems)
                  .select('vocabulary_words(word)')
                  .eq('word_list_id', itemId)
                  .order('order_index')
                  .limit(10);
              words = wordPreview
                  .map((row) {
                    final vw =
                        row['vocabulary_words'] as Map<String, dynamic>?;
                    return vw?['word'] as String? ?? '';
                  })
                  .where((w) => w.isNotEmpty)
                  .toList();
            } catch (_) {
              // Word preview is optional, ignore errors
            }
          } else if (itemType == LearningPathItemType.book.dbValue) {
            final bookData =
                itemRow['books'] as Map<String, dynamic>? ?? {};
            itemId = itemRow['book_id'] as String;
            itemName = bookData['title'] as String? ?? '';
            subtitle =
                '${bookData['level'] ?? '-'} · ${bookData['chapter_count'] ?? 0} bölüm';
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
            words: words,
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

      if (mounted) {
        setState(() {
          _units = units;
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
  // SAVE
  // ============================================

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şablon adı zorunludur'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final description = _descriptionController.text.trim();

      String templateId;

      if (_isNew) {
        // INSERT new template
        templateId = const Uuid().v4();
        await supabase.from(DbTables.learningPathTemplates).insert({
          'id': templateId,
          'name': name,
          'description': description.isEmpty ? null : description,
          'sequential_lock': _sequentialLock,
          'books_exempt_from_lock': _booksExemptFromLock,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        templateId = widget.templateId!;
        // UPDATE existing template
        await supabase
            .from(DbTables.learningPathTemplates)
            .update({
              'name': name,
              'description': description.isEmpty ? null : description,
              'sequential_lock': _sequentialLock,
              'books_exempt_from_lock': _booksExemptFromLock,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', templateId);
      }

      // Delete all existing units (cascade deletes items)
      await supabase
          .from(DbTables.learningPathTemplateUnits)
          .delete()
          .eq('template_id', templateId);

      // Re-insert all units with sort_order
      for (int i = 0; i < _units.length; i++) {
        final unit = _units[i];
        final templateUnitId = const Uuid().v4();

        await supabase.from(DbTables.learningPathTemplateUnits).insert({
          'id': templateUnitId,
          'template_id': templateId,
          'unit_id': unit.unitId,
          'sort_order': i,
          'tile_theme_id': unit.tileThemeId,
        });

        // Insert items for this unit
        for (int j = 0; j < unit.items.length; j++) {
          final item = unit.items[j];
          final isWordList =
              item.itemType == LearningPathItemType.wordList.dbValue;
          final isBook = item.itemType == LearningPathItemType.book.dbValue;

          await supabase.from(DbTables.learningPathTemplateItems).insert({
            'id': const Uuid().v4(),
            'template_unit_id': templateUnitId,
            'item_type': item.itemType,
            'word_list_id': isWordList ? item.itemId : null,
            'book_id': isBook ? item.itemId : null,
            'sort_order': j,
          });
        }
      }

      ref.invalidate(templatesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(_isNew ? 'Şablon oluşturuldu!' : 'Şablon güncellendi!'),
          ),
        );
        context.go('/learning-paths');
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
  // DELETE
  // ============================================

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Şablonu Sil'),
        content: const Text(
          'Bu şablon kalıcı olarak silinecektir. '
          'Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from(DbTables.learningPathTemplates)
          .delete()
          .eq('id', widget.templateId!);

      ref.invalidate(templatesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şablon silindi')),
        );
        context.go('/learning-paths');
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
  // BUILD
  // ============================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Şablon Düzenle'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/learning-paths'),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/learning-paths'),
        ),
        title: Text(
          _isNew
              ? 'Yeni Şablon'
              : (_nameController.text.isNotEmpty
                  ? _nameController.text
                  : 'Şablon Düzenle'),
        ),
        actions: [
          if (!_isNew)
            TextButton.icon(
              onPressed: _isSaving ? null : _handleDelete,
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text('Sil', style: TextStyle(color: Colors.red)),
            ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Template info section
            Text(
              'Şablon Bilgileri',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Ad *',
                hintText: 'ör. 5. Sınıf Standart Müfredat',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Açıklama',
                hintText: 'İsteğe bağlı açıklama',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Text('İlerleme Ayarları', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Sıralı ilerleme'),
              subtitle: const Text('Önceki tamamlanmadan sonraki açılmaz'),
              value: _sequentialLock,
              onChanged: (v) => setState(() {
                _sequentialLock = v;
                if (!v) _booksExemptFromLock = true;
              }),
            ),
            if (_sequentialLock)
              SwitchListTile(
                title: const Text('Kitapları hariç tut'),
                subtitle: const Text('Kitaplar her zaman erişilebilir'),
                value: _booksExemptFromLock,
                onChanged: (v) => setState(() => _booksExemptFromLock = v),
              ),
            const SizedBox(height: 32),

            // Content section
            Text(
              'İçerik',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            LearningPathTreeView(
              units: _units,
              onUnitsChanged: (units) => setState(() => _units = units),
              showWordPreview: true,
            ),
          ],
        ),
      ),
    );
  }
}
