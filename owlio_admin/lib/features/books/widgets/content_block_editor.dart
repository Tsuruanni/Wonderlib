import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';

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

class _ContentBlockListState extends ConsumerState<_ContentBlockList> {
  late List<Map<String, dynamic>> _localBlocks;
  bool _isGeneratingChapterAudio = false;

  @override
  void initState() {
    super.initState();
    _localBlocks = List.from(widget.blocks);
  }

  @override
  void didUpdateWidget(covariant _ContentBlockList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.blocks != oldWidget.blocks) {
      _localBlocks = List.from(widget.blocks);
    }
  }

  Future<void> _addBlock(String type) async {
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
    final newBlock = {
      'id': newBlockId,
      'chapter_id': widget.chapterId,
      'order_index': newOrderIndex,
      'type': type,
    };

    setState(() {
      _localBlocks = [..._localBlocks, newBlock];
    });

    try {
      await supabase.from(DbTables.contentBlocks).insert(newBlock);
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
    setState(() {
      _localBlocks = _localBlocks.where((b) => b['id'] != blockId).toList();
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from(DbTables.contentBlocks).delete().eq('id', blockId);
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
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              Text(
                'İçerik Blokları (${_localBlocks.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              // Generate Chapter Audio
              OutlinedButton.icon(
                onPressed: _isGeneratingChapterAudio ? null : _generateChapterAudio,
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
              // Add block buttons
              FilledButton.tonalIcon(
                onPressed: () => _addBlock('text'),
                icon: const Icon(Icons.text_fields, size: 18),
                label: const Text('Metin'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () => _addBlock('image'),
                icon: const Icon(Icons.image, size: 18),
                label: const Text('Görsel'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () => _addBlock('activity'),
                icon: const Icon(Icons.quiz, size: 18),
                label: const Text('Aktivite'),
              ),
            ],
          ),
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
                    return _BlockCard(
                      key: ValueKey(block['id']),
                      block: block,
                      index: index,
                      onDelete: () => _deleteBlock(block['id'] as String),
                      onRefresh: widget.onRefresh,
                    );
                  },
                ),
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
    required this.onDelete,
    required this.onRefresh,
  });

  final Map<String, dynamic> block;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_BlockCard> createState() => _BlockCardState();
}

class _BlockCardState extends ConsumerState<_BlockCard> {
  final _textController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _captionController = TextEditingController();
  bool _isEditing = false;
  bool _isSaving = false;

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
        'updated_at': DateTime.now().toIso8601String(),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _getTypeColor(type).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(_getTypeIcon(type), size: 20, color: _getTypeColor(type)),
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
                const Spacer(),
                if (_isEditing) ...[
                  TextButton(
                    onPressed: () => setState(() => _isEditing = false),
                    child: const Text('İptal'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSaving ? null : _saveBlock,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Kaydet'),
                  ),
                ] else ...[
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    tooltip: 'Düzenle',
                    onPressed: () => setState(() => _isEditing = true),
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
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(Icons.drag_handle, color: Colors.grey.shade600),
                      ),
                    ),
                  ),
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
        return FutureBuilder<Map<String, dynamic>?>(
          future: activityId != null ? _loadActivity(activityId) : Future.value(null),
          builder: (context, snapshot) {
            final activity = snapshot.data;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.quiz, color: Colors.purple.shade400),
                      const SizedBox(width: 12),
                      Expanded(
                        child: activity != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activity['title'] as String? ?? 'Aktivite',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Tür: ${activity['type'] ?? 'bilinmiyor'}',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              )
                            : Text(
                                activityId != null
                                    ? 'Aktivite ID: $activityId'
                                    : 'Aktivite atanmamış',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );

      default:
        return Text('Bilinmeyen blok türü: $type');
    }
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
    switch (type) {
      case 'text':
        return 'Metin';
      case 'image':
        return 'Görsel';
      case 'activity':
        return 'Aktivite';
      default:
        return 'Bilinmiyor';
    }
  }
}
