import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:readeng_shared/readeng_shared.dart';
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
          // Use invalidate to mark as stale and trigger refetch
          ref.invalidate(contentBlocksProvider(chapterId));
          onRefresh();
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
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
    // Update local blocks when parent provides new data
    if (widget.blocks != oldWidget.blocks) {
      _localBlocks = List.from(widget.blocks);
    }
  }

  Future<void> _addBlock(String type) async {
    final supabase = ref.read(supabaseClientProvider);

    // Calculate new order_index based on current local blocks
    int newOrderIndex = 0;
    if (_localBlocks.isNotEmpty) {
      // Find the max order_index in local blocks
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

    // Optimistically add to local list immediately
    setState(() {
      _localBlocks = [..._localBlocks, newBlock];
    });

    // Then persist to database
    try {
      await supabase.from(DbTables.contentBlocks).insert(newBlock);
      // Refresh from server to ensure consistency
      widget.onRefresh();
    } catch (e) {
      // Rollback on error
      setState(() {
        _localBlocks = _localBlocks.where((b) => b['id'] != newBlockId).toList();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding block: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteBlock(String blockId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Block'),
        content: const Text('Are you sure you want to delete this content block?'),
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

    // Optimistically remove from local list
    final deletedBlock = _localBlocks.firstWhere((b) => b['id'] == blockId);
    setState(() {
      _localBlocks = _localBlocks.where((b) => b['id'] != blockId).toList();
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from(DbTables.contentBlocks).delete().eq('id', blockId);
      widget.onRefresh();
    } catch (e) {
      // Rollback on error
      setState(() {
        _localBlocks = [..._localBlocks, deletedBlock]..sort(
            (a, b) => (a['order_index'] as int).compareTo(b['order_index'] as int),
          );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting block: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _generateChapterAudio() async {
    // Check if there are any text blocks
    final textBlocks = _localBlocks.where((b) => b['type'] == 'text').toList();
    if (textBlocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No text blocks to generate audio for'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if any text blocks have content
    final blocksWithText = textBlocks.where(
      (b) => (b['text'] as String?)?.isNotEmpty == true,
    ).toList();

    if (blocksWithText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All text blocks are empty. Add content first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isGeneratingChapterAudio = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      // Call the generate-chapter-audio edge function
      final response = await supabase.functions.invoke(
        'generate-chapter-audio',
        body: {
          'chapterId': widget.chapterId,
          'voiceId': 'QngvLQR8bsLR5bzoa6Vv', // Michael voice
        },
      );

      if (response.status != 200) {
        throw Exception(response.data?['error'] ?? 'Failed to generate chapter audio');
      }

      final blocksProcessed = response.data?['blocksProcessed'] ?? 0;

      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio generated for $blocksProcessed blocks!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating chapter audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isGeneratingChapterAudio = false);
    }
  }

  Future<void> _reorderBlocks(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    if (newIndex > oldIndex) newIndex--;

    // Save original state for rollback
    final originalBlocks = List<Map<String, dynamic>>.from(_localBlocks);

    // Optimistically update local list
    final reorderedBlocks = List<Map<String, dynamic>>.from(_localBlocks);
    final movedBlock = reorderedBlocks.removeAt(oldIndex);
    reorderedBlocks.insert(newIndex, movedBlock);

    // Update order_index in local list
    for (int i = 0; i < reorderedBlocks.length; i++) {
      reorderedBlocks[i] = {...reorderedBlocks[i], 'order_index': i};
    }

    setState(() {
      _localBlocks = reorderedBlocks;
    });

    // Persist to database
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
      // Rollback to original state immediately
      if (mounted) {
        setState(() {
          _localBlocks = originalBlocks;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reordering: $e'), backgroundColor: Colors.red),
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Content Blocks (${_localBlocks.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              // Generate Chapter Audio button
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
                    ? 'Generating...'
                    : 'Generate Chapter Audio'),
              ),
              const SizedBox(width: 12),
              PopupMenuButton<String>(
                onSelected: _addBlock,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'text',
                    child: Row(
                      children: [
                        Icon(Icons.text_fields),
                        SizedBox(width: 8),
                        Text('Text Block'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'image',
                    child: Row(
                      children: [
                        Icon(Icons.image),
                        SizedBox(width: 8),
                        Text('Image Block'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'activity',
                    child: Row(
                      children: [
                        Icon(Icons.quiz),
                        SizedBox(width: 8),
                        Text('Activity Block'),
                      ],
                    ),
                  ),
                ],
                child: FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Block'),
                ),
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
                      Icon(
                        Icons.view_agenda_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No content blocks yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add text, images, or activities to build your chapter content',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _localBlocks.length,
                  onReorder: _reorderBlocks,
                  buildDefaultDragHandles: false, // We use custom drag handles
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        final elevation = Tween<double>(begin: 0, end: 8).evaluate(animation);
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
  bool _isGeneratingAudio = false;
  bool _isPlayingPreview = false;
  AudioPlayer? _audioPlayer;

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
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _togglePreview() async {
    final audioUrl = widget.block['audio_url'] as String?;
    if (audioUrl == null || audioUrl.isEmpty) return;

    if (_isPlayingPreview) {
      await _audioPlayer?.stop();
      setState(() => _isPlayingPreview = false);
      return;
    }

    setState(() => _isPlayingPreview = true);

    try {
      _audioPlayer ??= AudioPlayer();
      await _audioPlayer!.setUrl(audioUrl);
      await _audioPlayer!.play();

      // Listen for completion
      _audioPlayer!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) {
            setState(() => _isPlayingPreview = false);
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isPlayingPreview = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
          const SnackBar(content: Text('Block saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _generateAudio() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter text first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isGeneratingAudio = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      // Call the generate-audio-sync edge function
      final response = await supabase.functions.invoke(
        'generate-audio-sync',
        body: {
          'blockId': widget.block['id'],
          'text': text,
          'voiceId': 'QngvLQR8bsLR5bzoa6Vv', // Michael voice
        },
      );

      if (response.status != 200) {
        throw Exception(response.data?['error'] ?? 'Failed to generate audio');
      }

      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isGeneratingAudio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.block['type'] as String;
    final hasAudio = widget.block['audio_url'] != null;

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
                Icon(
                  _getTypeIcon(type),
                  size: 20,
                  color: _getTypeColor(type),
                ),
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
                        Text(
                          'Audio',
                          style: TextStyle(fontSize: 10, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                if (_isEditing) ...[
                  TextButton(
                    onPressed: () => setState(() => _isEditing = false),
                    child: const Text('Cancel'),
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
                        : const Text('Save'),
                  ),
                ] else ...[
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => setState(() => _isEditing = true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    color: Colors.red,
                    onPressed: widget.onDelete,
                  ),
                  ReorderableDragStartListener(
                    index: widget.index,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.drag_handle,
                          color: Colors.grey.shade600,
                        ),
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

          // Audio generation (for text blocks)
          if (type == 'text' && !_isEditing)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isGeneratingAudio ? null : _generateAudio,
                    icon: _isGeneratingAudio
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            hasAudio ? Icons.refresh : Icons.record_voice_over,
                            size: 18,
                          ),
                    label: Text(hasAudio ? 'Regenerate Audio' : 'Generate Audio'),
                  ),
                  if (hasAudio) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _togglePreview,
                      icon: Icon(
                        _isPlayingPreview ? Icons.stop : Icons.play_arrow,
                        size: 18,
                      ),
                      label: Text(_isPlayingPreview ? 'Stop' : 'Preview'),
                    ),
                  ],
                ],
              ),
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
              hintText: 'Enter paragraph text...',
              border: OutlineInputBorder(),
            ),
          );
        }
        final text = widget.block['text'] as String?;
        return Text(
          text?.isNotEmpty == true ? text! : 'No text content',
          style: TextStyle(
            color: text?.isNotEmpty == true ? null : Colors.grey,
            fontStyle: text?.isNotEmpty == true ? null : FontStyle.italic,
          ),
        );

      case 'image':
        if (_isEditing) {
          return Column(
            children: [
              TextField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Image URL',
                  hintText: 'https://...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _captionController,
                decoration: const InputDecoration(
                  labelText: 'Caption (optional)',
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
                  child: Text('No image URL', style: TextStyle(color: Colors.grey)),
                ),
              ),
            if (caption?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                caption!,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity != null
                                  ? _getActivityTypeName(activity['type'] as String?)
                                  : 'Activity Block',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              activity != null
                                  ? _getActivityQuestion(activity)
                                  : 'No activity configured',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showActivityDialog(activity),
                        child: Text(activity != null ? 'Edit' : 'Configure'),
                      ),
                    ],
                  ),
                  if (activity != null) ...[
                    const SizedBox(height: 12),
                    _buildActivityPreview(activity),
                  ],
                ],
              ),
            );
          },
        );

      default:
        return Text('Unknown block type: $type');
    }
  }

  Future<Map<String, dynamic>?> _loadActivity(String activityId) async {
    final supabase = ref.read(supabaseClientProvider);
    final response = await supabase
        .from(DbTables.inlineActivities)
        .select()
        .eq('id', activityId)
        .maybeSingle();
    return response;
  }

  String _getActivityTypeName(String? type) {
    switch (type) {
      case 'true_false':
        return 'True/False Question';
      case 'word_translation':
        return 'Word Translation';
      case 'find_words':
        return 'Find Words';
      case 'multiple_choice':
        return 'Multiple Choice';
      case 'matching':
        return 'Matching';
      default:
        return 'Activity';
    }
  }

  String _getActivityQuestion(Map<String, dynamic> activity) {
    final type = activity['type'] as String?;
    final content = activity['content'] as Map<String, dynamic>? ?? {};

    switch (type) {
      case 'true_false':
        return content['statement'] as String? ?? 'No statement';
      case 'word_translation':
        return 'Word: ${content['word'] ?? 'No word'}';
      case 'find_words':
        return content['instruction'] as String? ?? 'No instruction';
      default:
        return 'No question';
    }
  }

  Widget _buildActivityPreview(Map<String, dynamic> activity) {
    final type = activity['type'] as String?;
    // The schema uses 'content' not 'data'
    final content = activity['content'] as Map<String, dynamic>? ?? {};

    switch (type) {
      case 'true_false':
        return Row(
          children: [
            const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
            const SizedBox(width: 4),
            Text(
              'Correct answer: ${content['correctAnswer'] == true ? 'True' : 'False'}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      case 'word_translation':
        final options = (content['options'] as List?)?.cast<String>() ?? [];
        return Text(
          'Options: ${options.join(', ')}',
          style: const TextStyle(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case 'find_words':
        final correctAnswers = (content['correctAnswers'] as List?)?.cast<String>() ?? [];
        return Text(
          'Target words: ${correctAnswers.join(', ')}',
          style: const TextStyle(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _showActivityDialog(Map<String, dynamic>? existingActivity) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ActivityConfigDialog(
        existingActivity: existingActivity,
        blockId: widget.block['id'] as String,
      ),
    );

    if (result != null) {
      // Activity was created/updated, refresh the block
      widget.onRefresh();
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
      case 'audio':
        return Icons.audiotrack;
      default:
        return Icons.help_outline;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'text':
        return const Color(0xFF4F46E5);
      case 'image':
        return const Color(0xFF059669);
      case 'activity':
        return const Color(0xFF7C3AED);
      case 'audio':
        return const Color(0xFFDC2626);
      default:
        return Colors.grey;
    }
  }

  String _getTypeName(String type) {
    switch (type) {
      case 'text':
        return 'Text Block';
      case 'image':
        return 'Image Block';
      case 'activity':
        return 'Activity Block';
      case 'audio':
        return 'Audio Block';
      default:
        return 'Unknown Block';
    }
  }
}

/// Dialog for configuring activity blocks
class _ActivityConfigDialog extends ConsumerStatefulWidget {
  const _ActivityConfigDialog({
    required this.blockId,
    this.existingActivity,
  });

  final String blockId;
  final Map<String, dynamic>? existingActivity;

  @override
  ConsumerState<_ActivityConfigDialog> createState() => _ActivityConfigDialogState();
}

class _ActivityConfigDialogState extends ConsumerState<_ActivityConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Common fields
  late String _selectedType;
  int _xpReward = 5;

  // True/False fields
  final _statementController = TextEditingController();
  bool _correctAnswer = true;

  // Word Translation fields
  final _wordController = TextEditingController();
  final _translationController = TextEditingController();
  final _optionsControllers = <TextEditingController>[];

  // Find Words fields
  final _instructionController = TextEditingController();
  final _findWordsOptionsControllers = <TextEditingController>[];
  final _correctAnswersSet = <int>{};

  @override
  void initState() {
    super.initState();
    _initializeFromExisting();
  }

  void _initializeFromExisting() {
    final activity = widget.existingActivity;
    if (activity != null) {
      _selectedType = activity['type'] as String? ?? 'true_false';
      _xpReward = activity['xp_reward'] as int? ?? 5;

      final content = activity['content'] as Map<String, dynamic>? ?? {};

      switch (_selectedType) {
        case 'true_false':
          _statementController.text = content['statement'] as String? ?? '';
          _correctAnswer = content['correctAnswer'] as bool? ?? true;
          break;
        case 'word_translation':
          _wordController.text = content['word'] as String? ?? '';
          _translationController.text = content['correctAnswer'] as String? ?? '';
          final options = (content['options'] as List?)?.cast<String>() ?? [];
          for (final opt in options) {
            _optionsControllers.add(TextEditingController(text: opt));
          }
          break;
        case 'find_words':
          _instructionController.text = content['instruction'] as String? ?? '';
          final options = (content['options'] as List?)?.cast<String>() ?? [];
          final correctAnswers = (content['correctAnswers'] as List?)?.cast<String>() ?? [];
          for (int i = 0; i < options.length; i++) {
            _findWordsOptionsControllers.add(TextEditingController(text: options[i]));
            if (correctAnswers.contains(options[i])) {
              _correctAnswersSet.add(i);
            }
          }
          break;
      }
    } else {
      _selectedType = 'true_false';
      // Add 4 empty options for word translation by default
      for (int i = 0; i < 4; i++) {
        _optionsControllers.add(TextEditingController());
      }
      // Add 6 empty options for find words by default
      for (int i = 0; i < 6; i++) {
        _findWordsOptionsControllers.add(TextEditingController());
      }
    }
  }

  @override
  void dispose() {
    _statementController.dispose();
    _wordController.dispose();
    _translationController.dispose();
    _instructionController.dispose();
    for (final c in _optionsControllers) {
      c.dispose();
    }
    for (final c in _findWordsOptionsControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      // Build content based on type
      Map<String, dynamic> content;
      switch (_selectedType) {
        case 'true_false':
          content = {
            'statement': _statementController.text.trim(),
            'correctAnswer': _correctAnswer,
          };
          break;
        case 'word_translation':
          content = {
            'word': _wordController.text.trim(),
            'correctAnswer': _translationController.text.trim(),
            'options': _optionsControllers
                .map((c) => c.text.trim())
                .where((t) => t.isNotEmpty)
                .toList(),
          };
          break;
        case 'find_words':
          final allOptions = _findWordsOptionsControllers
              .map((c) => c.text.trim())
              .where((t) => t.isNotEmpty)
              .toList();
          final correctAnswers = <String>[];
          for (int i = 0; i < _findWordsOptionsControllers.length; i++) {
            if (_correctAnswersSet.contains(i) && _findWordsOptionsControllers[i].text.trim().isNotEmpty) {
              correctAnswers.add(_findWordsOptionsControllers[i].text.trim());
            }
          }
          content = {
            'instruction': _instructionController.text.trim(),
            'options': allOptions,
            'correctAnswers': correctAnswers,
          };
          break;
        default:
          content = {};
      }

      // Get chapter_id from the content_block
      final blockResult = await supabase
          .from(DbTables.contentBlocks)
          .select('chapter_id')
          .eq('id', widget.blockId)
          .single();

      final chapterId = blockResult['chapter_id'] as String;

      String activityId;

      if (widget.existingActivity != null) {
        // Update existing activity
        activityId = widget.existingActivity!['id'] as String;
        await supabase
            .from(DbTables.inlineActivities)
            .update({
              'type': _selectedType,
              'content': content,
              'xp_reward': _xpReward,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', activityId);
      } else {
        // Create new activity
        activityId = const Uuid().v4();

        // Get the order_index of the content block to use as after_paragraph_index
        final blockOrderResult = await supabase
            .from(DbTables.contentBlocks)
            .select('order_index')
            .eq('id', widget.blockId)
            .single();

        final orderIndex = blockOrderResult['order_index'] as int;

        await supabase.from(DbTables.inlineActivities).insert({
          'id': activityId,
          'chapter_id': chapterId,
          'type': _selectedType,
          'after_paragraph_index': orderIndex,
          'content': content,
          'xp_reward': _xpReward,
        });

        // Update the content_block to reference this activity
        await supabase
            .from(DbTables.contentBlocks)
            .update({'activity_id': activityId})
            .eq('id', widget.blockId);
      }

      if (mounted) {
        Navigator.pop(context, {'id': activityId});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving activity: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.quiz, color: Colors.purple),
                  const SizedBox(width: 8),
                  Text(
                    widget.existingActivity != null ? 'Edit Activity' : 'Configure Activity',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Activity Type
                      const Text(
                        'Activity Type',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'true_false',
                            child: Text('True/False Question'),
                          ),
                          DropdownMenuItem(
                            value: 'word_translation',
                            child: Text('Word Translation'),
                          ),
                          DropdownMenuItem(
                            value: 'find_words',
                            child: Text('Find Words'),
                          ),
                        ],
                        onChanged: widget.existingActivity != null
                            ? null // Can't change type when editing
                            : (value) {
                                setState(() => _selectedType = value!);
                              },
                      ),
                      const SizedBox(height: 16),

                      // XP Reward
                      Row(
                        children: [
                          const Text(
                            'XP Reward: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: TextFormField(
                              initialValue: _xpReward.toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (v) {
                                setState(() {
                                  _xpReward = int.tryParse(v) ?? 5;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('XP', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Type-specific fields
                      _buildTypeFields(),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Activity'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeFields() {
    switch (_selectedType) {
      case 'true_false':
        return _buildTrueFalseFields();
      case 'word_translation':
        return _buildWordTranslationFields();
      case 'find_words':
        return _buildFindWordsFields();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTrueFalseFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statement',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _statementController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter a statement that can be true or false...',
            border: OutlineInputBorder(),
          ),
          validator: (v) => v?.trim().isEmpty == true ? 'Statement is required' : null,
        ),
        const SizedBox(height: 16),
        const Text(
          'Correct Answer',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ChoiceChip(
              label: const Text('True'),
              selected: _correctAnswer,
              onSelected: (_) => setState(() => _correctAnswer = true),
              selectedColor: Colors.green.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('False'),
              selected: !_correctAnswer,
              onSelected: (_) => setState(() => _correctAnswer = false),
              selectedColor: Colors.red.withValues(alpha: 0.3),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWordTranslationFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Word',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _wordController,
          decoration: const InputDecoration(
            hintText: 'Enter the English word...',
            border: OutlineInputBorder(),
          ),
          validator: (v) => v?.trim().isEmpty == true ? 'Word is required' : null,
        ),
        const SizedBox(height: 16),
        const Text(
          'Correct Translation',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _translationController,
          decoration: const InputDecoration(
            hintText: 'Enter the correct translation...',
            border: OutlineInputBorder(),
          ),
          validator: (v) => v?.trim().isEmpty == true ? 'Translation is required' : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text(
              'Options (wrong answers)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
              onPressed: () {
                setState(() {
                  _optionsControllers.add(TextEditingController());
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._optionsControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Option ${index + 1}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: _optionsControllers.length > 1
                      ? () {
                          setState(() {
                            _optionsControllers[index].dispose();
                            _optionsControllers.removeAt(index);
                          });
                        }
                      : null,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFindWordsFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Instruction',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _instructionController,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'e.g., Find the adjectives in this text...',
            border: OutlineInputBorder(),
          ),
          validator: (v) => v?.trim().isEmpty == true ? 'Instruction is required' : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text(
              'Word Options',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            const Text(
              '(check correct answers)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
              onPressed: () {
                setState(() {
                  _findWordsOptionsControllers.add(TextEditingController());
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._findWordsOptionsControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          final isCorrect = _correctAnswersSet.contains(index);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Checkbox(
                  value: isCorrect,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _correctAnswersSet.add(index);
                      } else {
                        _correctAnswersSet.remove(index);
                      }
                    });
                  },
                ),
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Word ${index + 1}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      fillColor: isCorrect ? Colors.green.withValues(alpha: 0.1) : null,
                      filled: isCorrect,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: _findWordsOptionsControllers.length > 2
                      ? () {
                          setState(() {
                            _findWordsOptionsControllers[index].dispose();
                            _findWordsOptionsControllers.removeAt(index);
                            // Update correct answers set
                            final newSet = <int>{};
                            for (final i in _correctAnswersSet) {
                              if (i < index) {
                                newSet.add(i);
                              } else if (i > index) {
                                newSet.add(i - 1);
                              }
                            }
                            _correctAnswersSet.clear();
                            _correctAnswersSet.addAll(newSet);
                          });
                        }
                      : null,
                ),
              ],
            ),
          );
        }),
        if (_correctAnswersSet.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Select at least one correct answer',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
