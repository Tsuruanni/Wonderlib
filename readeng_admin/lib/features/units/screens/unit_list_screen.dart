import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readeng_shared/readeng_shared.dart';

import '../../../core/supabase_client.dart';

// ============================================
// PROVIDERS
// ============================================

final unitsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.vocabularyUnits)
      .select()
      .order('sort_order', ascending: true);
  return List<Map<String, dynamic>>.from(response);
});

// ============================================
// SCREEN
// ============================================

class UnitListScreen extends ConsumerWidget {
  const UnitListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(unitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulary Units'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/units/new'),
            icon: const Icon(Icons.add),
            label: const Text('New Unit'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: unitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $e'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(unitsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (units) {
          if (units.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No units yet'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.go('/units/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create First Unit'),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: SizedBox(
                width: double.infinity,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Order')),
                    DataColumn(label: Text('Icon')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Description')),
                    DataColumn(label: Text('Active')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: units.map((unit) {
                    final color = _parseUnitColor(unit['color'] as String?);
                    return DataRow(
                      cells: [
                        DataCell(Text('${unit['sort_order']}')),
                        DataCell(
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: color,
                            child: Text(
                              (unit['icon'] as String?) ?? '',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        DataCell(Text(unit['name'] as String? ?? '')),
                        DataCell(
                          SizedBox(
                            width: 200,
                            child: Text(
                              unit['description'] as String? ?? '-',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          Icon(
                            (unit['is_active'] as bool? ?? true)
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: (unit['is_active'] as bool? ?? true)
                                ? Colors.green
                                : Colors.red,
                            size: 20,
                          ),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () =>
                                context.go('/units/${unit['id']}'),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Color _parseUnitColor(String? hex) {
  if (hex == null || hex.length < 7) return const Color(0xFF58CC02);
  try {
    return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
  } catch (_) {
    return const Color(0xFF58CC02);
  }
}
