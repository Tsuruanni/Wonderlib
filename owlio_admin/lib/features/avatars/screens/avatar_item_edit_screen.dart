import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/edit_screen_shortcuts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import '../providers/avatar_admin_providers.dart';

class AvatarItemEditScreen extends ConsumerStatefulWidget {
  const AvatarItemEditScreen({super.key, this.itemId});
  final String? itemId;

  @override
  ConsumerState<AvatarItemEditScreen> createState() =>
      _AvatarItemEditScreenState();
}

class _AvatarItemEditScreenState extends ConsumerState<AvatarItemEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _coinPriceCtrl = TextEditingController(text: '50');

  String? _categoryId;
  String _rarity = 'common';
  String _gender = 'unisex';
  bool _isActive = true;
  String? _imageUrl;
  Uint8List? _imageBytes; // local bytes for instant preview
  bool _isLoading = false;
  bool _isEdit = false;
  bool _dataLoaded = false;

  // For live composite preview — which base animal to show behind accessory
  String? _previewBaseUrl;

  static const _rarityPrices = {
    'common': 50,
    'rare': 150,
    'epic': 400,
    'legendary': 1000
  };

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
    if (_dataLoaded) return;
    _dataLoaded = true;
    _nameCtrl.text = data['name'] as String? ?? '';
    _displayNameCtrl.text = data['display_name'] as String? ?? '';
    _coinPriceCtrl.text = '${data['coin_price'] ?? 50}';
    _categoryId = data['category_id'] as String?;
    _rarity = data['rarity'] as String? ?? 'common';
    _gender = data['gender'] as String? ?? 'unisex';
    _isActive = data['is_active'] as bool? ?? true;
    _imageUrl = data['image_url'] as String?;
  }

  Future<void> _pickAndUploadImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseClientProvider);

      // Delete old blob if re-uploading
      if (_imageUrl != null) {
        final oldPath = _extractStoragePath(_imageUrl!);
        if (oldPath != null) {
          try {
            await supabase.storage.from('avatars').remove([oldPath]);
          } catch (_) {
            // Best-effort cleanup
          }
        }
      }

      final ext = file.extension ?? 'png';
      final ts = DateTime.now().millisecondsSinceEpoch;
      final slug = _nameCtrl.text.isNotEmpty
          ? _nameCtrl.text
          : '$ts';
      final path = 'items/${slug}_$ts.$ext';

      await supabase.storage.from('avatars').uploadBinary(
            path,
            file.bytes!,
            fileOptions: FileOptions(contentType: 'image/$ext'),
          );

      final url = supabase.storage.from('avatars').getPublicUrl(path);

      setState(() {
        _imageUrl = url;
        _imageBytes = file.bytes;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Resim yüklendi!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload hatası: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleClone() async {
    if (widget.itemId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aksesuarı Klonla'),
        content: const Text(
          'Bu aksesuar kopyalanarak yeni bir aksesuar oluşturulacak. '
          'Görsel, kategori, fiyat ve nadir seviyesi aynı, isim "(Kopya)" '
          'eki ile farklı olacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Klonla'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final original = await supabase
          .from(DbTables.avatarItems)
          .select()
          .eq('id', widget.itemId!)
          .single();

      final newId = const Uuid().v4();
      final clone = Map<String, dynamic>.from(original);
      clone['id'] = newId;
      clone['display_name'] =
          '${original['display_name']} (Kopya)';
      clone.remove('created_at');
      clone.remove('updated_at');
      await supabase.from(DbTables.avatarItems).insert(clone);

      ref.invalidate(avatarItemsAdminProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aksesuar klonlandı')),
        );
        context.go('/avatars/items/$newId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Klonlama başarısız: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen bir kategori seçin')));
      return;
    }
    if (_imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen resim yükleyin')));
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
        'gender': _gender,
        'coin_price': int.tryParse(_coinPriceCtrl.text) ?? 50,
        'is_active': _isActive,
        'image_url': _imageUrl,
      };

      if (_isEdit) {
        await supabase
            .from(DbTables.avatarItems)
            .update(data)
            .eq('id', widget.itemId!);
      } else {
        await supabase.from(DbTables.avatarItems).insert(data);
      }

      ref.invalidate(avatarItemsAdminProvider);
      if (_isEdit) ref.invalidate(avatarItemDetailProvider(widget.itemId!));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Kaydedildi!'), backgroundColor: Colors.green),
        );
        context.go('/avatars');
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        final msg = e.code == '23505'
            ? 'Bu isim zaten kullanılıyor. Farklı bir name girin.'
            : 'Kayıt hatası: ${e.message}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kayıt hatası: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EditScreenShortcuts(
      onSave: _save,
      child: _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final categoriesAsync = ref.watch(avatarItemCategoriesAdminProvider);
    final basesAsync = ref.watch(avatarBasesAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Aksesuar Düzenle' : 'Yeni Aksesuar'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/avatars')),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Klonla',
              icon: const Icon(Icons.content_copy_outlined),
              onPressed: _isLoading ? null : _handleClone,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isEdit
          ? ref.watch(avatarItemDetailProvider(widget.itemId!)).when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
                data: (data) {
                  if (data == null) {
                    return const Center(child: Text('Bulunamadı'));
                  }
                  _loadData(data);
                  return _buildForm(categoriesAsync, basesAsync);
                },
              )
          : _buildForm(categoriesAsync, basesAsync),
    );
  }

  Widget _buildForm(
    AsyncValue<List<Map<String, dynamic>>> categoriesAsync,
    AsyncValue<List<Map<String, dynamic>>> basesAsync,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Form ──
          Expanded(
            flex: 2,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Name (slug)',
                        helperText: 'red_beret, sunglasses...'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Zorunlu' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _displayNameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Display Name'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Zorunlu' : null,
                  ),
                  const SizedBox(height: 16),
                  categoriesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Kategori hatası: $e'),
                    data: (categories) => DropdownButtonFormField<String>(
                      value: _categoryId,
                      decoration:
                          const InputDecoration(labelText: 'Kategori'),
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
                  DropdownButtonFormField<String>(
                    value: _rarity,
                    decoration:
                        const InputDecoration(labelText: 'Nadirlik'),
                    items: const [
                      DropdownMenuItem(
                          value: 'common', child: Text('Common')),
                      DropdownMenuItem(value: 'rare', child: Text('Rare')),
                      DropdownMenuItem(value: 'epic', child: Text('Epic')),
                      DropdownMenuItem(
                          value: 'legendary', child: Text('Legendary')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _rarity = v;
                          _coinPriceCtrl.text =
                              '${_rarityPrices[v] ?? 50}';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _gender,
                    decoration:
                        const InputDecoration(labelText: 'Cinsiyet'),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Erkek')),
                      DropdownMenuItem(value: 'female', child: Text('Kadın')),
                      DropdownMenuItem(value: 'unisex', child: Text('Unisex')),
                    ],
                    onChanged: (v) => setState(() => _gender = v!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _coinPriceCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Gem Fiyatı'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final val = int.tryParse(v ?? '');
                      if (val == null || val < 0) return '0 veya üzeri olmalı';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Aktif'),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _pickAndUploadImage,
                        icon: const Icon(Icons.upload),
                        label: Text(_imageBytes != null || _imageUrl != null
                            ? 'Resmi Değiştir'
                            : 'Aksesuar PNG Yükle'),
                      ),
                      if (_imageUrl != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: SelectableText(
                            _imageUrl!,
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isEdit ? 'Güncelle' : 'Oluştur'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 32),

          // ── Preview — base animal + accessory composite ──
          Expanded(
            child: Column(
              children: [
                const Text('Canlı Önizleme',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),

                // Composite preview: base + accessory stacked
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: _rarityBorderColor(), width: 3),
                    color: Colors.grey.shade100,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Base animal (if selected)
                      if (_previewBaseUrl != null)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.network(
                            _previewBaseUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),

                      // Accessory overlay — local bytes or network URL
                      if (_imageBytes != null)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                        )
                      else if (_imageUrl != null)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.network(
                            _imageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cloud_upload, size: 36, color: Colors.orange),
                                  SizedBox(height: 4),
                                  Text('Resim yükleyin', style: TextStyle(fontSize: 10, color: Colors.orange)),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.checkroom, size: 40, color: Colors.grey),
                              SizedBox(height: 4),
                              Text('PNG yükleyin', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Base animal selector for preview
                const Text('Hayvan Seç (önizleme):',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                basesAsync.when(
                  loading: () => const SizedBox(
                      height: 50,
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2))),
                  error: (_, __) => const Text('Hayvanlar yüklenemedi'),
                  data: (bases) => SizedBox(
                    height: 56,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: bases.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final base = bases[i];
                        final url = base['image_url'] as String;
                        final isSelected = _previewBaseUrl == url;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _previewBaseUrl = url),
                          child: Container(
                            width: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.blue
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                              color: isSelected
                                  ? Colors.blue.shade50
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Image.network(
                                  url,
                                  width: 30,
                                  height: 30,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.pets, size: 20),
                                ),
                                Text(
                                  base['name'] as String,
                                  style: const TextStyle(fontSize: 8),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // URL moved next to upload button
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _rarityBorderColor() =>
      Color(CardRarity.fromDbValue(_rarity).colorHex);

  static String? _extractStoragePath(String url) {
    const marker = '/object/public/avatars/';
    final idx = url.indexOf(marker);
    if (idx < 0) return null;
    return url.substring(idx + marker.length);
  }
}
