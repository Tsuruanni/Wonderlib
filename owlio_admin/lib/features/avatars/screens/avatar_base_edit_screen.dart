import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../providers/avatar_admin_providers.dart';

class AvatarBaseEditScreen extends ConsumerStatefulWidget {
  const AvatarBaseEditScreen({super.key, this.baseId});
  final String? baseId;

  @override
  ConsumerState<AvatarBaseEditScreen> createState() =>
      _AvatarBaseEditScreenState();
}

class _AvatarBaseEditScreenState extends ConsumerState<AvatarBaseEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _sortOrderCtrl = TextEditingController(text: '0');

  String? _imageUrl;
  Uint8List? _imageBytes; // local bytes for instant preview
  bool _isLoading = false;
  bool _isEdit = false;
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.baseId != null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _displayNameCtrl.dispose();
    _sortOrderCtrl.dispose();
    super.dispose();
  }

  void _loadData(Map<String, dynamic> data) {
    if (_dataLoaded) return;
    _dataLoaded = true;
    _nameCtrl.text = data['name'] as String? ?? '';
    _displayNameCtrl.text = data['display_name'] as String? ?? '';
    _sortOrderCtrl.text = '${data['sort_order'] ?? 0}';
    _imageUrl = data['image_url'] as String?;
  }

  Future<void> _pickAndUploadImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'svg', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final ext = file.extension ?? 'png';
      final contentType = ext == 'svg' ? 'image/svg+xml' : 'image/$ext';
      final baseName = _nameCtrl.text.isNotEmpty
          ? _nameCtrl.text
          : '${DateTime.now().millisecondsSinceEpoch}';
      final path = 'bases/$baseName.$ext';

      await supabase.storage.from('avatars').uploadBinary(
            path,
            file.bytes!,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      final url = supabase.storage.from('avatars').getPublicUrl(path);

      setState(() {
        _imageUrl = url;
        _imageBytes = file.bytes; // keep bytes for instant preview
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resim yüklendi!'),
            backgroundColor: Colors.green,
          ),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir resim yükleyin')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final data = {
        'name': _nameCtrl.text.trim(),
        'display_name': _displayNameCtrl.text.trim(),
        'sort_order': int.tryParse(_sortOrderCtrl.text) ?? 0,
        'image_url': _imageUrl,
      };

      if (_isEdit) {
        await supabase
            .from(DbTables.avatarBases)
            .update(data)
            .eq('id', widget.baseId!);
      } else {
        await supabase.from(DbTables.avatarBases).insert(data);
      }

      ref.invalidate(avatarBasesAdminProvider);
      if (_isEdit) ref.invalidate(avatarBaseDetailProvider(widget.baseId!));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kaydedildi!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/avatars');
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Avatar Hayvan Düzenle' : 'Yeni Avatar Hayvan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/avatars'),
        ),
      ),
      body: _isEdit
          ? ref.watch(avatarBaseDetailProvider(widget.baseId!)).when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
                data: (data) {
                  if (data == null) {
                    return const Center(child: Text('Bulunamadı'));
                  }
                  _loadData(data);
                  return _buildForm();
                },
              )
          : _buildForm(),
    );
  }

  Widget _buildForm() {
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
                      helperText: 'owl, fox, bear...',
                    ),
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
                  TextFormField(
                    controller: _sortOrderCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Sort Order'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickAndUploadImage,
                    icon: const Icon(Icons.upload),
                    label: Text(
                      _imageBytes != null || _imageUrl != null
                          ? 'Resmi Değiştir'
                          : 'Resim Yükle (PNG/SVG)',
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEdit ? 'Güncelle' : 'Oluştur'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 32),

          // ── Preview ──
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Önizleme',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                  ),
                  child: ClipOval(child: _buildPreview()),
                ),
                if (_imageUrl != null) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    _imageUrl!,
                    style:
                        const TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Preview priority:
  /// 1. Local bytes (just uploaded, instant, no network)
  /// 2. Placeholder if no URL
  Widget _buildPreview() {
    // Show local bytes if available (just uploaded)
    if (_imageBytes != null) {
      return Image.memory(_imageBytes!, fit: BoxFit.cover);
    }

    // No image at all
    if (_imageUrl == null) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pets, size: 40, color: Colors.grey),
          SizedBox(height: 4),
          Text('Resim yükleyin', style: TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      );
    }

    // Has URL but no local bytes (editing existing) → try to load from network
    // Note: this will fail for seeded placeholder URLs that have no actual file
    return Image.network(
      _imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_upload, size: 36, color: Colors.orange),
          SizedBox(height: 4),
          Text(
            'Resim bulunamadı\nYeni resim yükleyin',
            style: TextStyle(fontSize: 10, color: Colors.orange),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
