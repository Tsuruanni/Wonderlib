import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../supabase_client.dart';

// ============================================
// DATA CLASSES
// ============================================

class LearningPathUnitData {
  String? id; // null for new units
  final String unitId;
  final String unitName;
  final String? unitIcon;
  final String? unitColor;
  int sortOrder;
  final List<LearningPathItemData> items;

  LearningPathUnitData({
    this.id,
    required this.unitId,
    required this.unitName,
    this.unitIcon,
    this.unitColor,
    required this.sortOrder,
    required this.items,
  });

  LearningPathUnitData copyWith({
    String? id,
    String? unitId,
    String? unitName,
    String? unitIcon,
    String? unitColor,
    int? sortOrder,
    List<LearningPathItemData>? items,
  }) {
    return LearningPathUnitData(
      id: id ?? this.id,
      unitId: unitId ?? this.unitId,
      unitName: unitName ?? this.unitName,
      unitIcon: unitIcon ?? this.unitIcon,
      unitColor: unitColor ?? this.unitColor,
      sortOrder: sortOrder ?? this.sortOrder,
      items: items ?? this.items,
    );
  }
}

class LearningPathItemData {
  String? id; // null for new items
  final String itemType; // 'word_list' or 'book'
  final String itemId;
  final String itemName;
  final String? subtitle; // e.g. "5 kelime" or "A1 · 4 bölüm"
  int sortOrder;
  final List<String>? words; // word preview for word_list items (read-only)

  LearningPathItemData({
    this.id,
    required this.itemType,
    required this.itemId,
    required this.itemName,
    this.subtitle,
    required this.sortOrder,
    this.words,
  });

  LearningPathItemData copyWith({
    String? id,
    String? itemType,
    String? itemId,
    String? itemName,
    String? subtitle,
    int? sortOrder,
    List<String>? words,
  }) {
    return LearningPathItemData(
      id: id ?? this.id,
      itemType: itemType ?? this.itemType,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      subtitle: subtitle ?? this.subtitle,
      sortOrder: sortOrder ?? this.sortOrder,
      words: words ?? this.words,
    );
  }
}

// ============================================
// HELPERS
// ============================================

Color parseHexColor(String? hex) {
  if (hex == null || hex.length < 7) return const Color(0xFF58CC02);
  try {
    return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
  } catch (_) {
    return const Color(0xFF58CC02);
  }
}

// ============================================
// WIDGET: LearningPathTreeView
// ============================================

class LearningPathTreeView extends ConsumerStatefulWidget {
  const LearningPathTreeView({
    super.key,
    required this.units,
    this.onUnitsChanged,
    this.readOnly = false,
    this.showWordPreview = false,
  });

  final List<LearningPathUnitData> units;
  final ValueChanged<List<LearningPathUnitData>>? onUnitsChanged;
  final bool readOnly;
  final bool showWordPreview;

  @override
  ConsumerState<LearningPathTreeView> createState() =>
      _LearningPathTreeViewState();
}

class _LearningPathTreeViewState extends ConsumerState<LearningPathTreeView> {
  // Track which word_list items are expanded for word preview
  final Set<String> _expandedWordLists = {};

  void _notifyChange(List<LearningPathUnitData> updated) {
    widget.onUnitsChanged?.call(updated);
  }

  // --- Unit operations ---

  void _moveUnitUp(int index) {
    if (index <= 0) return;
    final units = List<LearningPathUnitData>.from(widget.units);
    final unit = units.removeAt(index);
    units.insert(index - 1, unit);
    _reassignUnitSortOrders(units);
    _notifyChange(units);
  }

  void _moveUnitDown(int index) {
    if (index >= widget.units.length - 1) return;
    final units = List<LearningPathUnitData>.from(widget.units);
    final unit = units.removeAt(index);
    units.insert(index + 1, unit);
    _reassignUnitSortOrders(units);
    _notifyChange(units);
  }

