// owlio_admin/lib/features/tiles/screens/tile_theme_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/supabase_client.dart';

// ============================================
// PROVIDERS
// ============================================

final tileThemesAdminProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.tileThemes)
      .select()
      .order('sort_order', ascending: true);
  return List<Map<String, dynamic>>.from(response);
});

// ============================================
// SCREEN
// ============================================

class TileThemeListScreen extends ConsumerWidget {
  const TileThemeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themesAsync = ref.watch(tileThemesAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tile Temaları'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/tiles/new'),
            icon: const Icon(Icons.add),
            label: const Text('Yeni Tema'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: themesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (themes) {
          if (themes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Henüz tema yok'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.go('/tiles/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Yeni Tema'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Renk')),
                DataColumn(label: Text('Tema Adı')),
                DataColumn(label: Text('Yükseklik')),
                DataColumn(label: Text('Node Sayısı')),
                DataColumn(label: Text('Sıralama')),
                DataColumn(label: Text('Aktif')),
                DataColumn(label: Text('')),
              ],
              rows: themes.map((theme) {
                final color1 = _parseHex(theme['fallback_color_1'] as String? ?? '#888888');
                final color2 = _parseHex(theme['fallback_color_2'] as String? ?? '#CCCCCC');
                final positions = theme['node_positions'] as List? ?? [];

                return DataRow(cells: [
                  DataCell(
                    Container(
                      width: 48,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [color1, color2]),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  DataCell(Text(theme['name'] as String? ?? '')),
                  DataCell(Text('${theme['height'] ?? 1000}px')),
                  DataCell(Text('${positions.length}')),
                  DataCell(Text('${theme['sort_order'] ?? 0}')),
                  DataCell(Icon(
                    (theme['is_active'] as bool? ?? true)
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: (theme['is_active'] as bool? ?? true)
                        ? Colors.green
                        : Colors.red,
                    size: 20,
                  )),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => context.go('/tiles/${theme['id']}'),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          );
        },
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
