import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/color_picker_field.dart';
import '../../../core/widgets/edit_screen_shortcuts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  String? _imageUrl;
  Uint8List? _imageBytes; // local preview before save

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
    _imageUrl = theme['image_url'] as String?;

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
      // Validate dimensions BEFORE upload. Many Android GPUs cap texture
      // size at 4096; going over produces a blank tile on mobile even
      // when the file is small on disk.
      final codec = await ui.instantiateImageCodec(file.bytes!);
      final frame = await codec.getNextFrame();
      final imgW = frame.image.width;
      final imgH = frame.image.height;
      const maxDim = 2048;
      if (imgW > maxDim || imgH > maxDim) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Görsel çok büyük: $imgW×$imgH px. '
                'Lütfen en uzun kenarı $maxDim px altında olacak şekilde yeniden boyutlandırıp yükleyin '
                '(mobilde GPU texture limiti aşılırsa görsel hiç görünmez).',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 8),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final supabase = ref.read(supabaseClientProvider);

      final ext = file.extension ?? 'png';
      final contentType = 'image/$ext';
      final ts = DateTime.now().millisecondsSinceEpoch;
      final slug = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim().toLowerCase().replaceAll(' ', '_')
          : '$ts';
      final path = 'tiles/${slug}_$ts.$ext';

      await supabase.storage.from('avatars').uploadBinary(
            path,
            file.bytes!,
            fileOptions: FileOptions(contentType: contentType),
          );

      final url = supabase.storage.from('avatars').getPublicUrl(path);

      // Tile height is derived from the image aspect ratio:
      // kTileWidth = 800, so height = 800 * imgH / imgW.
      final autoHeight = (800.0 * imgH / imgW).roundToDouble();

      setState(() {
        _imageUrl = url;
        _imageBytes = file.bytes;
        _height = autoHeight.clamp(300, 5000);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Görsel yüklendi!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yükleme hatası: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        'image_url': _imageUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
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
    return EditScreenShortcuts(
      onSave: _save,
      child: _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
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
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade600, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Önerilen genişlik: 1920px. En uzun kenar 2048px altı olmalı '
                                  '(aksi halde mobilde görsel yüklenmez). '
                                  'Yükseklik görselin en-boy oranından otomatik hesaplanır.',
                                  style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text('Yükseklik: '),
                            const SizedBox(width: 8),
                            Text('${_height.round()}px',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Text('(görselden hesaplandı)',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Image upload
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.image, color: Colors.grey),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _imageUrl != null
                                            ? 'Görsel yüklendi'
                                            : 'Arka plan görseli (opsiyonel)',
                                        style: TextStyle(
                                          color: _imageUrl != null
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),
                                    if (_imageUrl != null)
                                      IconButton(
                                        icon: const Icon(Icons.clear, size: 20),
                                        onPressed: () => setState(() {
                                          _imageUrl = null;
                                          _imageBytes = null;
                                        }),
                                      ),
                                    FilledButton.icon(
                                      onPressed: _isLoading ? null : _pickAndUploadImage,
                                      icon: const Icon(Icons.upload, size: 18),
                                      label: Text(_imageUrl != null ? 'Değiştir' : 'Yükle'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ColorPickerField(
                                initialValue: _color1Controller.text,
                                labelText: 'Fallback Renk 1',
                                onChanged: (hex) {
                                  _color1Controller.text = hex;
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ColorPickerField(
                                initialValue: _color2Controller.text,
                                labelText: 'Fallback Renk 2',
                                onChanged: (hex) {
                                  _color2Controller.text = hex;
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Live gradient preview — updates as colors change
                            Container(
                              width: 80,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    _parseHex(_color1Controller.text),
                                    _parseHex(_color2Controller.text),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.grey.shade300),
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
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.touch_app,
                                  size: 16, color: Colors.indigo.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Sağdaki görsele tıklayarak yeni node ekleyin, '
                                  'noktalara basılı tutarak sürükleyin.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.indigo.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_nodes.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Henüz node yok.',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(_nodes.length, (i) {
                              final node = _nodes[i];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.indigo.shade200),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 10,
                                      backgroundColor: Colors.indigo,
                                      child: Text(
                                        '${i + 1}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${node.x.round()}%, ${node.y.round()}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () =>
                                          setState(() => _nodes.removeAt(i)),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      child: Padding(
                                        padding: const EdgeInsets.all(2),
                                        child: Icon(Icons.close,
                                            size: 14,
                                            color: Colors.red.shade400),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Önizleme',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      _TileCanvas(
                        color1: _parseHex(_color1Controller.text),
                        color2: _parseHex(_color2Controller.text),
                        height: _height,
                        nodes: _nodes,
                        imageUrl: _imageUrl,
                        imageBytes: _imageBytes,
                        onAddNode: (x, y) => setState(
                            () => _nodes.add(_NodePosition(x, y))),
                        onMoveNode: (i, x, y) => setState(() {
                          _nodes[i].x = x;
                          _nodes[i].y = y;
                        }),
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

/// Interactive canvas: tap empty area to add a node, drag a dot to move it.
/// Uses LayoutBuilder to get actual rendered width — never hardcodes a width
/// that might differ from the real constraint.
class _TileCanvas extends StatelessWidget {
  const _TileCanvas({
    required this.color1,
    required this.color2,
    required this.height,
    required this.nodes,
    this.imageUrl,
    this.imageBytes,
    this.onAddNode,
    this.onMoveNode,
  });

  final Color color1;
  final Color color2;
  final double height;
  final List<_NodePosition> nodes;
  final String? imageUrl;
  final Uint8List? imageBytes;

  /// Called with (x%, y%) when the canvas background is tapped.
  final void Function(double xPct, double yPct)? onAddNode;

  /// Called with (index, x%, y%) when a node is dragged.
  final void Function(int index, double xPct, double yPct)? onMoveNode;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final scale = w / 800.0;
        final h = height * scale;

        Widget background = _GradientFallback(color1: color1, color2: color2);
        if (imageBytes != null) {
          background = Image.memory(imageBytes!, fit: BoxFit.cover);
        } else if (imageUrl != null) {
          background = Image.network(
            imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _GradientFallback(color1: color1, color2: color2),
          );
        }

        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Background + tap-to-add layer
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: onAddNode == null
                      ? null
                      : (details) {
                          final p = details.localPosition;
                          final xPct = (p.dx / w * 100).clamp(0.0, 100.0);
                          final yPct = (p.dy / h * 100).clamp(0.0, 100.0);
                          onAddNode!(xPct, yPct);
                        },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: background,
                  ),
                ),
              ),
              // Draggable node dots
              for (int i = 0; i < nodes.length; i++)
                Positioned(
                  left: (nodes[i].x / 100) * w - 14,
                  top: (nodes[i].y / 100) * h - 14,
                  child: GestureDetector(
                    onPanUpdate: onMoveNode == null
                        ? null
                        : (details) {
                            final cur = nodes[i];
                            final pxX = (cur.x / 100) * w + details.delta.dx;
                            final pxY = (cur.y / 100) * h + details.delta.dy;
                            final newX =
                                (pxX / w * 100).clamp(0.0, 100.0);
                            final newY =
                                (pxY / h * 100).clamp(0.0, 100.0);
                            onMoveNode!(i, newX, newY);
                          },
                    child: MouseRegion(
                      cursor: onMoveNode == null
                          ? SystemMouseCursors.basic
                          : SystemMouseCursors.move,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.indigo, width: 2),
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
                            color: Colors.indigo,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GradientFallback extends StatelessWidget {
  const _GradientFallback({required this.color1, required this.color2});

  final Color color1;
  final Color color2;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color1, color2],
        ),
      ),
    );
  }
}
