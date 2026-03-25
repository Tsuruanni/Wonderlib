import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../providers/avatar_admin_providers.dart';

bool _isSvg(String url) =>
    (Uri.tryParse(url)?.path ?? url).toLowerCase().endsWith('.svg');

Widget _img(String url, {BoxFit fit = BoxFit.contain}) {
  if (_isSvg(url)) return SvgPicture.network(url, fit: fit);
  return Image.network(url, fit: fit, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image));
}

class AvatarManagementScreen extends ConsumerStatefulWidget {
  const AvatarManagementScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  ConsumerState<AvatarManagementScreen> createState() => _AvatarManagementScreenState();
}

class _AvatarManagementScreenState extends ConsumerState<AvatarManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
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
    final routes = ['/avatars/bases/new', '/avatars/categories/new', '/avatars/items/new'];
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

class _BasesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final basesAsync = ref.watch(avatarBasesAdminProvider);
    return basesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (bases) {
        if (bases.isEmpty) return const Center(child: Text('Henüz hayvan eklenmemiş'));
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
                        child: _img(base['image_url'] as String, fit: BoxFit.cover),
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

class _CategoriesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(avatarItemCategoriesAdminProvider);
    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (categories) {
        if (categories.isEmpty) return const Center(child: Text('Henüz kategori eklenmemiş'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            return ListTile(
              leading: CircleAvatar(child: Text('${cat['z_index']}')),
              title: Text(cat['display_name'] as String),
              subtitle: Text('name: ${cat['name']} | z_index: ${cat['z_index']} | sort: ${cat['sort_order']}'),
              trailing: const Icon(Icons.edit),
              onTap: () => context.go('/avatars/categories/${cat['id']}'),
            );
          },
        );
      },
    );
  }
}

class _ItemsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(avatarItemsAdminProvider);
    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (items) {
        if (items.isEmpty) return const Center(child: Text('Henüz aksesuar eklenmemiş'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final category = item['avatar_item_categories'] as Map<String, dynamic>?;
            final rarity = item['rarity'] as String? ?? 'common';
            final isActive = item['is_active'] as bool? ?? true;
            return ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _rarityColor(rarity), width: 2),
                ),
                child: _img((item['preview_url'] ?? item['image_url']) as String),
              ),
              title: Text(
                item['display_name'] as String,
                style: TextStyle(
                  color: isActive ? null : Colors.grey,
                  decoration: isActive ? null : TextDecoration.lineThrough,
                ),
              ),
              subtitle: Text(
                '${category?['display_name'] ?? '?'} | $rarity | ${item['coin_price']} coin',
              ),
              trailing: const Icon(Icons.edit),
              onTap: () => context.go('/avatars/items/${item['id']}'),
            );
          },
        );
      },
    );
  }

  Color _rarityColor(String rarity) {
    switch (rarity) {
      case 'common':
        return const Color(0xFFAFAFAF);
      case 'rare':
        return const Color(0xFF1CB0F6);
      case 'epic':
        return const Color(0xFF9B59B6);
      case 'legendary':
        return const Color(0xFFFFC800);
      default:
        return Colors.grey;
    }
  }
}
