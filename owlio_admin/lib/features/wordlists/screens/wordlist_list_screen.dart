import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/supabase_client.dart';
import '../../../core/providers/shared_providers.dart';

/// Provider for unit filter
final wordlistUnitFilterProvider = StateProvider<String?>((ref) => null);

/// Provider for loading all word lists
final wordlistsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final unitFilter = ref.watch(wordlistUnitFilterProvider);

  var query = supabase
      .from(DbTables.wordLists)
      .select('id, name, description, unit_id, order_in_unit, vocabulary_units(id, name, sort_order)');

  if (unitFilter != null) {
    query = query.eq('unit_id', unitFilter);
  }

  final response = await query.eq('is_system', true).order('name');
  return List<Map<String, dynamic>>.from(response);
});

class WordlistListScreen extends ConsumerWidget {
  const WordlistListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordlistsAsync = ref.watch(wordlistsProvider);
    final unitFilter = ref.watch(wordlistUnitFilterProvider);
    final unitsAsync = ref.watch(allVocabularyUnitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelime Listeleri'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/wordlists/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Yeni Kelime Listesi'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                // Unit filter
                SizedBox(
                  width: 250,
                  child: unitsAsync.when(
                    data: (units) => DropdownButtonFormField<String?>(
                      value: unitFilter,
                      decoration: const InputDecoration(
                        labelText: 'Ünite',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tüm Üniteler')),
                        ...units.map(
                          (unit) => DropdownMenuItem(
                            value: unit['id'] as String,
                            child: Text('${unit['sort_order']}. ${unit['name']}'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        ref.read(wordlistUnitFilterProvider.notifier).state = value;
                      },
                    ),
                    loading: () => const InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Ünite',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      child: Text('Yükleniyor...'),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 16),

                // Clear filter
                if (unitFilter != null)
                  TextButton.icon(
                    onPressed: () {
                      ref.read(wordlistUnitFilterProvider.notifier).state = null;
                    },
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Temizle'),
                  ),
              ],
            ),
          ),

          // Word lists
          Expanded(
            child: wordlistsAsync.when(
              data: (wordlists) {
                if (wordlists.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.list_alt,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Kelime listesi bulunamadı',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => context.go('/wordlists/new'),
                          icon: const Icon(Icons.add),
                          label: const Text('İlk kelime listenizi oluşturun'),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(1.5),
                      2: FixedColumnWidth(60),
                      3: FixedColumnWidth(50),
                    },
                    border: TableBorder.all(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    children: [
                      // Header
                      TableRow(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'Ad',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'Ünite',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'Sıra',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(),
                        ],
                      ),
                      // Data rows
                      ...wordlists.map((wordlist) {
                        final unit = wordlist['vocabulary_units']
                            as Map<String, dynamic>?;
                        final unitName = unit != null
                            ? '${unit['sort_order']}. ${unit['name']}'
                            : '';
                        final orderInUnit =
                            wordlist['order_in_unit'] as int? ?? 0;
                        return TableRow(
                          children: [
                            InkWell(
                              onTap: () =>
                                  context.go('/wordlists/${wordlist['id']}'),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  wordlist['name'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: unit != null
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF059669)
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        unitName,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF059669),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      'Atanmamış',
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                unit != null ? '$orderInUnit' : '',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () =>
                                  context.go('/wordlists/${wordlist['id']}'),
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                    const SizedBox(height: 16),
                    Text('Hata: $error'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(wordlistsProvider),
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
