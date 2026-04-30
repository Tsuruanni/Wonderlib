import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import 'activity_editor.dart';

/// Provider for loading content blocks for a chapter
final contentBlocksProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, chapterId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.contentBlocks)
      .select()
      .eq('chapter_id', chapterId)
      .order('order_index', ascending: true);

  return List<Map<String, dynamic>>.from(response);
});

class ContentBlockEditor extends ConsumerWidget {
  const ContentBlockEditor({
    super.key,
    required this.chapterId,
    required this.onRefresh,
  });

  final String chapterId;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocksAsync = ref.watch(contentBlocksProvider(chapterId));

    return blocksAsync.when(
      data: (blocks) => _ContentBlockList(
        chapterId: chapterId,
        blocks: blocks,
        onRefresh: () async {
          ref.invalidate(contentBlocksProvider(chapterId));
          onRefresh();
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }
}

class _ContentBlockList extends ConsumerStatefulWidget {
  const _ContentBlockList({
    required this.chapterId,
    required this.blocks,
    required this.onRefresh,
  });

  final String chapterId;
  final List<Map<String, dynamic>> blocks;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_ContentBlockList> createState() => _ContentBlockListState();
}

/// Add-block menu items. Listed in one place so the PopupMenuButton entries
/// and the activity sub-section share a single source of truth.
const _kBlockTypes = [
  ('text', Icons.text_fields, 'Metin', null),
  ('image', Icons.image, 'Görsel', null),
];

const _kActivityTypes = [
  ('true_false', Icons.check_circle_outline, 'True / False'),
  ('word_translation', Icons.translate, 'Word Translation'),
  ('find_words', Icons.checklist, 'Find Words (çoklu seçim)'),
  ('matching', Icons.compare_arrows, 'Matching'),
];

class _ContentBlockListState extends ConsumerState<_ContentBlockList> {
  late List<Map<String, dynamic>> _localBlocks;
  bool _isGeneratingChapterAudio = false;
  // Preserve activity type metadata across DB refreshes (blockId → activityType)
  final Map<String, String> _blockActivityTypes = {};

  @override
  void initState() {
    super.initState();
    _localBlocks = List.from(widget.blocks);
  }

  @override
  void didUpdateWidget(covariant _ContentBlockList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.blocks != oldWidget.blocks) {
      // Re-inject local-only _activityType metadata after DB refresh
      _localBlocks = widget.blocks.map((block) {
        final blockId = block['id'] as String?;
        final activityType = blockId != null ? _blockActivityTypes[blockId] : null;
        if (activityType != null && block['type'] == 'activity') {
          return {...block, '_activityType': activityType};
        }
        return Map<String, dynamic>.from(block);
      }).toList();
    }
  }

  // Bulk-select state — toggle-into-selection-mode pattern (mirrors vocab list).
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seçili Blokları Sil'),
        content: Text(
          '$count blok kalıcı olarak silinecek. '
          'İlişkili inline aktiviteler de kaldırılacak. '
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final supabase = ref.read(supabaseClientProvider);
    final idsToDelete = _selectedIds.toList();
    final activityIds = _localBlocks
        .where((b) => idsToDelete.contains(b['id']))
        .map((b) => b['activity_id'] as String?)
        .whereType<String>()
        .toList();

    setState(() {
      _localBlocks =
          _localBlocks.where((b) => !idsToDelete.contains(b['id'])).toList();
    });

    try {
      await supabase
          .from(DbTables.contentBlocks)
          .delete()
          .inFilter('id', idsToDelete);
      if (activityIds.isNotEmpty) {
        await supabase
            .from(DbTables.inlineActivities)
            .delete()
            .inFilter('id', activityIds);
      }
      _exitSelectionMode();
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count blok silindi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Toplu silme başarısız: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Duplicates a single block. Inserts a new content_blocks row right after
  /// the source. If the source has an inline_activity, that activity is also
  /// cloned and linked to the new block.
  Future<void> _duplicateBlock(Map<String, dynamic> source) async {
    final supabase = ref.read(supabaseClientProvider);
    final sourceOrder = source['order_index'] as int? ?? 0;

    // Shift everything after sourceOrder down by 1, then insert at sourceOrder+1.
    setState(() {
      _localBlocks = _localBlocks.map((b) {
        final idx = b['id'] == source['id']
            ? sourceOrder
            : (b['order_index'] as int? ?? 0);
        if (idx > sourceOrder) {
          return {...b, 'order_index': idx + 1};
        }
        return b;
      }).toList();
    });

    try {
      // Bump existing rows that were after the source
      for (final b in _localBlocks) {
        if (b['id'] == source['id']) continue;
        final idx = b['order_index'] as int? ?? 0;
        if (idx > sourceOrder + 1) {
          await supabase
              .from(DbTables.contentBlocks)
              .update({'order_index': idx})
              .eq('id', b['id'] as String);
        }
      }

      // Optionally clone activity
      String? newActivityId;
      final sourceActivityId = source['activity_id'] as String?;
      if (sourceActivityId != null) {
        final original = await supabase
            .from(DbTables.inlineActivities)
            .select()
            .eq('id', sourceActivityId)
            .maybeSingle();
        if (original != null) {
          newActivityId = const Uuid().v4();
          final clone = Map<String, dynamic>.from(original);
          clone['id'] = newActivityId;
          clone.remove('created_at');
          clone.remove('updated_at');
          await supabase.from(DbTables.inlineActivities).insert(clone);
        }
      }

      // Insert duplicated block
      final newId = const Uuid().v4();
      final newBlock = <String, dynamic>{
        'id': newId,
        'chapter_id': widget.chapterId,
        'order_index': sourceOrder + 1,
        'type': source['type'],
        'text': source['text'],
        'audio_url': null, // audio is per-block, don't copy stale URL
        'word_timings': [],
        'audio_start_ms': null,
        'audio_end_ms': null,
        'image_url': source['image_url'],
        'caption': source['caption'],
        'activity_id': newActivityId,
      };
      await supabase.from(DbTables.contentBlocks).insert(newBlock);

      setState(() {
        _localBlocks = [..._localBlocks, newBlock]
          ..sort((a, b) => (a['order_index'] as int)
              .compareTo(b['order_index'] as int));
      });
      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blok kopyalandı')),
        );
      }
    } catch (e) {
      // Rollback local state on failure
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kopyalama başarısız: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addBlock(String type, {String? activityType}) async {
    final supabase = ref.read(supabaseClientProvider);

    int newOrderIndex = 0;
    if (_localBlocks.isNotEmpty) {
      int maxIndex = 0;
      for (final block in _localBlocks) {
        final idx = block['order_index'] as int? ?? 0;
        if (idx > maxIndex) maxIndex = idx;
      }
      newOrderIndex = maxIndex + 1;
    }

    final newBlockId = const Uuid().v4();

    // DB payload — only real columns
    final insertData = {
      'id': newBlockId,
      'chapter_id': widget.chapterId,
      'order_index': newOrderIndex,
      'type': type,
    };

    // Local copy — includes UI-only metadata (NOT sent to DB)
    final localBlock = {
      ...insertData,
      if (activityType != null) '_activityType': activityType,
    };

    // Persist activity type metadata so it survives DB refresh
    if (activityType != null) {
      _blockActivityTypes[newBlockId] = activityType;
    }

    setState(() {
      _localBlocks = [..._localBlocks, localBlock];
    });

    try {
      await supabase.from(DbTables.contentBlocks).insert(insertData);
      widget.onRefresh();
    } catch (e) {
      setState(() {
        _localBlocks = _localBlocks.where((b) => b['id'] != newBlockId).toList();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Blok eklenemedi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteBlock(String blockId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bloğu Sil'),
        content: const Text('Bu içerik bloğunu silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final deletedBlock = _localBlocks.where((b) => b['id'] == blockId).firstOrNull;
    if (deletedBlock == null) return;
    final activityId = deletedBlock['activity_id'] as String?;
    setState(() {
      _localBlocks = _localBlocks.where((b) => b['id'] != blockId).toList();
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from(DbTables.contentBlocks).delete().eq('id', blockId);
      // Also delete linked inline_activities row
      if (activityId != null) {
        await supabase.from(DbTables.inlineActivities).delete().eq('id', activityId);
      }
      widget.onRefresh();
    } catch (e) {
      setState(() {
        _localBlocks = [..._localBlocks, deletedBlock]..sort(
            (a, b) => (a['order_index'] as int).compareTo(b['order_index'] as int),
          );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Silme hatası: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _generateChapterAudio() async {
    final textBlocks = _localBlocks.where((b) => b['type'] == 'text').toList();
    if (textBlocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ses üretilecek metin bloğu yok'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final blocksWithText = textBlocks.where(
      (b) => (b['text'] as String?)?.isNotEmpty == true,
    ).toList();

    if (blocksWithText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tüm metin blokları boş. Önce içerik ekleyin.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isGeneratingChapterAudio = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase.functions.invoke(
        'generate-chapter-audio',
        body: {
          'chapterId': widget.chapterId,
          'voiceId': 'QngvLQR8bsLR5bzoa6Vv',
        },
      );

      if (response.status != 200) {
        throw Exception(response.data?['error'] ?? 'Ses üretme başarısız');
      }

      final blocksProcessed = response.data?['blocksProcessed'] ?? 0;
      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$blocksProcessed blok için ses üretildi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ses üretme hatası: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isGeneratingChapterAudio = false);
    }
  }

  Future<void> _reorderBlocks(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    if (newIndex > oldIndex) newIndex--;

    final originalBlocks = List<Map<String, dynamic>>.from(_localBlocks);
    final reorderedBlocks = List<Map<String, dynamic>>.from(_localBlocks);
    final movedBlock = reorderedBlocks.removeAt(oldIndex);
    reorderedBlocks.insert(newIndex, movedBlock);

    for (int i = 0; i < reorderedBlocks.length; i++) {
      reorderedBlocks[i] = {...reorderedBlocks[i], 'order_index': i};
    }

    setState(() {
      _localBlocks = reorderedBlocks;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      final updates = <Future>[];
      for (int i = 0; i < reorderedBlocks.length; i++) {
        updates.add(
          supabase
              .from(DbTables.contentBlocks)
              .update({'order_index': i})
              .eq('id', reorderedBlocks[i]['id']),
        );
      }
      await Future.wait(updates);
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        setState(() {
          _localBlocks = originalBlocks;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sıralama hatası: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar — switches between regular mode and selection mode.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isSelectionMode ? Colors.indigo.shade50 : null,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: _isSelectionMode
              ? _buildSelectionToolbar()
              : _buildRegularToolbar(),
        ),

        // Block list
        Expanded(
          child: _localBlocks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.view_agenda_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'Henüz içerik bloğu yok',
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Yukarıdaki butonlardan metin, görsel veya aktivite ekleyin',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _localBlocks.length,
                  onReorder: _reorderBlocks,
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        final elevation =
                            Tween<double>(begin: 0, end: 8).evaluate(animation);
                        return Material(
                          elevation: elevation,
                          borderRadius: BorderRadius.circular(12),
                          child: child,
                        );
                      },
                      child: child,
                    );
                  },
                  itemBuilder: (context, index) {
                    final block = _localBlocks[index];
                    final id = block['id'] as String;
                    return _BlockCard(
                      key: ValueKey(id),
                      block: block,
                      index: index,
                      chapterId: widget.chapterId,
                      onDelete: () => _deleteBlock(id),
                      onDuplicate: () => _duplicateBlock(block),
                      onRefresh: widget.onRefresh,
                      isSelectionMode: _isSelectionMode,
                      isSelected: _selectedIds.contains(id),
                      onToggleSelection: () => _toggleSelection(id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRegularToolbar() {
    return Row(
      children: [
        Text(
          'İçerik Blokları (${_localBlocks.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Spacer(),
        // Multi-select toggle
        if (_localBlocks.isNotEmpty) ...[
          OutlinedButton.icon(
            onPressed: _enterSelectionMode,
            icon: const Icon(Icons.checklist, size: 18),
            label: const Text('Seç'),
          ),
          const SizedBox(width: 8),
        ],
        // Generate chapter audio
        OutlinedButton.icon(
          onPressed:
              _isGeneratingChapterAudio ? null : _generateChapterAudio,
          icon: _isGeneratingChapterAudio
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.music_note, size: 18),
          label: Text(_isGeneratingChapterAudio
              ? 'Üretiliyor...'
              : 'Bölüm Sesi Üret'),
        ),
        const SizedBox(width: 12),
        // Single consolidated add-block menu
        PopupMenuButton<String>(
          tooltip: 'Yeni blok ekle',
          onSelected: (value) {
            if (value == 'text' || value == 'image') {
              _addBlock(value);
            } else {
              // value is an activity sub-type
              _addBlock('activity', activityType: value);
            }
          },
          itemBuilder: (context) => [
            for (final t in _kBlockTypes)
              PopupMenuItem(
                value: t.$1,
                child: ListTile(
                  leading: Icon(t.$2),
                  title: Text(t.$3),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              enabled: false,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'AKTİVİTE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            for (final a in _kActivityTypes)
              PopupMenuItem(
                value: a.$1,
                child: ListTile(
                  leading: Icon(a.$2),
                  title: Text(a.$3, style: const TextStyle(fontSize: 13)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
          ],
          child: IgnorePointer(
            child: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Blok Ekle'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionToolbar() {
    final n = _selectedIds.length;
    final allOnPage = _localBlocks.length;
    return Row(
      children: [
        Checkbox(
          tristate: true,
          value: n == 0
              ? false
              : (n == allOnPage ? true : null),
          onChanged: (_) {
            setState(() {
              if (n == allOnPage) {
                _selectedIds.clear();
              } else {
                _selectedIds.addAll(
                    _localBlocks.map((b) => b['id'] as String));
              }
            });
          },
        ),
        const SizedBox(width: 4),
        Text(
          n == 0
              ? '$allOnPage blok — seçim yapın'
              : '$n / $allOnPage seçili',
          style: TextStyle(
            color: Colors.indigo.shade900,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade600,
          ),
          onPressed: n == 0 ? null : _bulkDelete,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: Text(n == 0 ? 'Sil' : 'Sil ($n)'),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: _exitSelectionMode,
          icon: const Icon(Icons.close, size: 18),
          label: const Text('Çıkış'),
        ),
      ],
    );
  }
}

class _BlockCard extends ConsumerStatefulWidget {
  const _BlockCard({
    super.key,
    required this.block,
    required this.index,
    required this.chapterId,
    required this.onDelete,
    required this.onDuplicate,
    required this.onRefresh,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onToggleSelection,
  });

  final Map<String, dynamic> block;
  final int index;
  final String chapterId;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onRefresh;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onToggleSelection;

  @override
  ConsumerState<_BlockCard> createState() => _BlockCardState();
}

class _BlockCardState extends ConsumerState<_BlockCard> {
  final _textController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _captionController = TextEditingController();
  bool _isEditing = false;
  bool _isSaving = false;
  Map<String, dynamic>? _loadedActivity;
  Future<Map<String, dynamic>?>? _activityFuture;
  bool _cancelledNewActivity = false;

  @override
  void initState() {
    super.initState();
    _textController.text = widget.block['text'] ?? '';
    _imageUrlController.text = widget.block['image_url'] ?? '';
    _captionController.text = widget.block['caption'] ?? '';
  }

  @override
  void dispose() {
    _textController.dispose();
    _imageUrlController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _saveBlock() async {
    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final type = widget.block['type'] as String;

      final data = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (type == 'text') {
        data['text'] = _textController.text;
      } else if (type == 'image') {
        data['image_url'] = _imageUrlController.text;
        data['caption'] = _captionController.text;
      }

      await supabase
          .from(DbTables.contentBlocks)
          .update(data)
          .eq('id', widget.block['id']);

      setState(() => _isEditing = false);
      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blok kaydedildi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.block['type'] as String;
    final hasAudio = (widget.block['audio_url'] as String?)?.isNotEmpty ?? false;
    final hasText = (widget.block['text'] as String?)?.isNotEmpty ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      // Visually highlight selected card while in selection mode
      shape: widget.isSelected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.indigo, width: 2),
            )
          : null,
      child: InkWell(
        // In selection mode, tapping the card body toggles selection
        onTap: widget.isSelectionMode
            ? widget.onToggleSelection
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _getTypeColor(type).withValues(alpha: 0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  if (widget.isSelectionMode) ...[
                    Checkbox(
                      value: widget.isSelected,
                      onChanged: (_) => widget.onToggleSelection(),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Icon(_getTypeIcon(type),
                      size: 20, color: _getTypeColor(type)),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.index + 1}. ${_getTypeName(type)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getTypeColor(type),
                    ),
                  ),
                if (hasAudio) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.volume_up, size: 12, color: Colors.green),
                        SizedBox(width: 4),
                        Text('Ses', style: TextStyle(fontSize: 10, color: Colors.green)),
                      ],
                    ),
                  ),
                ],
                if (type == 'text' && !hasText && !_isEditing) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber, size: 12, color: Colors.orange),
                        SizedBox(width: 4),
                        Text('Boş', style: TextStyle(fontSize: 10, color: Colors.orange)),
                      ],
                    ),
                  ),
                ],
                if (type == 'activity' && (widget.block['activity_id'] as String?) == null && _cancelledNewActivity && !_isEditing) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber, size: 12, color: Colors.orange),
                        SizedBox(width: 4),
                        Text('Not configured', style: TextStyle(fontSize: 10, color: Colors.orange)),
                      ],
                    ),
                  ),
                ],
                  const Spacer(),
                  // Action buttons — hidden in selection mode (checkbox handles)
                  if (!widget.isSelectionMode) ...[
                    if (_isEditing && type != 'activity') ...[
                      TextButton(
                        onPressed: () =>
                            setState(() => _isEditing = false),
                        child: const Text('İptal'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _isSaving ? null : _saveBlock,
                        child: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Text('Kaydet'),
                      ),
                    ] else ...[
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        tooltip: 'Düzenle',
                        onPressed: () => setState(() {
                          _isEditing = true;
                          _cancelledNewActivity = false;
                        }),
                      ),
                      IconButton(
                        icon: const Icon(Icons.content_copy_outlined,
                            size: 18),
                        tooltip: 'Aşağıya kopyala',
                        onPressed: widget.onDuplicate,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18),
                        color: Colors.red,
                        tooltip: 'Sil',
                        onPressed: widget.onDelete,
                      ),
                      ReorderableDragStartListener(
                        index: widget.index,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.grab,
                          child: Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.grey.shade200
                                  .withValues(alpha: 0.6),
                            ),
                            child: Icon(Icons.drag_indicator,
                                size: 18, color: Colors.grey.shade700),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildContent(type),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(String type) {
    switch (type) {
      case 'text':
        if (_isEditing) {
          return TextField(
            controller: _textController,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Paragraf metnini girin...',
              border: OutlineInputBorder(),
            ),
          );
        }
        final text = widget.block['text'] as String?;
        if (text == null || text.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.edit_note, color: Colors.orange.shade300),
                const SizedBox(width: 12),
                Text(
                  'Metin içeriği boş — düzenle butonuna basarak içerik ekleyin',
                  style: TextStyle(color: Colors.orange.shade400, fontSize: 13),
                ),
              ],
            ),
          );
        }
        return Text(text);

      case 'image':
        if (_isEditing) {
          return Column(
            children: [
              TextField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Görsel URL',
                  hintText: 'https://...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _captionController,
                decoration: const InputDecoration(
                  labelText: 'Açıklama (opsiyonel)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          );
        }
        final imageUrl = widget.block['image_url'] as String?;
        final caption = widget.block['caption'] as String?;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl?.isNotEmpty == true)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 150,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, size: 48),
                  ),
                ),
              )
            else
              Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('Görsel URL girilmemiş',
                      style: TextStyle(color: Colors.grey)),
                ),
              ),
            if (caption?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(caption!,
                  style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
            ],
          ],
        );

      case 'activity':
        final activityId = widget.block['activity_id'] as String?;

        // If editing or new (no activity_id and not cancelled), show the editor
        if (_isEditing || (activityId == null && !_cancelledNewActivity)) {
          final activityType = widget.block['_activityType'] as String?
              ?? _loadedActivity?['type'] as String?
              ?? 'true_false';
          return ActivityEditor(
            chapterId: widget.chapterId,
            blockId: widget.block['id'] as String,
            activityType: activityType,
            existingActivity: _loadedActivity,
            onSaved: () {
              setState(() {
                _isEditing = false;
                _activityFuture = null; // invalidate cache
              });
              widget.onRefresh();
            },
            onCancel: () => setState(() {
              _isEditing = false;
              if (activityId == null) _cancelledNewActivity = true;
            }),
          );
        }

        // Read-only view: use cached future to avoid re-fetching on every build
        _activityFuture ??= _loadActivity(activityId!);
        return FutureBuilder<Map<String, dynamic>?>(
          future: _activityFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final activity = snapshot.data;
            if (activity == null) {
              return const Text('Activity not found');
            }
            _loadedActivity = activity;
            return _buildActivitySummary(activity);
          },
        );

      default:
        return Text('Bilinmeyen blok türü: $type');
    }
  }

  Widget _buildActivitySummary(Map<String, dynamic> activity) {
    final type = activity['type'] as String? ?? '';
    final content = activity['content'] as Map<String, dynamic>? ?? {};
    final vocabWords = (activity['vocabulary_words'] as List<dynamic>?)?.length ?? 0;

    String summary;
    switch (type) {
      case 'true_false':
        summary = content['statement'] as String? ?? '';
      case 'word_translation':
        summary = '${content['word'] ?? ''} → ${content['correct_answer'] ?? ''}';
      case 'find_words':
        summary = content['instruction'] as String? ?? '';
      case 'matching':
        final pairs = (content['pairs'] as List<dynamic>?)?.length ?? 0;
        summary = '${content['instruction'] ?? ''} ($pairs pairs)';
      default:
        summary = 'Unknown type';
    }

    final typeLabel = type == 'find_words'
        ? 'Select Multiple'
        : type.replaceAll('_', ' ').split(' ').map(
            (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : ''
          ).join(' ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(typeLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.purple)),
            ),
            if (vocabWords > 0) ...[
              const SizedBox(width: 8),
              Text('$vocabWords vocab words', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ]),
          const SizedBox(height: 8),
          Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _loadActivity(String activityId) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      return await supabase
          .from(DbTables.inlineActivities)
          .select()
          .eq('id', activityId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'text':
        return const Color(0xFF4F46E5);
      case 'image':
        return Colors.teal;
      case 'activity':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'text':
        return Icons.text_fields;
      case 'image':
        return Icons.image;
      case 'activity':
        return Icons.quiz;
      default:
        return Icons.help;
    }
  }

  String _getTypeName(String type) {
    if (type == 'activity') {
      final activityType = widget.block['_activityType'] as String?
          ?? _loadedActivity?['type'] as String?;
      if (activityType != null) {
        if (activityType == 'find_words') return 'Select Multiple';
        return activityType.replaceAll('_', ' ').split(' ').map(
          (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : ''
        ).join(' ');
      }
      return 'Aktivite';
    }
    switch (type) {
      case 'text':
        return 'Metin';
      case 'image':
        return 'Görsel';
      default:
        return 'Bilinmiyor';
    }
  }
}
