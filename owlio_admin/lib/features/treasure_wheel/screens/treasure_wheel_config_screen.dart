import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../../core/widgets/color_picker_field.dart';

/// Provider to fetch and cache wheel slices
final _wheelSlicesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('treasure_wheel_slices')
      .select()
      .order('sort_order');
  return List<Map<String, dynamic>>.from(response);
});

class TreasureWheelConfigScreen extends ConsumerStatefulWidget {
  const TreasureWheelConfigScreen({super.key});

  @override
  ConsumerState<TreasureWheelConfigScreen> createState() => _TreasureWheelConfigScreenState();
}

class _TreasureWheelConfigScreenState extends ConsumerState<TreasureWheelConfigScreen> {
  @override
  Widget build(BuildContext context) {
    final slicesAsync = ref.watch(_wheelSlicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hazine Çarkı Ayarları'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Yeni Dilim Ekle',
            onPressed: () => _showSliceDialog(context),
          ),
        ],
      ),
      body: slicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (slices) {
          if (slices.isEmpty) {
            return const Center(
              child: Text('Henüz dilim eklenmemiş. Sağ üstteki + butonuna tıklayın.'),
            );
          }
          // Compute active total weight for probability display
          final activeSlices = slices
              .where((s) => (s['is_active'] as bool? ?? true))
              .toList();
          final totalWeight = activeSlices.fold<int>(
            0,
            (sum, s) => sum + ((s['weight'] as int?) ?? 0),
          );

          return Column(
            children: [
              // Probability summary + pie chart
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: CustomPaint(
                        painter: _SlicePiePainter(
                          slices: activeSlices
                              .map((s) => _SliceWedge(
                                    weight:
                                        (s['weight'] as int?) ?? 0,
                                    color: _parseColor(s['color']
                                            as String? ??
                                        '#999999'),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Olasılık Dağılımı',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Aktif dilim: ${activeSlices.length} · '
                            'Toplam ağırlık: $totalWeight',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (totalWeight > 0)
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                for (final s in activeSlices)
                                  _ProbabilityChip(
                                    label: s['label'] as String? ?? '',
                                    color: _parseColor(s['color']
                                            as String? ??
                                        '#999999'),
                                    pct: ((s['weight'] as int?) ?? 0) /
                                        totalWeight *
                                        100,
                                  ),
                              ],
                            )
                          else
                            Text(
                              'Aktif dilim yok',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Slice list
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: slices.length,
                  onReorder: (oldIndex, newIndex) =>
                      _reorderSlice(slices, oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    final slice = slices[index];
                    final color = _parseColor(
                        slice['color'] as String? ?? '#999999');
                    final weight = (slice['weight'] as int?) ?? 0;
                    final isActive = slice['is_active'] as bool? ?? true;
                    final pct = (isActive && totalWeight > 0)
                        ? (weight / totalWeight * 100)
                        : 0.0;
                    return Card(
                      key: ValueKey(slice['id']),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: color),
                        title: Text(slice['label'] as String? ?? ''),
                        subtitle: Text(
                          '${slice['reward_type'] == 'coin' ? 'Gem' : 'Kart Paketi'}'
                          ' × ${slice['reward_amount']}'
                          '  |  Ağırlık: $weight'
                          '${isActive ? '  (~%${pct.toStringAsFixed(1)})' : '  (Pasif)'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  _showSliceDialog(context, slice: slice),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red),
                              onPressed: () =>
                                  _deleteSlice(slice['id'] as String),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  Future<void> _reorderSlice(List<Map<String, dynamic>> slices, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final supabase = ref.read(supabaseClientProvider);

    // Update sort_order for affected slices
    final reordered = List<Map<String, dynamic>>.from(slices);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);

    for (int i = 0; i < reordered.length; i++) {
      await supabase
          .from('treasure_wheel_slices')
          .update({'sort_order': i})
          .eq('id', reordered[i]['id'] as String);
    }
    ref.invalidate(_wheelSlicesProvider);
  }

  Future<void> _deleteSlice(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dilimi Sil'),
        content: const Text('Bu dilimi silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final supabase = ref.read(supabaseClientProvider);
    await supabase.from('treasure_wheel_slices').delete().eq('id', id);
    ref.invalidate(_wheelSlicesProvider);
  }

  Future<void> _showSliceDialog(BuildContext context, {Map<String, dynamic>? slice}) async {
    final isEditing = slice != null;
    final labelCtrl = TextEditingController(text: slice?['label'] as String? ?? '');
    final amountCtrl = TextEditingController(text: '${slice?['reward_amount'] ?? 10}');
    final weightCtrl = TextEditingController(text: '${slice?['weight'] ?? 10}');
    final colorCtrl = TextEditingController(text: slice?['color'] as String? ?? '#4CAF50');
    var rewardType = slice?['reward_type'] as String? ?? 'coin';
    var isActive = slice?['is_active'] as bool? ?? true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Dilimi Düzenle' : 'Yeni Dilim'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Etiket (ör: 50 Gems)'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: rewardType,
                  decoration: const InputDecoration(labelText: 'Ödül Tipi'),
                  items: const [
                    DropdownMenuItem(value: 'coin', child: Text('Gem')),
                    DropdownMenuItem(value: 'card_pack', child: Text('Kart Paketi')),
                  ],
                  onChanged: (v) => setDialogState(() => rewardType = v!),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(labelText: 'Miktar'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: weightCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Ağırlık'),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        min: 0,
                        max: 100,
                        divisions: 100,
                        value: (int.tryParse(weightCtrl.text) ?? 10)
                            .toDouble()
                            .clamp(0, 100),
                        label: weightCtrl.text,
                        onChanged: (v) {
                          weightCtrl.text = v.round().toString();
                          setDialogState(() {});
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ColorPickerField(
                  initialValue: colorCtrl.text,
                  labelText: 'Renk',
                  onChanged: (hex) => colorCtrl.text = hex,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Aktif'),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isEditing ? 'Güncelle' : 'Ekle'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final supabase = ref.read(supabaseClientProvider);
    final data = {
      'label': labelCtrl.text,
      'reward_type': rewardType,
      'reward_amount': int.tryParse(amountCtrl.text) ?? 10,
      'weight': int.tryParse(weightCtrl.text) ?? 10,
      'color': colorCtrl.text,
      'is_active': isActive,
    };

    if (isEditing) {
      await supabase.from('treasure_wheel_slices').update(data).eq('id', slice['id'] as String);
    } else {
      // Get next sort_order
      final existing = ref.read(_wheelSlicesProvider).valueOrNull ?? [];
      data['sort_order'] = existing.length;
      await supabase.from('treasure_wheel_slices').insert(data);
    }

    ref.invalidate(_wheelSlicesProvider);
  }
}

// ============================================
// PIE CHART HELPERS
// ============================================

class _SliceWedge {
  const _SliceWedge({required this.weight, required this.color});
  final int weight;
  final Color color;
}

class _SlicePiePainter extends CustomPainter {
  _SlicePiePainter({required this.slices});

  final List<_SliceWedge> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final totalWeight =
        slices.fold<int>(0, (sum, s) => sum + s.weight);
    if (totalWeight <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    var startAngle = -math.pi / 2; // start at top (12 o'clock)
    for (final slice in slices) {
      if (slice.weight <= 0) continue;
      final sweep = (slice.weight / totalWeight) * 2 * math.pi;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, startAngle, sweep, true, paint);
      // White separator stroke
      final strokePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawArc(rect, startAngle, sweep, true, strokePaint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _SlicePiePainter old) =>
      old.slices != slices;
}

class _ProbabilityChip extends StatelessWidget {
  const _ProbabilityChip({
    required this.label,
    required this.color,
    required this.pct,
  });

  final String label;
  final Color color;
  final double pct;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '%${pct.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
