import 'package:flutter/material.dart';
import '../../../core/widgets/color_picker_field.dart';
import '../../../core/widgets/edit_screen_shortcuts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import 'unit_list_screen.dart';

// ============================================
// PROVIDERS
// ============================================

final unitDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, unitId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.vocabularyUnits)
      .select()
      .eq('id', unitId)
      .maybeSingle();
  return response;
});

// ============================================
// SCREEN
// ============================================

class UnitEditScreen extends ConsumerStatefulWidget {
  const UnitEditScreen({super.key, this.unitId});
  final String? unitId;

  @override
  ConsumerState<UnitEditScreen> createState() => _UnitEditScreenState();
}

class _UnitEditScreenState extends ConsumerState<UnitEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sortOrderController = TextEditingController(text: '0');
  final _colorController = TextEditingController(text: '#58CC02');
  final _iconController = TextEditingController();

  bool _isActive = true;
  bool _isLoading = false;
  bool _isInitialized = false;

  bool get _isNew => widget.unitId == null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sortOrderController.dispose();
    _colorController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  void _populateFields(Map<String, dynamic> unit) {
    if (_isInitialized) return;
    _isInitialized = true;

    _nameController.text = unit['name'] as String? ?? '';
    _descriptionController.text = unit['description'] as String? ?? '';
    _sortOrderController.text = '${unit['sort_order'] ?? 0}';
    _colorController.text = unit['color'] as String? ?? '#58CC02';
    _iconController.text = unit['icon'] as String? ?? '';
    _isActive = unit['is_active'] as bool? ?? true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'sort_order': int.tryParse(_sortOrderController.text) ?? 0,
        'color': _colorController.text.trim().isEmpty
            ? null
            : _colorController.text.trim(),
        'icon': _iconController.text.trim().isEmpty
            ? null
            : _iconController.text.trim(),
        'is_active': _isActive,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (_isNew) {
        data['id'] = const Uuid().v4();
        await supabase.from(DbTables.vocabularyUnits).insert(data);
      } else {
        await supabase
            .from(DbTables.vocabularyUnits)
            .update(data)
            .eq('id', widget.unitId!);
      }

      ref.invalidate(unitsProvider);
      if (!_isNew) {
        ref.invalidate(unitDetailProvider(widget.unitId!));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isNew ? 'Ünite oluşturuldu!' : 'Ünite güncellendi!'),
          ),
        );
        context.go('/units');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Üniteyi Sil'),
        content: const Text(
          'Bu ünite ve müfredat atamaları kaldırılacaktır. '
          'Bu üniteye atanan kelime listeleri atanmamış olacaktır. '
          'Emin misiniz?',
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

    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from(DbTables.vocabularyUnits).delete().eq('id', widget.unitId!);

      ref.invalidate(unitsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ünite silindi')),
        );
        context.go('/units');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    // Load existing unit data if editing
    if (!_isNew) {
      final unitAsync = ref.watch(unitDetailProvider(widget.unitId!));
      return unitAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Üniteyi Düzenle')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: const Text('Üniteyi Düzenle')),
          body: Center(child: Text('Hata: $e')),
        ),
        data: (unit) {
          if (unit == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Üniteyi Düzenle')),
              body: const Center(child: Text('Ünite bulunamadı')),
            );
          }
          _populateFields(unit);
          return _buildForm();
        },
      );
    }

    return _buildForm();
  }

  Widget _buildForm() {
    final previewColor = _parseColor(_colorController.text);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Yeni Ünite' : 'Üniteyi Düzenle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/units'),
        ),
        actions: [
          if (!_isNew)
            TextButton.icon(
              onPressed: _isLoading ? null : _delete,
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text('Sil', style: TextStyle(color: Colors.red)),
            ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isNew ? 'Oluştur' : 'Kaydet'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Form
            Expanded(
              flex: 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        Text(
                          'Ünite Detayları',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Ad *',
                            hintText: 'ör. Hayvanlar, Yiyecekler, Seyahat',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Zorunlu' : null,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Açıklama',
                            hintText: 'İsteğe bağlı açıklama',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _sortOrderController,
                                decoration: const InputDecoration(
                                  labelText: 'Sıralama *',
                                  hintText: '0',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) =>
                                    int.tryParse(v ?? '') == null
                                        ? 'Sayı olmalıdır'
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ColorPickerField(
                                initialValue: _colorController.text,
                                labelText: 'Renk',
                                onChanged: (hex) {
                                  _colorController.text = hex;
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _iconController,
                                decoration: const InputDecoration(
                                  labelText: 'İkon (emoji)',
                                  hintText: 'ör. hayvan emojisi',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Aktif'),
                          subtitle: const Text(
                            'Aktif olmayan üniteler öğrencilerden gizlenir',
                          ),
                          value: _isActive,
                          onChanged: (v) => setState(() => _isActive = v),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            // Right: Preview
            Expanded(
              flex: 1,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Önizleme',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: previewColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'ÜNİTE ${_sortOrderController.text}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white70,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_iconController.text.isNotEmpty) ...[
                                Text(
                                  _iconController.text,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                _nameController.text.isEmpty
                                    ? 'Ünite Adı'
                                    : _nameController.text,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (!_isActive)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber, color: Colors.orange),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Bu ünite aktif değil ve öğrencilere görünmeyecek.',
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    if (hex.length < 7) return const Color(0xFF58CC02);
    try {
      return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
    } catch (_) {
      return const Color(0xFF58CC02);
    }
  }
}