  void _removeUnit(int index) {
    final units = List<LearningPathUnitData>.from(widget.units);
    units.removeAt(index);
    _reassignUnitSortOrders(units);
    _notifyChange(units);
  }

  void _reassignUnitSortOrders(List<LearningPathUnitData> units) {
    for (int i = 0; i < units.length; i++) {
      units[i].sortOrder = i;
    }
  }

  // --- Item operations ---

  void _reorderItems(int unitIndex, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final units = List<LearningPathUnitData>.from(widget.units);
    final items = List<LearningPathItemData>.from(units[unitIndex].items);
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    _reassignItemSortOrders(items);
    units[unitIndex] = units[unitIndex].copyWith(items: items);
    _notifyChange(units);
  }

  void _removeItem(int unitIndex, int itemIndex) {
    final units = List<LearningPathUnitData>.from(widget.units);
    final items = List<LearningPathItemData>.from(units[unitIndex].items);
    items.removeAt(itemIndex);
    _reassignItemSortOrders(items);
    units[unitIndex] = units[unitIndex].copyWith(items: items);
    _notifyChange(units);
  }

  void _reassignItemSortOrders(List<LearningPathItemData> items) {
    for (int i = 0; i < items.length; i++) {
      items[i].sortOrder = i;
    }
  }

  // --- Add operations ---

  void _addUnit(Map<String, dynamic> unitData) {
    final units = List<LearningPathUnitData>.from(widget.units);
    units.add(LearningPathUnitData(
      unitId: unitData['id'] as String,
      unitName: unitData['name'] as String? ?? '',
      unitIcon: unitData['icon'] as String?,
      unitColor: unitData['color'] as String?,
      sortOrder: units.length,
      items: [],
    ));
    _notifyChange(units);
  }

  void _addWordList(int unitIndex, Map<String, dynamic> wlData) {
    final units = List<LearningPathUnitData>.from(widget.units);
    final items = List<LearningPathItemData>.from(units[unitIndex].items);
    items.add(LearningPathItemData(
      itemType: LearningPathItemType.wordList.dbValue,
      itemId: wlData['id'] as String,
      itemName: wlData['name'] as String? ?? '',
      subtitle: '${wlData['word_count'] ?? 0} kelime',
      sortOrder: items.length,
    ));
    _reassignItemSortOrders(items);
    units[unitIndex] = units[unitIndex].copyWith(items: items);
    _notifyChange(units);
  }

  void _addBook(int unitIndex, Map<String, dynamic> bookData) {
    final units = List<LearningPathUnitData>.from(widget.units);
    final items = List<LearningPathItemData>.from(units[unitIndex].items);
    items.add(LearningPathItemData(
      itemType: LearningPathItemType.book.dbValue,
      itemId: bookData['id'] as String,
      itemName: bookData['title'] as String? ?? '',
      subtitle:
          '${bookData['level'] ?? '-'} · ${bookData['chapter_count'] ?? 0} bölüm',
      sortOrder: items.length,
    ));
    _reassignItemSortOrders(items);
    units[unitIndex] = units[unitIndex].copyWith(items: items);
    _notifyChange(units);
  }

  // --- Exclude ID helpers ---

  Set<String> get _selectedUnitIds =>
      widget.units.map((u) => u.unitId).toSet();

