import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase_client.dart';
import 'tile_theme_list_screen.dart';

// ============================================
// PROVIDERS
// ============================================

final tileThemeDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, themeId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.tileThemes)
      .select()
      .eq('id', themeId)
      .maybeSingle();
  return response;
});

// ============================================
// SCREEN
// ============================================

class TileThemeEditScreen extends ConsumerStatefulWidget {
  const TileThemeEditScreen({super.key, this.themeId});
  final String? themeId;

  @override
  ConsumerState<TileThemeEditScreen> createState() =>
      _TileThemeEditScreenState();
}

class _TileThemeEditScreenState extends ConsumerState<TileThemeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _sortOrderController = TextEditingController(text: '0');
  final _color1Controller = TextEditingController(text: '#2E7D32');
  final _color2Controller = TextEditingController(text: '#81C784');

  double _height = 1000;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isInitialized = false;

  final List<_NodePosition> _nodes = [];

  bool get _isNew => widget.themeId == null;

  @override
  void initState() {
    super.initState();
    if (_isNew) {
      _nodes.addAll([
        _NodePosition(50, 15),
        _NodePosition(35, 50),
        _NodePosition(50, 85),
      ]);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sortOrderController.dispose();
    _color1Controller.dispose();
    _color2Controller.dispose();
    super.dispose();
  }

  void _populateFields(Map<String, dynamic> theme) {
    if (_isInitialized) return;
    _isInitialized = true;

    _nameController.text = theme['name'] as String? ?? '';
    _sortOrderController.text = '${theme['sort_order'] ?? 0}';
    _color1Controller.text = theme['fallback_color_1'] as String? ?? '#2E7D32';
    _color2Controller.text = theme['fallback_color_2'] as String? ?? '#81C784';
    _height = (theme['height'] as int? ?? 1000).toDouble();
    _isActive = theme['is_active'] as bool? ?? true;

    _nodes.clear();
    final positions = theme['node_positions'] as List? ?? [];
    for (final p in positions) {
      if (p is Map) {
        _nodes.add(_NodePosition(
          ((p['x'] as num?)?.toDouble() ?? 0.5) * 100,
          ((p['y'] as num?)?.toDouble() ?? 0.5) * 100,
        ));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      final nodePositionsJson = _nodes
          .map((n) => {
                'x': double.parse((n.x / 100).toStringAsFixed(2)),
                'y': double.parse((n.y / 100).toStringAsFixed(2)),
              })
          .toList();

      final data = {
        'name': _nameController.text.trim(),
        'height': _height.round(),
        'fallback_color_1': _color1Controller.text.trim(),
        'fallback_color_2': _color2Controller.text.trim(),
        'node_positions': nodePositionsJson,
        'sort_order': int.tryParse(_sortOrderController.text) ?? 0,
        'is_active': _isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_isNew) {
        data['id'] = const Uuid().v4();
        await supabase.from(DbTables.tileThemes).insert(data);
      } else {
        await supabase
            .from(DbTables.tileThemes)
            .update(data)
            .eq('id', widget.themeId!);
      }

      ref.invalidate(tileThemesAdminProvider);
      if (!_isNew) {
        ref.invalidate(tileThemeDetailProvider(widget.themeId!));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(_isNew ? 'Tema oluşturuldu!' : 'Tema güncellendi!')),
        );
        context.go('/tiles');
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
        title: const Text('Temayı Sil'),
        content: const Text('Bu tema kalıcı olarak silinecek. Emin misiniz?'),
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
      await supabase
          .from(DbTables.tileThemes)
          .delete()
          .eq('id', widget.themeId!);
      ref.invalidate(tileThemesAdminProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tema silindi')),
        );
        context.go('/tiles');
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
    if (!_isNew) {
      final themeAsync = ref.watch(tileThemeDetailProvider(widget.themeId!));
      return themeAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Tema Düzenle')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: const Text('Tema Düzenle')),
          body: Center(child: Text('Hata: $e')),
        ),
        data: (theme) {
          if (theme == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Tema Düzenle')),
              body: const Center(child: Text('Tema bulunamadı')),
            );
          }
          _populateFields(theme);
          return _buildForm();
        },
      );
    }
    return _buildForm();
  }

  Widget _buildForm() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Yeni Tema' : 'Tema Düzenle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/tiles'),
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
                        Text('Tema Detayları',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Tema Adı *',
                            hintText: 'ör. Forest, Beach, Mountain',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Zorunlu' : null,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text('Yükseklik: '),
                            Expanded(
                              child: Slider(
                                value: _height,
                                min: 300,
                                max: 1500,
                                divisions: 24,
                                label: '${_height.round()}px',
                                onChanged: (v) =>
                                    setState(() => _height = v),
                              ),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text('${_height.round()}px',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _color1Controller,
                                decoration: const InputDecoration(
                                  labelText: 'Gradient Renk 1',
                                  hintText: '#2E7D32',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _color2Controller,
                                decoration: const InputDecoration(
                                  labelText: 'Gradient Renk 2',
                                  hintText: '#81C784',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _sortOrderController,
                                decoration: const InputDecoration(
                                  labelText: 'Sıralama',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: SwitchListTile(
                                title: const Text('Aktif'),
                                value: _isActive,
                                onChanged: (v) =>
                                    setState(() => _isActive = v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Node Pozisyonları (${_nodes.length})',
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            FilledButton.icon(
                              onPressed: () {
                                setState(
                                    () => _nodes.add(_NodePosition(50, 50)));
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Node Ekle'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(_nodes.length, (i) {
                          final node = _nodes[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 60,
                                  child: Text('Node ${i + 1}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                                const Text('X: '),
                                Expanded(
                                  child: Slider(
                                    value: node.x,
                                    min: 0,
                                    max: 100,
                                    divisions: 100,
                                    label: '${node.x.round()}%',
                                    onChanged: (v) =>
                                        setState(() => node.x = v),
                                  ),
                                ),
                                SizedBox(
                                    width: 40,
                                    child: Text('${node.x.round()}%')),
                                const SizedBox(width: 8),
                                const Text('Y: '),
                                Expanded(
                                  child: Slider(
                                    value: node.y,
                                    min: 0,
                                    max: 100,
                                    divisions: 100,
                                    label: '${node.y.round()}%',
                                    onChanged: (v) =>
                                        setState(() => node.y = v),
                                  ),
                                ),
                                SizedBox(
                                    width: 40,
                                    child: Text('${node.y.round()}%')),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red, size: 20),
                                  onPressed: () =>
                                      setState(() => _nodes.removeAt(i)),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            // Right: Live Preview
            Expanded(
              flex: 1,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Önizleme',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      _TilePreview(
                        color1: _parseHex(_color1Controller.text),
                        color2: _parseHex(_color2Controller.text),
                        height: _height,
                        nodes: _nodes,
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

  Color _parseHex(String hex) {
    if (hex.length < 7) return Colors.grey;
    try {
      return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
    } catch (_) {
      return Colors.grey;
    }
  }
}

// ============================================
// HELPERS
// ============================================

class _NodePosition {
  double x;
  double y;

  _NodePosition(this.x, this.y);
}

/// Scaled-down tile preview with gradient + numbered node dots.
class _TilePreview extends StatelessWidget {
  const _TilePreview({
    required this.color1,
    required this.color2,
    required this.height,
    required this.nodes,
  });

  final Color color1;
  final Color color2;
  final double height;
  final List<_NodePosition> nodes;

  static const _previewWidth = 280.0;

  @override
  Widget build(BuildContext context) {
    final scale = _previewWidth / 800.0;
    final previewHeight = height * scale;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: _previewWidth,
        height: previewHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color1, color2],
                  ),
                ),
              ),
            ),
            for (int i = 0; i < nodes.length; i++)
              Positioned(
                left: (nodes[i].x / 100) * _previewWidth - 14,
                top: (nodes[i].y / 100) * previewHeight - 14,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
