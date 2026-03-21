import 'package:flutter/material.dart';
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
            const SnackBar(content: Text('Bölüm oluşturuldu')),
          );
          context.go('/books/${widget.bookId}/chapters/${data['id']}');
        }
      } else {
        await supabase.from(DbTables.chapters).update(data).eq('id', widget.chapterId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bölüm kaydedildi')),
          );
          ref.invalidate(chapterDetailProvider(widget.chapterId!));
        }
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

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bölümü Sil'),
        content: const Text(
          'Bu bölümü silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
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

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from(DbTables.chapters).delete().eq('id', widget.chapterId!);

      if (mounted) {
        ref.invalidate(bookDetailProvider(widget.bookId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bölüm silindi')),
        );
        context.go('/books/${widget.bookId}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isNewChapter ? 'Yeni Bölüm' : 'Bölümü Düzenle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.invalidate(bookDetailProvider(widget.bookId));
            context.go('/books/${widget.bookId}');
          },
        ),
        actions: [
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
                // Title field at top
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
                            'Önce bölümü oluşturun, ardından içerik blokları ekleyin',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