  Set<String> _selectedItemIds(String itemType) {
    final ids = <String>{};
    for (final unit in widget.units) {
      for (final item in unit.items) {
        if (item.itemType == itemType) {
          ids.add(item.itemId);
        }
      }
    }
    return ids;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.units.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_outlined,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Henüz ünite eklenmedi',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: Colors.grey.shade500),
            ),
            if (!widget.readOnly) ...[
              const SizedBox(height: 16),
              _buildAddUnitButton(context),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < widget.units.length; i++) ...[
          _buildUnitCard(context, i),
          const SizedBox(height: 12),
        ],
        if (!widget.readOnly) _buildAddUnitButton(context),
      ],
    );
  }

  Widget _buildUnitCard(BuildContext context, int unitIndex) {
    final unit = widget.units[unitIndex];
    final unitColor = parseHexColor(unit.unitColor);
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unit header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: unitColor.withAlpha(25),
              border: Border(
                left: BorderSide(color: unitColor, width: 4),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: unitColor.withAlpha(50),
                  child: Text(
                    unit.unitIcon ?? '📚',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ünite ${unitIndex + 1}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: unitColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        unit.unitName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.readOnly) ...[
                  // Move up
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                    onPressed: unitIndex > 0 ? () => _moveUnitUp(unitIndex) : null,
                    tooltip: 'Yukarı taşı',
                    visualDensity: VisualDensity.compact,
                  ),
                  // Move down
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                    onPressed: unitIndex < widget.units.length - 1
                        ? () => _moveUnitDown(unitIndex)
                        : null,
                    tooltip: 'Aşağı taşı',
                    visualDensity: VisualDensity.compact,
                  ),
                  // Remove
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.red),
                    onPressed: () => _removeUnit(unitIndex),
                    tooltip: 'Üniteyi kaldır',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ),

          // Items list
          if (unit.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Center(
                child: Text(
                  'Bu ünitede henüz içerik yok',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ),
            )
          else
            _buildItemsList(context, unitIndex),

          // Add item buttons
          if (!widget.readOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => showWordListPicker(
                      context,
                      ref,
                      excludeIds: _selectedItemIds(
                          LearningPathItemType.wordList.dbValue),
                      onSelect: (wl) => _addWordList(unitIndex, wl),
                    ),
                    icon: const Icon(Icons.list_alt, size: 16),
                    label: const Text('Kelime Listesi Ekle'),
                    style: TextButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => showBookPicker(
                      context,
                      ref,
                      excludeIds:
                          _selectedItemIds(LearningPathItemType.book.dbValue),
                      onSelect: (book) => _addBook(unitIndex, book),
                    ),
                    icon: const Icon(Icons.menu_book, size: 16),
                    label: const Text('Kitap Ekle'),
                    style: TextButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemsList(BuildContext context, int unitIndex) {
    final unit = widget.units[unitIndex];

    if (widget.readOnly) {
      // Read-only: simple list without reordering
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            for (int i = 0; i < unit.items.length; i++)
              _buildItemTile(context, unitIndex, i),
          ],
        ),
      );
    }

    // Editable: ReorderableListView for items within a unit
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: unit.items.length,
        onReorder: (oldIndex, newIndex) =>
            _reorderItems(unitIndex, oldIndex, newIndex),
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) => Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(8),
              child: child,
            ),
            child: child,
          );
        },
        itemBuilder: (context, itemIndex) {
          return _buildItemTile(
            context,
            unitIndex,
            itemIndex,
            key: ValueKey(
                '${unit.unitId}_${unit.items[itemIndex].itemId}_$itemIndex'),
          );
        },
      ),
    );
  }

  Widget _buildItemTile(
    BuildContext context,
    int unitIndex,
    int itemIndex, {
    Key? key,
  }) {
    final item = widget.units[unitIndex].items[itemIndex];
    final isWordList = item.itemType == LearningPathItemType.wordList.dbValue;
    final isExpanded = _expandedWordLists.contains(item.itemId);

    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 12, right: 4),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.readOnly)
                const Icon(Icons.drag_handle, size: 18, color: Colors.grey),
              if (!widget.readOnly) const SizedBox(width: 4),
              CircleAvatar(
                radius: 12,
                backgroundColor: isWordList
                    ? Colors.orange.shade100
                    : Colors.blue.shade100,
                child: Text(
                  isWordList ? '📝' : '📖',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${itemIndex + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          title: Text(
            item.itemName,
            style: const TextStyle(fontSize: 14),
          ),
          subtitle: item.subtitle != null
              ? Text(item.subtitle!, style: const TextStyle(fontSize: 12))
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Expand word preview
              if (widget.showWordPreview &&
                  isWordList &&
                  item.words != null &&
                  item.words!.isNotEmpty)
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedWordLists.remove(item.itemId);
                      } else {
                        _expandedWordLists.add(item.itemId);
                      }
                    });
                  },
                  visualDensity: VisualDensity.compact,
                  tooltip: isExpanded ? 'Daralt' : 'Kelimeleri göster',
                ),
              // Remove button
              if (!widget.readOnly)
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                  onPressed: () => _removeItem(unitIndex, itemIndex),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Kaldır',
                ),
            ],
          ),
        ),
        // Word preview (expandable)
        if (widget.showWordPreview &&
            isWordList &&
            isExpanded &&
            item.words != null &&
            item.words!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.words!.join(', '),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade900,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAddUnitButton(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: () => showUnitPicker(
          context,
          ref,
          excludeIds: _selectedUnitIds,
          onSelect: _addUnit,
        ),
        icon: const Icon(Icons.add),
        label: const Text('Ünite Ekle'),
      ),
    );
  }
}

