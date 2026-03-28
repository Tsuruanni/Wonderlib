import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../providers/avatar_admin_providers.dart';

class AvatarCategoryEditScreen extends ConsumerStatefulWidget {
  const AvatarCategoryEditScreen({super.key, this.categoryId});
  final String? categoryId;

  @override
  ConsumerState<AvatarCategoryEditScreen> createState() => _AvatarCategoryEditScreenState();
}

class _AvatarCategoryEditScreenState extends ConsumerState<AvatarCategoryEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _zIndexCtrl = TextEditingController(text: '0');
  final _sortOrderCtrl = TextEditingController(text: '0');
  bool _isLoading = false;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.categoryId != null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _displayNameCtrl.dispose();
    _zIndexCtrl.dispose();
    _sortOrderCtrl.dispose();
    super.dispose();
  }

  void _loadData(Map<String, dynamic> data) {
    _nameCtrl.text = data['name'] as String? ?? '';
    _displayNameCtrl.text = data['display_name'] as String? ?? '';
    _zIndexCtrl.text = '${data['z_index'] ?? 0}';
    _sortOrderCtrl.text = '${data['sort_order'] ?? 0}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final data = {
        'name': _nameCtrl.text.trim(),
        'display_name': _displayNameCtrl.text.trim(),
        'z_index': int.tryParse(_zIndexCtrl.text) ?? 0,
        'sort_order': int.tryParse(_sortOrderCtrl.text) ?? 0,
      };
      if (_isEdit) {
        await supabase.from(DbTables.avatarItemCategories).update(data).eq('id', widget.categoryId!);
      } else {
        await supabase.from(DbTables.avatarItemCategories).insert(data);
      }
      ref.invalidate(avatarItemCategoriesAdminProvider);
      if (_isEdit) ref.invalidate(avatarCategoryDetailProvider(widget.categoryId!));
      if (mounted) context.go('/avatars');
    } on PostgrestException catch (e) {
      if (mounted) {
        final msg = e.code == '23505'
            ? 'Bu isim zaten kullanılıyor. Farklı bir name girin.'
            : 'Hata: ${e.message}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Kategori Düzenle' : 'Yeni Kategori'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/avatars')),
      ),
      body: _isEdit
          ? ref.watch(avatarCategoryDetailProvider(widget.categoryId!)).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Hata: $e')),
              data: (data) {
                if (data == null) return const Center(child: Text('Bulunamadı'));
                if (_nameCtrl.text.isEmpty) _loadData(data);
                return _buildForm();
              },
            )
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name (slug)',
                helperText: 'head, face, body, neck, background',
              ),
              validator: (v) => v == null || v.isEmpty ? 'Zorunlu' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _displayNameCtrl,
              decoration: const InputDecoration(labelText: 'Display Name'),
              validator: (v) => v == null || v.isEmpty ? 'Zorunlu' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _zIndexCtrl,
              decoration: const InputDecoration(
                labelText: 'Z-Index',
                helperText: 'Render sırası: background=0, body=10, neck=15, face=20, head=30',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sortOrderCtrl,
              decoration: const InputDecoration(labelText: 'Sort Order'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEdit ? 'Güncelle' : 'Oluştur'),
            ),
          ],
        ),
      ),
    );
  }
}
