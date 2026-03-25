import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../providers/avatar_admin_providers.dart';

class AvatarItemEditScreen extends ConsumerStatefulWidget {
  const AvatarItemEditScreen({super.key, this.itemId});
  final String? itemId;

  @override
  ConsumerState<AvatarItemEditScreen> createState() => _AvatarItemEditScreenState();
}

class _AvatarItemEditScreenState extends ConsumerState<AvatarItemEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _coinPriceCtrl = TextEditingController(text: '50');
  String? _categoryId;
  String _rarity = 'common';
  bool _isActive = true;
  String? _imageUrl;
  String? _previewUrl;
  bool _isLoading = false;
  bool _isEdit = false;

  static const _rarityPrices = {'common': 50, 'rare': 150, 'epic': 400, 'legendary': 1000};

  @override
  void initState() {
    super.initState();
    _isEdit = widget.itemId != null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _displayNameCtrl.dispose();
    _coinPriceCtrl.dispose();
    super.dispose();
  }

  void _loadData(Map<String, dynamic> data) {
    _nameCtrl.text = data['name'] as String? ?? '';
    _displayNameCtrl.text = data['display_name'] as String? ?? '';
    _coinPriceCtrl.text = '${data['coin_price'] ?? 50}';
    _categoryId = data['category_id'] as String?;
    _rarity = data['rarity'] as String? ?? 'common';
    _isActive = data['is_active'] as bool? ?? true;
    _imageUrl = data['image_url'] as String?;
    _previewUrl = data['preview_url'] as String?;
  }

  static bool _isSvgUrl(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    return path.toLowerCase().endsWith('.svg');
  }

  Future<String?> _uploadImage(String folder) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'svg', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) return null;

    final file = result.files.first;
    final ext = file.extension ?? 'png';
    final contentType = ext == 'svg' ? 'image/svg+xml' : 'image/$ext';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final path = '$folder/$fileName';

    final supabase = ref.read(supabaseClientProvider);
    await supabase.storage.from('avatars').uploadBinary(
      path,
      file.bytes!,
      fileOptions: FileOptions(contentType: contentType, upsert: true),
    );
    return supabase.storage.from('avatars').getPublicUrl(path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir kategori seçin')));
      return;
    }
    if (_imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen overlay resmi yükleyin')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final data = {
        'name': _nameCtrl.text.trim(),
        'display_name': _displayNameCtrl.text.trim(),
        'category_id': _categoryId,
        'rarity': _rarity,
        'coin_price': int.tryParse(_coinPriceCtrl.text) ?? 50,
        'is_active': _isActive,
        'image_url': _imageUrl,
        'preview_url': _previewUrl,
      };

      if (_isEdit) {
        await supabase.from(DbTables.avatarItems).update(data).eq('id', widget.itemId!);
      } else {
        await supabase.from(DbTables.avatarItems).insert(data);
      }

      ref.invalidate(avatarItemsAdminProvider);
      if (_isEdit) ref.invalidate(avatarItemDetailProvider(widget.itemId!));
      if (mounted) context.go('/avatars');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(avatarItemCategoriesAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Aksesuar Düzenle' : 'Yeni Aksesuar'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/avatars')),
      ),
      body: _isEdit
          ? ref.watch(avatarItemDetailProvider(widget.itemId!)).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Hata: $e')),
              data: (data) {
                if (data == null) return const Center(child: Text('Bulunamadı'));
                if (_nameCtrl.text.isEmpty) _loadData(data);
                return _buildForm(categoriesAsync);
              },
            )
          : _buildForm(categoriesAsync),
    );
  }

  Widget _buildForm(AsyncValue<List<Map<String, dynamic>>> categoriesAsync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Form
          Expanded(
            flex: 2,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name (slug)'),
                    validator: (v) => v == null || v.isEmpty ? 'Zorunlu' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _displayNameCtrl,
                    decoration: const InputDecoration(labelText: 'Display Name'),
                    validator: (v) => v == null || v.isEmpty ? 'Zorunlu' : null,
                  ),
                  const SizedBox(height: 16),
                  // Category dropdown
                  categoriesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Kategori hatası: $e'),
                    data: (categories) => DropdownButtonFormField<String>(
                      value: _categoryId,
                      decoration: const InputDecoration(labelText: 'Kategori'),
                      items: categories
                          .map((c) => DropdownMenuItem(
                                value: c['id'] as String,
                                child: Text(c['display_name'] as String),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _categoryId = v),
                      validator: (v) => v == null ? 'Zorunlu' : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Rarity dropdown
                  DropdownButtonFormField<String>(
                    value: _rarity,
                    decoration: const InputDecoration(labelText: 'Nadirlik'),
                    items: const [
                      DropdownMenuItem(value: 'common', child: Text('Common')),
                      DropdownMenuItem(value: 'rare', child: Text('Rare')),
                      DropdownMenuItem(value: 'epic', child: Text('Epic')),
                      DropdownMenuItem(value: 'legendary', child: Text('Legendary')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _rarity = v;
                          _coinPriceCtrl.text = '${_rarityPrices[v] ?? 50}';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _coinPriceCtrl,
                    decoration: const InputDecoration(labelText: 'Coin Fiyatı'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Aktif'),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                  const SizedBox(height: 16),
                  // Upload buttons
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                final url = await _uploadImage('items');
                                if (url != null) setState(() => _imageUrl = url);
                              },
                        icon: const Icon(Icons.upload),
                        label: const Text('Overlay PNG'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                final url = await _uploadImage('previews');
                                if (url != null) setState(() => _previewUrl = url);
                              },
                        icon: const Icon(Icons.upload),
                        label: const Text('Preview PNG'),
                      ),
                    ],
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
          ),
          const SizedBox(width: 32),
          // Preview
          Expanded(
            child: Column(
              children: [
                const Text('Önizleme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _rarityBorderColor(), width: 3),
                    color: Colors.grey.shade100,
                  ),
                  child: _imageUrl != null
                      ? (_isSvgUrl(_imageUrl!)
                          ? SvgPicture.network(_imageUrl!, fit: BoxFit.contain)
                          : Image.network(_imageUrl!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)))
                      : const Icon(Icons.image, size: 48, color: Colors.grey),
                ),
                if (_previewUrl != null) ...[
                  const SizedBox(height: 16),
                  const Text('Preview:', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade100,
                    ),
                    child: _isSvgUrl(_previewUrl!)
                        ? SvgPicture.network(_previewUrl!, fit: BoxFit.contain)
                        : Image.network(_previewUrl!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _rarityBorderColor() {
    switch (_rarity) {
      case 'common':
        return const Color(0xFFAFAFAF);
      case 'rare':
        return const Color(0xFF1CB0F6);
      case 'epic':
        return const Color(0xFF9B59B6);
      case 'legendary':
        return const Color(0xFFFFC800);
      default:
        return Colors.grey;
    }
  }
}