// ============================================
// PICKER DIALOGS
// ============================================

/// Shows a dialog to select a vocabulary unit.
void showUnitPicker(
  BuildContext context,
  WidgetRef ref, {
  required Set<String> excludeIds,
  required Function(Map<String, dynamic>) onSelect,
}) {
  final searchController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        return AlertDialog(
          title: const Text('Ünite Seç'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    hintText: 'Ünite ara...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      return _UnitPickerList(
                        searchQuery: searchController.text.trim(),
                        excludeIds: excludeIds,
                        onSelect: (unit) {
                          onSelect(unit);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
          ],
        );
      },
    ),
  );
}

/// Internal widget for unit picker list (uses ConsumerWidget for Supabase access).
class _UnitPickerList extends ConsumerWidget {
  const _UnitPickerList({
    required this.searchQuery,
    required this.excludeIds,
    required this.onSelect,
  });

  final String searchQuery;
  final Set<String> excludeIds;
  final Function(Map<String, dynamic>) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncUnits = ref.watch(_activeUnitsProvider);

    return asyncUnits.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (units) {
        var filtered = units
            .where((u) => !excludeIds.contains(u['id'] as String))
            .toList();

        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          filtered = filtered
              .where((u) =>
                  (u['name'] as String? ?? '').toLowerCase().contains(q))
              .toList();
        }

        if (filtered.isEmpty) {
          return const Center(child: Text('Ünite bulunamadı'));
        }

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final unit = filtered[index];
            final color = parseHexColor(unit['color'] as String?);
            return ListTile(
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: color.withAlpha(50),
                child: Text(
                  unit['icon'] as String? ?? '📚',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              title: Text(unit['name'] as String? ?? ''),
              subtitle: Text(
                'Sıra: ${unit['sort_order'] ?? 0}',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () => onSelect(unit),
            );
          },
        );
      },
    );
  }
}

/// Shows a dialog to select a word list.
void showWordListPicker(
  BuildContext context,
  WidgetRef ref, {
  required Set<String> excludeIds,
  required Function(Map<String, dynamic>) onSelect,
}) {
  final searchController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        return AlertDialog(
          title: const Text('Kelime Listesi Seç'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    hintText: 'Kelime listesi ara...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      return _WordListPickerList(
                        searchQuery: searchController.text.trim(),
                        excludeIds: excludeIds,
                        onSelect: (wl) {
                          onSelect(wl);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
          ],
        );
      },
    ),
  );
}

/// Internal widget for word list picker (uses ConsumerWidget for Supabase access).
class _WordListPickerList extends ConsumerWidget {
  const _WordListPickerList({
    required this.searchQuery,
    required this.excludeIds,
    required this.onSelect,
  });

