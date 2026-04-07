import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';

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
          return ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: slices.length,
            onReorder: (oldIndex, newIndex) => _reorderSlice(slices, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final slice = slices[index];
              final color = _parseColor(slice['color'] as String? ?? '#999999');
              return Card(
                key: ValueKey(slice['id']),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: color),
                  title: Text(slice['label'] as String? ?? ''),
                  subtitle: Text(
                    '${slice['reward_type'] == 'coin' ? 'Coin' : 'Kart Paketi'}'
                    ' × ${slice['reward_amount']}'
                    '  |  Ağırlık: ${slice['weight']}'
                    '  |  ${(slice['is_active'] as bool? ?? true) ? 'Aktif' : 'Pasif'}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showSliceDialog(context, slice: slice),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteSlice(slice['id'] as String),
                      ),
                    ],
                  ),
                ),
              );
            },
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
                  decoration: const InputDecoration(labelText: 'Etiket (ör: 50 Coins)'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: rewardType,
                  decoration: const InputDecoration(labelText: 'Ödül Tipi'),
                  items: const [
                    DropdownMenuItem(value: 'coin', child: Text('Coin')),
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
                TextField(
                  controller: weightCtrl,
                  decoration: const InputDecoration(labelText: 'Ağırlık (olasılık)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: colorCtrl,
                  decoration: const InputDecoration(labelText: 'Renk (hex, ör: #FF9800)'),
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
