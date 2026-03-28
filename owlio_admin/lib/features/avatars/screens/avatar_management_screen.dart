import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../providers/avatar_admin_providers.dart';

class AvatarManagementScreen extends ConsumerStatefulWidget {
  const AvatarManagementScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  ConsumerState<AvatarManagementScreen> createState() =>
      _AvatarManagementScreenState();
}

class _AvatarManagementScreenState extends ConsumerState<AvatarManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 3, vsync: this, initialIndex: widget.initialTab);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avatar Yönetimi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: _buildActions(context),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Hayvanlar'),
            Tab(text: 'Kategoriler'),
            Tab(text: 'Aksesuarlar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BasesTab(),
          _CategoriesTab(),
          _ItemsTab(),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final labels = ['Yeni Hayvan', 'Yeni Kategori', 'Yeni Aksesuar'];
    final routes = [
      '/avatars/bases/new',
      '/avatars/categories/new',
      '/avatars/items/new'
    ];
    final idx = _tabController.index;
    return [
      FilledButton.icon(
        onPressed: () => context.go(routes[idx]),
        icon: const Icon(Icons.add, size: 18),
        label: Text(labels[idx]),
      ),
      const SizedBox(width: 16),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════
// BASES TAB
// ═══════════════════════════════════════════════════════════════

class _BasesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final basesAsync = ref.watch(avatarBasesAdminProvider);
    return basesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (bases) {
        if (bases.isEmpty) {
          return const Center(child: Text('Henüz hayvan eklenmemiş'));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.0,
          ),
          itemCount: bases.length,
          itemBuilder: (context, index) {
            final base = bases[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.go('/avatars/bases/${base['id']}'),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: Image.network(
                          base['image_url'] as String,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.pets,
                                size: 32, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      base['display_name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Sıra: ${base['sort_order']}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CATEGORIES TAB
// ═══════════════════════════════════════════════════════════════

class _CategoriesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(avatarItemCategoriesAdminProvider);
    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (categories) {
        if (categories.isEmpty) {
          return const Center(child: Text('Henüz kategori eklenmemiş'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            return ListTile(
              leading: CircleAvatar(child: Text('${cat['z_index']}')),
              title: Text(cat['display_name'] as String),
              subtitle: Text(
                  'name: ${cat['name']} | z_index: ${cat['z_index']} | sort: ${cat['sort_order']}'),
              trailing: const Icon(Icons.edit),
              onTap: () =>
                  context.go('/avatars/categories/${cat['id']}'),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ITEMS TAB — with category filter
// ═══════════════════════════════════════════════════════════════

class _ItemsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends ConsumerState<_ItemsTab> {
  String? _selectedCategoryId; // null = show all

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(avatarItemsAdminProvider);
    final categoriesAsync = ref.watch(avatarItemCategoriesAdminProvider);

    return Column(
      children: [
        // Category filter chips
        categoriesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (categories) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  FilterChip(
                    label: const Text('Tümü'),
                    selected: _selectedCategoryId == null,
                    onSelected: (_) =>
                        setState(() => _selectedCategoryId = null),
                  ),
                  const SizedBox(width: 8),
                  ...categories.map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat['display_name'] as String),
                          selected:
                              _selectedCategoryId == cat['id'] as String,
                          onSelected: (_) => setState(() =>
                              _selectedCategoryId = cat['id'] as String),
                        ),
                      )),
                ],
              ),
            ),
          ),
        ),

        // Items list
        Expanded(
          child: itemsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
            data: (items) {
              // Apply category filter
              final filtered = _selectedCategoryId == null
                  ? items
                  : items
                      .where((i) =>
                          i['category_id'] == _selectedCategoryId)
                      .toList();

              if (filtered.isEmpty) {
                return const Center(
                    child: Text('Bu kategoride aksesuar yok'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final category = item['avatar_item_categories']
                      as Map<String, dynamic>?;
                  final rarity =
                      item['rarity'] as String? ?? 'common';
                  final isActive =
                      item['is_active'] as bool? ?? true;

                  return ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _rarityColor(rarity), width: 2),
                        color: Colors.grey.shade100,
                      ),
                      child: Image.network(
                        item['image_url'] as String,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.checkroom,
                            size: 24,
                            color: Colors.grey),
                      ),
                    ),
                    title: Text(
                      item['display_name'] as String,
                      style: TextStyle(
                        color: isActive ? null : Colors.grey,
                        decoration: isActive
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: Text(
                      '${category?['display_name'] ?? '?'} | $rarity | ${item['coin_price']} coin${!isActive ? ' | İNAKTİF' : ''}',
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: () =>
                        context.go('/avatars/items/${item['id']}'),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Color _rarityColor(String rarity) =>
      Color(CardRarity.fromDbValue(rarity).colorHex);
}