  final String searchQuery;
  final Set<String> excludeIds;
  final Function(Map<String, dynamic>) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLists = searchQuery.isEmpty
        ? ref.watch(_allWordListsProvider)
        : ref.watch(_wordListSearchProvider(searchQuery));

    return asyncLists.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (lists) {
        final filtered = lists
            .where((wl) => !excludeIds.contains(wl['id'] as String))
            .toList();

        if (filtered.isEmpty) {
          return const Center(child: Text('Kelime listesi bulunamadı'));
        }

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final wl = filtered[index];
            return ListTile(
              leading: const Icon(Icons.list_alt),
              title: Text(wl['name'] as String? ?? ''),
              subtitle: Text(
                '${wl['word_count'] ?? 0} kelime'
                '${wl['level'] != null ? ' · ${wl['level']}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () => onSelect(wl),
            );
          },
        );
      },
    );
  }
}

/// Shows a dialog to select a book.
void showBookPicker(
  BuildContext context,
  WidgetRef ref, {
  required Set<String> excludeIds,
  required Function(Map<String, dynamic>) onSelect,
}) {
  final searchController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        return AlertDialog(
          title: const Text('Kitap Seç'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    hintText: 'Kitap ara...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      return _BookPickerList(
                        searchQuery: searchController.text.trim(),
                        excludeIds: excludeIds,
                        onSelect: (book) {
                          onSelect(book);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
          ],
        );
      },
    ),
  );
}

/// Internal widget for book picker (uses ConsumerWidget for Supabase access).
class _BookPickerList extends ConsumerWidget {
  const _BookPickerList({
    required this.searchQuery,
    required this.excludeIds,
    required this.onSelect,
  });

  final String searchQuery;
  final Set<String> excludeIds;
  final Function(Map<String, dynamic>) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBooks = searchQuery.isEmpty
        ? ref.watch(_publishedBooksProvider)
        : ref.watch(_bookSearchProvider(searchQuery));

    return asyncBooks.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (books) {
        final filtered = books
            .where((b) => !excludeIds.contains(b['id'] as String))
            .toList();

        if (filtered.isEmpty) {
          return const Center(child: Text('Kitap bulunamadı'));
        }

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final book = filtered[index];
            return ListTile(
              leading: const Icon(Icons.menu_book),
              title: Text(book['title'] as String? ?? ''),
              subtitle: Text(
                '${book['level'] ?? '-'} · ${book['chapter_count'] ?? 0} bölüm',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () => onSelect(book),
            );
          },
        );
      },
    );
  }
}

// ============================================
// PROVIDERS (file-private, for picker dialogs)
// ============================================

/// Active vocabulary units, sorted by sort_order.
final _activeUnitsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.vocabularyUnits)
      .select('id, name, sort_order, color, icon')
      .eq('is_active', true)
      .order('sort_order');
  return List<Map<String, dynamic>>.from(response);
});

/// All word lists, sorted by name.
final _allWordListsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.wordLists)
      .select('id, name, word_count, level, category')
      .order('name');
  return List<Map<String, dynamic>>.from(response);
});

/// Word list search by name.
final _wordListSearchProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, query) async {
  if (query.isEmpty) return [];
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.wordLists)
      .select('id, name, word_count, level, category')
      .ilike('name', '%$query%')
      .order('name')
      .limit(20);
  return List<Map<String, dynamic>>.from(response);
});

/// Published books with chapters.
final _publishedBooksProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.books)
      .select('id, title, level, chapter_count')
      .eq('status', BookStatus.published.dbValue)
      .gt('chapter_count', 0)
      .order('title');
  return List<Map<String, dynamic>>.from(response);
});

/// Book search by title.
final _bookSearchProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, query) async {
  if (query.isEmpty) return [];
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.books)
      .select('id, title, level, chapter_count')
      .eq('status', BookStatus.published.dbValue)
      .gt('chapter_count', 0)
      .ilike('title', '%$query%')
      .order('title')
      .limit(20);
  return List<Map<String, dynamic>>.from(response);
});
