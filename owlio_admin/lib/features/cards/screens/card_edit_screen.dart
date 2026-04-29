import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/edit_screen_shortcuts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import '../providers/card_providers.dart';

/// Provider for loading a single card
final cardDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, cardId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.mythCards)
      .select()
      .eq('id', cardId)
      .maybeSingle();
  return response;
});

class CardEditScreen extends ConsumerStatefulWidget {
  const CardEditScreen({super.key, this.cardId});

  final String? cardId;

  @override
  ConsumerState<CardEditScreen> createState() => _CardEditScreenState();
}

class _CardEditScreenState extends ConsumerState<CardEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNoController = TextEditingController();
  final _nameController = TextEditingController();
  final _powerController = TextEditingController();
  final _specialSkillController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryIconController = TextEditingController();

  CardCategory _category = CardCategory.turkishMyths;
  CardRarity _rarity = CardRarity.common;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploading = false;
  String? _imageUrl;

  bool get isNewCard => widget.cardId == null;

  @override
  void initState() {
    super.initState();
    if (!isNewCard) {
      _loadCard();
    } else {
      _powerController.text = '10';
      _categoryIconController.text = '🐺';
      _autoGenerateCardNo();
    }
  }

  Future<void> _autoGenerateCardNo() async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final result = await supabase
          .from(DbTables.mythCards)
          .select('card_no')
          .order('card_no', ascending: false)
          .limit(1);

      if (result.isNotEmpty) {
        final lastNo = result[0]['card_no'] as String;
        final num = int.tryParse(lastNo.replaceAll('M-', '')) ?? 0;
        _cardNoController.text = 'M-${(num + 1).toString().padLeft(3, '0')}';
      } else {
        _cardNoController.text = 'M-001';
      }
    } catch (_) {
      _cardNoController.text = 'M-001';
    }
  }

  Future<void> _loadCard() async {
    setState(() => _isLoading = true);

    final card = await ref.read(cardDetailProvider(widget.cardId!).future);
    if (card != null && mounted) {
      _cardNoController.text = card['card_no'] ?? '';
      _nameController.text = card['name'] ?? '';
      _powerController.text = (card['power'] ?? 10).toString();
      _specialSkillController.text = card['special_skill'] ?? '';
      _descriptionController.text = card['description'] ?? '';
      _categoryIconController.text = card['category_icon'] ?? '';
      setState(() {
        _category =
            CardCategory.fromDbValue(card['category'] as String? ?? '');
        _rarity = CardRarity.fromDbValue(card['rarity'] as String? ?? '');
        _isActive = card['is_active'] as bool? ?? true;
        _imageUrl = card['image_url'] as String?;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _cardNoController.dispose();
    _nameController.dispose();
    _powerController.dispose();
    _specialSkillController.dispose();
    _descriptionController.dispose();
    _categoryIconController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      final data = {
        'card_no': _cardNoController.text.trim(),
        'name': _nameController.text.trim(),
        'category': _category.dbValue,
        'rarity': _rarity.dbValue,
        'power': int.tryParse(_powerController.text) ?? 10,
        'special_skill': _specialSkillController.text.trim().isEmpty
            ? null
            : _specialSkillController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'category_icon': _categoryIconController.text.trim().isEmpty
            ? null
            : _categoryIconController.text.trim(),
        'is_active': _isActive,
        if (_imageUrl != null) 'image_url': _imageUrl,
      };

      if (isNewCard) {
        data['id'] = const Uuid().v4();
        await supabase.from(DbTables.mythCards).insert(data);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kart oluşturuldu')),
          );
          ref.invalidate(mythCardsProvider);
          context.go('/cards/${data['id']}');
        }
      } else {
        await supabase
            .from(DbTables.mythCards)
            .update(data)
            .eq('id', widget.cardId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kart kaydedildi')),
          );
          ref.invalidate(cardDetailProvider(widget.cardId!));
          ref.invalidate(mythCardsProvider);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleClone() async {
    if (widget.cardId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kartı Klonla'),
        content: const Text(
          'Bu kart kopyalanarak yeni bir kart oluşturulacak. '
          'Yeni kart, sonraki uygun kart numarasıyla ve "(Kopya)" eki ile '
          'oluşturulacak.',
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

    setState(() => _isSaving = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final original = await supabase
          .from(DbTables.mythCards)
          .select()
          .eq('id', widget.cardId!)
          .single();

      // Find next available card_no
      final maxRow = await supabase
          .from(DbTables.mythCards)
          .select('card_no')
          .order('card_no', ascending: false)
          .limit(1)
          .maybeSingle();
      final nextCardNo =
          ((maxRow?['card_no'] as int?) ?? 0) + 1;

      final newId = const Uuid().v4();
      final clone = Map<String, dynamic>.from(original);
      clone['id'] = newId;
      clone['card_no'] = nextCardNo;
      clone['name'] = '${original['name']} (Kopya)';
      clone.remove('created_at');
      clone.remove('updated_at');
      await supabase.from(DbTables.mythCards).insert(clone);

      ref.invalidate(mythCardsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kart klonlandı')),
        );
        context.go('/cards/$newId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Klonlama başarısız: $e')),
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
        title: const Text('Kartı Sil'),
        content: const Text(
          'Bu kartı silmek istediğinizden emin misiniz? '
          'Bu karta sahip kullanıcılar kartı kaybedecektir. '
          'Bu işlem geri alınamaz.',
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
      await supabase
          .from(DbTables.mythCards)
          .delete()
          .eq('id', widget.cardId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kart silindi')),
        );
        ref.invalidate(mythCardsProvider);
        context.go('/cards');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _isUploading = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final cardName = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : 'card_${const Uuid().v4().substring(0, 8)}';
      final ext = file.extension ?? 'png';
      final storagePath = '$cardName.$ext';

      await supabase.storage.from('card-images').uploadBinary(
            storagePath,
            file.bytes!,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = supabase.storage
          .from('card-images')
          .getPublicUrl(storagePath);

      setState(() => _imageUrl = publicUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Görsel yüklendi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yükleme hatası: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(isNewCard ? 'Yeni Kart' : 'Kartı Düzenle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/cards'),
        ),
        actions: [
          if (!isNewCard)
            IconButton(
              tooltip: 'Klonla',
              icon: const Icon(Icons.content_copy_outlined),
              onPressed: _isSaving ? null : _handleClone,
            ),
          if (!isNewCard)
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
                : Text(isNewCard ? 'Oluştur' : 'Kaydet'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Form
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kart Detayları',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 24),

                          // Card No
                          TextFormField(
                            controller: _cardNoController,
                            decoration: const InputDecoration(
                              labelText: 'Kart Numarası',
                              hintText: 'M-001',
                              helperText: 'Format: M-XXX',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Kart numarası zorunludur';
                              }
                              if (!RegExp(r'^M-\d{3}$').hasMatch(value.trim())) {
                                return 'M-XXX formatında olmalıdır (ör. M-001)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Name
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Kart Adı',
                              hintText: 'ör. Fenrir Kurt',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Ad zorunludur';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Category
                          DropdownButtonFormField<CardCategory>(
                            value: _category,
                            decoration: const InputDecoration(
                              labelText: 'Kategori',
                            ),
                            items: CardCategory.values.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Text(cat.label),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _category = value);
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // Rarity
                          DropdownButtonFormField<CardRarity>(
                            value: _rarity,
                            decoration: const InputDecoration(
                              labelText: 'Nadirlik',
                            ),
                            items: CardRarity.values.map((r) {
                              return DropdownMenuItem(
                                value: r,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: _rarityColor(r),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(r.label),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _rarity = value);
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // Power
                          TextFormField(
                            controller: _powerController,
                            decoration: const InputDecoration(
                              labelText: 'Güç',
                              hintText: '10',
                              helperText: 'Kart güç değeri',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Güç zorunludur';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Sayı olmalıdır';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Category Icon
                          TextFormField(
                            controller: _categoryIconController,
                            decoration: const InputDecoration(
                              labelText: 'Kategori İkonu (Emoji)',
                              hintText: '🐺',
                            ),
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(height: 16),

                          // Special Skill
                          TextFormField(
                            controller: _specialSkillController,
                            decoration: const InputDecoration(
                              labelText: 'Özel Yetenek',
                              hintText: 'ör. Gölge Saldırısı',
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Description
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Açıklama',
                              hintText: 'Kart hikayesi ve açıklaması',
                            ),
                            maxLines: 4,
                          ),
                          const SizedBox(height: 16),

                          // Image
                          const SizedBox(height: 8),
                          Text('Kart Görseli',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          if (_imageUrl != null && _imageUrl!.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _imageUrl!,
                                height: 150,
                                width: 150,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 150,
                                  width: 150,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image, size: 48),
                                ),
                              ),
                            )
                          else
                            Container(
                              height: 100,
                              width: 150,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Center(
                                child: Icon(Icons.image_not_supported,
                                    size: 32, color: Colors.grey),
                              ),
                            ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _isUploading ? null : _uploadImage,
                            icon: _isUploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.upload, size: 18),
                            label: Text(_isUploading
                                ? 'Yükleniyor...'
                                : _imageUrl != null
                                    ? 'Görseli Değiştir'
                                    : 'Görsel Yükle'),
                          ),
                          if (_imageUrl != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _imageUrl!,
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Is Active
                          SwitchListTile(
                            title: const Text('Aktif'),
                            subtitle: const Text(
                                'Aktif olmayan kartlar öğrencilerden gizlenir'),
                            value: _isActive,
                            onChanged: (value) {
                              setState(() => _isActive = value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Preview
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                        left: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Önizleme',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 16),
                        Center(
                          child: SizedBox(
                            width: 200,
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: _rarityColor(_rarity),
                                  width: 3,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    // Card No
                                    Text(
                                      _cardNoController.text.isEmpty
                                          ? 'M-XXX'
                                          : _cardNoController.text,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Image or Icon
                                    if (_imageUrl != null && _imageUrl!.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          _imageUrl!,
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _emojiPreview(_categoryIconController.text, _rarity),
                                        ),
                                      )
                                    else
                                      _emojiPreview(_categoryIconController.text, _rarity),
                                    const SizedBox(height: 12),
                                    // Name
                                    Text(
                                      _nameController.text.isEmpty
                                          ? 'Kart Adı'
                                          : _nameController.text,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _category.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Rarity + Power
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _rarityColor(_rarity)
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            _rarity.label,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: _rarityColor(_rarity),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(Icons.bolt,
                                            size: 14,
                                            color: Colors.amber.shade700),
                                        Text(
                                          _powerController.text.isEmpty
                                              ? '10'
                                              : _powerController.text,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_specialSkillController
                                        .text.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        _specialSkillController.text,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey.shade600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
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

  static Widget _emojiPreview(String text, CardRarity rarity) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: _rarityColor(rarity).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          text.isEmpty ? '🃏' : text,
          style: const TextStyle(fontSize: 32),
        ),
      ),
    );
  }

  static Color _rarityColor(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.common:
        return Colors.grey.shade400;
      case CardRarity.rare:
        return Colors.blue.shade400;
      case CardRarity.epic:
        return Colors.purple.shade400;
      case CardRarity.legendary:
        return Colors.amber.shade600;
    }
  }
}
