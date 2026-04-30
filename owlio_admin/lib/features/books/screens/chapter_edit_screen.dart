import 'package:flutter/material.dart';
import '../../../core/widgets/edit_screen_shortcuts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import '../widgets/content_block_editor.dart';
import 'book_edit_screen.dart'; // For bookDetailProvider

/// Provider for loading a single chapter
final chapterDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, chapterId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.chapters)
      .select('*, content_blocks(*)')
      .eq('id', chapterId)
      .order('order_index', referencedTable: 'content_blocks')
      .maybeSingle();

  return response;
});

class ChapterEditScreen extends ConsumerStatefulWidget {
  const ChapterEditScreen({
    super.key,
    required this.bookId,
    this.chapterId,
  });

  final String bookId;
  final String? chapterId;

  @override
  ConsumerState<ChapterEditScreen> createState() => _ChapterEditScreenState();
}

class _ChapterEditScreenState extends ConsumerState<ChapterEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;

  bool get isNewChapter => widget.chapterId == null;

  @override
  void initState() {
    super.initState();
    if (!isNewChapter) {
      _loadChapter();
    }
  }

  Future<void> _loadChapter() async {
    setState(() => _isLoading = true);

    final chapter = await ref.read(chapterDetailProvider(widget.chapterId!).future);
    if (chapter != null && mounted) {
      _titleController.text = chapter['title'] ?? '';
      setState(() => _isLoading = false);
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      int orderIndex = 0;
      if (isNewChapter) {
        final maxOrder = await supabase
            .from(DbTables.chapters)
            .select('order_index')
            .eq('book_id', widget.bookId)
            .order('order_index', ascending: false)
            .limit(1)
            .maybeSingle();

        if (maxOrder != null) {
          orderIndex = (maxOrder['order_index'] as int) + 1;
        }
      }

      final data = {
        'title': _titleController.text.trim(),
        'use_content_blocks': true,
      };

      if (isNewChapter) {
        data['id'] = const Uuid().v4();
        data['book_id'] = widget.bookId;
        data['order_index'] = orderIndex;
        await supabase.from(DbTables.chapters).insert(data);

        if (mounted) {
          ref.invalidate(bookDetailProvider(widget.bookId));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chapter created')),
          );
          context.go('/books/${widget.bookId}/chapters/${data['id']}');
        }
      } else {
        await supabase.from(DbTables.chapters).update(data).eq('id', widget.chapterId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chapter saved')),
          );
          ref.invalidate(chapterDetailProvider(widget.chapterId!));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chapter'),
        content: const Text(
          'Are you sure you want to delete this chapter? This action cannot be undone.',
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
      await supabase.from(DbTables.chapters).delete().eq('id', widget.chapterId!);

      if (mounted) {
        ref.invalidate(bookDetailProvider(widget.bookId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chapter deleted')),
        );
        context.go('/books/${widget.bookId}');
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
    // Compute live word count from content_blocks (only for existing chapters)
    final wordCount = isNewChapter
        ? 0
        : ref.watch(chapterDetailProvider(widget.chapterId!)).maybeWhen(
              data: (ch) => _countWords(ch),
              orElse: () => 0,
            );

    final liveTitle = _titleController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isNewChapter
              ? 'Yeni Bölüm'
              : (liveTitle.isEmpty
                  ? 'Bölüm Düzenle'
                  : 'Bölüm: $liveTitle'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.invalidate(bookDetailProvider(widget.bookId));
            context.go('/books/${widget.bookId}');
          },
        ),
        actions: [
          if (!isNewChapter && wordCount > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.text_fields,
                          size: 14, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 4),
                      Text(
                        '$wordCount kelime',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (!isNewChapter)
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
                : Text(isNewChapter ? 'Oluştur' : 'Kaydet'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Title field at top — already sticky relative to scrolling
                // content blocks below. AppBar title also reflects live value.
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Bölüm Başlığı',
                        hintText: 'Bölüm başlığını girin',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Başlık zorunludur';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),

                // Content blocks (only for existing chapters)
                if (!isNewChapter)
                  Expanded(
                    child: ContentBlockEditor(
                      chapterId: widget.chapterId!,
                      onRefresh: () =>
                          ref.invalidate(chapterDetailProvider(widget.chapterId!)),
                    ),
                  )
                else
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.article_outlined,
                              size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'İçerik blokları için önce bölümü oluşturmalısın',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Auto-create + jump-to-edit shortcut
                          FilledButton.icon(
                            onPressed: _isSaving ? null : _handleSave,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Bölümü oluştur ve devam et'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  /// Counts whitespace-separated tokens across all `text` content blocks.
  int _countWords(Map<String, dynamic>? chapter) {
    if (chapter == null) return 0;
    final blocks = chapter['content_blocks'] as List? ?? [];
    var n = 0;
    for (final b in blocks) {
      if (b is Map && b['type'] == 'text') {
        final text = (b['text'] as String? ?? '').trim();
        if (text.isEmpty) continue;
        n += text.split(RegExp(r'\s+')).length;
      }
    }
    return n;
  }
}
